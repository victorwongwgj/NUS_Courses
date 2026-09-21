# node-isolation / C20 — continuous history

Raw history: [node-isolation.jsonl](node-isolation.jsonl)

All four properties use the same history. PASS refers only to checked relations.
Faults run on an independent timer. Phases are host-observed invocation phases.
Schedule: [node-isolation.schedule.json](node-isolation.schedule.json)
Rollback of an acknowledged/observed append counts as loss.

```json
{
  "scenario": "node-isolation",
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
  "output": "results/raw/formal-old-workload-current-ids-v1/C20/node-isolation.md",
  "keep_fault": false,
  "inner": false,
  "trial_id": null
}
```

| Trial | Property | Status | Checked | Cross-phase | Witnesses |
| --- | --- | --- | --- | --- | --- |
| 1 | RYW | VIOLATION | 36 | 6 | 36 |
| 1 | MR | VIOLATION | 16 | 0 | 6 |
| 1 | MW | PASS | 66 | 0 | 0 |
| 1 | WFR | PASS | 12 | 0 | 0 |
| 2 | RYW | VIOLATION | 36 | 6 | 32 |
| 2 | MR | VIOLATION | 18 | 0 | 8 |
| 2 | MW | PASS | 66 | 11 | 0 |
| 2 | WFR | PASS | 48 | 0 | 0 |
| 3 | RYW | VIOLATION | 36 | 12 | 30 |
| 3 | MR | VIOLATION | 11 | 0 | 8 |
| 3 | MW | PASS | 66 | 11 | 0 |
| 3 | WFR | INCONCLUSIVE | 0 | 0 | 0 |
| 4 | RYW | VIOLATION | 36 | 12 | 28 |
| 4 | MR | VIOLATION | 23 | 0 | 8 |
| 4 | MW | PASS | 66 | 20 | 0 |
| 4 | WFR | PASS | 24 | 0 | 0 |
| 5 | RYW | VIOLATION | 36 | 12 | 34 |
| 5 | MR | VIOLATION | 20 | 0 | 10 |
| 5 | MW | PASS | 66 | 11 | 0 |
| 5 | WFR | INCONCLUSIVE | 0 | 0 | 0 |

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
    "checked": 16,
    "cross_phase_checked": 0,
    "witnesses": [
      {
        "earlier": "MR-R6",
        "later": "MR-R8",
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
          "bg:000000000000000e",
          "bg:000000000000000f",
          "bg:0000000000000010",
          "bg:0000000000000011"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R7",
        "later": "MR-R8",
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
        "earlier": "MR-R6",
        "later": "MR-R11",
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
          "bg:000000000000000e",
          "bg:000000000000000f",
          "bg:0000000000000010",
          "bg:0000000000000011"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R7",
        "later": "MR-R11",
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
        "earlier": "MR-R9",
        "later": "MR-R11",
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
        "earlier": "MR-R10",
        "later": "MR-R11",
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
          "bg:0000000000000023",
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
          "bg:0000000000000039",
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
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  },
  "WFR": {
    "checked": 12,
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
    "checked": 18,
    "cross_phase_checked": 0,
    "witnesses": [
      {
        "earlier": "MR-R5",
        "later": "MR-R6",
        "missing": [
          "bg:0000000000000001",
          "bg:0000000000000002",
          "bg:0000000000000003",
          "bg:0000000000000004",
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007",
          "bg:0000000000000008"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R5",
        "later": "MR-R9",
        "missing": [
          "bg:0000000000000001",
          "bg:0000000000000002",
          "bg:0000000000000003",
          "bg:0000000000000004",
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007",
          "bg:0000000000000008"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R7",
        "later": "MR-R9",
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
          "bg:0000000000000023",
          "bg:0000000000000024",
          "bg:0000000000000025",
          "bg:0000000000000026",
          "bg:0000000000000027",
          "bg:0000000000000028",
          "bg:0000000000000029",
          "bg:000000000000002a",
          "bg:000000000000002b"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R8",
        "later": "MR-R9",
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
          "bg:0000000000000023",
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
          "bg:0000000000000039",
          "bg:000000000000003a",
          "bg:000000000000003b",
          "bg:000000000000003c",
          "bg:000000000000003d",
          "bg:000000000000003e",
          "bg:000000000000003f",
          "bg:0000000000000040",
          "bg:0000000000000041",
          "bg:0000000000000042",
          "bg:0000000000000043",
          "bg:0000000000000044",
          "bg:0000000000000045",
          "bg:0000000000000046",
          "bg:0000000000000047",
          "bg:0000000000000048",
          "bg:0000000000000049",
          "bg:000000000000004a",
          "bg:000000000000004b",
          "bg:000000000000004c",
          "bg:000000000000004d",
          "bg:000000000000004e",
          "bg:000000000000004f",
          "bg:0000000000000050",
          "bg:0000000000000051",
          "bg:0000000000000052",
          "bg:0000000000000053",
          "bg:0000000000000054",
          "bg:0000000000000055",
          "bg:0000000000000056",
          "bg:0000000000000057",
          "bg:0000000000000058",
          "bg:0000000000000059",
          "bg:000000000000005a",
          "bg:000000000000005b"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R5",
        "later": "MR-R11",
        "missing": [
          "bg:0000000000000001",
          "bg:0000000000000002",
          "bg:0000000000000003",
          "bg:0000000000000004",
          "bg:0000000000000005",
          "bg:0000000000000006",
          "bg:0000000000000007",
          "bg:0000000000000008"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R7",
        "later": "MR-R11",
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
          "bg:0000000000000023",
          "bg:0000000000000024",
          "bg:0000000000000025",
          "bg:0000000000000026",
          "bg:0000000000000027",
          "bg:0000000000000028",
          "bg:0000000000000029",
          "bg:000000000000002a",
          "bg:000000000000002b"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R8",
        "later": "MR-R11",
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
          "bg:0000000000000023",
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
          "bg:0000000000000039",
          "bg:000000000000003a",
          "bg:000000000000003b",
          "bg:000000000000003c",
          "bg:000000000000003d",
          "bg:000000000000003e",
          "bg:000000000000003f",
          "bg:0000000000000040",
          "bg:0000000000000041",
          "bg:0000000000000042",
          "bg:0000000000000043",
          "bg:0000000000000044",
          "bg:0000000000000045",
          "bg:0000000000000046",
          "bg:0000000000000047",
          "bg:0000000000000048",
          "bg:0000000000000049",
          "bg:000000000000004a",
          "bg:000000000000004b",
          "bg:000000000000004c",
          "bg:000000000000004d",
          "bg:000000000000004e",
          "bg:000000000000004f",
          "bg:0000000000000050",
          "bg:0000000000000051",
          "bg:0000000000000052",
          "bg:0000000000000053",
          "bg:0000000000000054",
          "bg:0000000000000055",
          "bg:0000000000000056",
          "bg:0000000000000057",
          "bg:0000000000000058",
          "bg:0000000000000059",
          "bg:000000000000005a",
          "bg:000000000000005b"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R10",
        "later": "MR-R11",
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
          "bg:0000000000000023",
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
          "bg:0000000000000039",
          "bg:000000000000003a",
          "bg:000000000000003b",
          "bg:000000000000003c",
          "bg:000000000000003d",
          "bg:000000000000003e",
          "bg:000000000000003f",
          "bg:0000000000000040",
          "bg:0000000000000041",
          "bg:0000000000000042",
          "bg:0000000000000043",
          "bg:0000000000000044",
          "bg:0000000000000045",
          "bg:0000000000000046",
          "bg:0000000000000047",
          "bg:0000000000000048",
          "bg:0000000000000049",
          "bg:000000000000004a",
          "bg:000000000000004b",
          "bg:000000000000004c",
          "bg:000000000000004d",
          "bg:000000000000004e",
          "bg:000000000000004f",
          "bg:0000000000000050",
          "bg:0000000000000051",
          "bg:0000000000000052",
          "bg:0000000000000053",
          "bg:0000000000000054",
          "bg:0000000000000055",
          "bg:0000000000000056",
          "bg:0000000000000057",
          "bg:0000000000000058",
          "bg:0000000000000059",
          "bg:000000000000005a",
          "bg:000000000000005b",
          "bg:000000000000005c",
          "bg:000000000000005d",
          "bg:000000000000005e",
          "bg:000000000000005f",
          "bg:0000000000000060",
          "bg:0000000000000061",
          "bg:0000000000000062",
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
          "bg:0000000000000074"
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
    "checked": 48,
    "cross_phase_checked": 0,
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
    "checked": 11,
    "cross_phase_checked": 0,
    "witnesses": [
      {
        "earlier": "MR-R7",
        "later": "MR-R9",
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
          "bg:000000000000000e",
          "bg:000000000000000f",
          "bg:0000000000000010",
          "bg:0000000000000011",
          "bg:0000000000000012",
          "bg:0000000000000013"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R8",
        "later": "MR-R9",
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
          "bg:0000000000000022"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R7",
        "later": "MR-R11",
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
          "bg:000000000000000e",
          "bg:000000000000000f",
          "bg:0000000000000010",
          "bg:0000000000000011",
          "bg:0000000000000012",
          "bg:0000000000000013"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R8",
        "later": "MR-R11",
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
          "bg:0000000000000022"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R10",
        "later": "MR-R11",
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
          "bg:0000000000000023",
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
          "bg:0000000000000039",
          "bg:000000000000003a",
          "bg:000000000000003b",
          "bg:000000000000003c",
          "bg:000000000000003d",
          "bg:000000000000003e",
          "bg:000000000000003f"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R7",
        "later": "MR-R12",
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
          "bg:000000000000000e",
          "bg:000000000000000f",
          "bg:0000000000000010",
          "bg:0000000000000011",
          "bg:0000000000000012",
          "bg:0000000000000013"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R8",
        "later": "MR-R12",
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
          "bg:0000000000000022"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R10",
        "later": "MR-R12",
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
          "bg:0000000000000023",
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
          "bg:0000000000000039",
          "bg:000000000000003a",
          "bg:000000000000003b",
          "bg:000000000000003c",
          "bg:000000000000003d",
          "bg:000000000000003e",
          "bg:000000000000003f"
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
    "checked": 0,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "INCONCLUSIVE"
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
      }
    ],
    "status": "VIOLATION"
  },
  "MR": {
    "checked": 23,
    "cross_phase_checked": 0,
    "witnesses": [
      {
        "earlier": "MR-R5",
        "later": "MR-R9",
        "missing": [
          "bg:0000000000000001",
          "bg:0000000000000002",
          "bg:0000000000000003"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R6",
        "later": "MR-R9",
        "missing": [
          "bg:0000000000000001",
          "bg:0000000000000002",
          "bg:0000000000000003"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R7",
        "later": "MR-R9",
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
          "bg:000000000000001d"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R8",
        "later": "MR-R9",
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
          "bg:0000000000000023",
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
          "bg:0000000000000033"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R5",
        "later": "MR-R10",
        "missing": [
          "bg:0000000000000001",
          "bg:0000000000000002",
          "bg:0000000000000003"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R6",
        "later": "MR-R10",
        "missing": [
          "bg:0000000000000001",
          "bg:0000000000000002",
          "bg:0000000000000003"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R7",
        "later": "MR-R10",
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
          "bg:000000000000001d"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R8",
        "later": "MR-R10",
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
          "bg:0000000000000023",
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
          "bg:0000000000000033"
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
    "checked": 24,
    "cross_phase_checked": 0,
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
    "checked": 20,
    "cross_phase_checked": 0,
    "witnesses": [
      {
        "earlier": "MR-R5",
        "later": "MR-R6",
        "missing": [
          "bg:0000000000000001"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R5",
        "later": "MR-R10",
        "missing": [
          "bg:0000000000000001"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R7",
        "later": "MR-R10",
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
          "bg:000000000000000c"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R8",
        "later": "MR-R10",
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
          "bg:000000000000000c"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R9",
        "later": "MR-R10",
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
          "bg:0000000000000023",
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
          "bg:0000000000000031"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R5",
        "later": "MR-R12",
        "missing": [
          "bg:0000000000000001"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R7",
        "later": "MR-R12",
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
          "bg:000000000000000c"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R8",
        "later": "MR-R12",
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
          "bg:000000000000000c"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R9",
        "later": "MR-R12",
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
          "bg:0000000000000023",
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
          "bg:0000000000000031"
        ],
        "earlier_phase": "during",
        "later_phase": "during"
      },
      {
        "earlier": "MR-R11",
        "later": "MR-R12",
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
          "bg:0000000000000023",
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
          "bg:0000000000000039",
          "bg:000000000000003a",
          "bg:000000000000003b",
          "bg:000000000000003c",
          "bg:000000000000003d",
          "bg:000000000000003e",
          "bg:000000000000003f",
          "bg:0000000000000040",
          "bg:0000000000000041",
          "bg:0000000000000042",
          "bg:0000000000000043",
          "bg:0000000000000044",
          "bg:0000000000000045"
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
    "checked": 0,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "INCONCLUSIVE"
  }
}
```
