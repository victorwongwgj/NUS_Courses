#!/usr/bin/env python3
"""Public entry point for the MongoDB consistency experiment suite."""

from utils import parse_args
from host import host_main
from protocols import inner_main


if __name__ == "__main__":
    arguments = parse_args()
    raise SystemExit(inner_main(arguments) if arguments.inner else host_main(arguments))
