// tsne_mpi_cpu.cpp — pure-MPI CPU parallel t-SNE (one single-threaded rank per core).
//
// The CPU counterpart of tsne_gpu.cu, used as a fair "many CPU cores" comparison and to study the
// same design choices where compute is slow and communication is relatively cheap:
//   * same decomposition: points split into contiguous blocks (ordered by PC1 or randomly),
//     replicated interpolation grid, same CSR / ghost-exchange setup (core.cpp);
//   * Study A  --exchange allgather|ghost   --comm blocking|nonblocking
//   * Study B  --grid-comm blocking|nonblocking, --progress wait|poll (B2 vs B2')
//   * --fft replicated (default)  every rank repeats the whole FFT (as the GPU version)
//     --fft distributed           row-block FFT with MPI_Alltoall transposes: a *different
//                                 parallel decomposition* of the grid work (Alltoall transposes, study C1/W1)
// There is no write-conflict study here (a rank is a sequential loop) and no host/device copies.
//
// The key difference to the GPU program is progress of non-blocking MPI: the CPU thread is busy
// computing, so a posted Isend/Iallreduce only advances if the compute loop calls into MPI.
//   --progress wait : compute loops never call MPI (overlap only if the MPI library has an
//                     asynchronous progress thread)
//   --progress poll : the near-field loop is cut into chunks of --chunk rows and MPI_Testall is
//                     called between chunks (manual progress)   <- B2' / A4'
//
// Output files, option names and stage names are the same as tsne_gpu (stages that do not exist
// here are 0), so the analysis scripts read both; summary.json has "backend": "cpu-mpi".
#include <mpi.h>

#include <array>
#include <cstdio>
#include "tsne_common.h"


// ------------------------------------------------------------------------------------------
// Stage timers (wall clock; same stage list as tsne_gpu.cu, with two extra stages at the end)
// ------------------------------------------------------------------------------------------
enum Stage {
  ST_ITER = 0, ST_STATS, ST_SMALL_ALLRED, ST_SCATTER, ST_GRID_D2H, ST_GRID_COMM, ST_GRID_WAIT, ST_GRID_H2D,
  ST_EXCH_PACK, ST_EXCH_COMM, ST_EXCH_WAIT, ST_EXCH_UNPACK, ST_NEAR_LOCAL, ST_NEAR_REMOTE, ST_FFT, ST_GATHER,
  ST_Z, ST_UPDATE, ST_PLAN, ST_KSPEC, ST_KL, ST_PROBE_PLAIN, ST_PROBE_DISJ, ST_GPU_WAIT, ST_ZERO,
  ST_FFT_TRANSPOSE,  // distributed FFT: MPI_Alltoall transposes
  ST_POT_ALLGATHER,  // distributed FFT: MPI_Allgatherv of the potential grid
  NSTAGE
};
static const char* STAGE_NAME[NSTAGE] = {
    "iter", "stats", "small_allreduce", "scatter", "grid_d2h", "grid_comm", "grid_wait", "grid_h2d", "exch_pack",
    "exch_comm", "exch_wait", "exch_unpack", "near_local", "near_remote", "fft", "gather", "z_reduce", "update", "plan",
    "kernel_spec", "kl", "probe_plain", "probe_disjoint", "gpu_wait", "grid_zero", "fft_transpose", "pot_allgather"};

static bool g_timing = true;
static double g_acc[NSTAGE];
static std::vector<std::array<double, NSTAGE>> g_hist;
struct Tm {
  int s;
  double t0;
  explicit Tm(int stage) : s(stage), t0(MPI_Wtime()) {}
  ~Tm() { if (g_timing) g_acc[s] += MPI_Wtime() - t0; }
};
static void end_iter(double wall) {
  g_acc[ST_ITER] = wall;
  std::array<double, NSTAGE> a;
  for (int s = 0; s < NSTAGE; ++s) { a[s] = g_acc[s]; g_acc[s] = 0; }
  g_hist.push_back(a);
}

// ------------------------------------------------------------------------------------------
// Configuration and global state
// ------------------------------------------------------------------------------------------
struct Config {
  std::string data, out = "out/run", order = "pc1", coords, mode = "run";
  std::string exchange = "ghost", comm = "blocking", grid_comm = "blocking", progress = "wait", fft = "replicated";
  bool ssend = false, force_comm = false, adaptive = true;
  int iters = 1000, exag_iters = 250, mom_switch = 250, p = 3, min_boxes = 50, fixed_boxes = 128;
  int report_every = 50, warmup = 10, chunk = 2048;
  double exag = 12, perplexity = 30, lr = -1, bw = 0.5;
  uint64_t seed = 42;
};
static Config cfg;

static int rank_ = 0, P_ = 1;
static MPI_Comm comm_ = MPI_COMM_WORLD;
static int64_t N_ = 0;
static int lo_ = 0, hi_ = 0, nloc_ = 0;
static bool comm_on_ = false;
static SymCSR loc_, rem_;
static std::vector<double> Y_, upd_, gain_, Fattr_, Frep_;  // Y_: all N points (global ids); others: local rows
static std::vector<int> send_cnt_, send_dsp_, recv_cnt_, recv_dsp_, ag_cnt_, ag_dsp_;
static std::vector<int32_t> send_ids_, recv_ids_;
static int send_total_ = 0, recv_total_ = 0;
static std::vector<double> sendbuf_, recvbuf_;
static std::vector<MPI_Request> exch_reqs_;
static MPI_Request grid_req_ = MPI_REQUEST_NULL;
struct Bbox { double x0 = -1e-3, x1 = 1e-3, y0 = -1e-3, y1 = 1e-3; };
static Bbox bb_;
static double bytes_grid_ = 0, bytes_exch_recv_ = 0, bytes_exch_send_ = 0, bytes_transpose_ = 0;
static int plan_rebuilds_ = 0;

// ------------------------------------------------------------------------------------------
// FFT convolution state.  Grid layout everywhere: index (a*4 + term)*M + b  (row a of the
// M x M node grid, 4 charge terms, column b): a block of rows is contiguous, which is what
// Reduce_scatter / Allgatherv need for the distributed FFT.
// ------------------------------------------------------------------------------------------
struct FftState {
  int M = 0, n = 0;
  double h = -1;
  bool has = false;
  std::vector<double> grid, pot;     // full 4*M*M (replicated or after Allgatherv)
  // replicated: complex n x n (two real charge terms per complex array)
  FFT2D fft2;
  std::vector<cd> work;              // n*n
  std::vector<double> khat_full;     // n*n real spectrum, scaled by 1/n^2
  // distributed: R = C = n/P rows (columns) per rank
  FFT1D f1;
  int R = 0, rowsM = 0, r0 = 0;      // rows owned, how many of them are < M
  std::vector<cd> rowsA, rowsB, colsA, colsB;  // R*n each
  std::vector<double> khat_blk;      // C*n real, scaled; layout [j][ua]
  std::vector<double> grid_blk, pot_blk;       // rowsM*4*M
  std::vector<int> rs_cnt, rs_dsp;   // per-rank counts/displacements (doubles) of row blocks of the grid
  std::vector<cd> sbuf, rbuf;        // Alltoall buffers
};
static FftState fs_;
static MPI_Request rs_req_ = MPI_REQUEST_NULL;

static int fft_size(int M) {  // circulant embedding length (>= 2M); distributed: multiple of P
  int n = 2 * M;
  if (cfg.fft == "distributed") {
    for (;; ++n)
      if (n % P_ == 0 && next_smooth(n) == n) return n;
  }
  return n;
}

// n x n real kernel k(a,b) = 1/(1+h^2 (da^2+db^2))^2 with da = min(a, n-a), for rows a in [ra, rb)
static void fill_kernel_rows(std::vector<cd>& out, int ra, int rb, int n, double h) {
  for (int a = ra; a < rb; ++a) {
    int da = std::min(a, n - a);
    for (int b = 0; b < n; ++b) {
      int db = std::min(b, n - b);
      double q = 1.0 / (1.0 + h * h * ((double)da * da + (double)db * db));
      out[(size_t)(a - ra) * n + b] = cd(q * q, 0.0);
    }
  }
}

// ---- distributed FFT helpers: rows -> transpose -> columns --------------------------------
static void rows_fft(std::vector<cd>& a, bool inv) {  // R rows of length n
  const int n = fs_.n;
  std::vector<cd> tmp(n);
  for (int i = 0; i < fs_.R; ++i) {
    fs_.f1.transform(&a[(size_t)i * n], tmp.data(), inv);
    std::copy(tmp.begin(), tmp.end(), a.begin() + (size_t)i * n);
  }
}
// rows layout [i][b] (global row r0+i) -> cols layout [jj][a] (global column c0+jj), for nblk arrays at once
static void transpose_rows_to_cols(std::vector<cd>* rows, std::vector<cd>* cols, int nblk) {
  const int n = fs_.n, R = fs_.R, C = fs_.R;
  const size_t blk = (size_t)R * C;
  fs_.sbuf.resize(blk * P_ * nblk);
  fs_.rbuf.resize(blk * P_ * nblk);
  for (int q = 0; q < P_; ++q)
    for (int m = 0; m < nblk; ++m)
      for (int i = 0; i < R; ++i)
        for (int jj = 0; jj < C; ++jj) fs_.sbuf[((size_t)q * nblk + m) * blk + (size_t)i * C + jj] = rows[m][(size_t)i * n + q * C + jj];
  {
    Tm t(ST_FFT_TRANSPOSE);
    MPI_Alltoall(fs_.sbuf.data(), (int)(blk * nblk * 2), MPI_DOUBLE, fs_.rbuf.data(), (int)(blk * nblk * 2), MPI_DOUBLE, comm_);
  }
  bytes_transpose_ += (double)blk * nblk * 16 * (P_ - 1);
  for (int q = 0; q < P_; ++q)
    for (int m = 0; m < nblk; ++m)
      for (int i = 0; i < R; ++i)
        for (int jj = 0; jj < C; ++jj) cols[m][(size_t)jj * n + q * R + i] = fs_.rbuf[((size_t)q * nblk + m) * blk + (size_t)i * C + jj];
}
static void transpose_cols_to_rows(std::vector<cd>* cols, std::vector<cd>* rows, int nblk) {
  const int n = fs_.n, R = fs_.R, C = fs_.R;
  const size_t blk = (size_t)R * C;
  fs_.sbuf.resize(blk * P_ * nblk);
  fs_.rbuf.resize(blk * P_ * nblk);
  for (int q = 0; q < P_; ++q)
    for (int m = 0; m < nblk; ++m)
      for (int i = 0; i < R; ++i)
        for (int jj = 0; jj < C; ++jj) fs_.sbuf[((size_t)q * nblk + m) * blk + (size_t)i * C + jj] = cols[m][(size_t)jj * n + q * R + i];
  {
    Tm t(ST_FFT_TRANSPOSE);
    MPI_Alltoall(fs_.sbuf.data(), (int)(blk * nblk * 2), MPI_DOUBLE, fs_.rbuf.data(), (int)(blk * nblk * 2), MPI_DOUBLE, comm_);
  }
  bytes_transpose_ += (double)blk * nblk * 16 * (P_ - 1);
  for (int q = 0; q < P_; ++q)
    for (int m = 0; m < nblk; ++m)
      for (int i = 0; i < R; ++i)
        for (int jj = 0; jj < C; ++jj) rows[m][(size_t)i * n + q * C + jj] = fs_.rbuf[((size_t)q * nblk + m) * blk + (size_t)i * C + jj];
}
static void cols_fft(std::vector<cd>& a, bool inv) {  // C columns (stored contiguously as length-n vectors)
  const int n = fs_.n;
  std::vector<cd> tmp(n);
  for (int j = 0; j < fs_.R; ++j) {
    fs_.f1.transform(&a[(size_t)j * n], tmp.data(), inv);
    std::copy(tmp.begin(), tmp.end(), a.begin() + (size_t)j * n);
  }
}

// (Re)build plans and the kernel spectrum when the grid size (plan) or the node spacing changes.
// (Re)build everything that depends on the grid: FFT length, kernel spectrum rows, work buffers. Called every iteration; it only
// does work when the grid size M or the box width h changed (adaptive grids), and reports whether the plan was rebuilt.
static bool ensure_plan(const GridParams& gp) {
  const int M = gp.M, n = fft_size(M);
  const bool size_change = !fs_.has || fs_.M != M || fs_.n != n;
  const bool h_change = !fs_.has || fs_.h != (double)gp.h;
  if (!size_change && !h_change) return false;
  Tm t(size_change ? ST_PLAN : ST_KSPEC);
  if (size_change) {
    fs_.M = M; fs_.n = n;
    fs_.grid.assign(4 * (size_t)M * M, 0.0);
    fs_.pot.assign(4 * (size_t)M * M, 0.0);
    if (cfg.fft == "replicated") {
      fs_.fft2.reset(n, n);
      fs_.work.assign((size_t)n * n, cd(0, 0));
      fs_.khat_full.assign((size_t)n * n, 0.0);
    } else {
      fs_.f1.reset(n);
      fs_.R = n / P_;
      fs_.r0 = rank_ * fs_.R;
      fs_.rowsM = std::max(0, std::min(fs_.r0 + fs_.R, M) - fs_.r0);
      for (auto* v : {&fs_.rowsA, &fs_.rowsB, &fs_.colsA, &fs_.colsB}) v->assign((size_t)fs_.R * n, cd(0, 0));
      fs_.khat_blk.assign((size_t)fs_.R * n, 0.0);
      fs_.grid_blk.assign((size_t)fs_.rowsM * 4 * M, 0.0);
      fs_.pot_blk.assign((size_t)fs_.rowsM * 4 * M, 0.0);
      fs_.rs_cnt.assign(P_, 0); fs_.rs_dsp.assign(P_, 0);
      for (int r = 0; r < P_; ++r) {
        int a0 = r * fs_.R, a1 = std::min(a0 + fs_.R, M);
        fs_.rs_cnt[r] = std::max(0, a1 - a0) * 4 * M;
        fs_.rs_dsp[r] = r == 0 ? 0 : fs_.rs_dsp[r - 1] + fs_.rs_cnt[r - 1];
      }
    }
    plan_rebuilds_++;
  }
  fs_.has = true;
  fs_.h = gp.h;
  const double scale = 1.0 / ((double)n * n);
  if (cfg.fft == "replicated") {
    fill_kernel_rows(fs_.work, 0, n, n, gp.h);
    fs_.fft2.exec(fs_.work.data(), false);
    for (size_t e = 0; e < fs_.work.size(); ++e) fs_.khat_full[e] = fs_.work[e].real() * scale;  // symmetric => real
  } else {  // the kernel spectrum itself is computed with the distributed transform
    fill_kernel_rows(fs_.rowsA, fs_.r0, fs_.r0 + fs_.R, n, gp.h);
    rows_fft(fs_.rowsA, false);
    std::vector<cd> rows1[1] = {fs_.rowsA}, cols1[1] = {fs_.colsA};
    transpose_rows_to_cols(rows1, cols1, 1);
    cols_fft(cols1[0], false);
    for (size_t e = 0; e < fs_.khat_blk.size(); ++e) fs_.khat_blk[e] = cols1[0][e].real() * scale;
  }
  return size_change;
}

// ------------------------------------------------------------------------------------------
// Communication
// ------------------------------------------------------------------------------------------
static void poll_pending() {  // manual progress of outstanding non-blocking operations
  int flag = 0;
  if (!exch_reqs_.empty()) MPI_Testall((int)exch_reqs_.size(), exch_reqs_.data(), &flag, MPI_STATUSES_IGNORE);
  if (grid_req_ != MPI_REQUEST_NULL) MPI_Test(&grid_req_, &flag, MPI_STATUS_IGNORE);
  if (rs_req_ != MPI_REQUEST_NULL) MPI_Test(&rs_req_, &flag, MPI_STATUS_IGNORE);
}

// Start the exchange of the coordinates that the near-field (attraction) needs from other ranks:
// allgather = every rank gets all points; ghost = point-to-point messages with only the neighbours' ids (send_ids_/recv_ids_).
static void exchange_begin(bool nb) {
  if (cfg.exchange == "allgather") {
    Tm t(ST_EXCH_COMM);
    if (nb) {
      exch_reqs_.assign(1, MPI_REQUEST_NULL);
      MPI_Iallgatherv(MPI_IN_PLACE, 0, MPI_DATATYPE_NULL, Y_.data(), ag_cnt_.data(), ag_dsp_.data(), MPI_DOUBLE, comm_, &exch_reqs_[0]);
    } else {
      MPI_Allgatherv(MPI_IN_PLACE, 0, MPI_DATATYPE_NULL, Y_.data(), ag_cnt_.data(), ag_dsp_.data(), MPI_DOUBLE, comm_);
    }
    bytes_exch_recv_ += (double)(N_ - nloc_) * 16;
    bytes_exch_send_ += (double)nloc_ * 16 * (P_ - 1);
    return;
  }
  {
    Tm t(ST_EXCH_PACK);
    for (int j = 0; j < send_total_; ++j) {
      sendbuf_[2 * (size_t)j] = Y_[2 * (size_t)send_ids_[j]];
      sendbuf_[2 * (size_t)j + 1] = Y_[2 * (size_t)send_ids_[j] + 1];
    }
  }
  Tm t(ST_EXCH_COMM);
  exch_reqs_.clear();
  for (int q = 0; q < P_; ++q)
    if (recv_cnt_[q] > 0) {
      exch_reqs_.emplace_back();
      MPI_Irecv(&recvbuf_[2 * (size_t)recv_dsp_[q]], 2 * recv_cnt_[q], MPI_DOUBLE, q, 7, comm_, &exch_reqs_.back());
    }
  for (int q = 0; q < P_; ++q)
    if (send_cnt_[q] > 0) {
      double* sp = &sendbuf_[2 * (size_t)send_dsp_[q]];
      if (nb) {
        exch_reqs_.emplace_back();
        MPI_Isend(sp, 2 * send_cnt_[q], MPI_DOUBLE, q, 7, comm_, &exch_reqs_.back());
      } else if (cfg.ssend) {
        MPI_Ssend(sp, 2 * send_cnt_[q], MPI_DOUBLE, q, 7, comm_);
      } else {
        MPI_Send(sp, 2 * send_cnt_[q], MPI_DOUBLE, q, 7, comm_);
      }
    }
  bytes_exch_recv_ += (double)recv_total_ * 16;
  bytes_exch_send_ += (double)send_total_ * 16;
}
// Wait for the exchange started in exchange_begin() (if non-blocking) and unpack the received coordinates into Y_.
static void exchange_end() {
  {
    Tm t(ST_EXCH_WAIT);
    if (!exch_reqs_.empty()) MPI_Waitall((int)exch_reqs_.size(), exch_reqs_.data(), MPI_STATUSES_IGNORE);
    exch_reqs_.clear();
  }
  if (cfg.exchange == "allgather") return;
  Tm t(ST_EXCH_UNPACK);
  for (int j = 0; j < recv_total_; ++j) {
    Y_[2 * (size_t)recv_ids_[j]] = recvbuf_[2 * (size_t)j];
    Y_[2 * (size_t)recv_ids_[j] + 1] = recvbuf_[2 * (size_t)j + 1];
  }
}

// Sum of the partial grids: Allreduce (replicated FFT) or Reduce_scatter of row blocks (distributed FFT)
// Sum the partial charge grids of all ranks: Allreduce (replicated FFT, every rank needs the full grid) or Reduce_scatter
// (distributed FFT, a rank needs only its rows). Non-blocking variants return immediately; grid_end() waits.
static void grid_begin(const GridParams& gp, bool nb) {
  const int count = 4 * gp.M * gp.M;
  Tm t(ST_GRID_COMM);
  if (cfg.fft == "replicated") {
    if (nb) MPI_Iallreduce(MPI_IN_PLACE, fs_.grid.data(), count, MPI_DOUBLE, MPI_SUM, comm_, &grid_req_);
    else MPI_Allreduce(MPI_IN_PLACE, fs_.grid.data(), count, MPI_DOUBLE, MPI_SUM, comm_);
  } else {
    // separate receive buffer: the in-place variant of Reduce_scatter stores the result at the top of the buffer
    if (nb) MPI_Ireduce_scatter(fs_.grid.data(), fs_.grid_blk.data(), fs_.rs_cnt.data(), MPI_DOUBLE, MPI_SUM, comm_, &rs_req_);
    else MPI_Reduce_scatter(fs_.grid.data(), fs_.grid_blk.data(), fs_.rs_cnt.data(), MPI_DOUBLE, MPI_SUM, comm_);
  }
  bytes_grid_ += (double)count * 8;
}
// Complete the grid sum started by grid_begin() when it was non-blocking.
static void grid_end(bool nb) {
  if (!nb) return;
  Tm t(ST_GRID_WAIT);
  MPI_Request* r = cfg.fft == "replicated" ? &grid_req_ : &rs_req_;
  if (*r != MPI_REQUEST_NULL) MPI_Wait(r, MPI_STATUS_IGNORE);
}

// ------------------------------------------------------------------------------------------
// Compute kernels
// ------------------------------------------------------------------------------------------
// Attractive force for the non-zeros of P in the matrix m (local columns first, remote columns after the exchange).
// With --progress poll the rows are processed in chunks and MPI_Testall is called between the chunks to advance pending messages.
static void near_field(const SymCSR& m, bool accumulate) {
  const bool poll = cfg.progress == "poll" && comm_on_;
  for (int r0 = 0; r0 < nloc_; r0 += cfg.chunk) {
    const int r1 = std::min(r0 + cfg.chunk, nloc_);
    for (int i = r0; i < r1; ++i) {
      const double xi = Y_[2 * (size_t)(lo_ + i)], yi = Y_[2 * (size_t)(lo_ + i) + 1];
      double ax = 0, ay = 0;
      for (int64_t e = m.rowptr[i]; e < m.rowptr[i + 1]; ++e) {
        const int j = m.col[e];
        const double dx = xi - Y_[2 * (size_t)j], dy = yi - Y_[2 * (size_t)j + 1];
        const double w = m.val[e] / (1.0 + dx * dx + dy * dy);
        ax += w * dx;
        ay += w * dy;
      }
      if (accumulate) { Fattr_[2 * (size_t)i] += ax; Fattr_[2 * (size_t)i + 1] += ay; }
      else { Fattr_[2 * (size_t)i] = ax; Fattr_[2 * (size_t)i + 1] = ay; }
    }
    if (poll) poll_pending();  // manual MPI progress between chunks (B2' / A4')
  }
}

static inline void weights(const GridParams& gp, double x, double y, int& bx, int& by, double* wx, double* wy) {
  real tx, ty;
  locate_box((real)x, gp.ox, gp.bw, gp.nbox, bx, tx);
  locate_box((real)y, gp.oy, gp.bw, gp.nbox, by, ty);
  real tw[MAX_ORDER];
  lagrange_weights(gp.p, tx, tw);
  for (int a = 0; a < gp.p; ++a) wx[a] = tw[a];
  lagrange_weights(gp.p, ty, tw);
  for (int b = 0; b < gp.p; ++b) wy[b] = tw[b];
}

// Spread: add the 4 charges (1, y_x, y_y, |y|^2 terms) of every local point to the p x p interpolation nodes of its box.
static void scatter(const GridParams& gp) {
  const int p = gp.p, M = gp.M;
  double wx[MAX_ORDER], wy[MAX_ORDER];
  for (int i = 0; i < nloc_; ++i) {
    const double x = Y_[2 * (size_t)(lo_ + i)], y = Y_[2 * (size_t)(lo_ + i) + 1];
    int bx, by;
    weights(gp, x, y, bx, by, wx, wy);
    const double c1 = x, c2 = y, c3 = x * x + y * y;
    for (int a = 0; a < p; ++a)
      for (int b = 0; b < p; ++b) {
        double* g = &fs_.grid[((size_t)(bx * p + a) * 4) * M + (by * p + b)];
        const double w = wx[a] * wy[b];
        g[0] += w;
        g[M] += w * c1;
        g[2 * (size_t)M] += w * c2;
        g[3 * (size_t)M] += w * c3;
      }
  }
}

// summed charge grid -> potential grid (valid on every rank afterwards)
// Convolve the 4 charge grids with the kernel by FFT (replicated: whole 2D FFT on every rank; distributed: row FFTs,
// global transpose, column FFTs, global transpose back, then Allgatherv of the potentials).
static void convolve(const GridParams& gp) {
  const int M = gp.M, n = fs_.n;
  if (cfg.fft == "replicated") {
    Tm t(ST_FFT);
    for (int pair = 0; pair < 2; ++pair) {
      std::fill(fs_.work.begin(), fs_.work.end(), cd(0, 0));
      for (int a = 0; a < M; ++a)
        for (int b = 0; b < M; ++b)
          fs_.work[(size_t)a * n + b] = cd(fs_.grid[((size_t)a * 4 + 2 * pair) * M + b], fs_.grid[((size_t)a * 4 + 2 * pair + 1) * M + b]);
      fs_.fft2.exec(fs_.work.data(), false);
      for (size_t e = 0; e < fs_.work.size(); ++e) fs_.work[e] *= fs_.khat_full[e];
      fs_.fft2.exec(fs_.work.data(), true);
      for (int a = 0; a < M; ++a)
        for (int b = 0; b < M; ++b) {
          fs_.pot[((size_t)a * 4 + 2 * pair) * M + b] = fs_.work[(size_t)a * n + b].real();
          fs_.pot[((size_t)a * 4 + 2 * pair + 1) * M + b] = fs_.work[(size_t)a * n + b].imag();
        }
    }
    return;
  }
  // distributed: rows (local FFT) -> transpose -> columns (local FFT) -> * kernel -> back
  const int R = fs_.R;
  {
    Tm t(ST_FFT);
    std::fill(fs_.rowsA.begin(), fs_.rowsA.end(), cd(0, 0));
    std::fill(fs_.rowsB.begin(), fs_.rowsB.end(), cd(0, 0));
    for (int i = 0; i < fs_.rowsM; ++i)
      for (int b = 0; b < M; ++b) {
        const double* g = &fs_.grid_blk[((size_t)i * 4) * M + b];
        fs_.rowsA[(size_t)i * n + b] = cd(g[0], g[M]);
        fs_.rowsB[(size_t)i * n + b] = cd(g[2 * (size_t)M], g[3 * (size_t)M]);
      }
    rows_fft(fs_.rowsA, false);
    rows_fft(fs_.rowsB, false);
  }
  std::vector<cd> rowsAB[2] = {std::vector<cd>(), std::vector<cd>()};
  rowsAB[0].swap(fs_.rowsA); rowsAB[1].swap(fs_.rowsB);
  std::vector<cd> colsAB[2] = {std::vector<cd>(), std::vector<cd>()};
  colsAB[0].swap(fs_.colsA); colsAB[1].swap(fs_.colsB);
  transpose_rows_to_cols(rowsAB, colsAB, 2);
  {
    Tm t(ST_FFT);
    for (int m = 0; m < 2; ++m) {
      cols_fft(colsAB[m], false);
      for (size_t e = 0; e < colsAB[m].size(); ++e) colsAB[m][e] *= fs_.khat_blk[e];
      cols_fft(colsAB[m], true);
    }
  }
  transpose_cols_to_rows(colsAB, rowsAB, 2);
  {
    Tm t(ST_FFT);
    rows_fft(rowsAB[0], true);
    rows_fft(rowsAB[1], true);
    for (int i = 0; i < fs_.rowsM; ++i)
      for (int b = 0; b < M; ++b) {
        double* q = &fs_.pot_blk[((size_t)i * 4) * M + b];
        q[0] = rowsAB[0][(size_t)i * n + b].real();
        q[M] = rowsAB[0][(size_t)i * n + b].imag();
        q[2 * (size_t)M] = rowsAB[1][(size_t)i * n + b].real();
        q[3 * (size_t)M] = rowsAB[1][(size_t)i * n + b].imag();
      }
  }
  fs_.rowsA.swap(rowsAB[0]); fs_.rowsB.swap(rowsAB[1]);
  fs_.colsA.swap(colsAB[0]); fs_.colsB.swap(colsAB[1]);
  (void)R;
  {  // every rank needs the potentials of all nodes near its points
    Tm t(ST_POT_ALLGATHER);
    MPI_Allgatherv(fs_.pot_blk.data(), fs_.rs_cnt[rank_], MPI_DOUBLE, fs_.pot.data(), fs_.rs_cnt.data(), fs_.rs_dsp.data(),
                   MPI_DOUBLE, comm_);
    bytes_transpose_ += (double)4 * M * M * 8;
  }
}

// potentials -> repulsive force and Z contribution
// Gather: interpolate the node potentials back to the local points; returns the local part of Z.
static double gather(const GridParams& gp) {
  const int p = gp.p, M = gp.M;
  double wx[MAX_ORDER], wy[MAX_ORDER], sumS = 0;
  for (int i = 0; i < nloc_; ++i) {
    const double x = Y_[2 * (size_t)(lo_ + i)], y = Y_[2 * (size_t)(lo_ + i) + 1];
    int bx, by;
    weights(gp, x, y, bx, by, wx, wy);
    double phi[4] = {0, 0, 0, 0};
    for (int a = 0; a < p; ++a)
      for (int b = 0; b < p; ++b) {
        const double* q = &fs_.pot[((size_t)(bx * p + a) * 4) * M + (by * p + b)];
        const double w = wx[a] * wy[b];
        phi[0] += w * q[0];
        phi[1] += w * q[M];
        phi[2] += w * q[2 * (size_t)M];
        phi[3] += w * q[3 * (size_t)M];
      }
    Frep_[2 * (size_t)i] = x * phi[0] - phi[1];
    Frep_[2 * (size_t)i + 1] = y * phi[0] - phi[2];
    sumS += (1.0 + x * x + y * y) * phi[0] - 2.0 * (x * phi[1] + y * phi[2]) + phi[3];
  }
  return sumS;
}

// Bounding box (and optionally re-centering) of the embedding, reduced over all ranks; the box defines the grid of the next iteration.
static void stats_and_center(bool do_center) {
  double x0 = 1e300, x1 = -1e300, y0 = 1e300, y1 = -1e300, sx = 0, sy = 0;
  {
    Tm t(ST_STATS);
    for (int i = lo_; i < hi_; ++i) {
      const double x = Y_[2 * (size_t)i], y = Y_[2 * (size_t)i + 1];
      x0 = std::min(x0, x); x1 = std::max(x1, x); y0 = std::min(y0, y); y1 = std::max(y1, y);
      sx += x; sy += y;
    }
  }
  double mx[4] = {-x0, x1, -y0, y1}, sm[2] = {sx, sy};
  if (comm_on_) {
    Tm t(ST_SMALL_ALLRED);
    MPI_Allreduce(MPI_IN_PLACE, mx, 4, MPI_DOUBLE, MPI_MAX, comm_);
    MPI_Allreduce(MPI_IN_PLACE, sm, 2, MPI_DOUBLE, MPI_SUM, comm_);
  }
  const double mean_x = do_center ? sm[0] / (double)N_ : 0.0, mean_y = do_center ? sm[1] / (double)N_ : 0.0;
  if (do_center)
    for (int i = lo_; i < hi_; ++i) { Y_[2 * (size_t)i] -= mean_x; Y_[2 * (size_t)i + 1] -= mean_y; }
  bb_.x0 = -mx[0] - mean_x; bb_.x1 = mx[1] - mean_x;
  bb_.y0 = -mx[2] - mean_y; bb_.y1 = mx[3] - mean_y;
}

// KL divergence of the current embedding (needs the global normalization Z).
static double compute_kl(double Z) {
  Tm t(ST_KL);
  double s = 0;
  for (const SymCSR* m : {&loc_, &rem_})
    for (int i = 0; i < nloc_; ++i)
      for (int64_t e = m->rowptr[i]; e < m->rowptr[i + 1]; ++e) {
        const int j = m->col[e];
        const double dx = Y_[2 * (size_t)(lo_ + i)] - Y_[2 * (size_t)j], dy = Y_[2 * (size_t)(lo_ + i) + 1] - Y_[2 * (size_t)j + 1];
        if (m->val[e] > 0) s += m->val[e] * (std::log(m->val[e]) + std::log(1.0 + dx * dx + dy * dy));
      }
  if (comm_on_) MPI_Allreduce(MPI_IN_PLACE, &s, 1, MPI_DOUBLE, MPI_SUM, comm_);
  return s + std::log(Z);
}

// One iteration; order of steps identical to tsne_gpu.cu (see its header comment).
// One t-SNE iteration: grid setup, spread, grid sum (overlapped with the near field), FFT convolution, gather, Z, forces, update.
// do_update = false only computes the gradient (mode grad, used by the correctness gate).
static double iteration(double exag, double mom, double lr, bool do_update, bool want_kl, double* kl_out) {
  GridParams gp = make_grid(cfg.adaptive, cfg.p, cfg.bw, cfg.min_boxes, cfg.fixed_boxes, bb_.x0, bb_.x1, bb_.y0, bb_.y1);
  ensure_plan(gp);
  { Tm t(ST_ZERO); std::fill(fs_.grid.begin(), fs_.grid.end(), 0.0); }
  { Tm t(ST_SCATTER); scatter(gp); }
  const bool grid_nb = cfg.grid_comm == "nonblocking", exch_nb = cfg.comm == "nonblocking";
  if (comm_on_) grid_begin(gp, grid_nb);
  if (comm_on_) {
    if (exch_nb) {
      exchange_begin(true);
      { Tm t(ST_NEAR_LOCAL); near_field(loc_, false); }
      exchange_end();
      if (!rem_.col.empty()) { Tm t(ST_NEAR_REMOTE); near_field(rem_, true); }
    } else {
      exchange_begin(false);
      exchange_end();
      { Tm t(ST_NEAR_LOCAL); near_field(loc_, false); }
      if (!rem_.col.empty()) { Tm t(ST_NEAR_REMOTE); near_field(rem_, true); }
    }
    grid_end(grid_nb);
  } else {
    { Tm t(ST_NEAR_LOCAL); near_field(loc_, false); }
    if (!rem_.col.empty()) { Tm t(ST_NEAR_REMOTE); near_field(rem_, true); }
  }
  if (!comm_on_ && cfg.fft == "distributed") {  // P == 1: the "distributed" path still works (no comm skipped inside)
    MPI_Reduce_scatter(fs_.grid.data(), fs_.grid_blk.data(), fs_.rs_cnt.data(), MPI_DOUBLE, MPI_SUM, comm_);
  }
  convolve(gp);
  double sumS;
  { Tm t(ST_GATHER); sumS = gather(gp); }
  double Z = sumS;
  if (comm_on_) { Tm t(ST_SMALL_ALLRED); MPI_Allreduce(MPI_IN_PLACE, &Z, 1, MPI_DOUBLE, MPI_SUM, comm_); }
  Z -= (double)N_;
  if (!(Z > 0) || std::isinf(Z)) {
    std::fprintf(stderr, "rank %d: invalid Z = %g (NaN/Inf or non-positive). Embedding diverged?\n", rank_, Z);
    MPI_Abort(MPI_COMM_WORLD, 2);
  }
  if (want_kl && kl_out) *kl_out = compute_kl(Z);
  if (do_update) {
    {
      Tm t(ST_UPDATE);
      const double invZ = 1.0 / Z;
      for (int i = 0; i < nloc_; ++i)
        for (int c = 0; c < 2; ++c) {
          const size_t e = 2 * (size_t)i + c;
          const double g = 4.0 * (exag * Fattr_[e] - invZ * Frep_[e]);
          double gn = gain_[e];
          gn = ((g > 0) != (upd_[e] > 0)) ? gn + 0.2 : gn * 0.8;
          if (gn < 0.01) gn = 0.01;
          gain_[e] = gn;
          const double u = mom * upd_[e] - lr * gn * g;
          upd_[e] = u;
          Y_[2 * (size_t)(lo_ + i) + c] += u;
        }
    }
    stats_and_center(true);
  }
  return Z;
}

int main(int argc, char** argv) {
  MPI_Init(&argc, &argv);
  MPI_Comm_rank(MPI_COMM_WORLD, &rank_);
  MPI_Comm_size(MPI_COMM_WORLD, &P_);
  Args a(argc, argv);
  cfg.data = a.str("data", ""); cfg.out = a.str("out", "out/run"); cfg.order = a.str("order", "pc1");
  cfg.coords = a.str("coords", ""); cfg.mode = a.str("mode", "run");
  cfg.exchange = a.str("exchange", "ghost"); cfg.comm = a.str("comm", "blocking");
  cfg.grid_comm = a.str("grid-comm", "blocking"); cfg.progress = a.str("progress", "wait");
  cfg.fft = a.str("fft", "replicated"); cfg.ssend = a.flag("ssend");
  cfg.iters = (int)a.integer("iters", 1000); cfg.exag_iters = (int)a.integer("exag-iters", 250);
  cfg.mom_switch = (int)a.integer("mom-switch", 250); cfg.exag = a.num("exag", 12);
  cfg.perplexity = a.num("perplexity", 30); cfg.lr = a.num("lr", -1);
  cfg.p = (int)a.integer("order-p", 3); cfg.bw = a.num("bw", 0.5); cfg.min_boxes = (int)a.integer("min-boxes", 50);
  cfg.adaptive = a.str("grid-mode", "adaptive") == "adaptive"; cfg.fixed_boxes = (int)a.integer("fixed-boxes", 128);
  cfg.seed = (uint64_t)a.integer("seed", 42); cfg.report_every = (int)a.integer("report-every", 50);
  cfg.warmup = (int)a.integer("warmup", 10); cfg.chunk = (int)a.integer("chunk", 2048);
  cfg.force_comm = a.flag("force-comm", false); g_timing = a.flag("stage-timing", true);
  // accepted for command-line compatibility with tsne_gpu, no meaning on the CPU
  const std::string transport = a.str("transport", "host");
  a.integer("block", 0); a.flag("probe", false);
  if (rank_ == 0) {
    for (auto& u : a.unused()) std::fprintf(stderr, "warning: unused option --%s\n", u.c_str());
    if (transport != "host") std::fprintf(stderr, "warning: --transport %s ignored (CPU program)\n", transport.c_str());
    if (cfg.progress == "sync") std::fprintf(stderr, "note: --progress sync behaves like wait on the CPU\n");
  }
  if (cfg.data.empty()) die("--data is required");
  if (cfg.p < 2 || cfg.p > MAX_ORDER) die("--order-p must be in [2,6]");
  if (cfg.exchange != "ghost" && cfg.exchange != "allgather") die("--exchange must be ghost|allgather");
  if (cfg.comm != "blocking" && cfg.comm != "nonblocking") die("--comm must be blocking|nonblocking");
  if (cfg.grid_comm != "blocking" && cfg.grid_comm != "nonblocking") die("--grid-comm must be blocking|nonblocking");
  if (cfg.fft != "replicated" && cfg.fft != "distributed") die("--fft must be replicated|distributed");
  if (cfg.chunk < 1) die("--chunk must be >= 1");
  comm_on_ = (P_ > 1) || cfg.force_comm;
  if (rank_ == 0) { int rc = std::system(("mkdir -p '" + cfg.out + "'").c_str()); (void)rc; }
  MPI_Barrier(MPI_COMM_WORLD);
  char host[256]; int hl = 0;
  MPI_Get_processor_name(host, &hl);
  MPI_Comm node; int local_size = 1;
  MPI_Comm_split_type(MPI_COMM_WORLD, MPI_COMM_TYPE_SHARED, rank_, MPI_INFO_NULL, &node);
  MPI_Comm_size(node, &local_size);
  std::printf("[rank %d/%d] host %s (%d ranks on this node)\n", rank_, P_, host, local_size);

  // ---- load data, order, partition (identical to tsne_gpu) ----
  double t_setup0 = MPI_Wtime();
  Dataset ds;
  read_dataset(cfg.data, ds);
  N_ = ds.N;
  const int k = ds.k;
  Permutation pm = make_permutation(ds, cfg.order, cfg.seed);
  lo_ = (int)block_lo(N_, P_, rank_); hi_ = (int)block_lo(N_, P_, rank_ + 1); nloc_ = hi_ - lo_;
  if (nloc_ < 1) die("fewer points than ranks");
  double t_load = MPI_Wtime();
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
  split_local_remote(all, lo_, hi_, loc_, rem_);
  const std::vector<int32_t> ghost = unique_columns(rem_);
  { std::vector<int32_t>().swap(ds.idx); std::vector<float>().swap(ds.d2); std::vector<float>().swap(cond); }
  double t_csr = MPI_Wtime();
  recv_cnt_.assign(P_, 0); send_cnt_.assign(P_, 0); recv_dsp_.assign(P_, 0); send_dsp_.assign(P_, 0);
  for (int32_t g : ghost) recv_cnt_[owner_of(N_, P_, g)]++;
  MPI_Alltoall(recv_cnt_.data(), 1, MPI_INT, send_cnt_.data(), 1, MPI_INT, comm_);
  for (int q = 1; q < P_; ++q) {
    recv_dsp_[q] = recv_dsp_[q - 1] + recv_cnt_[q - 1];
    send_dsp_[q] = send_dsp_[q - 1] + send_cnt_[q - 1];
  }
  recv_total_ = (int)ghost.size();
  send_total_ = send_dsp_[P_ - 1] + send_cnt_[P_ - 1];
  recv_ids_ = ghost;
  send_ids_.assign(send_total_, 0);
  MPI_Alltoallv(recv_ids_.data(), recv_cnt_.data(), recv_dsp_.data(), MPI_INT, send_ids_.data(), send_cnt_.data(),
                send_dsp_.data(), MPI_INT, comm_);
  ag_cnt_.resize(P_); ag_dsp_.resize(P_);
  for (int r = 0; r < P_; ++r) {
    ag_cnt_[r] = 2 * (int)(block_lo(N_, P_, r + 1) - block_lo(N_, P_, r));
    ag_dsp_[r] = 2 * (int)block_lo(N_, P_, r);
  }
  sendbuf_.assign(2 * (size_t)std::max(send_total_, 1), 0.0);
  recvbuf_.assign(2 * (size_t)std::max(recv_total_, 1), 0.0);

  Y_.assign(2 * (size_t)N_, 0.0);
  upd_.assign(2 * (size_t)nloc_, 0.0); gain_.assign(2 * (size_t)nloc_, 1.0);
  Fattr_.assign(2 * (size_t)nloc_, 0.0); Frep_.assign(2 * (size_t)nloc_, 0.0);
  {
    std::vector<double> yo;
    if (!cfg.coords.empty()) read_embedding(cfg.coords, N_, yo);
    for (int i = 0; i < nloc_; ++i) {
      const int g = lo_ + i;
      if (!cfg.coords.empty()) {
        Y_[2 * (size_t)g] = yo[2 * (size_t)pm.perm[g]];
        Y_[2 * (size_t)g + 1] = yo[2 * (size_t)pm.perm[g] + 1];
      } else {  // keyed by the ORIGINAL point id (same start for every P and --order, as tsne_gpu)
        Y_[2 * (size_t)g] = 1e-4 * gaussian_at(cfg.seed, 2 * (uint64_t)pm.perm[g]);
        Y_[2 * (size_t)g + 1] = 1e-4 * gaussian_at(cfg.seed, 2 * (uint64_t)pm.perm[g] + 1);
      }
    }
  }
  stats_and_center(cfg.mode != "grad");
  double t_setup1 = MPI_Wtime();

  const double nnz_loc = (double)loc_.col.size(), nnz_rem = (double)rem_.col.size();
  double stat_in[4] = {(double)ghost.size(), nnz_rem / std::max(1.0, nnz_loc + nnz_rem), nnz_loc + nnz_rem, (double)send_total_};
  double st_min[4], st_max[4], st_sum[4];
  MPI_Allreduce(stat_in, st_min, 4, MPI_DOUBLE, MPI_MIN, comm_);
  MPI_Allreduce(stat_in, st_max, 4, MPI_DOUBLE, MPI_MAX, comm_);
  MPI_Allreduce(stat_in, st_sum, 4, MPI_DOUBLE, MPI_SUM, comm_);
  if (rank_ == 0)
    std::printf("setup %.2fs: N=%lld k=%d P=%d  ghosts/rank min %.0f max %.0f mean %.0f (%.2f%% of N)  remote-nnz fraction %.3f..%.3f  nnz(P)=%.3g  fft=%s\n",
                t_setup1 - t_setup0, (long long)N_, k, P_, st_min[0], st_max[0], st_sum[0] / P_, 100.0 * st_sum[0] / P_ / N_,
                st_min[1], st_max[1], st_sum[2], cfg.fft.c_str());
  const double lr = cfg.lr > 0 ? cfg.lr : std::max(50.0, (double)N_ / 48.0);

  // ---------------- gradient-check mode ----------------
  if (cfg.mode == "grad") {
    if (cfg.coords.empty()) die("--mode grad needs --coords");
    // P == 1 skips communication, but the distributed FFT needs its Reduce_scatter even then (handled in iteration())
    double Z = iteration(1, 0, 0, false, false, nullptr);
    std::vector<double> A, R;
    if (rank_ == 0) { A.resize(2 * (size_t)N_); R.resize(2 * (size_t)N_); }
    MPI_Gatherv(Fattr_.data(), 2 * nloc_, MPI_DOUBLE, A.data(), ag_cnt_.data(), ag_dsp_.data(), MPI_DOUBLE, 0, comm_);
    MPI_Gatherv(Frep_.data(), 2 * nloc_, MPI_DOUBLE, R.data(), ag_cnt_.data(), ag_dsp_.data(), MPI_DOUBLE, 0, comm_);
    if (rank_ == 0) {
      std::vector<double> Ao(2 * (size_t)N_), Ro(2 * (size_t)N_), Go(2 * (size_t)N_);
      for (int64_t i = 0; i < N_; ++i)
        for (int c = 0; c < 2; ++c) {
          int64_t o = pm.perm[i];
          Ao[2 * o + c] = A[2 * i + c]; Ro[2 * o + c] = R[2 * i + c];
          Go[2 * o + c] = 4.0 * (A[2 * i + c] - R[2 * i + c] / Z);
        }
      write_grad(cfg.out + "/grad.bin", N_, Z, Ao, Ro, Go);
      std::printf("wrote %s/grad.bin  Z=%.10g\n", cfg.out.c_str(), Z);
    }
    MPI_Finalize();
    return 0;
  }

  // ---------------- optimisation loop ----------------
  std::vector<std::pair<int, double>> kl_hist;
  MPI_Barrier(comm_);
  const double t_loop0 = MPI_Wtime();
  for (int it = 0; it < cfg.iters; ++it) {
    const double ti0 = MPI_Wtime();
    const double exag = it < cfg.exag_iters ? cfg.exag : 1.0;
    const double mom = it < cfg.mom_switch ? 0.5 : 0.8;
    const bool want_kl = cfg.report_every > 0 && (it % cfg.report_every == 0);
    double kl = 0;
    double Z = iteration(exag, mom, lr, true, want_kl, &kl);
    end_iter(MPI_Wtime() - ti0);
    if (want_kl) kl_hist.push_back({it, kl});
    if (rank_ == 0 && (it % 100 == 0 || it == cfg.iters - 1))
      std::printf("iter %5d  Z=%.6g  KL=%s%.5g  %.4fs  grid M=%d\n", it, Z, want_kl ? "" : "n/a ", kl, g_hist.back()[ST_ITER], fs_.M);
  }
  MPI_Barrier(comm_);
  const double t_loop1 = MPI_Wtime();
  {  // final KL, outside the timed window
    double klf = 0;
    iteration(1, 0, 0, false, true, &klf);
    kl_hist.push_back({cfg.iters, klf});
  }

  // ---------------- results (same files as tsne_gpu) ----------------
  std::vector<double> yd(Y_.begin() + 2 * (size_t)lo_, Y_.begin() + 2 * (size_t)hi_);
  double nonfinite = 0;
  for (double v : yd) if (!std::isfinite(v)) nonfinite += 1;
  MPI_Allreduce(MPI_IN_PLACE, &nonfinite, 1, MPI_DOUBLE, MPI_SUM, comm_);
  std::vector<double> Yall;
  if (rank_ == 0) Yall.resize(2 * (size_t)N_);
  MPI_Gatherv(yd.data(), 2 * nloc_, MPI_DOUBLE, Yall.data(), ag_cnt_.data(), ag_dsp_.data(), MPI_DOUBLE, 0, comm_);
  const int nit = (int)g_hist.size();
  std::vector<double> flat((size_t)nit * NSTAGE), tmax(flat.size()), tmin(flat.size());
  for (int i = 0; i < nit; ++i)
    for (int s = 0; s < NSTAGE; ++s) flat[(size_t)i * NSTAGE + s] = g_hist[i][s];
  MPI_Reduce(flat.data(), tmax.data(), (int)flat.size(), MPI_DOUBLE, MPI_MAX, 0, comm_);
  MPI_Reduce(flat.data(), tmin.data(), (int)flat.size(), MPI_DOUBLE, MPI_MIN, 0, comm_);
  std::vector<double> mytot(NSTAGE, 0.0), alltot((size_t)NSTAGE * P_);
  const int w0 = std::min(cfg.warmup, std::max(nit - 1, 0));
  for (int i = w0; i < nit; ++i)
    for (int s = 0; s < NSTAGE; ++s) mytot[s] += g_hist[i][s];
  MPI_Gather(mytot.data(), NSTAGE, MPI_DOUBLE, alltot.data(), NSTAGE, MPI_DOUBLE, 0, comm_);
  double loop_s = t_loop1 - t_loop0, loop_max = 0;
  MPI_Reduce(&loop_s, &loop_max, 1, MPI_DOUBLE, MPI_MAX, 0, comm_);
  double byt[4] = {bytes_grid_, bytes_exch_recv_, bytes_exch_send_, bytes_transpose_}, byt_max[4];
  MPI_Reduce(byt, byt_max, 4, MPI_DOUBLE, MPI_MAX, 0, comm_);
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
    js.add("program", "tsne_mpi_cpu");
    js.add("backend", "cpu-mpi");
    js.add("precision", "double");
    js.add("emulated", 0);
    js.add("data", cfg.data);
    js.add("N", (long long)N_);
    js.add("k", k);
    js.add("P", P_);
    js.add("ranks_per_node", local_size);
    js.add("gpu", "none (CPU)");
    js.add("order", cfg.order);
    js.add("exchange", cfg.exchange);
    js.add("comm", cfg.comm);
    js.add("grid_comm", cfg.grid_comm);
    js.add("transport", "host");
    js.add("progress", cfg.progress);
    js.add("fft", cfg.fft);
    js.add("chunk", cfg.chunk);
    js.add("mpi_cuda_aware", 0);
    js.add("block", 0);
    js.add("order_p", cfg.p);
    js.add("bw", cfg.bw);
    js.add("grid_mode", cfg.adaptive ? "adaptive" : "fixed");
    js.add("iters", cfg.iters);
    js.add("lr", lr);
    js.add("perplexity", cfg.perplexity);
    js.add("probe", 0);
    js.add("stage_timing", g_timing ? 1 : 0);
    js.add("warmup_iters_skipped", w0);
    js.add("plan_iters_skipped", skipped_plan);
    js.add("plan_rebuilds", plan_rebuilds_);
    js.add("plan_total_seconds", plan_total);
    js.add("setup_seconds", t_setup1 - t_setup0);
    js.add("setup_load_seconds", t_load - t_setup0);
    js.add("setup_calibration_seconds", t_calib - t_load);
    js.add("setup_csr_seconds", t_csr - t_calib);
    js.add("loop_seconds", loop_max);
    js.add("loop_seconds_excl_kl", loop_max - kl_total);
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
    js.add("bytes_fft_transpose_per_iter", byt_max[3] / std::max(cfg.iters, 1));
    js.add("gpu_mem_in_use_bytes_max", 0.0);
    js.add("gpu_mem_allocated_by_run_bytes_max", 0.0);
    js.add("nonfinite_coordinates", nonfinite);
    js.add("final_kl", kl_hist.empty() ? 0.0 : kl_hist.back().second);
    js.add("final_grid_nodes_per_dim", (long long)fs_.M);
    js.add("config_label", cfg.exchange + "/" + cfg.comm + "|" + cfg.grid_comm + "|" + cfg.progress + "|" + cfg.fft);
    js.write(cfg.out + "/summary.json");
    std::printf("done: %d iterations, loop %.3fs (%.4f s/iter total, %.4f s/iter steady), nonfinite=%g\n", cfg.iters, loop_max,
                (loop_max - kl_total) / std::max(cfg.iters, 1), mean[ST_ITER], nonfinite);
  }
  MPI_Finalize();
  return 0;
}
