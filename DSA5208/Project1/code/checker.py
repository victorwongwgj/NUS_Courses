"""Classify four client-centric properties from a completed event history.

The workload only appends uniquely named markers, so a later completed
operation must retain the markers required by its earlier dependency. A
missing marker is direct violation evidence. Failed writes remain unresolved
until the post-recovery audit determines their final effect. PASS therefore
describes the relations checked in one realised history, not a universal
MongoDB guarantee.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def check_history(events: list[dict]) -> dict:
    properties = {name: {"checked": 0, "cross_phase_checked": 0, "witnesses": []}
                  for name in ("RYW", "MR", "MW", "WFR")}
    writes, reads = [], []
    probe_writes = {name: [] for name in ("ryw", "mr", "mw", "wfr")}
    probe_reads = {name: [] for name in ("ryw", "mr", "mw", "wfr")}
    operations = [e for e in events if e.get("event") == "operation"]
    completed = {e["operation_id"] for e in operations}
    pending = [e for e in events if e.get("event") == "invocation"
               and e["operation_id"] not in completed]
    unresolved = [e["operation_id"] for e in operations
                  if e["kind"] == "write" and e["status"] != "success"]
    unresolved += [e["operation_id"] for e in pending if e["kind"] == "write"]
    resolved = {}
    audits = [e for e in events if e.get("event") == "post_recovery_audit"]
    if audits:
        members = audits[-1].get("members", {})
        histories = []
        for value in members.values():
            if value.get("status") != "success":
                continue
            documents = value.get("documents")
            # Older schema-3 histories stored one combined history rather than
            # the current per-property document map. Supporting both formats
            # keeps the offline checker usable on every retained formal run.
            if documents is None:
                histories.append(set(value.get("history", [])))
            else:
                histories.append({
                    marker
                    for document in documents.values()
                    for marker in (document.get("history", [])
                                   if isinstance(document, dict) else document)
                })
        audit_complete = len(histories) == 3
        if audit_complete:
            still_unresolved = []
            for marker in unresolved:
                present = [marker in history for history in histories]
                if all(present):
                    resolved[marker] = "applied_unacknowledged"
                elif not any(present):
                    resolved[marker] = "not_present_after_recovery"
                else:
                    still_unresolved.append(marker)
            unresolved = still_unresolved

    def tokens(document):
        doc = document or {}
        return ({f"fg:{m}" for m in doc.get("history", [])}
                | {f"bg:{m}" for m in doc.get("background_history", [])})

    def compare(name, previous, current, required, observed):
        if not required:
            return
        result = properties[name]
        result["checked"] += 1
        result["cross_phase_checked"] += previous.get("phase") != current.get("phase")
        missing = sorted(required - observed)
        if missing:
            result["witnesses"].append({
                "earlier": previous["operation_id"], "later": current["operation_id"],
                "missing": missing, "earlier_phase": previous.get("phase"),
                "later_phase": current.get("phase")})

    for current in operations:
        if current["status"] != "success":
            continue
        observed = tokens(current.get("result"))
        probe = current.get("probe")
        if probe:
            if current["kind"] == "read":
                if probe == "ryw":
                    for earlier in probe_writes[probe]:
                        compare("RYW", earlier, current,
                                {f"fg:{earlier['marker']}"}, observed)
                elif probe == "mr":
                    for earlier in probe_reads[probe]:
                        compare("MR", earlier, current,
                                tokens(earlier.get("result")), observed)
                probe_reads[probe].append(current)
            else:
                if current.get("result") is None:
                    continue
                if probe == "mw":
                    for earlier in probe_writes[probe]:
                        compare("MW", earlier, current,
                                {f"fg:{earlier['marker']}"}, observed)
                elif probe == "wfr":
                    for earlier in probe_reads[probe]:
                        compare("WFR", earlier, current,
                                tokens(earlier.get("result")), observed)
                probe_writes[probe].append(current)
            continue
        if current["kind"] == "read":
            for earlier in writes:
                compare("RYW", earlier, current, {f"fg:{earlier['marker']}"}, observed)
            for earlier in reads:
                compare("MR", earlier, current, tokens(earlier.get("result")), observed)
            reads.append(current)
        else:
            # A missing pre-image means findAndModify matched no document. It
            # cannot demonstrate that the requested write was applied, so it
            # must not create an MW or WFR comparison relation.
            if current.get("result") is None:
                continue
            for earlier in writes:
                compare("MW", earlier, current, {f"fg:{earlier['marker']}"}, observed)
            for earlier in reads:
                compare("WFR", earlier, current, tokens(earlier.get("result")), observed)
            writes.append(current)
    complete = (any(e.get("event") == "history_complete" for e in events)
                and not any(e.get("event") in {"runner_error", "controller_error"}
                            for e in events))
    for value in properties.values():
        value["status"] = ("VIOLATION" if value["witnesses"] else
                           "INCONCLUSIVE" if not value["checked"] or unresolved or not complete
                           else "PASS")
    return {"properties": properties, "history_complete": complete,
            "operations": len(operations),
            "successful": sum(e["status"] == "success" for e in operations),
            "failed": sum(e["status"] != "success" for e in operations),
            "pending": len(pending), "unresolved_writes": unresolved,
            "resolved_writes": resolved}


def read_histories(path: Path) -> dict:
    histories = {}
    for line in path.read_text().splitlines():
        event = json.loads(line)
        if event.get("trial_id"):
            histories.setdefault(event["trial_id"], []).append(event)
    return histories


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Recheck saved JSONL histories without MongoDB")
    parser.add_argument("history", type=Path)
    args = parser.parse_args()
    print(json.dumps({key: check_history(events)
                      for key, events in read_histories(args.history).items()}, indent=2))
