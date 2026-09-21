"""Control faults from an independent physical-clock schedule.

The foreground client never receives the scenario or injection time. This
keeps the workload identical across scenarios and prevents database responses
from changing when the fault is introduced or healed.
"""
from __future__ import annotations

import random
import threading
import time


def make_schedule(args):
    """Return the same injection plan for a seed across all configurations."""
    rng = random.Random(args.schedule_seed)
    return [{"trial": i + 1,
             "inject_at_seconds": round(rng.uniform(
                 args.fault_start_min_seconds, args.fault_start_max_seconds), 6),
             "recovery_policy": "after_workload"}
            for i in range(args.trials)]


class FaultController(threading.Thread):
    def __init__(self, plan, origin, inject, heal, emit):
        super().__init__(name="fault-controller", daemon=False)
        self.plan, self.origin = plan, origin
        self.inject, self.heal, self.emit = inject, heal, emit
        self.cancelled = threading.Event()
        self.error = None

    def run(self):
        injected = False
        try:
            delay = max(0, self.origin + self.plan["inject_at_seconds"] - time.monotonic())
            if self.cancelled.wait(delay):
                return
            # Record the fault as started before changing Docker state. If
            # injection fails halfway through, the finally block will still
            # remove any partial firewall or container-state change.
            injected = True
            self.emit({"event": "fault_started"})
            self.inject()
            self.emit({"event": "fault_active"})
            # Do not recover after a fixed duration. The host signals this
            # event only after the foreground workload exits or aborts, so a
            # slow request cannot accidentally outwait the experimental fault.
            self.cancelled.wait()
        except Exception as exc:
            self.error = str(exc)
            self.emit({"event": "controller_error", "error": self.error})
        finally:
            if injected:
                try:
                    self.emit({"event": "healing_started"})
                    self.heal()
                    self.emit({"event": "fault_healed"})
                except Exception as exc:
                    self.error = str(exc)
                    self.emit({"event": "controller_error", "error": self.error})
