#!/usr/bin/env bash
# run_experiments.sh -- driver of every MPI experiment (pure-MPI CPU program tsne_mpi_cpu and MPI+CUDA program tsne_gpu).
#
#   implementation/scripts/run_experiments.sh STUDY [STUDY ...]       (normally started by implementation/jobs/vanda_cpu.pbs or implementation/jobs/vanda_gpu.pbs)
#
# STUDY            report experiment / what it does                                                   backend
#   gate           V3/V4 correctness gates: every communication variant == serial gradient (1e-10)    cpu, gpu
#   base           the P=1 baselines (shared by A, B, D; run once so that no two jobs write one dir)   cpu, gpu
#   micro          platform micro-benchmarks: ping-pong (intra/inter node), Allreduce, copies, FLOPs     cpu, gpu
#   pilot          short pilots to estimate the time of the long runs                                  gpu
#   C              C1: single-GPU write-conflict study (probe kernels, interpolation order, clustering) gpu
#   A              A1-A4: coordinate exchange {allgather, ghost} x {blocking, nonblocking} + ordering   cpu, gpu
#   B              B1/B2: grid-sum variants (strong scaling) + weak scaling                             cpu, gpu
#   Bgs / W        the two halves of B: grid-sum variants / weak scaling only (W1: WEAK_N0_BOXES=<n0>)  cpu, gpu
#   D              replicated vs distributed FFT, strong scaling                                        cpu
#   E              C1: PAIRED, INTERLEAVED strong scaling (replicated vs distributed FFT, rounds)       cpu
#   F              C4: coordinate-exchange variants under the distributed FFT                           cpu
#   Q              grid-size quantisation (--grid-quant) vs the default grid; FFT-plan amortisation     gpu
#   float          float vs double on one GPU (needs the float build)                                   gpu
#   real / realB1  R1: real data REAL=<name> on 1 and MAXP GPUs / B1 vs B2 on one fixed grid           gpu
#   realcpu        R1: real data on the CPU, fixed REAL_BOXES [540] boxes, distributed FFT              cpu
#   quality        Q1: quality metrics for several seeds and rank counts                                cpu, gpu
#   serial         serial single-core baseline on SERIAL_NS (results in ${RES}_serial/)                 tsne_cpu
#   place          C3: same P on a different number of nodes (placement)                                cpu
#   ablation       X1/X2: point ordering and grid-sum ablations                                         cpu
#   samegrid       G3: GPU vs CPU on the same fixed grid; float vs double quality and time              gpu
#   hpcx_probe     diagnostic of the CUDA-aware ping-pong (UCX settings)                                gpu
#   all            gate micro pilot C A B
#
# Backend: BIN=build/tsne_mpi_cpu (or BACKEND=cpu) switches to the CPU program: no study C, no float/transport/probe options, no `--progress sync`
# variant; defaults change to PS="1 2 4 8 16", N_STRONG=250000, NS="100000 250000", N_PER_GPU (= points per rank) 10000; `micro` uses
# build/microbench_cpu; `gate` is run for --fft replicated and distributed.
#
# Environment (defaults in brackets):
#   BUILD     build directory                      [build]       BIN  the program [$BUILD/tsne_gpu, or $BUILD/tsne_mpi_cpu for BACKEND=cpu]
#   BACKEND   gpu | cpu                            [cpu if BIN contains mpi_cpu, else gpu]
#   LAUNCH    MPI launch prefix; the rank count is appended   [mpirun -np]   (implementation/jobs/vanda_*.pbs set it, with binding and node placement)
#   PS        rank counts for scaling studies      [1 2 4]   (only counts you really have GPUs / cores for)
#   ITERS     iterations of the long runs          [500]     (keep >= 300 so early exaggeration is included)
#   REPS      repetitions of each configuration    [3]
#   NS        point counts for study A             [250000 1000000]        N_STRONG  N of the strong-scaling runs   [1000000]
#   N_C       N of the single-GPU study C          [1000000]               N_PER_GPU points per rank in weak scaling [250000]
#   RES       results directory                    [results]               TRANSPORT host|device [host]
#   SEED      seed of all timing runs              [42]   (repetitions use the SAME seed so that the spread is timing noise only)
#   QS        grid-quant ratios compared with the default (0) in study Q       [1.15 1.3]
#   Q_EVAL    1: run `tsne_tools eval` on repetition 1 of every Q run [1]
#   GRID_FIXED fixed grid for all runs without their own --grid-mode: n boxes/dim or "auto" (400 up to 250k points, else 800); use a separate RES  []
#   RE        --report-every of a run (final KL needs RE=ITERS-1; study Q sets it)  [0 = no KL inside the timed loop]
#   ROUNDS    study E / place / ablation: rounds [3];  EITERS iterations of each measured E run [150]; EBOXES fixed grid boxes of study E (use a separate RES!)
#   WEAK_VARIANTS WEAK_N0_BOXES FIXED_BOXES WEAK_ITERS WEAK_REP_REPS (weak scaling, see weak_scaling below), E_REP_MAXP (study E), REAL REAL_BOXES REAL_ITERS,
#   GATE_PS GATE_QUICK GATE_N GATE_TRANSPORTS (gate), NO_GEN=1 (never generate a missing data set), DRY=1 (print the commands instead of running them)
# Every run goes to $RES/<study>/<label>_P<p>_<data>_r<rep>/ and is skipped if its summary.json already exists (an interrupted campaign can simply
# be restarted); a lock directory stops two jobs from running the same configuration (remove stale locks with
#   find results* -name '*.lock' -type d | xargs -r rmdir ).
set -u
JOB_TAG=${PBS_JOBID:-local}
# A failed run prints a message, is recorded in $RES/FAILED_RUNS.txt and the study continues; the script exits with status 1 at the end if any run
# of this job failed, so that an incomplete result set is visible in the job's exit status.
fail_note() { echo "$*"; mkdir -p "${RES:-.}" 2>/dev/null; echo "$JOB_TAG $*" >> "${RES:-.}/FAILED_RUNS.txt"; }
cd "$(dirname "$0")/../.."
BUILD=${BUILD:-build}
TOOLS=$BUILD/tsne_tools; CPU=$BUILD/tsne_cpu
BIN=${BIN:-$BUILD/tsne_gpu}
case "$BIN" in *mpi_cpu*) BACKEND=${BACKEND:-cpu};; esac
BACKEND=${BACKEND:-gpu}
LAUNCH=${LAUNCH:-mpirun -np}
if [ "$BACKEND" = cpu ]; then
  PS=${PS:-"1 2 4 8 16"}; NS=${NS:-"100000 250000"}; N_STRONG=${N_STRONG:-250000}; N_PER_GPU=${N_PER_GPU:-10000}
else
  PS=${PS:-"1 2 4"}; NS=${NS:-"250000 1000000"}; N_STRONG=${N_STRONG:-1000000}; N_PER_GPU=${N_PER_GPU:-250000}
fi
ITERS=${ITERS:-500}
REPS=${REPS:-3}
N_C=${N_C:-1000000}
SERIAL_NS=${SERIAL_NS:-"100000 250000"}
RES=${RES:-results}
TRANSPORT=${TRANSPORT:-host}
SEED=${SEED:-42}
MAXP=$(echo $PS | tr ' ' '\n' | sort -n | tail -1)
mkdir -p "$RES" data
jv() { tr -d ' \n' < "$1" | sed -n "s/.*\"$2\":\([-0-9.eE+]*\).*/\1/p"; }   # value of a number field of a flat summary.json

run() {  # run STUDY LABEL P DATASET [options...]
  local study=$1 label=$2 p=$3 data=$4; shift 4
  local n; n=$(basename "$data" .ds.bin)
  for r in $(seq 1 "$REPS"); do
    local out="$RES/$study/${label}_P${p}_${n}_r${r}"
    if [ -f "$out/summary.json" ]; then echo "skip   $out"; continue; fi
    # several jobs may share a configuration (e.g. the P=1 baseline "base" is created by studies A, B and D):
    # an atomic lock directory makes sure only ONE job runs it. A stale lock (job killed) must be removed by hand:
    #   find results* -name '*.lock' -type d | xargs -r rmdir
    if [ "${DRY:-0}" != 1 ]; then
      mkdir -p "$(dirname "$out")"
      if ! mkdir "$out.lock" 2>/dev/null; then echo "busy   $out (another job is running it)"; continue; fi
    fi
    local topt="--transport $TRANSPORT"; [ "$BACKEND" = cpu ] && topt=""
    # GRID_FIXED=<n>|auto: FIXED grid (n boxes per dimension; auto = 400 up to 250k points, 800 above) for every run that does not choose its own
    # --grid-mode: identical work for every P and no FFT-plan rebuilds (the adaptive grid follows the embedding extent, which differs between P).
    local gopt=""
    if [ -n "${GRID_FIXED:-}" ]; then case " $* " in *" --grid-mode "*) ;; *)
      local nb=$GRID_FIXED; [ "$nb" = auto ] && case "$n" in g100k|g250k|gate|small|g120000|g10000|g20000|g40000|g80000) nb=400;; *) nb=800;; esac
      gopt="--grid-mode fixed --fixed-boxes $nb";; esac; fi
    local cmd="$LAUNCH $p $BIN --data data/$data.ds.bin --out $out --iters $ITERS $topt --seed $SEED --report-every ${RE:-0} $gopt $*"
    echo "run    $cmd"
    if [ "${DRY:-0}" != 1 ]; then
      mkdir -p "$out"
      # node load before/after: evidence for timing noise on shared nodes ; harmless elsewhere
      { echo "before: $(cat /proc/loadavg 2>/dev/null)"; } > "$out/loadavg.txt"
      $cmd >"$out/stdout.log" 2>&1 || fail_note "FAILED $out (see stdout.log)"
      { echo "after:  $(cat /proc/loadavg 2>/dev/null)"; } >> "$out/loadavg.txt"
      rmdir "$out.lock" 2>/dev/null || true
    fi
  done
}
data() {  # NO_GEN=1: never generate a missing dataset (use for jobs that must not spend GPU time on data generation)
  if [ "${NO_GEN:-0}" = 1 ] && [ "${DRY:-0}" != 1 ] && [ ! -f "data/$1.ds.bin" ]; then echo "FATAL: data/$1.ds.bin missing and NO_GEN=1"; exit 5; fi
  if [ "${DRY:-0}" != 1 ]; then implementation/scripts/prepare.sh synthetic "$@"; else echo "data   $*"; fi; }
nlabel() { case $1 in 100000) echo g100k;; 250000) echo g250k;; 500000) echo g500k;; 1000000) echo g1m;; 2000000) echo g2m;; 4000000) echo g4m;; *) echo "g$1";; esac; }

study_base() {  # P=1 baselines for every N of NS plus N_STRONG; the other studies skip them when summary.json exists
  local ns="$NS"; case " $ns " in *" $N_STRONG "*) ;; *) ns="$ns $N_STRONG";; esac
  for n in $ns; do
    local d; d=$(nlabel "$n"); data "$d" "$n" 50 20 6 90
    run base base 1 "$d" --exchange ghost
  done
}

study_gate() {
  # GATE_PS="2 8 64 512": rank counts to test (default: every P of PS above 1); GATE_QUICK=1: representative subset of the communication variants
  # (use it for large P); GATE_N: size of the gate data set (default 20000; use >= 2*maxP*30 so that every rank owns points)
  local gn=${GATE_N:-20000}; local gname=gate; [ "$gn" != 20000 ] && gname=gate$gn
  data "$gname" "$gn" 30 15 5 60
  mkdir -p "$RES/gate"
  [ -f "$RES/gate/cpu_run_$gname/embedding.bin" ] || "$CPU" --data data/$gname.ds.bin --perplexity 20 --iters 300 --out "$RES/gate/cpu_run_$gname" >/dev/null || exit 1
  local variants="replicated"; [ "$BACKEND" = cpu ] && variants="replicated distributed"
  local pl; pl=$(echo ${GATE_PS:-$PS} | tr ' ' '\n' | awk '$1>1' | tr '\n' ' ')
  for fftv in $variants; do
    local extra="--perplexity 20"; [ "$BACKEND" = cpu ] && extra="$extra --fft $fftv"
    # G1 (single rank = serial) and G2 (all variants on every available P); tolerance frozen at 1e-10
    QUICK=${GATE_QUICK:-0} TSNE_GPU=$BIN LAUNCH="$LAUNCH" WORK="$RES/gate/parallel_${fftv}_$gname" TRANSPORTS="${GATE_TRANSPORTS:-host}" EXTRA="$extra" \
      check_parallel data/$gname.ds.bin "$RES/gate/cpu_run_$gname/embedding.bin" "$pl" 1e-10 \
      || { echo "GATE FAILED ($fftv): do not run performance experiments"; exit 1; }
  done
}

study_micro() {
  local out="$RES/micro"; mkdir -p "$out"
  [ "${DRY:-0}" = 1 ] && { echo "micro  (pingpong, allreduce, copy, flops, overlap)"; return; }
  if [ "$BACKEND" = cpu ]; then
    MB=${MB:-$BUILD/microbench_cpu}
    $LAUNCH 2 $MB --test pingpong --peer 1 > "$out/pingpong_peer1.csv"
    [ -n "${PEER_INTER:-}" ] && $LAUNCH $((PEER_INTER + 1)) $MB --test pingpong --peer "$PEER_INTER" > "$out/pingpong_inter.csv"
    for p in $PS; do
      [ "$p" -gt 1 ] || continue
      $LAUNCH "$p" $MB --test allreduce > "$out/allreduce_P$p.csv"
      for kb in 64 1024 8192; do
        $LAUNCH "$p" $MB --test overlap_cpu --bytes $((kb * 1024)) --kernel-ms 5 > "$out/overlap_cpu_P${p}_${kb}KB.csv"
        [ $((p % 2)) -eq 0 ] && $LAUNCH "$p" $MB --test overlap_cpu --p2p --bytes $((kb * 1024)) --kernel-ms 5 > "$out/overlap_cpu_p2p_P${p}_${kb}KB.csv"
      done
    done
    lscpu > "$out/lscpu.txt" 2>&1 || true
    return
  fi
  MB=${MB:-$BUILD/microbench}   # every micro test is wrapped in `timeout` (MICRO_TIMEOUT s): the device-pointer ping-pong can hang on a non-CUDA-aware MPI
  timeout ${MICRO_TIMEOUT:-180} $LAUNCH 1 $MB --test flops > "$out/flops.csv"
  timeout ${MICRO_TIMEOUT:-180} $LAUNCH 1 $MB --test copy > "$out/copy.csv"
  # ping-pong: --peer 1 is on the same node if ranks are placed node-first. For a different node
  # use PEER_INTER=<rank on another node> (e.g. the number of GPUs per node).
  timeout ${MICRO_TIMEOUT:-180} $LAUNCH 2 $MB --test pingpong --peer 1 > "$out/pingpong_peer1.csv"
  [ -n "${PEER_INTER:-}" ] && timeout ${MICRO_TIMEOUT:-180} $LAUNCH $((PEER_INTER + 1)) $MB --test pingpong --peer "$PEER_INTER" > "$out/pingpong_inter.csv"
  timeout ${MICRO_TIMEOUT:-180} $LAUNCH 2 $MB --test pingpong --peer 1 --device-ptr > "$out/pingpong_device.csv" 2>&1 || echo "device-pointer ping-pong failed (MPI not CUDA-aware?)"
  for p in $PS; do
    [ "$p" -gt 1 ] && timeout ${MICRO_TIMEOUT:-180} $LAUNCH "$p" $MB --test allreduce > "$out/allreduce_P$p.csv"
    [ "$p" -gt 1 ] && for kb in 64 1024 8192 32768; do
      timeout ${MICRO_TIMEOUT:-180} $LAUNCH "$p" $MB --test overlap --bytes $((kb * 1024)) --kernel-ms 5 > "$out/overlap_P${p}_${kb}KB.csv"
      [ $((p % 2)) -eq 0 ] && timeout ${MICRO_TIMEOUT:-180} $LAUNCH "$p" $MB --test overlap_p2p --bytes $((kb * 1024)) --kernel-ms 5 > "$out/overlap_p2p_P${p}_${kb}KB.csv"
    done
  done
  ompi_info --parsable 2>/dev/null | grep -i cuda > "$out/mpi_cuda_support.txt" || true
  nvidia-smi -L > "$out/gpus.txt" 2>&1 || true
  nvidia-smi topo -m > "$out/topology.txt" 2>&1 || true
}

study_pilot() {
  local d; d=$(nlabel "$N_STRONG"); data "$d" "$N_STRONG" 50 20 6 90
  local save=$REPS; REPS=1
  for p in $PS; do ITERS=60 run pilot "pilot" "$p" "$d" --exchange ghost --stage-timing 1; done
  REPS=$save
  echo "Pilot done: see $RES/pilot/*/summary.json (seconds_per_iter_steady) to compute GPU hours = runs x ITERS x s/iter x P / 3600."
}

study_C() {
  [ "$BACKEND" = cpu ] && { echo "study C (GPU write conflicts) does not apply to the CPU backend"; return; }
  local d; d=$(nlabel "$N_C")
  data "$d" "$N_C" 50 20 6 90
  data "${d}_near" "$N_C" 50 20 2 90
  data "${d}_far" "$N_C" 50 20 12 90
  # (1) per-iteration scatter time of C1 (atomics) vs probes C2 (plain) and C2' (conflict-free)
  run C base 1 "$d" --probe 1 --order-p 3 --block 256
  # (2) interpolation order => number of writes per point (p^2 * 4)
  for p in 2 4 5; do run C "order$p" 1 "$d" --probe 1 --order-p $p --block 256; done
  # (3) clustering of the data
  run C near 1 "${d}_near" --probe 1 --order-p 3 --block 256
  run C far 1 "${d}_far" --probe 1 --order-p 3 --block 256
  # (4) thread-block size (side check)
  for b in 64 128 512; do run C "block$b" 1 "$d" --probe 1 --block $b; done
}

study_A() {
  for n in $NS; do
    local d; d=$(nlabel "$n"); data "$d" "$n" 50 20 6 90
    for p in $PS; do
      # P=1 has no communication: one baseline per N, shared by all variants
      if [ "$p" -eq 1 ]; then run base base 1 "$d" --exchange ghost; continue; fi
      run A A1_allgather_block "$p" "$d" --exchange allgather --comm blocking
      run A A2_allgather_nonblock "$p" "$d" --exchange allgather --comm nonblocking
      run A A3_ghost_block "$p" "$d" --exchange ghost --comm blocking
      run A A4_ghost_nonblock "$p" "$d" --exchange ghost --comm nonblocking
      [ "$BACKEND" = cpu ] && run A A4poll_ghost_nonblock "$p" "$d" --exchange ghost --comm nonblocking --progress poll
    done
  done
  # ordering control: ghost count with PC1 order vs random order (largest N, largest P)
  local dl; dl=$(nlabel "$N_STRONG")
  [ "$MAXP" -gt 1 ] && { run A A3_order_pc1 "$MAXP" "$dl" --exchange ghost --order pc1; run A A3_order_random "$MAXP" "$dl" --exchange ghost --order random; }
}

study_B() { study_Bgs; weak_scaling; }

study_Bgs() {  # grid-sum variants (blocking / non-blocking / polling / + non-blocking exchange), strong scaling; use GRID_FIXED=<n> on Vanda
  local d; d=$(nlabel "$N_STRONG"); data "$d" "$N_STRONG" 50 20 6 90
  for p in $PS; do
    if [ "$p" -eq 1 ]; then run base base 1 "$d" --exchange ghost; continue; fi
    # B1 is the same configuration as A3 (blocking grid sum + blocking ghost exchange)
    run B B1_gridblock "$p" "$d" --exchange ghost --comm blocking --grid-comm blocking
    run B B2_gridnonblock "$p" "$d" --exchange ghost --comm blocking --grid-comm nonblocking --progress wait
    [ "$BACKEND" = cpu ] || run B B2sync_gridnonblock "$p" "$d" --exchange ghost --comm blocking --grid-comm nonblocking --progress sync
    run B B2poll_gridnonblock "$p" "$d" --exchange ghost --comm blocking --grid-comm nonblocking --progress poll
    run B A4B2_both "$p" "$d" --exchange ghost --comm nonblocking --grid-comm nonblocking --progress wait
  done
}

weak_scaling() {   # weak scaling: N_PER_GPU points per GPU (= per rank on the CPU), adaptive grid and fixed grid (controls); also study W
  # WEAK_VARIANTS (comma list, default = all):  sqrtgrid_fftdist sqrtgrid_fftrep fixed_B1 adaptive_B1 adaptive_B2   (sqrtgrid_* are CPU only)
  #   sqrtgrid_*: grid grows as WEAK_N0_BOXES*sqrt(P) so that grid nodes ~ N (the meaningful weak scaling); fixed_B1: FIXED_BOXES [128] boxes (flat by construction)
  # WEAK_ITERS: iterations of the weak runs (default ITERS);  WEAK_REP_REPS: repetitions of the variants with the replicated FFT (default REPS; they are slow at large P)
  local wv=",${WEAK_VARIANTS:-sqrtgrid_fftdist,sqrtgrid_fftrep,fixed_B1,adaptive_B1,adaptive_B2},"
  local wit=${WEAK_ITERS:-$ITERS}; local wrr=${WEAK_REP_REPS:-$REPS}
  has_wv() { case "$wv" in *",$1,"*) return 0;; esac; return 1; }
  for p in $PS; do
    local n=$((N_PER_GPU * p)); local dw; dw=$(nlabel "$n"); data "$dw" "$n" 50 20 6 90
    if [ "$p" -eq 1 ]; then
      has_wv adaptive_B1 || has_wv adaptive_B2 && ITERS=$wit run base base 1 "$dw" --exchange ghost   # same configuration as the A / B baselines (shared)
      has_wv fixed_B1 && ITERS=$wit run Bweak fixed 1 "$dw" --exchange ghost --grid-mode fixed --fixed-boxes "${FIXED_BOXES:-128}"
      # WEAK_N0_BOXES=<n0> (CPU only): weak scaling in which the GRID grows with the points (boxes per dimension = n0*sqrt(P), so grid nodes ~ N), i.e. the FFT
      # work per rank stays ~constant under the distributed FFT; the fixed 128-box grid makes the weak-scaling curve flat by construction.
      [ -n "${WEAK_N0_BOXES:-}" ] && ITERS=$wit run Bweak sqrtgrid 1 "$dw" --exchange ghost --grid-mode fixed --fixed-boxes "$WEAK_N0_BOXES"
      continue
    fi
    if [ -n "${WEAK_N0_BOXES:-}" ] && [ "$BACKEND" = cpu ]; then
      local nbx; nbx=$(awk -v n0="$WEAK_N0_BOXES" -v p="$p" 'BEGIN{printf "%d", int(n0*sqrt(p)+0.5)}')
      has_wv sqrtgrid_fftdist && ITERS=$wit run Bweak sqrtgrid_fftdist "$p" "$dw" --exchange ghost --grid-comm blocking --grid-mode fixed --fixed-boxes "$nbx" --fft distributed
      has_wv sqrtgrid_fftrep && ITERS=$wit REPS=$wrr run Bweak sqrtgrid_fftrep "$p" "$dw" --exchange ghost --grid-comm blocking --grid-mode fixed --fixed-boxes "$nbx" --fft replicated
    fi
    has_wv adaptive_B1 && ITERS=$wit REPS=$wrr run Bweak adaptive_B1 "$p" "$dw" --exchange ghost --grid-comm blocking
    has_wv adaptive_B2 && ITERS=$wit REPS=$wrr run Bweak adaptive_B2 "$p" "$dw" --exchange ghost --grid-comm nonblocking
    has_wv fixed_B1 && ITERS=$wit REPS=$wrr run Bweak fixed_B1 "$p" "$dw" --exchange ghost --grid-comm blocking --grid-mode fixed --fixed-boxes "${FIXED_BOXES:-128}"
  done
}

study_realcpu() {  # CPU backend, real data: REAL=<ts50k|ts200k|...> (data/<name>.ds.bin), fixed grid REAL_BOXES [540], distributed FFT; P=1 uses the replicated FFT (the only one a single rank has)
  [ "$BACKEND" = cpu ] || { echo "study realcpu exists only for the CPU backend"; return; }
  local d=${REAL:?set REAL=ts50k}; local nb=${REAL_BOXES:-540}
  for p in $PS; do
    if [ "$p" -eq 1 ]; then run realcpu base 1 "$d" --exchange ghost --grid-mode fixed --fixed-boxes "$nb"; continue; fi
    run realcpu fftdist "$p" "$d" --exchange ghost --comm blocking --grid-comm blocking --grid-mode fixed --fixed-boxes "$nb" --fft distributed
  done
}

study_W() { weak_scaling; }   # weak scaling only (CPU or GPU); see WEAK_N0_BOXES

study_D() {  # CPU backend: replicated vs distributed FFT , strong scaling + weak scaling
  [ "$BACKEND" = cpu ] || { echo "study D (distributed FFT) exists only in the CPU program"; return; }
  local d; d=$(nlabel "$N_STRONG"); data "$d" "$N_STRONG" 50 20 6 90
  for p in $PS; do
    if [ "$p" -eq 1 ]; then run base base 1 "$d" --exchange ghost; run D fftdist 1 "$d" --exchange ghost --fft distributed; continue; fi
    run D fftrep "$p" "$d" --exchange ghost --comm blocking --grid-comm blocking --fft replicated
    run D fftdist "$p" "$d" --exchange ghost --comm blocking --grid-comm blocking --fft distributed
    run D fftdist_B2 "$p" "$d" --exchange ghost --comm blocking --grid-comm nonblocking --progress poll --fft distributed
  done
}

study_F() {  # CPU backend: coordinate exchange variants UNDER THE DISTRIBUTED FFT (the regime where the exchange can matter)
  # Why: with the replicated FFT one iteration takes ~1 s and a ~3 ms exchange is invisible (study A). With the FFT divided over the ranks
  # an iteration is ~80 ms at P=12 and the exchange is a few % of it. Use GRID_FIXED=auto (identical work, no plan rebuilds) and a separate RES.
  [ "$BACKEND" = cpu ] || { echo "study F exists only in the CPU program"; return; }
  local d; d=$(nlabel "$N_STRONG"); data "$d" "$N_STRONG" 50 20 6 90
  for p in $PS; do
    [ "$p" -gt 1 ] || continue
    run F F1_allgather_block "$p" "$d" --exchange allgather --comm blocking --grid-comm blocking --fft distributed
    run F F2_allgather_nonblock "$p" "$d" --exchange allgather --comm nonblocking --grid-comm blocking --fft distributed
    run F F3_ghost_block "$p" "$d" --exchange ghost --comm blocking --grid-comm blocking --fft distributed
    run F F4_ghost_nonblock "$p" "$d" --exchange ghost --comm nonblocking --grid-comm blocking --fft distributed
    run F F4poll_ghost_nonblock "$p" "$d" --exchange ghost --comm nonblocking --grid-comm blocking --progress poll --fft distributed
  done
}

study_E() {  # CPU backend: PAIRED, INTERLEAVED scaling control for shared nodes (replicated vs distributed FFT)
  # Why: on shared nodes identical work ran 2-4x slower at another time/node, so speed-ups taken from different jobs are not
  # comparable. Here ONE job (one node) runs, in every round, all (variant, P) combinations back to back; each measured run is
  # preceded by a short fixed-grid P=1 CALIBRATION run (machine-speed probe). implementation/analysis/01_summary_tables.ipynb reports medians over rounds
  # and the calibration-normalised times. Short runs (EITERS, default 150) so that several rounds fit into one job.
  [ "$BACKEND" = cpu ] || { echo "study E exists only for the CPU backend"; return; }
  local d; d=$(nlabel "${N_STRONG}"); data "$d" "$N_STRONG" 50 20 6 90
  local rounds=${ROUNDS:-3} eit=${EITERS:-150} k p
  # EBOXES=<n>: FIXED grid of n boxes per dim (--grid-mode fixed): identical work for every P and no plan rebuilds. The adaptive grid follows the
  # embedding extent, and that trajectory differs between P (rounding differences amplified by the dynamics), so adaptive times are not comparable across P.
  local gopt=""; [ -n "${EBOXES:-}" ] && gopt="--grid-mode fixed --fixed-boxes $EBOXES"
  for k in $(seq 1 "$rounds"); do
    for p in $PS; do
      local v
      for v in fftrep fftdist; do
        [ "$p" -eq 1 ] && [ "$v" = fftdist ] && continue     # P=1 has no distributed variant: fftrep P=1 is the common baseline
        # E_REP_MAXP=<p>: skip the replicated FFT above p ranks (it cannot scale, and one iteration costs ~1 s): large-P runs then measure the distributed FFT only
        [ -n "${E_REP_MAXP:-}" ] && [ "$p" -gt "$E_REP_MAXP" ] && [ "$v" = fftrep ] && continue
        ITERS=30 REPS=1 run E "cal_rd${k}_${v}_P${p}" 1 "$d" --exchange ghost --grid-mode fixed --fixed-boxes 128
        if [ "$p" -eq 1 ]; then ITERS=$eit REPS=1 run E "${v}_rd${k}" 1 "$d" --exchange ghost $gopt
        else ITERS=$eit REPS=1 run E "${v}_rd${k}" "$p" "$d" --exchange ghost --comm blocking --grid-comm blocking $gopt --fft "$([ "$v" = fftdist ] && echo distributed || echo replicated)"
        fi
      done
    done
  done
}

study_serial() {  # serial single-core baseline for the speed-up denominators (run it on an otherwise idle core/node)
  local out_root="${RES}_serial"
  for n in $SERIAL_NS; do
    local d; d=$(nlabel "$n"); data "$d" "$n" 50 20 6 90
    for r in $(seq 1 "$REPS"); do
      local out="$out_root/${d}_r${r}"
      if [ -f "$out/summary.json" ]; then echo "skip   $out"; continue; fi
      local cmd=""$CPU" --data data/$d.ds.bin --method fast --iters $ITERS --seed $SEED --report-every 0 --out $out"
      echo "run    $cmd"
      if [ "${DRY:-0}" != 1 ]; then mkdir -p "$out"; $cmd >"$out/stdout.log" 2>&1 || fail_note "FAILED $out"; fi
    done
  done
}

# study_quality -- Q1: does the embedding quality depend on the number of ranks more than on the seed?  (report Section 4.1, quality against P)
# For every (P, seed) in PS x SEEDS runs the program (ITERS iterations) and scores the embedding with `tsne_tools eval` (trustworthiness, kNN
# recall, label purity) plus the final KL.  Writes $RES/quality/quality.csv and prints mean +- std per P: a difference between P values is only
# meaningful if it exceeds the seed-to-seed spread.  Variables: DATA (data/<DATA>.ds.bin and .feat.bin; default g250k), SEEDS, SAMPLE, EXTRA
# (extra program options; implementation/jobs/vanda_cpu.pbs turns QGRID / QFFT into EXTRA="--grid-mode fixed --fixed-boxes $QGRID --fft $QFFT").
study_quality() (
SEEDS=${SEEDS:-"1 2 3"}
DATA=${DATA:-g250k}
SEEDS=${SEEDS:-"1 2 3"}; SAMPLE=${SAMPLE:-2000}
OUT=$RES/quality; mkdir -p "$OUT"
CSV=$OUT/quality.csv
[ -f "$CSV" ] || echo "P,seed,trustworthiness,knn_recall,label_purity,final_kl" > "$CSV"
for p in $PS; do
  for sd in $SEEDS; do
    d=$OUT/${DATA}_P${p}_s${sd}
    if grep -q "^$p,$sd," "$CSV"; then echo "skip P=$p seed=$sd"; continue; fi
    $LAUNCH "$p" "$BIN" --data "data/$DATA.ds.bin" --out "$d" --iters "$ITERS" --seed "$sd" --report-every 0 \
        --comm nonblocking --grid-comm nonblocking ${EXTRA:-} > "$d.log" 2>&1 || { fail_note "FAILED P=$p seed=$sd"; continue; }
    "$TOOLS" eval --feat "data/$DATA.feat.bin" --data "data/$DATA.ds.bin" --emb "$d/embedding.bin" --sample "$SAMPLE" --json "$d/quality.json" > /dev/null
    jv() { tr -d ' \n' < "$1" | sed -n "s/.*\"$2\":\([-0-9.eE+]*\).*/\1/p"; }
    echo "$p,$sd,$(jv "$d/quality.json" trustworthiness),$(jv "$d/quality.json" knn_recall),$(jv "$d/quality.json" label_purity),$(jv "$d/summary.json" final_kl)" >> "$CSV"
  done
done
echo; echo "per P: mean +- std over seeds"
awk -F, 'NR>1 {n[$1]++; for(c=3;c<=6;c++){s[$1,c]+=$c; q[$1,c]+=$c*$c}}
  END {split("trustworthiness knn_recall label_purity final_kl",nm," ");
       for(p in n){line="P=" p " (n=" n[p] "): "; for(c=3;c<=6;c++){m=s[p,c]/n[p]; v=(n[p]>1)?sqrt((q[p,c]-n[p]*m*m)/(n[p]-1)):0; line=line sprintf("%s=%.4f+-%.4f  ",nm[c-2],m,v)}; print line}}' "$CSV" | sort
)


study_Q() {  # plan amortisation (GPU only). q0 = default grid; every variant also records the final KL (KL is outside the timed loop)
  [ "$BACKEND" = cpu ] && { echo "study Q (grid-quant) exists only for the GPU program"; return; }
  local qs="${QS:-1.15 1.3}" qns="${NS:-250000 1000000}"
  for n in $qns; do
    local d; d=$(nlabel "$n"); data "$d" "$n" 50 20 6 90
    for p in $PS; do
      local opts="--exchange ghost"; [ "$p" -gt 1 ] && opts="--exchange ghost --comm blocking --grid-comm blocking"   # B1 configuration
      RE=$((ITERS - 1)) run Q q0 "$p" "$d" $opts
      for q in $qs; do RE=$((ITERS - 1)) run Q "q$q" "$p" "$d" $opts --grid-quant "$q"; done
    done
    if [ "${Q_EVAL:-1}" = 1 ] && [ "${DRY:-0}" != 1 ] && [ -x "$TOOLS" ] && [ -f "data/$d.feat.bin" ]; then
      for o in "$RES"/Q/*_P*_"${d}"_r1; do
        [ -f "$o/embedding.bin" ] && [ ! -f "$o/quality.json" ] && \
          "$TOOLS" eval --feat "data/$d.feat.bin" --data "data/$d.ds.bin" --emb "$o/embedding.bin" --sample "${SAMPLE:-2000}" --json "$o/quality.json" >/dev/null 2>&1
      done
    fi
  done
}

study_float() {
  local d; d=$(nlabel 250000); data "$d" 250000 50 20 6 90
  run float double 1 "$d"
  BIN=${BIN_FLOAT:-${BIN}_float} run float float 1 "$d"
}

study_real() {
  local d=${REAL:?set REAL=<name of data/<name>.ds.bin>}
  for p in 1 "$MAXP"; do
    run real "real" "$p" "$d" --exchange ghost --comm nonblocking --grid-comm nonblocking --iters 1000
  done
}

study_realB1() {  # GPU, real data REAL=<name>: blocking (B1) vs non-blocking (B2) grid sum on the SAME fixed grid REAL_BOXES [540]; P=1 and P=MAXP (the earlier real-data runs used the adaptive grid + B2)
  [ "$BACKEND" = cpu ] && { echo "study realB1 is for the GPU program"; return; }
  local d=${REAL:?set REAL=ts50k}; local nb=${REAL_BOXES:-540}; local save=$ITERS; ITERS=${REAL_ITERS:-1000}
  for p in 1 "$MAXP"; do
    if [ "$p" -eq 1 ]; then run realB1 fixed 1 "$d" --exchange ghost --grid-mode fixed --fixed-boxes "$nb"; continue; fi
    run realB1 B1 "$p" "$d" --exchange ghost --comm blocking --grid-comm blocking --grid-mode fixed --fixed-boxes "$nb"
    run realB1 B2 "$p" "$d" --exchange ghost --comm nonblocking --grid-comm nonblocking --grid-mode fixed --fixed-boxes "$nb"
  done
  ITERS=$save
}

# check_parallel DATA.ds.bin COORDS.bin ["PROCS"] [TOL] -- correctness gate (experiments V3/V4 of the report): every communication variant must give the
# same gradient as the single-rank run, and the single-rank run must match the serial CPU program (relative L2 error <= TOL = 1e-10).
# Environment: TSNE_GPU (binary), LAUNCH (MPI launcher + "-np"), WORK (output dir), EXTRA (extra program options, e.g. "--fft distributed"),
# TRANSPORTS ("host", or "host device" with a CUDA-aware MPI), QUICK=1 (representative subset of the variants), FORCE_COMM_P1.
# Exit status 0 only if every variant passes.
check_parallel() (
DATA=${1:?dataset .ds.bin}
COORDS=${2:?coords embedding.bin}
PROCS=${3-"2 4"}   # note: "-" not ":-" so that an empty list ("" = P=1 cases only) stays empty
TOL=${4:-1e-10}
BIN=${TSNE_GPU:-$BIN}
LAUNCH=${LAUNCH:-mpirun -np}
TRANSPORTS=${TRANSPORTS:-host}
WORK=${WORK:-out/check_parallel}
mkdir -p "$WORK"

echo "== serial CPU reference (fast gradient)"
"$CPU" --data "$DATA" --method fast --mode grad --coords "$COORDS" --out "$WORK/ref" ${EXTRA:-} >/dev/null || exit 2

fail=0; total=0
run_case() {  # name nprocs options...
  local name=$1 np=$2; shift 2
  local out="$WORK/$name"
  $LAUNCH "$np" "$BIN" --data "$DATA" --mode grad --coords "$COORDS" --out "$out" "$@" >"$WORK/$name.log" 2>&1
  if [ $? -ne 0 ] || [ ! -f "$out/grad.bin" ]; then echo "FAIL (run)  $name"; fail=$((fail+1)); total=$((total+1)); return; fi
  local res
  res=$("$TOOLS" compare-grad "$WORK/ref/grad.bin" "$out/grad.bin" --tol-grad "$TOL" --tol-attr "$TOL" --tol-rep "$TOL" --tol-z "$TOL" | tail -2)
  total=$((total+1))
  if echo "$res" | grep -q PASS; then echo "ok    $name"; else echo "FAIL  $name"; echo "$res"; fail=$((fail+1)); fi
}

echo "== P=1"
run_case p1 1 ${EXTRA:-}
if [ "${FORCE_COMM_P1:-1}" = "1" ]; then run_case p1_forcecomm 1 --force-comm ${EXTRA:-}; fi

for P in $PROCS; do
  echo "== P=$P"
  for tr in $TRANSPORTS; do
    for ex in ghost allgather; do
      for cm in blocking nonblocking; do
        for gc in blocking nonblocking; do
          if [ "${QUICK:-0}" = "1" ] && [ "$cm" != "$gc" ]; then continue; fi
          run_case "p${P}_${ex}_${cm}_${gc}_${tr}" "$P" --exchange "$ex" --comm "$cm" --grid-comm "$gc" --transport "$tr" ${EXTRA:-}
        done
      done
    done
  done
  run_case "p${P}_ssend" "$P" --ssend ${EXTRA:-}
  run_case "p${P}_poll" "$P" --comm nonblocking --grid-comm nonblocking --progress poll ${EXTRA:-}
  run_case "p${P}_sync" "$P" --comm nonblocking --grid-comm nonblocking --progress sync ${EXTRA:-}
  run_case "p${P}_random_order" "$P" --order random ${EXTRA:-}   # different ordering => same gradient up to rounding
done

echo "== summary: $((total-fail))/$total passed"
[ $fail -eq 0 ]
)


# ===========================================================================================================================================
# Further studies: placement, ablations, same-grid GPU vs CPU, HPC-X diagnostics
# ===========================================================================================================================================
study_place() {  # P1: same rank count P on a different number of nodes (placement counterfactual of the scaling plateau), CPU only
  # LAYOUTS="P:K ..." (K = ranks per node; '_' also separates the items), BOXES=400, ITERS=100, ROUNDS=3, DATA=g250k, RES. Needs LAUNCH_BASE (mpirun with
  # binding, no -np), set by implementation/jobs/vanda_cpu.pbs; ranks are placed with --map-by ppr:K:node. Rounds are interleaved over the layouts.
  # Output: $RES/place.csv  P,K,nodes,round,sec_per_iter_steady,loop_seconds,fft,fft_transpose,pot_allgather,grid_comm,exch_comm
  [ "$BACKEND" = cpu ] || { echo "study place exists only for the CPU program"; return; }
  local layouts=${LAYOUTS:-"64:64 64:32 64:16 64:8 128:64 128:32 128:16 256:64 256:32"}; layouts=${layouts//_/ }
  local boxes=${BOXES:-400} rounds=${ROUNDS:-3} data=${DATA:-g250k} L=${LAUNCH_BASE:-mpirun --bind-to core}
  local nodes_avail; nodes_avail=$(sort -u "${PBS_NODEFILE:-/dev/null}" 2>/dev/null | wc -l); [ "$nodes_avail" -ge 1 ] || nodes_avail=1
  local out="$RES"; mkdir -p "$out"; local csv=$out/place.csv
  [ "${DRY:-0}" = 1 ] && { echo "place  layouts=$layouts"; return; }
  [ -f "$csv" ] || echo "P,K,nodes,round,sec_per_iter_steady,loop_seconds,fft,fft_transpose,pot_allgather,grid_comm,exch_comm" > "$csv"
  local r lay p k nodes d
  for r in $(seq 1 "$rounds"); do
    for lay in $layouts; do
      p=${lay%%:*}; k=${lay##*:}; nodes=$(( (p + k - 1) / k ))
      [ "$nodes" -le "$nodes_avail" ] || { echo "skip $lay (needs $nodes nodes, job has $nodes_avail)"; continue; }
      d=$out/P${p}_K${k}_r$r; [ -f "$d/summary.json" ] && continue
      $L --map-by ppr:$k:node -np "$p" "$BIN" --data data/$data.ds.bin --iters "$ITERS" --seed 42 --report-every 0 \
         --fft distributed --exchange ghost --grid-mode fixed --fixed-boxes "$boxes" --out "$d" > "$d.log" 2>&1 || { fail_note "FAILED $lay r$r"; continue; }
      echo "$p,$k,$nodes,$r,$(jv $d/summary.json seconds_per_iter_steady),$(jv $d/summary.json loop_seconds),$(jv $d/summary.json steady_fft),$(jv $d/summary.json steady_fft_transpose),$(jv $d/summary.json steady_pot_allgather),$(jv $d/summary.json steady_grid_comm),$(jv $d/summary.json steady_exch_comm)" >> "$csv"
      tail -1 "$csv"
    done
  done
}

# study_ablation -- X1/X2: CPU ablations of two design choices.
#   X1  point ordering: PC1-sorted blocks (default) vs random blocks, with the ghost exchange (ordering changes the number of ghost points) and with the
#       allgather (control: ordering must not matter);
#   X2  grid sum: blocking Allreduce-based path (default) vs non-blocking (--grid-comm nonblocking) with the distributed FFT.
# Common: 250k points (g250k), fixed grid 400 boxes, distributed FFT, 100 iterations; rounds interleaved over configurations and rank counts.
# Variables: PS="16 64 128" ROUNDS=3 BOXES=400 ITERS=100 DATA=g250k RES=results_ablation (LAUNCH like "mpirun --bind-to core --map-by core -np").
# Output: $RES/ablation.csv  P,config,round,sec_per_iter_steady,exch_comm,grid_comm,fft,ghost_mean,ghost_fraction,recv_bytes_per_iter
study_ablation() (
ROUNDS=${ROUNDS:-3}; BOXES=${BOXES:-400}; DATA=${DATA:-g250k}
: "${LAUNCH:?LAUNCH not set (use implementation/jobs/vanda_cpu.pbs)}"
mkdir -p "$RES"; CSV=$RES/ablation.csv
[ -f "$CSV" ] || echo "P,config,round,sec_per_iter_steady,exch_comm,grid_comm,fft,ghost_mean,ghost_fraction,recv_bytes_per_iter" > "$CSV"
jv() { tr -d ' \n' < "$1" | sed -n "s/.*\"$2\":\([-0-9.eE+]*\).*/\1/p"; }
declare -A CFG=(
  [base_pc1_ghost]="--order pc1 --exchange ghost --grid-comm blocking"
  [random_ghost]="--order random --exchange ghost --grid-comm blocking"
  [pc1_allgather]="--order pc1 --exchange allgather --grid-comm blocking"
  [random_allgather]="--order random --exchange allgather --grid-comm blocking"
  [gridcomm_nonblocking]="--order pc1 --exchange ghost --grid-comm nonblocking"
)
ORDER_OF=(base_pc1_ghost random_ghost pc1_allgather random_allgather gridcomm_nonblocking)
for r in $(seq 1 "$ROUNDS"); do for p in $PS; do for c in "${ORDER_OF[@]}"; do
  d=$RES/${c}_P${p}_r$r; [ -f "$d/summary.json" ] && continue
  $LAUNCH "$p" "$BIN" --data data/$DATA.ds.bin --iters "$ITERS" --seed 42 --report-every 0 --fft distributed --grid-mode fixed --fixed-boxes "$BOXES" ${CFG[$c]} --out "$d" > "$d.log" 2>&1 || { fail_note "FAILED $c P=$p r=$r"; continue; }
  echo "$p,$c,$r,$(jv $d/summary.json seconds_per_iter_steady),$(jv $d/summary.json steady_exch_comm),$(jv $d/summary.json steady_grid_comm),$(jv $d/summary.json steady_fft),$(jv $d/summary.json ghost_mean),$(jv $d/summary.json ghost_fraction_of_N),$(jv $d/summary.json bytes_exch_recv_per_iter)" >> "$CSV"; tail -1 "$CSV"
done; done; done
echo DONE
)

# study_samegrid -- G3: (1) GPU time on EXACTLY the same fixed grids as the CPU strong-scaling runs (250k: 400/512 boxes, 1M: 768 boxes; 800 = the
# default fixed GPU grid for large N), (2) double vs float on the GPU: time and embedding quality.  One GPU, P=1.  Needs both builds: `make gpu` and `make gpu REAL=float`
# (implementation/jobs/vanda_gpu.pbs builds the float program when the study list contains float or samegrid).
# Variables: CASES="g250k:400_g250k:512_g1m:768_g1m:800" ITERS=200 REPS=3 SAMPLE=1000 QCASES="g250k:400 g1m:768" QSEEDS="1 2 3" QITERS=1000
#            RES=results_gpu_samegrid.  Needs data/g250k.{ds,feat}.bin and data/g1m.{ds,feat}.bin.
# Output: $RES/samegrid.csv  data,boxes,precision,rep,iters,sec_per_iter_steady,sec_per_iter_total (both precisions interleaved inside each rep);
#         $RES/quality.csv   data,boxes,precision,seed,iters,trust,knn_recall,purity,final_kl,sec_per_iter_steady (full QITERS-iteration runs).
# sec_per_iter_steady = median per-iteration time without the first 10 iterations (same definition as the CPU tables).
study_samegrid() (
SAMPLE=${SAMPLE:-1000}
QCASES=${QCASES:-"g250k:400 g1m:768"}; QCASES=${QCASES//_/ }; QSEEDS=${QSEEDS:-"1 2 3"}; QSEEDS=${QSEEDS//_/ }; QITERS=${QITERS:-1000}
CASES=${CASES:-"g250k:400 g250k:512 g1m:768 g1m:800"}; CASES=${CASES//_/ }
ls -l "$BIN" "${BIN}_float"
mkdir -p "$RES"; CSV=$RES/samegrid.csv
[ -f "$CSV" ] || echo "data,boxes,precision,rep,iters,sec_per_iter_steady,sec_per_iter_total" > "$CSV"
jv() { tr -d ' \n' < "$1" | sed -n "s/.*\"$2\":\([-0-9.eE+]*\).*/\1/p"; }
for r in $(seq 1 "$REPS"); do
  for c in $CASES; do
    d=${c%%:*}; b=${c##*:}
    [ -f "data/$d.ds.bin" ] || { echo "MISSING data/$d.ds.bin"; continue; }
    for prec in double float; do
      bin=$BIN; [ "$prec" = float ] && bin=${BIN}_float
      out=$RES/${d}_b${b}_${prec}_r$r
      grep -q "^$d,$b,$prec,$r," "$CSV" && continue
      mkdir -p "$out"
      $LAUNCH 1 "$bin" --data "data/$d.ds.bin" --iters "$ITERS" --seed 42 --report-every 0 --grid-mode fixed --fixed-boxes "$b" --out "$out" > "$out.log" 2>&1 \
        || { fail_note "FAILED $out"; continue; }
      echo "$d,$b,$prec,$r,$ITERS,$(jv "$out/summary.json" seconds_per_iter_steady),$(jv "$out/summary.json" seconds_per_iter_total)" >> "$CSV"
      tail -1 "$CSV"
    done
  done
done
# quality of double vs float after a FULL run (QITERS iterations, seeds QSEEDS) on QCASES
QCSV=$RES/quality.csv; [ -f "$QCSV" ] || echo "data,boxes,precision,seed,iters,trust,knn_recall,purity,final_kl,sec_per_iter_steady" > "$QCSV"
for sd in $QSEEDS; do
  for c in $QCASES; do
    d=${c%%:*}; b=${c##*:}
    [ -f "data/$d.ds.bin" ] && [ -f "data/$d.feat.bin" ] || { echo "MISSING data for $d"; continue; }
    for prec in double float; do
      bin=$BIN; [ "$prec" = float ] && bin=${BIN}_float
      out=$RES/q_${d}_b${b}_${prec}_s$sd
      grep -q "^$d,$b,$prec,$sd," "$QCSV" && continue
      mkdir -p "$out"
      $LAUNCH 1 "$bin" --data "data/$d.ds.bin" --iters "$QITERS" --seed "$sd" --report-every 0 --grid-mode fixed --fixed-boxes "$b" --out "$out" > "$out.log" 2>&1 \
        || { fail_note "FAILED $out"; continue; }
      "$TOOLS" eval --feat "data/$d.feat.bin" --data "data/$d.ds.bin" --emb "$out/embedding.bin" --sample "$SAMPLE" --json "$out/quality.json" > "$out/eval.log" 2>&1
      echo "$d,$b,$prec,$sd,$QITERS,$(jv "$out/quality.json" trustworthiness),$(jv "$out/quality.json" knn_recall),$(jv "$out/quality.json" label_purity),$(jv "$out/summary.json" final_kl),$(jv "$out/summary.json" seconds_per_iter_steady)" >> "$QCSV"
      tail -1 "$QCSV"
      rm -f "$out/embedding.bin"
    done
  done
done
column -s, -t "$CSV"; column -s, -t "$QCSV"
)

# study_hpcx_probe -- diagnostic of the device-pointer ping-pong with the NVHPC/HPC-X Open MPI: tries several UCX / Open MPI transport settings with two
# ranks and prints the fitted alpha/beta of each.  Run with MODULES=nvhpc-hpcx-cuda12/26.1 and BUILD=build_hpcx (implementation/jobs/vanda_gpu.pbs); with MULTINODE=1 on
# two nodes the inter-node variants (UCX_NET_DEVICES=all, tcp) are tried as well.  Output: $RES/hpcx_probe/pp_<variant>.csv
study_hpcx_probe() {
  [ "${DRY:-0}" = 1 ] && { echo "hpcx_probe"; return; }
  local out="$RES/hpcx_probe"; mkdir -p "$out"; local MB=${MB:-$BUILD/microbench}
  ucx_info -d 2>/dev/null | grep -i -E "Transport:|cuda" | sort | uniq -c | head -30
  env | grep -i -E "^UCX|^OMPI|^HPCX" | sort | head -30
  local B="${LAUNCH_BASE:-mpirun --bind-to none}"; [ -z "${MULTINODE:-}" ] && B="$B --oversubscribe"
  pp() { local tag=$1; shift; echo "=== $tag"; timeout 120 "$@" --test pingpong --peer 1 --device-ptr > "$out/pp_$tag.csv" 2>&1; echo "rc=$?"; grep -E "^fit|error|Error|fail" "$out/pp_$tag.csv" | head -5; }
  pp default        $B -np 2 $MB
  pp ucx_cudaipc    $B -np 2 -x UCX_TLS=cuda_copy,cuda_ipc,sm,self $MB
  pp ucx_nocudaipc  $B -np 2 -x UCX_TLS=cuda_copy,sm,self $MB
  pp ucx_log        $B -np 2 -x UCX_LOG_LEVEL=info $MB
  pp ucx_rndv_get   $B -np 2 -x UCX_RNDV_SCHEME=get_zcopy $MB
  if [ -n "${MULTINODE:-}" ]; then
    pp ucx_netall   $B -np 2 -x UCX_NET_DEVICES=all $MB
    pp ucx_tcp      $B -np 2 -x UCX_TLS=tcp,self,sm,cuda_copy,cuda_ipc -x UCX_NET_DEVICES=all $MB
    pp ob1_tcp      $B -np 2 --mca pml ob1 --mca btl tcp,self $MB
  fi
  pp ob1_smcuda     $B -np 2 --mca pml ob1 --mca btl smcuda,self $MB
}

STUDIES=${*:-}
[ -z "$STUDIES" ] && { sed -n '2,/^set -u/p' "$0" | sed 's/^# \{0,1\}//' | head -60; exit 0; }
[ "$STUDIES" = all ] && STUDIES="gate micro pilot C A B"
for s in $STUDIES; do echo "=================== study $s"; "study_$s"; done
if [ -f "${RES:-.}/FAILED_RUNS.txt" ] && grep -q "^$JOB_TAG " "${RES:-.}/FAILED_RUNS.txt"; then
  echo "SOME RUNS FAILED (details in ${RES:-.}/FAILED_RUNS.txt):"; grep "^$JOB_TAG " "${RES:-.}/FAILED_RUNS.txt"; exit 1
fi
