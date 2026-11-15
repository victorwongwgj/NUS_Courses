#!/usr/bin/env bash
# EXPERIMENTAL -- NOT USED FOR ANY NUMBER OF THE REPORT (the option has only been compiled against the CPU emulation, never run on a GPU).
# overlap_near.sh -- tsne_gpu --overlap-near (attraction on a second CUDA stream, overlapping the FFT) against the default, same fixed grid.
#   qsub -N gpu_ovl -l select=1:ncpus=8:ngpus=2:mem=64gb -l walltime=01:00:00 -v SCRIPT=implementation/scripts/overlap_near.sh implementation/jobs/vanda_gpu.pbs
# Variables (-v; '_' separates list items):
#   CASES="g1m:768_g250k:400"  data:boxes   PS="1_2"   ITERS=100   REPS=5   RES=results_gpu_overlap   ARCH=sm_86   FFT_MODES="replicated_distributed"
# Output: $RES/overlap.csv (one row per run; on/off interleaved within each repetition), $RES/<run>/summary.json.
# Notes:  * With overlap the stage times (near, fft) overlap in time, so they no longer sum to the iteration time; compare sec_per_iter only.
#         * final_kl must agree between on and off (same arithmetic, other order of launches): a difference beyond ~1e-9 is a bug.
#         * Restartable: finished rows are skipped.
set -u
cd "$(dirname "$0")/../.."
ARCH=${ARCH:-sm_86}; RES=${RES:-results_gpu_overlap}; ITERS=${ITERS:-100}; REPS=${REPS:-5}
CASES=${CASES:-"g1m:768 g250k:400"}; CASES=${CASES//_/ }; PS=${PS:-"1 2"}; PS=${PS//_/ }
FFT_MODES=${FFT_MODES:-"replicated distributed"}; FFT_MODES=${FFT_MODES//_/ }
make gpu ARCH="$ARCH" CXX=g++ MPICXX=mpicxx REAL=double || exit 1
BIN=build/tsne_gpu; LAUNCH=${LAUNCH:-"mpirun -np"}
mkdir -p "$RES"
jv() { tr -d ' \n' < "$1" | sed -n "s/.*\"$2\":\([-0-9.eE+]*\).*/\1/p"; }
CSV=$RES/overlap.csv
STAGES="fft near_local near_remote gather scatter exch_comm gpu_wait"
if [ ! -f "$CSV" ]; then
  hdr="data,boxes,P,fft,overlap,rep,iters,sec_per_iter_steady,sec_per_iter_total,final_kl"
  for s in $STAGES; do hdr="$hdr,$s"; done; echo "$hdr" > "$CSV"
fi
for r in $(seq 1 "$REPS"); do
  for c in $CASES; do
    d=${c%%:*}; b=${c##*:}
    [ -f "data/$d.ds.bin" ] || { echo "MISSING data/$d.ds.bin"; continue; }
    for np in $PS; do for fft in $FFT_MODES; do
      [ "$np" = 1 ] && [ "$fft" = distributed ] && continue
      # alternate the order of on/off with the repetition so that drift does not favor one side
      if [ $((r % 2)) = 1 ]; then ORDER="off on"; else ORDER="on off"; fi
      for ov in $ORDER; do
        grep -q "^$d,$b,$np,$fft,$ov,$r," "$CSV" && continue
        out=$RES/${d}_b${b}_p${np}_${fft}_${ov}_r$r; mkdir -p "$out"
        flag=""; [ "$ov" = on ] && flag="--overlap-near"
        $LAUNCH "$np" $BIN --data "data/$d.ds.bin" --iters "$ITERS" --seed 42 --report-every 0 --grid-mode fixed --fixed-boxes "$b" \
               --fft "$fft" $flag --out "$out" > "$out.log" 2>&1 || { echo "FAILED $out"; tail -3 "$out.log"; continue; }
        row="$d,$b,$np,$fft,$ov,$r,$ITERS,$(jv "$out/summary.json" seconds_per_iter_steady),$(jv "$out/summary.json" seconds_per_iter_total),$(jv "$out/summary.json" final_kl)"
        for s in $STAGES; do row="$row,$(jv "$out/summary.json" "steady_$s")"; done
        echo "$row" >> "$CSV"; tail -1 "$CSV" | cut -d, -f1-10
        rm -f "$out/embedding.bin"
      done
    done; done
  done
done
# median per configuration and the ratio on/off
python3 - "$CSV" <<'PY'
import csv, sys, statistics as st, collections
rows = list(csv.DictReader(open(sys.argv[1])))
g = collections.defaultdict(lambda: collections.defaultdict(list))
kl = collections.defaultdict(lambda: collections.defaultdict(set))
for r in rows:
    k = (r['data'], r['boxes'], r['P'], r['fft'])
    g[k][r['overlap']].append(float(r['sec_per_iter_steady'])); kl[k][r['overlap']].add(r['final_kl'])
print("\ndata boxes P fft | median ms/iter off | on | on/off | final_kl equal")
for k, v in g.items():
    if 'on' in v and 'off' in v:
        a, b = st.median(v['off']) * 1e3, st.median(v['on']) * 1e3
        same = kl[k]['on'] == kl[k]['off'] or abs(float(next(iter(kl[k]['on']))) - float(next(iter(kl[k]['off'])))) < 1e-9
        print(*k, f"| {a:.2f} | {b:.2f} | {b/a:.3f} | {same}")
PY
echo "== overlap_near done $(date -Is)"
