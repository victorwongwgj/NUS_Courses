// tools.cpp -- all small CPU command-line utilities in one multi-command binary (build/tsne_tools).
//
//   tsne_tools gen-data     synthetic Gaussian-mixture data sets (data generation, all scaling studies)
//   tsne_tools prep-cpu     exact brute-force kNN graph + PC1 on the CPU (preprocessing, N up to ~2e5; GPU version: prep_gpu)
//   tsne_tools eval         embedding quality on a random sample: kNN recall, trustworthiness, label purity
//   tsne_tools compare-grad compare two grad.bin files (parallel-consistency gate, exact-gradient validation V1/V2)
//   tsne_tools fitsne-io    converters to/from the official FIt-SNE (KlugerLab) binary files (comparison O1)
//
// The documentation of every sub-command follows.
#include <cstdio>
#include <map>
#include <string>
#include <vector>
#include <queue>

#include "tsne_common.h"


// ----------------------------------------------------------------------------------------------------
// sub-command: gen-data
// ----------------------------------------------------------------------------------------------------
// gen-data — synthetic Gaussian-mixture data for scaling and write-conflict experiments.
//
//   gen_data --n 1000000 --dim 50 --clusters 20 --spacing 6 --seed 1 --out data/g1m
//
// writes data/g1m.feat.bin and data/g1m.labels.bin.
//   cluster centres ~ N(0, spacing^2 I_dim);  points = centre + N(0, I_dim)
// --spacing controls how clustered the data is (near: ~2, medium: ~6, far: ~12), which
// controls how much the embedding points pile up on the same grid cells (study C).
// --sizes zipf makes cluster sizes unequal (weight 1/(c+1)), --sizes equal (default) does not.
// Everything is a pure function of (seed, index), so the file is identical for any thread count.
static int cmd_gen_data(int argc, char** argv) {
  Args a(argc, argv);
  const int64_t N = a.integer("n", 100000);
  const int64_t D = a.integer("dim", 50);
  const int K = (int)a.integer("clusters", 20);
  const double spacing = a.num("spacing", 6.0);
  const uint64_t seed = (uint64_t)a.integer("seed", 1);
  const std::string sizes = a.str("sizes", "equal");
  const std::string out = a.str("out", "data/synthetic");
  for (auto& u : a.unused()) std::fprintf(stderr, "warning: unused option --%s\n", u.c_str());

  std::vector<double> centre((size_t)K * D);
  for (int c = 0; c < K; ++c)
    for (int64_t d = 0; d < D; ++d) centre[(size_t)c * D + d] = spacing * gaussian_at(seed + 1000, (uint64_t)c * D + d);
  std::vector<double> cum(K);
  double tot = 0;
  for (int c = 0; c < K; ++c) {
    tot += (sizes == "zipf") ? 1.0 / (c + 1) : 1.0;
    cum[c] = tot;
  }

  Features f;
  f.N = N;
  f.D = D;
  f.x.resize((size_t)N * D);
  std::vector<int32_t> label(N);
#ifdef _OPENMP
#pragma omp parallel for schedule(static)
#endif
  for (int64_t i = 0; i < N; ++i) {
    double u = uniform01(seed, (uint64_t)i, 5) * tot;
    int c = (int)(std::lower_bound(cum.begin(), cum.end(), u) - cum.begin());
    if (c >= K) c = K - 1;
    label[i] = c;
    for (int64_t d = 0; d < D; ++d)
      f.x[(size_t)i * D + d] = (float)(centre[(size_t)c * D + d] + gaussian_at(seed, (uint64_t)i * D + d));
  }
  write_features(out + ".feat.bin", f);
  write_labels(out + ".labels.bin", label);
  std::printf("wrote %s.feat.bin (N=%lld D=%lld) and %s.labels.bin (%d clusters)\n", out.c_str(),
              (long long)N, (long long)D, out.c_str(), K);
  return 0;
}

// ----------------------------------------------------------------------------------------------------
// sub-command: prep-cpu
// ----------------------------------------------------------------------------------------------------
// prep-cpu — exact brute-force kNN graph + PC1 on the CPU (for small/medium N, and as the
// reference for prep_gpu).
//
//   prep_cpu --feat data/g.feat.bin --labels data/g.labels.bin --k 90 --out data/g.ds.bin
//
// Output: dataset file with the exact k nearest neighbours (self excluded) of every point,
// sorted by squared distance, plus the first principal component projection and the labels.
// Cost is O(N^2 D); use prep_gpu for N beyond a few 100k.
static int cmd_prep_cpu(int argc, char** argv) {
  Args a(argc, argv);
  const std::string featp = a.str("feat", "");
  const std::string labp = a.str("labels", "");
  const std::string outp = a.str("out", "data/dataset.ds.bin");
  const int k = (int)a.integer("k", 90);
  for (auto& u : a.unused()) std::fprintf(stderr, "warning: unused option --%s\n", u.c_str());
  if (featp.empty()) die("--feat is required");

  Features f;
  read_features(featp, f);
  const int64_t N = f.N, D = f.D;
  if (k >= N) die("k must be smaller than N");
  Dataset ds;
  ds.N = N;
  ds.k = k;
  ds.idx.resize((size_t)N * k);
  ds.d2.resize((size_t)N * k);
  ds.label.assign(N, -1);
  if (!labp.empty()) read_labels(labp, ds.label);

  double t0 = wall_time();
  compute_pc1(f, ds.pc1);
  double t1 = wall_time();

#ifdef _OPENMP
#pragma omp parallel
#endif
  {
    std::vector<std::pair<float, int32_t>> cand(N);
#ifdef _OPENMP
#pragma omp for schedule(dynamic, 16)
#endif
    for (int64_t i = 0; i < N; ++i) {
      const float* xi = &f.x[(size_t)i * D];
      for (int64_t j = 0; j < N; ++j) {
        const float* xj = &f.x[(size_t)j * D];
        float s = 0;
        for (int64_t d = 0; d < D; ++d) {
          float t = xi[d] - xj[d];
          s += t * t;
        }
        cand[j] = {j == i ? INFINITY : s, (int32_t)j};
      }
      std::partial_sort(cand.begin(), cand.begin() + k, cand.end());
      for (int t = 0; t < k; ++t) {
        ds.idx[(size_t)i * k + t] = cand[t].second;
        ds.d2[(size_t)i * k + t] = cand[t].first;
      }
    }
  }
  double t2 = wall_time();
  write_dataset(outp, ds);
  std::printf("prep_cpu: N=%lld D=%lld k=%d  pc1 %.2fs  knn %.2fs  -> %s\n", (long long)N, (long long)D, k,
              t1 - t0, t2 - t1, outp.c_str());
  return 0;
}

// ----------------------------------------------------------------------------------------------------
// sub-command: eval
// ----------------------------------------------------------------------------------------------------
// eval — quality metrics of an embedding, computed on a random sample of query points.
//
//   eval --feat data/g.feat.bin --data data/g.ds.bin --emb out/run/embedding.bin
//        [--sample 2000] [--k 15] [--seed 7] [--json out/run/quality.json]
//
// For every sampled point i the metrics compare its k nearest neighbours in the original
// feature space (H_i) with its k nearest neighbours in the 2-D embedding (U_i), both found by
// exact search over ALL N points:
//   knn_recall      mean |H_i ∩ U_i| / k
//   trustworthiness 1 - 2/(k (2N-3k-1)) * mean_i  sum_{j in U_i \ H_i} (r_i(j) - k)
//                   r_i(j) = rank of j among the neighbours of i in feature space (1 = nearest)
//   label_purity    mean fraction of U_i that has the same label as i (labels from the dataset
//                   file; skipped if all labels are -1)
// Sampling keeps the cost at O(sample * N * D). Compare runs against the spread between random
// seeds, not against each other point-by-point (t-SNE embeddings are only defined up to
// rotation, reflection and chaotic differences between runs).
static int cmd_eval(int argc, char** argv) {
  Args a(argc, argv);
  const std::string featp = a.str("feat", ""), dsp = a.str("data", ""), embp = a.str("emb", "");
  const std::string jsonp = a.str("json", "");
  const int m = (int)a.integer("sample", 2000);
  const int k = (int)a.integer("k", 15);
  const uint64_t seed = (uint64_t)a.integer("seed", 7);
  for (auto& u : a.unused()) std::fprintf(stderr, "warning: unused option --%s\n", u.c_str());
  if (featp.empty() || embp.empty()) die("--feat and --emb are required");

  Features f;
  read_features(featp, f);
  const int64_t N = f.N, D = f.D;
  std::vector<double> y;
  read_embedding(embp, N, y);
  std::vector<int32_t> label(N, -1);
  if (!dsp.empty()) {
    Dataset ds;
    read_dataset(dsp, ds);
    label = ds.label;
  }
  bool have_labels = false;
  for (int32_t l : label) if (l >= 0) { have_labels = true; break; }

  // distinct sample of query points
  std::vector<int64_t> pick(N);
  for (int64_t i = 0; i < N; ++i) pick[i] = i;
  const int ms = (int)std::min<int64_t>(m, N);
  for (int i = 0; i < ms; ++i) {
    int64_t j = i + (int64_t)(uniform01(seed, (uint64_t)i, 11) * (double)(N - i));
    if (j >= N) j = N - 1;
    std::swap(pick[i], pick[j]);
  }

  double sum_recall = 0, sum_pen = 0, sum_pur = 0;
#ifdef _OPENMP
#pragma omp parallel
#endif
  {
    std::vector<float> dh(N), dl(N);
    std::vector<int32_t> order(N);
#ifdef _OPENMP
#pragma omp for schedule(dynamic, 4) reduction(+ : sum_recall, sum_pen, sum_pur)
#endif
    for (int s = 0; s < ms; ++s) {
      const int64_t i = pick[s];
      const float* xi = &f.x[(size_t)i * D];
      for (int64_t j = 0; j < N; ++j) {
        const float* xj = &f.x[(size_t)j * D];
        float d = 0;
        for (int64_t c = 0; c < D; ++c) { float t = xi[c] - xj[c]; d += t * t; }
        dh[j] = d;
        double ex = y[2 * i] - y[2 * j], ey = y[2 * i + 1] - y[2 * j + 1];
        dl[j] = (float)(ex * ex + ey * ey);
      }
      dh[i] = dl[i] = INFINITY;  // exclude self
      for (int64_t j = 0; j < N; ++j) order[j] = (int32_t)j;
      // high-dimensional k nearest
      std::nth_element(order.begin(), order.begin() + k, order.end(), [&](int32_t p, int32_t q) { return dh[p] < dh[q]; });
      std::vector<int32_t> H(order.begin(), order.begin() + k);
      std::sort(H.begin(), H.end());
      // embedding k nearest
      for (int64_t j = 0; j < N; ++j) order[j] = (int32_t)j;
      std::nth_element(order.begin(), order.begin() + k, order.end(), [&](int32_t p, int32_t q) { return dl[p] < dl[q]; });
      std::vector<int32_t> U(order.begin(), order.begin() + k);
      int inter = 0, same = 0;
      double pen = 0;
      for (int32_t j : U) {
        if (std::binary_search(H.begin(), H.end(), j)) {
          inter++;
        } else {
          // rank of j among the feature-space neighbours of i: 1 + number of points closer than j
          int64_t closer = 0;
          for (int64_t q = 0; q < N; ++q) if (dh[q] < dh[j]) closer++;
          pen += (double)(closer + 1 - k);
        }
        if (have_labels && label[j] == label[i]) same++;
      }
      sum_recall += (double)inter / k;
      sum_pen += pen;
      sum_pur += (double)same / k;
    }
  }
  const double recall = sum_recall / ms;
  const double trust = 1.0 - 2.0 / ((double)k * (2.0 * N - 3.0 * k - 1.0)) * (sum_pen / ms);
  const double purity = have_labels ? sum_pur / ms : -1.0;
  std::printf("eval: N=%lld sample=%d k=%d  knn_recall=%.4f  trustworthiness=%.4f  label_purity=%.4f\n", (long long)N, ms, k,
              recall, trust, purity);
  if (!jsonp.empty()) {
    JsonOut js;
    js.add("N", (long long)N);
    js.add("sample", ms);
    js.add("k", k);
    js.add("knn_recall", recall);
    js.add("trustworthiness", trust);
    js.add("label_purity", purity);
    js.write(jsonp);
  }
  return 0;
}

// ----------------------------------------------------------------------------------------------------
// sub-command: compare-grad
// ----------------------------------------------------------------------------------------------------
// compare-grad — compare two grad.bin files (reference vs candidate).
//
//   compare_grad ref/grad.bin test/grad.bin [--tol-grad 1e-10] [--tol-attr 1e-10] [--tol-rep 1e-10]
//                [--tol-z 1e-10]
//
// Prints the relative L2 error of the attractive force, the repulsive force, the total gradient
// and Z, plus the largest absolute difference. Exit code 1 if a tolerance is exceeded (a
// tolerance of 0 disables that check). Use loose tolerances (~1e-2) when comparing the
// FFT-accelerated gradient with the exact one, tight ones (1e-10) for parallel consistency.
static double grad_rel_l2(const std::vector<double>& a, const std::vector<double>& b, double& maxabs) {
  double num = 0, den = 0;
  maxabs = 0;
  for (size_t i = 0; i < a.size(); ++i) {
    double d = a[i] - b[i];
    num += d * d;
    den += a[i] * a[i];
    maxabs = std::max(maxabs, std::fabs(d));
  }
  return std::sqrt(num / std::max(den, 1e-300));
}

static int cmd_compare_grad(int argc, char** argv) {
  if (argc < 3) die("usage: compare_grad ref.bin test.bin [--tol-grad t] [--tol-attr t] [--tol-rep t] [--tol-z t]");
  std::string pa = argv[1], pb = argv[2];
  Args a(argc - 2, argv + 2);
  const double tg = a.num("tol-grad", 0), ta = a.num("tol-attr", 0), tr = a.num("tol-rep", 0), tz = a.num("tol-z", 0);
  int64_t Na, Nb;
  double Za, Zb;
  std::vector<double> aa, ra, ga, ab, rb, gb;
  read_grad(pa, Na, Za, aa, ra, ga);
  read_grad(pb, Nb, Zb, ab, rb, gb);
  if (Na != Nb) die("N differs between the two files");
  double m1, m2, m3;
  double e_attr = grad_rel_l2(aa, ab, m1), e_rep = grad_rel_l2(ra, rb, m2), e_grad = grad_rel_l2(ga, gb, m3);
  double e_z = std::fabs(Za - Zb) / std::fabs(Za);
  std::printf("N=%lld  Z_ref=%.12g Z_test=%.12g  rel(Z)=%.3e\n", (long long)Na, Za, Zb, e_z);
  std::printf("rel L2 attr=%.3e (max|d|=%.2e)  rep=%.3e (max|d|=%.2e)  grad=%.3e (max|d|=%.2e)\n", e_attr, m1, e_rep,
              m2, e_grad, m3);
  bool bad = false;
  if (ta > 0 && e_attr > ta) bad = true;
  if (tr > 0 && e_rep > tr) bad = true;
  if (tg > 0 && e_grad > tg) bad = true;
  if (tz > 0 && e_z > tz) bad = true;
  std::printf(bad ? "RESULT: FAIL\n" : "RESULT: PASS\n");
  return bad ? 1 : 0;
}

// ----------------------------------------------------------------------------------------------------
// sub-command: fitsne-io
// ----------------------------------------------------------------------------------------------------
// fitsne-io — converters between this project's files and the official FIt-SNE (KlugerLab) binary's input/output.
//
//   fitsne_io to-fitsne   --feat data/g.feat.bin --out run/data.dat [--perp 30] [--iters 1000] [--lr 0 (=N/48 like tsne_cpu)]
//                         [--knn annoy|vptree] [--max-step 5 (-1 = off)] [--seed 1] [--ipi 1] [--nterms 3] [--min-intervals 50]
//   fitsne_io from-fitsne --result run/result.dat --out run/embedding.bin
//
// The record layout is the one written by FIt-SNE-master/fast_tsne.py (version 1.2.1). Random initialisation is used (no
// initialisation block is written), as in tsne_cpu, so that no Python/numpy is needed on the cluster.
static std::map<std::string, std::string> fitsne_parse(int argc, char** argv) {
  std::map<std::string, std::string> m;
  for (int i = 2; i + 1 < argc; i += 2) m[argv[i]] = argv[i + 1];
  return m;
}
static std::string fitsne_get(std::map<std::string, std::string>& m, const char* k, const char* d) { return m.count(k) ? m[k] : d; }
template <class T> static void fitsne_put(FILE* f, T v) { if (std::fwrite(&v, sizeof v, 1, f) != 1) die("write failed"); }

static int cmd_fitsne_io(int argc, char** argv) {
  if (argc < 2) die("usage: fitsne_io to-fitsne|from-fitsne ...");
  const std::string cmd = argv[1];
  auto a = fitsne_parse(argc, argv);
  if (cmd == "to-fitsne") {
    Features f; read_features(fitsne_get(a, "--feat", ""), f);
    const int n = (int)f.N, d = (int)f.D;
    const double perp = std::stod(fitsne_get(a, "--perp", "30"));
    const int iters = std::stoi(fitsne_get(a, "--iters", "1000"));
    double lr = std::stod(fitsne_get(a, "--lr", "0")); if (lr <= 0) lr = std::max(50.0, (double)n / 48.0);   // same rule as tsne_cpu
    const double maxstep = std::stod(fitsne_get(a, "--max-step", "5"));
    const int knn = fitsne_get(a, "--knn", "annoy") == "vptree" ? 2 : 1;
    const int seed = std::stoi(fitsne_get(a, "--seed", "1"));
    const double ipi = std::stod(fitsne_get(a, "--ipi", "1"));
    const int nterms = std::stoi(fitsne_get(a, "--nterms", "3")), minint = std::stoi(fitsne_get(a, "--min-intervals", "50"));
    const int ntrees = 50;
    FILE* o = std::fopen(fitsne_get(a, "--out", "").c_str(), "wb"); if (!o) die("cannot open --out");
    fitsne_put<int>(o, n); fitsne_put<int>(o, d); fitsne_put<double>(o, 0.5 /*theta*/); fitsne_put<double>(o, perp);
    fitsne_put<int>(o, 2 /*map_dims*/); fitsne_put<int>(o, iters); fitsne_put<int>(o, 250 /*stop early exag*/); fitsne_put<int>(o, 250 /*mom switch*/);
    fitsne_put<double>(o, 0.5); fitsne_put<double>(o, 0.8); fitsne_put<double>(o, lr); fitsne_put<double>(o, maxstep);
    fitsne_put<int>(o, -1 /*K*/); fitsne_put<double>(o, -1.0 /*sigma*/); fitsne_put<int>(o, 2 /*FFT*/); fitsne_put<int>(o, knn);
    fitsne_put<double>(o, 12.0 /*early exag*/); fitsne_put<int>(o, 0 /*no_momentum_during_exag*/); fitsne_put<int>(o, ntrees); fitsne_put<int>(o, (int)(3 * perp * ntrees));
    fitsne_put<int>(o, -1 /*start late exag*/); fitsne_put<double>(o, -1.0 /*late exag*/); fitsne_put<int>(o, nterms); fitsne_put<double>(o, ipi); fitsne_put<int>(o, minint);
    std::vector<double> row(d);
    for (int i = 0; i < n; ++i) { for (int j = 0; j < d; ++j) row[j] = f.x[(size_t)i * d + j]; std::fwrite(row.data(), 8, d, o); }
    fitsne_put<int>(o, seed); fitsne_put<double>(o, 1.0 /*df*/); fitsne_put<int>(o, 0 /*load_affinities*/);
    std::fclose(o);
    std::printf("fitsne_io: wrote %s  n=%d d=%d perp=%g iters=%d lr=%g knn=%s max_step=%g seed=%d ipi=%g\n", fitsne_get(a, "--out", "").c_str(), n, d, perp, iters, lr, knn == 2 ? "vptree" : "annoy", maxstep, seed, ipi);
    return 0;
  }
  if (cmd == "from-fitsne") {
    FILE* i = std::fopen(fitsne_get(a, "--result", "").c_str(), "rb"); if (!i) die("cannot open --result");
    int n = 0, md = 0;
    if (std::fread(&n, 4, 1, i) != 1 || std::fread(&md, 4, 1, i) != 1) die("short read");
    if (md != 2) die("map_dims != 2");
    std::vector<double> y((size_t)n * 2);
    if (std::fread(y.data(), 8, y.size(), i) != y.size()) die("short read of the embedding");
    std::fclose(i);
    write_embedding(fitsne_get(a, "--out", ""), n, y);
    std::printf("fitsne_io: converted %d points\n", n);
    return 0;
  }
  die("unknown command " + cmd);
}

// ---------------------------------------------------------------------------------------------
// dispatcher
// ---------------------------------------------------------------------------------------------
int main(int argc, char** argv) {
  if (argc < 2) die("usage: tsne_tools gen-data|prep-cpu|eval|compare-grad|fitsne-io [options]");
  const std::string c = argv[1];
  // The sub-command handlers parse argv[1..] exactly like the former stand-alone programs parsed their own argv.
  if (c == "gen-data") return cmd_gen_data(argc - 1, argv + 1);
  if (c == "prep-cpu") return cmd_prep_cpu(argc - 1, argv + 1);
  if (c == "eval") return cmd_eval(argc - 1, argv + 1);
  if (c == "compare-grad") return cmd_compare_grad(argc - 1, argv + 1);
  if (c == "fitsne-io") return cmd_fitsne_io(argc - 1, argv + 1);
  die("unknown sub-command " + c);
}
