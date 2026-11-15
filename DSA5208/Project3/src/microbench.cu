// microbench.cu — platform micro-benchmarks used to explain and predict the t-SNE results.
//
//   mpirun -np 2 microbench --test pingpong [--peer 1] [--device-ptr] [--max-bytes 67108864]
//   mpirun -np P microbench --test allreduce [--device-ptr] [--max-bytes 67108864]
//   mpirun -np P microbench --test overlap   [--bytes 1048576] [--kernel-ms 5] [--device-ptr]
//   mpirun -np P microbench --test overlap_p2p [--bytes 1048576] [--kernel-ms 5]   (P even; ranks r and r^1 exchange)
//   mpirun -np P microbench_cpu --test overlap_cpu [--bytes 1048576] [--kernel-ms 5] [--chunks 50] [--p2p]   (CPU-only)
//   mpirun -np 1 microbench --test copy      (pageable vs pinned host<->device bandwidth)
//   mpirun -np 1 microbench --test flops     (FP32 vs FP64 FMA throughput)
//
// Output is CSV on stdout (rank 0): `test,variant,bytes,seconds,extra`.
//
//  pingpong : one-way time vs message size between rank 0 and rank --peer. Choose the peer on
//             the same node and on another node to measure intra-/inter-node latency alpha and
//             bandwidth beta (T ~ alpha + bytes * beta). A `fit` line is printed.
//  allreduce: MPI_Allreduce(SUM, in place) time vs size — the model of the grid sum (study B).
//  copy     : cudaMemcpy bandwidth, pageable vs pinned memory (cost of host staging).
//  flops    : FP32 vs FP64 fused multiply-add throughput (A40 FP64 is slow; this measures it).
//  overlap_cpu: the CPU-MPI analogue: a busy CPU loop replaces the GPU kernel. The thread is busy
//             computing, so a posted non-blocking operation can only advance if the loop calls into MPI:
//               seq : blocking op, then compute        nopoll: post, compute, wait   (no MPI calls during compute)
//               poll: post, compute in --chunks pieces with MPI_Testall in between, wait        (A4'/B2')
//             add --p2p for the pairwise Isend/Irecv pattern instead of Iallreduce. Works with the CPU
//             emulation build (`make microbench_cpu`), i.e. on machines without a GPU.
//  overlap_p2p: the same test for a ghost-exchange-like pattern: Isend/Irecv between rank pairs.
//  overlap  : can an Iallreduce make progress while a GPU kernel runs? Variants:
//               seq    : Allreduce, then kernel               (no overlap, reference)
//               wait   : Iallreduce, launch kernel, MPI_Waitall, sync       (intended design)
//               sync   : Iallreduce, launch kernel, cudaDeviceSynchronize, THEN Waitall
//               poll   : Iallreduce, launch kernel, MPI_Test loop until done, sync
//             overlap_efficiency = (seq - variant) / min(comm_only, kernel_only); 1 = perfect.
#include <mpi.h>
#define TSNE_USE_MPI
#include <cstdio>
#define TSNE_GPU
#include "tsne_common.h"


template <class T>
__global__ void k_fma(T* out, long long iters) {
  long long t = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  T a0 = (T)(t % 7) * (T)1e-3 + (T)1, a1 = a0 + (T)0.1, a2 = a0 + (T)0.2, a3 = a0 + (T)0.3;
  const T m = (T)1.0000001, c = (T)1e-9;
  for (long long i = 0; i < iters; ++i) {  // 4 independent FMA chains
    a0 = a0 * m + c; a1 = a1 * m + c; a2 = a2 * m + c; a3 = a3 * m + c;
  }
  if (a0 + a1 + a2 + a3 == (T)12345.678) out[0] = a0;  // keeps the loop alive
}

int main(int argc, char** argv) {
  MPI_Init(&argc, &argv);
  int rank, P;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  MPI_Comm_size(MPI_COMM_WORLD, &P);
  Args a(argc, argv);
  const std::string test = a.str("test", "pingpong");
  const bool devptr = a.flag("device-ptr");
  const int reps = (int)a.integer("reps", 50);
  const long long max_bytes = a.integer("max-bytes", 1LL << 28);
  const int peer = (int)a.integer("peer", 1);
  const long long ov_bytes = a.integer("bytes", 1 << 20);
  const double kernel_ms = a.num("kernel-ms", 5.0);
  const long long fthreads = a.integer("flop-threads", 1 << 20);
  const long long fiters = a.integer("flop-iters", 4096);
  if (rank == 0) for (auto& u : a.unused()) std::fprintf(stderr, "warning: unused option --%s\n", u.c_str());

  MPI_Comm node;
  MPI_Comm_split_type(MPI_COMM_WORLD, MPI_COMM_TYPE_SHARED, rank, MPI_INFO_NULL, &node);
  int lr = 0, ng = 1;
  MPI_Comm_rank(node, &lr);
  CUDA_CHECK(cudaGetDeviceCount(&ng));
  CUDA_CHECK(cudaSetDevice(lr % ng));
  cudaDeviceProp prop;
  CUDA_CHECK(cudaGetDeviceProperties(&prop, lr % ng));
  char name[256]; int nl = 0;
  MPI_Get_processor_name(name, &nl);
  std::vector<char> names((size_t)256 * P);
  MPI_Allgather(name, 256, MPI_CHAR, names.data(), 256, MPI_CHAR, MPI_COMM_WORLD);
  if (rank == 0) {
    std::printf("# gpu=%s ranks=%d\n", prop.name, P);
    std::printf("test,variant,bytes,seconds,extra\n");
  }
  const char* where = "host";
  if (devptr) where = "device";

  if (test == "pingpong") {
    if (P < 2 || peer >= P) die("pingpong needs --peer < number of ranks (and >= 2 ranks)");
    const bool same_node = std::string(&names[0]) == std::string(&names[(size_t)256 * peer]);
    void* buf = nullptr;
    if (devptr) CUDA_CHECK(cudaMalloc(&buf, max_bytes)); else CUDA_CHECK(cudaMallocHost(&buf, max_bytes));
    std::vector<double> xs, ts;
    for (long long b = 8; b <= max_bytes; b *= 4) {
      MPI_Barrier(MPI_COMM_WORLD);
      double t = 0;
      if (rank == 0 || rank == peer) {
        const int other = rank == 0 ? peer : 0;
        for (int r = -5; r < reps; ++r) {  // 5 warm-up rounds
          if (r == 0) t = MPI_Wtime();
          if (rank == 0) {
            MPI_Send(buf, (int)b, MPI_BYTE, other, 1, MPI_COMM_WORLD);
            MPI_Recv(buf, (int)b, MPI_BYTE, other, 2, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
          } else {
            MPI_Recv(buf, (int)b, MPI_BYTE, other, 1, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
            MPI_Send(buf, (int)b, MPI_BYTE, other, 2, MPI_COMM_WORLD);
          }
        }
        t = (MPI_Wtime() - t) / reps / 2.0;
      }
      if (rank == 0) {
        std::printf("pingpong,%s_%s,%lld,%.9g,%.4f GB/s\n", where, same_node ? "intra" : "inter", b, t, b / t / 1e9);
        xs.push_back((double)b); ts.push_back(t);
      }
    }
    if (rank == 0 && xs.size() >= 2) {  // alpha from the smallest message, beta from the largest
      double beta = (ts.back() - ts[0]) / (xs.back() - xs[0]);
      std::printf("fit,%s_%s,0,%.9g,beta=%.6g s/byte (%.2f GB/s)\n", where, same_node ? "intra" : "inter", ts[0], beta, 1e-9 / beta);
    }
    if (devptr) cudaFree(buf); else cudaFreeHost(buf);
  } else if (test == "allreduce") {
    void* buf = nullptr;
    if (devptr) CUDA_CHECK(cudaMalloc(&buf, max_bytes)); else CUDA_CHECK(cudaMallocHost(&buf, max_bytes));
    CUDA_CHECK(cudaMemset(buf, 0, max_bytes));
    for (long long b = 8; b <= max_bytes; b *= 4) {
      const int cnt = (int)(b / 8);
      MPI_Barrier(MPI_COMM_WORLD);
      double t = 0;
      for (int r = -3; r < reps; ++r) {
        if (r == 0) { MPI_Barrier(MPI_COMM_WORLD); t = MPI_Wtime(); }
        MPI_Allreduce(MPI_IN_PLACE, buf, cnt, MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);
      }
      t = (MPI_Wtime() - t) / reps;
      double tmax = 0;
      MPI_Reduce(&t, &tmax, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);
      if (rank == 0) std::printf("allreduce,%s_P%d,%lld,%.9g,%.4f GB/s\n", where, P, b, tmax, b / tmax / 1e9);
      // the same reduction as MPI_Iallreduce + MPI_Wait with nothing in between: is the nonblocking call slower than the blocking one
      // when it has no computation to overlap with? (explains B2 vs B1 in study B)
      MPI_Barrier(MPI_COMM_WORLD);
      double t2 = 0;
      for (int r = -3; r < reps; ++r) {
        if (r == 0) { MPI_Barrier(MPI_COMM_WORLD); t2 = MPI_Wtime(); }
        MPI_Request rq;
        MPI_Iallreduce(MPI_IN_PLACE, buf, cnt, MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD, &rq);
        MPI_Wait(&rq, MPI_STATUS_IGNORE);
      }
      t2 = (MPI_Wtime() - t2) / reps;
      double t2max = 0;
      MPI_Reduce(&t2, &t2max, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);
      if (rank == 0) std::printf("iallreduce_wait,%s_P%d,%lld,%.9g,%.4f GB/s\n", where, P, b, t2max, b / t2max / 1e9);
    }
    if (devptr) cudaFree(buf); else cudaFreeHost(buf);
  } else if (test == "copy") {
    if (rank == 0) {
      void* dev = nullptr;
      CUDA_CHECK(cudaMalloc(&dev, max_bytes));
      void* pinned = nullptr;
      CUDA_CHECK(cudaMallocHost(&pinned, max_bytes));
      std::vector<char> pageable(max_bytes, 1);
      for (long long b = 1024; b <= max_bytes; b *= 4) {
        for (int dir = 0; dir < 2; ++dir)
          for (int kind = 0; kind < 2; ++kind) {
            void* h = kind ? pinned : (void*)pageable.data();
            double t = 0;
            for (int r = -3; r < reps; ++r) {
              if (r == 0) t = MPI_Wtime();
              if (dir == 0) CUDA_CHECK(cudaMemcpy(dev, h, b, cudaMemcpyHostToDevice));
              else CUDA_CHECK(cudaMemcpy(h, dev, b, cudaMemcpyDeviceToHost));
            }
            t = (MPI_Wtime() - t) / reps;
            std::printf("copy,%s_%s,%lld,%.9g,%.4f GB/s\n", dir ? "D2H" : "H2D", kind ? "pinned" : "pageable", b, t, b / t / 1e9);
          }
      }
      cudaFree(dev); cudaFreeHost(pinned);
    }
  } else if (test == "flops") {
    if (rank == 0) {
      void* out = nullptr;
      CUDA_CHECK(cudaMalloc(&out, 16));
      cudaEvent_t e0, e1;
      CUDA_CHECK(cudaEventCreate(&e0)); CUDA_CHECK(cudaEventCreate(&e1));
      for (int prec = 0; prec < 2; ++prec) {
        const int bs = 256;
        const int nb = blocks_for(fthreads, bs);
        for (int r = 0; r < 3; ++r) {  // first run is warm-up; last one reported
          CUDA_CHECK(cudaEventRecord(e0));
          if (prec == 0) LAUNCH(k_fma<float>, nb, bs, (float*)out, fiters);
          else LAUNCH(k_fma<double>, nb, bs, (double*)out, fiters);
          CUDA_CHECK(cudaEventRecord(e1));
          CUDA_CHECK(cudaEventSynchronize(e1));
          float ms = 0;
          CUDA_CHECK(cudaEventElapsedTime(&ms, e0, e1));
          if (r == 2) {
            double flop = 2.0 * 4.0 * (double)fiters * (double)nb * bs;  // 4 chains x (mul+add)
            std::printf("flops,%s,0,%.9g,%.1f GFLOP/s\n", prec ? "fp64" : "fp32", ms * 1e-3, flop / (ms * 1e-3) / 1e9);
          }
        }
      }
    }
  } else if (test == "overlap_cpu") {
    const bool p2p = a.flag("p2p");
    const int chunks = (int)a.integer("chunks", 50);
    if (p2p && P % 2 != 0) die("--p2p needs an even number of ranks");
    // busy loop of `iters` dependent FMAs (4 chains); calibrated to run ~kernel_ms
    volatile double sink = 0;
    auto spin = [&](long long iters) {
      double a0 = 1.0, a1 = 1.1, a2 = 1.2, a3 = 1.3;
      for (long long i = 0; i < iters; ++i) { a0 = a0 * 1.0000001 + 1e-9; a1 = a1 * 1.0000001 + 1e-9; a2 = a2 * 1.0000001 + 1e-9; a3 = a3 * 1.0000001 + 1e-9; }
      sink = a0 + a1 + a2 + a3;
    };
    long long iters = 1 << 20;
    for (int c = 0; c < 4; ++c) {
      double t0 = MPI_Wtime();
      spin(iters);
      double dt = std::max(MPI_Wtime() - t0, 1e-6);
      iters = std::max<long long>(chunks, (long long)((double)iters * (kernel_ms * 1e-3) / dt));
    }
    std::vector<char> buf((size_t)2 * ov_bytes + 8, 0);
    const int cnt = (int)(ov_bytes / 8);
    const int partner = rank ^ 1;
    auto comm_blocking = [&]() {
      if (!p2p) MPI_Allreduce(MPI_IN_PLACE, buf.data(), cnt, MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);
      else MPI_Sendrecv(buf.data(), (int)ov_bytes, MPI_BYTE, partner, 3, buf.data() + ov_bytes, (int)ov_bytes, MPI_BYTE, partner, 3, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
    };
    auto comm_post = [&](MPI_Request* rq) {
      if (!p2p) {
        MPI_Iallreduce(MPI_IN_PLACE, buf.data(), cnt, MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD, &rq[0]);
        rq[1] = MPI_REQUEST_NULL;
      } else {
        MPI_Irecv(buf.data() + ov_bytes, (int)ov_bytes, MPI_BYTE, partner, 3, MPI_COMM_WORLD, &rq[0]);
        MPI_Isend(buf.data(), (int)ov_bytes, MPI_BYTE, partner, 3, MPI_COMM_WORLD, &rq[1]);
      }
    };
    auto timeit = [&](const std::string& v) {
      double t = 0;
      for (int r = -3; r < reps; ++r) {
        MPI_Barrier(MPI_COMM_WORLD);
        double t0 = MPI_Wtime();
        MPI_Request rq[2] = {MPI_REQUEST_NULL, MPI_REQUEST_NULL};
        if (v == "comm_only") comm_blocking();
        else if (v == "compute_only") spin(iters);
        else if (v == "seq") { comm_blocking(); spin(iters); }
        else if (v == "nopoll") { comm_post(rq); spin(iters); MPI_Waitall(2, rq, MPI_STATUSES_IGNORE); }
        else {  // poll
          comm_post(rq);
          const long long step = std::max<long long>(1, iters / chunks);
          for (long long done = 0; done < iters; done += step) {
            spin(std::min(step, iters - done));
            int flag = 0;
            MPI_Testall(2, rq, &flag, MPI_STATUSES_IGNORE);
          }
          MPI_Waitall(2, rq, MPI_STATUSES_IGNORE);
        }
        if (r >= 0) t += MPI_Wtime() - t0;
      }
      t /= reps;
      double tmax = 0;
      MPI_Reduce(&t, &tmax, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);
      return tmax;
    };
    const double t_comm = timeit("comm_only"), t_comp = timeit("compute_only"), t_seq = timeit("seq");
    const double t_nop = timeit("nopoll"), t_poll = timeit("poll");
    if (rank == 0) {
      const double lim = std::min(t_comm, t_comp);
      const char* tn = p2p ? "overlap_cpu_p2p" : "overlap_cpu";
      std::printf("%s,comm_only,%lld,%.9g,\n", tn, ov_bytes, t_comm);
      std::printf("%s,compute_only,%lld,%.9g,\n", tn, ov_bytes, t_comp);
      std::printf("%s,seq,%lld,%.9g,\n", tn, ov_bytes, t_seq);
      std::printf("%s,nopoll,%lld,%.9g,overlap_efficiency=%.3f\n", tn, ov_bytes, t_nop, (t_seq - t_nop) / lim);
      std::printf("%s,poll_%dchunks,%lld,%.9g,overlap_efficiency=%.3f\n", tn, chunks, ov_bytes, t_poll, (t_seq - t_poll) / lim);
    }
  } else if (test == "overlap" || test == "overlap_p2p") {
    const bool p2p = test == "overlap_p2p";
    if (p2p && P % 2 != 0) die("overlap_p2p needs an even number of ranks");
    // 1. calibrate the spin kernel to run ~kernel_ms
    const int bs = 256, nb = 2048;
    void* out = nullptr;
    CUDA_CHECK(cudaMalloc(&out, 16));
    long long iters = 1 << 14;
    cudaEvent_t e0, e1;
    CUDA_CHECK(cudaEventCreate(&e0)); CUDA_CHECK(cudaEventCreate(&e1));
    for (int c = 0; c < 4; ++c) {
      CUDA_CHECK(cudaEventRecord(e0));
      LAUNCH(k_fma<double>, nb, bs, (double*)out, iters);
      CUDA_CHECK(cudaEventRecord(e1));
      CUDA_CHECK(cudaEventSynchronize(e1));
      float ms = 0;
      CUDA_CHECK(cudaEventElapsedTime(&ms, e0, e1));
      iters = std::max<long long>(1, (long long)((double)iters * kernel_ms / std::max(ms, 0.001f)));
    }
    void* buf = nullptr;
    if (devptr) CUDA_CHECK(cudaMalloc(&buf, 2 * ov_bytes)); else CUDA_CHECK(cudaMallocHost(&buf, 2 * ov_bytes));
    CUDA_CHECK(cudaMemset(buf, 0, 2 * ov_bytes));
    const int cnt = (int)(ov_bytes / 8);
    const int partner = rank ^ 1;  // used by the p2p variant only
    // The communication under test: a collective sum (grid-sum like) or a pairwise exchange
    // (ghost-exchange like). Blocking and non-blocking forms.
    auto comm_blocking = [&]() {
      if (!p2p) {
        MPI_Allreduce(MPI_IN_PLACE, buf, cnt, MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);
      } else {
        MPI_Sendrecv(buf, (int)ov_bytes, MPI_BYTE, partner, 3, (char*)buf + ov_bytes, (int)ov_bytes, MPI_BYTE, partner, 3,
                     MPI_COMM_WORLD, MPI_STATUS_IGNORE);
      }
    };
    auto comm_post = [&](MPI_Request* rq) {  // rq has room for 2 requests
      if (!p2p) {
        MPI_Iallreduce(MPI_IN_PLACE, buf, cnt, MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD, &rq[0]);
        rq[1] = MPI_REQUEST_NULL;
      } else {
        MPI_Irecv((char*)buf + ov_bytes, (int)ov_bytes, MPI_BYTE, partner, 3, MPI_COMM_WORLD, &rq[0]);
        MPI_Isend(buf, (int)ov_bytes, MPI_BYTE, partner, 3, MPI_COMM_WORLD, &rq[1]);
      }
    };
    auto timeit = [&](const char* variant) {
      double t = 0;
      for (int r = -3; r < reps; ++r) {
        MPI_Barrier(MPI_COMM_WORLD);
        if (r == 0) t = 0;
        double t0 = MPI_Wtime();
        std::string v = variant;
        MPI_Request req[2] = {MPI_REQUEST_NULL, MPI_REQUEST_NULL};
        if (v == "comm_only") {
          comm_blocking();
        } else if (v == "kernel_only") {
          LAUNCH(k_fma<double>, nb, bs, (double*)out, iters);
          CUDA_CHECK(cudaDeviceSynchronize());
        } else if (v == "seq") {
          comm_blocking();
          LAUNCH(k_fma<double>, nb, bs, (double*)out, iters);
          CUDA_CHECK(cudaDeviceSynchronize());
        } else {
          comm_post(req);
          LAUNCH(k_fma<double>, nb, bs, (double*)out, iters);
          if (v == "wait") {
            MPI_Waitall(2, req, MPI_STATUSES_IGNORE);
            CUDA_CHECK(cudaDeviceSynchronize());
          } else if (v == "sync") {
            CUDA_CHECK(cudaDeviceSynchronize());
            MPI_Waitall(2, req, MPI_STATUSES_IGNORE);
          } else {  // poll
            int flag = 0;
            while (!flag) MPI_Testall(2, req, &flag, MPI_STATUSES_IGNORE);
            CUDA_CHECK(cudaDeviceSynchronize());
          }
        }
        if (r >= 0) t += MPI_Wtime() - t0;
      }
      t /= reps;
      double tmax = 0;
      MPI_Reduce(&t, &tmax, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);
      return tmax;
    };
    const double t_comm = timeit("comm_only"), t_comp = timeit("kernel_only"), t_seq = timeit("seq");
    const double t_wait = timeit("wait"), t_sync = timeit("sync"), t_poll = timeit("poll");
    if (rank == 0) {
      const double lim = std::min(t_comm, t_comp);
      const char* tn = test.c_str();
      std::printf("%s,comm_only,%lld,%.9g,\n", tn, ov_bytes, t_comm);
      std::printf("%s,kernel_only,%lld,%.9g,\n", tn, ov_bytes, t_comp);
      std::printf("%s,seq,%lld,%.9g,\n", tn, ov_bytes, t_seq);
      std::printf("%s,wait,%lld,%.9g,overlap_efficiency=%.3f\n", tn, ov_bytes, t_wait, (t_seq - t_wait) / lim);
      std::printf("%s,sync,%lld,%.9g,overlap_efficiency=%.3f\n", tn, ov_bytes, t_sync, (t_seq - t_sync) / lim);
      std::printf("%s,poll,%lld,%.9g,overlap_efficiency=%.3f\n", tn, ov_bytes, t_poll, (t_seq - t_poll) / lim);
    }
  } else {
    die("unknown --test (pingpong|allreduce|copy|flops|overlap|overlap_p2p|overlap_cpu)");
  }
  MPI_Finalize();
  return 0;
}
