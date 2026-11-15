// tsne_gpu.cu — MPI + CUDA parallel t-SNE (FIt-SNE gradient), one GPU per MPI rank.
//
// Parallelisation (see ../README.md for how each experiment of the report is run):
//   * Points are ordered once (by first principal component, or randomly) and split into P
//     contiguous blocks; rank r owns block [lo,hi). Every rank keeps a full-size coordinate
//     array indexed by global id; only the owned block is up to date, the rest holds the
//     ghost / gathered coordinates received each iteration.
//   * Study A  --exchange allgather|ghost   --comm blocking|nonblocking
//       how the coordinates of neighbours that live on other ranks reach this rank.
//   * Study B  --grid-comm blocking|nonblocking   (+ --progress wait|sync|poll)
//       every rank holds the full interpolation grid; the partial grids are summed with
//       Allreduce / Iallreduce, then every rank repeats the FFT.
//   * --fft distributed   (default: replicated)  distributed FFT, the GPU counterpart of the CPU program's
//       --fft distributed: the partial grids are summed with Reduce_scatter into blocks of rows, every rank
//       runs batched 1-D cuFFT transforms on its rows, two MPI_Alltoall transposes bring the columns to the
//       ranks, and an Allgatherv returns the potentials to all ranks. No rank ever holds the whole FFT.
//   * Study C  --probe 1   times the scatter kernel against variants without atomics.
//
// One iteration (all ranks, in this order):
//   1 grid parameters from the bounding box   2 scatter local points -> grid (atomicAdd)
//   3 start/perform grid sum                  4 coordinate exchange + near-field (attractive) force
//   5 finish grid sum                         6 FFT convolution on the summed grid
//   7 grid -> points (gather), Z              8 gradient, momentum/gains update
//   9 bounding box + centring (small Allreduces)
//
// Build: see Makefile (nvcc + MPI).
#include <mpi.h>
#if defined(OPEN_MPI) && defined(__has_include)
#if __has_include(<mpi-ext.h>)
#include <mpi-ext.h>
#endif
#endif
#define TSNE_USE_MPI
#include <array>
#include <cstdio>
#include <numeric>
#define TSNE_GPU
#include "tsne_common.h"


#ifdef TSNE_REAL_FLOAT
#define MPI_REAL_T MPI_FLOAT
#else
#define MPI_REAL_T MPI_DOUBLE
#endif

// =============================================================================================
// Stage timers
// =============================================================================================
// GPU stages are timed with CUDA events (read at the end of the iteration, which is always a
// natural synchronisation point because of the small Allreduces), CPU stages with MPI_Wtime.
enum Stage {
  ST_ITER = 0,      // wall time of the whole iteration
  ST_STATS,         // local min/max/sum reduction of the coordinates (incl. D2H of 6 numbers)
  ST_SMALL_ALLRED,  // all tiny Allreduces (bounding box, mean, Z)
  ST_SCATTER,       // points -> grid (GPU)                                          [study C]
  ST_GRID_D2H,      // grid GPU -> pinned host (host transport only)
  ST_GRID_COMM,     // grid Allreduce (blocking) or posting the Iallreduce          [study B]
  ST_GRID_WAIT,     // waiting for the Iallreduce
  ST_GRID_H2D,      // summed grid host -> GPU
  ST_EXCH_PACK,     // pack ghost coordinates (GPU)
  ST_EXCH_COMM,     // coordinate exchange: D2H + blocking calls, or posting          [study A]
  ST_EXCH_WAIT,     // waiting for the coordinate exchange
  ST_EXCH_UNPACK,   // host -> GPU copy of received coordinates + unpack
  ST_NEAR_LOCAL,    // attractive force from neighbours owned by this rank (GPU)
  ST_NEAR_REMOTE,   // attractive force from ghost neighbours (GPU)
  ST_FFT,           // pad + forward FFT + multiply + inverse FFT + unpad (GPU)
  ST_GATHER,        // grid -> points, repulsive force, Z terms (GPU)
  ST_Z,             // local reduction of Z terms
  ST_UPDATE,        // gradient, gains, momentum, position update (GPU)
  ST_PLAN,          // FFT plans + buffers + kernel spectrum rebuilt because the grid size changed
  ST_KSPEC,         // kernel spectrum recomputed because only the node spacing changed (fixed-grid mode: every iteration)
  ST_KL,            // KL divergence evaluation (reporting only)
  ST_PROBE_PLAIN,   // study C probe: scatter with plain stores (no atomics)
  ST_PROBE_DISJ,    // study C probe: scatter with conflict-free addresses
  ST_GPU_WAIT,      // CPU idle time waiting for GPU kernels queued earlier (explicit sync before a copy / MPI call)
  ST_ZERO,          // zeroing the charge grids (GPU)
  // stages of the distributed FFT (--fft distributed); ST_FFT then holds the row transforms
  ST_FFT2,          // distributed FFT: unpack, column transforms, multiplication by the kernel spectrum (GPU)
  ST_FFT3,          // distributed FFT: unpack, inverse row transforms, store of the potential rows (GPU)
  ST_PERM_IN,       // distributed FFT: charge grid -> row-block layout (GPU)
  ST_PERM_OUT,      // distributed FFT: potential grid -> layout of the gather kernel (GPU)
  ST_FFT_TRANSPOSE, // distributed FFT: the two MPI_Alltoall transposes incl. host copies
  ST_POT_ALLGATHER, // distributed FFT: Allgatherv of the potential rows incl. host copies
  NSTAGE
};
static const char* STAGE_NAME[NSTAGE] = {"iter", "stats", "small_allreduce", "scatter", "grid_d2h", "grid_comm",
                                         "grid_wait", "grid_h2d", "exch_pack", "exch_comm", "exch_wait",
                                         "exch_unpack", "near_local", "near_remote", "fft", "gather", "z_reduce",
                                         "update", "plan", "kernel_spec", "kl", "probe_plain", "probe_disjoint", "gpu_wait", "grid_zero",
                                         "fft_cols", "fft_rows_inv", "fft_perm_in", "fft_perm_out", "fft_transpose",
                                         "pot_allgather"};
static const bool STAGE_IS_GPU[NSTAGE] = {false, false, false, true,  false, false, false, false, true, false, false,
                                          false, true,  true,  true,  true,  false, true,  false, true,  false, true, true, false, true,
                                          true, true, true, true, false, false};

struct Timers {
  bool on = true;
  cudaEvent_t ev[NSTAGE][2];
  bool used[NSTAGE];
  double acc[NSTAGE];
  std::vector<std::array<double, NSTAGE>> hist;
  void init(bool enabled) {
    on = enabled;
    for (int s = 0; s < NSTAGE; ++s) {
      used[s] = false;
      acc[s] = 0;
      if (STAGE_IS_GPU[s]) {
        CUDA_CHECK(cudaEventCreate(&ev[s][0]));
        CUDA_CHECK(cudaEventCreate(&ev[s][1]));
      }
    }
  }
  void gb(int s, cudaStream_t st = 0) { if (on) CUDA_CHECK(cudaEventRecord(ev[s][0], st)); }
  void ge(int s, cudaStream_t st = 0) { if (on) { CUDA_CHECK(cudaEventRecord(ev[s][1], st)); used[s] = true; } }
  void add(int s, double sec) { if (on) acc[s] += sec; }
  // Called at the end of every iteration, when all GPU work of the iteration has finished.
  void end_iter(double iter_wall) {
    for (int s = 0; s < NSTAGE; ++s)
      if (STAGE_IS_GPU[s] && used[s]) {
        CUDA_CHECK(cudaEventSynchronize(ev[s][1]));
        float ms = 0;
        CUDA_CHECK(cudaEventElapsedTime(&ms, ev[s][0], ev[s][1]));
        acc[s] += ms * 1e-3;
        used[s] = false;
      }
    acc[ST_ITER] = iter_wall;
    std::array<double, NSTAGE> a;
    for (int s = 0; s < NSTAGE; ++s) { a[s] = acc[s]; acc[s] = 0; }
    hist.push_back(a);
  }
};
static Timers T;

// RAII wall-clock scope for CPU stages.
struct CpuScope {
  int s;
  double t0;
  explicit CpuScope(int stage) : s(stage), t0(MPI_Wtime()) {}
  ~CpuScope() { T.add(s, MPI_Wtime() - t0); }
};

// Wait for all GPU work queued so far, and book the waiting time under its own stage.
// Called right BEFORE a CPU-timed scope that contains a synchronous cudaMemcpy or hands device
// memory to MPI: the copy would wait for the queued kernels anyway (so the critical path does not
// change), but without this the copy's stage would be charged with the kernels' remaining run time.
// For --transport device it is also required for correctness: MPI must not read a buffer that a
// kernel is still writing.
static void gpu_drain() {
  CpuScope s(ST_GPU_WAIT);
  CUDA_CHECK(cudaDeviceSynchronize());
}

// =============================================================================================
// Configuration
// =============================================================================================
struct Config {
  std::string data, out = "out/run", order = "pc1", coords, mode = "run";
  std::string exchange = "ghost";       // allgather | ghost
  std::string comm = "blocking";        // blocking | nonblocking   (coordinate exchange)
  std::string grid_comm = "blocking";   // blocking | nonblocking   (grid sum)
  std::string transport = "host";       // host (stage through pinned CPU memory) | device (CUDA-aware MPI)
  std::string progress = "wait";        // wait | sync | poll       (how the CPU waits while the GPU computes)
  std::string fft = "replicated";       // replicated (every rank transforms the whole grid) | distributed
  bool ssend = false;                   // use MPI_Ssend instead of MPI_Send in the blocking ghost exchange
  bool overlap_near = false;            // EXPERIMENTAL, default off, never run on a real GPU and used for no number of the report: run the attraction kernels on a second CUDA stream, so that they overlap with the FFT
  int iters = 1000, exag_iters = 250, mom_switch = 250;
  double exag = 12, perplexity = 30, lr = -1;
  int p = 3, min_boxes = 50, fixed_boxes = 128;
  double bw = 0.5;
  double grid_quant = 0;                // >1: round the number of boxes up to a geometric sequence (fewer FFT-plan rebuilds); 0 = off
  bool adaptive = true;
  int block = 256;
  uint64_t seed = 42;
  int report_every = 50, warmup = 10;
  bool stage_timing = true, probe = false, force_comm = false;
};
static Config cfg;

// =============================================================================================
// Kernels (one thread per point unless stated otherwise)
// =============================================================================================
// Points -> grid. VARIANT 0: global atomicAdd (the real kernel, "C1").
//                 VARIANT 1: same addresses, plain read-modify-write (probe "C2": no atomics).
//                 VARIANT 2: every thread writes to its own scratch slots (probe "C2'": no sharing).
// Variants 1 and 2 give wrong sums and are only used as timing probes (--probe 1).
template <int VARIANT>
__global__ void k_scatter(const real* __restrict__ Y, int lo, int nloc, GridParams gp, real* grid, real* scratch) {
  long long i = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  if (i >= nloc) return;
  const int p = gp.p;
  const long long M = gp.M, M2 = M * M;
  real x = Y[2 * (lo + i)], y = Y[2 * (lo + i) + 1];
  int bx, by;
  real tx, ty;
  locate_box(x, gp.ox, gp.bw, gp.nbox, bx, tx);
  locate_box(y, gp.oy, gp.bw, gp.nbox, by, ty);
  real wx[MAX_ORDER], wy[MAX_ORDER];
  lagrange_weights(p, tx, wx);
  lagrange_weights(p, ty, wy);
  const real c1 = x, c2 = y, c3 = x * x + y * y;
  for (int a = 0; a < p; ++a)
    for (int b = 0; b < p; ++b) {
      const real w = wx[a] * wy[b];
      if (VARIANT == 0) {
        const long long g = (long long)(bx * p + a) * M + (by * p + b);
        atomicAdd(&grid[g], w);
        atomicAdd(&grid[M2 + g], w * c1);
        atomicAdd(&grid[2 * M2 + g], w * c2);
        atomicAdd(&grid[3 * M2 + g], w * c3);
      } else if (VARIANT == 1) {
        const long long g = (long long)(bx * p + a) * M + (by * p + b);
        grid[g] += w;
        grid[M2 + g] += w * c1;
        grid[2 * M2 + g] += w * c2;
        grid[3 * M2 + g] += w * c3;
      } else {
        real* s = scratch + ((long long)i * p * p + a * p + b) * 4;
        s[0] = w;
        s[1] = w * c1;
        s[2] = w * c2;
        s[3] = w * c3;
      }
    }
}

// Real grid (4 charge grids, M x M) -> zero padded (2M x 2M) arrays for the FFT.
__global__ void k_pad(const real* __restrict__ grid, fft_real* pad, int M) {
  long long e = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  const long long n = 2LL * M, n2 = n * n;
  if (e >= 4 * n2) return;
  long long term = e / n2, r = e % n2;
  long long a = r / n, b = r % n;
  pad[e] = (a < M && b < M) ? (fft_real)grid[term * M * M + a * M + b] : (fft_real)0;
}

// Circulant embedding of the kernel 1/(1+r^2)^2 on the (2M x 2M) periodic grid.
__global__ void k_fill_kernel(fft_real* ker, int M, real h) {
  long long e = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  const long long n = 2LL * M;
  if (e >= n * n) return;
  long long a = e / n, b = e % n;
  long long da = a <= M ? a : n - a, db = b <= M ? b : n - b;
  real r2 = h * h * (real)(da * da + db * db);
  real q = (real)1 / ((real)1 + r2);
  ker[e] = (fft_real)(q * q);
}

// spec[term][i] *= khat[i] * scale   (complex multiplication; 4 terms share the kernel)
__global__ void k_mul_spec(fft_cplx* spec, const fft_cplx* __restrict__ khat, long long nspec, real scale) {
  long long e = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  if (e >= 4 * nspec) return;
  const fft_cplx k = khat[e % nspec];
  const fft_cplx s = spec[e];
  spec[e].x = (fft_real)(((real)s.x * (real)k.x - (real)s.y * (real)k.y) * scale);
  spec[e].y = (fft_real)(((real)s.x * (real)k.y + (real)s.y * (real)k.x) * scale);
}

// (2M x 2M) FFT output -> potentials on the M x M grid (valid part of the linear convolution).
__global__ void k_unpad(const fft_real* __restrict__ out, real* pot, int M) {
  long long e = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  const long long M2 = (long long)M * M, n = 2LL * M;
  if (e >= 4 * M2) return;
  long long term = e / M2, r = e % M2;
  long long a = r / M, b = r % M;
  pot[e] = (real)out[term * n * n + a * n + b];
}

// ---------------------------------------------------------------------------------------------
// Distributed FFT kernels (--fft distributed). Row-block layout of a grid: [a][term][b] (row a of the
// M x M node grid, 4 charge terms, column b), so that a block of rows is contiguous in memory, which
// is what MPI_Reduce_scatter / MPI_Allgatherv need. The FFT length n >= 2M is a multiple of P; rank r
// owns the rows [r*R, (r+1)*R) of the n x n circulant embedding, R = n/P, and of those only the first
// rowsM = max(0, min((r+1)R, M) - rR) hold charge. "Block buffers" for the MPI_Alltoall transposes hold
// P blocks of NB arrays of R x R complex numbers, ordered [q][m][i][jj].
// ---------------------------------------------------------------------------------------------
__global__ void k_perm_in(const real* __restrict__ grid, real* gridP, int M) {  // [term][a][b] -> [a][term][b]
  long long e = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  const long long M2 = (long long)M * M;
  if (e >= 4 * M2) return;
  const long long t = e / M2, r = e % M2, a = r / M, b = r % M;
  gridP[(a * 4 + t) * M + b] = grid[e];
}
__global__ void k_perm_out(const real* __restrict__ potP, real* grid, int M) {  // [a][term][b] -> [term][a][b]
  long long e = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  const long long M2 = (long long)M * M;
  if (e >= 4 * M2) return;
  const long long t = e / M2, r = e % M2, a = r / M, b = r % M;
  grid[e] = potP[(a * 4 + t) * M + b];
}
// Summed charge rows (rowsM x 4 x M) -> two complex arrays of R x n: (term0 + i term1), (term2 + i term3), zero padded.
__global__ void k_dist_load(const real* __restrict__ blk, fft_cplx* rows, int R, int n, int rowsM, int M) {
  long long e = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  const long long Rn = (long long)R * n;
  if (e >= 2 * Rn) return;
  const long long m = e / Rn, r = e % Rn, i = r / n, b = r % n;
  fft_cplx v;
  v.x = (fft_real)0;
  v.y = (fft_real)0;
  if (i < rowsM && b < M) {
    v.x = (fft_real)blk[(i * 4 + 2 * m) * M + b];
    v.y = (fft_real)blk[(i * 4 + 2 * m + 1) * M + b];
  }
  rows[e] = v;
}
// Inverse transform result -> potential rows (rowsM x 4 x M), real and imaginary parts are the terms.
__global__ void k_dist_store(const fft_cplx* __restrict__ rows, real* blk, int R, int n, int rowsM, int M) {
  long long e = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  if (e >= (long long)rowsM * 4 * M) return;
  const long long i = e / (4LL * M), rem = e % (4LL * M), t = rem / M, b = rem % M, m = t / 2;
  const fft_cplx v = rows[(m * R + i) * n + b];
  blk[e] = (real)((t & 1) ? v.y : v.x);
}
// The four block-buffer kernels: element e = ((q*NB + m)*R + i)*R + jj of the block buffer.
__global__ void k_blk_pack_rows(const fft_cplx* __restrict__ rows, fft_cplx* buf, int R, int n, int NB) {
  long long e = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  if (e >= (long long)NB * R * n) return;
  const long long RR = (long long)R * R, q = e / (NB * RR), rem = e % (NB * RR), m = rem / RR, r2 = rem % RR, i = r2 / R, jj = r2 % R;
  buf[e] = rows[(m * R + i) * n + q * R + jj];
}
__global__ void k_blk_unpack_cols(const fft_cplx* __restrict__ buf, fft_cplx* cols, int R, int n, int NB) {
  long long e = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  if (e >= (long long)NB * R * n) return;
  const long long RR = (long long)R * R, q = e / (NB * RR), rem = e % (NB * RR), m = rem / RR, r2 = rem % RR, i = r2 / R, jj = r2 % R;
  cols[(m * R + jj) * n + q * R + i] = buf[e];
}
__global__ void k_blk_pack_cols(const fft_cplx* __restrict__ cols, fft_cplx* buf, int R, int n, int NB) {
  long long e = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  if (e >= (long long)NB * R * n) return;
  const long long RR = (long long)R * R, q = e / (NB * RR), rem = e % (NB * RR), m = rem / RR, r2 = rem % RR, i = r2 / R, jj = r2 % R;
  buf[e] = cols[(m * R + jj) * n + q * R + i];
}
__global__ void k_blk_unpack_rows(const fft_cplx* __restrict__ buf, fft_cplx* rows, int R, int n, int NB) {
  long long e = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  if (e >= (long long)NB * R * n) return;
  const long long RR = (long long)R * R, q = e / (NB * RR), rem = e % (NB * RR), m = rem / RR, r2 = rem % RR, i = r2 / R, jj = r2 % R;
  rows[(m * R + i) * n + q * R + jj] = buf[e];
}
// Columns (stored as length-n vectors, R of them per array) *= khat * scale; khat is real (the kernel is symmetric).
__global__ void k_dist_mul(fft_cplx* cols, const fft_real* __restrict__ khat, int R, int n, real scale) {
  long long e = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  const long long Rn = (long long)R * n;
  if (e >= 2 * Rn) return;
  const real k = (real)khat[e % Rn] * scale;
  cols[e].x = (fft_real)((real)cols[e].x * k);
  cols[e].y = (fft_real)((real)cols[e].y * k);
}
// Rows [r0, r0+R) of the n x n circulant embedding of the kernel 1/(1+r^2)^2 (complex array, imaginary part 0).
__global__ void k_fill_kernel_rows(fft_cplx* ker, int r0, int R, int n, real h) {
  long long e = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  if (e >= (long long)R * n) return;
  const long long i = e / n, b = e % n, a = r0 + i;
  const long long da = a <= n - a ? a : n - a, db = b <= n - b ? b : n - b;
  const real r2 = h * h * (real)(da * da + db * db);
  const real q = (real)1 / ((real)1 + r2);
  ker[e].x = (fft_real)(q * q);
  ker[e].y = (fft_real)0;
}
__global__ void k_take_real(fft_real* out, const fft_cplx* __restrict__ in, long long cnt) {
  long long e = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  if (e >= cnt) return;
  out[e] = in[e].x;
}

// Grid -> points. Writes the unnormalised repulsive force and the per-point Z term.
//   rep_i = y_i * phi0 - (phi1, phi2)
//   S_i   = sum_j q~_ij = (1+|y_i|^2) phi0 - 2 (x_i phi1 + y_i phi2) + phi3     (j = i included)
__global__ void k_gather(const real* __restrict__ Y, int lo, int nloc, GridParams gp, const real* __restrict__ pot,
                         real* Frep, double* S) {
  long long i = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  if (i >= nloc) return;
  const int p = gp.p;
  const long long M = gp.M, M2 = M * M;
  real x = Y[2 * (lo + i)], y = Y[2 * (lo + i) + 1];
  int bx, by;
  real tx, ty;
  locate_box(x, gp.ox, gp.bw, gp.nbox, bx, tx);
  locate_box(y, gp.oy, gp.bw, gp.nbox, by, ty);
  real wx[MAX_ORDER], wy[MAX_ORDER];
  lagrange_weights(p, tx, wx);
  lagrange_weights(p, ty, wy);
  real phi0 = 0, phi1 = 0, phi2 = 0, phi3 = 0;
  for (int a = 0; a < p; ++a)
    for (int b = 0; b < p; ++b) {
      const long long g = (long long)(bx * p + a) * M + (by * p + b);
      const real w = wx[a] * wy[b];
      phi0 += w * pot[g];
      phi1 += w * pot[M2 + g];
      phi2 += w * pot[2 * M2 + g];
      phi3 += w * pot[3 * M2 + g];
    }
  Frep[2 * i] = x * phi0 - phi1;
  Frep[2 * i + 1] = y * phi0 - phi2;
  S[i] = (double)(((real)1 + x * x + y * y) * phi0 - (real)2 * (x * phi1 + y * phi2) + phi3);
}

// Attractive force sum_j p_ij q~_ij (y_i - y_j) over one CSR matrix (local or remote columns).
// ACC=0 writes, ACC=1 adds to the result of the first call. One thread per row.
template <int ACC>
__global__ void k_near(const long long* __restrict__ rowptr, const int* __restrict__ col, const real* __restrict__ val,
                       const real* __restrict__ Y, int lo, int nloc, real* F) {
  long long i = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  if (i >= nloc) return;
  const real xi = Y[2 * (lo + i)], yi = Y[2 * (lo + i) + 1];
  real ax = 0, ay = 0;
  for (long long e = rowptr[i]; e < rowptr[i + 1]; ++e) {
    const int j = col[e];
    const real dx = xi - Y[2 * (long long)j], dy = yi - Y[2 * (long long)j + 1];
    const real w = val[e] / ((real)1 + dx * dx + dy * dy);
    ax += w * dx;
    ay += w * dy;
  }
  if (ACC) { F[2 * i] += ax; F[2 * i + 1] += ay; }
  else { F[2 * i] = ax; F[2 * i + 1] = ay; }
}

// sum_j p_ij (log p_ij + log(1+d_ij^2)) per row (part of KL); ACC as above.
template <int ACC>
__global__ void k_kl_rows(const long long* __restrict__ rowptr, const int* __restrict__ col, const real* __restrict__ val,
                          const real* __restrict__ Y, int lo, int nloc, double* out) {
  long long i = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  if (i >= nloc) return;
  const double xi = Y[2 * (lo + i)], yi = Y[2 * (lo + i) + 1];
  double s = 0;
  for (long long e = rowptr[i]; e < rowptr[i + 1]; ++e) {
    const int j = col[e];
    const double dx = xi - Y[2 * (long long)j], dy = yi - Y[2 * (long long)j + 1];
    const double pij = val[e];
    if (pij > 0) s += pij * (log(pij) + log(1.0 + dx * dx + dy * dy));
  }
  if (ACC) out[i] += s; else out[i] = s;
}

// Gradient 4 (exag * attr - rep / Z), gains (delta-bar-delta) and momentum update.
__global__ void k_update(real* Y, real* upd, real* gain, const real* __restrict__ Fattr, const real* __restrict__ Frep,
                         int lo, int nloc, real exag, real invZ, real lr, real mom) {
  long long i = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  if (i >= nloc) return;
  for (int c = 0; c < 2; ++c) {
    const long long e = 2 * i + c;
    const real g = (real)4 * (exag * Fattr[e] - invZ * Frep[e]);
    real gn = gain[e];
    gn = ((g > 0) != (upd[e] > 0)) ? gn + (real)0.2 : gn * (real)0.8;
    if (gn < (real)0.01) gn = (real)0.01;
    gain[e] = gn;
    const real u = mom * upd[e] - lr * gn * g;
    upd[e] = u;
    Y[2 * (lo + i) + c] += u;
  }
}

__global__ void k_center(real* Y, int lo, int nloc, real mx, real my) {
  long long i = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  if (i >= nloc) return;
  Y[2 * (lo + i)] -= mx;
  Y[2 * (lo + i) + 1] -= my;
}

__global__ void k_pack(const real* __restrict__ Y, const int* __restrict__ ids, int n, real* buf) {
  long long j = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  if (j >= n) return;
  buf[2 * j] = Y[2 * (long long)ids[j]];
  buf[2 * j + 1] = Y[2 * (long long)ids[j] + 1];
}

__global__ void k_unpack(const real* __restrict__ buf, const int* __restrict__ ids, int n, real* Y) {
  long long j = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  if (j >= n) return;
  Y[2 * (long long)ids[j]] = buf[2 * j];
  Y[2 * (long long)ids[j] + 1] = buf[2 * j + 1];
}

// ---------------------------------------------------------------------------------------------
// Reductions. On a real GPU: block reduction in shared memory, final combination on the host
// (only 256 partial results are copied). In the CPU emulation: plain loops.
// ---------------------------------------------------------------------------------------------
#ifndef TSNE_EMULATE
static DevBuf<double> g_part;
#endif

#ifdef TSNE_EMULATE
static void reduce_stats(const real* Y, int n, double out[6]) {
  double x0 = 1e300, x1 = -1e300, y0 = 1e300, y1 = -1e300, sx = 0, sy = 0;
  for (int i = 0; i < n; ++i) {
    double x = Y[2 * i], y = Y[2 * i + 1];
    x0 = std::min(x0, x); x1 = std::max(x1, x); y0 = std::min(y0, y); y1 = std::max(y1, y);
    sx += x; sy += y;
  }
  out[0] = x0; out[1] = x1; out[2] = y0; out[3] = y1; out[4] = sx; out[5] = sy;
}
static double reduce_sum(const double* d, int n) {
  double s = 0;
  for (int i = 0; i < n; ++i) s += d[i];
  return s;
}
#else
static const int RED_THREADS = 256, RED_BLOCKS = 256;
__global__ void k_stats(const real* __restrict__ Y, int n, double* part) {
  __shared__ double sh[6][RED_THREADS];
  const int tid = threadIdx.x;
  double x0 = 1e300, x1 = -1e300, y0 = 1e300, y1 = -1e300, sx = 0, sy = 0;
  for (long long i = (long long)blockIdx.x * blockDim.x + tid; i < n; i += (long long)gridDim.x * blockDim.x) {
    double x = Y[2 * i], y = Y[2 * i + 1];
    x0 = fmin(x0, x); x1 = fmax(x1, x); y0 = fmin(y0, y); y1 = fmax(y1, y);
    sx += x; sy += y;
  }
  sh[0][tid] = x0; sh[1][tid] = x1; sh[2][tid] = y0; sh[3][tid] = y1; sh[4][tid] = sx; sh[5][tid] = sy;
  __syncthreads();
  for (int off = RED_THREADS / 2; off > 0; off >>= 1) {
    if (tid < off) {
      sh[0][tid] = fmin(sh[0][tid], sh[0][tid + off]);
      sh[1][tid] = fmax(sh[1][tid], sh[1][tid + off]);
      sh[2][tid] = fmin(sh[2][tid], sh[2][tid + off]);
      sh[3][tid] = fmax(sh[3][tid], sh[3][tid + off]);
      sh[4][tid] += sh[4][tid + off];
      sh[5][tid] += sh[5][tid + off];
    }
    __syncthreads();
  }
  if (tid == 0)
    for (int c = 0; c < 6; ++c) part[blockIdx.x * 6 + c] = sh[c][0];
}
__global__ void k_sum(const double* __restrict__ in, int n, double* part) {
  __shared__ double sh[RED_THREADS];
  const int tid = threadIdx.x;
  double s = 0;
  for (long long i = (long long)blockIdx.x * blockDim.x + tid; i < n; i += (long long)gridDim.x * blockDim.x) s += in[i];
  sh[tid] = s;
  __syncthreads();
  for (int off = RED_THREADS / 2; off > 0; off >>= 1) {
    if (tid < off) sh[tid] += sh[tid + off];
    __syncthreads();
  }
  if (tid == 0) part[blockIdx.x] = sh[0];
}
static void reduce_stats(const real* Y, int n, double out[6]) {
  g_part.reserve(6 * RED_BLOCKS);
  LAUNCH(k_stats, RED_BLOCKS, RED_THREADS, Y, n, g_part.p);
  double h[6 * RED_BLOCKS];
  g_part.download(h, 6 * RED_BLOCKS);  // synchronous: also waits for all earlier kernels
  out[0] = 1e300; out[1] = -1e300; out[2] = 1e300; out[3] = -1e300; out[4] = 0; out[5] = 0;
  for (int b = 0; b < RED_BLOCKS; ++b) {
    out[0] = std::min(out[0], h[6 * b + 0]); out[1] = std::max(out[1], h[6 * b + 1]);
    out[2] = std::min(out[2], h[6 * b + 2]); out[3] = std::max(out[3], h[6 * b + 3]);
    out[4] += h[6 * b + 4]; out[5] += h[6 * b + 5];
  }
}
static double reduce_sum(const double* d, int n) {
  g_part.reserve(6 * RED_BLOCKS);
  LAUNCH(k_sum, RED_BLOCKS, RED_THREADS, d, n, g_part.p);
  double h[RED_BLOCKS];
  g_part.download(h, RED_BLOCKS);
  double s = 0;
  for (int b = 0; b < RED_BLOCKS; ++b) s += h[b];
  return s;
}
#endif

// =============================================================================================
// Global state of the run
// =============================================================================================
struct Csr {  // device copy of one CSR matrix
  DevBuf<long long> rowptr;
  DevBuf<int> col;
  DevBuf<real> val;
  long long nnz = 0;
};
struct FftState {
  int M = 0;
  real h = -1;
  bool has = false;
  cufftHandle fwd4, inv4, fwd1;
  DevBuf<real> grid;  // 4 charge grids; after the FFT it holds the 4 potential grids
  DevBuf<fft_real> pad, ker;
  DevBuf<fft_cplx> spec, khat;
  PinnedBuf<real> hgrid;  // host staging for the grid sum (host transport)
  // ---- distributed FFT (--fft distributed) ----
  int n = 0, R = 0, r0 = 0, rowsM = 0;       // FFT length, rows per rank, first row, rows that hold charge
  cufftHandle p2, p1;                         // batched 1-D complex plans: 2R and R transforms of length n
  std::vector<int> rs_cnt, rs_dsp;            // per-rank counts / displacements (reals) of the row blocks of a grid
  DevBuf<real> gridP, blk, potblk, potP;      // permuted charge grid, summed rows, potential rows, all potential rows
  DevBuf<fft_cplx> rowsAB, colsAB, sbuf, rbuf;
  DevBuf<fft_real> khat_blk;                  // real kernel spectrum, R columns of length n (not scaled)
  PinnedBuf<real> h_gridP, h_blk, h_potblk, h_potP;
  PinnedBuf<fft_cplx> h_sbuf, h_rbuf;
};

static int rank_ = 0, P_ = 1;
static MPI_Comm comm_ = MPI_COMM_WORLD;
static int64_t N_ = 0;
static int lo_ = 0, hi_ = 0, nloc_ = 0;
static bool comm_on_ = false;  // false => P == 1 and communication skipped
static Csr csr_loc_, csr_rem_;
static FftState fs_;
static DevBuf<real> d_Y, d_upd, d_gain, d_Fattr, d_Frep;
static DevBuf<double> d_S;
static DevBuf<real> d_probe_grid, d_probe_scratch;

// ghost exchange plan
static std::vector<int> send_cnt_, send_dsp_, recv_cnt_, recv_dsp_;
static std::vector<int32_t> send_ids_, recv_ids_;
static int send_total_ = 0, recv_total_ = 0;
static DevBuf<int> d_send_ids, d_recv_ids;
static DevBuf<real> d_sendbuf, d_recvbuf;
static PinnedBuf<real> h_sendbuf, h_recvbuf, h_Y;
static std::vector<int> ag_cnt_, ag_dsp_;  // allgather counts / displacements in reals
static std::vector<MPI_Request> exch_reqs_;
static MPI_Request grid_req_ = MPI_REQUEST_NULL;

struct Bbox { double x0 = -1e-3, x1 = 1e-3, y0 = -1e-3, y1 = 1e-3; };
static Bbox bb_;
static cudaStream_t s_near_ = 0;                 // second stream of --overlap-near
static cudaEvent_t ev_y_, ev_near_;              // Y is ready for the attraction / the attraction has finished
static double bytes_grid_ = 0, bytes_exch_recv_ = 0, bytes_exch_send_ = 0;
static int plan_rebuilds_ = 0;
static double bytes_fft_ = 0, bytes_pot_ = 0;  // distributed FFT: Alltoall and Allgatherv traffic (per rank, summed over iterations)
static bool dist_() { return cfg.fft == "distributed"; }
static double plan_t_alloc_ = 0, plan_t_cufft_ = 0, plan_t_spec_ = 0;  // where a plan rebuild spends its time (this rank, seconds, summed)
static bool last_plan_rebuilt_ = false;
static bool host_transport_() { return cfg.transport == "host"; }

// =============================================================================================
// FFT plan / kernel spectrum management
// =============================================================================================
static void ensure_plan(const GridParams& gp) {
  const bool size_change = !fs_.has || fs_.M != gp.M;
  const bool h_change = !fs_.has || fs_.h != gp.h;
  last_plan_rebuilt_ = size_change;
  if (!size_change && !h_change) return;
  const int M = gp.M, n = 2 * M;
  const size_t nspec = (size_t)n * (M + 1);
  if (size_change) {
    CpuScope scope(ST_PLAN);  // includes the device synchronisation at the end: a one-off cost
    const double tp0 = MPI_Wtime();
    if (fs_.has) {
      CUFFT_CHECK(cufftDestroy(fs_.fwd4));
      CUFFT_CHECK(cufftDestroy(fs_.inv4));
      CUFFT_CHECK(cufftDestroy(fs_.fwd1));
    }
    const double tp1 = MPI_Wtime();
    fs_.grid.reserve(4 * (size_t)M * M);
    fs_.pad.reserve(4 * (size_t)n * n);
    fs_.ker.reserve((size_t)n * n);
    fs_.spec.reserve(4 * nspec);
    fs_.khat.reserve(nspec);
    fs_.hgrid.reserve(4 * (size_t)M * M);
    const double tp2 = MPI_Wtime();
    int dims[2] = {n, n};
    CUFFT_CHECK(cufftPlanMany(&fs_.fwd4, 2, dims, nullptr, 1, n * n, nullptr, 1, (int)nspec, FFT_FWD_TYPE, 4));
    CUFFT_CHECK(cufftPlanMany(&fs_.inv4, 2, dims, nullptr, 1, (int)nspec, nullptr, 1, n * n, FFT_INV_TYPE, 4));
    CUFFT_CHECK(cufftPlanMany(&fs_.fwd1, 2, dims, nullptr, 1, n * n, nullptr, 1, (int)nspec, FFT_FWD_TYPE, 1));
    fs_.has = true;
    plan_rebuilds_++;
    const double tp3 = MPI_Wtime();
    // Kernel spectrum: depends on M and on the node spacing h.
    LAUNCH(k_fill_kernel, blocks_for((long long)n * n, cfg.block), cfg.block, fs_.ker.p, M, gp.h);
    CUFFT_CHECK(fft_forward(fs_.fwd1, fs_.ker.p, fs_.khat.p));
    CUDA_CHECK(cudaDeviceSynchronize());
    const double tp4 = MPI_Wtime();
    plan_t_alloc_ += tp2 - tp1;                 // buffer (re)allocation: cudaMalloc / cudaFree inside reserve()
    plan_t_cufft_ += (tp1 - tp0) + (tp3 - tp2);  // cufftDestroy x3 + cufftPlanMany x3
    plan_t_spec_ += tp4 - tp3;                   // kernel fill + kernel FFT + device synchronisation
  } else {
    T.gb(ST_KSPEC);  // fixed-grid mode: h follows the embedding extent, so this runs every iteration
    LAUNCH(k_fill_kernel, blocks_for((long long)n * n, cfg.block), cfg.block, fs_.ker.p, M, gp.h);
    CUFFT_CHECK(fft_forward(fs_.fwd1, fs_.ker.p, fs_.khat.p));
    T.ge(ST_KSPEC);
  }
  fs_.M = M;
  fs_.h = gp.h;
}


// ---------------------------------------------------------------------------------------------
// Distributed FFT: plan, kernel spectrum, transposes
// ---------------------------------------------------------------------------------------------
static int dist_fft_size(int M) {  // circulant embedding length >= 2M, a multiple of P and 2,3,5,7-smooth
  int n = 2 * M;
  for (;; ++n)
    if (n % P_ == 0 && next_smooth(n) == n) return n;
}

// Alltoall of the block buffer fs_.sbuf -> fs_.rbuf (NB arrays); host-staged unless --transport device.
static void dist_exchange(int NB) {
  const long long total = (long long)NB * fs_.R * fs_.n;  // complex numbers per rank, = P * NB * R * R
  const size_t bytes = (size_t)total * sizeof(fft_cplx);
  const int cnt = NB * fs_.R * fs_.R * 2;                 // reals per partner
  gpu_drain();
  CpuScope s(ST_FFT_TRANSPOSE);
  if (host_transport_()) {
    CUDA_CHECK(cudaMemcpy(fs_.h_sbuf.p, fs_.sbuf.p, bytes, cudaMemcpyDeviceToHost));
    MPI_Alltoall(fs_.h_sbuf.p, cnt, MPI_REAL_T, fs_.h_rbuf.p, cnt, MPI_REAL_T, comm_);
    CUDA_CHECK(cudaMemcpy(fs_.rbuf.p, fs_.h_rbuf.p, bytes, cudaMemcpyHostToDevice));
  } else {
    MPI_Alltoall(fs_.sbuf.p, cnt, MPI_REAL_T, fs_.rbuf.p, cnt, MPI_REAL_T, comm_);
  }
  bytes_fft_ += (double)bytes * (P_ - 1) / P_;
}

// Kernel spectrum with the distributed transform: rows -> transpose -> columns; keeps the real part.
static void dist_kernel_spectrum(const GridParams& gp) {
  const int n = fs_.n, R = fs_.R, bs = cfg.block;
  const long long Rn = (long long)R * n;
  LAUNCH(k_fill_kernel_rows, blocks_for(Rn, bs), bs, fs_.rowsAB.p, fs_.r0, R, n, gp.h);
  CUFFT_CHECK(fft_c2c(fs_.p1, fs_.rowsAB.p, fs_.rowsAB.p, CUFFT_FORWARD));
  LAUNCH(k_blk_pack_rows, blocks_for(Rn, bs), bs, fs_.rowsAB.p, fs_.sbuf.p, R, n, 1);
  dist_exchange(1);
  LAUNCH(k_blk_unpack_cols, blocks_for(Rn, bs), bs, fs_.rbuf.p, fs_.colsAB.p, R, n, 1);
  CUFFT_CHECK(fft_c2c(fs_.p1, fs_.colsAB.p, fs_.colsAB.p, CUFFT_FORWARD));
  LAUNCH(k_take_real, blocks_for(Rn, bs), bs, fs_.khat_blk.p, fs_.colsAB.p, Rn);
}

static void ensure_plan_dist(const GridParams& gp) {
  const int M = gp.M, n = dist_fft_size(M);
  const bool size_change = !fs_.has || fs_.M != M || fs_.n != n;
  const bool h_change = !fs_.has || fs_.h != gp.h;
  last_plan_rebuilt_ = size_change;
  if (!size_change && !h_change) return;
  if (size_change) {
    CpuScope scope(ST_PLAN);
    const double tp0 = MPI_Wtime();
    if (fs_.has) {
      CUFFT_CHECK(cufftDestroy(fs_.p2));
      CUFFT_CHECK(cufftDestroy(fs_.p1));
    }
    const double tp1 = MPI_Wtime();
    fs_.M = M;
    fs_.n = n;
    fs_.R = n / P_;
    fs_.r0 = rank_ * fs_.R;
    fs_.rowsM = std::max(0, std::min(fs_.r0 + fs_.R, M) - fs_.r0);
    fs_.rs_cnt.assign(P_, 0);
    fs_.rs_dsp.assign(P_, 0);
    for (int r = 0; r < P_; ++r) {
      const int a0 = r * fs_.R, a1 = std::min(a0 + fs_.R, M);
      fs_.rs_cnt[r] = std::max(0, a1 - a0) * 4 * M;
      fs_.rs_dsp[r] = r == 0 ? 0 : fs_.rs_dsp[r - 1] + fs_.rs_cnt[r - 1];
    }
    const size_t grid_n = 4 * (size_t)M * M, blk_n = std::max<size_t>((size_t)fs_.rowsM * 4 * M, 1), cplx_n = 2 * (size_t)fs_.R * n;
    fs_.grid.reserve(grid_n);
    fs_.gridP.reserve(grid_n);
    fs_.potP.reserve(grid_n);
    fs_.blk.reserve(blk_n);
    fs_.potblk.reserve(blk_n);
    fs_.rowsAB.reserve(cplx_n);
    fs_.colsAB.reserve(cplx_n);
    fs_.sbuf.reserve(cplx_n);
    fs_.rbuf.reserve(cplx_n);
    fs_.khat_blk.reserve((size_t)fs_.R * n);
    if (host_transport_()) {
      fs_.h_gridP.reserve(grid_n);
      fs_.h_potP.reserve(grid_n);
      fs_.h_blk.reserve(blk_n);
      fs_.h_potblk.reserve(blk_n);
      fs_.h_sbuf.reserve(cplx_n);
      fs_.h_rbuf.reserve(cplx_n);
    }
    const double tp2 = MPI_Wtime();
    int len = n;
    CUFFT_CHECK(cufftPlanMany(&fs_.p2, 1, &len, nullptr, 1, n, nullptr, 1, n, FFT_C2C_TYPE, 2 * fs_.R));
    CUFFT_CHECK(cufftPlanMany(&fs_.p1, 1, &len, nullptr, 1, n, nullptr, 1, n, FFT_C2C_TYPE, fs_.R));
    fs_.has = true;
    plan_rebuilds_++;
    const double tp3 = MPI_Wtime();
    dist_kernel_spectrum(gp);
    CUDA_CHECK(cudaDeviceSynchronize());
    const double tp4 = MPI_Wtime();
    plan_t_alloc_ += tp2 - tp1;
    plan_t_cufft_ += (tp1 - tp0) + (tp3 - tp2);
    plan_t_spec_ += tp4 - tp3;
  } else {
    T.gb(ST_KSPEC);  // fixed-grid mode: runs every iteration (includes the transpose of the kernel rows)
    dist_kernel_spectrum(gp);
    T.ge(ST_KSPEC);
  }
  fs_.h = gp.h;
}

// =============================================================================================
// Communication: waiting policy, coordinate exchange (study A), grid sum (study B)
// =============================================================================================
// How the CPU waits for outstanding non-blocking MPI requests while GPU kernels run:
//   wait: MPI_Waitall right after the kernels were launched (GPU runs asynchronously, MPI
//         progresses inside Waitall)      <- the intended overlap
//   sync: cudaDeviceSynchronize() first, THEN MPI_Waitall: the naive ordering; if the MPI library
//         only progresses transfers inside MPI calls, nothing overlaps
//   poll: busy loop with MPI_Testall (manual progress)
static void wait_requests(std::vector<MPI_Request>& reqs) {
  if (reqs.empty()) return;
  if (cfg.progress == "sync") CUDA_CHECK(cudaDeviceSynchronize());
  if (cfg.progress == "poll") {
    int flag = 0;
    while (!flag) MPI_Testall((int)reqs.size(), reqs.data(), &flag, MPI_STATUSES_IGNORE);
  } else {
    MPI_Waitall((int)reqs.size(), reqs.data(), MPI_STATUSES_IGNORE);
  }
  reqs.clear();
}
static void wait_one(MPI_Request& r) {
  if (r == MPI_REQUEST_NULL) return;
  std::vector<MPI_Request> v{r};
  wait_requests(v);
  r = MPI_REQUEST_NULL;
}

static void exchange_begin(bool nonblocking) {
  const int bs = cfg.block;
  if (cfg.exchange == "allgather") {
    // Every rank receives all other coordinates, in place.
    real* buf = d_Y.p;
    gpu_drain();  // our block was written by kernels (update/centre)
    {
      CpuScope s(ST_EXCH_COMM);
      if (host_transport_()) {
        CUDA_CHECK(cudaMemcpy(h_Y.p + 2 * (size_t)lo_, d_Y.p + 2 * (size_t)lo_, 2 * (size_t)nloc_ * sizeof(real),
                              cudaMemcpyDeviceToHost));
        buf = h_Y.p;
      }
      if (nonblocking) {
        exch_reqs_.resize(1);
        MPI_Iallgatherv(MPI_IN_PLACE, 0, MPI_DATATYPE_NULL, buf, ag_cnt_.data(), ag_dsp_.data(), MPI_REAL_T, comm_,
                        &exch_reqs_[0]);
      } else {
        MPI_Allgatherv(MPI_IN_PLACE, 0, MPI_DATATYPE_NULL, buf, ag_cnt_.data(), ag_dsp_.data(), MPI_REAL_T, comm_);
      }
    }
    bytes_exch_recv_ += (double)(N_ - nloc_) * 2 * sizeof(real);
    bytes_exch_send_ += (double)nloc_ * 2 * sizeof(real) * (P_ - 1);
    return;
  }
  // ghost exchange: pack on the GPU, then point-to-point messages to/from each neighbour rank
  if (send_total_ > 0) {
    T.gb(ST_EXCH_PACK);
    LAUNCH(k_pack, blocks_for(send_total_, bs), bs, d_Y.p, d_send_ids.p, send_total_, d_sendbuf.p);
    T.ge(ST_EXCH_PACK);
  }
  gpu_drain();  // pack kernel must be finished before the D2H copy / before MPI reads the device buffer
  {
    CpuScope s(ST_EXCH_COMM);
    real* sbuf = d_sendbuf.p;
    real* rbuf = d_recvbuf.p;
    if (host_transport_()) {
      if (send_total_ > 0)
        CUDA_CHECK(cudaMemcpy(h_sendbuf.p, d_sendbuf.p, (size_t)send_total_ * 2 * sizeof(real), cudaMemcpyDeviceToHost));
      sbuf = h_sendbuf.p;
      rbuf = h_recvbuf.p;
    }
    exch_reqs_.clear();
    for (int q = 0; q < P_; ++q)  // post all receives first (needed for deadlock-free blocking sends)
      if (recv_cnt_[q] > 0) {
        exch_reqs_.emplace_back();
        MPI_Irecv(rbuf + 2 * (size_t)recv_dsp_[q], 2 * recv_cnt_[q], MPI_REAL_T, q, 7, comm_, &exch_reqs_.back());
      }
    for (int q = 0; q < P_; ++q)
      if (send_cnt_[q] > 0) {
        real* sp = sbuf + 2 * (size_t)send_dsp_[q];
        if (nonblocking) {
          exch_reqs_.emplace_back();
          MPI_Isend(sp, 2 * send_cnt_[q], MPI_REAL_T, q, 7, comm_, &exch_reqs_.back());
        } else if (cfg.ssend) {
          MPI_Ssend(sp, 2 * send_cnt_[q], MPI_REAL_T, q, 7, comm_);
        } else {
          MPI_Send(sp, 2 * send_cnt_[q], MPI_REAL_T, q, 7, comm_);
        }
      }
  }
  bytes_exch_recv_ += (double)recv_total_ * 2 * sizeof(real);
  bytes_exch_send_ += (double)send_total_ * 2 * sizeof(real);
}

// Complete the exchange and make the received coordinates visible to the GPU kernels.
static void exchange_end() {
  {
    CpuScope s(ST_EXCH_WAIT);
    wait_requests(exch_reqs_);
  }
  if (host_transport_()) gpu_drain();  // H2D below would otherwise absorb the running near-field kernel
  CpuScope s(ST_EXCH_UNPACK);
  if (cfg.exchange == "allgather") {
    if (host_transport_()) {  // upload everything except our own block (already on the GPU)
      if (lo_ > 0)
        CUDA_CHECK(cudaMemcpy(d_Y.p, h_Y.p, 2 * (size_t)lo_ * sizeof(real), cudaMemcpyHostToDevice));
      if (hi_ < N_)
        CUDA_CHECK(cudaMemcpy(d_Y.p + 2 * (size_t)hi_, h_Y.p + 2 * (size_t)hi_, 2 * (size_t)(N_ - hi_) * sizeof(real),
                              cudaMemcpyHostToDevice));
    }
    return;
  }
  if (recv_total_ == 0) return;
  if (host_transport_())
    CUDA_CHECK(cudaMemcpy(d_recvbuf.p, h_recvbuf.p, (size_t)recv_total_ * 2 * sizeof(real), cudaMemcpyHostToDevice));
  LAUNCH(k_unpack, blocks_for(recv_total_, cfg.block), cfg.block, d_recvbuf.p, d_recv_ids.p, recv_total_, d_Y.p);
}

// Sum the partial grids of all ranks (4 charge grids of M x M reals).
static void grid_begin(const GridParams& gp, bool nonblocking) {
  const int count = 4 * gp.M * gp.M;
  real* buf = fs_.grid.p;
  gpu_drain();  // scatter must be finished (D2H copy / device-pointer Allreduce)
  if (host_transport_()) {
    {
      CpuScope s(ST_GRID_D2H);
      CUDA_CHECK(cudaMemcpy(fs_.hgrid.p, fs_.grid.p, (size_t)count * sizeof(real), cudaMemcpyDeviceToHost));
    }
    buf = fs_.hgrid.p;
  }
  CpuScope s(ST_GRID_COMM);
  if (nonblocking) MPI_Iallreduce(MPI_IN_PLACE, buf, count, MPI_REAL_T, MPI_SUM, comm_, &grid_req_);
  else MPI_Allreduce(MPI_IN_PLACE, buf, count, MPI_REAL_T, MPI_SUM, comm_);
  bytes_grid_ += (double)count * sizeof(real);
}
static void grid_end(const GridParams& gp, bool nonblocking) {
  const int count = 4 * gp.M * gp.M;
  if (nonblocking) {
    CpuScope s(ST_GRID_WAIT);
    wait_one(grid_req_);
  }
  if (host_transport_()) {
    // AFTER the MPI wait on purpose: while the CPU sits in MPI_Wait the Iallreduce progresses and the
    // near-field kernels run (the overlap of study B). Draining the GPU before the wait would stop that.
    gpu_drain();  // the H2D copy waits for the near-field kernels anyway; book that time as gpu_wait
    CpuScope s(ST_GRID_H2D);
    CUDA_CHECK(cudaMemcpy(fs_.grid.p, fs_.hgrid.p, (size_t)count * sizeof(real), cudaMemcpyHostToDevice));
  }
}


// ---- distributed FFT: grid sum (Reduce_scatter of row blocks) and convolution ----
static void dist_grid_begin(const GridParams& gp, bool nonblocking) {
  const int M = gp.M, bs = cfg.block;
  const long long M2 = (long long)M * M;
  const size_t count = 4 * (size_t)M2;
  T.gb(ST_PERM_IN);
  LAUNCH(k_perm_in, blocks_for(4 * M2, bs), bs, fs_.grid.p, fs_.gridP.p, M);
  T.ge(ST_PERM_IN);
  gpu_drain();  // scatter + permutation must be finished (D2H copy / device-pointer Reduce_scatter)
  real* sbuf = fs_.gridP.p;
  real* rbuf = fs_.blk.p;
  if (host_transport_()) {
    {
      CpuScope s(ST_GRID_D2H);
      CUDA_CHECK(cudaMemcpy(fs_.h_gridP.p, fs_.gridP.p, count * sizeof(real), cudaMemcpyDeviceToHost));
    }
    sbuf = fs_.h_gridP.p;
    rbuf = fs_.h_blk.p;
  }
  CpuScope s(ST_GRID_COMM);
  if (nonblocking) MPI_Ireduce_scatter(sbuf, rbuf, fs_.rs_cnt.data(), MPI_REAL_T, MPI_SUM, comm_, &grid_req_);
  else MPI_Reduce_scatter(sbuf, rbuf, fs_.rs_cnt.data(), MPI_REAL_T, MPI_SUM, comm_);
  bytes_grid_ += (double)count * sizeof(real);
}
static void dist_grid_end(const GridParams&, bool nonblocking) {
  if (nonblocking) {
    CpuScope s(ST_GRID_WAIT);
    wait_one(grid_req_);
  }
  if (host_transport_()) {
    gpu_drain();
    CpuScope s(ST_GRID_H2D);
    const size_t mine = (size_t)fs_.rs_cnt[rank_];
    if (mine > 0) CUDA_CHECK(cudaMemcpy(fs_.blk.p, fs_.h_blk.p, mine * sizeof(real), cudaMemcpyHostToDevice));
  }
}

// Summed charge rows -> potential grid on every rank (in fs_.grid, layout of k_gather).
static void dist_convolve(const GridParams& gp) {
  const int M = gp.M, n = fs_.n, R = fs_.R, bs = cfg.block;
  const long long Rn = (long long)R * n;
  const real scale = (real)1 / ((real)n * (real)n);
  T.gb(ST_FFT);  // load, transforms of the rows
  LAUNCH(k_dist_load, blocks_for(2 * Rn, bs), bs, fs_.blk.p, fs_.rowsAB.p, R, n, fs_.rowsM, M);
  CUFFT_CHECK(fft_c2c(fs_.p2, fs_.rowsAB.p, fs_.rowsAB.p, CUFFT_FORWARD));
  LAUNCH(k_blk_pack_rows, blocks_for(2 * Rn, bs), bs, fs_.rowsAB.p, fs_.sbuf.p, R, n, 2);
  T.ge(ST_FFT);
  dist_exchange(2);
  T.gb(ST_FFT2);  // columns: forward, multiplication by the kernel spectrum, inverse
  LAUNCH(k_blk_unpack_cols, blocks_for(2 * Rn, bs), bs, fs_.rbuf.p, fs_.colsAB.p, R, n, 2);
  CUFFT_CHECK(fft_c2c(fs_.p2, fs_.colsAB.p, fs_.colsAB.p, CUFFT_FORWARD));
  LAUNCH(k_dist_mul, blocks_for(2 * Rn, bs), bs, fs_.colsAB.p, fs_.khat_blk.p, R, n, scale);
  CUFFT_CHECK(fft_c2c(fs_.p2, fs_.colsAB.p, fs_.colsAB.p, CUFFT_INVERSE));
  LAUNCH(k_blk_pack_cols, blocks_for(2 * Rn, bs), bs, fs_.colsAB.p, fs_.sbuf.p, R, n, 2);
  T.ge(ST_FFT2);
  dist_exchange(2);
  T.gb(ST_FFT3);  // rows: inverse, store of the potential rows
  LAUNCH(k_blk_unpack_rows, blocks_for(2 * Rn, bs), bs, fs_.rbuf.p, fs_.rowsAB.p, R, n, 2);
  CUFFT_CHECK(fft_c2c(fs_.p2, fs_.rowsAB.p, fs_.rowsAB.p, CUFFT_INVERSE));
  if (fs_.rowsM > 0)
    LAUNCH(k_dist_store, blocks_for((long long)fs_.rowsM * 4 * M, bs), bs, fs_.rowsAB.p, fs_.potblk.p, R, n, fs_.rowsM, M);
  T.ge(ST_FFT3);
  gpu_drain();
  {  // every rank needs the potentials of all nodes near its points
    CpuScope s(ST_POT_ALLGATHER);
    const size_t mine = (size_t)fs_.rs_cnt[rank_], all = 4 * (size_t)M * M;
    if (host_transport_()) {
      if (mine > 0) CUDA_CHECK(cudaMemcpy(fs_.h_potblk.p, fs_.potblk.p, mine * sizeof(real), cudaMemcpyDeviceToHost));
      MPI_Allgatherv(fs_.h_potblk.p, (int)mine, MPI_REAL_T, fs_.h_potP.p, fs_.rs_cnt.data(), fs_.rs_dsp.data(), MPI_REAL_T, comm_);
      CUDA_CHECK(cudaMemcpy(fs_.potP.p, fs_.h_potP.p, all * sizeof(real), cudaMemcpyHostToDevice));
    } else {
      MPI_Allgatherv(fs_.potblk.p, (int)mine, MPI_REAL_T, fs_.potP.p, fs_.rs_cnt.data(), fs_.rs_dsp.data(), MPI_REAL_T, comm_);
    }
    bytes_pot_ += (double)all * sizeof(real) * (P_ - 1) / P_;
  }
  T.gb(ST_PERM_OUT);
  LAUNCH(k_perm_out, blocks_for(4LL * M * M, bs), bs, fs_.potP.p, fs_.grid.p, M);
  T.ge(ST_PERM_OUT);
}

// =============================================================================================
// One-iteration pieces
// =============================================================================================
// --overlap-near: the attraction runs on s_near_. It starts after everything that was queued on the
// default stream so far (coordinates, unpacked ghosts), and the default stream waits for it only
// after the gather of the repulsion (see iteration()), so it overlaps with the FFT.
static cudaStream_t near_stream() { return cfg.overlap_near ? s_near_ : (cudaStream_t)0; }
static void near_sync_in() {
  if (!cfg.overlap_near) return;
  CUDA_CHECK(cudaEventRecord(ev_y_, 0));
  CUDA_CHECK(cudaStreamWaitEvent(s_near_, ev_y_, 0));
}
static void launch_near_local() {
  const cudaStream_t st = near_stream();
  T.gb(ST_NEAR_LOCAL, st);
  LAUNCH_S(k_near<0>, blocks_for(nloc_, cfg.block), cfg.block, st, csr_loc_.rowptr.p, csr_loc_.col.p, csr_loc_.val.p, d_Y.p,
           lo_, nloc_, d_Fattr.p);
  T.ge(ST_NEAR_LOCAL, st);
}
static void launch_near_remote() {
  if (csr_rem_.nnz == 0) return;
  const cudaStream_t st = near_stream();
  T.gb(ST_NEAR_REMOTE, st);
  LAUNCH_S(k_near<1>, blocks_for(nloc_, cfg.block), cfg.block, st, csr_rem_.rowptr.p, csr_rem_.col.p, csr_rem_.val.p, d_Y.p,
           lo_, nloc_, d_Fattr.p);
  T.ge(ST_NEAR_REMOTE, st);
}

// Bounding box, mean and centring. Needs 2 tiny Allreduces (MAX of box, SUM of coordinates).
static void stats_and_center(bool do_center = true) {
  double st[6];
  gpu_drain();
  {
    CpuScope s(ST_STATS);
    reduce_stats(d_Y.p + 2 * (size_t)lo_, nloc_, st);
  }
  double mx[4] = {-st[0], st[1], -st[2], st[3]}, sm[2] = {st[4], st[5]};
  if (comm_on_) {
    CpuScope s(ST_SMALL_ALLRED);
    MPI_Allreduce(MPI_IN_PLACE, mx, 4, MPI_DOUBLE, MPI_MAX, comm_);
    MPI_Allreduce(MPI_IN_PLACE, sm, 2, MPI_DOUBLE, MPI_SUM, comm_);
  }
  // In gradient-check mode the coordinates must stay exactly as given (the interpolation error
  // depends on where the points sit relative to the grid), so no centring is applied.
  const double mean_x = do_center ? sm[0] / (double)N_ : 0.0, mean_y = do_center ? sm[1] / (double)N_ : 0.0;
  if (do_center)
    LAUNCH(k_center, blocks_for(nloc_, cfg.block), cfg.block, d_Y.p, lo_, nloc_, (real)mean_x, (real)mean_y);
  bb_.x0 = -mx[0] - mean_x; bb_.x1 = mx[1] - mean_x;
  bb_.y0 = -mx[2] - mean_y; bb_.y1 = mx[3] - mean_y;
}

// KL(P||Q) at the current coordinates, given Z. Collective.
static double compute_kl(double Z) {
  CpuScope s(ST_KL);
  const int bs = cfg.block;
  LAUNCH(k_kl_rows<0>, blocks_for(nloc_, bs), bs, csr_loc_.rowptr.p, csr_loc_.col.p, csr_loc_.val.p, d_Y.p, lo_, nloc_, d_S.p);
  if (csr_rem_.nnz > 0)
    LAUNCH(k_kl_rows<1>, blocks_for(nloc_, bs), bs, csr_rem_.rowptr.p, csr_rem_.col.p, csr_rem_.val.p, d_Y.p, lo_, nloc_, d_S.p);
  double part = reduce_sum(d_S.p, nloc_);
  if (comm_on_) MPI_Allreduce(MPI_IN_PLACE, &part, 1, MPI_DOUBLE, MPI_SUM, comm_);
  return part + std::log(Z);
}

// One full iteration. If do_update is false (gradient-check mode) the coordinates are left
// untouched and the raw forces stay in d_Fattr / d_Frep. Returns Z.
static double iteration(real exag, real mom, real lr, bool do_update, bool want_kl, double* kl_out) {
  const int bs = cfg.block;
  // 1. grid for the current bounding box
  GridParams gp = make_grid(cfg.adaptive, cfg.p, cfg.bw, cfg.min_boxes, cfg.fixed_boxes, bb_.x0, bb_.x1, bb_.y0, bb_.y1, cfg.grid_quant);
  const bool dist = dist_();
  if (dist) ensure_plan_dist(gp);
  else ensure_plan(gp);
  const long long M2 = (long long)gp.M * gp.M;

  // 2. scatter the local points (needs no remote data)
  T.gb(ST_ZERO);
  CUDA_CHECK(cudaMemset(fs_.grid.p, 0, 4 * (size_t)M2 * sizeof(real)));
  T.ge(ST_ZERO);  // zeroing is timed separately so that C1 and the probes time exactly the same work
  T.gb(ST_SCATTER);
  LAUNCH(k_scatter<0>, blocks_for(nloc_, bs), bs, d_Y.p, lo_, nloc_, gp, fs_.grid.p, (real*)nullptr);
  T.ge(ST_SCATTER);
  if (cfg.probe) {  // study C: same input, different write pattern, results discarded
    d_probe_grid.reserve(4 * (size_t)M2);
    d_probe_scratch.reserve((size_t)nloc_ * gp.p * gp.p * 4);
    T.gb(ST_PROBE_PLAIN);
    LAUNCH(k_scatter<1>, blocks_for(nloc_, bs), bs, d_Y.p, lo_, nloc_, gp, d_probe_grid.p, (real*)nullptr);
    T.ge(ST_PROBE_PLAIN);
    T.gb(ST_PROBE_DISJ);
    LAUNCH(k_scatter<2>, blocks_for(nloc_, bs), bs, d_Y.p, lo_, nloc_, gp, (real*)nullptr, d_probe_scratch.p);
    T.ge(ST_PROBE_DISJ);
  }

  // 3. grid sum: start (B1: blocks until finished, B2: returns immediately)
  const bool grid_nb = cfg.grid_comm == "nonblocking";
  const bool exch_nb = cfg.comm == "nonblocking";
  if (dist) dist_grid_begin(gp, grid_nb);  // the distributed FFT needs its Reduce_scatter also for P == 1
  else if (comm_on_) grid_begin(gp, grid_nb);

  // 4. coordinate exchange + attractive force (A1..A4)
  if (comm_on_) {
    if (exch_nb) {
      exchange_begin(true);   // post messages
      near_sync_in();
      launch_near_local();    // GPU works on local neighbours while data is in flight
      exchange_end();         // wait, upload, unpack
      near_sync_in();         // the ghosts are in d_Y now
      launch_near_remote();
    } else {
      exchange_begin(false);
      exchange_end();
      near_sync_in();
      launch_near_local();
      launch_near_remote();
    }
  } else {
    near_sync_in();
    launch_near_local();
    launch_near_remote();
  }
  if (cfg.overlap_near) CUDA_CHECK(cudaEventRecord(ev_near_, s_near_));

  // 5. finish the grid sum (B2: the Iallreduce had the whole of step 4 to complete)
  if (dist) dist_grid_end(gp, grid_nb);
  else if (comm_on_) grid_end(gp, grid_nb);

  // 6. FFT convolution: potentials of the 4 charge grids
  if (dist) {
    dist_convolve(gp);
  } else {
    T.gb(ST_FFT);
    const int n = 2 * gp.M;
    const long long nspec = (long long)n * (gp.M + 1);
    LAUNCH(k_pad, blocks_for(4LL * n * n, bs), bs, fs_.grid.p, fs_.pad.p, gp.M);
    CUFFT_CHECK(fft_forward(fs_.fwd4, fs_.pad.p, fs_.spec.p));
    LAUNCH(k_mul_spec, blocks_for(4 * nspec, bs), bs, fs_.spec.p, fs_.khat.p, nspec, (real)1 / ((real)n * (real)n));
    CUFFT_CHECK(fft_inverse(fs_.inv4, fs_.spec.p, fs_.pad.p));
    LAUNCH(k_unpad, blocks_for(4 * M2, bs), bs, fs_.pad.p, fs_.grid.p, gp.M);
    T.ge(ST_FFT);
  }

  // 7. grid -> points, repulsive force, Z
  T.gb(ST_GATHER);
  LAUNCH(k_gather, blocks_for(nloc_, bs), bs, d_Y.p, lo_, nloc_, gp, fs_.grid.p, d_Frep.p, d_S.p);
  T.ge(ST_GATHER);
  if (cfg.overlap_near) CUDA_CHECK(cudaStreamWaitEvent(0, ev_near_, 0));  // the attraction must be finished before the update
  double Z;
  {
    gpu_drain();
    {
      CpuScope s(ST_Z);
      Z = reduce_sum(d_S.p, nloc_);
    }
    if (comm_on_) {
      CpuScope s(ST_SMALL_ALLRED);
      MPI_Allreduce(MPI_IN_PLACE, &Z, 1, MPI_DOUBLE, MPI_SUM, comm_);
    }
    Z -= (double)N_;  // remove the N self-terms q~_ii = 1
  }
  if (!(Z > 0) || std::isinf(Z)) {
    std::fprintf(stderr, "rank %d: invalid Z = %g (NaN/Inf or non-positive). Embedding diverged?\n", rank_, Z);
    MPI_Abort(MPI_COMM_WORLD, 2);
  }

  if (want_kl && kl_out) *kl_out = compute_kl(Z);

  // 8. update, then 9. bounding box and centring for the next iteration
  if (do_update) {
    T.gb(ST_UPDATE);
    LAUNCH(k_update, blocks_for(nloc_, bs), bs, d_Y.p, d_upd.p, d_gain.p, d_Fattr.p, d_Frep.p, lo_, nloc_, exag,
           (real)(1.0 / Z), lr, mom);
    T.ge(ST_UPDATE);
    stats_and_center();
  }
  return Z;
}

// =============================================================================================
// Setup helpers
// =============================================================================================
static void upload_csr(const SymCSR& m, Csr& d) {
  d.nnz = (long long)m.col.size();
  d.rowptr.upload((const long long*)m.rowptr.data(), m.rowptr.size());
  d.col.upload((const int*)m.col.data(), m.col.size());
  std::vector<real> v(m.val.begin(), m.val.end());
  d.val.upload(v.data(), v.size());
}

#if defined(MPIX_CUDA_AWARE_SUPPORT) && MPIX_CUDA_AWARE_SUPPORT
static bool mpi_cuda_aware() { return MPIX_Query_cuda_support() == 1; }
#else
static bool mpi_cuda_aware() { return false; }
#endif

static std::string flag_str(const std::string& a, const std::string& b) { return a + "/" + b; }

int main(int argc, char** argv) {
  MPI_Init(&argc, &argv);
  MPI_Comm_rank(MPI_COMM_WORLD, &rank_);
  MPI_Comm_size(MPI_COMM_WORLD, &P_);
  Args a(argc, argv);
  cfg.data = a.str("data", "");
  cfg.out = a.str("out", "out/run");
  cfg.order = a.str("order", "pc1");
  cfg.coords = a.str("coords", "");
  cfg.mode = a.str("mode", "run");
  cfg.exchange = a.str("exchange", "ghost");
  cfg.comm = a.str("comm", "blocking");
  cfg.grid_comm = a.str("grid-comm", "blocking");
  cfg.transport = a.str("transport", "host");
  cfg.progress = a.str("progress", "wait");
  cfg.fft = a.str("fft", "replicated");
  cfg.ssend = a.flag("ssend");
  cfg.overlap_near = a.flag("overlap-near");
  cfg.iters = (int)a.integer("iters", 1000);
  cfg.exag_iters = (int)a.integer("exag-iters", 250);
  cfg.mom_switch = (int)a.integer("mom-switch", 250);
  cfg.exag = a.num("exag", 12);
  cfg.perplexity = a.num("perplexity", 30);
  cfg.lr = a.num("lr", -1);
  cfg.p = (int)a.integer("order-p", 3);
  cfg.bw = a.num("bw", 0.5);
  cfg.min_boxes = (int)a.integer("min-boxes", 50);
  cfg.adaptive = a.str("grid-mode", "adaptive") == "adaptive";
  cfg.fixed_boxes = (int)a.integer("fixed-boxes", 128);
  cfg.grid_quant = a.num("grid-quant", 0);
  cfg.block = (int)a.integer("block", 256);
  cfg.seed = (uint64_t)a.integer("seed", 42);
  cfg.report_every = (int)a.integer("report-every", 50);  // 0 = no KL inside the timed loop (use 0 for timing runs)
  cfg.warmup = (int)a.integer("warmup", 10);
  cfg.stage_timing = a.flag("stage-timing", true);
  cfg.probe = a.flag("probe", false);
  cfg.force_comm = a.flag("force-comm", false);  // keep MPI calls / copies even for P == 1 (overhead test)
  if (rank_ == 0)
    for (auto& u : a.unused()) std::fprintf(stderr, "warning: unused option --%s\n", u.c_str());
  if (cfg.data.empty()) die("--data is required");
  if (cfg.p < 2 || cfg.p > MAX_ORDER) die("--order-p must be in [2,6]");
  if (cfg.exchange != "ghost" && cfg.exchange != "allgather") die("--exchange must be ghost|allgather");
  if (cfg.comm != "blocking" && cfg.comm != "nonblocking") die("--comm must be blocking|nonblocking");
  if (cfg.grid_comm != "blocking" && cfg.grid_comm != "nonblocking") die("--grid-comm must be blocking|nonblocking");
  if (cfg.transport != "host" && cfg.transport != "device") die("--transport must be host|device");
  if (cfg.progress != "wait" && cfg.progress != "sync" && cfg.progress != "poll") die("--progress must be wait|sync|poll");
  if (cfg.fft != "replicated" && cfg.fft != "distributed") die("--fft must be replicated|distributed");
  comm_on_ = (P_ > 1) || cfg.force_comm;
  if (rank_ == 0) {
    int rc = std::system(("mkdir -p '" + cfg.out + "'").c_str());
    (void)rc;
  }
  MPI_Barrier(MPI_COMM_WORLD);

  // ---- GPU binding: ranks on the same node use different GPUs ----
  MPI_Comm node;
  MPI_Comm_split_type(MPI_COMM_WORLD, MPI_COMM_TYPE_SHARED, rank_, MPI_INFO_NULL, &node);
  int local_rank = 0, local_size = 1, ngpu = 0;
  MPI_Comm_rank(node, &local_rank);
  MPI_Comm_size(node, &local_size);
  CUDA_CHECK(cudaGetDeviceCount(&ngpu));
  if (ngpu == 0) die("no CUDA device visible");
  if (rank_ == 0 && local_size > ngpu)
    std::fprintf(stderr, "warning: %d ranks share %d GPU(s) on a node; timings will not be meaningful\n", local_size, ngpu);
  const int dev = local_rank % ngpu;
  CUDA_CHECK(cudaSetDevice(dev));
  cudaDeviceProp prop;
  CUDA_CHECK(cudaGetDeviceProperties(&prop, dev));
  char host[256];
  int hl = 0;
  MPI_Get_processor_name(host, &hl);
  std::printf("[rank %d/%d] host %s local_rank %d -> GPU %d (%s, %.1f GB)\n", rank_, P_, host, local_rank, dev, prop.name,
              prop.totalGlobalMem / 1073741824.0);
  const bool cuda_aware = mpi_cuda_aware();
  if (cfg.transport == "device" && !cuda_aware && rank_ == 0)
    std::fprintf(stderr, "warning: --transport device but this MPI does not report CUDA-aware support; "
                         "if the run crashes or hangs, use --transport host\n");
  T.init(cfg.stage_timing);
  if (cfg.overlap_near) {  // non-blocking: the default stream must not synchronise with it implicitly
    CUDA_CHECK(cudaStreamCreateWithFlags(&s_near_, cudaStreamNonBlocking));
    CUDA_CHECK(cudaEventCreate(&ev_y_));
    CUDA_CHECK(cudaEventCreate(&ev_near_));
  }

  // ---- load data, order, partition ----
  double t_setup0 = MPI_Wtime();
  Dataset ds;
  read_dataset(cfg.data, ds);
  N_ = ds.N;
  const int k = ds.k;
  Permutation pm = make_permutation(ds, cfg.order, cfg.seed);
  lo_ = (int)block_lo(N_, P_, rank_);
  hi_ = (int)block_lo(N_, P_, rank_ + 1);
  nloc_ = hi_ - lo_;
  if (nloc_ < 1) die("fewer points than ranks");
  double t_load = MPI_Wtime();

  // ---- perplexity calibration: each rank its own rows, then share ----
  std::vector<float> cond((size_t)N_ * k);
  {
    std::vector<double> row(k);
    for (int i = lo_; i < hi_; ++i) {
      calibrate_row(&ds.d2[(size_t)pm.perm[i] * k], k, cfg.perplexity, row.data());
      for (int t = 0; t < k; ++t) cond[(size_t)i * k + t] = (float)row[t];
    }
    if (P_ > 1) {
      std::vector<int> cnt(P_), dsp(P_);
      for (int r = 0; r < P_; ++r) {
        cnt[r] = (int)(block_lo(N_, P_, r + 1) - block_lo(N_, P_, r)) * k;
        dsp[r] = (int)block_lo(N_, P_, r) * k;
      }
      MPI_Allgatherv(MPI_IN_PLACE, 0, MPI_DATATYPE_NULL, cond.data(), cnt.data(), dsp.data(), MPI_FLOAT, comm_);
    }
  }
  double t_calib = MPI_Wtime();
  SymCSR all = build_sym_rows(ds, pm, cond, lo_, hi_);
  SymCSR loc, rem;
  split_local_remote(all, lo_, hi_, loc, rem);
  const std::vector<int32_t> ghost = unique_columns(rem);
  { std::vector<int32_t>().swap(ds.idx); std::vector<float>().swap(ds.d2); std::vector<float>().swap(cond); }
  double t_csr = MPI_Wtime();

  // ---- ghost exchange plan: who needs which of my points ----
  recv_cnt_.assign(P_, 0); send_cnt_.assign(P_, 0); recv_dsp_.assign(P_, 0); send_dsp_.assign(P_, 0);
  for (int32_t g : ghost) recv_cnt_[owner_of(N_, P_, g)]++;
  MPI_Alltoall(recv_cnt_.data(), 1, MPI_INT, send_cnt_.data(), 1, MPI_INT, comm_);
  for (int q = 1; q < P_; ++q) {
    recv_dsp_[q] = recv_dsp_[q - 1] + recv_cnt_[q - 1];
    send_dsp_[q] = send_dsp_[q - 1] + send_cnt_[q - 1];
  }
  recv_total_ = (int)ghost.size();
  send_total_ = send_cnt_.empty() ? 0 : send_dsp_[P_ - 1] + send_cnt_[P_ - 1];
  recv_ids_ = ghost;
  send_ids_.assign(send_total_, 0);
  MPI_Alltoallv(recv_ids_.data(), recv_cnt_.data(), recv_dsp_.data(), MPI_INT, send_ids_.data(), send_cnt_.data(),
                send_dsp_.data(), MPI_INT, comm_);
  ag_cnt_.resize(P_); ag_dsp_.resize(P_);
  for (int r = 0; r < P_; ++r) {
    ag_cnt_[r] = 2 * (int)(block_lo(N_, P_, r + 1) - block_lo(N_, P_, r));
    ag_dsp_[r] = 2 * (int)block_lo(N_, P_, r);
  }

  // ---- device memory ----
  size_t free0 = 0, total0 = 0;
  CUDA_CHECK(cudaMemGetInfo(&free0, &total0));
  upload_csr(loc, csr_loc_);
  upload_csr(rem, csr_rem_);
  d_Y.reserve(2 * (size_t)N_);
  d_Y.zero(2 * (size_t)N_);
  d_upd.reserve(2 * (size_t)nloc_); d_upd.zero(2 * (size_t)nloc_);
  d_gain.reserve(2 * (size_t)nloc_);
  { std::vector<real> ones(2 * (size_t)nloc_, (real)1); d_gain.upload(ones.data(), ones.size()); }
  d_Fattr.reserve(2 * (size_t)nloc_);
  d_Frep.reserve(2 * (size_t)nloc_);
  d_S.reserve(nloc_);
  d_send_ids.upload((const int*)send_ids_.data(), (size_t)send_total_);
  d_recv_ids.upload((const int*)recv_ids_.data(), (size_t)recv_total_);
  d_sendbuf.reserve(2 * (size_t)std::max(send_total_, 1));
  d_recvbuf.reserve(2 * (size_t)std::max(recv_total_, 1));
  h_sendbuf.reserve(2 * (size_t)std::max(send_total_, 1));
  h_recvbuf.reserve(2 * (size_t)std::max(recv_total_, 1));
  if (cfg.exchange == "allgather") h_Y.reserve(2 * (size_t)N_);

  // ---- initial coordinates (counter-based RNG on the global id => independent of P) ----
  {
    std::vector<real> y(2 * (size_t)nloc_);
    std::vector<double> yo;
    if (!cfg.coords.empty()) read_embedding(cfg.coords, N_, yo);
    for (int i = 0; i < nloc_; ++i) {
      const int g = lo_ + i;
      if (!cfg.coords.empty()) {
        y[2 * i] = (real)yo[2 * (size_t)pm.perm[g]];
        y[2 * i + 1] = (real)yo[2 * (size_t)pm.perm[g] + 1];
      } else {
        // keyed by the ORIGINAL point id: the start does not depend on --order or on P
        y[2 * i] = (real)(1e-4 * gaussian_at(cfg.seed, 2 * (uint64_t)pm.perm[g]));
        y[2 * i + 1] = (real)(1e-4 * gaussian_at(cfg.seed, 2 * (uint64_t)pm.perm[g] + 1));
      }
    }
    CUDA_CHECK(cudaMemcpy(d_Y.p + 2 * (size_t)lo_, y.data(), y.size() * sizeof(real), cudaMemcpyHostToDevice));
  }
  stats_and_center(cfg.mode != "grad");  // initial bounding box (all ranks); centres the start in run mode
  double t_setup1 = MPI_Wtime();

  // ---- static statistics of the partition (study A evidence) ----
  const double nnz_loc = (double)csr_loc_.nnz, nnz_rem = (double)csr_rem_.nnz;
  double stat_in[4] = {(double)ghost.size(), nnz_rem / std::max(1.0, nnz_loc + nnz_rem), nnz_loc + nnz_rem, (double)send_total_};
  double st_min[4], st_max[4], st_sum[4];
  MPI_Allreduce(stat_in, st_min, 4, MPI_DOUBLE, MPI_MIN, comm_);
  MPI_Allreduce(stat_in, st_max, 4, MPI_DOUBLE, MPI_MAX, comm_);
  MPI_Allreduce(stat_in, st_sum, 4, MPI_DOUBLE, MPI_SUM, comm_);
  if (rank_ == 0)
    std::printf("setup %.2fs: N=%lld k=%d P=%d  ghosts/rank min %.0f max %.0f mean %.0f (%.2f%% of N)  "
                "remote-nnz fraction %.3f..%.3f  nnz(P)=%.3g\n",
                t_setup1 - t_setup0, (long long)N_, k, P_, st_min[0], st_max[0], st_sum[0] / P_,
                100.0 * st_sum[0] / P_ / N_, st_min[1], st_max[1], st_sum[2]);

  const double lr = cfg.lr > 0 ? cfg.lr : std::max(50.0, (double)N_ / 48.0);

  // =========================================================================================
  // gradient-check mode: one evaluation at fixed coordinates, no update
  // =========================================================================================
  if (cfg.mode == "grad") {
    if (cfg.coords.empty()) die("--mode grad needs --coords");
    double Z = iteration(1, 0, 0, false, false, nullptr);
    std::vector<real> fa(2 * (size_t)nloc_), fr(2 * (size_t)nloc_);
    d_Fattr.download(fa.data(), fa.size());
    d_Frep.download(fr.data(), fr.size());
    std::vector<double> fa_d(fa.begin(), fa.end()), fr_d(fr.begin(), fr.end());
    std::vector<int> cnt(P_), dsp(P_);
    for (int r = 0; r < P_; ++r) { cnt[r] = ag_cnt_[r]; dsp[r] = ag_dsp_[r]; }
    std::vector<double> A, R;
    if (rank_ == 0) { A.resize(2 * (size_t)N_); R.resize(2 * (size_t)N_); }
    MPI_Gatherv(fa_d.data(), 2 * nloc_, MPI_DOUBLE, A.data(), cnt.data(), dsp.data(), MPI_DOUBLE, 0, comm_);
    MPI_Gatherv(fr_d.data(), 2 * nloc_, MPI_DOUBLE, R.data(), cnt.data(), dsp.data(), MPI_DOUBLE, 0, comm_);
    if (rank_ == 0) {
      std::vector<double> Ao(2 * (size_t)N_), Ro(2 * (size_t)N_), Go(2 * (size_t)N_);
      for (int64_t i = 0; i < N_; ++i)
        for (int c = 0; c < 2; ++c) {
          int64_t o = pm.perm[i];
          Ao[2 * o + c] = A[2 * i + c];
          Ro[2 * o + c] = R[2 * i + c];
          Go[2 * o + c] = 4.0 * (A[2 * i + c] - R[2 * i + c] / Z);
        }
      write_grad(cfg.out + "/grad.bin", N_, Z, Ao, Ro, Go);
      std::printf("wrote %s/grad.bin  Z=%.10g\n", cfg.out.c_str(), Z);
    }
    MPI_Finalize();
    return 0;
  }

  // =========================================================================================
  // optimisation loop
  // =========================================================================================
  size_t free1 = 0, total1 = 0;
  CUDA_CHECK(cudaMemGetInfo(&free1, &total1));
  std::vector<std::pair<int, double>> kl_hist;
  CUDA_CHECK(cudaDeviceSynchronize());
  MPI_Barrier(comm_);
  const double t_loop0 = MPI_Wtime();
  std::vector<char> plan_flag;
  for (int it = 0; it < cfg.iters; ++it) {
    const double ti0 = MPI_Wtime();
    const real exag = it < cfg.exag_iters ? (real)cfg.exag : (real)1;
    const real mom = it < cfg.mom_switch ? (real)0.5 : (real)0.8;
    // KL inside the loop only if requested (--report-every > 0); those iterations are excluded
    // from the steady-state statistics. The final KL is always computed after the timed loop.
    const bool want_kl = cfg.report_every > 0 && (it % cfg.report_every == 0);
    double kl = 0;
    double Z = iteration(exag, mom, (real)lr, true, want_kl, &kl);
    T.end_iter(MPI_Wtime() - ti0);
    if (want_kl) kl_hist.push_back({it, kl});
    if (rank_ == 0 && (it % 100 == 0 || it == cfg.iters - 1))
      std::printf("iter %5d  Z=%.6g  KL=%s%.5g  %.4fs  grid M=%d\n", it, Z, want_kl ? "" : "n/a ", kl,
                  T.hist.back()[ST_ITER], make_grid(cfg.adaptive, cfg.p, cfg.bw, cfg.min_boxes, cfg.fixed_boxes, bb_.x0, bb_.x1, bb_.y0, bb_.y1, cfg.grid_quant).M);
  }
  CUDA_CHECK(cudaDeviceSynchronize());
  MPI_Barrier(comm_);
  const double t_loop1 = MPI_Wtime();

  // final KL, outside the timed window: one more gradient evaluation at the final coordinates
  // (no update). Collective on all ranks.
  {
    double klf = 0;
    iteration(1, 0, 0, false, true, &klf);
    kl_hist.push_back({cfg.iters, klf});
  }

  // ---- results ----
  std::vector<real> ylocal(2 * (size_t)nloc_);
  CUDA_CHECK(cudaMemcpy(ylocal.data(), d_Y.p + 2 * (size_t)lo_, ylocal.size() * sizeof(real), cudaMemcpyDeviceToHost));
  std::vector<double> yd(ylocal.begin(), ylocal.end());
  double nonfinite = 0;
  for (double v : yd) if (!std::isfinite(v)) nonfinite += 1;
  MPI_Allreduce(MPI_IN_PLACE, &nonfinite, 1, MPI_DOUBLE, MPI_SUM, comm_);
  std::vector<double> Yall;
  if (rank_ == 0) Yall.resize(2 * (size_t)N_);
  MPI_Gatherv(yd.data(), 2 * nloc_, MPI_DOUBLE, Yall.data(), ag_cnt_.data(), ag_dsp_.data(), MPI_DOUBLE, 0, comm_);

  // timing: per-iteration maximum and minimum over ranks, per-rank steady-state totals
  const int nit = (int)T.hist.size();
  std::vector<double> flat((size_t)nit * NSTAGE), tmax(flat.size()), tmin(flat.size());
  for (int i = 0; i < nit; ++i)
    for (int s = 0; s < NSTAGE; ++s) flat[(size_t)i * NSTAGE + s] = T.hist[i][s];
  MPI_Reduce(flat.data(), tmax.data(), (int)flat.size(), MPI_DOUBLE, MPI_MAX, 0, comm_);
  MPI_Reduce(flat.data(), tmin.data(), (int)flat.size(), MPI_DOUBLE, MPI_MIN, 0, comm_);
  std::vector<double> mytot(NSTAGE, 0.0), alltot((size_t)NSTAGE * P_);
  const int w0 = std::min(cfg.warmup, std::max(nit - 1, 0));
  for (int i = w0; i < nit; ++i)
    for (int s = 0; s < NSTAGE; ++s) mytot[s] += T.hist[i][s];
  MPI_Gather(mytot.data(), NSTAGE, MPI_DOUBLE, alltot.data(), NSTAGE, MPI_DOUBLE, 0, comm_);
  double loop_s = t_loop1 - t_loop0, loop_max = 0;
  MPI_Reduce(&loop_s, &loop_max, 1, MPI_DOUBLE, MPI_MAX, 0, comm_);
  double byt[5] = {bytes_grid_, bytes_exch_recv_, bytes_exch_send_, bytes_fft_, bytes_pot_}, byt_max[5];
  MPI_Reduce(byt, byt_max, 5, MPI_DOUBLE, MPI_MAX, 0, comm_);
  size_t free2 = 0, total2 = 0;
  CUDA_CHECK(cudaMemGetInfo(&free2, &total2));  // after the loop: includes cuFFT work areas
  double mem_in[2] = {(double)(total2 - free2), (double)free0 - (double)free2}, mem_max[2];
  MPI_Reduce(mem_in, mem_max, 2, MPI_DOUBLE, MPI_MAX, 0, comm_);
  double ptime_in[3] = {plan_t_alloc_, plan_t_cufft_, plan_t_spec_}, ptime_max[3];
  MPI_Reduce(ptime_in, ptime_max, 3, MPI_DOUBLE, MPI_MAX, 0, comm_);
  (void)free1; (void)total1;
  int rebuilds = plan_rebuilds_;

  if (rank_ == 0) {
    std::vector<double> Yo(2 * (size_t)N_);
    for (int64_t i = 0; i < N_; ++i) {
      Yo[2 * (int64_t)pm.perm[i]] = Yall[2 * i];
      Yo[2 * (int64_t)pm.perm[i] + 1] = Yall[2 * i + 1];
    }
    write_embedding(cfg.out + "/embedding.bin", N_, Yo);

    for (int which = 0; which < 2; ++which) {
      FILE* f = xfopen(cfg.out + (which == 0 ? "/timing.csv" : "/timing_min.csv"), "w");
      std::fprintf(f, "iter");
      for (int s = 0; s < NSTAGE; ++s) std::fprintf(f, ",%s", STAGE_NAME[s]);
      std::fprintf(f, "\n");
      const std::vector<double>& src = which == 0 ? tmax : tmin;
      for (int i = 0; i < nit; ++i) {
        std::fprintf(f, "%d", i);
        for (int s = 0; s < NSTAGE; ++s) std::fprintf(f, ",%.6g", src[(size_t)i * NSTAGE + s]);
        std::fprintf(f, "\n");
      }
      std::fclose(f);
    }
    {
      FILE* f = xfopen(cfg.out + "/timing_ranks.csv", "w");
      std::fprintf(f, "rank");
      for (int s = 0; s < NSTAGE; ++s) std::fprintf(f, ",%s", STAGE_NAME[s]);
      std::fprintf(f, "\n");
      for (int r = 0; r < P_; ++r) {
        std::fprintf(f, "%d", r);
        for (int s = 0; s < NSTAGE; ++s) std::fprintf(f, ",%.6g", alltot[(size_t)r * NSTAGE + s]);
        std::fprintf(f, "\n");
      }
      std::fclose(f);
    }
    {
      FILE* f = xfopen(cfg.out + "/kl.csv", "w");
      std::fprintf(f, "iter,kl\n");
      for (auto& e : kl_hist) std::fprintf(f, "%d,%.9g\n", e.first, e.second);
      std::fclose(f);
    }

    // steady state: skip warm-up iterations and iterations in which the FFT plan was rebuilt
    // "steady" statistics: for every iteration the slowest rank counts (max over the ranks, tmax); the mean is taken over the iterations after the
    // first `warmup` ones, WITHOUT the iterations in which a plan was (re)built (ST_PLAN > 0) or the KL divergence was computed (ST_KL > 0).
    // With an adaptive grid the plan rebuilds are therefore not in seconds_per_iter_steady; they are reported in plan_total_seconds and in
    // loop_seconds (the whole loop). timing.csv holds the per-iteration max over the ranks, timing_min.csv the min, timing_ranks.csv the per-rank totals.
    std::vector<double> mean(NSTAGE, 0.0);
    int cnt = 0, skipped_plan = 0, skipped_kl = 0;
    for (int i = w0; i < nit; ++i) {
      if (tmax[(size_t)i * NSTAGE + ST_PLAN] > 0) { skipped_plan++; continue; }
      if (tmax[(size_t)i * NSTAGE + ST_KL] > 0) { skipped_kl++; continue; }
      for (int s = 0; s < NSTAGE; ++s) mean[s] += tmax[(size_t)i * NSTAGE + s];
      cnt++;
    }
    for (int s = 0; s < NSTAGE; ++s) mean[s] /= std::max(cnt, 1);
    double plan_total = 0, kl_total = 0;
    for (int i = 0; i < nit; ++i) {
      plan_total += tmax[(size_t)i * NSTAGE + ST_PLAN];
      kl_total += tmax[(size_t)i * NSTAGE + ST_KL];
    }

    JsonOut js;
    js.add("program", "tsne_gpu");
    js.add("precision", sizeof(real) == 8 ? "double" : "float");
    js.add("emulated",
#ifdef TSNE_EMULATE
           1
#else
           0
#endif
    );
    js.add("data", cfg.data);
    js.add("N", (long long)N_);
    js.add("k", k);
    js.add("P", P_);
    js.add("ranks_per_node", local_size);
    js.add("gpu", prop.name);
    js.add("order", cfg.order);
    js.add("exchange", cfg.exchange);
    js.add("comm", cfg.comm);
    js.add("grid_comm", cfg.grid_comm);
    js.add("transport", cfg.transport);
    js.add("progress", cfg.progress);
    js.add("fft", cfg.fft);
    js.add("mpi_cuda_aware", cuda_aware ? 1 : 0);
    js.add("block", cfg.block);
    js.add("order_p", cfg.p);
    js.add("bw", cfg.bw);
    js.add("grid_mode", cfg.adaptive ? "adaptive" : "fixed");
    js.add("overlap_near", cfg.overlap_near ? "on" : "off");
    js.add("iters", cfg.iters);
    js.add("lr", lr);
    js.add("perplexity", cfg.perplexity);
    js.add("probe", cfg.probe ? 1 : 0);
    js.add("stage_timing", cfg.stage_timing ? 1 : 0);
    js.add("warmup_iters_skipped", w0);
    js.add("plan_iters_skipped", skipped_plan);
    js.add("plan_rebuilds", rebuilds);
    js.add("plan_total_seconds", plan_total);
    js.add("plan_alloc_seconds", ptime_max[0]);   // of plan_total_seconds: buffer allocation
    js.add("plan_cufft_seconds", ptime_max[1]);   //                      : cufftPlanMany / cufftDestroy
    js.add("plan_kspec_seconds", ptime_max[2]);   //                      : kernel spectrum + synchronisation
    js.add("grid_quant", cfg.grid_quant);
    js.add("setup_seconds", t_setup1 - t_setup0);
    js.add("setup_load_seconds", t_load - t_setup0);
    js.add("setup_calibration_seconds", t_calib - t_load);
    js.add("setup_csr_seconds", t_csr - t_calib);
    js.add("loop_seconds", loop_max);                       // includes in-loop KL evaluations, if any
    js.add("loop_seconds_excl_kl", loop_max - kl_total);    // use this for end-to-end speed-ups
    js.add("report_every", cfg.report_every);
    js.add("kl_iters_skipped", skipped_kl);
    js.add("seconds_per_iter_total", (loop_max - kl_total) / std::max(cfg.iters, 1));
    js.add("seconds_per_iter_steady", mean[ST_ITER]);
    for (int s = 0; s < NSTAGE; ++s) js.add(std::string("steady_") + STAGE_NAME[s], mean[s]);
    js.add("ghost_min", st_min[0]);
    js.add("ghost_max", st_max[0]);
    js.add("ghost_mean", st_sum[0] / P_);
    js.add("ghost_fraction_of_N", st_sum[0] / P_ / (double)N_);
    js.add("remote_nnz_fraction_min", st_min[1]);
    js.add("remote_nnz_fraction_max", st_max[1]);
    js.add("send_points_max", st_max[3]);
    js.add("nnz_total", st_sum[2]);
    js.add("bytes_grid_per_iter", byt_max[0] / std::max(cfg.iters, 1));
    js.add("bytes_exch_recv_per_iter", byt_max[1] / std::max(cfg.iters, 1));
    js.add("bytes_exch_send_per_iter", byt_max[2] / std::max(cfg.iters, 1));
    js.add("bytes_fft_transpose_per_iter", byt_max[3] / std::max(cfg.iters, 1));   // distributed FFT: the two Alltoall transposes
    js.add("bytes_pot_allgather_per_iter", byt_max[4] / std::max(cfg.iters, 1));   // distributed FFT: Allgatherv of the potentials
    js.add("gpu_mem_in_use_bytes_max", mem_max[0]);       // whole device incl. CUDA context
    js.add("gpu_mem_allocated_by_run_bytes_max", mem_max[1]);  // allocated since before the upload
    js.add("nonfinite_coordinates", nonfinite);
    js.add("final_kl", kl_hist.empty() ? 0.0 : kl_hist.back().second);
    js.add("final_grid_nodes_per_dim", (long long)make_grid(cfg.adaptive, cfg.p, cfg.bw, cfg.min_boxes, cfg.fixed_boxes, bb_.x0, bb_.x1, bb_.y0, bb_.y1, cfg.grid_quant).M);
    js.add("config_label", flag_str(cfg.exchange, cfg.comm) + "|" + cfg.grid_comm + "|" + cfg.transport + "|" + cfg.progress + (dist_() ? "|dist" : ""));
    js.write(cfg.out + "/summary.json");
    std::printf("done: %d iterations, loop %.3fs (%.4f s/iter total, %.4f s/iter steady), nonfinite=%g\n", cfg.iters,
                loop_max, loop_max / std::max(cfg.iters, 1), mean[ST_ITER], nonfinite);
  }
  MPI_Finalize();
  return 0;
}
