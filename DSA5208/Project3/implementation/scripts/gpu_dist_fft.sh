#!/usr/bin/env bash
# gpu_dist_fft.sh -- distributed FFT on the GPU (tsne_gpu --fft distributed): (1) correctness gate, (2) time per iteration against the
#                    replicated FFT on the same grid, with the stages of the iteration, (3) quality of a full run.
#   qsub -N gpu_dist -l select=1:ncpus=8:ngpus=2:mem=64gb -l walltime=02:00:00 -v SCRIPT=implementation/scripts/gpu_dist_fft.sh implementation/jobs/vanda_gpu.pbs
# Variables (-v; '_' separates list items):
#   CASES="g250k:400_g250k:512_g1m:768"  data:boxes (fixed grids, the same as the CPU strong scaling)   PS="1_2"   ITERS=100   REPS=3
#   GATE=1 (0 = skip the gate)  GATE_DATA=data/gate.ds.bin  GATE_COORDS=results/gate/cpu_run/embedding.bin (made by a short run if missing)  GATE_TOL=1e-10
#   QUALITY=1  QCASE=g250k:400  QITERS=1000  QSEEDS=1  SAMPLE=1000        RES=results_gpu_dist   ARCH=sm_86   TRANSPORTS="host"
# Output: $RES/gate.txt ; $RES/dist.csv (one row per run: data,boxes,P,fft,transport,rep,iters, seconds per iteration and the stages in
#         seconds per iteration, steady state = without the first 10 iterations) ; $RES/quality.csv ; $RES/<run>/summary.json.
# Notes:  * "fft" of a distributed run = row transforms; fft_cols and fft_rows_inv are the other two transform segments, fft_transpose the two
#           MPI_Alltoall (incl. host copies), pot_allgather the Allgatherv of the potentials, fft_perm_in/out the layout changes.
#         * kernel_spec (every iteration in fixed-grid mode) of a distributed run contains one more transpose, which is also counted in fft_transpose.
#         * P=1 with --fft distributed measures the cost of the distributed code path itself (no partner).
#         * Restartable: finished rows are skipped. A failed gate stops the script before any timing.
set -u
cd "$(dirname "$0")/../.."
ARCH=${ARCH:-sm_86}; RES=${RES:-results_gpu_dist}; ITERS=${ITERS:-100}; REPS=${REPS:-3}; GATE=${GATE:-1}; GATE_TOL=${GATE_TOL:-1e-10}
CASES=${CASES:-"g250k:400 g250k:512 g1m:768"}; CASES=${CASES//_/ }; PS=${PS:-"1 2"}; PS=${PS//_/ }; TRANSPORTS=${TRANSPORTS:-host}; TRANSPORTS=${TRANSPORTS//_/ }   # host | device (CUDA-aware MPI)
QUALITY=${QUALITY:-1}; QCASE=${QCASE:-g250k:400}; QITERS=${QITERS:-1000}; QSEEDS=${QSEEDS:-1}; QSEEDS=${QSEEDS//_/ }; SAMPLE=${SAMPLE:-1000}
GATE_DATA=${GATE_DATA:-data/gate.ds.bin}; GATE_COORDS=${GATE_COORDS:-results/gate/cpu_run/embedding.bin}
[ -f "$GATE_DATA" ] || GATE_DATA=data/g100k.ds.bin
make gpu ARCH="$ARCH" CXX=g++ MPICXX=mpicxx REAL=double || exit 1
make cpu OMP=1 CXX=g++ || exit 1
BIN=build/tsne_gpu
# MULTI=1: one rank per node on the nodes of the job (qsub -l select=2:ncpus=8:ngpus=1 -l place=scatter); plain mpirun fills the first node first.
if [ "${MULTI:-0}" = 1 ]; then
  HF=$(mktemp); sort -u "$PBS_NODEFILE" > "$HF"; echo "nodes:"; cat "$HF"
  LAUNCH="mpirun --hostfile $HF --mca plm rsh --bind-to none --map-by ppr:1:node --prefix $(dirname $(dirname $(which mpirun))) -x LD_LIBRARY_PATH -x PATH -np"
else LAUNCH="mpirun -np"; fi
echo "launch: $LAUNCH"
ls -l "$BIN"
if [ -x build/compare_grad ]; then CMP="build/compare_grad"; else CMP="build/tsne_tools compare-grad"; fi
if [ -x build/eval ]; then EVAL="build/eval"; else EVAL="build/tsne_tools eval"; fi
mkdir -p "$RES"
jv() { tr -d ' \n' < "$1" | sed -n "s/.*\"$2\":\([-0-9.eE+]*\).*/\1/p"; }

# ---------------- (1) correctness gate: gradient of the distributed FFT against the replicated FFT, one evaluation at fixed coordinates ----------------
if [ "$GATE" = 1 ]; then
  G=$RES/gate; mkdir -p "$G"; : > "$RES/gate.txt"
  if [ ! -f "$GATE_COORDS" ]; then
    GATE_COORDS=$G/coords/embedding.bin
    [ -f "$GATE_COORDS" ] || $LAUNCH 1 $BIN --data "$GATE_DATA" --iters 150 --exag-iters 75 --mom-switch 75 --report-every 0 --out "$G/coords" > "$G/coords.log" 2>&1
  fi
  [ -f "$GATE_COORDS" ] || { echo "GATE: no coordinates ($GATE_COORDS)" | tee -a "$RES/gate.txt"; exit 3; }
  echo "gate data $GATE_DATA coords $GATE_COORDS" | tee -a "$RES/gate.txt"
  run_grad() {  # name np options...
    local name=$1 np=$2; shift 2
    $LAUNCH "$np" $BIN --data "$GATE_DATA" --mode grad --coords "$GATE_COORDS" --out "$G/$name" "$@" > "$G/$name.log" 2>&1
    [ -f "$G/$name/grad.bin" ]
  }
  run_grad ref 1 || { echo "GATE: reference run failed" | tee -a "$RES/gate.txt"; exit 3; }
  fail=0
  GX=""; case " $TRANSPORTS " in *" device "*) GX="d_p2_device:2:--transport device";; esac
  for spec in "d_p1:1:" "d_p2:2:" "d_p2_nbgrid:2:--grid-comm nonblocking" "d_p2_allgather:2:--exchange allgather --comm nonblocking" \
              "d_p2_fixedgrid:2:--grid-mode fixed --fixed-boxes 200" ${GX:+"$GX"}; do
    name=${spec%%:*}; rest=${spec#*:}; np=${rest%%:*}; opts=${rest#*:}
    ref=$G/ref/grad.bin
    if [[ "$name" == *fixedgrid ]]; then   # needs its own reference with the same grid
      run_grad ref_fixed 1 $opts || { echo "FAIL (run) ref_fixed" | tee -a "$RES/gate.txt"; fail=1; continue; }
      ref=$G/ref_fixed/grad.bin
    fi
    msg=""
    if run_grad "$name" "$np" --fft distributed $opts; then
      res=$($CMP "$ref" "$G/$name/grad.bin" --tol-grad "$GATE_TOL" --tol-attr "$GATE_TOL" --tol-rep "$GATE_TOL" --tol-z "$GATE_TOL" | tail -2)
      if echo "$res" | grep -q PASS; then msg="ok    $name   $(echo "$res" | head -1)"
      else msg="FAIL  $name   $res"; fail=1; fi
    else msg="FAIL (run) $name"; fail=1; fi
    echo "$msg" | tee -a "$RES/gate.txt"
  done
  if [ "$fail" != 0 ]; then echo "GATE FAILED -- stopping before any timing" | tee -a "$RES/gate.txt"; exit 4; fi
  echo "GATE PASSED" | tee -a "$RES/gate.txt"
fi

# ---------------- (2) time per iteration: replicated against distributed FFT on the same fixed grid ----------------
CSV=$RES/dist.csv
STAGES="fft fft_cols fft_rows_inv fft_transpose pot_allgather fft_perm_in fft_perm_out kernel_spec grid_comm grid_d2h grid_h2d grid_wait scatter gather gpu_wait exch_comm"
if [ ! -f "$CSV" ]; then
  hdr="data,boxes,P,fft,transport,rep,iters,sec_per_iter_steady,sec_per_iter_total"
  for s in $STAGES; do hdr="$hdr,$s"; done
  echo "$hdr,bytes_fft_transpose,bytes_pot_allgather,gpu_mem_bytes" > "$CSV"
fi
for r in $(seq 1 "$REPS"); do
  for c in $CASES; do
    d=${c%%:*}; b=${c##*:}
    [ -f "data/$d.ds.bin" ] || { echo "MISSING data/$d.ds.bin"; continue; }
    for np in $PS; do
      for tr in $TRANSPORTS; do
        for fft in replicated distributed; do
          [ "$np" = 1 ] && [ "$tr" != host ] && continue
          grep -q "^$d,$b,$np,$fft,$tr,$r," "$CSV" && continue
          out=$RES/${d}_b${b}_p${np}_${fft}_${tr}_r$r
          mkdir -p "$out"
          $LAUNCH "$np" $BIN --data "data/$d.ds.bin" --iters "$ITERS" --seed 42 --report-every 0 --grid-mode fixed --fixed-boxes "$b" \
                 --fft "$fft" --transport "$tr" --out "$out" > "$out.log" 2>&1 || { echo "FAILED $out"; tail -3 "$out.log"; continue; }
          row="$d,$b,$np,$fft,$tr,$r,$ITERS,$(jv "$out/summary.json" seconds_per_iter_steady),$(jv "$out/summary.json" seconds_per_iter_total)"
          for s in $STAGES; do row="$row,$(jv "$out/summary.json" "steady_$s")"; done
          echo "$row,$(jv "$out/summary.json" bytes_fft_transpose_per_iter),$(jv "$out/summary.json" bytes_pot_allgather_per_iter),$(jv "$out/summary.json" gpu_mem_in_use_bytes_max)" >> "$CSV"
          tail -1 "$CSV" | cut -d, -f1-9
          rm -f "$out/embedding.bin"
        done
      done
    done
  done
done

# ---------------- (3) quality of a full run: replicated against distributed (P = largest of PS) ----------------
if [ "$QUALITY" = 1 ]; then
  QCSV=$RES/quality.csv; [ -f "$QCSV" ] || echo "data,boxes,P,fft,seed,iters,trust,knn_recall,purity,final_kl,sec_per_iter_total" > "$QCSV"
  d=${QCASE%%:*}; b=${QCASE##*:}; np=$(echo $PS | tr ' ' '\n' | sort -n | tail -1)
  if [ -f "data/$d.ds.bin" ] && [ -f "data/$d.feat.bin" ]; then
    for sd in $QSEEDS; do
      for fft in replicated distributed; do
        grep -q "^$d,$b,$np,$fft,$sd," "$QCSV" && continue
        out=$RES/q_${d}_b${b}_p${np}_${fft}_s$sd; mkdir -p "$out"
        $LAUNCH "$np" $BIN --data "data/$d.ds.bin" --iters "$QITERS" --seed "$sd" --report-every 0 --grid-mode fixed --fixed-boxes "$b" --fft "$fft" --out "$out" > "$out.log" 2>&1 \
          || { echo "FAILED $out"; continue; }
        $EVAL --feat "data/$d.feat.bin" --data "data/$d.ds.bin" --emb "$out/embedding.bin" --sample "$SAMPLE" --json "$out/quality.json" > "$out/eval.log" 2>&1
        echo "$d,$b,$np,$fft,$sd,$QITERS,$(jv "$out/quality.json" trustworthiness),$(jv "$out/quality.json" knn_recall),$(jv "$out/quality.json" label_purity),$(jv "$out/summary.json" final_kl),$(jv "$out/summary.json" seconds_per_iter_total)" >> "$QCSV"
        tail -1 "$QCSV"
        rm -f "$out/embedding.bin"
      done
    done
  else echo "QUALITY: data/$d.ds.bin or data/$d.feat.bin missing"; fi
fi
column -s, -t "$CSV" | cut -c1-200
[ -f "${QCSV:-/nonexistent}" ] && column -s, -t "$QCSV"
echo "== gpu_dist_fft done $(date -Is)"
