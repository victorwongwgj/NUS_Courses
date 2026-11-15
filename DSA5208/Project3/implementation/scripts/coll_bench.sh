#!/usr/bin/env bash
# coll_bench.sh -- collective micro-benchmark (src/coll_bench.cpp) for the (P, ranks per node) layouts of the report.
# Run it inside a CPU job:  qsub ... -v SCRIPT=implementation/scripts/coll_bench.sh,LAYOUTS=16:16_64:64_128:64_256:64_256:72_512:64_512:72,RES=results_coll implementation/jobs/vanda_cpu.pbs
# Variables: LAYOUTS (P:K = ranks, ranks per node; '_' separates items), COLL_BOXES (grid sizes, space separated; default 400), REPS (calls per collective, 30).
set -u
cd "$(dirname "$0")/../.."; mkdir -p build
make build/coll_bench MPICXX=${MPICXX:-mpicxx} || exit 3
OUT=${RES:-results_coll}; mkdir -p "$OUT"
LAYOUTS=${LAYOUTS:-"16:16 64:64 128:64 256:64 256:72 512:64 512:72"}; LAYOUTS=${LAYOUTS//_/ }
for B in ${COLL_BOXES:-400}; do
  for lay in $LAYOUTS; do
    P=${lay%%:*}; K=${lay##*:}
    mpirun --bind-to core --map-by ppr:"$K":node -np "$P" build/coll_bench "$B" 3 "${REPS:-30}" > "$OUT/coll_b${B}_P${P}_K${K}.csv" 2> "$OUT/coll_b${B}_P${P}_K${K}.err" \
      || echo "FAILED b=$B P=$P K=$K"
  done
done
cat "$OUT"/coll_b*_P*_K*.csv | awk -F, 'NR==1||$1!="P"' > "$OUT/coll_all.csv"
