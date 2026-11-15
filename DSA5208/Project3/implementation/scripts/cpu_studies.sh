#!/usr/bin/env bash
# cpu_studies.sh -- every study that needs only CPU cores and (at most) a handful of MPI ranks on one node:
# the serial timing studies, the exact-t-SNE validation, the comparison with the official FIt-SNE and the KL-gap ablation.
#
#   implementation/scripts/cpu_studies.sh COMMAND [COMMAND ...]        (or CMD=COMMAND1+COMMAND2 in the environment, for implementation/jobs/vanda_cpu.pbs)
#
#   COMMAND         report experiment / figure                          main variables (defaults in the code below)
#   serial-base     S1 serial baselines T_s (fixed grids 512/400/200)    NAMES BOXES ITERS REPS
#   serial-grid     S1 FFT cost vs grid size                            NAME BOXES ITERS
#   serial-npts     S1 point-dependent cost vs N at one grid            NAMES BOXES ITERS
#   serial-nscale   S1 whole algorithm, grid growing with N             NAMES N0_BOXES NPR ITERS
#   serial-knn      S1 cost vs number of neighbours K (fig11)           KN KS BOXES ITERS (makes the data sets itself)
#   serial-exact    S1 exact O(N^2) vs FIt-SNE, 30 iterations           NSIZES ITERS
#   serial-all      the five serial studies above with the settings of the report (one job, so they do not disturb each other);
#                   SERIAL_STUDIES="base grid npts nscale exact" (or '+'-separated) selects a subset
#   crossover       S2 break-even N of exact vs FIt-SNE (full runs)     NSIZES REPS ITERS RES
#   pcost           C-section: cost of the interpolation order p        NAMES BOXES PORDERS ITERS REPS RES
#   validation      V1/V2 FIt-SNE and the MPI program vs exact t-SNE    N ITERS SEEDS PS (MPI ranks) BOXLIST ORDERS GRADN
#   official        O1 official FIt-SNE vs ours                         DATA CONFIGS SEEDS THREADS MPI_PS ITERS RES OURS_SERIAL
#   klgap           K1 KL-gap ablation                                  DATA SEEDS ITERS LONG VARIANTS RES
#
# List-valued variables are separated by spaces, or by '_' (so that they survive `qsub -v`). Every study is restartable: finished runs are
# skipped.  Timing studies must run on an otherwise idle core (request a whole node or place=excl).  OMP_NUM_THREADS is set to 1 where the
# study measures a single core.  Common variables: BUILD (default build), RES (output directory; each study has its own default).
# The code of each study is the former stand-alone script; its original documentation is kept above it.
set -eu
cd "$(dirname "$0")/../.."
BUILD=${BUILD:-build}
export BUILD
TOOLS=$BUILD/tsne_tools        # gen-data | prep-cpu | eval | compare-grad | fitsne-io
CPU=$BUILD/tsne_cpu            # serial t-SNE / FIt-SNE
MPI_CPU=$BUILD/tsne_mpi_cpu    # pure-MPI program (validation and official comparison only)

# ==============================================================================================================
# STUDY base|grid|npts|nscale|knn|exact: serial FIt-SNE timing studies (S1: Fig. R1a/R1b, fig11)
# ==============================================================================================================
# Study serial-all — serial (1 core, tsne_cpu) timing studies, to be run on a cluster node (all reported timings come from Vanda).
#
#   STUDY=base   NAMES="g250k" BOXES="512 400 200" ITERS=300   # fixed-grid serial baselines = denominators T_s of the speed-ups
#   STUDY=grid   NAME=g100k BOXES="50 75 100 150 200 300 400 600" ITERS=40   # FFT cost vs grid size: expect  t_fft ~ G log G,  G = (2M)^2 = (6n)^2 FFT points
#   STUDY=npts   BOXES=200 NAMES="g100k g250k g500k g1m" ITERS=40            # point-dependent work (spread/gather/attraction) vs N at one grid: expect ~ N
#   STUDY=nscale NAMES="g10000 g20000 ... g1280000" N0_BOXES=40 NPR=10000    # whole algorithm, grid growing with N (boxes = N0_BOXES*sqrt(N/NPR)): expect ~ N log N
#   STUDY=knn    KN="20000 50000" KS="15 30 60 90 150 300" BOXES=100 ITERS=100   # nonzeros of P (= N*K, K = 3*perplexity) varied at fixed grid: attraction ~ N*K, FFT constant; makes data g<N>_k<K> itself (PREP=cpu)
#   STUDY=exact  NSIZES="1000 2000 4000 8000" ITERS=30                       # exact O(N^2) vs FIt-SNE (adaptive grid, default box width) vs N; makes the small data sets itself
#
# Output: $RES/serial/<study>/<name>_<method>_b<boxes>_r<rep>/{summary.json,timing.csv}; $RES/serial/<study>.csv with one row per run:
#   study,name,N,method,boxes,grid_dim,rep,iters,med_total,med_repulsion,med_attraction,med_update,med_spread,med_kernel_spec,med_fft,med_gather
# (seconds per iteration, median over iterations, first 10 skipped.)  med_repulsion = spread + kernel_spec + fft + gather (+ glue);
# med_fft = packing + forward FFT + kernel product + inverse FFT: the O(G log G) part.  med_kernel_spec = FFT of the kernel (also O(G log G)).
# Restartable: finished runs are skipped. Needs data/<name>.ds.bin for every study except `exact` (implementation/scripts/prepare.sh synthetic; g100k..g1m, g10000..g1280000 exist on Vanda).
study_serial_scaling() (
set -eu
STUDY=${STUDY:?STUDY=base|grid|npts|nscale|exact}; ITERS=${ITERS:-300}; SEED=${SEED:-42}; REPS=${REPS:-3}; RES=${RES:-results_vanda_cpu}
NAMES=${NAMES:-${NAME:-g250k}}; BOXES=${BOXES:-400}; NAMES=${NAMES//_/ }; BOXES=${BOXES//_/ }
NSIZES=${NSIZES:-"1000 2000 4000 8000"}; NSIZES=${NSIZES//_/ }; N0_BOXES=${N0_BOXES:-40}; NPR=${NPR:-10000}
export OMP_NUM_THREADS=1
mkdir -p "$RES/serial/$STUDY"; CSV=$RES/serial/$STUDY.csv
HDR="study,name,N,method,boxes,grid_dim,rep,iters,med_total,med_repulsion,med_attraction,med_update,med_spread,med_kernel_spec,med_fft,med_gather"
[ -f "$CSV" ] || echo "$HDR" > "$CSV"
median() { sort -g | awk '{a[NR]=$1} END{ if(NR==0){print "nan"} else if(NR%2){print a[(NR+1)/2]} else {printf "%.9g\n",(a[NR/2]+a[NR/2+1])/2} }'; }
col() { awk -F, -v c="$2" 'NR>11 {print $c}' "$1" | median; }      # skip the header and the first 10 iterations

one() {  # name method boxes(or "adaptive") rep
  local nm=$1 method=$2 nb=$3 r=$4
  [ -f "data/$nm.ds.bin" ] || { echo "MISSING data/$nm.ds.bin"; return 0; }
  local out=$RES/serial/$STUDY/${nm}_${method}_b${nb}_r$r
  local gopt="--grid-mode adaptive"; [ "$nb" != adaptive ] && gopt="--grid-mode fixed --fixed-boxes $nb"
  if [ -f "$out/summary.json" ]; then echo "skip $out"; else
    mkdir -p "$out"
    "$CPU" --data "data/$nm.ds.bin" --method "$method" --iters "$ITERS" --seed "$SEED" --report-every 0 $gopt --out "$out" > "$out.log" 2>&1 \
      || { echo "FAILED $out"; return 0; }
  fi
  local N; N=$(tr -d ' \n' < "$out/summary.json" | sed -n 's/.*"N":\([0-9]*\).*/\1/p')
  grep -q "^$STUDY,$nm,$N,$method,$nb,.*,$r,$ITERS," "$CSV" && return 0
  local gd=""; [ "$nb" != adaptive ] && gd=$((3*nb))
  local t=$out/timing.csv
  echo "$STUDY,$nm,$N,$method,$nb,$gd,$r,$ITERS,$(col $t 5),$(col $t 2),$(col $t 3),$(col $t 4),$(col $t 6),$(col $t 7),$(col $t 8),$(col $t 9)" >> "$CSV"
}

case $STUDY in
  base|grid|npts)
    for nm in $NAMES; do for nb in $BOXES; do for r in $(seq 1 "$REPS"); do one "$nm" fast "$nb" "$r"; done; done; done ;;
  nscale)
    for nm in $NAMES; do
      N=$(echo "$nm" | sed -n 's/^g\([0-9]*\)$/\1/p'); case $nm in g100k) N=100000;; g250k) N=250000;; g500k) N=500000;; g1m) N=1000000;; esac
      [ -n "$N" ] || { echo "cannot parse N from $nm"; continue; }
      nb=$(awk -v n0="$N0_BOXES" -v n="$N" -v npr="$NPR" 'BEGIN{printf "%d", int(n0*sqrt(n/npr)+0.5)}')
      for r in $(seq 1 "$REPS"); do one "$nm" fast "$nb" "$r"; done
    done ;;
  knn)
    KN=${KN:-"20000 50000"}; KS=${KS:-"15 30 60 90 150 300"}; KN=${KN//_/ }; KS=${KS//_/ }
    for n in $KN; do for k in $KS; do
      nm=g${n}_k$k
      OMP_NUM_THREADS=${PREP_THREADS:-1} PREP=${PREP:-cpu} implementation/scripts/prepare.sh synthetic "$nm" "$n" 50 20 6 "$k" > /dev/null || { echo "data FAILED $nm"; continue; }
      for nb in $BOXES; do for r in $(seq 1 "$REPS"); do one "$nm" fast "$nb" "$r"; done; done
    done; done ;;
  exact)
    for n in $NSIZES; do
      nm=g$n; PREP=${PREP:-cpu} implementation/scripts/prepare.sh synthetic "$nm" "$n" 50 20 6 90 > /dev/null
      for r in $(seq 1 "$REPS"); do one "$nm" exact adaptive "$r"; one "$nm" fast adaptive "$r"; done
    done ;;
  *) echo "unknown STUDY=$STUDY"; exit 2 ;;
esac
column -s, -t "$CSV"
)

# ==============================================================================================================
# crossover: exact vs FIt-SNE, full runs on one core (Fig. R11)
# ==============================================================================================================
# Study crossover -- exact O(N^2) vs FIt-SNE on ONE core over a FULL run, to locate the break-even N directly and to explain why the per-iteration time
# of FIt-SNE depends on the phase of the run (the adaptive grid grows as the embedding spreads out; the earlier 30-iteration study saw only the compact start).
# Variables: NSIZES (list with '_'), REPS=2, ITERS=1000, SEED=42, RES=results_vanda_cross, FIXED_BOXES="" (optional: also run FIt-SNE with this fixed box count, e.g. 64)
# Output: $RES/<name>_<method>_<grid>_r<rep>/{summary.json,timing.csv};  $RES/crossover.csv with
#   N,method,grid,rep,iters,loop_seconds,sec_per_iter_mean,med_it11_250,med_it251_600,med_it601_end      (seconds; median of per-iteration 'total' in the iteration ranges)
study_serial_crossover() (
set -eu
NSIZES=${NSIZES:-"2000 3000 4000 5000 6000 8000 10000"}; NSIZES=${NSIZES//_/ }; REPS=${REPS:-2}; ITERS=${ITERS:-1000}; SEED=${SEED:-42}; RES=${RES:-results_vanda_cross}
FIXED_BOXES=${FIXED_BOXES:-}
export OMP_NUM_THREADS=1
mkdir -p "$RES"; CSV=$RES/crossover.csv
[ -f "$CSV" ] || echo "N,method,grid,rep,iters,loop_seconds,sec_per_iter_mean,med_it11_250,med_it251_600,med_it601_end" > "$CSV"
jv() { tr -d ' \n' < "$1" | sed -n "s/.*\"$2\":\([-0-9.eE+]*\).*/\1/p"; }
med() { awk -F, -v a="$1" -v b="$2" 'NR>1 && $1>=a && $1<=b {print $5}' "$3" | sort -g | awk '{x[NR]=$1} END{ if(NR==0){print "nan"} else if(NR%2){print x[(NR+1)/2]} else {printf "%.9g\n",(x[NR/2]+x[NR/2+1])/2} }'; }
one() {  # N method grid(adaptive|<boxes>) rep
  local n=$1 m=$2 g=$3 r=$4 nm=g$1
  grep -q "^$n,$m,$g,$r,$ITERS," "$CSV" && return 0
  local out=$RES/${nm}_${m}_${g}_r$r gopt="--grid-mode adaptive"; [ "$g" != adaptive ] && gopt="--grid-mode fixed --fixed-boxes $g"
  mkdir -p "$out"
  "$CPU" --data data/$nm.ds.bin --method "$m" --iters "$ITERS" --seed "$SEED" --report-every 0 $gopt --out "$out" > "$out.log" 2>&1 || { echo "FAILED $out"; return 0; }
  local L; L=$(jv "$out/summary.json" loop_seconds)
  echo "$n,$m,$g,$r,$ITERS,$L,$(awk -v l="$L" -v i="$ITERS" 'BEGIN{printf "%.6g", l/i}'),$(med 11 250 "$out/timing.csv"),$(med 251 600 "$out/timing.csv"),$(med 601 "$ITERS" "$out/timing.csv")" >> "$CSV"
  tail -1 "$CSV"
}
for n in $NSIZES; do
  PREP=${PREP:-cpu} implementation/scripts/prepare.sh synthetic "g$n" "$n" 50 20 6 90 > /dev/null
  for r in $(seq 1 "$REPS"); do
    one "$n" exact adaptive "$r"; one "$n" fast adaptive "$r"
    [ -n "$FIXED_BOXES" ] && one "$n" fast "$FIXED_BOXES" "$r"
  done
done
column -s, -t "$CSV"
)

# ==============================================================================================================
# pcost: cost of the interpolation order p (Fig. R14, right panel)
# ==============================================================================================================
# Study pcost -- cost of the interpolation order p (accuracy of p=2..5 against exact t-SNE is already in exact_validation/grad_errors.csv).
# ONE core, fixed grid, serial FIt-SNE; rounds interleaved over p so that node-speed drift hits every p equally.
# Variables: NAMES=g100k  BOXES=200 (boxes per dimension, fixed)  PORDERS="2 3 4 5"  ITERS=30  REPS=3  RES=results_pcost
# Output: $RES/pcost.csv  data,p,boxes,round,total,spread,kernel_spec,fft,gather,attraction = medians over iterations 10.. of timing.csv (seconds)  (grid nodes = (p*boxes)^2)
study_pcost() (
set -u
NAMES=${NAMES:-g100k}; BOXES=${BOXES:-200}; PORDERS=${PORDERS:-"2 3 4 5"}; ITERS=${ITERS:-30}; REPS=${REPS:-3}; RES=${RES:-results_pcost}
for v in NAMES BOXES PORDERS; do eval "$v=\${$v//_/ }"; done
export OMP_NUM_THREADS=1; mkdir -p "$RES"; CSV=$RES/pcost.csv
[ -f "$CSV" ] || echo "data,p,boxes,round,total,spread,kernel_spec,fft,gather,attraction" > "$CSV"
jv() { tr -d ' \n' < "$1" | sed -n "s/.*\"$2\":\([-0-9.eE+]*\).*/\1/p"; }
for r in $(seq 1 "$REPS"); do for d in $NAMES; do for b in $BOXES; do for p in $PORDERS; do
  out=$RES/${d}_b${b}_p${p}_r$r; [ -f "$out/summary.json" ] && continue
  "$CPU" --data data/$d.ds.bin --method fast --iters "$ITERS" --seed 42 --report-every 0 --order-p "$p" --grid-mode fixed --fixed-boxes "$b" --out "$out" > "$out.log" 2>&1 || { echo "FAILED $out"; continue; }
  med=$(python3 - "$out/timing.csv" <<'PY'
import csv,sys,statistics as st
rows=list(csv.DictReader(open(sys.argv[1])))[10:]
print(",".join("%.6g"%st.median(float(r[k]) for r in rows) for k in ["total","spread","kernel_spec","fft","gather","attraction"]))
PY
)
  echo "$d,$p,$b,$r,$med" >> "$CSV"; tail -1 "$CSV"
done; done; done; done
echo DONE
)

# ==============================================================================================================
# validation: V1/V2 gradient errors and end-to-end quality against exact t-SNE (Fig. fig5)
# ==============================================================================================================
# Study validation — validate FIt-SNE (serial and parallel) against EXACT t-SNE at small sizes.
# (Instructor feedback, 10-29: "For validation, you can check against an exact t-SNE at a smaller problem size".)
#
#   N=5000 ITERS=1000 SEEDS="1 2 3" PS="4 12" implementation/scripts/cpu_studies.sh validation       # PS: also the MPI program on these rank counts (needs mpirun, tsne_mpi_cpu)
#   Other variables: BOXLIST="16 32 64 128 256"  ORDERS="2 4 5"  GRADN="2000 5000 10000 20000"  SAMPLE=2000  RES=results  LAUNCH="mpirun -np"
#
# What "exact" means here: the repulsive force and Z are summed over ALL N^2 pairs; the attractive part uses the SAME sparse kNN affinity matrix P
# (k = 90 = 3*perplexity) as FIt-SNE, as in the FIt-SNE paper and the official implementation. So the comparison isolates the approximation made in the
# repulsion (interpolation onto a grid + FFT) and the parallelisation; it does not test the kNN truncation of P.
#
# Part 1 (gradient error, N): exact runs of 50, 250 and ITERS iterations (seed 1) give three coordinate sets (early / end of early exaggeration / converged).
#   At each set the gradient is computed by the exact method (reference) and by FIt-SNE: serial adaptive grid; serial fixed grids of BOXLIST boxes (order p=3);
#   serial fixed 128 boxes with interpolation orders ORDERS; and, if PS is set, the MPI program (replicated and distributed FFT).
#   tsne_tools compare-grad gives the relative L2 error of Z, the attractive force, the repulsive force and the total gradient.   -> grad_errors.csv
# Part 2 (end-to-end): full runs of exact / FIt-SNE / MPI program (same data, ITERS iterations, every seed in SEEDS), scored with tsne_tools eval
#   (trustworthiness, kNN recall, label purity) and the final KL.   -> quality.csv, quality_summary.csv (mean +- std over seeds)
# Part 3 (error vs N): for N in GRADN, coordinates from a 250-iteration FIt-SNE run; gradient error of FIt-SNE (adaptive; fixed 128 boxes) against the exact one.  -> gradN_errors.csv
# Cost: the exact method is O(N^2) per iteration (~1 s/iter at N=5000 on one core): 3 seeds x ITERS=1000 take ~1 h; ask for 4 h.
study_validation() (
set -eu
N=${N:-5000}; ITERS=${ITERS:-1000}; SEEDS=${SEEDS:-"1 2 3"}; SEEDS=${SEEDS//_/ }; PS=${PS:-}; PS=${PS//_/ }; SAMPLE=${SAMPLE:-2000}
BOXLIST=${BOXLIST:-"16 32 64 128 256"}; BOXLIST=${BOXLIST//_/ }; ORDERS=${ORDERS:-"2 4 5"}; ORDERS=${ORDERS//_/ }
GRADN=${GRADN:-"2000 5000 10000 20000"}; GRADN=${GRADN//_/ }
LAUNCH=${LAUNCH:-mpirun -np}; MPIBIN=${MPIBIN:-$MPI_CPU}
NAME=${NAME:-ev$N}; OUT=${RES:-results}/exact_validation; mkdir -p "$OUT" data
PREP=${PREP:-cpu} implementation/scripts/prepare.sh synthetic "$NAME" "$N" 50 20 6 90
D=data/$NAME.ds.bin; F=data/$NAME.feat.bin
SEED1=$(echo $SEEDS | awk '{print $1}')

jv() { tr -d ' \n' < "$1" | sed -n "s/.*\"$2\":\([-0-9.eE+]*\).*/\1/p"; }
fkl() { local v; v=$(jv "$OUT/$1/summary.json" final_kl); [ -z "$v" ] && [ -f "$OUT/$1/kl.csv" ] && v=$(tail -1 "$OUT/$1/kl.csv" | cut -d, -f2); echo "$v"; }
run_serial() {  # name method seed [extra...]
  local nm=$1 m=$2 sd=$3; shift 3
  [ -f "$OUT/$nm/summary.json" ] || "$CPU" --data "$D" --method "$m" --iters "$ITERS" --seed "$sd" --report-every "$ITERS" --out "$OUT/$nm" "$@" > "$OUT/$nm.log" 2>&1
}
[ -f "$OUT/quality.csv" ] || echo "run,method,P,fft,seed,trustworthiness,knn_recall,label_purity,final_kl,loop_seconds" > "$OUT/quality.csv"
score() {  # name method P fft seed
  local nm=$1 m=$2 P=$3 fft=$4 sd=$5
  grep -q "^$nm," "$OUT/quality.csv" && return 0
  "$TOOLS" eval --feat "$F" --data "$D" --emb "$OUT/$nm/embedding.bin" --sample "$SAMPLE" --json "$OUT/$nm/quality.json" > /dev/null
  echo "$nm,$m,$P,$fft,$sd,$(jv "$OUT/$nm/quality.json" trustworthiness),$(jv "$OUT/$nm/quality.json" knn_recall),$(jv "$OUT/$nm/quality.json" label_purity),$(fkl "$nm"),$(jv "$OUT/$nm/summary.json" loop_seconds)" >> "$OUT/quality.csv"
}
echo "== Part 2: full runs (N=$N, $ITERS iterations, seeds: $SEEDS)"
for sd in $SEEDS; do
  run_serial exact_full_s$sd exact $sd;  score exact_full_s$sd exact 1 - $sd
  run_serial fast_full_s$sd  fast  $sd;  score fast_full_s$sd  fast  1 - $sd
  if [ -n "$PS" ] && [ -x "$MPIBIN" ]; then
    for p in $PS; do for fft in replicated distributed; do
      nm=mpi_P${p}_${fft}_s$sd
      [ -f "$OUT/$nm/summary.json" ] || $LAUNCH "$p" "$MPIBIN" --data "$D" --iters "$ITERS" --seed "$sd" --report-every 0 --fft "$fft" \
          --exchange ghost --comm blocking --grid-comm blocking --out "$OUT/$nm" > "$OUT/$nm.log" 2>&1 || { echo "FAILED $nm"; continue; }
      score "$nm" mpi "$p" "$fft" "$sd"
    done; done
  fi
done
# mean +- std over seeds per (method,P,fft)
awk -F, 'NR>1 {k=$2","$3","$4; n[k]++; for(c=6;c<=9;c++){s[k,c]+=$c; q[k,c]+=$c*$c}}
  END {for(k in n){line=k","n[k]; for(c=6;c<=9;c++){m=s[k,c]/n[k]; v=(n[k]>1)?sqrt((q[k,c]-n[k]*m*m)/(n[k]-1)):0; line=line sprintf(",%.5f,%.5f",m,v)}; print line}}' \
  "$OUT/quality.csv" | sort > "$OUT/quality_summary.body"
{ echo "method,P,fft,n_seeds,trust_mean,trust_std,knn_mean,knn_std,purity_mean,purity_std,kl_mean,kl_std"; cat "$OUT/quality_summary.body"; } > "$OUT/quality_summary.csv"; rm -f "$OUT/quality_summary.body"

echo "== Part 1: gradient errors vs the exact gradient (N=$N)"
for it in 50 250; do
  [ -f "$OUT/exact_it$it/embedding.bin" ] || "$CPU" --data "$D" --method exact --iters "$it" --seed "$SEED1" --report-every 0 --out "$OUT/exact_it$it" > "$OUT/exact_it$it.log" 2>&1
done
CSV=$OUT/grad_errors.csv; echo "coords,candidate,rel_Z,rel_attr,rel_rep,rel_grad" > "$CSV"
cmp_grad() {  # outcsv coordsname candname
  local csv=$1 cn=$2 cand=$3
  local line; line=$("$TOOLS" compare-grad "$OUT/g_${cn}_exact/grad.bin" "$OUT/g_${cn}_$cand/grad.bin" | tr '\n' ' ')
  local z a r g
  z=$(echo "$line" | sed -n 's/.*rel(Z)=\([^ ]*\).*/\1/p'); a=$(echo "$line" | sed -n 's/.*attr=\([^ ]*\) .*/\1/p')
  r=$(echo "$line" | sed -n 's/.*rep=\([^ ]*\) .*/\1/p'); g=$(echo "$line" | sed -n 's/.*grad=\([^ ]*\) .*/\1/p')
  echo "$cn,$cand,$z,$a,$r,$g" >> "$csv"; echo "  $cn  $cand: Z $z  attr $a  rep $r  grad $g"
}
for cn in it50 it250 final; do
  case $cn in it50) cf=$OUT/exact_it50/embedding.bin;; it250) cf=$OUT/exact_it250/embedding.bin;; final) cf=$OUT/exact_full_s$SEED1/embedding.bin;; esac
  "$CPU" --data "$D" --method exact --mode grad --coords "$cf" --out "$OUT/g_${cn}_exact" > /dev/null
  "$CPU" --data "$D" --method fast  --mode grad --coords "$cf" --out "$OUT/g_${cn}_fast_adaptive" > /dev/null; cmp_grad "$CSV" $cn fast_adaptive
  for nb in $BOXLIST; do
    "$CPU" --data "$D" --method fast --mode grad --coords "$cf" --grid-mode fixed --fixed-boxes $nb --out "$OUT/g_${cn}_fast_fixed$nb" > /dev/null; cmp_grad "$CSV" $cn fast_fixed$nb
  done
  for op in $ORDERS; do
    "$CPU" --data "$D" --method fast --mode grad --coords "$cf" --grid-mode fixed --fixed-boxes 128 --order-p $op --out "$OUT/g_${cn}_fast_fixed128_p$op" > /dev/null; cmp_grad "$CSV" $cn fast_fixed128_p$op
  done
  if [ -n "$PS" ] && [ -x "$MPIBIN" ]; then
    for p in $PS; do for fft in replicated distributed; do
      $LAUNCH "$p" "$MPIBIN" --data "$D" --mode grad --coords "$cf" --fft "$fft" --out "$OUT/g_${cn}_mpi_P${p}_$fft" > /dev/null 2>&1 || { echo "FAILED mpi P=$p $fft"; continue; }
      cmp_grad "$CSV" $cn mpi_P${p}_$fft
    done; done
  fi
done

echo "== Part 3: gradient error vs N"
GCSV=$OUT/gradN_errors.csv; echo "N,candidate,rel_Z,rel_attr,rel_rep,rel_grad" > "$GCSV"
for n in $GRADN; do
  nm=g$n; PREP=${PREP:-cpu} implementation/scripts/prepare.sh synthetic "$nm" "$n" 50 20 6 90 > /dev/null
  d=data/$nm.ds.bin; w=$OUT/gradN_$n; mkdir -p "$w"
  [ -f "$w/run/embedding.bin" ] || "$CPU" --data "$d" --method fast --iters 250 --seed 1 --report-every 0 --out "$w/run" > "$w/run.log" 2>&1
  "$CPU" --data "$d" --method exact --mode grad --coords "$w/run/embedding.bin" --out "$w/g_exact" > /dev/null
  "$CPU" --data "$d" --method fast --mode grad --coords "$w/run/embedding.bin" --out "$w/g_fast_adaptive" > /dev/null
  "$CPU" --data "$d" --method fast --mode grad --coords "$w/run/embedding.bin" --grid-mode fixed --fixed-boxes 128 --out "$w/g_fast_fixed128" > /dev/null
  for cand in fast_adaptive fast_fixed128; do
    line=$("$TOOLS" compare-grad "$w/g_exact/grad.bin" "$w/g_$cand/grad.bin" | tr '\n' ' ')
    z=$(echo "$line" | sed -n 's/.*rel(Z)=\([^ ]*\).*/\1/p'); a=$(echo "$line" | sed -n 's/.*attr=\([^ ]*\) .*/\1/p')
    r=$(echo "$line" | sed -n 's/.*rep=\([^ ]*\) .*/\1/p'); g=$(echo "$line" | sed -n 's/.*grad=\([^ ]*\) .*/\1/p')
    echo "$n,$cand,$z,$a,$r,$g" >> "$GCSV"; echo "  N=$n $cand: grad $g"
  done
done
echo; echo "== quality (mean +- std over seeds)"; column -s, -t "$OUT/quality_summary.csv" 2>/dev/null || cat "$OUT/quality_summary.csv"
echo "== gradient errors"; column -s, -t "$CSV" 2>/dev/null || cat "$CSV"
echo "== gradient error vs N"; column -s, -t "$GCSV" 2>/dev/null || cat "$GCSV"
)

# ==============================================================================================================
# official: comparison with the official FIt-SNE (O1, Fig. R9)
# ==============================================================================================================
# Study official — our FIt-SNE (serial + MPI) against the OFFICIAL KlugerLab FIt-SNE on the same data, same node.
#   DATA="ts50k g50k" CONFIGS="matched default" SEEDS="1 2 3" THREADS="1 8 36 72" MPI_PS="8 36 72" ITERS=1000 implementation/scripts/cpu_studies.sh official
# configs: matched = exact kNN (vp-tree), no step clipping, learning rate = official max(200,N/12) (= our max(50,N/48)), and OUR box width BW=1.0 / order 3 (official intervals_per_integer=1, nterms=3)
#          default = official defaults (Annoy kNN, step clipping 5)
# OURS_SERIAL=0 skips our serial runs (use in the multi-core job); BW=0.5 reproduces our own default grid.
# Metrics: optimisation-loop seconds (official: sum of the "50 iterations in X seconds" lines; ours: loop_seconds); trustworthiness / kNN recall /
# label purity (tsne_tools eval, same sample); KL(P_ours || Q) of the final embedding computed by OUR code (tsne_cpu --mode kl, exact sum) for every
# implementation, so that the numbers are comparable although the official P differs (Annoy/own calibration).
# Output: $RES/official_compare/results.csv. Restartable (a row that exists is skipped). Needs tsne_cpu, tsne_mpi_cpu, tsne_tools, FIt-SNE-master/bin/fast_tsne.
study_official() (
set -u
DATA=${DATA:-"ts50k"}; CONFIGS=${CONFIGS:-"matched default"}; SEEDS=${SEEDS:-"1 2 3"}; THREADS=${THREADS:-"1 8 36 72"}; MPI_PS=${MPI_PS:-"8 36 72"}
ITERS=${ITERS:-1000}; SAMPLE=${SAMPLE:-2000}; RES=${RES:-results_official}; BOXES=${BOXES:-}; SKIP_OURS=${SKIP_OURS:-0}; OURS_SERIAL=${OURS_SERIAL:-1}; BW=${BW:-1.0}   # BW: our box width (official intervals_per_integer=1 -> 1.0; our own default is 0.5)
for v in DATA CONFIGS SEEDS THREADS MPI_PS; do eval "$v=\${$v//_/ }"; done
[ "$MPI_PS" = none ] && MPI_PS=""      # MPI_PS=none: no MPI runs of our program (e.g. in a 1-core job); an empty value would be lost in `qsub -v`
OFF=${OFF:-$PWD/../FIt-SNE-master}; [ -x "$OFF/bin/fast_tsne" ] || OFF=$HOME/tsne/FIt-SNE-master
[ -f "$OFF/bin/fftw_env.sh" ] && . "$OFF/bin/fftw_env.sh"
OUT=$RES/official_compare; mkdir -p "$OUT"; CSV=$OUT/results.csv
[ -f "$CSV" ] || echo "data,impl,config,threads_or_P,seed,loop_seconds,wall_seconds,trust,knn_recall,purity,kl_common" > "$CSV"
jv() { tr -d ' \n' < "$1" | sed -n "s/.*\"$2\":\([-0-9.eE+]*\).*/\1/p"; }
LAUNCH=${LAUNCH:-mpirun --bind-to core --map-by core -np}
score() {  # key data dir  -> prints "trust,knn,purity,kl"
  local d=$1 dir=$2 D=data/$1.ds.bin F=data/$1.feat.bin
  "$TOOLS" eval --feat "$F" --data "$D" --emb "$dir/embedding.bin" --sample "$SAMPLE" --json "$dir/quality.json" > /dev/null 2>&1
  local m=exact; "$CPU" --data "$D" --method $m --mode kl --coords "$dir/embedding.bin" --out "$dir/kl" > "$dir/kl.log" 2>&1
  echo "$(jv "$dir/quality.json" trustworthiness),$(jv "$dir/quality.json" knn_recall),$(jv "$dir/quality.json" label_purity),$(jv "$dir/kl/kl_eval.json" kl)"
}
have() { grep -q "^$1," "$CSV"; }
for d in $DATA; do
  if [ ! -f data/$d.ds.bin ]; then case $d in g*k) n=${d#g}; n=${n%k}; PREP=cpu implementation/scripts/prepare.sh synthetic "$d" $(( n * 1000 )) 50 20 6 90;; *) echo "missing data/$d.ds.bin"; continue;; esac; fi
  N=$(od -An -t d8 -j8 -N8 data/$d.feat.bin 2>/dev/null | tr -d ' '); [ -z "$N" ] && N=50000
  for cfg in $CONFIGS; do
    # The official code drops the factor 4 of the gradient, so ITS learning rate max(200,N/12) is the same step as OUR max(50,N/48): both configs use the official value.
    LR=$(awk -v n="$N" 'BEGIN{x=n/12; if(x<200)x=200; printf "%d", x}')
    if [ "$cfg" = matched ]; then KNN=vptree; MS=-1; else KNN=annoy; MS=5; fi
    for sd in $SEEDS; do
      # ---------- official
      if [ -d "$OFF" ]; then
        for nt in $THREADS; do
          key="$d,official,$cfg,$nt,$sd"; have "$key," && continue
          dir=$OUT/${d}_official_${cfg}_t${nt}_s$sd; mkdir -p "$dir"
          "$TOOLS" fitsne-io to-fitsne --feat data/$d.feat.bin --out "$dir/data.dat" --iters "$ITERS" --lr "$LR" --knn "$KNN" --max-step "$MS" --seed "$sd" > "$dir/io.log" 2>&1 || { echo "FAILED to-fitsne $key"; continue; }
          t0=$(date +%s.%N)
          ( cd "$dir" && "$OFF/bin/fast_tsne" 1.2.1 data.dat result.dat "$nt" ) > "$dir/run.log" 2>&1 || { echo "FAILED official $key"; continue; }
          wall=$(awk -v a="$t0" -v b="$(date +%s.%N)" 'BEGIN{printf "%.3f", b-a}')
          loop=$(grep -o "in [0-9.]* seconds" "$dir/run.log" | awk '{s+=$2} END{printf "%.3f", s}')
          "$TOOLS" fitsne-io from-fitsne --result "$dir/result.dat" --out "$dir/embedding.bin" >> "$dir/io.log" 2>&1 || { echo "FAILED from-fitsne $key"; continue; }
          echo "$key,$loop,$wall,$(score $d $dir)" >> "$CSV"; echo "done $key loop=$loop"
          rm -f "$dir/data.dat"
        done
      fi
      [ "$SKIP_OURS" = 1 ] && continue
      [ "$cfg" = default ] && [ "${OURS_ONCE:-1}" = 1 ] && continue   # ours has one setting; run it under 'matched' only
      # ---------- ours, serial
      key="$d,ours_serial,$cfg,1,$sd"
      if [ "$OURS_SERIAL" = 1 ] && ! have "$key,"; then
        dir=$OUT/${d}_ours_serial_s$sd; mkdir -p "$dir"
        OMP_NUM_THREADS=1 "$CPU" --data data/$d.ds.bin --method fast --iters "$ITERS" --seed "$sd" --report-every 0 --bw "$BW" --order-p 3 --out "$dir" > "$dir/run.log" 2>&1 \
          && echo "$key,$(jv $dir/summary.json loop_seconds),$(jv $dir/summary.json loop_seconds),$(score $d $dir)" >> "$CSV" && echo "done $key"
      fi
      # ---------- ours, MPI (distributed FFT, ghost exchange, adaptive grid)
      for p in $MPI_PS; do
        key="$d,ours_mpi,$cfg,$p,$sd"; have "$key," && continue
        dir=$OUT/${d}_ours_mpi_P${p}_s$sd; mkdir -p "$dir"
        $LAUNCH "$p" "$MPI_CPU" --data data/$d.ds.bin --iters "$ITERS" --seed "$sd" --report-every 0 --fft distributed --exchange ghost --bw "$BW" --order-p 3 --out "$dir" > "$dir/run.log" 2>&1 \
          && echo "$key,$(jv $dir/summary.json loop_seconds),$(jv $dir/summary.json loop_seconds),$(score $d $dir)" >> "$CSV" && echo "done $key"
      done
    done
  done
done
echo "== summary (mean over seeds)"
awk -F, 'NR>1 {k=$1","$2","$3","$4; n[k]++; for(c=6;c<=11;c++) s[k,c]+=$c} END{for(k in n){printf "%s n=%d",k,n[k]; for(c=6;c<=11;c++) printf ",%.4g", s[k,c]/n[k]; print ""}}' "$CSV" | sort
)

# ==============================================================================================================
# klgap: KL-gap ablation at N = 10k (K1, Fig. R12)
# ==============================================================================================================
# Study klgap -- why is OUR final KL 1.5-4 % above the official FIt-SNE's (same data, same learning rate, same kNN)?  Ablation at N=10k, ONE core, so that
# the exact O(N^2) t-SNE can be run as a reference. The KL of every embedding is computed by the same exact code (tsne_cpu --mode kl).
#   Hypotheses:  (a) our interpolation is coarser  -> a finer grid (bw 0.5) / higher order (p=5) lowers our KL towards the official one;
#                (b) our optimiser is slower to converge -> 2000 iterations lowers it;  (c) both converge to a similar optimum, the gap is seed noise -> see the seed spread.
# Variables: DATA="g10000" (ts10k is skipped if data/ts10k.* does not exist), SEEDS="1 2 3", ITERS=1000, LONG=2000, SAMPLE=2000, RES=results_klgap, VARIANTS="official ours ours_bw05 ours_p5 ours_bw05_p5 exact ours_long official_long"
# Output: $RES/klgap.csv  data,variant,seed,iters,loop_seconds,trust,knn_recall,purity,kl_common      (restartable)
study_klgap() (
set -u
DATA=${DATA:-g10000}; SEEDS=${SEEDS:-"1 2 3"}; ITERS=${ITERS:-1000}; LONG=${LONG:-2000}; SAMPLE=${SAMPLE:-2000}; RES=${RES:-results_klgap}
VARIANTS=${VARIANTS:-"official ours ours_bw05 ours_p5 ours_bw05_p5 exact ours_long official_long"}
for v in DATA SEEDS; do eval "$v=\${$v//_/ }"; done
VARIANTS=${VARIANTS//+/ }   # variants contain "_" -> in -v lists separate them with "+": VARIANTS=official+ours+exact
export OMP_NUM_THREADS=1
OFF=${OFF:-$PWD/../FIt-SNE-master}; [ -x "$OFF/bin/fast_tsne" ] || OFF=$HOME/tsne/FIt-SNE-master
[ -f "$OFF/bin/fftw_env.sh" ] && . "$OFF/bin/fftw_env.sh"
mkdir -p "$RES"; CSV=$RES/klgap.csv
[ -f "$CSV" ] || echo "data,variant,seed,iters,loop_seconds,trust,knn_recall,purity,kl_common" > "$CSV"
jv() { tr -d ' \n' < "$1" | sed -n "s/.*\"$2\":\([-0-9.eE+]*\).*/\1/p"; }
score() {  # data dir
  local d=$1 dir=$2
  "$TOOLS" eval --feat data/$d.feat.bin --data data/$d.ds.bin --emb "$dir/embedding.bin" --sample "$SAMPLE" --json "$dir/quality.json" > /dev/null 2>&1
  "$CPU" --data data/$d.ds.bin --method exact --mode kl --coords "$dir/embedding.bin" --out "$dir/kl" > "$dir/kl.log" 2>&1
  echo "$(jv "$dir/quality.json" trustworthiness),$(jv "$dir/quality.json" knn_recall),$(jv "$dir/quality.json" label_purity),$(jv "$dir/kl/kl_eval.json" kl)"
}
for d in $DATA; do
  [ -f data/$d.ds.bin ] && [ -f data/$d.feat.bin ] || { case $d in g*) n=${d#g}; PREP=cpu implementation/scripts/prepare.sh synthetic "$d" "$n" 50 20 6 90;; *) echo "missing data/$d.*  -> skipped"; continue;; esac; }
  N=$(od -An -t d8 -j8 -N8 data/$d.feat.bin 2>/dev/null | tr -d ' '); [ -z "$N" ] && N=10000
  LR=$(awk -v n="$N" 'BEGIN{x=n/12; if(x<200)x=200; printf "%d", x}')       # official unit (= ours N/48, see study official)
  for v in $VARIANTS; do
    for sd in $SEEDS; do
      it=$ITERS; case $v in *_long) it=$LONG;; esac
      key="$d,$v,$sd,$it,"; grep -q "^$key" "$CSV" && continue
      dir=$RES/${d}_${v}_s$sd; mkdir -p "$dir"
      case $v in
        official|official_long)
          "$TOOLS" fitsne-io to-fitsne --feat data/$d.feat.bin --out "$dir/data.dat" --iters "$it" --lr "$LR" --knn vptree --max-step -1 --seed "$sd" > "$dir/io.log" 2>&1 || { echo "FAILED to-fitsne $v"; continue; }
          ( cd "$dir" && "$OFF/bin/fast_tsne" 1.2.1 data.dat result.dat 1 ) > "$dir/run.log" 2>&1 || { echo "FAILED official $v $sd"; continue; }
          loop=$(grep -o "in [0-9.]* seconds" "$dir/run.log" | awk '{s+=$2} END{printf "%.3f", s}')
          "$TOOLS" fitsne-io from-fitsne --result "$dir/result.dat" --out "$dir/embedding.bin" >> "$dir/io.log" 2>&1 || { echo "FAILED from-fitsne"; continue; }
          rm -f "$dir/data.dat" ;;
        *)
          case $v in
            ours|ours_long)   opt="--method fast --bw 1.0 --order-p 3" ;;
            ours_bw05)        opt="--method fast --bw 0.5 --order-p 3" ;;
            ours_p5)          opt="--method fast --bw 1.0 --order-p 5" ;;
            ours_bw05_p5)     opt="--method fast --bw 0.5 --order-p 5" ;;
            exact)            opt="--method exact" ;;
            *) echo "unknown variant $v"; continue ;;
          esac
          "$CPU" --data data/$d.ds.bin $opt --iters "$it" --seed "$sd" --report-every 0 --out "$dir" > "$dir/run.log" 2>&1 || { echo "FAILED $v $sd"; continue; }
          loop=$(jv "$dir/summary.json" loop_seconds) ;;
      esac
      echo "$key$loop,$(score $d $dir)" >> "$CSV"; tail -1 "$CSV"
    done
  done
done
echo; echo "mean +- std of kl_common over seeds:"
awk -F, 'NR>1 {k=$1","$2; n[k]++; s[k]+=$9; q[k]+=$9*$9} END{for(k in n){m=s[k]/n[k]; v=(n[k]>1)?sqrt((q[k]-n[k]*m*m)/(n[k]-1)):0; printf "%-28s n=%d kl=%.4f +- %.4f\n",k,n[k],m,v}}' "$CSV" | sort
)

# ===========================================================================================================================================
# serial_all: the serial studies with the settings of the report
# ===========================================================================================================================================
# Expected time on one Vanda core: base ~1.6 h, grid ~0.7 h, npts ~0.2 h, nscale ~0.7 h, exact ~0.3 h.
study_serial_all() (
  S=${SERIAL_STUDIES:-"base grid npts nscale exact"}; S=${S//_/ }; S=${S//+/ }
  has() { case " $S " in *" $1 "*) return 0;; esac; return 1; }
  has base   && STUDY=base   BOXES="512 400 200" NAMES="g250k" ITERS=300 REPS=3 study_serial_scaling
  has grid   && STUDY=grid   NAME=g100k BOXES="50 75 100 150 200 300 400 600" ITERS=40 REPS=3 study_serial_scaling
  has npts   && STUDY=npts   BOXES=200 NAMES="g100k g250k g500k g1m" ITERS=40 REPS=3 study_serial_scaling
  has nscale && STUDY=nscale NAMES="g10000 g20000 g40000 g80000 g160000 g320000 g640000 g1280000" N0_BOXES=40 NPR=10000 ITERS=40 REPS=3 study_serial_scaling
  has exact  && STUDY=exact  NSIZES="1000 2000 4000 8000" ITERS=30 REPS=3 study_serial_scaling
  echo "serial-all done"
)

# ===========================================================================================================================================
# dispatcher
# ===========================================================================================================================================
CMDS="$*"; [ -z "$CMDS" ] && CMDS="${CMD:?usage: cpu_studies.sh COMMAND ...  (see the header of this file)}"
CMDS=${CMDS//+/ }
for c in $CMDS; do
  echo "=================== $c"
  case $c in
    serial-base|serial-grid|serial-npts|serial-nscale|serial-knn|serial-exact)
      # the study name is the part after "serial-"; variables NAME(S), BOXES, ... come from the environment
      STUDY=${c#serial-} study_serial_scaling ;;
    serial-all)  study_serial_all ;;
    crossover)   study_serial_crossover ;;
    pcost)       study_pcost ;;
    validation)  study_validation ;;
    official)    study_official ;;
    klgap)       study_klgap ;;
    *) echo "unknown command $c"; exit 2 ;;
  esac
done
