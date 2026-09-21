# node-isolation / C02 — continuous history

Raw history: [node-isolation.jsonl](node-isolation.jsonl)

All four properties use the same history. PASS refers only to checked relations.
Faults run on an independent timer. Phases are host-observed invocation phases.
Schedule: [node-isolation.schedule.json](node-isolation.schedule.json)
Rollback of an acknowledged/observed append counts as loss.

```json
{
  "scenario": "node-isolation",
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
  "output": "results/raw/formal-old-workload-current-ids-v1/C02/node-isolation.md",
  "keep_fault": false,
  "inner": false,
  "trial_id": null
}
```

| Trial | Property | Status | Checked | Cross-phase | Witnesses |
| --- | --- | --- | --- | --- | --- |
| 1 | RYW | PASS | 24 | 4 | 0 |
| 1 | MR | PASS | 3 | 0 | 0 |
| 1 | MW | PASS | 66 | 0 | 0 |
| 1 | WFR | PASS | 60 | 0 | 0 |
| 2 | RYW | PASS | 30 | 5 | 0 |
| 2 | MR | PASS | 6 | 0 | 0 |
| 2 | MW | PASS | 66 | 11 | 0 |
| 2 | WFR | PASS | 48 | 24 | 0 |
| 3 | RYW | PASS | 18 | 6 | 0 |
| 3 | MR | PASS | 28 | 12 | 0 |
| 3 | MW | PASS | 66 | 11 | 0 |
| 3 | WFR | PASS | 60 | 0 | 0 |
| 4 | RYW | PASS | 6 | 1 | 0 |
| 4 | MR | PASS | 21 | 6 | 0 |
| 4 | MW | PASS | 66 | 11 | 0 |
| 4 | WFR | PASS | 36 | 12 | 0 |
| 5 | RYW | PASS | 18 | 3 | 0 |
| 5 | MR | PASS | 28 | 7 | 0 |
| 5 | MW | PASS | 66 | 11 | 0 |
| 5 | WFR | PASS | 60 | 24 | 0 |

## Trial 1

Operations: 60; success: 48; failed: 12; pending: 0.
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
    "checked": 3,
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
    "checked": 60,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  }
}
```

## Trial 2

Operations: 60; success: 45; failed: 15; pending: 0.
Complete: True; unresolved writes: [].

```json
{
  "RYW": {
    "checked": 30,
    "cross_phase_checked": 5,
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
    "checked": 48,
    "cross_phase_checked": 24,
    "witnesses": [],
    "status": "PASS"
  }
}
```

## Trial 3

Operations: 60; success: 49; failed: 11; pending: 0.
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
    "checked": 28,
    "cross_phase_checked": 12,
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
    "checked": 60,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  }
}
```

## Trial 4

Operations: 60; success: 42; failed: 18; pending: 0.
Complete: True; unresolved writes: [].

```json
{
  "RYW": {
    "checked": 6,
    "cross_phase_checked": 1,
    "witnesses": [],
    "status": "PASS"
  },
  "MR": {
    "checked": 21,
    "cross_phase_checked": 6,
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
    "checked": 36,
    "cross_phase_checked": 12,
    "witnesses": [],
    "status": "PASS"
  }
}
```

## Trial 5

Operations: 60; success: 46; failed: 14; pending: 0.
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
    "checked": 28,
    "cross_phase_checked": 7,
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
    "checked": 60,
    "cross_phase_checked": 24,
    "witnesses": [],
    "status": "PASS"
  }
}
```
