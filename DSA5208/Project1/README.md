# DSA5208 Project 1: MongoDB Client-Centric Consistency

This repository is the reproducibility package for the submitted report
`DSA5208_Project1_A0352456B.pdf`. It contains the runnable Docker deployment,
the experiment and checker scripts, and the complete active datasets used in
the report.

## Repository layout

| Path | Contents |
| --- | --- |
| `DSA5208_Project1_A0352456B.pdf` | Final submitted report |
| `compose.yaml` | Three-member MongoDB replica set and Python client container |
| `client/`, `mongo-node/` | Docker images for the client and database members |
| `code/` | Workload, fault injection, offline checker, host controller, and batch runners |
| `results/formal/` | Complete C01--C36 × S1--S6 formal dataset |
| `results/supplementary/` | CC07--CC09 and CC19--CC21 supplementary WFR dataset |

The historical old-numbering archive and failed runner attempts are excluded
because they do not enter any reported denominator. The retained data are the
authoritative current-ID formal dataset and the separately reported WFR
supplement.

## Result-file format

Each completed configuration--scenario combination contains:

- a readable `.md` report;
- a deterministic `.schedule.json` workload and fault schedule; and
- the complete event history as `.jsonl.gz`.

The JSONL files are compressed solely to keep the repository practical for
GitHub. Compression does not alter their contents. To unpack all histories
while retaining the compressed copies, run:

```bash
bash code/unpack_results.sh
```

To inspect one history with the offline checker after unpacking:

```bash
python3 code/checker.py results/formal/C01/normal.jsonl
```

The checker exit status is `2` when a sound violation is present, `0` when no
violation is present in a completed run, and another non-zero value for a
runner or input error. Always inspect the per-property `PASS`, `VIOLATION`, and
`INCONCLUSIVE` results rather than interpreting the process exit status alone.

## Environment setup

The reported experiment used Docker Desktop on Apple Silicon. Reproduction
requires Docker Compose, Python 3, `jq`, and the standard `gzip` utility. Copy
the public environment template, build the images, and start the containers
from the repository root:

```bash
cp .env.example .env
docker compose config
docker compose up -d --build
docker compose ps
```

On a new set of Docker volumes, initialize the replica set once:

```bash
docker compose exec mongo1 mongosh --quiet --eval '
rs.initiate({
  _id: "rs0",
  members: [
    {_id: 0, host: "mongo1:27017", tags: {node: "A"}},
    {_id: 1, host: "mongo2:27017", tags: {node: "B"}},
    {_id: 2, host: "mongo3:27017", tags: {node: "C"}}
  ]
})'
```

Wait until `rs.status()` reports one primary and two secondaries. The complete
installation procedure and recorded software versions are in the report.

## Reproducing the experiments

A small end-to-end run can be started with:

```bash
python3 code/run.py --scenario normal --causal-session on \
  --read-concern local --write-concern 1 --read-preference primary \
  --journal on --workload-mode phased-probes --operation-pairs 24 \
  --trials 1 --output results/reproduction-smoke.md
```

The complete C01--C36 × S1--S6 factorial, with five trials for every
configuration--scenario combination, can be reproduced under a new result
directory with:

```bash
RUN_ID=reproduction-full CONFIG_START=1 CONFIG_END=36 \
INCLUDE_W3=on INCLUDE_TWO_NODES=on \
bash code/run_factorial_matrix.sh 5
```

The runner is resumable when the same `RUN_ID` is reused. Experiments mutate
one shared replica set and must therefore run sequentially. The complete run is
long; keep the host awake and ensure Docker Desktop has the resources recorded
in the report.

The WFR supplement is implemented by `code/run_wfr_supplement.sh` and writes
to `results/supplementary-run` by default. The precise
frozen controls, configuration catalogue, workload construction, and
measurement rules are documented in the PDF.

## Integrity and privacy

`SHA256SUMS` records hashes for every distributed file other than the manifest
itself. No credentials, local `.env` file, Docker volumes, or macOS metadata are
included. The included `.env.example` contains only the public MongoDB image
tag required by Compose.
