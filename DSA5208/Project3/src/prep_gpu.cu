// prep_gpu.cu — exact brute-force kNN graph on one GPU (+ PC1 on the CPU).
//
//   prep_gpu --feat data/g.feat.bin --labels data/g.labels.bin --k 90 --out data/g.ds.bin
//
// Same output as prep_cpu (exact neighbours, so recall is 1 by construction), but fast enough
// for N ~ 1e6: one thread per query scans all points and keeps its k best candidates in a
// sorted private list. Roughly N^2 D flops; about a minute-scale job for N = 1e6, D = 50 on a
// modern GPU. Features are processed in float. Preprocessing time is reported separately in
// the project and is not part of the t-SNE timings.
#include <cstdio>

#define TSNE_GPU
#include "tsne_common.h"

static const int KMAX = 128;  // largest supported k

// One thread = one query. Distances in float. The private top-k list is kept sorted ascending;
// after the first k candidates almost every new candidate is rejected by one comparison.
__global__ void k_knn(const float* __restrict__ X, int N, int D, int k, int q0, int nq, int* outIdx, float* outD2) {
  long long t = (long long)blockIdx.x * blockDim.x + threadIdx.x;
  if (t >= nq) return;
  const int qi = q0 + (int)t;
  const float* xq = X + (long long)qi * D;
  float bd[KMAX];
  int bi[KMAX];
  for (int s = 0; s < k; ++s) { bd[s] = 3.0e38f; bi[s] = -1; }
  float worst = 3.0e38f;
  for (int j = 0; j < N; ++j) {
    if (j == qi) continue;
    const float* xj = X + (long long)j * D;
    float d = 0.f;
    for (int c = 0; c < D; ++c) {
      float diff = xq[c] - xj[c];
      d += diff * diff;
    }
    if (d < worst) {  // insert into the sorted list
      int s = k - 1;
      while (s > 0 && bd[s - 1] > d) { bd[s] = bd[s - 1]; bi[s] = bi[s - 1]; --s; }
      bd[s] = d;
      bi[s] = j;
      worst = bd[k - 1];
    }
  }
  for (int s = 0; s < k; ++s) {
    outIdx[(long long)t * k + s] = bi[s];
    outD2[(long long)t * k + s] = bd[s];
  }
}

int main(int argc, char** argv) {
  Args a(argc, argv);
  const std::string featp = a.str("feat", "");
  const std::string labp = a.str("labels", "");
  const std::string outp = a.str("out", "data/dataset.ds.bin");
  const int k = (int)a.integer("k", 90);
  const int block = (int)a.integer("block", 128);
  const long long batch = a.integer("batch", 1 << 17);
  const int device = (int)a.integer("device", 0);
  for (auto& u : a.unused()) std::fprintf(stderr, "warning: unused option --%s\n", u.c_str());
  if (featp.empty()) die("--feat is required");
  if (k > KMAX) die("k exceeds KMAX (128); change KMAX in prep_gpu.cu");

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

  CUDA_CHECK(cudaSetDevice(device));
  double t0 = wall_time();
  compute_pc1(f, ds.pc1);
  double t1 = wall_time();

  DevBuf<float> dX;
  DevBuf<int> dIdx;
  DevBuf<float> dD2;
  dX.upload(f.x.data(), f.x.size());
  dIdx.reserve((size_t)batch * k);
  dD2.reserve((size_t)batch * k);
  for (int64_t q0 = 0; q0 < N; q0 += batch) {
    int nq = (int)std::min<int64_t>(batch, N - q0);
    LAUNCH(k_knn, blocks_for(nq, block), block, dX.p, (int)N, (int)D, k, (int)q0, nq, dIdx.p, dD2.p);
    CUDA_CHECK(cudaDeviceSynchronize());
    CUDA_CHECK(cudaMemcpy(&ds.idx[(size_t)q0 * k], dIdx.p, (size_t)nq * k * sizeof(int), cudaMemcpyDeviceToHost));
    CUDA_CHECK(cudaMemcpy(&ds.d2[(size_t)q0 * k], dD2.p, (size_t)nq * k * sizeof(float), cudaMemcpyDeviceToHost));
    std::printf("\rknn %lld / %lld", (long long)(q0 + nq), (long long)N);
    std::fflush(stdout);
  }
  double t2 = wall_time();
  write_dataset(outp, ds);
  std::printf("\nprep_gpu: N=%lld D=%lld k=%d  pc1 %.2fs  knn %.2fs  -> %s\n", (long long)N, (long long)D, k, t1 - t0,
              t2 - t1, outp.c_str());
  return 0;
}
