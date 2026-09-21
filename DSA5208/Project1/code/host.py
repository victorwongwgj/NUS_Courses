"""Host-side Docker topology control and trial orchestration."""

from __future__ import annotations

import argparse
import json
import subprocess
import threading
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from utils import SERVICES, configuration_id, scenario_id
from faults import FaultController, make_schedule

# Replica-set inspection -----------------------------------------------------

def run(command: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, check=check, text=True, capture_output=True, timeout=120)


def compose(*parts: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return run(["docker", "compose", *parts], check=check)


def roles_from(service: str) -> dict[str, str]:
    js = "JSON.stringify(rs.status().members.map(m=>({name:m.name,state:m.stateStr})))"
    result = compose("exec", "-T", service, "mongosh", "--quiet", "--eval", js, check=False)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or f"cannot query {service}")
    rows = json.loads(result.stdout.strip().splitlines()[-1])
    return {row["name"].split(":", 1)[0]: row["state"] for row in rows}


def member_roles(exclude: tuple[str, ...] = ()) -> dict[str, str]:
    """Read rs.status() from any reachable member, not necessarily Primary."""
    error = ""
    for service in SERVICES:
        if service in exclude:
            continue
        try:
            return roles_from(service)
        except (RuntimeError, json.JSONDecodeError) as exc:
            error = str(exc)
    raise RuntimeError(f"cannot read replica-set status: {error}")


def wait_for_healthy(timeout: int) -> dict[str, str]:
    """Require the clean topology used before and after every subtrial."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            roles = member_roles()
            if (
                sorted(roles) == sorted(SERVICES)
                and list(roles.values()).count("PRIMARY") == 1
                and list(roles.values()).count("SECONDARY") == 2
            ):
                return roles
        except RuntimeError:
            pass
        time.sleep(1)
    raise RuntimeError(f"replica set did not recover within {timeout}s")


def container_ips(service: str) -> list[str]:
    cid = compose("ps", "-q", service).stdout.strip()
    if not cid:
        raise RuntimeError(f"{service} is not running")
    result = run(["docker", "inspect", "--format", "{{json .NetworkSettings.Networks}}", cid])
    networks = json.loads(result.stdout)
    return sorted(v["IPAddress"] for v in networks.values() if v.get("IPAddress"))


def network_interfaces(service: str) -> list[str]:
    """Return the container's Ethernet interfaces, excluding loopback."""
    result = compose("exec", "-T", service, "ip", "-o", "link", "show")
    interfaces: list[str] = []
    for line in result.stdout.splitlines():
        fields = line.split(":", 2)
        if len(fields) < 2:
            continue
        name = fields[1].strip().split("@", 1)[0]
        if name.startswith("eth"):
            interfaces.append(name)
    return interfaces


def clear_replication_impairment(services=SERVICES) -> None:
    """Remove only the traffic-control state and packet marks owned by this runner."""
    for service in services:
        try:
            interfaces = network_interfaces(service)
        except subprocess.CalledProcessError:
            continue
        for interface in interfaces:
            compose(
                "exec", "-T", service, "tc", "qdisc", "del",
                "dev", interface, "root", check=False,
            )
        peer_ips = sorted(
            {ip for peer in SERVICES if peer != service for ip in container_ips(peer)}
        )
        for peer_ip in peer_ips:
            compose(
                "exec", "-T", service, "iptables", "-t", "mangle", "-D", "OUTPUT",
                "-d", peer_ip, "-p", "tcp", "-j", "MARK", "--set-mark", "10",
                check=False,
            )


def reset_experiment_environment(timeout: int = 120) -> dict[str, str]:
    """Recover stopped members and remove runner-owned fault/link rules."""
    compose("up", "-d")
    compose("start", *SERVICES)
    for service in SERVICES:
        for peer in SERVICES:
            if peer == service:
                continue
            for peer_ip in container_ips(peer):
                for chain, flag in (("INPUT", "-s"), ("OUTPUT", "-d")):
                    # Repeated partial injections can leave duplicate rules.
                    while compose(
                        "exec", "-T", service, "iptables", "-D", chain,
                        flag, peer_ip, "-p", "tcp", "-j", "DROP", check=False,
                    ).returncode == 0:
                        pass
    clear_replication_impairment()
    return wait_for_healthy(timeout)


def apply_replication_impairment(args: argparse.Namespace, services=SERVICES) -> None:
    """Delay and rate-limit only MongoDB member-to-member traffic."""
    clear_replication_impairment(services)
    if args.replication_delay_ms == 0:
        return
    for service in services:
        peer_ips = sorted(
            {ip for peer in SERVICES if peer != service for ip in container_ips(peer)}
        )
        for interface in network_interfaces(service):
            compose(
                "exec", "-T", service, "tc", "qdisc", "replace",
                "dev", interface, "root", "handle", "1:", "prio",
            )
            compose(
                "exec", "-T", service, "tc", "qdisc", "replace",
                "dev", interface, "parent", "1:3", "handle", "30:", "netem",
                "delay", f"{args.replication_delay_ms}ms",
                f"{args.replication_jitter_ms}ms", "distribution", "normal",
                "rate", f"{args.replication_rate_mbit}mbit",
            )
            compose(
                "exec", "-T", service, "tc", "filter", "replace",
                "dev", interface, "protocol", "ip", "parent", "1:0",
                "prio", "3", "handle", "10", "fw", "flowid", "1:3",
            )
        for peer_ip in peer_ips:
            compose(
                "exec", "-T", service, "iptables", "-t", "mangle", "-I", "OUTPUT",
                "-d", peer_ip, "-p", "tcp", "-j", "MARK", "--set-mark", "10",
            )


# Fault injection and healing -----------------------------------------------

def firewall_rule(service: str, action: str, chain: str, peer_ip: str) -> None:
    """Add/delete one peer-specific rule while leaving client traffic intact."""
    direction = ["-s", peer_ip] if chain == "INPUT" else ["-d", peer_ip]
    compose(
        "exec", "-T", service, "iptables", action, chain,
        *direction, "-p", "tcp", "-j", "DROP",
    )


def client_can_reach(service: str) -> bool:
    uri = f"mongodb://{service}-client:27017/?directConnection=true"
    code = (
        "import sys; from pymongo import MongoClient; "
        "c=MongoClient(sys.argv[1],serverSelectionTimeoutMS=3000); "
        "c.admin.command('ping')"
    )
    return compose("exec", "-T", "client", "python", "-c", code, uri, check=False).returncode == 0


def audit_trial(args: argparse.Namespace, trial_id: str) -> dict[str, dict]:
    """Read the recovered append history directly from every member."""
    code = (
        "import json,sys; from pymongo import MongoClient,ReadPreference; "
        "c=MongoClient(sys.argv[1],directConnection=True,serverSelectionTimeoutMS=5000); "
        "ids=json.loads(sys.argv[3]); col=c[sys.argv[2]].get_collection("
        "'formal_consistency_trials',read_preference=ReadPreference.SECONDARY_PREFERRED); "
        "docs=list(col.find({'_id':{'$in':ids}})); "
        "print(json.dumps({d['_id']:{'history':d.get('history',[]),"
        "'background_count':len(d.get('background_history',[])),"
        "'background_last':(d.get('background_history') or [None])[-1]} for d in docs}))"
    )
    document_ids = ([f"{trial_id}:{name}" for name in ("ryw", "mr", "mw", "wfr")]
                    if args.workload_mode in ("probes", "phased-probes",
                                              "phased-probes-wfr-late")
                    else [trial_id])
    members = {}
    for service in SERVICES:
        uri = f"mongodb://{service}-client:27017/"
        result = compose("exec", "-T", "client", "python", "-c", code,
                         uri, args.db, json.dumps(document_ids), check=False)
        if result.returncode:
            members[service] = {"status": "failure",
                                "error": result.stderr.strip() or result.stdout.strip()}
            continue
        try:
            members[service] = {"status": "success",
                                "documents": json.loads(result.stdout.strip().splitlines()[-1])}
        except (json.JSONDecodeError, IndexError) as exc:
            members[service] = {"status": "failure", "error": str(exc)}
    return members


def wait_for_trial_convergence(
    args: argparse.Namespace, trial_id: str
) -> tuple[dict[str, dict], bool]:
    """Wait until the just-finished trial has identical state on all members."""
    deadline = time.monotonic() + args.recovery_catchup_seconds
    latest: dict[str, dict] = {}
    while time.monotonic() < deadline:
        latest = audit_trial(args, trial_id)
        successful = [value["documents"] for value in latest.values()
                      if value.get("status") == "success"]
        if len(successful) == len(SERVICES) and all(
            documents == successful[0] for documents in successful[1:]
        ):
            return latest, True
        time.sleep(1)
    return latest, False


def select_fault_target(scenario: str, roles: dict[str, str]) -> tuple[str, ...]:
    """Select by current role so elections in earlier trials do not matter."""
    primary = next(name for name, role in roles.items() if role == "PRIMARY")
    secondaries = tuple(sorted(name for name, role in roles.items() if role == "SECONDARY"))
    if scenario == "normal":
        return ()
    if scenario in ("primary-down", "network-partition"):
        return (primary,)
    if scenario in ("secondary-down", "node-isolation"):
        return (secondaries[0],)
    return secondaries


def inject_fault(
    scenario: str, targets: tuple[str, ...], before: dict[str, str]
) -> dict[str, Any]:
    """Apply the preselected fault; recovery is owned by the independent timer."""
    metadata: dict[str, Any] = {
        "event": "fault",
        "injected_at": datetime.now(timezone.utc).isoformat(),
        "scenario": scenario,
        "roles_before": before,
        "targets": list(targets),
    }

    if scenario == "normal":
        metadata["roles_after_fault"] = before
        return metadata

    if scenario in ("node-isolation", "network-partition"):
        target = targets[0]
        peers = [service for service in SERVICES if service != target]
        peer_ips = sorted({ip for peer in peers for ip in container_ips(peer)})
        metadata.update(
            partition_method="selective iptables rules",
            blocked_peers=peers,
            blocked_peer_ips=peer_ips,
            client_reachable_before=client_can_reach(target),
        )
        # Both MongoDB networks must be blocked. Otherwise replication can
        # silently continue through the other shared Docker network.
        for peer_ip in peer_ips:
            firewall_rule(target, "-I", "INPUT", peer_ip)
            firewall_rule(target, "-I", "OUTPUT", peer_ip)
    else:
        if scenario == "primary-down":
            # SIGKILL models a crash. `docker compose stop` grants MongoDB a
            # graceful shutdown interval and usually lets w:1 writes replicate.
            compose("kill", "-s", "SIGKILL", *targets)
            metadata["termination"] = "SIGKILL"
        else:
            compose("stop", *targets)

    metadata["injection_completed_at"] = datetime.now(timezone.utc).isoformat()
    return metadata


# Host/client coordination and persistence ---------------------------------

def run_inner_trial(args, trial_id, roles_before, plan, record):
    """Collect a scenario-blind client while an independent timer controls faults."""
    command = ["docker", "compose", "exec", "-T", "client", "python", "/code/run.py",
               "--inner", "--trial-id", trial_id]
    # No scenario or fault scheduling arguments are passed to the client.
    names = ("read_concern", "write_concern", "read_preference", "journal",
             "causal_session", "timeout_ms", "read_timeout_ms", "write_timeout_ms",
             "replication_wait_seconds", "recovery_catchup_seconds",
             "background_workload", "background_interval_ms", "background_payload_bytes",
             "background_warmup_writes", "background_settle_ms", "background_baseline",
             "operation_pairs", "operation_interval_ms", "workload_mode",
             "interarrival_distribution", "interarrival_slot_ms",
             "interarrival_probability", "uri", "db")
    for name in names:
        command.extend(["--" + name.replace("_", "-"), str(getattr(args, name))])
    command.extend(["--workload-seed", str(args.workload_seed + plan["trial"] - 1)])
    events, invocation_phases = [], {}
    lock = threading.Lock()
    origin = None
    phase = "before"
    controller = None

    def save(event):
        nonlocal phase
        with lock:
            event["trial_id"] = trial_id
            event["scenario"] = args.scenario
            event["scenario_id"] = scenario_id(args.scenario)
            event["recorded_at"] = datetime.now(timezone.utc).isoformat()
            event["host_elapsed_seconds"] = (
                round(time.monotonic() - origin, 6) if origin is not None else None)
            if event.get("event") == "fault_started":
                phase = "during"
            elif event.get("event") == "fault_healed":
                phase = "after"
            if event.get("event") == "invocation":
                invocation_phases[event["operation_id"]] = phase
                event["phase"] = phase
            elif event.get("event") == "operation":
                event["phase"] = invocation_phases.get(event["operation_id"], phase)
                event["completion_phase"] = phase
            events.append(event)
            record(event)

    # The target is selected by its role at trial setup, not by client progress.
    targets = select_fault_target(args.scenario, roles_before)

    def inject():
        metadata = inject_fault(args.scenario, targets, roles_before)
        save(metadata)

    def heal():
        # Also handles partial injection: it never depends on inject returning.
        if args.scenario in ("primary-down", "secondary-down", "two-nodes-down"):
            compose("start", *targets)
            apply_replication_impairment(args, targets)
        elif args.scenario in ("node-isolation", "network-partition"):
            for target in targets:
                for peer in SERVICES:
                    if peer != target:
                        for ip in container_ips(peer):
                            for chain in ("INPUT", "OUTPUT"):
                                # A missing rule is expected after partial setup.
                                compose("exec", "-T", target, "iptables", "-D", chain,
                                        "-s" if chain == "INPUT" else "-d", ip,
                                        "-p", "tcp", "-j", "DROP", check=False)

    process = subprocess.Popen(command, text=True, stdin=subprocess.DEVNULL,
                               stdout=subprocess.PIPE, stderr=None, bufsize=1)
    try:
        for line in process.stdout:
            event = json.loads(line)
            if event.get("event") == "workload_started":
                if controller is not None:
                    raise RuntimeError("duplicate workload start event")
                origin = time.monotonic()
                save(event)
                controller = FaultController(plan, origin, inject, heal, save)
                controller.start()
            else:
                save(event)
        code = process.wait()
        if code:
            save({"event": "runner_error", "exit_code": code})
        if controller is None:
            save({"event": "runner_error", "error": "workload never started"})
        # Recovery is cleanup, never a way to unblock measured requests.
        if controller is not None:
            controller.cancelled.set()
            controller.join()
    except Exception as exc:
        save({"event": "runner_error", "error": str(exc)})
        raise
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        if controller is not None:
            controller.cancelled.set()
            controller.join()
        try:
            heal()
            clear_replication_impairment()
            roles = wait_for_healthy(args.election_wait_seconds + args.replication_wait_seconds)
            save({"event": "recovery", "status": "success", "roles": roles})
            members, converged = wait_for_trial_convergence(args, trial_id)
            save({"event": "post_recovery_audit", "members": members,
                  "converged": converged,
                  "catchup_timeout_seconds": args.recovery_catchup_seconds})
            if not converged:
                raise RuntimeError(
                    f"trial state did not converge within "
                    f"{args.recovery_catchup_seconds}s"
                )
        except Exception as exc:
            save({"event": "runner_error", "error": f"cleanup failed: {exc}"})
            raise
    return events


def render_report(args, trials, history_path):
    lines = [f"# {scenario_id(args.scenario)} {args.scenario} / {configuration_id(args)} - continuous history", "",
             f"Raw history: [{history_path.name}]({history_path.name})", "",
             "All four properties use the same history. PASS refers only to checked relations.",
             "Faults run on an independent timer. Phases are host-observed invocation phases.",
             f"Schedule: [{history_path.with_suffix('.schedule.json').name}]"
             f"({history_path.with_suffix('.schedule.json').name})",
             "Rollback of an acknowledged/observed append counts as loss.", "",
             "```json", json.dumps(vars(args), indent=2), "```", "",
             "| Trial | Property | Status | Checked | Cross-phase | Witnesses |",
             "| --- | --- | --- | --- | --- | --- |"]
    for number, result in enumerate(trials, 1):
        for name, prop in result["properties"].items():
            lines.append(f"| {number} | {name} | {prop['status']} | {prop['checked']} | "
                         f"{prop['cross_phase_checked']} | {len(prop['witnesses'])} |")
    for number, result in enumerate(trials, 1):
        lines += ["", f"## Trial {number}", "",
                  f"Operations: {result['operations']}; success: {result['successful']}; "
                  f"failed: {result['failed']}; pending: {result['pending']}.",
                  f"Complete: {result['history_complete']}; unresolved writes: "
                  f"{result['unresolved_writes']}.", "",
                  "```json", json.dumps(result["properties"], indent=2), "```"]
    return "\n".join(lines) + "\n"


def host_main(args):
    """Execute exactly N histories; never select trials by their outcome."""
    from checker import check_history
    config = configuration_id(args)
    output = Path(args.output or f"results/{args.scenario}-{config}.md").resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    history_path = output.with_suffix(".jsonl")
    schedule_path = output.with_suffix(".schedule.json")
    if output.exists() or history_path.exists() or schedule_path.exists():
        raise RuntimeError(f"Output already exists; choose a new --output: {output}")
    schedule = make_schedule(args)
    schedule_path.write_text(json.dumps({"seed": args.schedule_seed, "trials": schedule}, indent=2))
    compose("up", "-d")
    results = []
    with history_path.open("x") as stream:
        def record(event):
            stream.write(json.dumps(event) + "\n")
            stream.flush()
        record({"event": "experiment", "schema": 3,
                "configuration_id": config, "scenario_id": scenario_id(args.scenario),
                "settings": vars(args)})
        for number, plan in enumerate(schedule):
            trial_id = f"{args.scenario}-{number + 1}-{uuid.uuid4().hex[:8]}"
            roles = wait_for_healthy(args.election_wait_seconds)
            apply_replication_impairment(args)
            record({"event": "trial_started", "trial_id": trial_id,
                    "configuration_id": config, "scenario_id": scenario_id(args.scenario),
                    "plan": plan, "roles": roles})
            print(f"Starting {trial_id}", flush=True)
            events = run_inner_trial(args, trial_id, roles, plan, record)
            result = check_history(events)
            record({"event": "offline_result", "trial_id": trial_id, "result": result})
            results.append(result)
            output.write_text(render_report(args, results, history_path))
            print({k: v["status"] for k, v in result["properties"].items()}, flush=True)
    print(f"result report: {output}", flush=True)
    if any(not r["history_complete"] for r in results):
        return 1
    if any(p["status"] == "VIOLATION" for r in results for p in r["properties"].values()):
        return 2
    return 0
