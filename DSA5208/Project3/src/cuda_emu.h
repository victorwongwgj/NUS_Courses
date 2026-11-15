// cuda_emu.h — single-thread CPU emulation of the small CUDA subset used by tsne_gpu.cu.
//
// PURPOSE: lets the *whole* MPI+CUDA program be compiled with a plain C++ compiler (-DTSNE_EMULATE)
// and run on a machine without a GPU (the CPU cluster build `microbench_cpu` of the Makefile uses it). Kernels are run one thread after another, "device"
// memory is ordinary host memory, cuFFT is replaced by the CPU FFT of tsne_common.h. It allows testing the logic
// (indexing, partitioning, communication, FFT convolution) against the serial program. It is NOT
// a performance model and is not used for any timing in the report.
//
// Limitations: kernels must not use __shared__/__syncthreads (the few reduction kernels that do
// are compiled only when TSNE_EMULATE is not defined and have host-loop replacements).
#pragma once
#include <chrono>
#include <complex>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

// (the FFT used in place of cuFFT is the one defined in tsne_common.h, which includes this file)

#define __global__
#define __device__
#define __host__
#define __forceinline__ inline

struct dim3 {
  unsigned x, y, z;
  dim3(unsigned x_ = 1, unsigned y_ = 1, unsigned z_ = 1) : x(x_), y(y_), z(z_) {}
};
inline dim3 threadIdx, blockIdx, blockDim, gridDim;

#define EMU_LAUNCH(kernel, nb, nt, ...)                          \
  do {                                                           \
    gridDim = dim3((unsigned)(nb));                              \
    blockDim = dim3((unsigned)(nt));                             \
    for (unsigned b_ = 0; b_ < gridDim.x; ++b_) {                \
      blockIdx = dim3(b_);                                       \
      for (unsigned t_ = 0; t_ < blockDim.x; ++t_) {             \
        threadIdx = dim3(t_);                                    \
        kernel(__VA_ARGS__);                                     \
      }                                                          \
    }                                                            \
  } while (0)

// ---- runtime API ----
enum cudaError_t { cudaSuccess = 0, cudaErrorNotReady = 600, cudaErrorUnknown = 999 };
enum cudaMemcpyKind { cudaMemcpyHostToHost, cudaMemcpyHostToDevice, cudaMemcpyDeviceToHost, cudaMemcpyDeviceToDevice, cudaMemcpyDefault };
typedef void* cudaStream_t;
struct EmuEvent { double t = 0; };
typedef EmuEvent* cudaEvent_t;
static const unsigned cudaStreamNonBlocking = 1;
inline cudaError_t cudaStreamCreateWithFlags(cudaStream_t* s, unsigned) { *s = nullptr; return cudaSuccess; }
inline cudaError_t cudaStreamWaitEvent(cudaStream_t, cudaEvent_t, unsigned = 0) { return cudaSuccess; }
struct cudaDeviceProp {
  char name[256];
  size_t totalGlobalMem;
  int major, minor, pciBusID, pciDeviceID, pciDomainID;
};

inline const char* cudaGetErrorString(cudaError_t) { return "emulated CUDA error"; }
inline cudaError_t cudaGetLastError() { return cudaSuccess; }
inline cudaError_t cudaGetDeviceCount(int* n) { *n = 1; return cudaSuccess; }
inline cudaError_t cudaSetDevice(int) { return cudaSuccess; }
inline cudaError_t cudaGetDeviceProperties(cudaDeviceProp* p, int) {
  std::memset(p, 0, sizeof *p);
  std::snprintf(p->name, sizeof p->name, "CPU-emulated device");
  p->totalGlobalMem = (size_t)16 << 30;
  p->major = 0;
  p->minor = 0;
  return cudaSuccess;
}
inline cudaError_t cudaRuntimeGetVersion(int* v) { *v = 0; return cudaSuccess; }
inline cudaError_t cudaDriverGetVersion(int* v) { *v = 0; return cudaSuccess; }
inline cudaError_t cudaMemGetInfo(size_t* f, size_t* t) { *f = (size_t)8 << 30; *t = (size_t)16 << 30; return cudaSuccess; }
inline cudaError_t cudaMalloc(void** p, size_t n) { *p = std::malloc(n ? n : 1); return *p ? cudaSuccess : cudaErrorUnknown; }
inline cudaError_t cudaFree(void* p) { std::free(p); return cudaSuccess; }
inline cudaError_t cudaMallocHost(void** p, size_t n) { return cudaMalloc(p, n); }
inline cudaError_t cudaFreeHost(void* p) { std::free(p); return cudaSuccess; }
inline cudaError_t cudaMemcpy(void* d, const void* s, size_t n, cudaMemcpyKind) { std::memcpy(d, s, n); return cudaSuccess; }
inline cudaError_t cudaMemcpyAsync(void* d, const void* s, size_t n, cudaMemcpyKind, cudaStream_t = 0) { std::memcpy(d, s, n); return cudaSuccess; }
inline cudaError_t cudaMemset(void* p, int v, size_t n) { std::memset(p, v, n); return cudaSuccess; }
inline cudaError_t cudaDeviceSynchronize() { return cudaSuccess; }
inline cudaError_t cudaEventCreate(cudaEvent_t* e) { *e = new EmuEvent; return cudaSuccess; }
inline cudaError_t cudaEventDestroy(cudaEvent_t e) { delete e; return cudaSuccess; }
inline cudaError_t cudaEventRecord(cudaEvent_t e, cudaStream_t = 0) {
  e->t = std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count();
  return cudaSuccess;
}
inline cudaError_t cudaEventSynchronize(cudaEvent_t) { return cudaSuccess; }
inline cudaError_t cudaEventQuery(cudaEvent_t) { return cudaSuccess; }
inline cudaError_t cudaEventElapsedTime(float* ms, cudaEvent_t a, cudaEvent_t b) { *ms = (float)((b->t - a->t) * 1e3); return cudaSuccess; }

// atomics (kernels run serially, so plain adds are exact)
inline double atomicAdd(double* a, double v) { double o = *a; *a += v; return o; }
inline float atomicAdd(float* a, float v) { float o = *a; *a += v; return o; }

// ---- cuFFT subset ----
typedef int cufftHandle;
typedef int cufftResult;
enum { CUFFT_SUCCESS = 0 };
typedef double cufftDoubleReal;
typedef float cufftReal;
struct cufftDoubleComplex { double x, y; };
struct cufftComplex { float x, y; };
enum cufftType { CUFFT_R2C, CUFFT_C2R, CUFFT_D2Z, CUFFT_Z2D, CUFFT_C2C, CUFFT_Z2Z };
enum { CUFFT_FORWARD = -1, CUFFT_INVERSE = 1 };

struct EmuPlan { int n0, n1, batch; FFT2D fft; FFT1D f1; };
inline std::vector<EmuPlan*>& emu_plans() { static std::vector<EmuPlan*> v; return v; }

inline cufftResult cufftPlanMany(cufftHandle* h, int rank, int* n, int*, int, int, int*, int, int, cufftType, int batch) {
  if (rank != 1 && rank != 2) return 1;
  // rank 2: the real 2-D transforms of the replicated FFT; rank 1: batched complex 1-D transforms (distributed FFT)
  EmuPlan* p = rank == 2 ? new EmuPlan{n[0], n[1], batch, FFT2D(n[0], n[1]), FFT1D(1)}
                         : new EmuPlan{n[0], 1, batch, FFT2D(1, 1), FFT1D(n[0])};
  emu_plans().push_back(p);
  *h = (int)emu_plans().size() - 1;
  return CUFFT_SUCCESS;
}
inline cufftResult cufftDestroy(cufftHandle h) { delete emu_plans()[h]; emu_plans()[h] = nullptr; return CUFFT_SUCCESS; }

// Real -> half complex spectrum [n0][n1/2+1], per batch entry.
template <class R, class C>
inline cufftResult emu_r2c(cufftHandle h, R* in, C* out) {
  EmuPlan& p = *emu_plans()[h];
  const int n0 = p.n0, n1 = p.n1, nh = n1 / 2 + 1;
  std::vector<cd> w((size_t)n0 * n1);
  for (int b = 0; b < p.batch; ++b) {
    for (size_t e = 0; e < w.size(); ++e) w[e] = cd(in[(size_t)b * n0 * n1 + e], 0.0);
    p.fft.exec(w.data(), false);
    for (int i = 0; i < n0; ++i)
      for (int j = 0; j < nh; ++j) {
        out[(size_t)b * n0 * nh + (size_t)i * nh + j].x = w[(size_t)i * n1 + j].real();
        out[(size_t)b * n0 * nh + (size_t)i * nh + j].y = w[(size_t)i * n1 + j].imag();
      }
  }
  return CUFFT_SUCCESS;
}
// Half spectrum -> real (unnormalised inverse), using Hermitian symmetry for the missing half.
template <class R, class C>
inline cufftResult emu_c2r(cufftHandle h, C* in, R* out) {
  EmuPlan& p = *emu_plans()[h];
  const int n0 = p.n0, n1 = p.n1, nh = n1 / 2 + 1;
  std::vector<cd> w((size_t)n0 * n1);
  for (int b = 0; b < p.batch; ++b) {
    const C* s = in + (size_t)b * n0 * nh;
    for (int i = 0; i < n0; ++i)
      for (int j = 0; j < n1; ++j) {
        if (j < nh) w[(size_t)i * n1 + j] = cd(s[(size_t)i * nh + j].x, s[(size_t)i * nh + j].y);
        else {
          const C& c = s[(size_t)((n0 - i) % n0) * nh + (n1 - j)];
          w[(size_t)i * n1 + j] = cd(c.x, -c.y);
        }
      }
    p.fft.exec(w.data(), true);
    for (size_t e = 0; e < w.size(); ++e) out[(size_t)b * n0 * n1 + e] = (R)w[e].real();
  }
  return CUFFT_SUCCESS;
}
inline cufftResult cufftExecD2Z(cufftHandle h, cufftDoubleReal* i, cufftDoubleComplex* o) { return emu_r2c(h, i, o); }
inline cufftResult cufftExecZ2D(cufftHandle h, cufftDoubleComplex* i, cufftDoubleReal* o) { return emu_c2r(h, i, o); }
inline cufftResult cufftExecR2C(cufftHandle h, cufftReal* i, cufftComplex* o) { return emu_r2c(h, i, o); }
inline cufftResult cufftExecC2R(cufftHandle h, cufftComplex* i, cufftReal* o) { return emu_c2r(h, i, o); }

// Batched 1-D complex transforms (contiguous, distance n), in place or out of place.
template <class C>
inline cufftResult emu_c2c(cufftHandle h, C* in, C* out, int dir) {
  EmuPlan& p = *emu_plans()[h];
  const int n = p.n0;
  std::vector<cd> w(n), o(n);
  for (int b = 0; b < p.batch; ++b) {
    for (int i = 0; i < n; ++i) w[i] = cd(in[(size_t)b * n + i].x, in[(size_t)b * n + i].y);
    p.f1.transform(w.data(), o.data(), dir == CUFFT_INVERSE);
    for (int i = 0; i < n; ++i) { out[(size_t)b * n + i].x = o[i].real(); out[(size_t)b * n + i].y = o[i].imag(); }
  }
  return CUFFT_SUCCESS;
}
inline cufftResult cufftExecZ2Z(cufftHandle h, cufftDoubleComplex* i, cufftDoubleComplex* o, int dir) { return emu_c2c(h, i, o, dir); }
inline cufftResult cufftExecC2C(cufftHandle h, cufftComplex* i, cufftComplex* o, int dir) { return emu_c2c(h, i, o, dir); }
