// tsne_common.h -- the single shared header of the project.
//
// It collects, in this order:
//   1. common    : types, FIt-SNE interpolation math, grid construction, counter-based RNG, argument parser, JSON writer
//   2. cpu_fft   : self-contained mixed-radix FFT (serial CPU baseline and the CPU stand-in for cuFFT)
//   3. dataset   : binary file formats and PCA (implemented in src/core.cpp)
//   4. problem   : point ordering, perplexity calibration, symmetrised P in CSR form (implemented in src/core.cpp)
//   5. gpu       : CUDA/cuFFT runtime helpers; only compiled when the including file defines TSNE_GPU
//                  (tsne_gpu.cu, microbench.cu, prep_gpu.cu).  With -DTSNE_EMULATE the CUDA subset is replaced by the
//                  single-thread CPU emulation in cuda_emu.h (testing without a GPU only; never used for timings).
#pragma once
// common.h — shared types, interpolation math, RNG, argument parsing, tiny JSON writer.
//
// Everything here is header-only and usable from host code (g++) and device code (nvcc):
// functions marked HD compile for both.  The same interpolation math is used by the serial
// CPU program and by the GPU kernels, so the two implementations agree by construction.
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <set>
#include <string>
#include <vector>

#if defined(__CUDACC__)
#define HD __host__ __device__
#else
#define HD
#endif

// Floating point type of the GPU path. Default double; build with -DTSNE_REAL_FLOAT for float.
// (Host-side bookkeeping — files, CSR build, CPU programs — is always double.)
#ifdef TSNE_REAL_FLOAT
typedef float real;
#else
typedef double real;
#endif

static const int MAX_ORDER = 6;  // largest supported number of interpolation nodes per box

// ---------------------------------------------------------------------------------------------
// FIt-SNE interpolation grid
// ---------------------------------------------------------------------------------------------
// The 2-D domain is cut into nbox x nbox square boxes of width bw. Inside each box there are
// p x p interpolation nodes at the interior equispaced positions c_m = (m + 0.5) / p (box
// coordinates, 0..1). The node spacing is h = bw / p and the node grid has M = nbox * p nodes
// per dimension. A point spreads its charges onto the p x p nodes of the box that contains it
// with tensor-product Lagrange weights, and reads potentials back with the same weights.
struct GridParams {
  int nbox;   // boxes per dimension
  int p;      // interpolation nodes per box per dimension (the "order")
  int M;      // nbox * p, nodes per dimension
  real bw;    // box width
  real h;     // node spacing = bw / p
  real ox, oy;  // lower-left corner of the domain
};

// Lagrange basis weights w[m], m = 0..p-1, for evaluation at box coordinate t in [0,1].
HD inline void lagrange_weights(int p, real t, real* w) {
  for (int m = 0; m < p; ++m) {
    real cm = (real(m) + real(0.5)) / real(p);
    real num = 1, den = 1;
    for (int l = 0; l < p; ++l) {
      if (l == m) continue;
      real cl = (real(l) + real(0.5)) / real(p);
      num *= (t - cl);
      den *= (cm - cl);
    }
    w[m] = num / den;
  }
}

// Box index b and in-box coordinate t of coordinate x. Points on the upper edge are clamped
// into the last box (t then equals 1).
HD inline void locate_box(real x, real origin, real bw, int nbox, int& b, real& t) {
  real u = (x - origin) / bw;
  int ib = (int)floor((double)u);
  if (ib < 0) ib = 0;
  if (ib > nbox - 1) ib = nbox - 1;
  b = ib;
  t = u - real(ib);
}

// Smallest integer >= n whose prime factors are all in {2,3,5,7}: FFT-friendly sizes.
inline int next_smooth(int n) {
  if (n < 1) n = 1;
  for (;; ++n) {
    int m = n;
    for (int f : {2, 3, 5, 7})
      while (m % f == 0) m /= f;
    if (m == 1) return n;
  }
}

// Grid-size quantisation (optional, --grid-quant r with r > 1; r <= 1 means off = the original behaviour).
// The adaptive grid needs `need` boxes per dimension, and `need` grows slightly almost every iteration while the embedding
// expands, which makes the GPU program rebuild its FFT plans (cuFFT plans, buffers, kernel spectrum) ~100 times. With
// quantisation the number of boxes is the smallest member >= need of the fixed geometric sequence
//     q_0 = next_smooth(min_boxes),  q_k = next_smooth(ceil(min_boxes * r^k)),
// so the plans change only when the embedding has grown by a factor ~r. The box width bw (node spacing) is unchanged; the grid
// only has a few more (empty) boxes around the embedding, so the interpolation error is of the same size. The result depends only on
// (need, min_boxes, r): every rank computes the same value from the same global bounding box. FIt-SNE does the same thing with a
// short list of allowed grid sizes.
inline int quantize_boxes(int need, int min_boxes, double r) {
  int q = next_smooth(std::max(1, min_boxes));
  double v = (double)std::max(1, min_boxes);
  while (q < need) {
    v *= r;
    int nq = next_smooth((int)std::ceil(v));
    q = nq > q ? nq : next_smooth(q + 1);   // strictly increasing, even for r very close to 1
  }
  return q;
}

// Build the grid for the current bounding box.
//  adaptive: box width stays `bw` (node spacing constant), number of boxes grows with the
//            embedding extent (at least min_boxes). The convolution kernel is then constant
//            and its FFT only has to be recomputed when the number of boxes changes.
//  fixed:    number of boxes is `fixed_boxes` for the whole run; box width follows the extent,
//            so the kernel FFT must be recomputed every iteration (and accuracy degrades as
//            the embedding grows).
inline GridParams make_grid(bool adaptive, int p, double bw, int min_boxes, int fixed_boxes,
                            double xmin, double xmax, double ymin, double ymax, double quant = 0.0) {
  GridParams g;
  double range = std::max(xmax - xmin, ymax - ymin);
  if (!(range > 1e-12)) range = 1e-12;
  g.p = p;
  // The domain is placed so that the centre of the bounding box falls in the MIDDLE of a box.
  // (If the centre sat on a box boundary, the collapsed initial embedding would straddle two
  //  boxes and be interpolated from the extrapolated edge of both; the error is large there.)
  // With c = nbox/2 boxes to the left of the centre box and nbox-c-1 to its right, the domain
  // covers the bounding box when (nbox-1) * bw >= range.
  if (adaptive) {
    const int need = std::max(min_boxes, (int)std::ceil(range * (1.0 + 1e-9) / bw) + 1);
    g.nbox = quant > 1.0 ? quantize_boxes(need, min_boxes, quant) : next_smooth(need);
    g.bw = (real)bw;
  } else {
    g.nbox = next_smooth(fixed_boxes);
    g.bw = (real)(range * (1.0 + 1e-6) / (g.nbox - 1));
  }
  g.M = g.nbox * p;
  g.h = g.bw / real(p);
  double cx = 0.5 * (xmin + xmax), cy = 0.5 * (ymin + ymax);
  double left = (g.nbox / 2 + 0.5) * (double)g.bw;
  g.ox = (real)(cx - left);
  g.oy = (real)(cy - left);
  return g;
}

// ---------------------------------------------------------------------------------------------
// Counter-based RNG: value depends only on (seed, index), never on how work is split over ranks.
// ---------------------------------------------------------------------------------------------
inline uint64_t splitmix64(uint64_t x) {
  x += 0x9E3779B97F4A7C15ULL;
  x = (x ^ (x >> 30)) * 0xBF58476D1CE4E5B9ULL;
  x = (x ^ (x >> 27)) * 0x94D049BB133111EBULL;
  return x ^ (x >> 31);
}
inline double uniform01(uint64_t seed, uint64_t idx, uint64_t salt) {
  uint64_t h = splitmix64(splitmix64(seed * 0x2545F4914F6CDD1DULL + salt) ^ (idx * 0xD6E8FEB86659FD93ULL));
  return ((h >> 11) + 0.5) * (1.0 / 9007199254740992.0);  // in (0,1)
}
inline double gaussian_at(uint64_t seed, uint64_t idx) {
  double u1 = uniform01(seed, idx, 1), u2 = uniform01(seed, idx, 2);
  return std::sqrt(-2.0 * std::log(u1)) * std::cos(6.283185307179586 * u2);
}

// ---------------------------------------------------------------------------------------------
// Misc host helpers
// ---------------------------------------------------------------------------------------------
inline double wall_time() {
  using clk = std::chrono::steady_clock;
  return std::chrono::duration<double>(clk::now().time_since_epoch()).count();
}

[[noreturn]] inline void die(const std::string& msg) {
  std::fprintf(stderr, "FATAL: %s\n", msg.c_str());
  std::exit(1);
}

inline FILE* xfopen(const std::string& path, const char* mode) {
  FILE* f = std::fopen(path.c_str(), mode);
  if (!f) die("cannot open file " + path);
  return f;
}

// "--key value" / "--flag" command line parser. Remembers which keys were read so that typos
// can be reported with unused().
class Args {
 public:
  Args(int argc, char** argv) {
    for (int i = 1; i < argc; ++i) {
      std::string a = argv[i];
      if (a.rfind("--", 0) != 0) die("unexpected argument: " + a);
      std::string key = a.substr(2);
      std::string val = "1";
      if (i + 1 < argc && std::string(argv[i + 1]).rfind("--", 0) != 0) val = argv[++i];
      kv_[key] = val;
    }
  }
  bool has(const std::string& k) const { return kv_.count(k) > 0; }
  std::string str(const std::string& k, const std::string& def) {
    used_.insert(k);
    auto it = kv_.find(k);
    return it == kv_.end() ? def : it->second;
  }
  long long integer(const std::string& k, long long def) {
    used_.insert(k);
    auto it = kv_.find(k);
    return it == kv_.end() ? def : std::atoll(it->second.c_str());
  }
  double num(const std::string& k, double def) {
    used_.insert(k);
    auto it = kv_.find(k);
    return it == kv_.end() ? def : std::atof(it->second.c_str());
  }
  bool flag(const std::string& k, bool def = false) {
    used_.insert(k);
    auto it = kv_.find(k);
    if (it == kv_.end()) return def;
    return !(it->second == "0" || it->second == "false" || it->second == "off");
  }
  std::vector<std::string> unused() const {
    std::vector<std::string> u;
    for (auto& p : kv_)
      if (!used_.count(p.first)) u.push_back(p.first);
    return u;
  }

 private:
  std::map<std::string, std::string> kv_;
  std::set<std::string> used_;
};

// Minimal flat JSON object writer (strings and numbers) for summary files.
class JsonOut {
 public:
  void add(const std::string& k, const std::string& v) { items_.push_back({k, "\"" + escape(v) + "\""}); }
  void add(const std::string& k, const char* v) { add(k, std::string(v)); }
  void add(const std::string& k, double v) {
    char b[64];
    std::snprintf(b, sizeof b, "%.9g", v);
    items_.push_back({k, b});
  }
  void add(const std::string& k, long long v) { items_.push_back({k, std::to_string(v)}); }
  void add(const std::string& k, int v) { add(k, (long long)v); }
  void write(const std::string& path) const {
    FILE* f = xfopen(path, "w");
    std::fprintf(f, "{\n");
    for (size_t i = 0; i < items_.size(); ++i)
      std::fprintf(f, "  \"%s\": %s%s\n", items_[i].first.c_str(), items_[i].second.c_str(),
                   i + 1 < items_.size() ? "," : "");
    std::fprintf(f, "}\n");
    std::fclose(f);
  }

 private:
  static std::string escape(const std::string& s) {
    std::string o;
    for (char c : s) {
      if (c == '"' || c == '\\') o += '\\';
      if (c == '\n') { o += "\\n"; continue; }
      o += c;
    }
    return o;
  }
  std::vector<std::pair<std::string, std::string>> items_;
};

// ====================================================================================================
// PART: cpu_fft
// ====================================================================================================
// Section FFT — small self-contained mixed-radix FFT (any size; fast for 2^a 3^b 5^c 7^d).
//
// Used by the serial CPU program (the speed-up baseline) and by the CPU "CUDA emulation"
// layer that lets the GPU program be tested on a laptop. No external FFT library needed.
#include <complex>
#include <vector>

typedef std::complex<double> cd;

class FFT1D {
 public:
  explicit FFT1D(int n = 1) { reset(n); }
  void reset(int n) {
    n_ = n;
    tw_.resize(n);
    for (int j = 0; j < n; ++j) tw_[j] = std::polar(1.0, -6.283185307179586476925 * j / n);
    factors_.clear();
    int m = n;
    for (int f = 2; f * f <= m;) {  // trial division, smallest factors first
      if (m % f == 0) {
        factors_.push_back(f);
        m /= f;
      } else {
        f += (f == 2 ? 1 : 2);
      }
    }
    if (m > 1) factors_.push_back(m);
  }
  int size() const { return n_; }
  // out[0..n) = DFT of in[0], in[istride], ... (forward e^{-i}, inverse e^{+i}, unnormalised).
  void transform(const cd* in, cd* out, bool inverse, int istride = 1) const {
    rec(out, in, n_, istride, 0, inverse);
  }

 private:
  void rec(cd* out, const cd* in, int n, int istride, int level, bool inv) const {
    if (n == 1) {
      out[0] = in[0];
      return;
    }
    const int p = factors_[level];
    const int m = n / p;
    for (int q = 0; q < p; ++q) rec(out + (size_t)q * m, in + (size_t)q * istride, m, istride * p, level + 1, inv);
    const int twstep = n_ / n;  // W_n^e = W_N^(e*twstep)
    const int pstep = n_ / p;   // W_p^e = W_N^(e*pstep)
    cd small[16];
    std::vector<cd> big;
    cd* tmp = small;
    if (p > 16) {
      big.resize(p);
      tmp = big.data();
    }
    for (int k = 0; k < m; ++k) {
      for (int q = 0; q < p; ++q) {
        cd w = tw_[((size_t)q * k * twstep) % n_];
        if (inv) w = std::conj(w);
        tmp[q] = out[(size_t)q * m + k] * w;
      }
      for (int r = 0; r < p; ++r) {
        cd s = 0;
        for (int q = 0; q < p; ++q) {
          cd w = tw_[((size_t)((q * r) % p)) * pstep];
          if (inv) w = std::conj(w);
          s += tmp[q] * w;
        }
        out[(size_t)r * m + k] = s;
      }
    }
  }
  int n_ = 1;
  std::vector<cd> tw_;
  std::vector<int> factors_;
};

// 2-D complex FFT on a row-major n0 x n1 array, in place.
class FFT2D {
 public:
  FFT2D(int n0 = 1, int n1 = 1) { reset(n0, n1); }
  void reset(int n0, int n1) {
    n0_ = n0;
    n1_ = n1;
    f0_.reset(n0);
    f1_.reset(n1);
    tmpin_.resize(std::max(n0, n1));
    tmpout_.resize(std::max(n0, n1));
  }
  void exec(cd* a, bool inverse) {
    for (int i = 0; i < n0_; ++i) {  // rows (contiguous)
      f1_.transform(a + (size_t)i * n1_, tmpout_.data(), inverse);
      std::copy(tmpout_.begin(), tmpout_.begin() + n1_, a + (size_t)i * n1_);
    }
    for (int j = 0; j < n1_; ++j) {  // columns (stride n1)
      f0_.transform(a + j, tmpout_.data(), inverse, n1_);
      for (int i = 0; i < n0_; ++i) a[(size_t)i * n1_ + j] = tmpout_[i];
    }
  }
  int n0() const { return n0_; }
  int n1() const { return n1_; }

 private:
  int n0_ = 1, n1_ = 1;
  FFT1D f0_, f1_;
  std::vector<cd> tmpin_, tmpout_;
};

// ====================================================================================================
// PART: dataset
// ====================================================================================================
// Section data files — binary file formats and the CPU-side preprocessing shared by every program.
//
// File formats (all little-endian, written by gen_data / prep_*, read by tsne_* / eval):
//   features   "*.feat.bin"  : int64 magic(0x54534e4546454131) | int64 N | int64 D | float x[N*D]
//   labels     "*.labels.bin": int64 magic(0x54534e454c424c31) | int64 N | int32 label[N]
//   dataset    "*.ds.bin"    : int64 magic(0x54534e4544533031) | int64 N | int64 k |
//                              int32 idx[N*k] | float d2[N*k] | float pc1[N] | int32 label[N]
//                              (kNN graph: neighbours of point i sorted by increasing squared
//                               distance, self excluded; pc1 = projection on first principal
//                               component, used to order/partition the points; label = -1 if none)
//   embedding  "embedding.bin": int64 magic(0x54534e45454d4231) | int64 N | double y[N*2]
//   gradient   "grad.bin"    : int64 magic(0x54534e4547524431) | int64 N | double Z |
//                              double attr[N*2] | double rep[N*2] | double grad[N*2]
// Point order in all files is the ORIGINAL order; programs permute internally.
#include <cstdint>
#include <string>
#include <vector>

struct Features {
  int64_t N = 0, D = 0;
  std::vector<float> x;  // N*D row-major
};

struct Dataset {
  int64_t N = 0;
  int k = 0;
  std::vector<int32_t> idx;    // N*k
  std::vector<float> d2;       // N*k squared distances (high-dimensional space)
  std::vector<float> pc1;      // N
  std::vector<int32_t> label;  // N, -1 if unknown
};

void write_features(const std::string& path, const Features& f);
void read_features(const std::string& path, Features& f);
void write_labels(const std::string& path, const std::vector<int32_t>& labels);
void read_labels(const std::string& path, std::vector<int32_t>& labels);
void write_dataset(const std::string& path, const Dataset& d);
void read_dataset(const std::string& path, Dataset& d);
void write_embedding(const std::string& path, int64_t N, const std::vector<double>& y);
void read_embedding(const std::string& path, int64_t N, std::vector<double>& y);
void write_grad(const std::string& path, int64_t N, double Z, const std::vector<double>& attr,
                const std::vector<double>& rep, const std::vector<double>& grad);
void read_grad(const std::string& path, int64_t& N, double& Z, std::vector<double>& attr,
               std::vector<double>& rep, std::vector<double>& grad);

// First principal component projection (power iteration on the covariance, OpenMP if enabled).
void compute_pc1(const Features& f, std::vector<float>& pc1, int iters = 40, uint64_t seed = 1);

// ====================================================================================================
// PART: problem
// ====================================================================================================
// Section problem setup — turning a kNN graph into the t-SNE input similarity matrix P and a rank layout.
//
// Pipeline (identical for the serial program and every MPI rank):
//   1. Order the points (pc1 | random | none): perm[new] = old, inv[old] = new.  The order does
//      NOT depend on the number of ranks, so every P sees the same "new" point numbering and the
//      same initial embedding.
//   2. Rank r owns the contiguous block of new ids [lo_r, hi_r) with lo_r = N*r/P.
//   3. Perplexity calibration gives the conditional P_{j|i}; it is symmetrised to
//      p_ij = (P_{j|i} + P_{i|j}) / (2N) and stored as a CSR matrix for the rows a rank owns.
//   4. The CSR matrix is split into a "local" part (columns owned by this rank) and a "remote"
//      part (columns owned by other ranks => ghost points).
#include <cstdint>
#include <string>
#include <vector>

struct Permutation {
  std::vector<int32_t> perm;  // perm[new] = old
  std::vector<int32_t> inv;   // inv[old] = new
};

// order: "pc1" (sort by first principal component), "random" (seeded shuffle), "none".
Permutation make_permutation(const Dataset& ds, const std::string& order, uint64_t seed);

// Contiguous block distribution of N points over P ranks.
inline int64_t block_lo(int64_t N, int P, int r) { return N * r / P; }
inline int owner_of(int64_t N, int P, int64_t id) {
  int r = (int)((id * P) / N);  // first guess, then fix up the rounding
  while (r > 0 && id < block_lo(N, P, r)) --r;
  while (r + 1 < P && id >= block_lo(N, P, r + 1)) ++r;
  return r;
}

// Conditional probabilities of one row by binary search on the Gaussian precision so that the
// entropy matches log(perplexity). d2: k squared distances, out: k probabilities summing to 1.
void calibrate_row(const float* d2, int k, double perplexity, double* out);

struct SymCSR {
  int64_t nrows = 0;
  std::vector<int64_t> rowptr;  // nrows + 1
  std::vector<int32_t> col;     // global new ids
  std::vector<double> val;
};

// Symmetrised P restricted to the rows [lo,hi) of the new numbering.
// cond[i*k + t] is P_{nbr|i} for new id i and its t-th neighbour (all N rows, new numbering).
SymCSR build_sym_rows(const Dataset& ds, const Permutation& pm, const std::vector<float>& cond,
                      int64_t lo, int64_t hi);

// Split rows into entries whose column lies in [lo,hi) and the rest (column order preserved).
void split_local_remote(const SymCSR& all, int64_t lo, int64_t hi, SymCSR& local, SymCSR& remote);

// Sorted unique column ids of a CSR matrix (the ghost points when applied to the remote part).
std::vector<int32_t> unique_columns(const SymCSR& m);

// ====================================================================================================
// PART: gpu runtime helpers (only when TSNE_GPU is defined)
// ====================================================================================================
#ifdef TSNE_GPU
// Section GPU backend — one include for "the GPU runtime": real CUDA + cuFFT, or the CPU emulation
// (-DTSNE_EMULATE, see cuda_emu.h). Also a few helpers shared by the GPU programs.
#include <cstdio>
#include <cstdlib>

#ifdef TSNE_EMULATE
#include "cuda_emu.h"  // single-thread CPU emulation of the CUDA subset (testing only)
#define LAUNCH(kernel, nblocks, nthreads, ...) EMU_LAUNCH(kernel, nblocks, nthreads, __VA_ARGS__)
#define LAUNCH_S(kernel, nblocks, nthreads, stream, ...) EMU_LAUNCH(kernel, nblocks, nthreads, __VA_ARGS__)
#else
#include <cuda_runtime.h>
#include <cufft.h>
// Kernel launch on the default stream. (All work of the program is on the default stream; the
// overlap studied in the project is between GPU kernels and CPU-side MPI, which needs no
// second stream.)
#define LAUNCH(kernel, nblocks, nthreads, ...) kernel<<<(nblocks), (nthreads)>>>(__VA_ARGS__)
// Launch on a given stream (used only by --overlap-near; stream 0 is the default stream).
#define LAUNCH_S(kernel, nblocks, nthreads, stream, ...) kernel<<<(nblocks), (nthreads), 0, (stream)>>>(__VA_ARGS__)
#endif

#ifdef TSNE_USE_MPI
#include <mpi.h>
#define TSNE_ABORT(code) MPI_Abort(MPI_COMM_WORLD, (code))
#else
#define TSNE_ABORT(code) std::exit(code)
#endif

#define CUDA_CHECK(call)                                                                      \
  do {                                                                                        \
    cudaError_t err_ = (call);                                                                \
    if (err_ != cudaSuccess) {                                                                \
      std::fprintf(stderr, "CUDA error '%s' at %s:%d\n", cudaGetErrorString(err_), __FILE__, \
                   __LINE__);                                                                 \
      TSNE_ABORT(1);                                                                          \
    }                                                                                         \
  } while (0)

#define CUFFT_CHECK(call)                                                                       \
  do {                                                                                          \
    cufftResult r_ = (call);                                                                    \
    if (r_ != CUFFT_SUCCESS) {                                                                  \
      std::fprintf(stderr, "cuFFT error %d at %s:%d\n", (int)r_, __FILE__, __LINE__);          \
      TSNE_ABORT(1);                                                                            \
    }                                                                                           \
  } while (0)

// cuFFT precision matches `real`.
#ifdef TSNE_REAL_FLOAT
typedef cufftReal fft_real;
typedef cufftComplex fft_cplx;
#define FFT_FWD_TYPE CUFFT_R2C
#define FFT_INV_TYPE CUFFT_C2R
inline cufftResult fft_forward(cufftHandle h, fft_real* in, fft_cplx* out) { return cufftExecR2C(h, in, out); }
inline cufftResult fft_inverse(cufftHandle h, fft_cplx* in, fft_real* out) { return cufftExecC2R(h, in, out); }
#define FFT_C2C_TYPE CUFFT_C2C   // batched 1-D complex transforms of the distributed FFT
inline cufftResult fft_c2c(cufftHandle h, fft_cplx* in, fft_cplx* out, int dir) { return cufftExecC2C(h, in, out, dir); }
#else
typedef cufftDoubleReal fft_real;
typedef cufftDoubleComplex fft_cplx;
#define FFT_FWD_TYPE CUFFT_D2Z
#define FFT_INV_TYPE CUFFT_Z2D
inline cufftResult fft_forward(cufftHandle h, fft_real* in, fft_cplx* out) { return cufftExecD2Z(h, in, out); }
inline cufftResult fft_inverse(cufftHandle h, fft_cplx* in, fft_real* out) { return cufftExecZ2D(h, in, out); }
#define FFT_C2C_TYPE CUFFT_Z2Z   // batched 1-D complex transforms of the distributed FFT
inline cufftResult fft_c2c(cufftHandle h, fft_cplx* in, fft_cplx* out, int dir) { return cufftExecZ2Z(h, in, out, dir); }
#endif

// Grow-only device array (re-allocates when a larger size is requested).
template <class T>
struct DevBuf {
  T* p = nullptr;
  size_t cap = 0;
  void reserve(size_t n) {
    if (n <= cap) return;
    release();
    CUDA_CHECK(cudaMalloc((void**)&p, n * sizeof(T)));
    cap = n;
  }
  void release() {
    if (p) CUDA_CHECK(cudaFree(p));
    p = nullptr;
    cap = 0;
  }
  void zero(size_t n) { CUDA_CHECK(cudaMemset(p, 0, n * sizeof(T))); }
  void upload(const T* h, size_t n) {
    reserve(n ? n : 1);  // never leave p null, even for empty arrays
    if (n) CUDA_CHECK(cudaMemcpy(p, h, n * sizeof(T), cudaMemcpyHostToDevice));
  }
  void download(T* h, size_t n) const {
    if (n) CUDA_CHECK(cudaMemcpy(h, p, n * sizeof(T), cudaMemcpyDeviceToHost));
  }
};

// Grow-only page-locked (pinned) host array.
template <class T>
struct PinnedBuf {
  T* p = nullptr;
  size_t cap = 0;
  void reserve(size_t n) {
    if (n <= cap) return;
    release();
    CUDA_CHECK(cudaMallocHost((void**)&p, n * sizeof(T)));
    cap = n;
  }
  void release() {
    if (p) CUDA_CHECK(cudaFreeHost(p));
    p = nullptr;
    cap = 0;
  }
};

inline int blocks_for(long long n, int block) { return (int)((n + block - 1) / block); }

#endif  // TSNE_GPU
