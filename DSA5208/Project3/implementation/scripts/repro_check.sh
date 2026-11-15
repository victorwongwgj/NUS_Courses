#!/usr/bin/env bash
# repro_check.sh -- are repeated runs of the SAME configuration bitwise identical?  (Lecture 8: floating-point sums are not associative; on the GPU the
# atomic additions of the spread kernel add in a varying order.)  Three runs with the same seed; the embeddings are compared byte by byte.
#   CPU job:  qsub -l select=1:ncpus=72:mpiprocs=72:mem=200gb -l place=pack:excl -l walltime=00:30:00 \
#                  -v SCRIPT=implementation/scripts/repro_check.sh,TARGET=cpu,P=4,RES=results_repro_cpu implementation/jobs/vanda_cpu.pbs
#   GPU job:  qsub -l select=1:ncpus=16:ngpus=2:mem=100gb -l walltime=00:30:00 -v SCRIPT=implementation/scripts/repro_check.sh,TARGET=gpu,P=1_2,RES=results_repro_gpu implementation/jobs/vanda_gpu.pbs
# Variables: TARGET (cpu|gpu), P (rank counts, '_' separated), DATA (default data/g10000.ds.bin), ITERS (200), RES.
set -u
cd "$(dirname "$0")/../.."
TARGET=${TARGET:-cpu}; BIN=build/tsne_mpi_cpu; EXTRA="--fft distributed --grid-mode fixed --fixed-boxes 128"
[ "$TARGET" = gpu ] && { BIN=build/tsne_gpu; EXTRA="--grid-mode fixed --fixed-boxes 128"; }
DATA=${DATA:-data/g10000.ds.bin}; ITERS=${ITERS:-200}; OUT=${RES:-results_repro}; mkdir -p "$OUT"
BINDOPT="--bind-to core"; [ "$TARGET" = gpu ] && BINDOPT=""; case "${MODULES:-}" in *hpcx*) BINDOPT="--bind-to none";; esac   # MODULES must be exported (qsub -v MODULES=...) for the HPC-X case
echo "target=$TARGET data=$DATA iters=$ITERS" > "$OUT/repro.txt"
for P in ${P//_/ }; do
  for r in 1 2 3; do
    mpirun $BINDOPT -np "$P" "$BIN" --data "$DATA" --perplexity 20 --iters "$ITERS" --seed 42 $EXTRA --out "$OUT/P${P}_r$r" > "$OUT/P${P}_r$r.log" 2>&1
  done
  for r in 2 3; do
    n=$(cmp -l "$OUT/P${P}_r1/embedding.bin" "$OUT/P${P}_r$r/embedding.bin" 2>&1 | wc -l)
    echo "P=$P run1-vs-run$r differing bytes: $n" | tee -a "$OUT/repro.txt"
  done
done
