#!/usr/bin/env python3
"""shipcheck verdict — aggregation + rendering.

Loads dimensions.yaml, orchestrates per-dimension checks via checkers.py,
and renders PASS / WARN / BLOCKING / NOT_CHECKED verdicts. Pure logic —
unit-testable without tools.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import checkers
from model import DimensionResult, Finding


def detect_stack(repo: Path) -> list[str]:
    """Manifest sniffing → ecosystem tags (Decision 3: runtime stack detection)."""
    tags: list[str] = []
    try:
        names = {p.name for p in repo.iterdir() if p.is_file()}
    except OSError:
        return ["unknown"]
    if "requirements.txt" in names or "pyproject.toml" in names:
        tags.append("python")
    if "package.json" in names:
        tags.append("node")
    if "Cargo.toml" in names or "Cargo.lock" in names:
        tags.append("rust")
    if "go.mod" in names or "go.sum" in names:
        tags.append("go")
    if "pom.xml" in names or "build.gradle" in names or "build.gradle.kts" in names:
        tags.append("java")
    if any(p.suffix == ".csproj" for p in repo.iterdir()):
        tags.append("dotnet")
    if (repo / ".github" / "workflows").is_dir():
        tags.append("github-actions")
    return tags or ["unknown"]


def load_dimensions(config_path: Path) -> dict[str, Any]:
    """Load dimensions.yaml — minimal YAML-subset parser (stdlib-only, Constitution 7).

    Supported subset: top-level `name:` blocks with indented `key: value`
    lines; `checkers` as `[a, b]`; `ai_review` as true/false.
    """
    dims: dict[str, Any] = {}

    current: str | None = None

    for raw in config_path.read_text().splitlines():
        line = raw.rstrip()

        if not line.strip() or line.lstrip().startswith("#"):
            continue

        indent = len(line) - len(line.lstrip(" "))

        stripped = line.strip()

        if indent <= 2 and stripped.endswith(":"):
            name = stripped[:-1].strip()

            if name == "dimensions":
                current = None  # wrapper; actual dims follow at indent 2

            else:
                current = name

                dims[current] = {
                    "checkers": [],
                    "ai_review": False,
                    "severity": "info",
                    "description": "",
                }

        elif current is not None and indent >= 4:
            key, _, val = stripped.partition(":")

            val = val.strip().strip('"').strip("'")

            if key == "checkers":
                dims[current][key] = [
                    c.strip() for c in val.strip("[]").split(",") if c.strip()
                ]

            elif key == "ai_review":
                dims[current][key] = val.lower() == "true"

            elif key == "severity":
                dims[current][key] = val

            elif key == "description":
                dims[current][key] = val

    return dims


def run_dimension(name: str, cfg: dict[str, Any], repo: Path) -> DimensionResult:
    """Execute a dimension's checkers; aggregate into PASS/WARN/BLOCKING/NOT_CHECKED."""
    result = DimensionResult(name=name, severity=cfg.get("severity", "info"))
    checkers_list = cfg.get("checkers", [])

    if not checkers_list and cfg.get("ai_review"):
        result.status = "NOT_CHECKED"
        result.reason = "AI-review dimension — no machine checker; run OMO AI skill or manual review"
        return result

    findings: list[Finding] = []
    problems: list[str] = []
    for checker in checkers_list:
        if checker == "semgrep":
            found = checkers.run_semgrep(repo)
        elif checker == "trivy-secrets":
            found = checkers.run_trivy(repo, "secret", name, "trivy-secrets")
        elif checker == "trivy-vulns":
            found = checkers.run_trivy(repo, "vuln", name, "trivy-vulns")
        elif checker == "audit":
            found = checkers.run_audit(repo)
        else:
            continue
        for finding in found:
            if "timed out" in finding.title or "unparseable" in finding.title:
                problems.append(finding.title)
            else:
                findings.append(finding)

    tool = (
        {
            "semgrep": "semgrep",
            "trivy-secrets": "trivy",
            "trivy-vulns": "trivy",
            "audit": "audit.sh",
        }.get(checkers_list[0], checkers_list[0])
        if checkers_list
        else ""
    )
    tool_missing = bool(checkers_list) and not checkers.tool_available(tool)

    if findings:
        blocking = any(f.severity == "blocking" for f in findings)
        result.status = "BLOCKING" if blocking else "WARN"
        result.findings = findings
    elif tool_missing or problems:
        result.status = "NOT_CHECKED"
        result.reason = (
            "; ".join(problems) if problems else f"checker tool not installed: {tool}"
        )
    else:
        result.status = "PASS"
    return result


def build_verdict(
    repo: Path, config_path: Path, skip_dims: set[str]
) -> list[DimensionResult]:
    dims = load_dimensions(config_path)
    return [
        run_dimension(name, cfg, repo)
        for name, cfg in dims.items()
        if name not in skip_dims
    ]


def render_terminal(
    results: list[DimensionResult], stack: list[str], version: str
) -> str:
    lines = [f"SHIPCHECK v{version}", "repo stack: " + ", ".join(stack), ""]
    lines.append(f"{'DIMENSION':<16} {'STATUS':<11} FINDINGS")
    lines.append("-" * 60)
    blocking = warn = passed = not_checked = 0
    for r in results:
        n = len(r.findings)
        lines.append(f"{r.name:<16} {r.status:<11} {n}")
        if r.reason:
            lines.append(f"  -> {r.reason}")
        for f in r.findings[:5]:
            lines.append(f"    [{f.severity}] {f.title}")
        blocking += r.status == "BLOCKING"
        warn += r.status == "WARN"
        passed += r.status == "PASS"
        not_checked += r.status == "NOT_CHECKED"
    lines.append("-" * 60)
    lines.append(
        f"BLOCKING: {blocking} | WARN: {warn} | PASS: {passed} | NOT-CHECKED: {not_checked}"
    )
    return "\n".join(lines)
