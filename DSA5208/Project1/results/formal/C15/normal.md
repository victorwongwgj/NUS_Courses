# normal / C15 — continuous history

Raw history: [normal.jsonl](normal.jsonl)

All four properties use the same history. PASS refers only to checked relations.
Faults run on an independent timer. Phases are host-observed invocation phases.
Schedule: [normal.schedule.json](normal.schedule.json)
Rollback of an acknowledged/observed append counts as loss.

```json
{
  "scenario": "normal",
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
  "output": "results/raw/formal-old-workload-current-ids-v1/C15/normal.md",
  "keep_fault": false,
  "inner": false,
  "trial_id": null
}
```

| Trial | Property | Status | Checked | Cross-phase | Witnesses |
| --- | --- | --- | --- | --- | --- |
| 1 | RYW | VIOLATION | 36 | 6 | 6 |
| 1 | MR | VIOLATION | 66 | 11 | 2 |
| 1 | MW | PASS | 66 | 0 | 0 |
| 1 | WFR | PASS | 108 | 0 | 0 |
| 2 | RYW | VIOLATION | 36 | 6 | 4 |
| 2 | MR | VIOLATION | 66 | 11 | 6 |
| 2 | MW | PASS | 66 | 11 | 0 |
| 2 | WFR | PASS | 132 | 24 | 0 |
| 3 | RYW | VIOLATION | 36 | 12 | 19 |
| 3 | MR | VIOLATION | 55 | 10 | 9 |
| 3 | MW | PASS | 66 | 11 | 0 |
| 3 | WFR | PASS | 108 | 0 | 0 |
| 4 | RYW | VIOLATION | 36 | 12 | 8 |
| 4 | MR | VIOLATION | 66 | 20 | 5 |
| 4 | MW | PASS | 66 | 20 | 0 |
| 4 | WFR | PASS | 120 | 12 | 0 |
| 5 | RYW | VIOLATION | 36 | 12 | 21 |
| 5 | MR | VIOLATION | 56 | 10 | 3 |
| 5 | MW | PASS | 66 | 11 | 0 |
| 5 | WFR | PASS | 108 | 12 | 0 |

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
        "earlier": "RYW-W6",
        "later": "RYW-R3",
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
    "checked": 66,
    "cross_phase_checked": 11,
    "witnesses": [
      {
        "earlier": "MR-R3",
        "later": "MR-R4",
        "missing": [
          "bg:000000000000000e",
          "bg:000000000000000f"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R11",
        "later": "MR-R12",
        "missing": [
          "bg:0000000000000102",
          "bg:0000000000000103",
          "bg:0000000000000104",
          "bg:0000000000000105"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      }
    ],
    "status": "VIOLATION"
  },
  "MW": {
    "checked": 66,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  },
  "WFR": {
    "checked": 108,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
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
    "cross_phase_checked": 6,
    "witnesses": [
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
    "checked": 66,
    "cross_phase_checked": 11,
    "witnesses": [
      {
        "earlier": "MR-R1",
        "later": "MR-R2",
        "missing": [
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c",
          "bg:000000000000000d",
          "bg:000000000000000e",
          "bg:000000000000000f"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R4",
        "later": "MR-R5",
        "missing": [
          "bg:0000000000000024",
          "bg:0000000000000025",
          "bg:0000000000000026",
          "bg:0000000000000027",
          "bg:0000000000000028",
          "bg:0000000000000029",
          "bg:000000000000002a",
          "bg:000000000000002b",
          "bg:000000000000002c",
          "bg:000000000000002d",
          "bg:000000000000002e",
          "bg:000000000000002f",
          "bg:0000000000000030",
          "bg:0000000000000031",
          "bg:0000000000000032",
          "bg:0000000000000033",
          "bg:0000000000000034",
          "bg:0000000000000035",
          "bg:0000000000000036",
          "bg:0000000000000037",
          "bg:0000000000000038",
          "bg:0000000000000039"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R6",
        "later": "MR-R7",
        "missing": [
          "bg:0000000000000063",
          "bg:0000000000000064",
          "bg:0000000000000065",
          "bg:0000000000000066",
          "bg:0000000000000067",
          "bg:0000000000000068",
          "bg:0000000000000069",
          "bg:000000000000006a",
          "bg:000000000000006b",
          "bg:000000000000006c",
          "bg:000000000000006d",
          "bg:000000000000006e",
          "bg:000000000000006f",
          "bg:0000000000000070",
          "bg:0000000000000071",
          "bg:0000000000000072",
          "bg:0000000000000073",
          "bg:0000000000000074",
          "bg:0000000000000075",
          "bg:0000000000000076",
          "bg:0000000000000077",
          "bg:0000000000000078",
          "bg:0000000000000079",
          "bg:000000000000007a",
          "bg:000000000000007b",
          "bg:000000000000007c",
          "bg:000000000000007d",
          "bg:000000000000007e",
          "bg:000000000000007f"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R8",
        "later": "MR-R10",
        "missing": [
          "bg:00000000000000af",
          "bg:00000000000000b0"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R9",
        "later": "MR-R10",
        "missing": [
          "bg:00000000000000af",
          "bg:00000000000000b0",
          "bg:00000000000000b1",
          "bg:00000000000000b2",
          "bg:00000000000000b3",
          "bg:00000000000000b4",
          "bg:00000000000000b5",
          "bg:00000000000000b6",
          "bg:00000000000000b7",
          "bg:00000000000000b8",
          "bg:00000000000000b9",
          "bg:00000000000000ba",
          "bg:00000000000000bb",
          "bg:00000000000000bc",
          "bg:00000000000000bd",
          "bg:00000000000000be"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R11",
        "later": "MR-R12",
        "missing": [
          "bg:00000000000000d5",
          "bg:00000000000000d6",
          "bg:00000000000000d7",
          "bg:00000000000000d8",
          "bg:00000000000000d9",
          "bg:00000000000000da",
          "bg:00000000000000db",
          "bg:00000000000000dc",
          "bg:00000000000000dd",
          "bg:00000000000000de",
          "bg:00000000000000df",
          "bg:00000000000000e0",
          "bg:00000000000000e1",
          "bg:00000000000000e2",
          "bg:00000000000000e3",
          "bg:00000000000000e4",
          "bg:00000000000000e5"
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
    "witnesses": [],
    "status": "PASS"
  },
  "WFR": {
    "checked": 132,
    "cross_phase_checked": 24,
    "witnesses": [],
    "status": "PASS"
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
    "checked": 55,
    "cross_phase_checked": 10,
    "witnesses": [
      {
        "earlier": "MR-R2",
        "later": "MR-R4",
        "missing": [
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c",
          "bg:000000000000000d",
          "bg:000000000000000e",
          "bg:000000000000000f",
          "bg:0000000000000010",
          "bg:0000000000000011",
          "bg:0000000000000012",
          "bg:0000000000000013",
          "bg:0000000000000014",
          "bg:0000000000000015",
          "bg:0000000000000016",
          "bg:0000000000000017",
          "bg:0000000000000018"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R3",
        "later": "MR-R4",
        "missing": [
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c",
          "bg:000000000000000d",
          "bg:000000000000000e",
          "bg:000000000000000f",
          "bg:0000000000000010",
          "bg:0000000000000011",
          "bg:0000000000000012",
          "bg:0000000000000013",
          "bg:0000000000000014",
          "bg:0000000000000015",
          "bg:0000000000000016",
          "bg:0000000000000017",
          "bg:0000000000000018",
          "bg:0000000000000019",
          "bg:000000000000001a",
          "bg:000000000000001b",
          "bg:000000000000001c",
          "bg:000000000000001d",
          "bg:000000000000001e",
          "bg:000000000000001f",
          "bg:0000000000000020",
          "bg:0000000000000021",
          "bg:0000000000000022",
          "bg:0000000000000023"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R5",
        "missing": [
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c",
          "bg:000000000000000d",
          "bg:000000000000000e",
          "bg:000000000000000f",
          "bg:0000000000000010",
          "bg:0000000000000011",
          "bg:0000000000000012",
          "bg:0000000000000013",
          "bg:0000000000000014",
          "bg:0000000000000015",
          "bg:0000000000000016",
          "bg:0000000000000017",
          "bg:0000000000000018"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R3",
        "later": "MR-R5",
        "missing": [
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c",
          "bg:000000000000000d",
          "bg:000000000000000e",
          "bg:000000000000000f",
          "bg:0000000000000010",
          "bg:0000000000000011",
          "bg:0000000000000012",
          "bg:0000000000000013",
          "bg:0000000000000014",
          "bg:0000000000000015",
          "bg:0000000000000016",
          "bg:0000000000000017",
          "bg:0000000000000018",
          "bg:0000000000000019",
          "bg:000000000000001a",
          "bg:000000000000001b",
          "bg:000000000000001c",
          "bg:000000000000001d",
          "bg:000000000000001e",
          "bg:000000000000001f",
          "bg:0000000000000020",
          "bg:0000000000000021",
          "bg:0000000000000022",
          "bg:0000000000000023"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R6",
        "missing": [
          "bg:0000000000000010",
          "bg:0000000000000011",
          "bg:0000000000000012",
          "bg:0000000000000013",
          "bg:0000000000000014",
          "bg:0000000000000015",
          "bg:0000000000000016",
          "bg:0000000000000017",
          "bg:0000000000000018"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R3",
        "later": "MR-R6",
        "missing": [
          "bg:0000000000000010",
          "bg:0000000000000011",
          "bg:0000000000000012",
          "bg:0000000000000013",
          "bg:0000000000000014",
          "bg:0000000000000015",
          "bg:0000000000000016",
          "bg:0000000000000017",
          "bg:0000000000000018",
          "bg:0000000000000019",
          "bg:000000000000001a",
          "bg:000000000000001b",
          "bg:000000000000001c",
          "bg:000000000000001d",
          "bg:000000000000001e",
          "bg:000000000000001f",
          "bg:0000000000000020",
          "bg:0000000000000021",
          "bg:0000000000000022",
          "bg:0000000000000023"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R7",
        "missing": [
          "bg:0000000000000014",
          "bg:0000000000000015",
          "bg:0000000000000016",
          "bg:0000000000000017",
          "bg:0000000000000018"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R3",
        "later": "MR-R7",
        "missing": [
          "bg:0000000000000014",
          "bg:0000000000000015",
          "bg:0000000000000016",
          "bg:0000000000000017",
          "bg:0000000000000018",
          "bg:0000000000000019",
          "bg:000000000000001a",
          "bg:000000000000001b",
          "bg:000000000000001c",
          "bg:000000000000001d",
          "bg:000000000000001e",
          "bg:000000000000001f",
          "bg:0000000000000020",
          "bg:0000000000000021",
          "bg:0000000000000022",
          "bg:0000000000000023"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R10",
        "later": "MR-R11",
        "missing": [
          "bg:0000000000000069",
          "bg:000000000000006a",
          "bg:000000000000006b",
          "bg:000000000000006c",
          "bg:000000000000006d",
          "bg:000000000000006e",
          "bg:000000000000006f",
          "bg:0000000000000070",
          "bg:0000000000000071",
          "bg:0000000000000072",
          "bg:0000000000000073",
          "bg:0000000000000074",
          "bg:0000000000000075",
          "bg:0000000000000076",
          "bg:0000000000000077",
          "bg:0000000000000078",
          "bg:0000000000000079",
          "bg:000000000000007a",
          "bg:000000000000007b",
          "bg:000000000000007c",
          "bg:000000000000007d",
          "bg:000000000000007e",
          "bg:000000000000007f",
          "bg:0000000000000080",
          "bg:0000000000000081",
          "bg:0000000000000082",
          "bg:0000000000000083",
          "bg:0000000000000084",
          "bg:0000000000000085",
          "bg:0000000000000086",
          "bg:0000000000000087",
          "bg:0000000000000088",
          "bg:0000000000000089",
          "bg:000000000000008a",
          "bg:000000000000008b",
          "bg:000000000000008c",
          "bg:000000000000008d",
          "bg:000000000000008e",
          "bg:000000000000008f",
          "bg:0000000000000090",
          "bg:0000000000000091",
          "bg:0000000000000092",
          "bg:0000000000000093",
          "bg:0000000000000094",
          "bg:0000000000000095",
          "bg:0000000000000096",
          "bg:0000000000000097",
          "bg:0000000000000098",
          "bg:0000000000000099",
          "bg:000000000000009a",
          "bg:000000000000009b",
          "bg:000000000000009c",
          "bg:000000000000009d",
          "bg:000000000000009e",
          "bg:000000000000009f",
          "bg:00000000000000a0",
          "bg:00000000000000a1",
          "bg:00000000000000a2",
          "bg:00000000000000a3",
          "bg:00000000000000a4"
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
    "witnesses": [],
    "status": "PASS"
  },
  "WFR": {
    "checked": 108,
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
        "later": "MR-R3",
        "missing": [
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c",
          "bg:000000000000000d",
          "bg:000000000000000e",
          "bg:000000000000000f",
          "bg:0000000000000010",
          "bg:0000000000000011",
          "bg:0000000000000012",
          "bg:0000000000000013"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R3",
        "missing": [
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c",
          "bg:000000000000000d",
          "bg:000000000000000e",
          "bg:000000000000000f",
          "bg:0000000000000010",
          "bg:0000000000000011",
          "bg:0000000000000012",
          "bg:0000000000000013",
          "bg:0000000000000014",
          "bg:0000000000000015",
          "bg:0000000000000016",
          "bg:0000000000000017",
          "bg:0000000000000018",
          "bg:0000000000000019"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R4",
        "missing": [
          "bg:0000000000000015",
          "bg:0000000000000016",
          "bg:0000000000000017",
          "bg:0000000000000018",
          "bg:0000000000000019"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R2",
        "later": "MR-R5",
        "missing": [
          "bg:0000000000000015",
          "bg:0000000000000016",
          "bg:0000000000000017",
          "bg:0000000000000018",
          "bg:0000000000000019"
        ],
        "earlier_phase": "before",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R11",
        "later": "MR-R12",
        "missing": [
          "bg:00000000000000ac",
          "bg:00000000000000ad",
          "bg:00000000000000ae",
          "bg:00000000000000af",
          "bg:00000000000000b0",
          "bg:00000000000000b1",
          "bg:00000000000000b2",
          "bg:00000000000000b3",
          "bg:00000000000000b4",
          "bg:00000000000000b5",
          "bg:00000000000000b6",
          "bg:00000000000000b7",
          "bg:00000000000000b8",
          "bg:00000000000000b9",
          "bg:00000000000000ba",
          "bg:00000000000000bb",
          "bg:00000000000000bc",
          "bg:00000000000000bd",
          "bg:00000000000000be",
          "bg:00000000000000bf"
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
    "checked": 120,
    "cross_phase_checked": 12,
    "witnesses": [],
    "status": "PASS"
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
        "earlier": "RYW-W6",
        "later": "RYW-R5",
        "missing": [
          "fg:RYW-W6"
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
    "checked": 56,
    "cross_phase_checked": 10,
    "witnesses": [
      {
        "earlier": "MR-R1",
        "later": "MR-R2",
        "missing": [
          "bg:0000000000000001",
          "bg:0000000000000002",
          "bg:0000000000000003",
          "bg:0000000000000004",
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007",
          "bg:0000000000000008",
          "bg:0000000000000009",
          "bg:000000000000000a",
          "bg:000000000000000b",
          "bg:000000000000000c",
          "bg:000000000000000d",
          "bg:000000000000000e"
        ],
        "earlier_phase": "before",
        "later_phase": "before"
      },
      {
        "earlier": "MR-R5",
        "later": "MR-R6",
        "missing": [
          "bg:0000000000000014",
          "bg:0000000000000015"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R9",
        "later": "MR-R10",
        "missing": [
          "bg:000000000000003a",
          "bg:000000000000003b"
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
    "witnesses": [],
    "status": "PASS"
  },
  "WFR": {
    "checked": 108,
    "cross_phase_checked": 12,
    "witnesses": [],
    "status": "PASS"
  }
}
```
