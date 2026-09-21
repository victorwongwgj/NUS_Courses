"""Shared command-line configuration for the experiment runner."""

from __future__ import annotations

import argparse
import os

DEFAULT_URI = "mongodb://mongo1:27017,mongo2:27017,mongo3:27017/lab?replicaSet=rs0"
SERVICES = ("mongo1", "mongo2", "mongo3")
SCENARIOS = (
    "normal",
    "primary-down",
    "secondary-down",
    "node-isolation",
    "network-partition",
    "two-nodes-down",
)
PROPERTIES = ("ryw", "mr", "mw", "wfr")


def parse_args() -> argparse.Namespace:
    """Parse both the public host CLI and the hidden container-side CLI."""
    parser = argparse.ArgumentParser(
        description=(
            "Formal MongoDB consistency experiment runner. The host injects "
            "faults while a client-container process keeps its session alive."
        )
    )
    parser.add_argument("--scenario", choices=SCENARIOS, default="normal")
    parser.add_argument("--property", choices=("all",), default="all",
                        help="all four properties are checked from the same history")
    parser.add_argument("--read-concern", choices=("local", "majority"), default="majority")
    parser.add_argument("--write-concern", choices=("1", "majority", "3"), default="majority")
    parser.add_argument(
        "--journal",
        choices=("on", "off"),
        default="on",
        help="require journal acknowledgment for measured writes (default: on)",
    )
    parser.add_argument(
        "--read-preference",
        choices=("primary", "primaryPreferred", "secondary", "secondaryPreferred", "nearest"),
        default="secondaryPreferred",
    )
    parser.add_argument("--causal-session", choices=("on", "off"), default="on")
    parser.add_argument(
        "--background-workload",
        choices=("on", "off"),
        default="on",
        help="continuously generate independent w:1 writes during each trial",
    )
    parser.add_argument("--background-interval-ms", type=int, default=20)
    parser.add_argument("--background-payload-bytes", type=int, default=16_384)
    parser.add_argument("--background-warmup-writes", type=int, default=50)
    parser.add_argument("--background-settle-ms", type=int, default=1_000)
    parser.add_argument(
        "--background-baseline",
        choices=("off", "all-members"),
        default="off",
        help=("before the measured history starts, optionally require at least "
              "one common MR/WFR background marker on every member"),
    )
    parser.add_argument(
        "--replication-delay-ms",
        type=int,
        default=500,
        help="one-way delay applied only to member-to-member traffic (0 disables impairment)",
    )
    parser.add_argument("--replication-jitter-ms", type=int, default=100)
    parser.add_argument("--replication-rate-mbit", type=int, default=5)
    parser.add_argument("--trials", type=int, default=1)
    parser.add_argument("--operation-pairs", type=int, default=50,
                        help="attempt this many writes and this many reads per trial")
    parser.add_argument(
        "--workload-mode",
        choices=("fixed", "mixed", "probes", "phased-probes",
                 "phased-probes-wfr-late"),
        default="mixed",
    )
    parser.add_argument("--workload-seed", type=int, default=1729)
    parser.add_argument("--operation-interval-ms", type=int, default=1000,
                        help="fixed think time; used only with fixed interarrival")
    parser.add_argument("--interarrival-distribution",
                        choices=("fixed", "geometric"), default="fixed",
                        help="distribution of think time between foreground requests")
    parser.add_argument("--interarrival-slot-ms", type=int, default=20,
                        help="duration of one geometric waiting slot")
    parser.add_argument("--interarrival-probability", type=float, default=0.1,
                        help="geometric success probability; mean wait is slot/p")
    parser.add_argument("--schedule-seed", type=int, default=5208)
    parser.add_argument("--fault-start-min-seconds", type=float, default=5)
    parser.add_argument("--fault-start-max-seconds", type=float, default=10)
    parser.add_argument("--timeout-ms", type=int, default=5_000)
    parser.add_argument("--read-timeout-ms", type=int,
                        help="per-read deadline; defaults to --timeout-ms")
    parser.add_argument("--write-timeout-ms", type=int,
                        help="per-write and write-concern deadline; defaults to --timeout-ms")
    parser.add_argument("--election-wait-seconds", type=int, default=60)
    parser.add_argument("--replication-wait-seconds", type=int, default=30)
    parser.add_argument(
        "--recovery-catchup-seconds",
        type=int,
        default=300,
        help="maximum wait for all members to converge between trials",
    )
    parser.add_argument("--uri", default=os.getenv("MONGO_URI", DEFAULT_URI))
    parser.add_argument("--db", default="lab")
    parser.add_argument("--output", help="Readable Markdown report path")
    parser.add_argument("--keep-fault", action="store_true")
    # Hidden arguments are used when the host re-enters the runner inside the
    # client container; users should continue to call run.py normally.
    parser.add_argument("--inner", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--trial-id", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.read_timeout_ms is None:
        args.read_timeout_ms = args.timeout_ms
    if args.write_timeout_ms is None:
        args.write_timeout_ms = args.timeout_ms
    if min(
        args.trials,
        args.operation_pairs,
        args.timeout_ms,
        args.read_timeout_ms,
        args.write_timeout_ms,
        args.election_wait_seconds,
        args.replication_wait_seconds,
        args.recovery_catchup_seconds,
        args.background_interval_ms,
        args.background_payload_bytes,
        args.background_warmup_writes,
        args.background_settle_ms,
    ) < 1:
        parser.error("trial counts and timeouts must be positive")
    if args.replication_delay_ms < 0 or args.replication_jitter_ms < 0:
        parser.error("replication delay and jitter must be non-negative")
    if args.replication_rate_mbit < 1:
        parser.error("replication rate must be positive")
    if min(args.operation_interval_ms, args.interarrival_slot_ms) < 0 or args.fault_start_min_seconds < 0:
        parser.error("intervals must be non-negative")
    if not 0 < args.interarrival_probability <= 1:
        parser.error("interarrival probability must be in (0, 1]")
    if args.fault_start_max_seconds < args.fault_start_min_seconds:
        parser.error("fault start range is reversed")
    mean_interval_ms = (args.operation_interval_ms
                        if args.interarrival_distribution == "fixed"
                        else args.interarrival_slot_ms / args.interarrival_probability)
    if (not args.inner and (2 * args.operation_pairs - 1) * mean_interval_ms / 1000
            <= args.fault_start_max_seconds):
        parser.error("expected think times must extend beyond the latest fault start")
    if args.inner and not args.trial_id:
        parser.error("inner mode requires --trial-id")
    if args.keep_fault:
        parser.error("continuous histories require recovery; --keep-fault is unsupported")
    return args


def configuration_id(args: argparse.Namespace) -> str:
    """Map the 24 main cells to C01-C24 and the w:3 extension to C25-C36."""
    causal_values = ("on", "off")
    read_values = ("local", "majority")
    route_values = ("primary", "secondary", "secondaryPreferred")
    if (args.journal == "on" and args.causal_session in causal_values
            and args.read_concern in read_values
            and args.read_preference in route_values):
        causal_index = causal_values.index(args.causal_session)
        read_index = read_values.index(args.read_concern)
        route_index = route_values.index(args.read_preference)
        if args.write_concern in ("1", "majority"):
            write_index = ("1", "majority").index(args.write_concern)
            number = causal_index * 12 + read_index * 6 + write_index * 3 + route_index + 1
            return f"C{number:02d}"
        if args.write_concern == "3":
            number = 25 + causal_index * 6 + read_index * 3 + route_index
            return f"C{number:02d}"
    return (
        f"causal-{args.causal_session}_rc-{args.read_concern}_"
        f"wc-{args.write_concern}_j-{args.journal}_rp-{args.read_preference}"
    )


def scenario_id(scenario: str) -> str:
    """Return the stable S1-S6 identifier, with two-nodes-down last."""
    return f"S{SCENARIOS.index(scenario) + 1}"
