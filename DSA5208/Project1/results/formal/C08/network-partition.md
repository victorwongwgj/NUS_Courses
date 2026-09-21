# network-partition / C08 — continuous history

Raw history: [network-partition.jsonl](network-partition.jsonl)

All four properties use the same history. PASS refers only to checked relations.
Faults run on an independent timer. Phases are host-observed invocation phases.
Schedule: [network-partition.schedule.json](network-partition.schedule.json)
Rollback of an acknowledged/observed append counts as loss.

```json
{
  "scenario": "network-partition",
  "property": "all",
  "read_concern": "majority",
  "write_concern": "1",
  "journal": "on",
  "read_preference": "secondary",
  "causal_session": "on",
  "background_workload": "on",
  "background_interval_ms": 50,
  "background_payload_bytes": 8192,
  "background_warmup_writes": 50,
  "background_settle_ms": 1000,
  "replication_delay_ms": 1500,
  "replication_jitter_ms": 250,
  "replication_rate_mbit": 20,
  "trials": 5,
  "operation_pairs": 24,
  "workload_mode": "phased-probes",
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
  "output": "results/raw/formal-old-workload-current-ids-v1/C08/network-partition.md",
  "keep_fault": false,
  "inner": false,
  "trial_id": null
}
```

| Trial | Property | Status | Checked | Cross-phase | Witnesses |
| --- | --- | --- | --- | --- | --- |
| 1 | RYW | VIOLATION | 6 | 1 | 4 |
| 1 | MR | PASS | 15 | 0 | 0 |
| 1 | MW | VIOLATION | 66 | 0 | 24 |
| 1 | WFR | PASS | 84 | 0 | 0 |
| 2 | RYW | INCONCLUSIVE | 0 | 0 | 0 |
| 2 | MR | PASS | 28 | 0 | 0 |
| 2 | MW | VIOLATION | 66 | 11 | 24 |
| 2 | WFR | PASS | 60 | 0 | 0 |
| 3 | RYW | VIOLATION | 12 | 4 | 2 |
| 3 | MR | PASS | 21 | 0 | 0 |
| 3 | MW | VIOLATION | 66 | 11 | 12 |
| 3 | WFR | PASS | 12 | 0 | 0 |
| 4 | RYW | VIOLATION | 18 | 6 | 9 |
| 4 | MR | PASS | 6 | 0 | 0 |
| 4 | MW | VIOLATION | 66 | 20 | 18 |
| 4 | WFR | INCONCLUSIVE | 0 | 0 | 0 |
| 5 | RYW | VIOLATION | 18 | 6 | 12 |
| 5 | MR | PASS | 15 | 0 | 0 |
| 5 | MW | VIOLATION | 66 | 11 | 24 |
| 5 | WFR | PASS | 33 | 0 | 0 |

## Trial 1

Operations: 60; success: 52; failed: 8; pending: 0.
Complete: True; unresolved writes: [].

```json
{
  "RYW": {
    "checked": 6,
    "cross_phase_checked": 1,
    "witnesses": [
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
    "cross_phase_checked": 0,
    "witnesses": [
      {
        "earlier": "MW-W3",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W4",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W5",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W6",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W3",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W4",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W5",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W6",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W3",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W4",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W5",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W6",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W3",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W4",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W5",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W6",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W6"
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
      }
    ],
    "status": "VIOLATION"
  },
  "WFR": {
    "checked": 84,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  }
}
```

## Trial 2

Operations: 60; success: 54; failed: 6; pending: 0.
Complete: True; unresolved writes: [].

```json
{
  "RYW": {
    "checked": 0,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "INCONCLUSIVE"
  },
  "MR": {
    "checked": 28,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  },
  "MW": {
    "checked": 66,
    "cross_phase_checked": 11,
    "witnesses": [
      {
        "earlier": "MW-W3",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W4",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W5",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W6",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W3",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W4",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W5",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W6",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W3",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W4",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W5",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W6",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W3",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W4",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W5",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W6",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W6"
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
      }
    ],
    "status": "VIOLATION"
  },
  "WFR": {
    "checked": 60,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  }
}
```

## Trial 3

Operations: 60; success: 56; failed: 4; pending: 0.
Complete: True; unresolved writes: [].

```json
{
  "RYW": {
    "checked": 12,
    "cross_phase_checked": 4,
    "witnesses": [
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
        "earlier": "RYW-W6",
        "later": "RYW-R5",
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
    "cross_phase_checked": 11,
    "witnesses": [
      {
        "earlier": "MW-W5",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W6",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W5",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W6",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W5",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W6",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W5",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W6",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W6"
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
      }
    ],
    "status": "VIOLATION"
  },
  "WFR": {
    "checked": 12,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  }
}
```

## Trial 4

Operations: 60; success: 53; failed: 7; pending: 0.
Complete: True; unresolved writes: [].

```json
{
  "RYW": {
    "checked": 18,
    "cross_phase_checked": 6,
    "witnesses": [
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
    "checked": 6,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  },
  "MW": {
    "checked": 66,
    "cross_phase_checked": 20,
    "witnesses": [
      {
        "earlier": "MW-W4",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W5",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W6",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W4",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W5",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W6",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W4",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W5",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W6",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W4",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W5",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W6",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W6"
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

## Trial 5

Operations: 60; success: 55; failed: 5; pending: 0.
Complete: True; unresolved writes: [].

```json
{
  "RYW": {
    "checked": 18,
    "cross_phase_checked": 6,
    "witnesses": [
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
    "cross_phase_checked": 11,
    "witnesses": [
      {
        "earlier": "MW-W3",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W4",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W5",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W6",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W3",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W4",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W5",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W6",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W3",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W4",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W5",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W6",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W6"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W3",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W3"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W4",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W4"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W5",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W5"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W6",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W6"
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
      }
    ],
    "status": "VIOLATION"
  },
  "WFR": {
    "checked": 33,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  }
}
```
