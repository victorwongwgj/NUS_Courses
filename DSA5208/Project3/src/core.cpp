// core.cpp -- non-template implementation shared by every program: binary dataset I/O + PCA (declared in the
// "dataset" part of tsne_common.h), and point ordering / perplexity calibration / symmetrised P (the "problem" part).
#include "tsne_common.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <numeric>

// ====================================================================================================
// PART: dataset I/O and PCA
// ====================================================================================================
static const int64_t MAGIC_FEAT = 0x54534e4546454131LL;
static const int64_t MAGIC_LABL = 0x54534e454c424c31LL;
static const int64_t MAGIC_DS = 0x54534e4544533031LL;
static const int64_t MAGIC_EMB = 0x54534e45454d4231LL;
static const int64_t MAGIC_GRD = 0x54534e4547524431LL;

// fwrite/fread of large arrays in chunks (a single call >2GB is not portable everywhere).
static void wr(FILE* f, const void* p, size_t bytes) {
  const char* c = (const char*)p;
  while (bytes) {
    size_t n = std::min<size_t>(bytes, 1u << 28);
    if (std::fwrite(c, 1, n, f) != n) die("write error");
    c += n;
    bytes -= n;
  }
}
static void rd(FILE* f, void* p, size_t bytes, const std::string& what) {
  char* c = (char*)p;
  while (bytes) {
    size_t n = std::min<size_t>(bytes, 1u << 28);
    if (std::fread(c, 1, n, f) != n) die("short read while reading " + what);
    c += n;
    bytes -= n;
  }
}
static void expect_magic(FILE* f, int64_t magic, const std::string& path) {
  int64_t m = 0;
  rd(f, &m, 8, path);
  if (m != magic) die("bad file magic (wrong file type?): " + path);
}

void write_features(const std::string& path, const Features& f) {
  FILE* o = xfopen(path, "wb");
  int64_t h[3] = {MAGIC_FEAT, f.N, f.D};
  wr(o, h, sizeof h);
  wr(o, f.x.data(), f.x.size() * sizeof(float));
  std::fclose(o);
}
void read_features(const std::string& path, Features& f) {
  FILE* i = xfopen(path, "rb");
  expect_magic(i, MAGIC_FEAT, path);
  rd(i, &f.N, 8, path);
  rd(i, &f.D, 8, path);
  f.x.resize((size_t)f.N * f.D);
  rd(i, f.x.data(), f.x.size() * sizeof(float), path);
  std::fclose(i);
}
void write_labels(const std::string& path, const std::vector<int32_t>& l) {
  FILE* o = xfopen(path, "wb");
  int64_t h[2] = {MAGIC_LABL, (int64_t)l.size()};
  wr(o, h, sizeof h);
  wr(o, l.data(), l.size() * 4);
  std::fclose(o);
}
void read_labels(const std::string& path, std::vector<int32_t>& l) {
  FILE* i = xfopen(path, "rb");
  expect_magic(i, MAGIC_LABL, path);
  int64_t n = 0;
  rd(i, &n, 8, path);
  l.resize(n);
  rd(i, l.data(), (size_t)n * 4, path);
  std::fclose(i);
}
void write_dataset(const std::string& path, const Dataset& d) {
  FILE* o = xfopen(path, "wb");
  int64_t h[3] = {MAGIC_DS, d.N, (int64_t)d.k};
  wr(o, h, sizeof h);
  wr(o, d.idx.data(), d.idx.size() * 4);
  wr(o, d.d2.data(), d.d2.size() * 4);
  wr(o, d.pc1.data(), d.pc1.size() * 4);
  wr(o, d.label.data(), d.label.size() * 4);
  std::fclose(o);
}
void read_dataset(const std::string& path, Dataset& d) {
  FILE* i = xfopen(path, "rb");
  expect_magic(i, MAGIC_DS, path);
  int64_t k = 0;
  rd(i, &d.N, 8, path);
  rd(i, &k, 8, path);
  d.k = (int)k;
  size_t nk = (size_t)d.N * d.k;
  d.idx.resize(nk);
  d.d2.resize(nk);
  d.pc1.resize(d.N);
  d.label.resize(d.N);
  rd(i, d.idx.data(), nk * 4, path);
  rd(i, d.d2.data(), nk * 4, path);
  rd(i, d.pc1.data(), (size_t)d.N * 4, path);
  rd(i, d.label.data(), (size_t)d.N * 4, path);
  std::fclose(i);
}
void write_embedding(const std::string& path, int64_t N, const std::vector<double>& y) {
  FILE* o = xfopen(path, "wb");
  int64_t h[2] = {MAGIC_EMB, N};
  wr(o, h, sizeof h);
  wr(o, y.data(), (size_t)N * 2 * 8);
  std::fclose(o);
}
void read_embedding(const std::string& path, int64_t N, std::vector<double>& y) {
  FILE* i = xfopen(path, "rb");
  expect_magic(i, MAGIC_EMB, path);
  int64_t n = 0;
  rd(i, &n, 8, path);
  if (N > 0 && n != N) die("embedding size mismatch in " + path);
  y.resize((size_t)n * 2);
  rd(i, y.data(), (size_t)n * 16, path);
  std::fclose(i);
}
void write_grad(const std::string& path, int64_t N, double Z, const std::vector<double>& attr,
                const std::vector<double>& rep, const std::vector<double>& grad) {
  FILE* o = xfopen(path, "wb");
  int64_t h[2] = {MAGIC_GRD, N};
  wr(o, h, sizeof h);
  wr(o, &Z, 8);
  wr(o, attr.data(), (size_t)N * 16);
  wr(o, rep.data(), (size_t)N * 16);
  wr(o, grad.data(), (size_t)N * 16);
  std::fclose(o);
}
void read_grad(const std::string& path, int64_t& N, double& Z, std::vector<double>& attr,
               std::vector<double>& rep, std::vector<double>& grad) {
  FILE* i = xfopen(path, "rb");
  expect_magic(i, MAGIC_GRD, path);
  rd(i, &N, 8, path);
  rd(i, &Z, 8, path);
  attr.resize((size_t)N * 2);
  rep.resize((size_t)N * 2);
  grad.resize((size_t)N * 2);
  rd(i, attr.data(), (size_t)N * 16, path);
  rd(i, rep.data(), (size_t)N * 16, path);
  rd(i, grad.data(), (size_t)N * 16, path);
  std::fclose(i);
}

// Power iteration for the leading eigenvector of the covariance matrix X^T X (X centred).
void compute_pc1(const Features& f, std::vector<float>& pc1, int iters, uint64_t seed) {
  const int64_t N = f.N, D = f.D;
  std::vector<double> mean(D, 0.0), v(D), w(D);
  for (int64_t i = 0; i < N; ++i)
    for (int64_t d = 0; d < D; ++d) mean[d] += f.x[i * D + d];
  for (int64_t d = 0; d < D; ++d) mean[d] /= (double)N;
  for (int64_t d = 0; d < D; ++d) v[d] = gaussian_at(seed, (uint64_t)d);
  for (int it = 0; it < iters; ++it) {
    double norm = 0;
    for (double x : v) norm += x * x;
    norm = std::sqrt(norm);
    for (double& x : v) x /= norm;
    std::fill(w.begin(), w.end(), 0.0);
    // w = X^T (X v), accumulated row by row.
#ifdef _OPENMP
#pragma omp parallel
    {
      std::vector<double> wl(D, 0.0);
#pragma omp for schedule(static)
      for (int64_t i = 0; i < N; ++i) {
        double s = 0;
        for (int64_t d = 0; d < D; ++d) s += (f.x[i * D + d] - mean[d]) * v[d];
        for (int64_t d = 0; d < D; ++d) wl[d] += s * (f.x[i * D + d] - mean[d]);
      }
#pragma omp critical
      for (int64_t d = 0; d < D; ++d) w[d] += wl[d];
    }
#else
    for (int64_t i = 0; i < N; ++i) {
      double s = 0;
      for (int64_t d = 0; d < D; ++d) s += (f.x[i * D + d] - mean[d]) * v[d];
      for (int64_t d = 0; d < D; ++d) w[d] += s * (f.x[i * D + d] - mean[d]);
    }
#endif
    v = w;
  }
  double norm = 0;
  for (double x : v) norm += x * x;
  norm = std::sqrt(norm);
  if (norm == 0) norm = 1;
  for (double& x : v) x /= norm;
  pc1.resize(N);
  for (int64_t i = 0; i < N; ++i) {
    double s = 0;
    for (int64_t d = 0; d < D; ++d) s += (f.x[i * D + d] - mean[d]) * v[d];
    pc1[i] = (float)s;
  }
}

// ====================================================================================================
// PART: problem construction
// ====================================================================================================
Permutation make_permutation(const Dataset& ds, const std::string& order, uint64_t seed) {
  const int64_t N = ds.N;
  Permutation pm;
  pm.perm.resize(N);
  pm.inv.resize(N);
  std::iota(pm.perm.begin(), pm.perm.end(), 0);
  if (order == "pc1") {
    std::stable_sort(pm.perm.begin(), pm.perm.end(),
                     [&](int32_t a, int32_t b) { return ds.pc1[a] < ds.pc1[b]; });
  } else if (order == "random") {
    // Fisher-Yates with a counter-based RNG so the shuffle is reproducible.
    for (int64_t i = N - 1; i > 0; --i) {
      int64_t j = (int64_t)(uniform01(seed, (uint64_t)i, 77) * (double)(i + 1));
      if (j > i) j = i;
      std::swap(pm.perm[i], pm.perm[j]);
    }
  } else if (order != "none") {
    die("unknown --order " + order + " (use pc1|random|none)");
  }
  for (int64_t i = 0; i < N; ++i) pm.inv[pm.perm[i]] = (int32_t)i;
  return pm;
}

void calibrate_row(const float* d2, int k, double perplexity, double* out) {
  const double target = std::log(perplexity);
  double dmin = d2[0];
  for (int t = 1; t < k; ++t) dmin = std::min<double>(dmin, d2[t]);  // shift avoids underflow
  double beta = 1.0, lo = 0.0, hi = INFINITY;
  for (int it = 0; it < 200; ++it) {
    double sum = 0, sumd = 0;
    for (int t = 0; t < k; ++t) {
      double e = std::exp(-beta * ((double)d2[t] - dmin));
      out[t] = e;
      sum += e;
      sumd += ((double)d2[t] - dmin) * e;
    }
    double H = std::log(sum) + beta * sumd / sum;  // entropy in nats
    double diff = H - target;
    if (std::fabs(diff) < 1e-6) break;
    if (diff > 0) {  // entropy too high => distribution too flat => increase precision
      lo = beta;
      beta = std::isinf(hi) ? beta * 2.0 : 0.5 * (beta + hi);
    } else {
      hi = beta;
      beta = 0.5 * (beta + lo);
    }
  }
  double sum = 0;
  for (int t = 0; t < k; ++t) {
    out[t] = std::exp(-beta * ((double)d2[t] - dmin));
    sum += out[t];
  }
  for (int t = 0; t < k; ++t) out[t] /= sum;
}

SymCSR build_sym_rows(const Dataset& ds, const Permutation& pm, const std::vector<float>& cond,
                      int64_t lo, int64_t hi) {
  const int64_t N = ds.N;
  const int k = ds.k;
  const int64_t nloc = hi - lo;
  // Pass 1: count entries per local row (k forward edges + incoming reverse edges).
  std::vector<int64_t> cnt(nloc, (int64_t)k);
  for (int64_t jn = 0; jn < N; ++jn) {
    const int32_t jo = pm.perm[jn];
    const int32_t* row = &ds.idx[(size_t)jo * k];
    for (int t = 0; t < k; ++t) {
      int64_t in = pm.inv[row[t]];
      if (in >= lo && in < hi) cnt[in - lo]++;
    }
  }
  std::vector<int64_t> start(nloc + 1, 0);
  for (int64_t i = 0; i < nloc; ++i) start[i + 1] = start[i] + cnt[i];
  std::vector<int32_t> ecol(start[nloc]);
  std::vector<double> ew(start[nloc]);
  std::vector<int64_t> pos(start.begin(), start.end() - 1);
  // Pass 2: fill forward and reverse entries.
  for (int64_t i = lo; i < hi; ++i) {
    const int32_t io = pm.perm[i];
    for (int t = 0; t < k; ++t) {
      int64_t q = pos[i - lo]++;
      ecol[q] = pm.inv[ds.idx[(size_t)io * k + t]];
      ew[q] = cond[(size_t)i * k + t];
    }
  }
  for (int64_t jn = 0; jn < N; ++jn) {
    const int32_t jo = pm.perm[jn];
    const int32_t* row = &ds.idx[(size_t)jo * k];
    for (int t = 0; t < k; ++t) {
      int64_t in = pm.inv[row[t]];
      if (in >= lo && in < hi) {
        int64_t q = pos[in - lo]++;
        ecol[q] = (int32_t)jn;
        ew[q] = cond[(size_t)jn * k + t];
      }
    }
  }
  // Pass 3: per row sort by column and merge duplicates (edge present in both directions).
  SymCSR out;
  out.nrows = nloc;
  out.rowptr.assign(nloc + 1, 0);
  out.col.reserve(start[nloc]);
  out.val.reserve(start[nloc]);
  std::vector<std::pair<int32_t, double>> tmp;
  const double scale = 1.0 / (2.0 * (double)N);
  for (int64_t i = 0; i < nloc; ++i) {
    tmp.clear();
    for (int64_t q = start[i]; q < start[i + 1]; ++q) tmp.push_back({ecol[q], ew[q]});
    std::sort(tmp.begin(), tmp.end(),
              [](const std::pair<int32_t, double>& a, const std::pair<int32_t, double>& b) {
                return a.first < b.first;
              });
    for (size_t a = 0; a < tmp.size();) {
      size_t b = a;
      double s = 0;
      while (b < tmp.size() && tmp[b].first == tmp[a].first) s += tmp[b++].second;
      // Entries that underflowed to exactly 0 (far neighbours with a very peaked Gaussian) carry no
      // force and would give 0*log(0) in the KL, so they are dropped. A self edge never occurs for
      // kNN graphs; the check is defensive.
      if (tmp[a].first != (int32_t)(i + lo) && s > 0) {
        out.col.push_back(tmp[a].first);
        out.val.push_back(s * scale);
      }
      a = b;
    }
    out.rowptr[i + 1] = (int64_t)out.col.size();
  }
  return out;
}

void split_local_remote(const SymCSR& all, int64_t lo, int64_t hi, SymCSR& local, SymCSR& remote) {
  local.nrows = remote.nrows = all.nrows;
  local.rowptr.assign(all.nrows + 1, 0);
  remote.rowptr.assign(all.nrows + 1, 0);
  local.col.clear(); local.val.clear(); remote.col.clear(); remote.val.clear();
  for (int64_t i = 0; i < all.nrows; ++i) {
    for (int64_t e = all.rowptr[i]; e < all.rowptr[i + 1]; ++e) {
      int32_t c = all.col[e];
      if (c >= lo && c < hi) {
        local.col.push_back(c);
        local.val.push_back(all.val[e]);
      } else {
        remote.col.push_back(c);
        remote.val.push_back(all.val[e]);
      }
    }
    local.rowptr[i + 1] = (int64_t)local.col.size();
    remote.rowptr[i + 1] = (int64_t)remote.col.size();
  }
}

std::vector<int32_t> unique_columns(const SymCSR& m) {
  std::vector<int32_t> u(m.col.begin(), m.col.end());
  std::sort(u.begin(), u.end());
  u.erase(std::unique(u.begin(), u.end()), u.end());
  return u;
}
