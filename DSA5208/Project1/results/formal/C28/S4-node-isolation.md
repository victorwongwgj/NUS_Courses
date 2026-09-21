# S4 node-isolation / C28 — continuous history

Raw history: [S4-node-isolation.jsonl](S4-node-isolation.jsonl)

All four properties use the same history. PASS refers only to checked relations.
Faults run on an independent timer. Phases are host-observed invocation phases.
Schedule: [S4-node-isolation.schedule.json](S4-node-isolation.schedule.json)
Rollback of an acknowledged/observed append counts as loss.

```json
{
  "scenario": "node-isolation",
  "property": "all",
  "read_concern": "majority",
  "write_concern": "3",
  "journal": "on",
  "read_preference": "primary",
  "causal_session": "on",
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
  "output": "results/raw/formal-old-workload-current-ids-v1/C28/S4-node-isolation.md",
  "keep_fault": false,
  "inner": false,
  "trial_id": null
}
```

| Trial | Property | Status | Checked | Cross-phase | Witnesses |
| --- | --- | --- | --- | --- | --- |
| 1 | RYW | INCONCLUSIVE | 0 | 0 | 0 |
| 1 | MR | PASS | 66 | 0 | 0 |
| 1 | MW | INCONCLUSIVE | 0 | 0 | 0 |
| 1 | WFR | INCONCLUSIVE | 0 | 0 | 0 |
| 2 | RYW | INCONCLUSIVE | 0 | 0 | 0 |
| 2 | MR | PASS | 66 | 0 | 0 |
| 2 | MW | INCONCLUSIVE | 0 | 0 | 0 |
| 2 | WFR | INCONCLUSIVE | 0 | 0 | 0 |
| 3 | RYW | INCONCLUSIVE | 0 | 0 | 0 |
| 3 | MR | PASS | 66 | 0 | 0 |
| 3 | MW | INCONCLUSIVE | 0 | 0 | 0 |
| 3 | WFR | INCONCLUSIVE | 0 | 0 | 0 |
| 4 | RYW | INCONCLUSIVE | 0 | 0 | 0 |
| 4 | MR | PASS | 66 | 0 | 0 |
| 4 | MW | INCONCLUSIVE | 0 | 0 | 0 |
| 4 | WFR | INCONCLUSIVE | 0 | 0 | 0 |
| 5 | RYW | INCONCLUSIVE | 0 | 0 | 0 |
| 5 | MR | PASS | 66 | 0 | 0 |
| 5 | MW | INCONCLUSIVE | 0 | 0 | 0 |
| 5 | WFR | INCONCLUSIVE | 0 | 0 | 0 |

## Trial 1

Operations: 60; success: 30; failed: 30; pending: 0.
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
    "checked": 66,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  },
  "MW": {
    "checked": 0,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "INCONCLUSIVE"
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

Operations: 60; success: 30; failed: 30; pending: 0.
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
    "checked": 66,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  },
  "MW": {
    "checked": 0,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "INCONCLUSIVE"
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

Operations: 60; success: 30; failed: 30; pending: 0.
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
    "checked": 66,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  },
  "MW": {
    "checked": 0,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "INCONCLUSIVE"
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

Operations: 60; success: 30; failed: 30; pending: 0.
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
    "checked": 66,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  },
  "MW": {
    "checked": 0,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "INCONCLUSIVE"
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

Operations: 60; success: 30; failed: 30; pending: 0.
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
    "checked": 66,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "PASS"
  },
  "MW": {
    "checked": 0,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "INCONCLUSIVE"
  },
  "WFR": {
    "checked": 0,
    "cross_phase_checked": 0,
    "witnesses": [],
    "status": "INCONCLUSIVE"
  }
}
```
