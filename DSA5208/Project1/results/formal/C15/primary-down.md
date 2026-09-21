# primary-down / C15 — continuous history

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
  "read_preference": "secondaryPreferred",
  "causal_session": "off",
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
  "output": "results/raw/formal-old-workload-current-ids-v1/C15/primary-down.md",
  "keep_fault": false,
  "inner": false,
  "trial_id": null
}
```

| Trial | Property | Status | Checked | Cross-phase | Witnesses |
| --- | --- | --- | --- | --- | --- |
| 1 | RYW | VIOLATION | 30 | 6 | 30 |
| 1 | MR | PASS | 66 | 11 | 0 |
| 1 | MW | VIOLATION | 66 | 0 | 11 |
| 1 | WFR | PASS | 144 | 12 | 0 |
| 2 | RYW | VIOLATION | 30 | 6 | 24 |
| 2 | MR | VIOLATION | 66 | 11 | 14 |
| 2 | MW | VIOLATION | 66 | 11 | 11 |
| 2 | WFR | PASS | 144 | 36 | 0 |
| 3 | RYW | VIOLATION | 30 | 12 | 30 |
| 3 | MR | VIOLATION | 66 | 20 | 18 |
| 3 | MW | VIOLATION | 66 | 11 | 20 |
| 3 | WFR | PASS | 144 | 36 | 0 |
| 4 | RYW | VIOLATION | 30 | 12 | 30 |
| 4 | MR | VIOLATION | 66 | 20 | 18 |
| 4 | MW | VIOLATION | 66 | 20 | 20 |
| 4 | WFR | PASS | 144 | 36 | 0 |
| 5 | RYW | VIOLATION | 30 | 12 | 30 |
| 5 | MR | VIOLATION | 66 | 20 | 11 |
| 5 | MW | VIOLATION | 66 | 11 | 20 |
| 5 | WFR | PASS | 144 | 36 | 0 |

## Trial 1

Operations: 60; success: 59; failed: 1; pending: 0.
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
    "checked": 144,
    "cross_phase_checked": 12,
    "witnesses": [],
    "status": "PASS"
  }
}
```

## Trial 2

Operations: 60; success: 59; failed: 1; pending: 0.
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
    "checked": 66,
    "cross_phase_checked": 11,
    "witnesses": [
      {
        "earlier": "MR-R1",
        "later": "MR-R3",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R3",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R1",
        "later": "MR-R4",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R4",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R1",
        "later": "MR-R5",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R5",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R1",
        "later": "MR-R6",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R6",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R1",
        "later": "MR-R7",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R7",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R1",
        "later": "MR-R8",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R8",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R1",
        "later": "MR-R9",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R9",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      }
    ],
    "status": "VIOLATION"
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
    "checked": 144,
    "cross_phase_checked": 36,
    "witnesses": [],
    "status": "PASS"
  }
}
```

## Trial 3

Operations: 60; success: 59; failed: 1; pending: 0.
Complete: True; unresolved writes: [].

```json
{
  "RYW": {
    "checked": 30,
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
    "checked": 66,
    "cross_phase_checked": 20,
    "witnesses": [
      {
        "earlier": "MR-R2",
        "later": "MR-R4",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004",
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R3",
        "later": "MR-R4",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004",
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R5",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004",
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R3",
        "later": "MR-R5",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004",
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R6",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004",
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R3",
        "later": "MR-R6",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004",
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R7",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004",
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R3",
        "later": "MR-R7",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004",
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R8",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004",
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R3",
        "later": "MR-R8",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004",
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R9",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004",
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R3",
        "later": "MR-R9",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004",
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R10",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004",
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R3",
        "later": "MR-R10",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004",
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R11",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004",
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R3",
        "later": "MR-R11",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004",
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R12",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004",
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R3",
        "later": "MR-R12",
        "missing": [
          "bg:0000000000000003",
          "bg:0000000000000004",
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      }
    ],
    "status": "VIOLATION"
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
    "checked": 144,
    "cross_phase_checked": 36,
    "witnesses": [],
    "status": "PASS"
  }
}
```

## Trial 4

Operations: 60; success: 59; failed: 1; pending: 0.
Complete: True; unresolved writes: [].

```json
{
  "RYW": {
    "checked": 30,
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
    "checked": 66,
    "cross_phase_checked": 20,
    "witnesses": [
      {
        "earlier": "MR-R2",
        "later": "MR-R4",
        "missing": [
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R3",
        "later": "MR-R4",
        "missing": [
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R5",
        "missing": [
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R3",
        "later": "MR-R5",
        "missing": [
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R6",
        "missing": [
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R3",
        "later": "MR-R6",
        "missing": [
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R7",
        "missing": [
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R3",
        "later": "MR-R7",
        "missing": [
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R8",
        "missing": [
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R3",
        "later": "MR-R8",
        "missing": [
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R9",
        "missing": [
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R3",
        "later": "MR-R9",
        "missing": [
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R10",
        "missing": [
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R3",
        "later": "MR-R10",
        "missing": [
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R11",
        "missing": [
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R3",
        "later": "MR-R11",
        "missing": [
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R12",
        "missing": [
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R3",
        "later": "MR-R12",
        "missing": [
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c"
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
        "earlier": "MW-W2",
        "later": "MW-W4",
        "missing": [
          "fg:MW-W2"
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
        "earlier": "MW-W2",
        "later": "MW-W5",
        "missing": [
          "fg:MW-W2"
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
        "earlier": "MW-W2",
        "later": "MW-W6",
        "missing": [
          "fg:MW-W2"
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
        "earlier": "MW-W2",
        "later": "MW-W7",
        "missing": [
          "fg:MW-W2"
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
        "earlier": "MW-W2",
        "later": "MW-W8",
        "missing": [
          "fg:MW-W2"
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
        "earlier": "MW-W2",
        "later": "MW-W9",
        "missing": [
          "fg:MW-W2"
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
        "earlier": "MW-W2",
        "later": "MW-W10",
        "missing": [
          "fg:MW-W2"
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
        "earlier": "MW-W2",
        "later": "MW-W11",
        "missing": [
          "fg:MW-W2"
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
      },
      {
        "earlier": "MW-W2",
        "later": "MW-W12",
        "missing": [
          "fg:MW-W2"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      }
    ],
    "status": "VIOLATION"
  },
  "WFR": {
    "checked": 144,
    "cross_phase_checked": 36,
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
    "checked": 30,
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
    "checked": 66,
    "cross_phase_checked": 20,
    "witnesses": [
      {
        "earlier": "MR-R1",
        "later": "MR-R2",
        "missing": [
          "bg:0000000000000004",
          "bg:0000000000000005"
        ],
        "earlier_phase": "before",
        "later_phase": "before"
      },
      {
        "earlier": "MR-R1",
        "later": "MR-R3",
        "missing": [
          "bg:0000000000000004",
          "bg:0000000000000005"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R1",
        "later": "MR-R4",
        "missing": [
          "bg:0000000000000004",
          "bg:0000000000000005"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R1",
        "later": "MR-R5",
        "missing": [
          "bg:0000000000000004",
          "bg:0000000000000005"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R1",
        "later": "MR-R6",
        "missing": [
          "bg:0000000000000004",
          "bg:0000000000000005"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R1",
        "later": "MR-R7",
        "missing": [
          "bg:0000000000000004",
          "bg:0000000000000005"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R1",
        "later": "MR-R8",
        "missing": [
          "bg:0000000000000004",
          "bg:0000000000000005"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R1",
        "later": "MR-R9",
        "missing": [
          "bg:0000000000000004",
          "bg:0000000000000005"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R1",
        "later": "MR-R10",
        "missing": [
          "bg:0000000000000004",
          "bg:0000000000000005"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R1",
        "later": "MR-R11",
        "missing": [
          "bg:0000000000000004",
          "bg:0000000000000005"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R1",
        "later": "MR-R12",
        "missing": [
          "bg:0000000000000004",
          "bg:0000000000000005"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      }
    ],
    "status": "VIOLATION"
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
    "checked": 144,
    "cross_phase_checked": 36,
    "witnesses": [],
    "status": "PASS"
  }
}
```
