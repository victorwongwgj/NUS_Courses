# Makefile -- builds every program of the project into $(BUILD)/ (default: build/).
#
#   make cpu      CPU tools: tsne_tools (gen-data, prep-cpu, eval, compare-grad, fitsne-io) and the serial tsne_cpu
#                 needs only a C++17 compiler; use OMP=1 to enable OpenMP in the preprocessing / evaluation tools
#   make cpumpi   pure-MPI CPU parallel program tsne_mpi_cpu, the CPU-only communication micro-benchmark microbench_cpu and coll_bench
#                 needs an MPI C++ wrapper (mpicxx)
#   make gpu      MPI+CUDA program tsne_gpu, GPU kNN prep_gpu, GPU/MPI micro-benchmark microbench
#                 needs nvcc (CUDA >= 12 with cuFFT) and an MPI library
#   make all      = cpu + cpumpi + gpu
#
# Variables (override on the command line, e.g. `make gpu ARCH=sm_80 BUILD=build_hpcx`):
#   CXX      host compiler for the serial tools         (default g++)
#   MPICXX   MPI C++ wrapper                            (default mpicxx)
#   NVCC     CUDA compiler                              (default nvcc)
#   ARCH     GPU architecture; A40 = sm_86 (Vanda)      (default sm_86)
#   REAL     double (default) or float: precision of the GPU path (float builds get the suffix _float)
#   OMP      1 = build the serial CPU tools with OpenMP (default 0)
#   BUILD    output directory                           (default build)
#   NVCC_MPI_FLAGS  extra include/link flags if `nvcc -ccbin $(MPICXX)` does not find MPI, e.g.
#                   NVCC_MPI_FLAGS="$(shell mpicxx --showme:compile) $(shell mpicxx --showme:link)"

CXX      ?= g++
MPICXX   ?= mpicxx
NVCC     ?= nvcc
ARCH     ?= sm_86
REAL     ?= double
OMP      ?= 0
BUILD    ?= build

CXXFLAGS := -O3 -std=c++17 -Wall -Wextra
ifeq ($(OMP),1)
CXXFLAGS += -fopenmp
endif
ifeq ($(REAL),float)
REALDEF := -DTSNE_REAL_FLOAT
SUFFIX  := _float
endif
NVCCFLAGS := -O3 -std=c++17 -arch=$(ARCH) $(REALDEF) -lineinfo
# Flags for compiling the .cu files as plain C++ (CPU emulation of the CUDA subset, src/cuda_emu.h)
EMUFLAGS  := -x c++ -std=c++17 -O2 -Wall -Wextra -Wno-unused-parameter -DTSNE_EMULATE $(REALDEF)

HDR := src/tsne_common.h

.PHONY: all cpu cpumpi gpu clean dirs
all: cpu cpumpi gpu

dirs:
	@mkdir -p $(BUILD)

# ---- serial CPU programs --------------------------------------------------------------------
cpu: dirs $(BUILD)/tsne_tools $(BUILD)/tsne_cpu

$(BUILD)/tsne_tools: src/tools.cpp src/core.cpp $(HDR)
	$(CXX) $(CXXFLAGS) src/tools.cpp src/core.cpp -o $@
$(BUILD)/tsne_cpu: src/tsne_cpu.cpp src/core.cpp $(HDR)
	$(CXX) $(CXXFLAGS) src/tsne_cpu.cpp src/core.cpp -o $@

# ---- pure-MPI CPU parallel program ----------------------------------------------------------
cpumpi: dirs $(BUILD)/tsne_mpi_cpu $(BUILD)/microbench_cpu $(BUILD)/coll_bench

$(BUILD)/tsne_mpi_cpu: src/tsne_mpi_cpu.cpp src/core.cpp $(HDR)
	$(MPICXX) $(CXXFLAGS) src/tsne_mpi_cpu.cpp src/core.cpp -o $@
# collective-communication benchmark of the grid sum (Table `coll`)
$(BUILD)/coll_bench: src/coll_bench.cpp
	$(MPICXX) -O2 -std=c++17 $< -o $@
# microbench.cu compiled as plain C++ (only its CPU test `overlap_cpu` is used on the CPU cluster)
$(BUILD)/microbench_cpu: src/microbench.cu $(HDR) src/cuda_emu.h
	$(MPICXX) $(EMUFLAGS) src/microbench.cu -o $@

# ---- MPI + CUDA program ---------------------------------------------------------------------
gpu: dirs $(BUILD)/tsne_gpu$(SUFFIX) $(BUILD)/prep_gpu $(BUILD)/microbench

$(BUILD)/tsne_gpu$(SUFFIX): src/tsne_gpu.cu src/core.cpp $(HDR)
	$(NVCC) $(NVCCFLAGS) -ccbin $(MPICXX) $(NVCC_MPI_FLAGS) src/tsne_gpu.cu src/core.cpp -lcufft -o $@
$(BUILD)/prep_gpu: src/prep_gpu.cu src/core.cpp $(HDR)
	$(NVCC) $(NVCCFLAGS) src/prep_gpu.cu src/core.cpp -o $@
$(BUILD)/microbench: src/microbench.cu $(HDR)
	$(NVCC) $(NVCCFLAGS) -ccbin $(MPICXX) $(NVCC_MPI_FLAGS) src/microbench.cu -o $@

clean:
	rm -rf $(BUILD)
