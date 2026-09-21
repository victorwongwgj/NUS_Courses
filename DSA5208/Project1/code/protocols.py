"""Collect one continuous client history; classification is performed offline."""

from __future__ import annotations

import argparse
import json
import random
import threading
import time
from contextlib import ExitStack
from datetime import datetime, timezone
from typing import Any, Callable

from utils import SERVICES, configuration_id, scenario_id

def inner_main(args: argparse.Namespace) -> int:
    """Run the identical read/write schedule for every scenario."""
    from pymongo import MongoClient, ReadPreference, ReturnDocument, monitoring, timeout
    from pymongo.errors import PyMongoError
    from pymongo.read_concern import ReadConcern
    from pymongo.write_concern import WriteConcern

    from bson import json_util

    causal = args.causal_session == "on"
    preferences = {
        "primary": ReadPreference.PRIMARY,
        "primaryPreferred": ReadPreference.PRIMARY_PREFERRED,
        "secondary": ReadPreference.SECONDARY,
        "secondaryPreferred": ReadPreference.SECONDARY_PREFERRED,
        "nearest": ReadPreference.NEAREST,
    }

    class Tracker(monitoring.CommandListener):
        """Capture the server selected for the latest measured command."""
        def __init__(self) -> None:
            self.last_connection: str | None = None

        def started(self, event: Any) -> None:
            emit("command", command_name=event.command_name, request_id=event.request_id,
                 served_by=str(event.connection_id), command=event.command)
            if event.command_name in {"find", "insert", "update", "findAndModify"}:
                self.last_connection = str(event.connection_id)

        def succeeded(self, event: Any) -> None:
            pass

        def failed(self, event: Any) -> None:
            pass

    tracker = Tracker()
    client = MongoClient(
        args.uri,
        serverSelectionTimeoutMS=args.write_timeout_ms,
        connectTimeoutMS=args.write_timeout_ms,
        socketTimeoutMS=args.write_timeout_ms,
        retryReads=True,
        retryWrites=True,
        event_listeners=[tracker],
        appname="dsa5208-formal-experiment",
    )
    wc_value: Any = "majority" if args.write_concern == "majority" else int(args.write_concern)
    journal = args.journal == "on"
    collection = client[args.db].get_collection(
        "formal_consistency_trials",
        read_concern=ReadConcern(args.read_concern),
        write_concern=WriteConcern(w=wc_value, j=journal, wtimeout=args.write_timeout_ms),
        read_preference=preferences[args.read_preference],
    )
    setup_collection = client[args.db].get_collection(
        "formal_consistency_trials",
        read_concern=ReadConcern("local"),
        write_concern=WriteConcern(w="majority", j=True, wtimeout=args.write_timeout_ms),
        read_preference=ReadPreference.PRIMARY,
    )
    workload_client: Any = None
    workload_thread: threading.Thread | None = None
    workload_stop = threading.Event()
    workload_counts = {"successful": 0, "failed": 0, "history_successful": 0}

    def emit(event: str, **fields: Any) -> None:
        print(
            json.dumps(
                {
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "event": event,
                    "trial_id": args.trial_id,
                    "property": args.property.upper(),
                    "configuration_id": configuration_id(args),
                    "scenario_id": scenario_id(args.scenario),
                    "read_concern": args.read_concern,
                    "write_concern": args.write_concern,
                    "journal": journal,
                    "read_preference": args.read_preference,
                    "causal_session": causal,
                    **fields,
                },
                default=json_util.default,
            ),
            flush=True,
        )

    def operation(label: str, function: Callable[[], Any], *, session: Any,
                  is_write: bool = False, probe: str | None = None,
                  document_id: str | None = None) -> Any:
        """Time one operation and retain availability/ambiguity evidence."""
        tracker.last_connection = None
        started = time.perf_counter_ns()
        invoked_at = datetime.now(timezone.utc).isoformat()
        emit("invocation", operation_id=label,
             kind="write" if is_write else "read", marker=label if is_write else None,
             probe=probe, document_id=document_id,
             session_id=str(session.session_id), invoked_at=invoked_at,
             topology=[{"address": str(address), "role": description.server_type_name,
                        "rtt": description.round_trip_time}
                       for address, description in
                       client.topology_description.server_descriptions().items()])
        try:
            deadline_ms = args.write_timeout_ms if is_write else args.read_timeout_ms
            with timeout(deadline_ms / 1_000):
                value = function()
            emit(
                "operation",
                operation_id=label,
                kind="write" if is_write else "read",
                marker=label if is_write else None,
                probe=probe, document_id=document_id,
                completed_at=datetime.now(timezone.utc).isoformat(),
                status="success",
                invoked_at=invoked_at,
                latency_ms=round((time.perf_counter_ns() - started) / 1_000_000, 3),
                served_by=tracker.last_connection,
                result=value,
            )
            return value
        except PyMongoError as exc:
            # A timed-out write may have committed despite losing its reply.
            # Classifying it as a consistency violation would be unsound.
            ambiguous = is_write  # Retain failed writes conservatively as unresolved.
            emit(
                "operation",
                operation_id=label,
                kind="write" if is_write else "read",
                marker=label if is_write else None,
                probe=probe, document_id=document_id,
                completed_at=datetime.now(timezone.utc).isoformat(),
                status="ambiguous" if ambiguous else "unavailable",
                invoked_at=invoked_at,
                latency_ms=round((time.perf_counter_ns() - started) / 1_000_000, 3),
                served_by=tracker.last_connection,
                error_type=type(exc).__name__,
                error=str(exc),
            )
            return None

    def wait_all_replicated(required_version: int, document_ids: list[str]) -> None:
        """Wait until every member has the setup version needed by a protocol."""
        deadline = time.monotonic() + args.replication_wait_seconds
        pending = set(SERVICES)
        while pending and time.monotonic() < deadline:
            for service in tuple(pending):
                direct = MongoClient(
                    f"mongodb://{service}-client:27017/?directConnection=true",
                    serverSelectionTimeoutMS=args.timeout_ms,
                    connectTimeoutMS=args.timeout_ms,
                    socketTimeoutMS=args.timeout_ms,
                    retryReads=False,
                )
                try:
                    docs = list(direct[args.db].get_collection(
                        "formal_consistency_trials",
                        read_concern=ReadConcern("local"),
                        read_preference=ReadPreference.SECONDARY_PREFERRED,
                    ).find({"_id": {"$in": document_ids}}))
                    if (len(docs) == len(document_ids)
                            and all(doc.get("version", -1) >= required_version for doc in docs)):
                        pending.remove(service)
                except PyMongoError:
                    pass
                finally:
                    direct.close()
            if pending:
                time.sleep(0.2)
        if pending:
            raise RuntimeError(
                f"version {required_version} did not reach members: {sorted(pending)}"
            )

    def run_background_workload() -> None:
        """Generate load and append external events observed by MR/WFR."""
        nonlocal workload_client
        short_timeout = min(args.timeout_ms, 1_000)
        workload_client = MongoClient(
            args.uri,
            serverSelectionTimeoutMS=short_timeout,
            connectTimeoutMS=short_timeout,
            socketTimeoutMS=short_timeout,
            retryWrites=False,
            appname="dsa5208-background-workload",
        )
        workload_collection = workload_client[args.db].get_collection(
            "background_workload",
            write_concern=WriteConcern(w=1, wtimeout=short_timeout),
            read_preference=ReadPreference.PRIMARY,
        )
        history_collection = workload_client[args.db].get_collection(
            "formal_consistency_trials",
            write_concern=WriteConcern(w=1, wtimeout=short_timeout),
            read_preference=ReadPreference.PRIMARY,
        )
        sequence = 0
        background_ids = ([f"{args.trial_id}:mr", f"{args.trial_id}:wfr"]
                          if args.workload_mode in ("probes", "phased-probes",
                                                    "phased-probes-wfr-late")
                          else [args.trial_id])
        while not workload_stop.is_set():
            sequence += 1
            marker = f"{sequence:016x}"
            payload = marker + "x" * max(0, args.background_payload_bytes - len(marker))
            try:
                for document_id in background_ids:
                    history_collection.update_one(
                        {"_id": document_id},
                        {"$push": {"background_history": marker}},
                    )
                    workload_counts["history_successful"] += 1
                workload_collection.update_one(
                    {"_id": args.trial_id},
                    {
                        "$set": {
                            "sequence": sequence,
                            "payload": payload,
                            "trial_id": args.trial_id,
                        },
                    },
                    upsert=True,
                )
                workload_counts["successful"] += 1
            except PyMongoError:
                workload_counts["failed"] += 1
            workload_stop.wait(args.background_interval_ms / 1_000)

    def wait_common_background_marker(document_ids: list[str]) -> str:
        """Require a non-empty MR/WFR baseline before measurement starts."""
        deadline = time.monotonic() + args.replication_wait_seconds
        while time.monotonic() < deadline:
            marker_sets = []
            complete = True
            for service in SERVICES:
                direct = MongoClient(
                    f"mongodb://{service}-client:27017/?directConnection=true",
                    serverSelectionTimeoutMS=args.timeout_ms,
                    connectTimeoutMS=args.timeout_ms,
                    socketTimeoutMS=args.timeout_ms,
                    retryReads=False,
                )
                try:
                    docs = list(direct[args.db].get_collection(
                        "formal_consistency_trials",
                        read_concern=ReadConcern("local"),
                        read_preference=ReadPreference.SECONDARY_PREFERRED,
                    ).find({"_id": {"$in": document_ids}}))
                    if len(docs) != len(document_ids):
                        complete = False
                        break
                    marker_sets.extend(set(doc.get("background_history", []))
                                       for doc in docs)
                except PyMongoError:
                    complete = False
                    break
                finally:
                    direct.close()
            if complete and marker_sets:
                common = set.intersection(*marker_sets)
                if common:
                    return min(common)
            time.sleep(0.2)
        raise RuntimeError(
            "no common MR/WFR background marker reached all members before workload"
        )

    # Initialisation is deliberately stronger than the measured configuration;
    # an absent baseline must never be mistaken for a consistency result.
    document_ids = ([f"{args.trial_id}:{name}" for name in ("ryw", "mr", "mw", "wfr")]
                    if args.workload_mode in ("probes", "phased-probes",
                                              "phased-probes-wfr-late")
                    else [args.trial_id])
    for document_id in document_ids:
        setup_collection.replace_one(
            {"_id": document_id},
            {
                "_id": document_id,
                "version": 0,
                "history": [],
                "background_history": [],
                "derived_from_version": None,
            },
            upsert=True,
        )
    wait_all_replicated(0, document_ids)
    emit("initialised", status="success")

    if args.background_workload == "on":
        workload_thread = threading.Thread(
            target=run_background_workload,
            name=f"background-{args.trial_id}",
            daemon=True,
        )
        workload_thread.start()
        emit(
            "background_workload",
            status="started",
            interval_ms=args.background_interval_ms,
            payload_bytes=args.background_payload_bytes,
        )

    try:
        deadline = time.monotonic() + args.replication_wait_seconds
        while (args.background_workload == "on"
               and workload_counts["history_successful"] < args.background_warmup_writes
               and time.monotonic() < deadline):
            time.sleep(0.01)
        if (args.background_workload == "on"
                and workload_counts["history_successful"] < args.background_warmup_writes):
            raise RuntimeError(
                "background warm-up did not reach the required number of "
                f"successful marker appends: {workload_counts['history_successful']}/"
                f"{args.background_warmup_writes}"
            )
        time.sleep(args.background_settle_ms / 1_000)
        if args.background_baseline == "all-members":
            if args.background_workload != "on":
                raise RuntimeError("all-members background baseline requires background workload")
            baseline_marker = wait_common_background_marker(
                [f"{args.trial_id}:mr", f"{args.trial_id}:wfr"]
            )
            emit("background_baseline", status="ready", marker=baseline_marker,
                 members=list(SERVICES))
        emit("warmup_complete", counts=dict(workload_counts))
        # One-way lifecycle notification only: no scenario, schedule or host reply.
        with ExitStack() as sessions:
            default_session = sessions.enter_context(
                client.start_session(causal_consistency=causal)
            )
            probe_sessions = ({name: sessions.enter_context(
                client.start_session(causal_consistency=causal)
            ) for name in ("ryw", "mr", "mw", "wfr")}
                if args.workload_mode in ("phased-probes",
                                          "phased-probes-wfr-late") else {})
            rng = random.Random(args.workload_seed)
            # Plan before execution; neither outcomes nor faults change the order.
            kinds: list[Any] = ["write", "read"] * args.operation_pairs
            if args.workload_mode == "mixed":
                kinds = ["write"] * (args.operation_pairs - 1) + ["read"] * args.operation_pairs
                rng.shuffle(kinds)
                kinds.insert(0, "write")
            elif args.workload_mode == "probes":
                # Repeat a balanced, scenario-blind probe round. This guarantees
                # that every property receives candidate relations throughout
                # the trial, instead of allowing random queue selection to
                # cluster one property entirely before or after the fault.
                rounds = max(4, args.operation_pairs // 4)
                probe_round = (
                    {"probe": "ryw", "kind": "write"},
                    {"probe": "mr", "kind": "read"},
                    {"probe": "wfr", "kind": "read"},
                    {"probe": "mw", "kind": "write"},
                    {"probe": "ryw", "kind": "read"},
                    {"probe": "mr", "kind": "read"},
                    {"probe": "wfr", "kind": "write"},
                )
                kinds = [dict(item) for _ in range(rounds) for item in probe_round]
            elif args.workload_mode == "phased-probes":
                # Accumulate dependencies before the independently timed fault
                # window, then exercise observations/dependent writes later.
                # The client never receives scenario or fault-state feedback.
                rounds = max(4, args.operation_pairs // 4)
                build_phase = (
                    {"probe": "wfr", "kind": "read"},
                    {"probe": "ryw", "kind": "write"},
                    {"probe": "mr", "kind": "read"},
                    {"probe": "mw", "kind": "write"},
                    {"probe": "wfr", "kind": "read"},
                )
                observe_phase = (
                    {"probe": "ryw", "kind": "read"},
                    {"probe": "wfr", "kind": "write"},
                    {"probe": "mw", "kind": "write"},
                    {"probe": "mr", "kind": "read"},
                    {"probe": "wfr", "kind": "write"},
                )
                kinds = ([dict(item) for _ in range(rounds) for item in build_phase]
                         + [dict(item) for _ in range(rounds) for item in observe_phase])
            elif args.workload_mode == "phased-probes-wfr-late":
                # Sensitivity variant: retain the same documents, sessions,
                # operation counts and non-WFR relative order, but place one
                # WFR source read after each dependent-write opportunity. This
                # lets later WFR writes inherit a non-empty dependency without
                # consulting the scenario or fault state.
                rounds = max(4, args.operation_pairs // 4)
                build_phase = (
                    {"probe": "wfr", "kind": "read"},
                    {"probe": "ryw", "kind": "write"},
                    {"probe": "mr", "kind": "read"},
                    {"probe": "mw", "kind": "write"},
                )
                observe_phase = (
                    {"probe": "ryw", "kind": "read"},
                    {"probe": "wfr", "kind": "write"},
                    {"probe": "mw", "kind": "write"},
                    {"probe": "mr", "kind": "read"},
                    {"probe": "wfr", "kind": "read"},
                    {"probe": "wfr", "kind": "write"},
                )
                kinds = ([dict(item) for _ in range(rounds) for item in build_phase]
                         + [dict(item) for _ in range(rounds) for item in observe_phase])
            pauses_ms = []
            for _ in range(len(kinds) - 1):
                if args.interarrival_distribution == "fixed":
                    pauses_ms.append(args.operation_interval_ms)
                    continue
                slots = 1
                while rng.random() > args.interarrival_probability:
                    slots += 1
                pauses_ms.append(slots * args.interarrival_slot_ms)
            def planned_kind(item: Any) -> str:
                return item["kind"] if isinstance(item, dict) else item

            planned_writes = sum(planned_kind(item) == "write" for item in kinds)
            planned_reads = sum(planned_kind(item) == "read" for item in kinds)
            emit("workload_started", planned_writes=planned_writes,
                 planned_reads=planned_reads, operation_plan=kinds,
                 planned_interarrival_ms=pauses_ms,
                 interarrival_distribution=args.interarrival_distribution,
                 workload_mode=args.workload_mode, workload_seed=args.workload_seed)
            number = 0
            reads = 0
            steps = 0
            probe_counts = {name: {"write": 0, "read": 0}
                            for name in ("ryw", "mr", "mw", "wfr")}
            for index, planned in enumerate(kinds):
                probe = planned["probe"] if isinstance(planned, dict) else None
                kind = planned["kind"] if isinstance(planned, dict) else planned
                active_session = probe_sessions.get(probe, default_session)
                pause_ms = pauses_ms[index] if index < len(pauses_ms) else None
                emit("workload_step", index=steps, kind=kind,
                     probe=probe, next_interarrival_ms=pause_ms)
                document_id = f"{args.trial_id}:{probe}" if probe else args.trial_id
                probe_collection = collection
                if kind == "write":
                    if probe:
                        probe_counts[probe]["write"] += 1
                        marker = f"{probe.upper()}-W{probe_counts[probe]['write']}"
                    else:
                        number += 1
                        marker = f"W{number}"
                    operation(
                        marker,
                        lambda marker=marker, document_id=document_id: probe_collection.find_one_and_update(
                            {"_id": document_id}, {"$push": {"history": marker}},
                            return_document=ReturnDocument.BEFORE, session=active_session),
                        session=active_session, is_write=True, probe=probe,
                        document_id=document_id)
                else:
                    if probe:
                        probe_counts[probe]["read"] += 1
                        label = f"{probe.upper()}-R{probe_counts[probe]['read']}"
                    else:
                        reads += 1
                        label = f"R{reads}"
                    operation(label, lambda document_id=document_id: probe_collection.find_one(
                        {"_id": document_id}, session=active_session),
                        session=active_session, probe=probe, document_id=document_id)
                steps += 1
                if pause_ms is not None:
                    time.sleep(pause_ms / 1_000)
            if args.workload_mode in ("probes", "phased-probes",
                                      "phased-probes-wfr-late"):
                number = sum(counts["write"] for counts in probe_counts.values())
                reads = sum(counts["read"] for counts in probe_counts.values())
            emit("history_complete", logical_operations=steps,
                 attempted_writes=number, attempted_reads=reads,
                 probe_counts=(probe_counts if args.workload_mode in
                               ("probes", "phased-probes",
                                "phased-probes-wfr-late") else None))
        return 0
    finally:
        workload_stop.set()
        if workload_thread:
            workload_thread.join(timeout=3)
            emit("background_workload", status="stopped", **workload_counts)
        if workload_client:
            workload_client.close()
        client.close()
