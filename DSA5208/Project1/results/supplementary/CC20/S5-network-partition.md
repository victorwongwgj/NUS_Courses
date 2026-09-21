# S5 network-partition / C20 — continuous history

Raw history: [S5-network-partition.jsonl](S5-network-partition.jsonl)

All four properties use the same history. PASS refers only to checked relations.
Faults run on an independent timer. Phases are host-observed invocation phases.
Schedule: [S5-network-partition.schedule.json](S5-network-partition.schedule.json)
Rollback of an acknowledged/observed append counts as loss.

```json
{
  "scenario": "network-partition",
  "property": "all",
  "read_concern": "majority",
  "write_concern": "1",
  "journal": "on",
  "read_preference": "secondary",
  "causal_session": "off",
  "background_workload": "on",
  "background_interval_ms": 50,
  "background_payload_bytes": 8192,
  "background_warmup_writes": 50,
  "background_settle_ms": 1000,
  "background_baseline": "off",
  "replication_delay_ms": 1500,
  "replication_jitter_ms": 250,
  "replication_rate_mbit": 20,
  "trials": 5,
  "operation_pairs": 24,
  "workload_mode": "phased-probes-wfr-late",
  "workload_seed": 1729,
  "operation_interval_ms": 1000,
  "interarrival_distribution": "geometric",
  "interarrival_slot_ms": 20,
  "interarrival_probability": 0.1,
  "schedule_seed": 5208,
  "fault_start_min_seconds": 1.0,
  "fault_start_max_seconds": 2.0,
  "timeout_ms": 5000,
  "read_timeout_ms": 8000,
  "write_timeout_ms": 20000,
  "election_wait_seconds": 60,
  "replication_wait_seconds": 30,
  "recovery_catchup_seconds": 300,
  "uri": "mongodb://mongo1:27017,mongo2:27017,mongo3:27017/lab?replicaSet=rs0",
  "db": "lab",
  "output": "results/raw/wfr-supplement-current-ids-v2/CC20/S5-network-partition.md",
  "keep_fault": false,
  "inner": false,
  "trial_id": null
}
```

| Trial | Property | Status | Checked | Cross-phase | Witnesses |
| --- | --- | --- | --- | --- | --- |
| 1 | RYW | VIOLATION | 36 | 6 | 36 |
| 1 | MR | PASS | 1 | 0 | 0 |
| 1 | MW | VIOLATION | 66 | 0 | 20 |
| 1 | WFR | INCONCLUSIVE | 0 | 0 | 0 |
| 2 | RYW | VIOLATION | 36 | 12 | 36 |
| 2 | MR | INCONCLUSIVE | 0 | 0 | 0 |
| 2 | MW | PASS | 66 | 11 | 0 |
| 2 | WFR | INCONCLUSIVE | 0 | 0 | 0 |
| 3 | RYW | VIOLATION | 36 | 12 | 36 |
| 3 | MR | PASS | 15 | 0 | 0 |
| 3 | MW | PASS | 66 | 20 | 0 |
| 3 | WFR | PASS | 18 | 0 | 0 |
| 4 | RYW | VIOLATION | 36 | 12 | 36 |
| 4 | MR | PASS | 21 | 0 | 0 |
| 4 | MW | PASS | 66 | 20 | 0 |
| 4 | WFR | INCONCLUSIVE | 0 | 0 | 0 |
| 5 | RYW | VIOLATION | 36 | 12 | 36 |
| 5 | MR | VIOLATION | 8 | 0 | 2 |
| 5 | MW | PASS | 66 | 20 | 0 |
| 5 | WFR | PASS | 29 | 0 | 0 |

## Trial 1

Operations: 60; success: 60; failed: 0; pending: 0.
Complete: True; unresolved writes: [].

```json
{
  "RYW": {
    "checked": 36,
    "cross_phase_checked": 6,
    "witnesses": [
      {
        "earlier": "RYW-W1",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      }
    ],
    "status": "VIOLATION"
  },
  "MR": {
    "checked": 1,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  },
  "MW": {
    "checked": 66,
    "cross_phase_checked": 0,
    "witnesses": [
      {
        "earlier": "MW-W1",
        "later": "MW-W11",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W2",
        "later": "MW-W11",
        "missing": [
          "fg:MW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W3",
        "later": "MW-W11",
        "missing": [
          "fg:MW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W4",
        "later": "MW-W11",
        "missing": [
          "fg:MW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W5",
        "later": "MW-W11",
        "missing": [
          "fg:MW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W6",
        "later": "MW-W11",
        "missing": [
          "fg:MW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W7",
        "later": "MW-W11",
        "missing": [
          "fg:MW-W7"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W8",
        "later": "MW-W11",
        "missing": [
          "fg:MW-W8"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W9",
        "later": "MW-W11",
        "missing": [
          "fg:MW-W9"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W10",
        "later": "MW-W11",
        "missing": [
          "fg:MW-W10"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W12",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W2",
        "later": "MW-W12",
        "missing": [
          "fg:MW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W3",
        "later": "MW-W12",
        "missing": [
          "fg:MW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W4",
        "later": "MW-W12",
        "missing": [
          "fg:MW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W5",
        "later": "MW-W12",
        "missing": [
          "fg:MW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W6",
        "later": "MW-W12",
        "missing": [
          "fg:MW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W7",
        "later": "MW-W12",
        "missing": [
          "fg:MW-W7"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W8",
        "later": "MW-W12",
        "missing": [
          "fg:MW-W8"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W9",
        "later": "MW-W12",
        "missing": [
          "fg:MW-W9"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W10",
        "later": "MW-W12",
        "missing": [
          "fg:MW-W10"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      }
    ],
    "status": "VIOLATION"
  },
  "WFR": {
    "checked": 0,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "INCONCLUSIVE"
  }
}
```

## Trial 2

Operations: 60; success: 60; failed: 0; pending: 0.
Complete: True; unresolved writes: [].

```json
{
  "RYW": {
    "checked": 36,
    "cross_phase_checked": 12,
    "witnesses": [
      {
        "earlier": "RYW-W1",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      }
    ],
    "status": "VIOLATION"
  },
  "MR": {
    "checked": 0,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "INCONCLUSIVE"
  },
  "MW": {
    "checked": 66,
    "cross_phase_checked": 11,
    "witnesses": [],
    "status": "PASS"
  },
  "WFR": {
    "checked": 0,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "INCONCLUSIVE"
  }
}
```

## Trial 3

Operations: 60; success: 60; failed: 0; pending: 0.
Complete: True; unresolved writes: [].

```json
{
  "RYW": {
    "checked": 36,
    "cross_phase_checked": 12,
    "witnesses": [
      {
        "earlier": "RYW-W1",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      }
    ],
    "status": "VIOLATION"
  },
  "MR": {
    "checked": 15,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  },
  "MW": {
    "checked": 66,
    "cross_phase_checked": 20,
    "witnesses": [],
    "status": "PASS"
  },
  "WFR": {
    "checked": 18,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  }
}
```

## Trial 4

Operations: 60; success: 60; failed: 0; pending: 0.
Complete: True; unresolved writes: [].

```json
{
  "RYW": {
    "checked": 36,
    "cross_phase_checked": 12,
    "witnesses": [
      {
        "earlier": "RYW-W1",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      }
    ],
    "status": "VIOLATION"
  },
  "MR": {
    "checked": 21,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  },
  "MW": {
    "checked": 66,
    "cross_phase_checked": 20,
    "witnesses": [],
    "status": "PASS"
  },
  "WFR": {
    "checked": 0,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "INCONCLUSIVE"
  }
}
```

## Trial 5

Operations: 60; success: 60; failed: 0; pending: 0.
Complete: True; unresolved writes: [].

```json
{
  "RYW": {
    "checked": 36,
    "cross_phase_checked": 12,
    "witnesses": [
      {
        "earlier": "RYW-W1",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R1",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R3",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W1",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W2",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W3",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W4",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W5",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "RYW-W6",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      }
    ],
    "status": "VIOLATION"
  },
  "MR": {
    "checked": 8,
    "cross_phase_checked": 0,
    "witnesses": [
      {
        "earlier": "MR-R8",
        "later": "MR-R10",
        "missing": [
          "bg:0000000000000001"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R9",
        "later": "MR-R10",
        "missing": [
          "bg:0000000000000001"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      }
    ],
    "status": "VIOLATION"
  },
  "MW": {
    "checked": 66,
    "cross_phase_checked": 20,
    "witnesses": [],
    "status": "PASS"
  },
  "WFR": {
    "checked": 29,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  }
}
```
