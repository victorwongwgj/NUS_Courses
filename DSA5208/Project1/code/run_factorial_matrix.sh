#!/usr/bin/env bash
# Run the resumable C01-C36 factorial. S1-S5 are enabled by default; setting
# INCLUDE_TWO_NODES=on adds S6, and INCLUDE_W3=on enables C25-C36.
set -uo pipefail

trials="${1:-5}"
run_id="${RUN_ID:-formal-c1-c36-$(date +%Y%m%d-%H%M%S)}"
config_start="${CONFIG_START:-1}"
config_end="${CONFIG_END:-36}"
operation_pairs="${OPERATION_PAIRS:-24}"
include_w3="${INCLUDE_W3:-off}"
include_two_nodes="${INCLUDE_TWO_NODES:-off}"
output_root="results/${run_id}"
failed_root="${output_root}/_failed_attempts"
failure_log="${output_root}/failed-cells.tsv"
max_attempts=3

if ! [[ "$trials" =~ ^[1-9][0-9]*$ ]]; then
  echo "Usage: $0 [positive-trial-count]" >&2
  exit 64
fi
if ! [[ "$config_start" =~ ^[1-9][0-9]*$ && "$config_end" =~ ^[1-9][0-9]*$ ]] \
    || (( config_start > config_end || config_end > 36 )); then
  echo "CONFIG_START and CONFIG_END must satisfy 1 <= start <= end <= 36" >&2
  exit 64
fi
if ! [[ "$operation_pairs" =~ ^[1-9][0-9]*$ ]]; then
  echo "OPERATION_PAIRS must be a positive integer" >&2
  exit 64
fi
if [[ "$include_w3" != "on" && "$include_w3" != "off" ]]; then
  echo "INCLUDE_W3 must be either on or off" >&2
  exit 64
fi
if [[ "$include_two_nodes" != "on" && "$include_two_nodes" != "off" ]]; then
  echo "INCLUDE_TWO_NODES must be either on or off" >&2
  exit 64
fi

mkdir -p "$output_root" "$failed_root"

causal_values=(on off)
read_concerns=(local majority)
read_preferences=(primary secondary secondaryPreferred)

scenario_specs=(S1:normal S2:primary-down S3:secondary-down
                S4:node-isolation S5:network-partition)
if [[ "$include_two_nodes" == "on" ]]; then
  scenario_specs+=(S6:two-nodes-down)
fi

# These are the frozen controls used by the report. Configuration and scenario
# values vary in the loops below; workload timing, link impairment, timeouts,
# background load, and random seeds remain fixed for controlled comparison.
common_args=(
  --journal on
  --workload-mode phased-probes
  --operation-pairs "$operation_pairs"
  --workload-seed 1729
  --schedule-seed 5208
  --interarrival-distribution geometric
  --interarrival-slot-ms 20
  --interarrival-probability 0.1
  --fault-start-min-seconds 1
  --fault-start-max-seconds 2
  --timeout-ms 5000
  --read-timeout-ms 8000
  --write-timeout-ms 20000
  --replication-delay-ms 1500
  --replication-jitter-ms 250
  --replication-rate-mbit 20
  --background-workload on
  --background-interval-ms 50
  --background-payload-bytes 8192
  --background-warmup-writes 50
  --background-settle-ms 1000
  --recovery-catchup-seconds 300
  --trials "$trials"
)

reset_environment() {
  python3 -c 'import sys; sys.path.insert(0,"code"); from host import reset_experiment_environment; reset_experiment_environment(180)'
}

cleanup_on_exit() {
  reset_environment || true
}

trap cleanup_on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

archive_partial() {
  local base="$1" attempt="$2" destination
  destination="${failed_root}/${base#${output_root}/}-attempt-${attempt}"
  mkdir -p "$destination"
  for path in "${base}.md" "${base}.jsonl" "${base}.schedule.json"; do
    if [[ -e "$path" ]]; then
      mv "$path" "$destination/"
    fi
  done
}

completed_trial_count() {
  local history="$1"
  if [[ ! -f "$history" ]]; then
    echo 0
    return
  fi
  jq -s '[.[] | select(.event == "offline_result" and .result.history_complete == true)] | length' \
    "$history" 2>/dev/null || echo 0
}

config_number=0
for catalogue in main w3-extension; do
  for causal in "${causal_values[@]}"; do
    for read_concern in "${read_concerns[@]}"; do
      if [[ "$catalogue" == "main" ]]; then
        write_concerns=(1 majority)
      else
        write_concerns=(3)
      fi
      for write_concern in "${write_concerns[@]}"; do
      for read_preference in "${read_preferences[@]}"; do
        config_number=$((config_number + 1))
        # Use the same zero-padded identifier as the report and retained data,
        # so lexicographic directory order also matches catalogue order.
        printf -v config 'C%02d' "$config_number"
        if (( config_number < config_start || config_number > config_end )); then
          continue
        fi
        # In a three-member replica set, w:3 needs every member. A stopped or
        # isolated member therefore prevents acknowledgement. These rows are
        # kept as an explicit availability extension and are disabled in the
        # default C01-C24 run to avoid an unexpectedly long batch.
        if [[ "$catalogue" == "w3-extension" && "$include_w3" != "on" ]]; then
          echo "Skipping extension configuration $config (write concern w:3)"
          continue
        fi

        for scenario_spec in "${scenario_specs[@]}"; do
          scenario_id="${scenario_spec%%:*}"
          scenario="${scenario_spec#*:}"
          output="${output_root}/${config}/${scenario_id}-${scenario}.md"
          base="${output%.md}"
          complete_trials="$(completed_trial_count "${base}.jsonl")"
          if [[ -e "$output" && "$complete_trials" -eq "$trials" ]]; then
            echo "Skipping completed $config $scenario"
            continue
          fi
          if [[ -e "$output" || -e "${base}.jsonl" || -e "${base}.schedule.json" ]]; then
            echo "Archiving incomplete $config $scenario ($complete_trials/$trials complete trials)"
            archive_partial "$base" "preexisting"
          fi

          completed=0
          for attempt in 1 2 3; do
            echo "Running $config $scenario ($trials trials), attempt $attempt/$max_attempts"
            if ! reset_environment; then
              echo "Environment reset failed before $config $scenario attempt $attempt" >&2
              archive_partial "$base" "$attempt"
              sleep 5
              continue
            fi

            python3 code/run.py \
              --scenario "$scenario" \
              --causal-session "$causal" \
              --read-concern "$read_concern" \
              --write-concern "$write_concern" \
              --read-preference "$read_preference" \
              "${common_args[@]}" \
              --output "$output"
            exit_code=$?

            # Exit 0 means no violation was found; exit 2 means at least one
            # sound witness was found. Both are valid experimental outcomes.
            # Other exit codes indicate an incomplete runner attempt and are
            # archived before the cell is retried.
            if [[ "$exit_code" -eq 0 || "$exit_code" -eq 2 ]]; then
              complete_trials="$(completed_trial_count "${base}.jsonl")"
              if [[ -e "$output" && "$complete_trials" -eq "$trials" ]]; then
                completed=1
                break
              fi
              echo "Incomplete output after successful exit: $complete_trials/$trials trials" >&2
            else
              echo "Attempt $attempt failed for $config $scenario (exit $exit_code)" >&2
            fi

            archive_partial "$base" "$attempt"
            reset_environment || true
            sleep 5
          done

          if [[ "$completed" -ne 1 ]]; then
            printf '%s\t%s\tfailed after %s attempts\n' \
              "$config" "$scenario" "$max_attempts" >> "$failure_log"
            echo "Continuing after failed cell $config $scenario" >&2
          fi
        done
      done
    done
  done
done
done

reset_environment || true
echo "C${config_start}-C${config_end} factorial batch finished: $output_root"
if [[ -s "$failure_log" ]]; then
  echo "Some cells need attention: $failure_log" >&2
  exit 1
fi
