# primary-down / C02 — continuous history

Raw history: [primary-down.jsonl](primary-down.jsonl)

All four properties use the same history. PASS refers only to checked relations.
Faults run on an independent timer. Phases are host-observed invocation phases.
Schedule: [primary-down.schedule.json](primary-down.schedule.json)
Rollback of an acknowledged/observed append counts as loss.

```json
{
  "scenario": "primary-down",
  "property": "all",
  "read_concern": "local",
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
  "output": "results/raw/formal-old-workload-current-ids-v1/C02/primary-down.md",
  "keep_fault": false,
  "inner": false,
  "trial_id": null
}
```

| Trial | Property | Status | Checked | Cross-phase | Witnesses |
| --- | --- | --- | --- | --- | --- |
| 1 | RYW | VIOLATION | 12 | 2 | 2 |
| 1 | MR | PASS | 66 | 11 | 0 |
| 1 | MW | VIOLATION | 66 | 0 | 11 |
| 1 | WFR | PASS | 132 | 0 | 0 |
| 2 | RYW | VIOLATION | 30 | 6 | 6 |
| 2 | MR | PASS | 66 | 11 | 0 |
| 2 | MW | VIOLATION | 66 | 11 | 11 |
| 2 | WFR | PASS | 132 | 36 | 0 |
| 3 | RYW | VIOLATION | 36 | 12 | 12 |
| 3 | MR | PASS | 45 | 9 | 0 |
| 3 | MW | VIOLATION | 66 | 11 | 20 |
| 3 | WFR | PASS | 108 | 12 | 0 |
| 4 | RYW | VIOLATION | 36 | 6 | 6 |
| 4 | MR | PASS | 66 | 11 | 0 |
| 4 | MW | VIOLATION | 66 | 11 | 11 |
| 4 | WFR | PASS | 120 | 24 | 0 |
| 5 | RYW | VIOLATION | 36 | 12 | 12 |
| 5 | MR | PASS | 66 | 20 | 0 |
| 5 | MW | VIOLATION | 66 | 11 | 20 |
| 5 | WFR | PASS | 132 | 36 | 0 |

## Trial 1

Operations: 60; success: 56; failed: 4; pending: 0.
Complete: True; unresolved writes: [].

```json
{
  "RYW": {
    "checked": 12,
    "cross_phase_checked": 2,
    "witnesses": [
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
        "earlier": "RYW-W1",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      }
    ],
    "status": "VIOLATION"
  },
  "MR": {
    "checked": 66,
    "cross_phase_checked": 11,
    "witnesses": [],
    "status": "PASS"
  },
  "MW": {
    "checked": 66,
    "cross_phase_checked": 0,
    "witnesses": [
      {
        "earlier": "MW-W1",
        "later": "MW-W2",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W3",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W4",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W5",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W6",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
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
        "earlier": "MW-W1",
        "later": "MW-W12",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      }
    ],
    "status": "VIOLATION"
  },
  "WFR": {
    "checked": 132,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  }
}
```

## Trial 2

Operations: 60; success: 58; failed: 2; pending: 0.
Complete: True; unresolved writes: [].

```json
{
  "RYW": {
    "checked": 30,
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
        "earlier": "RYW-W1",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
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
        "earlier": "RYW-W1",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
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
        "earlier": "RYW-W1",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      }
    ],
    "status": "VIOLATION"
  },
  "MR": {
    "checked": 66,
    "cross_phase_checked": 11,
    "witnesses": [],
    "status": "PASS"
  },
  "MW": {
    "checked": 66,
    "cross_phase_checked": 11,
    "witnesses": [
      {
        "earlier": "MW-W1",
        "later": "MW-W2",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W3",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W4",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W5",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W6",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W11",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W12",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      }
    ],
    "status": "VIOLATION"
  },
  "WFR": {
    "checked": 132,
    "cross_phase_checked": 36,
    "witnesses": [],
    "status": "PASS"
  }
}
```

## Trial 3

Operations: 60; success: 58; failed: 2; pending: 0.
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
      }
    ],
    "status": "VIOLATION"
  },
  "MR": {
    "checked": 45,
    "cross_phase_checked": 9,
    "witnesses": [],
    "status": "PASS"
  },
  "MW": {
    "checked": 66,
    "cross_phase_checked": 11,
    "witnesses": [
      {
        "earlier": "MW-W1",
        "later": "MW-W3",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W2",
        "later": "MW-W3",
        "missing": [
          "fg:MW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W4",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W2",
        "later": "MW-W4",
        "missing": [
          "fg:MW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W5",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W2",
        "later": "MW-W5",
        "missing": [
          "fg:MW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W6",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W2",
        "later": "MW-W6",
        "missing": [
          "fg:MW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W2",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W2",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W2",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W2",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W11",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
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
        "earlier": "MW-W1",
        "later": "MW-W12",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
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
      }
    ],
    "status": "VIOLATION"
  },
  "WFR": {
    "checked": 108,
    "cross_phase_checked": 12,
    "witnesses": [],
    "status": "PASS"
  }
}
```

## Trial 4

Operations: 60; success: 58; failed: 2; pending: 0.
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
        "earlier": "RYW-W1",
        "later": "RYW-R2",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
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
        "earlier": "RYW-W1",
        "later": "RYW-R4",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
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
        "earlier": "RYW-W1",
        "later": "RYW-R6",
        "missing": [
          "fg:RYW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      }
    ],
    "status": "VIOLATION"
  },
  "MR": {
    "checked": 66,
    "cross_phase_checked": 11,
    "witnesses": [],
    "status": "PASS"
  },
  "MW": {
    "checked": 66,
    "cross_phase_checked": 11,
    "witnesses": [
      {
        "earlier": "MW-W1",
        "later": "MW-W2",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W3",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W4",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W5",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W6",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W11",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W12",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      }
    ],
    "status": "VIOLATION"
  },
  "WFR": {
    "checked": 120,
    "cross_phase_checked": 24,
    "witnesses": [],
    "status": "PASS"
  }
}
```

## Trial 5

Operations: 60; success: 59; failed: 1; pending: 0.
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
      }
    ],
    "status": "VIOLATION"
  },
  "MR": {
    "checked": 66,
    "cross_phase_checked": 20,
    "witnesses": [],
    "status": "PASS"
  },
  "MW": {
    "checked": 66,
    "cross_phase_checked": 11,
    "witnesses": [
      {
        "earlier": "MW-W1",
        "later": "MW-W3",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W2",
        "later": "MW-W3",
        "missing": [
          "fg:MW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W4",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W2",
        "later": "MW-W4",
        "missing": [
          "fg:MW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W5",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W2",
        "later": "MW-W5",
        "missing": [
          "fg:MW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W6",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W2",
        "later": "MW-W6",
        "missing": [
          "fg:MW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W2",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W2",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W2",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W2",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W2"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MW-W1",
        "later": "MW-W11",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
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
        "earlier": "MW-W1",
        "later": "MW-W12",
        "missing": [
          "fg:MW-W1"
        ],
        "earlier_phase": "before",
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
      }
    ],
    "status": "VIOLATION"
  },
  "WFR": {
    "checked": 132,
    "cross_phase_checked": 36,
    "witnesses": [],
    "status": "PASS"
  }
}
```
