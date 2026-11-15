# Parallel FIt-SNE with MPI+CUDA

Code, raw results and analysis notebooks behind the report of DSA5208 Project 3. All commands are run from the repository root.

## 1. Reproducing the experiments

**Step 1 -- build** (on Vanda the PBS scripts also build what they need)

```
make cpu          # build/tsne_tools, build/tsne_cpu                              g++ (OMP=1: OpenMP in the tools)
make cpumpi       # build/tsne_mpi_cpu, build/microbench_cpu, build/coll_bench    mpicxx
make gpu          # build/tsne_gpu, build/prep_gpu, build/microbench              nvcc + MPI (REAL=float -> build/tsne_gpu_float)
```

**Step 2 -- data** (deterministic, seed 1; written to `data/NAME.{feat,labels,ds}.bin`, ds = symmetric kNN graph with k = 90)

| Data | Command | Used by |
|---|---|---|
| g100k, g250k, g500k, g1m (+ g1m_near, g1m_far) | `implementation/scripts/prepare.sh big` | serial, strong scaling, GPU |
| g10000 ... g1280000 (10 000 points per rank) | `NPR=10000 PS=1_2_4_8_16_32_64_128 implementation/scripts/prepare.sh weak` | serial N-scaling, weak scaling |
| g5000 ... g2560000 (5 000 points per rank) | `NPR=5000 PS=1_16_64_128_256_512 implementation/scripts/prepare.sh weak` | weak scaling to 256 / 512 cores |
| any single set | `implementation/scripts/prepare.sh synthetic NAME N [DIM CLUSTERS SPACING K SEED]` | custom |
| Tabula Sapiens ts, ts200k, ts50k, ts10k | `python3 implementation/scripts/h5ad_to_bin.py tabula_sapiens.h5ad data/ts --pcs 50 --label-key cell_type` (+ `--subsample N --seed 1` for the subsets), then `implementation/scripts/prepare.sh real-knn` | real-data experiments |
| official FIt-SNE binary | `implementation/scripts/prepare.sh official-build` | official comparison (O1, K1) |

Smaller sets (g20000, g50k, ...) are created on demand by the experiment scripts. `implementation/scripts/submit_all.sh data` prints the PBS jobs that do all of the above (the kNN graphs of the large sets need a GPU).

**Step 3 -- submit the jobs.** `submit_all.sh` is the catalogue of every job of the report as a `qsub` line (resources, walltime, parameters, `RES=` result directory).

```
implementation/scripts/submit_all.sh                  # list the groups
implementation/scripts/submit_all.sh cpu-strong       # PRINT the qsub lines of a group (nothing is submitted)
export PROJECT=<your HPC project>                     # passed to qsub -P
SUBMIT=1 implementation/scripts/submit_all.sh data    # submit; wait until the data jobs have finished, then:
SUBMIT=1 implementation/scripts/submit_all.sh validation serial cpu-strong cpu-comm cpu-weak cpu-real gpu gpu-dist official diagnostics
```

| Group | Experiments | Report section |
|---|---|---|
| `data` | data sets and kNN graphs | -- |
| `serial` | serial anatomy, N / grid / k scans, crossover exact vs FFT, interpolation order | 4.3 |
| `validation` | exact-gradient validation, parallel-vs-serial gate (CPU, 1 and 2 nodes), quality against P | 4.1 |
| `cpu-strong` | strong scaling, replicated vs distributed FFT, 200 / 400 / 512 / 768 boxes, up to 512 ranks | 4.4 |
| `cpu-comm` | process placement, coordinate-exchange variants, grid-sum variants, collectives, ablations | 4.2, 4.4 |
| `cpu-weak` | weak scaling, 10k and 5k points per rank | 4.5 |
| `cpu-real` | real-data scaling on the CPU | 4.7 |
| `gpu` | one and two GPUs, adaptive grid, host-staged vs CUDA-aware transport, write conflicts, precision, real data | 4.6, 4.7 |
| `gpu-dist` | distributed FFT on the GPU: gate, time per iteration, grid scan, capacity, quality, one and two nodes | 4.6 |
| `official` | official FIt-SNE against ours, KL gap | 4.8 |
| `diagnostics` | bitwise reproducibility of repeated runs | -- |

Each job writes into its own `RES=` directory (e.g. `results_vcpu_E400_big/`). Example (strong scaling, 8 nodes, 250k points, 400 boxes):

```
qsub -N E400_big -l select=8:ncpus=72:mpiprocs=72:mem=200gb -l place=scatter:excl -l walltime=02:30:00 \
     -v STUDIES=E,PSLIST=1_2_4_8_16_32_64_128_256_512,N_STRONG=250000,EBOXES=400,EITERS=100,ROUNDS=3,E_REP_MAXP=64,RES=results_vcpu_E400_big implementation/jobs/vanda_cpu.pbs
```

A study can also be run without PBS on any machine with MPI: `BACKEND=cpu LAUNCH="mpirun -np" implementation/scripts/run_experiments.sh E` with the same variables (the header of `run_experiments.sh` lists all studies and variables; the options of each program are in the comment block at the top of its source file).

**Step 4 -- tables and figures.** Copy the result directories into `output/` (replacing the files; the raw results of the report are already there) and run the three notebooks in `implementation/analysis/` in this order, each top to bottom
(Jupyter *Run All*, or `jupyter nbconvert --to notebook --execute --inplace implementation/analysis/0*.ipynb`; about one minute, no cluster or GPU needed):

| Notebook | Output |
|---|---|
| `01_summary_tables.ipynb` | intermediate summary tables and LaTeX tables in `work/` (distributed FFT, collectives, grid sum, atomics, precision, quality, GPU stages, real data on the GPU, GPU MPI library, weak-scaling stages, CPU gate error terms) |
| `02_figures.ipynb` | `figures/*.png` (the 23 figures of the report) |
| `03_latex_tables.ipynb` | the remaining tables in `work/`, then `tables/*.csv`: one csv per table of the report (29 tables) and `tables/INDEX.csv` |

## 2. Requirements

| Component | Needs |
|---|---|
| Serial programs, tools | bash, g++ >= 9 (C++17) |
| `tsne_mpi_cpu`, `coll_bench`, `microbench_cpu` | MPI C++ wrapper (`mpicxx`); Vanda: `gcc11/11.5.0`, `openmpi/gcc/64/4.1.8` |
| `tsne_gpu`, `prep_gpu`, `microbench` | CUDA >= 12 with cuFFT (`cuda12.4/toolkit/12.4.1`), A40 = `ARCH=sm_86`; CUDA-aware transport: NVHPC HPC-X (`nvhpc-hpcx-cuda12/26.1`, Open MPI with UCX) |
| Notebooks | Python 3 with numpy, pandas, matplotlib, Jupyter; scipy only for the optional `REALQ = True` step of notebook 01 |
| Real data | Tabula Sapiens `.h5ad` file (external download); scanpy / anndata for `h5ad_to_bin.py` |
| Official comparison | KlugerLab FIt-SNE sources in `../FIt-SNE-master`, FFTW |
| Cluster | PBS (Vanda: 72-core CPU nodes, A40 GPU nodes); set `PROJECT=` for `submit_all.sh` (the `.pbs` files carry the placeholder `#PBS -P PROJECT_ID`) |

## 3. Layout

| Path | Content |
|---|---|
| `Makefile` | `make cpu`, `cpumpi`, `gpu`, `all`, `clean`; variables `CXX MPICXX NVCC ARCH REAL OMP BUILD` |
| `src/tsne_common.h` | shared header: data structures, own mixed-radix FFT, interpolation weights, grid / box set-up, partition, timers, JSON summary |
| `src/cuda_emu.h` | CPU emulation of the CUDA subset; only for `microbench_cpu` (CPU-cluster build of `microbench.cu`) |
| `src/core.cpp` | shared by all programs (not the gradient): file formats and I/O, PCA / PC1 ordering, perplexity calibration, symmetrised P |
| `src/tsne_cpu.cpp` | serial reference t-SNE / FIt-SNE, one core |
| `src/tsne_mpi_cpu.cpp` | pure-MPI CPU program: ghost / allgather exchange, grid-sum variants, replicated or distributed (pencil) FFT |
| `src/tsne_gpu.cu` | MPI+CUDA program: same options, GPU kernels, cuFFT, host-staged or CUDA-aware transport, float / double, distributed FFT |
| `src/prep_gpu.cu` | exact kNN graph (k = 90) on the GPU |
| `src/tools.cpp` | `tsne_tools`: gen-data, prep-cpu, eval (trustworthiness, kNN recall, purity, KL), compare-grad (correctness gate), fitsne-io |
| `src/microbench.cu`, `src/coll_bench.cpp` | platform micro-benchmarks (ping-pong, Allreduce, copies, FLOPs, overlap); collective benchmark of the grid sum |
| `implementation/jobs/` | `vanda_cpu.pbs`, `vanda_gpu.pbs`: modules, build, MPI launch, `STUDIES=...` or `SCRIPT=...` |
| `implementation/scripts/` | `submit_all.sh` (job catalogue), `run_experiments.sh` (MPI experiment driver), `cpu_studies.sh`, `gpu_dist_fft.sh`, `coll_bench.sh`, `repro_check.sh`, `overlap_near.sh` (experimental, no reported result), `prepare.sh` (data), `h5ad_to_bin.py` |
| `implementation/analysis/` | notebooks `01_summary_tables`, `02_figures`, `03_latex_tables` |
| `output/` | raw experiment results read by the notebooks (14 MB): one directory per job (name = `RES=`), `data_real/` labels, `real_quality.json`, micro-benchmark and gate logs |
| `tables/` | the 29 tables of the report as csv (rows and columns as in the report, one file per LaTeX label, e.g. `tab_strong.csv`, `tab_gpufft.csv`) and `INDEX.csv` (label, file, caption); written by notebook 03 |
| `figures/` | the figures of the report (png), written by notebook 02 (R0_pipeline, R12_kl_gap and R16_type_purity are also drawn but not used in the report) |
| `work/` | intermediate files of the notebooks (summary tables, source tables, LaTeX tables, raw files arranged by report section); regenerated by notebook 01, not part of the repository |
