#!/usr/bin/env bash
# Run the 60-operation WFR timing supplement for the majority/w:1 slice. Only
# the WFR source-read position differs from the formal workload; all frozen
# network, timeout, background-load, and random-seed controls remain unchanged.
set -uo pipefail

trials="${1:-5}"
output_root="${OUTPUT_ROOT:-results/supplementary-run}"
mkdir -p "$output_root"

common=(
  --journal on --workload-mode phased-probes-wfr-late --operation-pairs 24
  --workload-seed 1729 --schedule-seed 5208
  --interarrival-distribution geometric --interarrival-slot-ms 20
  --interarrival-probability 0.1 --fault-start-min-seconds 1
  --fault-start-max-seconds 2 --timeout-ms 5000 --read-timeout-ms 8000
  --write-timeout-ms 20000 --replication-delay-ms 1500
  --replication-jitter-ms 250 --replication-rate-mbit 20
  --background-workload on --background-interval-ms 50
  --background-payload-bytes 8192 --background-warmup-writes 50
  --background-settle-ms 1000 --background-baseline off
  --recovery-catchup-seconds 300 --trials "$trials"
)

reset_environment() {
  python3 -c 'import sys; sys.path.insert(0,"code"); from host import reset_experiment_environment; reset_experiment_environment(180)'
}

complete_trials() {
  local path="$1"
  [[ -f "$path" ]] || { echo 0; return; }
  python3 -c 'import json,sys; print(sum(json.loads(x).get("event")=="history_complete" for x in open(sys.argv[1])))' "$path"
}

run_cell() {
  local id="$1" causal="$2" read_preference="$3" scenario="$4"
  local scenario_id="$5" base status complement_label
  # CC denotes a complementary workload configuration. Its numeric suffix
  # identifies the formal configuration whose database parameters are reused,
  # making each supplementary result directly matchable to the main matrix.
  printf -v complement_label 'CC%02d' "$id"
  base="$output_root/${complement_label}/${scenario_id}-${scenario}"
  mkdir -p "$(dirname "$base")"
  if [[ "$(complete_trials "${base}.jsonl")" -eq "$trials" ]]; then
    echo "Skipping complete ${complement_label} ${scenario}"
    return
  fi
  if [[ -e "${base}.md" || -e "${base}.jsonl" || -e "${base}.schedule.json" ]]; then
    local archive="$output_root/_failed_attempts/${complement_label}-${scenario_id}-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$archive"
    for path in "${base}.md" "${base}.jsonl" "${base}.schedule.json"; do
      [[ -e "$path" ]] && mv "$path" "$archive/"
    done
  fi
  for attempt in 1 2 3; do
    echo "Running supplementary ${complement_label} ${scenario}, attempt ${attempt}/3"
    reset_environment || continue
    python3 code/run.py "${common[@]}" --causal-session "$causal" \
      --read-concern majority --write-concern 1 \
      --read-preference "$read_preference" --scenario "$scenario" \
      --output "${base}.md"
    status=$?
    [[ "$status" -eq 0 || "$status" -eq 2 ]] && return
    local retry_archive="$output_root/_failed_attempts/${complement_label}-${scenario_id}-attempt-${attempt}"
    mkdir -p "$retry_archive"
    for path in "${base}.md" "${base}.jsonl" "${base}.schedule.json"; do
      [[ -e "$path" ]] && mv "$path" "$retry_archive/"
    done
  done
  echo "FAILED supplementary ${complement_label} ${scenario}" >&2
}

trap 'reset_environment || true' EXIT

for spec in primary-down:S2 network-partition:S5; do
  scenario="${spec%%:*}"
  scenario_id="${spec##*:}"
  run_cell 7 on primary "$scenario" "$scenario_id"
  run_cell 8 on secondary "$scenario" "$scenario_id"
  run_cell 9 on secondaryPreferred "$scenario" "$scenario_id"
  run_cell 19 off primary "$scenario" "$scenario_id"
  run_cell 20 off secondary "$scenario" "$scenario_id"
  run_cell 21 off secondaryPreferred "$scenario" "$scenario_id"
done
