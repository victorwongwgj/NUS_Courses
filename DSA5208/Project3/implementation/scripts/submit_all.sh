#!/usr/bin/env bash
# submit_all.sh -- the catalogue of every Vanda job behind the results of the report, with the parameters actually used.
#
#   implementation/scripts/submit_all.sh GROUP [GROUP ...]          prints the qsub lines of the groups (nothing is submitted)
#   SUBMIT=1 implementation/scripts/submit_all.sh GROUP ...         submits them
#   GROUPS: data  serial  validation  cpu-strong  cpu-comm  cpu-weak  cpu-real  gpu  gpu-dist  official  diagnostics  all
#   (run `implementation/scripts/submit_all.sh` without argument to list the groups)
#
# Run it on the Vanda login node from the project directory (the directory that contains Makefile, implementation/scripts/, implementation/jobs/).  Each line is one job; jobs of one
# group are independent unless a comment says otherwise (data sets must exist before the studies that read them: submit group `data` first and wait).
# Walltimes and memory are the values to request for a full-length run.
# Optional variables:  PROJECT=<your HPC project> (required for SUBMIT=1; passed to qsub as -P),  CPUQ=<queue>.
# The result directory of each job (RES=...) matches the directory names read by the notebooks in implementation/analysis/ (copy the result directories into output/).
set -euo pipefail
cd "$(dirname "$0")/../.."; mkdir -p logs
CPU=implementation/jobs/vanda_cpu.pbs; GPU=implementation/jobs/vanda_gpu.pbs
PROJECT=${PROJECT:-PROJECT_ID}
[ "${SUBMIT:-0}" = 1 ] && [ "$PROJECT" = PROJECT_ID ] && { echo "set PROJECT=<your HPC project> to submit" >&2; exit 2; }
Q=(-P "$PROJECT"); [ -n "${CPUQ:-}" ] && Q+=(-q "$CPUQ")
sub() {   # sub JOBFILE NAME "RESOURCE_LIST" "-v VARIABLES"      (RESOURCE_LIST: space-separated -l arguments)
  local jf=$1 nm=$2 res=$3 vars=$4 cmd=(qsub "${Q[@]}" -N "$2") r
  for r in $res; do cmd+=(-l "$r"); done
  cmd+=(-v "$vars" "$jf")
  echo "${cmd[*]}"; [ "${SUBMIT:-0}" = 1 ] && "${cmd[@]}"; return 0
}
# resource shortcuts
n1="select=1:ncpus=72:mpiprocs=72:mem=200gb place=pack:excl"          # one full CPU node
n2="select=2:ncpus=72:mpiprocs=72:mem=200gb place=scatter:excl"
n4="select=4:ncpus=72:mpiprocs=72:mem=200gb place=scatter:excl"
n8="select=8:ncpus=72:mpiprocs=72:mem=200gb place=scatter:excl"
core="select=1:ncpus=1:mem=16gb place=excl"                            # one core of an otherwise idle node
g1="select=1:ncpus=8:ngpus=1:mem=32gb"                                  # one A40
g2="select=1:ncpus=16:ngpus=2:mem=100gb"                                # two A40 on one node (the server gives the whole node)
g2n="select=2:ncpus=8:ngpus=1:mem=32gb place=scatter"                   # two A40 on two nodes
wt() { echo "walltime=$1"; }

grp_data() {   # all data sets (deterministic: seed 1); the kNN graphs need a GPU (prep_gpu)
  sub $GPU data_big      "$g1 $(wt 03:00:00)" "SCRIPT=implementation/scripts/prepare.sh,CMD=big"
  sub $GPU data_weak10k  "$g1 $(wt 03:00:00)" "SCRIPT=implementation/scripts/prepare.sh,CMD=weak,NPR=10000,PS=1_2_4_8_16_32_64_128"      # g10000 ... g1280000 (serial nscale + weak scaling)
  sub $GPU data_weak5k   "$g1 $(wt 03:00:00)" "SCRIPT=implementation/scripts/prepare.sh,CMD=weak,NPR=5000,PS=1_16_64_128_256_512"        # g5000, g80000, g320000, g640000, g1280000, g2560000
  echo "# real data: python3 implementation/scripts/h5ad_to_bin.py tabula_sapiens.h5ad data/ts --pcs 50 --label-key cell_type ; and the subsets"
  echo "#   ... data/ts200k --subsample 200000 --seed 1 ; data/ts50k --subsample 50000 --seed 1 ; data/ts10k --subsample 10000 --seed 1   (same file, same PCs)"
  sub $GPU data_real     "$g1 $(wt 02:00:00)" "SCRIPT=implementation/scripts/prepare.sh,CMD=real-knn"
  sub $CPU build_official "select=1:ncpus=4:mem=24gb $(wt 00:30:00)" "SCRIPT=implementation/scripts/prepare.sh,CMD=official-build"   # needs ../FIt-SNE-master (and FFTW, see prepare.sh)
}

grp_serial() {   # S1, S2, X3 (one core each; do not share the node with other jobs)
  sub $CPU ser_base   "select=1:ncpus=1:mem=32gb place=excl $(wt 06:00:00)" "SCRIPT=implementation/scripts/cpu_studies.sh,CMD=serial-all,SERIAL_STUDIES=base+grid+npts+exact,RES=results_vanda_cpu_v2"
  sub $CPU ser_nscale "select=1:ncpus=8:mem=48gb place=excl $(wt 03:00:00)" "SCRIPT=implementation/scripts/cpu_studies.sh,CMD=serial-all,SERIAL_STUDIES=nscale,RES=results_vanda_cpu_v2"       # 6 GB per core limit
  sub $CPU ser_knn    "select=1:ncpus=1:mem=32gb place=excl $(wt 06:00:00)" "SCRIPT=implementation/scripts/cpu_studies.sh,CMD=serial-knn,KN=20000_50000,KS=15_30_60_90_150_300,BOXES=100,ITERS=100,PREP=cpu,RES=results_vanda_cpu_knn"
  sub $CPU ser_cross  "$core $(wt 04:00:00)" "SCRIPT=implementation/scripts/cpu_studies.sh,CMD=crossover,NSIZES=2000_3000_4000_5000_6000_8000_10000,REPS=2,ITERS=1000,RES=results_vanda_cross"
  sub $CPU ser_pcost  "$core $(wt 01:00:00)" "SCRIPT=implementation/scripts/cpu_studies.sh,CMD=pcost,NAMES=g100k,BOXES=200,ITERS=30,REPS=3,RES=results_pcost"
}

grp_validation() {   # V1, V2
  sub $CPU exact_val  "select=1:ncpus=12:mem=32gb $(wt 02:30:00)" "SCRIPT=implementation/scripts/cpu_studies.sh,CMD=validation,N=5000,ITERS=1000,PS=4_12,NCPUS=12,RES=results_validation"
  sub $CPU gate_1n    "$n1 $(wt 00:40:00)" "STUDIES=gate,PSLIST=1_2_4_8,RES=results_vcpu_gate"
  sub $CPU gate_2n    "$n2 $(wt 01:00:00)" "STUDIES=gate,PSLIST=1_4_72_144,RES=results_vcpu_gate"
  sub $CPU quality_P  "$n1 $(wt 04:00:00)" "STUDIES=quality,PSLIST=1_4_16_64,DATA=g100k,SEEDS=1_2_3,QGRID=200,QFFT=distributed,RES=results_vcpu_q"
}

grp_cpu_strong() {   # C1 (paired, interleaved rounds; replicated FFT only up to E_REP_MAXP ranks)
  sub $CPU E400     "$n1 $(wt 04:00:00)" "STUDIES=E,PSLIST=1_2_4_8_16_32_64,N_STRONG=250000,EBOXES=400,EITERS=100,ROUNDS=3,RES=results_vcpu_E400"
  sub $CPU E200     "$n1 $(wt 04:00:00)" "STUDIES=E,PSLIST=1_2_4_8_16_32_64,N_STRONG=250000,EBOXES=200,EITERS=100,ROUNDS=3,RES=results_vcpu_E200"
  sub $CPU E512     "$n1 $(wt 03:30:00)" "STUDIES=E,PSLIST=1_2_4_8_16_32_64,N_STRONG=250000,EBOXES=512,EITERS=100,ROUNDS=3,RES=results_vcpu_E512"
  sub $CPU E400_big "$n8 $(wt 02:30:00)" "STUDIES=E,PSLIST=1_2_4_8_16_32_64_128_256_512,N_STRONG=250000,EBOXES=400,EITERS=100,ROUNDS=3,E_REP_MAXP=64,RES=results_vcpu_E400_big"
  sub $CPU E512_big "$n8 $(wt 02:30:00)" "STUDIES=E,PSLIST=1_2_4_8_16_32_64_128_256_512,N_STRONG=250000,EBOXES=512,EITERS=100,ROUNDS=3,E_REP_MAXP=1,RES=results_vcpu_E512_big"
  sub $CPU E768_1m  "select=8:ncpus=72:mpiprocs=72:mem=400gb place=scatter:excl $(wt 03:00:00)" "STUDIES=E,PSLIST=1_2_4_8_16_32_64_128_256_512,N_STRONG=1000000,EBOXES=768,EITERS=60,ROUNDS=2,E_REP_MAXP=1,RES=results_vcpu_E768_1m"
  sub $CPU E200_big "$n4 $(wt 02:00:00)" "STUDIES=E,PSLIST=1_64_128_256,N_STRONG=250000,EBOXES=200,EITERS=100,ROUNDS=3,E_REP_MAXP=1,RES=results_vcpu_E200_big"   # 200 boxes, P=64..256 (Table strong200, second job)
  echo "# then:  copy the result directories into output/ and run the notebooks of implementation/analysis/ (01_summary_tables writes the E_summary.csv files), see README.md"
}

grp_cpu_comm() {   # C2 uses the E results; C3 placement; C4 exchange variants; X1/X2 ablations
  sub $CPU place_4n   "$n4 $(wt 01:30:00)" "STUDIES=place,LAYOUTS=64:64_64:32_64:16_128:64_128:32,ROUNDS=2,BOXES=400,ITERS=100,DATA=g250k,RES=results_place"
  sub $CPU place_256  "$n4 $(wt 01:30:00)" "STUDIES=place,LAYOUTS=128:64_128:43_128:32_256:64_256:72,ROUNDS=2,BOXES=400,ITERS=100,DATA=g250k,RES=results_place256"
  sub $CPU exch_F     "$n4 $(wt 04:00:00)" "STUDIES=F,PSLIST=16_64_128_256,N_STRONG=250000,GRID_FIXED=auto,REPS=3,ITERS=200,RES=results_vcpu_F"
  sub $CPU place_8    "$n4 $(wt 01:30:00)" "STUDIES=place,LAYOUTS=256:64_256:72_216:72_216:54_144:72_144:48,ROUNDS=2,BOXES=400,ITERS=100,DATA=g250k,RES=results_place8"   # P=144, 216, 256 (Fig. R4, Table app-place)
  sub $CPU exch_F_rep "select=2:ncpus=72:mpiprocs=72:mem=500gb place=scatter:excl $(wt 02:30:00)" "STUDIES=F,PSLIST=128,N_STRONG=250000,GRID_FIXED=auto,REPS=5,ITERS=200,RES=results_vcpu_F_rep"   # C4 at P=128, 5 repeats (Fig. R5)
  sub $CPU bgs_poll   "$n2 $(wt 00:55:00)" "STUDIES=Bgs,PSLIST=64_128,N_STRONG=250000,GRID_FIXED=400,REPS=2,ITERS=20,RES=results_bgs_poll2"   # blocking / non-blocking / polling grid sum, replicated FFT (Table gridsum)
  sub $CPU coll       "$n2 $(wt 00:20:00)" "SCRIPT=implementation/scripts/coll_bench.sh,LAYOUTS=16:16_64:64_128:64,COLL_BOXES=400,REPS=20,RES=results_coll"   # Reduce_scatter / Allgather / Allreduce / Alltoall of the 46 MB partial grid (Table coll)
  sub $CPU ablation   "$n2 $(wt 01:15:00)" "STUDIES=ablation,PSLIST=16_64_128,ROUNDS=3,BOXES=400,ITERS=100,DATA=g250k,RES=results_ablation"
}

grp_cpu_weak() {   # W1
  sub $CPU weak10k "$n2 $(wt 03:00:00)" "STUDIES=W,PSLIST=1_2_4_8_16_32_64_128,N_PER_GPU=10000,WEAK_N0_BOXES=40,FIXED_BOXES=128,NO_GEN=1,REPS=3,ITERS=300,WEAK_VARIANTS=sqrtgrid_fftdist+sqrtgrid_fftrep+fixed_B1,RES=results_vcpu_weak"
  sub $CPU weak10k_hi "$n2 $(wt 03:00:00)" "STUDIES=W,PSLIST=64_128,N_PER_GPU=10000,WEAK_N0_BOXES=40,FIXED_BOXES=128,NO_GEN=1,REPS=3,ITERS=300,WEAK_VARIANTS=sqrtgrid_fftdist+fixed_B1,RES=results_vcpu_weak"   # re-run of P=64,128 without the slow replicated variant
  sub $CPU weak5k  "$n4 $(wt 03:00:00)" "STUDIES=W,PSLIST=1_16_64_128_256,N_PER_GPU=5000,WEAK_N0_BOXES=28,FIXED_BOXES=128,NO_GEN=1,REPS=2,ITERS=100,WEAK_VARIANTS=sqrtgrid_fftdist+fixed_B1,RES=results_vcpu_weak256"
  sub $CPU weak512 "select=8:ncpus=72:mpiprocs=72:mem=400gb place=scatter:excl $(wt 04:00:00)" "STUDIES=W,PSLIST=1_512,N_PER_GPU=5000,WEAK_N0_BOXES=28,FIXED_BOXES=128,NO_GEN=1,REPS=2,ITERS=100,WEAK_VARIANTS=sqrtgrid_fftdist+fixed_B1,RES=results_vcpu_weak512"   # attempted P=512 point
}

grp_cpu_real() {   # R1 (CPU)
  sub $CPU real_a "$n1 $(wt 04:00:00)" "STUDIES=realcpu,PSLIST=1_4_12_36_72,REAL=ts50k,REAL_BOXES=540,ITERS=300,REPS=3,RES=results_vcpu_real"
  sub $CPU real_b "$n4 $(wt 02:00:00)" "STUDIES=realcpu,PSLIST=36_72_144_288,REAL=ts50k,REAL_BOXES=540,ITERS=100,REPS=2,RES=results_vcpu_real2"
}

grp_gpu() {   # G1-G3 and the GPU parts of V2/R1
  local hx="MODULES=nvhpc-hpcx-cuda12/26.1,BUILD=build_hpcx"          # CUDA-aware Open MPI (HPC-X); BIN lives in its own build directory
  sub $GPU gate_gpu      "$g2 $(wt 01:30:00)"  "STUDIES=gate,PSLIST=1_2,RES=results"
  sub $GPU gate_hpcx     "$g2 $(wt 01:30:00)"  "STUDIES=gate,PSLIST=1_2,GATE_TRANSPORTS=host_device,$hx,RES=results_hpcx_gate"
  sub $GPU gate_hpcx_2n  "$g2n $(wt 01:30:00)" "STUDIES=gate,PSLIST=2,GATE_TRANSPORTS=host_device,MULTINODE=1,$hx,RES=results_hpcx_gate_2n_u"
  sub $GPU gpu_base      "$g1 $(wt 03:00:00)"  "STUDIES=base,PSLIST=1,GRID_FIXED=auto,RES=results_fx"                          # G1: one GPU, 250k and 1M, fixed grids (400 / 800 boxes)
  sub $GPU gpu_C         "$g1 $(wt 03:00:00)"  "STUDIES=C,PSLIST=1,N_C=1000000,RES=results"                                   # G3: write conflicts (probe kernels, order p, clustering, block size)
  sub $GPU gpu_P2        "$g2 $(wt 04:00:00)"  "STUDIES=A+B,PSLIST=2,GRID_FIXED=auto,NO_GEN=1,RES=results_fx"                    # G2: P=2, one node, host-staged
  sub $GPU gpu_P2_450    "$g2 $(wt 04:00:00)"  "STUDIES=A+B,PSLIST=2,GRID_FIXED=450,NO_GEN=1,RES=results_fx450"
  sub $GPU gpu_P2_2n     "$g2n $(wt 04:00:00)" "STUDIES=A+B,PSLIST=2,GRID_FIXED=auto,NO_GEN=1,MULTINODE=1,RES=results_fx_2n"    # G2: P=2, two nodes
  sub $GPU gpu_adaptive  "$g2 $(wt 04:00:00)"  "STUDIES=A+B,PSLIST=2,NO_GEN=1,RES=results_ad"                                   # adaptive grid: cuFFT plan rebuild cost
  sub $GPU gpu_dev_1n    "$g2 $(wt 04:00:00)"  "STUDIES=A+B,PSLIST=2,GRID_FIXED=auto,TRANSPORT=device,NO_GEN=1,$hx,RES=results_fx_device"          # CUDA-aware, one node
  sub $GPU gpu_host_1n   "$g2 $(wt 04:00:00)"  "STUDIES=A+B,PSLIST=2,GRID_FIXED=auto,TRANSPORT=host,NO_GEN=1,$hx,RES=results_fx_hpcxhost"          # same MPI library, host-staged
  sub $GPU gpu_dev_2n    "$g2n $(wt 04:00:00)" "STUDIES=A+B,PSLIST=2,GRID_FIXED=auto,TRANSPORT=device,NO_GEN=1,MULTINODE=1,$hx,RES=results_fx_device_2n_u"
  sub $GPU gpu_host_2n   "$g2n $(wt 04:00:00)" "STUDIES=A+B,PSLIST=2,GRID_FIXED=auto,TRANSPORT=host,NO_GEN=1,MULTINODE=1,$hx,RES=results_fx_hpcxhost_2n_u"
  sub $GPU micro_1n      "$g2 $(wt 01:00:00)"  "STUDIES=micro,PSLIST=2,RES=results_micro_device"
  sub $GPU micro_2n      "$g2n $(wt 01:00:00)" "STUDIES=micro,PSLIST=2,MULTINODE=1,RES=results_micro_2n"
  sub $GPU hpcx_probe    "$g2n $(wt 00:30:00)" "STUDIES=hpcx_probe,MULTINODE=1,$hx,RES=results_hpcx_probe"
  sub $GPU gpu_samegrid  "select=1:ncpus=8:ngpus=1:mem=64gb $(wt 01:30:00)" "STUDIES=samegrid,CASES=g250k:400_g250k:512_g1m:768_g1m:800,ITERS=200,REPS=3,QCASES=g250k:400_g1m:768,QSEEDS=1_2_3,QITERS=1000,RES=results_gpu_samegrid"   # G3: same grids as the CPU, float vs double
  sub $GPU quality_gpu   "$g2 $(wt 04:00:00)"  "STUDIES=quality,PSLIST=1_2,DATA=g250k,SEEDS=1_2_3,RES=results"   # adaptive grid, 1000 iterations
  sub $GPU quality_gpu_2n "$g2n $(wt 04:00:00)" "STUDIES=quality,PSLIST=1_2,DATA=g250k,SEEDS=1_2_3,MULTINODE=1,RES=results_q_2n"
  sub $GPU gpu_P2_450_2n "$g2n $(wt 04:00:00)" "STUDIES=A+B,PSLIST=2,GRID_FIXED=450,NO_GEN=1,MULTINODE=1,RES=results_fx450_2n"
  sub $GPU gpu_adapt_2n  "$g2n $(wt 04:00:00)" "STUDIES=B,PSLIST=2,NO_GEN=1,MULTINODE=1,RES=results_ad_2n"
  sub $GPU gpu_base_450  "$g1 $(wt 03:00:00)"  "STUDIES=base,PSLIST=1,GRID_FIXED=450,RES=results_fx450"
  sub $GPU micro_1gpu    "$g1 $(wt 01:00:00)"  "STUDIES=micro,PSLIST=1,RES=results"
  sub $GPU micro_v2      "$g2 $(wt 01:00:00)"  "STUDIES=micro,PSLIST=2,RES=results_micro_v2"
  sub $GPU micro_2n_v2   "$g2n $(wt 01:00:00)" "STUDIES=micro,PSLIST=2,MULTINODE=1,RES=results_micro_2n_v2"
  for d in ts10k ts50k ts200k ts; do   # R1 on the GPU, adaptive grid, one GPU (results/real, Fig. R15/R16, Table app-realq)
    sub $GPU gpu_real_adapt_$d "$g1 $(wt 02:00:00)" "STUDIES=real,PSLIST=1,REAL=$d,NO_GEN=1,RES=results"
  done
  for d in ts50k ts200k ts; do   # R1 on two nodes, and blocking against non-blocking grid sum on the same fixed grid (Table realgpu)
    sub $GPU gpu_real_2n_$d "$g2n $(wt 02:00:00)" "STUDIES=real,PSLIST=1_2,REAL=$d,GRID_FIXED=540,NO_GEN=1,MULTINODE=1,RES=results_fx_real_2n"
    sub $GPU gpu_realB1_$d  "$g2 $(wt 02:00:00)"  "STUDIES=realB1,PSLIST=1_2,REAL=$d,REAL_BOXES=540,NO_GEN=1,RES=results_fx_realB1"
  done
  for d in ts10k ts50k ts200k ts; do   # R1 on the GPU: P = 1 and 2, fixed grid of 540 boxes, 1000 iterations
    sub $GPU gpu_real_$d "$g2 $(wt 02:00:00)" "STUDIES=real,PSLIST=1_2,REAL=$d,GRID_FIXED=540,NO_GEN=1,RES=results_fx_real"
  done
}

grp_gpu_dist() {   # Q2-gpufft: distributed FFT on the GPU (implementation/scripts/gpu_dist_fft.sh; run `gpu_dist_fft.sh` header for the variables). MULTI=1 = one rank per node.
  local g="SCRIPT=implementation/scripts/gpu_dist_fft.sh"
  sub $GPU gpu_dist       "$g2 $(wt 02:00:00)"  "$g,RES=results_gpu_dist,CASES=g250k:200_g250k:400_g250k:512_g1m:768,PS=1_2"                     # gate + time per iteration + quality (same node)
  sub $GPU gpu_dist_grid  "$g2 $(wt 02:00:00)"  "$g,RES=results_gpu_dist_grid,GATE=0,QUALITY=0,CASES=g1m:400_g1m:768_g1m:1024_g1m:1280,PS=1_2"     # grid scan, 1M points; also the P=1 column of Table gpustages
  sub $GPU gpu_dist_real  "$g2 $(wt 02:00:00)"  "$g,RES=results_gpu_dist_real,GATE=0,QUALITY=0,CASES=ts200k:540,PS=1_2"                           # real data (Tabula Sapiens, 200k cells)
  sub $GPU gpu_dist_2n    "$g2n $(wt 02:00:00)" "$g,RES=results_gpu_dist_2n_v3,MULTI=1,CASES=g250k:400_g1m:768_g1m:1280,PS=2,QUALITY=0"            # two nodes, one GPU each
  sub $GPU gpu_dist_q2n   "$g2n $(wt 02:00:00)" "$g,RES=results_gpu_dist_q2n,MULTI=1,CASES=g250k:400,PS=2,REPS=1,ITERS=20,QUALITY=1,QCASE=g250k:400,QITERS=1000,QSEEDS=1_2"   # quality across two nodes
  sub $GPU gpu_dist_big   "$g2 $(wt 02:00:00)"  "$g,RES=results_gpu_dist_big,GATE=0,QUALITY=0,CASES=g1m:2048_g1m:2560,PS=1_2,ITERS=30,REPS=2"     # largest grids
  sub $GPU gpu_dist_cap   "$g2 $(wt 01:00:00)"  "$g,RES=results_gpu_dist_cap,GATE=0,QUALITY=0,CASES=g1m:2816,PS=1_2,ITERS=20,REPS=1"
  sub $GPU gpu_dist_cap2  "$g2 $(wt 01:00:00)"  "$g,RES=results_gpu_dist_cap2,GATE=0,QUALITY=0,CASES=g1m:2944,PS=1_2,ITERS=10,REPS=1"
  sub $GPU gpu_dist_real_dev "$g2 $(wt 02:00:00)" "$g,RES=results_gpu_dist_real_dev,GATE=0,QUALITY=0,CASES=ts200k:540,PS=1_2,TRANSPORTS=host_device"   # repeat of the real-data run; the `device` runs fail (Open MPI is not CUDA-aware)
  sub $GPU gpu_dist_smoke "$g2 $(wt 00:30:00)"  "$g,RES=results_gpu_dist_smoke,CASES=g250k:200,PS=1_2,REPS=1,ITERS=20,QUALITY=0"                    # first gate run (smoke test)
}

grp_diagnostics() {   # Section 5.3: are repeated runs bitwise identical?  (reads RES/repro.txt)
  sub $CPU repro_cpu "$n1 $(wt 00:30:00)" "SCRIPT=implementation/scripts/repro_check.sh,TARGET=cpu,P=4,RES=results_repro_cpu"
  sub $GPU repro_gpu "$g2 $(wt 00:30:00)" "SCRIPT=implementation/scripts/repro_check.sh,TARGET=gpu,P=1_2,RES=results_repro_gpu"
}

grp_official() {   # O1 and K1 (need FIt-SNE-master/bin/fast_tsne from `prepare.sh official-build`)
  sub $CPU off_1core  "select=1:ncpus=1:mem=16gb place=excl $(wt 06:00:00)" "SCRIPT=implementation/scripts/cpu_studies.sh,CMD=official,DATA=ts50k_g50k,CONFIGS=matched,SEEDS=1_2_3,THREADS=1,MPI_PS=none,ITERS=1000,RES=results_official2"
  sub $CPU off_72core "select=1:ncpus=72:mpiprocs=72:mem=200gb place=pack:excl $(wt 06:00:00)" "SCRIPT=implementation/scripts/cpu_studies.sh,CMD=official,DATA=ts50k_g50k,CONFIGS=matched,SEEDS=1_2_3,THREADS=8_36_72,MPI_PS=8_36_72,OURS_SERIAL=0,ITERS=1000,RES=results_official2"
  sub $CPU klgap      "$core $(wt 04:00:00)" "SCRIPT=implementation/scripts/cpu_studies.sh,CMD=klgap,DATA=g10000_ts10k,SEEDS=1_2_3,RES=results_klgap"
}

if [ $# -eq 0 ]; then sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//' | head -16; exit 0; fi
for g in "$@"; do
  case $g in
    data) grp_data;; serial) grp_serial;; validation) grp_validation;; cpu-strong) grp_cpu_strong;; cpu-comm) grp_cpu_comm;;
    cpu-weak) grp_cpu_weak;; cpu-real) grp_cpu_real;; gpu) grp_gpu;; gpu-dist) grp_gpu_dist;; official) grp_official;; diagnostics) grp_diagnostics;;
    all) grp_data; grp_serial; grp_validation; grp_cpu_strong; grp_cpu_comm; grp_cpu_weak; grp_cpu_real; grp_gpu; grp_gpu_dist; grp_official; grp_diagnostics;;
    *) echo "unknown group $g"; exit 2;;
  esac
done
