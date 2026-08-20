#!/usr/bin/env python3
"""shipcheck — universal pre-ship verification CLI (thin entry point).

Usage:
    shipcheck [repo] [--json] [--strict] [--skip-dim D] [--version]

Exit codes:
    0  no BLOCKING findings (clean or WARN-only)
    1  BLOCKING finding exists (or --strict with any WARN)
    2  usage / environment error
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import verdict

VERSION = "0.1.0"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="shipcheck", description="Universal pre-ship verification."
    )
    parser.add_argument("repo", nargs="?", default=".", help="repo path (default: cwd)")
    parser.add_argument("--json", action="store_true", help="emit verdict as JSON")
    parser.add_argument("--strict", action="store_true", help="exit 1 on any WARN too")
    parser.add_argument(
        "--skip-dim", action="append", default=[], metavar="D", help="skip a dimension"
    )
    parser.add_argument("--version", action="store_true", help="print version and exit")
    args = parser.parse_args(argv)

    if args.version:
        print(VERSION)
        return 0

    repo = Path(args.repo).resolve()
    if not repo.is_dir():
        print(f"shipcheck: repo not found: {repo}", file=sys.stderr)
        return 2
    if not (repo / ".git").is_dir():
        print(f"shipcheck: not a git repo: {repo}", file=sys.stderr)
        return 2

    config_path = Path(__file__).resolve().parent.parent / "dimensions.yaml"
    if not config_path.exists():
        print(f"shipcheck: dimensions.yaml not found at {config_path}", file=sys.stderr)
        return 2

    stack = verdict.detect_stack(repo)
    results = verdict.build_verdict(repo, config_path, set(args.skip_dim))

    if args.json:
        payload = {
            "version": VERSION,
            "repo": str(repo),
            "stack": stack,
            "dimensions": [r.to_dict() for r in results],
            "summary": {
                "blocking": sum(1 for r in results if r.status == "BLOCKING"),
                "warn": sum(1 for r in results if r.status == "WARN"),
                "pass": sum(1 for r in results if r.status == "PASS"),
                "not_checked": sum(1 for r in results if r.status == "NOT_CHECKED"),
            },
        }
        print(json.dumps(payload, indent=2))
    else:
        print(verdict.render_terminal(results, stack, VERSION))

    if any(r.status == "BLOCKING" for r in results):
        return 1
    if args.strict and any(r.status == "WARN" for r in results):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
