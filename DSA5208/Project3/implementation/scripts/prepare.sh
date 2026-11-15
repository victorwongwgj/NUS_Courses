#!/usr/bin/env bash
# prepare.sh -- data preparation and the one-off build of the official FIt-SNE (everything that is not an experiment).
#
#   implementation/scripts/prepare.sh synthetic NAME N [DIM=50] [CLUSTERS=20] [SPACING=6] [K=90] [SEED=1]
#         Gaussian-mixture data set data/NAME.{feat,labels,ds}.bin (features, labels, exact kNN graph with K neighbours).
#         The kNN graph is built by build/prep_gpu if it exists, otherwise by `tsne_tools prep-cpu` (O(N^2); fine up to ~1e5 points).
#         Force one with PREP=gpu|cpu.  Existing files are never overwritten.  SPACING: ~2 near / ~6 medium / ~12 far clustered (study C).
#   implementation/scripts/prepare.sh big
#         g100k, g250k, g500k, g1m, g1m_near, g1m_far (serial studies, strong scaling, GPU studies C/G; needs one GPU for prep_gpu).
#   implementation/scripts/prepare.sh weak          (env NPR=points per rank, PS=1_2_4_..., e.g. NPR=10000 PS=1_2_4_8_16_32_64_128)
#         One data set of N = NPR * P points for every P of the weak-scaling studies (names g<N>, or g100k / g250k / g500k / g1m).
#   implementation/scripts/prepare.sh real-knn      (env NAMES="ts10k ts50k ts200k ts")
#         Exact kNN graphs (k = 90) of the real data sets; needs data/<name>.feat.bin and data/<name>.labels.bin
#         (made once from the Tabula Sapiens .h5ad file by implementation/scripts/h5ad_to_bin.py).
#   implementation/scripts/prepare.sh official-build
#         Builds the OFFICIAL FIt-SNE (KlugerLab, directory ../FIt-SNE-master) into FIt-SNE-master/bin/fast_tsne for comparison O1/K1.
#         FFTW is searched in this order: system install, environment modules, ~/opt/fftw, source build of ~/fftw-3.3.10.tar.gz
#         (download it once from https://www.fftw.org/fftw-3.3.10.tar.gz).  Writes bin/fftw_env.sh, sourced by cpu_studies.sh.
#
# The sub-command can also be given as environment variable CMD (so that the script can be run through implementation/jobs/vanda_*.pbs with
# -v SCRIPT=implementation/scripts/prepare.sh,CMD=big).  Variables: BUILD (default build).
set -eu
cd "$(dirname "$0")/../.."
CMD=${1:-${CMD:?usage: prepare.sh synthetic|big|weak|real-knn|official-build ...}}
[ $# -gt 0 ] && shift
BUILD=${BUILD:-build}
TOOLS=$BUILD/tsne_tools

synthetic() {
  local NAME=${1:?name} N=${2:?number of points} DIM=${3:-50} CL=${4:-20} SP=${5:-6} K=${6:-90} SEED=${7:-1}
  mkdir -p data
  if [ ! -f "data/$NAME.feat.bin" ]; then
    "$TOOLS" gen-data --n "$N" --dim "$DIM" --clusters "$CL" --spacing "$SP" --seed "$SEED" --out "data/$NAME"
  fi
  if [ -f "data/$NAME.ds.bin" ]; then echo "data/$NAME.ds.bin exists, skipping kNN"; return 0; fi
  local PREPK=${PREP:-auto}
  if [ "$PREPK" = auto ]; then if [ -x "$BUILD/prep_gpu" ]; then PREPK=gpu; else PREPK=cpu; fi; fi
  echo "building kNN graph with prep_$PREPK (K=$K)"
  local T0; T0=$(date +%s)
  if [ "$PREPK" = gpu ]; then
    "$BUILD/prep_gpu" --feat "data/$NAME.feat.bin" --labels "data/$NAME.labels.bin" --k "$K" --out "data/$NAME.ds.bin"
  else
    "$TOOLS" prep-cpu --feat "data/$NAME.feat.bin" --labels "data/$NAME.labels.bin" --k "$K" --out "data/$NAME.ds.bin"
  fi
  echo "kNN preprocessing wall time: $(( $(date +%s) - T0 )) s (NOT part of any t-SNE timing)"
}

case $CMD in
  synthetic) synthetic "$@" ;;
  big)
    synthetic g100k     100000  50 20 6  90
    synthetic g250k     250000  50 20 6  90
    synthetic g500k     500000  50 20 6  90
    synthetic g1m      1000000  50 20 6  90
    synthetic g1m_near 1000000  50 20 2  90
    synthetic g1m_far  1000000  50 20 12 90
    ls -lh data/ ;;
  weak)
    NPR=${NPR:-5000}; PSL=${PS:-1_2_4_8_16_32_64_128}
    for p in ${PSL//_/ }; do
      n=$((NPR*p)); case $n in 100000) d=g100k;; 250000) d=g250k;; 500000) d=g500k;; 1000000) d=g1m;; *) d=g$n;; esac
      PREP=${PREP:-gpu} synthetic "$d" "$n" 50 20 6 90
    done
    ls -lh data | tail -20 ;;
  real-knn)
    NAMES="${NAMES:-ts10k ts50k ts200k ts}"; NAMES=${NAMES//_/ }      # small first: a problem shows up early and cheaply
    for d in $NAMES; do
      if [ -f data/$d.ds.bin ]; then echo "skip $d (data/$d.ds.bin exists)"; continue; fi
      [ -f data/$d.feat.bin ] && [ -f data/$d.labels.bin ] || { echo "missing data/$d.feat.bin or data/$d.labels.bin" >&2; exit 1; }
      echo "== kNN $d  $(date -Is)"
      "$BUILD/prep_gpu" --feat data/$d.feat.bin --labels data/$d.labels.bin --k 90 --out data/$d.ds.bin
    done
    ls -lh data/*.ds.bin ;;
  official-build)
    OFF=$PWD/../FIt-SNE-master; [ -d "$OFF" ] || OFF=$HOME/tsne/FIt-SNE-master
    [ -d "$OFF" ] || { echo "FATAL: FIt-SNE-master not found (expected next to this directory)"; exit 2; }
    ENVF=$OFF/bin/fftw_env.sh; mkdir -p "$OFF/bin"; : > "$ENVF"
    try_build() {  # $1 = extra compiler flags, $2 = extra linker flags
      ( cd "$OFF" && g++ -std=c++11 -O3 $1 src/sptree.cpp src/tsne.cpp src/nbodyfft.cpp -o bin/fast_tsne -pthread $2 -lfftw3 -lm -Wno-address-of-packed-member ) && [ -x "$OFF/bin/fast_tsne" ]
    }
    ok=0
    if try_build "" ""; then ok=1; echo "system fftw works"; fi                                           # 1. system FFTW
    if [ $ok = 0 ] && command -v module >/dev/null 2>&1; then                                              # 2. environment modules
      for m in $(module avail -t 2>&1 | grep -i fftw | tr -d ' ' | sed 's/(default)//'); do
        module load "$m" 2>/dev/null || continue
        inc=""; lib=""
        for v in FFTW_ROOT FFTW_DIR FFTW3_ROOT FFTW_HOME EBROOTFFTW; do [ -n "${!v:-}" ] && { inc="-I${!v}/include"; lib="-L${!v}/lib -Wl,-rpath,${!v}/lib"; break; }; done
        if try_build "$inc" "$lib"; then ok=1; echo "module load $m" > "$ENVF"; echo "built with module $m"; break; fi
        module unload "$m" 2>/dev/null || true
      done
    fi
    if [ $ok = 0 ] && [ -f "$HOME/opt/fftw/lib/libfftw3.so" -o -f "$HOME/opt/fftw/lib/libfftw3.a" ]; then   # 3. ~/opt/fftw
      try_build "-I$HOME/opt/fftw/include" "-L$HOME/opt/fftw/lib -Wl,-rpath,$HOME/opt/fftw/lib" && ok=1 && echo "export LD_LIBRARY_PATH=$HOME/opt/fftw/lib:\${LD_LIBRARY_PATH:-}" > "$ENVF"
    fi
    if [ $ok = 0 ]; then                                                                                    # 4. FFTW source build
      T=$HOME/fftw-3.3.10.tar.gz
      [ -f "$T" ] || curl -fsSL -o "$T" https://www.fftw.org/fftw-3.3.10.tar.gz || true
      if [ -s "$T" ]; then
        W=$(mktemp -d); tar -xzf "$T" -C "$W"
        ( cd "$W"/fftw-3.3.10 && ./configure --prefix="$HOME/opt/fftw" --enable-shared --enable-sse2 --enable-avx2 && make -j4 && make install )
        try_build "-I$HOME/opt/fftw/include" "-L$HOME/opt/fftw/lib -Wl,-rpath,$HOME/opt/fftw/lib" && ok=1 && echo "export LD_LIBRARY_PATH=$HOME/opt/fftw/lib:\${LD_LIBRARY_PATH:-}" > "$ENVF"
      fi
    fi
    [ $ok = 1 ] || { echo "FATAL: could not build the official FIt-SNE (no FFTW). Put fftw-3.3.10.tar.gz in your home and retry."; exit 3; }
    . "$ENVF"; ldd "$OFF/bin/fast_tsne" | grep -i fftw
    # smoke test: 3000 points, 250 iterations, 2 threads, through our converters
    synthetic smoke3k 3000 50 20 6 90
    W=$PWD/results_official/smoke; mkdir -p "$W"
    "$TOOLS" fitsne-io to-fitsne --feat data/smoke3k.feat.bin --out "$W/data.dat" --iters 250 --knn annoy
    ( cd "$W" && "$OFF/bin/fast_tsne" 1.2.1 data.dat result.dat 2 ) 2>&1 | tail -8
    "$TOOLS" fitsne-io from-fitsne --result "$W/result.dat" --out "$W/embedding.bin"
    "$TOOLS" eval --feat data/smoke3k.feat.bin --data data/smoke3k.ds.bin --emb "$W/embedding.bin" --sample 2000 --json "$W/quality.json"; cat "$W/quality.json"
    echo "OFFICIAL BUILD + SMOKE TEST OK" ;;
  *) echo "unknown sub-command $CMD"; exit 2 ;;
esac
