// tsne_cpu.cpp — serial (single core) t-SNE: exact O(N^2) gradient and FIt-SNE fast gradient.
//
//   tsne_cpu --data data/g.ds.bin --method fast --iters 1000 --out out/cpu_fast
//   tsne_cpu --data data/g.ds.bin --method exact --mode grad --coords out/emb.bin --out out/g_exact
//
// --method exact : sums over all N^2 pairs. Ground truth for small N (<= ~5000). Not for speed.
// --method fast  : FIt-SNE. Points are interpolated onto a regular grid (Lagrange, `--order-p`
//                  nodes per box), the all-pairs sum is a convolution done with FFT, and the
//                  result is interpolated back. This is the speed-up baseline (1 core, own FFT).
// --mode run     : full optimisation; writes embedding.bin, timing.csv, kl.csv, summary.json.
// --mode grad    : gradient at the fixed coordinates in --coords (embedding.bin format; original
//                  point order); writes grad.bin with Z, attractive, repulsive and total gradient.
// --mode kl      : KL(P||Q) of the embedding in --coords (same P and Z as the optimiser); writes kl_eval.json.
//
// Mathematics (gradient of KL(P||Q), q~_ij = 1/(1+|yi-yj|^2), Z = sum_{k!=l} q~_kl):
//   dC/dy_i = 4 [ sum_j p_ij q~_ij (y_i-y_j)   -   (1/Z) sum_j q~_ij^2 (y_i-y_j) ]
//                 \_______ attr_i _________/       \________ rep_i / Z ________/
// FIt-SNE evaluates sum_j q~^2_ij * {1, x_j, y_j, x_j^2+y_j^2} (4 "charges") by one kernel
// convolution; rep_i and Z follow from them (see gather step below).
#include <cstdio>
#include "tsne_common.h"


// ------------------------------------------------------------------------------------------
// Fast gradient (grid + FFT) on the CPU
// ------------------------------------------------------------------------------------------
struct FastCtx {
  int M = 0;
  double h = -1;
  FFT2D fft;
  std::vector<double> khat;  // real spectrum of the kernel, already scaled by 1/(2M)^2
  std::vector<double> grid;  // 4 charge grids, M*M each
  std::vector<double> pot;   // 4 potential grids
  std::vector<cd> work;      // (2M)^2 complex scratch
  // per-call stage timers (seconds), reset at the start of fast_repulsion; written to timing.csv
  double t_spread = 0, t_kspec = 0, t_fft = 0, t_gather = 0;
};

static void ensure_kernel(FastCtx& c, const GridParams& gp) {
  if (c.M == gp.M && c.h == (double)gp.h) return;
  const double t_k0 = wall_time();
  const int M = gp.M, n = 2 * M;
  if (c.M != M) {
    c.fft.reset(n, n);
    c.work.resize((size_t)n * n);
  }
  c.M = M;
  c.h = gp.h;
  c.khat.resize((size_t)n * n);
  for (int a = 0; a < n; ++a) {
    int da = a <= M ? a : n - a;
    for (int b = 0; b < n; ++b) {
      int db = b <= M ? b : n - b;
      double r2 = (double)gp.h * gp.h * ((double)da * da + (double)db * db);
      double q = 1.0 / (1.0 + r2);
      c.work[(size_t)a * n + b] = cd(q * q, 0.0);
    }
  }
  c.fft.exec(c.work.data(), false);
  const double scale = 1.0 / ((double)n * n);
  for (size_t e = 0; e < c.khat.size(); ++e) c.khat[e] = c.work[e].real() * scale;  // symmetric kernel => real
  c.t_kspec += wall_time() - t_k0;
}

// Computes attr is NOT done here; returns rep (unnormalised repulsive force) and Z.
static void fast_repulsion(FastCtx& c, const GridParams& gp, int64_t N, const std::vector<double>& Y,
                           std::vector<double>& rep, double& Z) {
  c.t_spread = c.t_kspec = c.t_fft = c.t_gather = 0;
  ensure_kernel(c, gp);
  const int p = gp.p, M = gp.M, n = 2 * M;
  const size_t M2 = (size_t)M * M;
  c.grid.assign(4 * M2, 0.0);
  c.pot.assign(4 * M2, 0.0);
  double wx[MAX_ORDER], wy[MAX_ORDER];
  double t_s0 = wall_time();
  // 1. points -> grid (scatter)
  for (int64_t i = 0; i < N; ++i) {
    double x = Y[2 * i], y = Y[2 * i + 1];
    int bx, by;
    real tx, ty;
    locate_box((real)x, gp.ox, gp.bw, gp.nbox, bx, tx);
    locate_box((real)y, gp.oy, gp.bw, gp.nbox, by, ty);
    real tw[MAX_ORDER];
    lagrange_weights(p, tx, tw);
    for (int a = 0; a < p; ++a) wx[a] = tw[a];
    lagrange_weights(p, ty, tw);
    for (int b = 0; b < p; ++b) wy[b] = tw[b];
    const double ch[4] = {1.0, x, y, x * x + y * y};
    for (int a = 0; a < p; ++a)
      for (int b = 0; b < p; ++b) {
        size_t g = (size_t)(bx * p + a) * M + (by * p + b);
        double w = wx[a] * wy[b];
        for (int t = 0; t < 4; ++t) c.grid[t * M2 + g] += w * ch[t];
      }
  }
  c.t_spread = wall_time() - t_s0;
  double t_f0 = wall_time();
  // 2. FFT convolution (packing + forward FFT + kernel product + inverse FFT + unpacking = the O(G log G) part).
  //    The kernel is real and symmetric, so two real charge grids can share one complex FFT (re = first, im = second).
  for (int pair = 0; pair < 2; ++pair) {
    std::fill(c.work.begin(), c.work.end(), cd(0, 0));
    for (int a = 0; a < M; ++a)
      for (int b = 0; b < M; ++b)
        c.work[(size_t)a * n + b] = cd(c.grid[(2 * pair) * M2 + (size_t)a * M + b],
                                       c.grid[(2 * pair + 1) * M2 + (size_t)a * M + b]);
    c.fft.exec(c.work.data(), false);
    for (size_t e = 0; e < c.work.size(); ++e) c.work[e] *= c.khat[e];
    c.fft.exec(c.work.data(), true);
    for (int a = 0; a < M; ++a)
      for (int b = 0; b < M; ++b) {
        c.pot[(2 * pair) * M2 + (size_t)a * M + b] = c.work[(size_t)a * n + b].real();
        c.pot[(2 * pair + 1) * M2 + (size_t)a * M + b] = c.work[(size_t)a * n + b].imag();
      }
  }
  c.t_fft = wall_time() - t_f0;
  double t_g0 = wall_time();
  // 3. grid -> points (gather) and the Z / repulsion formulas
  rep.assign(2 * N, 0.0);
  double sumS = 0;
  for (int64_t i = 0; i < N; ++i) {
    double x = Y[2 * i], y = Y[2 * i + 1];
    int bx, by;
    real tx, ty;
    locate_box((real)x, gp.ox, gp.bw, gp.nbox, bx, tx);
    locate_box((real)y, gp.oy, gp.bw, gp.nbox, by, ty);
    real tw[MAX_ORDER];
    lagrange_weights(p, tx, tw);
    for (int a = 0; a < p; ++a) wx[a] = tw[a];
    lagrange_weights(p, ty, tw);
    for (int b = 0; b < p; ++b) wy[b] = tw[b];
    double phi[4] = {0, 0, 0, 0};
    for (int a = 0; a < p; ++a)
      for (int b = 0; b < p; ++b) {
        size_t g = (size_t)(bx * p + a) * M + (by * p + b);
        double w = wx[a] * wy[b];
        for (int t = 0; t < 4; ++t) phi[t] += w * c.pot[t * M2 + g];
      }
    rep[2 * i] = x * phi[0] - phi[1];
    rep[2 * i + 1] = y * phi[0] - phi[2];
    // sum_j q~_ij (incl. j=i) = (1+|y_i|^2) phi0 - 2 (x_i phi1 + y_i phi2) + phi3, using
    // q~ = q~^2 (1 + |y_i - y_j|^2).
    sumS += (1.0 + x * x + y * y) * phi[0] - 2.0 * (x * phi[1] + y * phi[2]) + phi[3];
  }
  Z = sumS - (double)N;  // remove the N self terms (q~_ii = 1)
  c.t_gather = wall_time() - t_g0;
}

static void exact_repulsion(int64_t N, const std::vector<double>& Y, std::vector<double>& rep, double& Z) {
  rep.assign(2 * N, 0.0);
  double z = 0;
  for (int64_t i = 0; i < N; ++i)
    for (int64_t j = 0; j < N; ++j) {
      if (i == j) continue;
      double dx = Y[2 * i] - Y[2 * j], dy = Y[2 * i + 1] - Y[2 * j + 1];
      double q = 1.0 / (1.0 + dx * dx + dy * dy);
      z += q;
      rep[2 * i] += q * q * dx;
      rep[2 * i + 1] += q * q * dy;
    }
  Z = z;
}

static void attraction(const SymCSR& P, const std::vector<double>& Y, std::vector<double>& attr) {
  attr.assign(2 * P.nrows, 0.0);
  for (int64_t i = 0; i < P.nrows; ++i) {
    double ax = 0, ay = 0;
    for (int64_t e = P.rowptr[i]; e < P.rowptr[i + 1]; ++e) {
      int32_t j = P.col[e];
      double dx = Y[2 * i] - Y[2 * j], dy = Y[2 * i + 1] - Y[2 * j + 1];
      double w = P.val[e] / (1.0 + dx * dx + dy * dy);
      ax += w * dx;
      ay += w * dy;
    }
    attr[2 * i] = ax;
    attr[2 * i + 1] = ay;
  }
}

static double kl_divergence(const SymCSR& P, const std::vector<double>& Y, double Z) {
  double s = 0;
  for (int64_t i = 0; i < P.nrows; ++i)
    for (int64_t e = P.rowptr[i]; e < P.rowptr[i + 1]; ++e) {
      int32_t j = P.col[e];
      double dx = Y[2 * i] - Y[2 * j], dy = Y[2 * i + 1] - Y[2 * j + 1];
      if (P.val[e] > 0) s += P.val[e] * (std::log(P.val[e]) + std::log(1.0 + dx * dx + dy * dy));
    }
  return s + std::log(Z);
}

int main(int argc, char** argv) {
  Args a(argc, argv);
  const std::string datap = a.str("data", "");
  const std::string outd = a.str("out", "out/cpu");
  const std::string method = a.str("method", "fast");
  const std::string mode = a.str("mode", "run");
  const std::string coordsp = a.str("coords", "");
  const std::string order = a.str("order", "pc1");
  const int iters = (int)a.integer("iters", 1000);
  const int exag_iters = (int)a.integer("exag-iters", 250);
  const int mom_switch = (int)a.integer("mom-switch", 250);
  const double exag_factor = a.num("exag", 12.0);
  const double perplexity = a.num("perplexity", 30.0);
  const int p = (int)a.integer("order-p", 3);
  const double bw = a.num("bw", 0.5);
  const int min_boxes = (int)a.integer("min-boxes", 50);
  const bool adaptive = a.str("grid-mode", "adaptive") == "adaptive";
  const int fixed_boxes = (int)a.integer("fixed-boxes", 128);
  const uint64_t seed = (uint64_t)a.integer("seed", 42);
  const int report_every = (int)a.integer("report-every", 50);
  double lr = a.num("lr", -1);
  for (auto& u : a.unused()) std::fprintf(stderr, "warning: unused option --%s\n", u.c_str());
  if (datap.empty()) die("--data is required");
  if (p < 2 || p > MAX_ORDER) die("--order-p must be in [2,6]");
  const std::string cmd = "mkdir -p '" + outd + "'";
  if (std::system(cmd.c_str()) != 0) die("cannot create output directory");

  double tload0 = wall_time();
  Dataset ds;
  read_dataset(datap, ds);
  const int64_t N = ds.N;
  const int k = ds.k;
  Permutation pm = make_permutation(ds, order, seed);
  std::vector<float> cond((size_t)N * k);
  {
    std::vector<double> row(k);
    for (int64_t i = 0; i < N; ++i) {
      calibrate_row(&ds.d2[(size_t)pm.perm[i] * k], k, perplexity, row.data());
      for (int t = 0; t < k; ++t) cond[(size_t)i * k + t] = (float)row[t];
    }
  }
  SymCSR P = build_sym_rows(ds, pm, cond, 0, N);
  double tload1 = wall_time();
  std::printf("tsne_cpu: N=%lld k=%d nnz(P)=%lld method=%s mode=%s setup %.2fs\n", (long long)N, k,
              (long long)P.col.size(), method.c_str(), mode.c_str(), tload1 - tload0);

  // Coordinates (new numbering)
  std::vector<double> Y(2 * N);
  if (!coordsp.empty()) {
    std::vector<double> yo;
    read_embedding(coordsp, N, yo);
    for (int64_t i = 0; i < N; ++i) {
      Y[2 * i] = yo[2 * (int64_t)pm.perm[i]];
      Y[2 * i + 1] = yo[2 * (int64_t)pm.perm[i] + 1];
    }
  } else if (mode == "run") {
    for (int64_t i = 0; i < N; ++i) {
      Y[2 * i] = 1e-4 * gaussian_at(seed, 2 * (uint64_t)pm.perm[i]);  // keyed by the original id (as tsne_gpu)
      Y[2 * i + 1] = 1e-4 * gaussian_at(seed, 2 * (uint64_t)pm.perm[i] + 1);
    }
  } else {
    die("--mode grad needs --coords");
  }

  FastCtx ctx;
  auto bbox_grid = [&]() {
    double x0 = 1e300, x1 = -1e300, y0 = 1e300, y1 = -1e300;
    for (int64_t i = 0; i < N; ++i) {
      x0 = std::min(x0, Y[2 * i]); x1 = std::max(x1, Y[2 * i]);
      y0 = std::min(y0, Y[2 * i + 1]); y1 = std::max(y1, Y[2 * i + 1]);
    }
    return make_grid(adaptive, p, bw, min_boxes, fixed_boxes, x0, x1, y0, y1);
  };
  auto repulsion = [&](std::vector<double>& rep, double& Z) {
    if (method == "exact") exact_repulsion(N, Y, rep, Z);
    else fast_repulsion(ctx, bbox_grid(), N, Y, rep, Z);
  };

  if (mode == "grad") {
    std::vector<double> attr, rep, grad(2 * N), attr_o(2 * N), rep_o(2 * N), grad_o(2 * N);
    double Z = 0;
    attraction(P, Y, attr);
    repulsion(rep, Z);
    for (int64_t i = 0; i < N; ++i)
      for (int c = 0; c < 2; ++c) {
        grad[2 * i + c] = 4.0 * (attr[2 * i + c] - rep[2 * i + c] / Z);
        int64_t o = pm.perm[i];
        attr_o[2 * o + c] = attr[2 * i + c];
        rep_o[2 * o + c] = rep[2 * i + c];
        grad_o[2 * o + c] = grad[2 * i + c];
      }
    write_grad(outd + "/grad.bin", N, Z, attr_o, rep_o, grad_o);
    std::printf("wrote %s/grad.bin  Z=%.10g\n", outd.c_str(), Z);
    return 0;
  }

  if (mode == "kl") {   // KL(P||Q) of the embedding in --coords under THIS program's P (same measure for every implementation's embedding)
    std::vector<double> rep;
    double Z = 0;
    repulsion(rep, Z);
    const double kl = kl_divergence(P, Y, Z);
    FILE* fj = xfopen(outd + "/kl_eval.json", "w");
    std::fprintf(fj, "{\"N\": %lld, \"kl\": %.9g, \"Z\": %.10g, \"method\": \"%s\"}\n", (long long)N, kl, Z, method.c_str());
    std::fclose(fj);
    std::printf("kl_eval: N=%lld KL=%.9g (method=%s)\n", (long long)N, kl, method.c_str());
    return 0;
  }

  // ---------------- optimisation loop ----------------
  if (lr <= 0) lr = std::max(50.0, (double)N / 48.0);
  std::vector<double> upd(2 * N, 0.0), gains(2 * N, 1.0), attr, rep;
  FILE* ft = xfopen(outd + "/timing.csv", "w");
  std::fprintf(ft, "iter,scatter_fft_gather,attraction,update,total,spread,kernel_spec,fft,gather\n");
  FILE* fk = xfopen(outd + "/kl.csv", "w");
  std::fprintf(fk, "iter,kl\n");
  double t_loop0 = wall_time();
  for (int it = 0; it < iters; ++it) {
    double ta = wall_time();
    const double exag = it < exag_iters ? exag_factor : 1.0;
    const double mom = it < mom_switch ? 0.5 : 0.8;
    double Z = 0;
    repulsion(rep, Z);
    double tb = wall_time();
    attraction(P, Y, attr);
    double tc = wall_time();
    for (int64_t e = 0; e < 2 * N; ++e) {
      double g = 4.0 * (exag * attr[e] - rep[e] / Z);
      gains[e] = ((g > 0) != (upd[e] > 0)) ? gains[e] + 0.2 : gains[e] * 0.8;
      if (gains[e] < 0.01) gains[e] = 0.01;
      upd[e] = mom * upd[e] - lr * gains[e] * g;
    }
    if (report_every > 0 && (it % report_every == 0 || it == iters - 1)) {
      // KL uses the Y of this iteration (before the update below is applied)
      std::fprintf(fk, "%d,%.9g\n", it, kl_divergence(P, Y, Z));
    }
    for (int64_t e = 0; e < 2 * N; ++e) Y[e] += upd[e];
    double mx = 0, my = 0;  // centre
    for (int64_t i = 0; i < N; ++i) { mx += Y[2 * i]; my += Y[2 * i + 1]; }
    mx /= N; my /= N;
    for (int64_t i = 0; i < N; ++i) { Y[2 * i] -= mx; Y[2 * i + 1] -= my; }
    double td = wall_time();
    std::fprintf(ft, "%d,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g\n", it, tb - ta, tc - tb, td - tc, td - ta, ctx.t_spread, ctx.t_kspec, ctx.t_fft, ctx.t_gather);
    if (it % 100 == 0) std::printf("iter %d  Z=%.6g  %.3fs/iter\n", it, Z, td - ta);
  }
  double t_loop1 = wall_time();
  std::fclose(ft);
  std::fclose(fk);
  std::vector<double> Yo(2 * N);
  for (int64_t i = 0; i < N; ++i) {
    Yo[2 * (int64_t)pm.perm[i]] = Y[2 * i];
    Yo[2 * (int64_t)pm.perm[i] + 1] = Y[2 * i + 1];
  }
  write_embedding(outd + "/embedding.bin", N, Yo);
  JsonOut js;
  js.add("program", "tsne_cpu");
  js.add("method", method);
  js.add("N", (long long)N);
  js.add("k", k);
  js.add("iters", iters);
  js.add("order_p", p);
  js.add("grid_mode", adaptive ? "adaptive" : "fixed");
  js.add("setup_seconds", tload1 - tload0);
  js.add("loop_seconds", t_loop1 - t_loop0);
  js.add("seconds_per_iter", (t_loop1 - t_loop0) / iters);
  js.write(outd + "/summary.json");
  std::printf("done: %d iterations in %.2fs (%.4f s/iter)\n", iters, t_loop1 - t_loop0, (t_loop1 - t_loop0) / iters);
  return 0;
}
