# node-isolation / C08 — continuous history

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
  "output": "results/raw/formal-old-workload-current-ids-v1/C08/node-isolation.md",
  "keep_fault": false,
  "inner": false,
  "trial_id": null
}
```

| Trial | Property | Status | Checked | Cross-phase | Witnesses |
| --- | --- | --- | --- | --- | --- |
| 1 | RYW | PASS | 18 | 3 | 0 |
| 1 | MR | PASS | 15 | 0 | 0 |
| 1 | MW | PASS | 66 | 0 | 0 |
| 1 | WFR | PASS | 36 | 0 | 0 |
| 2 | RYW | PASS | 24 | 4 | 0 |
| 2 | MR | PASS | 6 | 0 | 0 |
| 2 | MW | PASS | 66 | 11 | 0 |
| 2 | WFR | PASS | 12 | 0 | 0 |
| 3 | RYW | PASS | 12 | 4 | 0 |
| 3 | MR | PASS | 3 | 0 | 0 |
| 3 | MW | PASS | 66 | 11 | 0 |
| 3 | WFR | PASS | 12 | 0 | 0 |
| 4 | RYW | PASS | 18 | 6 | 0 |
| 4 | MR | PASS | 10 | 0 | 0 |
| 4 | MW | PASS | 66 | 20 | 0 |
| 4 | WFR | PASS | 24 | 0 | 0 |
| 5 | RYW | PASS | 18 | 6 | 0 |
| 5 | MR | PASS | 6 | 0 | 0 |
| 5 | MW | PASS | 66 | 11 | 0 |
| 5 | WFR | PASS | 24 | 0 | 0 |

## Trial 1

Operations: 60; success: 50; failed: 10; pending: 0.
Complete: True; unresolved writes: [].

```json
{
  "RYW": {
    "checked": 18,
    "cross_phase_checked": 3,
    "witnesses": [],
    "status": "PASS"
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
    "witnesses": [],
    "status": "PASS"
  },
  "WFR": {
    "checked": 36,
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
    "checked": 24,
    "cross_phase_checked": 4,
    "witnesses": [],
    "status": "PASS"
  },
  "MR": {
    "checked": 6,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  },
  "MW": {
    "checked": 66,
    "cross_phase_checked": 11,
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

## Trial 3

Operations: 60; success: 54; failed: 6; pending: 0.
Complete: True; unresolved writes: [].

```json
{
  "RYW": {
    "checked": 12,
    "cross_phase_checked": 4,
    "witnesses": [],
    "status": "PASS"
  },
  "MR": {
    "checked": 3,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  },
  "MW": {
    "checked": 66,
    "cross_phase_checked": 11,
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

## Trial 4

Operations: 60; success: 54; failed: 6; pending: 0.
Complete: True; unresolved writes: [].

```json
{
  "RYW": {
    "checked": 18,
    "cross_phase_checked": 6,
    "witnesses": [],
    "status": "PASS"
  },
  "MR": {
    "checked": 10,
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
    "checked": 24,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  }
}
```

## Trial 5

Operations: 60; success: 52; failed: 8; pending: 0.
Complete: True; unresolved writes: [].

```json
{
  "RYW": {
    "checked": 18,
    "cross_phase_checked": 6,
    "witnesses": [],
    "status": "PASS"
  },
  "MR": {
    "checked": 6,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  },
  "MW": {
    "checked": 66,
    "cross_phase_checked": 11,
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
