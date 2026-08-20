#!/usr/bin/env python3
"""shipcheck checkers — thin subprocess wrappers over existing tools.

Constitution: reuse not rebuild; tool-first. Each runner returns a list of
Finding objects. Missing tools return [] (the orchestrator reports
NOT-CHECKED via shutil.which); timeout/unparseable output returns a warn
Finding so the verdict is never silent.

Tools: semgrep (SAST), trivy (secrets + vulns), audit.sh (standards).
"""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

from model import Finding

CHECKER_TIMEOUTS = {"semgrep": 90, "trivy": 90, "audit": 60}
AUDIT_SH = Path.home() / "projects/dev/standards/scripts/audit.sh"


def _run(cmd: list[str], cwd: Path, timeout: int) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd, cwd=str(cwd), capture_output=True, text=True, timeout=timeout, check=False
    )


def tool_available(name: str) -> bool:
    """True if the checker's CLI is on PATH (audit.sh checked by path)."""
    if name == "audit.sh":
        return AUDIT_SH.exists()
    return shutil.which(name) is not None


def _timeout_finding(dimension: str, check: str, scanner: str) -> Finding:
    return Finding(dimension, "warn", check, f"{scanner} timed out (>90s)", "SKIPPED")


def _unparseable_finding(dimension: str, check: str, raw: str) -> Finding:
    return Finding(dimension, "warn", check, "output unparseable", raw[:200])


def run_semgrep(repo: Path) -> list[Finding]:
    """SAST via `semgrep --config auto --json --quiet`. Blocking on ERROR/WARNING."""
    if not tool_available("semgrep"):
        return []
    try:
        proc = _run(
            ["semgrep", "--config", "auto", "--json", "--quiet", "."],
            repo,
            CHECKER_TIMEOUTS["semgrep"],
        )
    except subprocess.TimeoutExpired:
        return [_timeout_finding("security", "semgrep", "semgrep")]

    raw = (proc.stdout or "") + (proc.stderr or "")
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return [_unparseable_finding("security", "semgrep", raw)]

    findings: list[Finding] = []
    for result in data.get("results", []):
        sev = (result.get("extra", {}).get("severity") or "").upper()
        is_blocking = sev in ("ERROR", "WARNING", "BLOCKING")
        path = result.get("path", "")
        start = result.get("start", {}).get("line", "")
        msg = (result.get("extra", {}).get("message") or "").strip()
        rule = result.get("check_id", "")
        title = f"{path}:{start} — {msg.splitlines()[0] if msg else rule}"
        findings.append(
            Finding(
                dimension="security",
                severity="blocking" if is_blocking else "warn",
                check=f"semgrep:{rule}",
                title=title,
                detail=msg[:500],
                evidence=[f"{path}:{start}"],
            )
        )
    return findings


def run_trivy(repo: Path, scanner: str, dimension: str, check: str) -> list[Finding]:
    """trivy fs scan: `secret` or `vuln`. Secrets block; CRITICAL/HIGH vulns block."""
    if not tool_available("trivy"):
        return []
    try:
        proc = _run(
            [
                "trivy",
                "fs",
                "--scanners",
                scanner,
                "--no-progress",
                "--exit-code",
                "0",
                "--format",
                "json",
                ".",
            ],
            repo,
            CHECKER_TIMEOUTS["trivy"],
        )
    except subprocess.TimeoutExpired:
        return [_timeout_finding(dimension, check, f"trivy {scanner}")]

    try:
        data = json.loads(proc.stdout or "{}")
    except json.JSONDecodeError:
        return [_unparseable_finding(dimension, check, proc.stdout[:200])]

    findings: list[Finding] = []
    if scanner == "secret":
        for target in data.get("Results", []):
            for secret in target.get("Secrets", []):
                findings.append(
                    Finding(
                        dimension=dimension,
                        severity="blocking",
                        check=check,
                        title=f"{target.get('Target', '?')}:{secret.get('StartLine', '?')} — {secret.get('RuleID', 'secret')}",
                        detail=(secret.get("Match") or "")[:200],
                        evidence=[
                            f"{target.get('Target', '?')}:{secret.get('StartLine', '?')}"
                        ],
                    )
                )
    else:  # vuln
        for target in data.get("Results", []):
            for vuln in target.get("Vulnerabilities", []):
                sev = (vuln.get("Severity") or "").upper()
                findings.append(
                    Finding(
                        dimension=dimension,
                        severity="blocking" if sev in ("CRITICAL", "HIGH") else "warn",
                        check=f"{check}:{vuln.get('VulnerabilityID', '?')}",
                        title=f"{vuln.get('PkgName', '?')} {vuln.get('InstalledVersion', '?')} — "
                        f"{vuln.get('VulnerabilityID', '?')} ({sev})",
                        detail=(vuln.get("Title") or "")[:300],
                        evidence=[
                            vuln.get("VulnerabilityID", "?"),
                            vuln.get("PkgName", "?"),
                        ],
                    )
                )
    return findings


def run_audit(repo: Path) -> list[Finding]:
    """Standards compliance via audit.sh. Always WARN tier (VALIDATION noise lesson)."""
    if not AUDIT_SH.exists():
        return []
    try:
        proc = _run(
            ["bash", str(AUDIT_SH), str(repo), "--report", "json"],
            repo,
            CHECKER_TIMEOUTS["audit"],
        )
    except subprocess.TimeoutExpired:
        return [_timeout_finding("repo-hygiene", "audit", "audit.sh")]

    try:
        data = json.loads(proc.stdout or "{}")
    except json.JSONDecodeError:
        return [_unparseable_finding("repo-hygiene", "audit", proc.stdout[:200])]

    findings: list[Finding] = []

    entries = data.get("results", data.get("RESULT", []))

    for entry in entries:
        if isinstance(entry, dict):
            status = entry.get("status", "")

            if status in ("fail", "error"):
                standard = entry.get("standard", "?")

                desc = entry.get("description", entry.get("id", "?"))

                findings.append(
                    Finding(
                        dimension="repo-hygiene",
                        severity="warn",
                        check=f"audit:{standard}",
                        title=desc,
                        evidence=[str(entry)],
                    )
                )

        elif isinstance(entry, str):
            parts = entry.split("|")

            if len(parts) >= 4 and parts[0] in ("fail", "error"):
                findings.append(
                    Finding(
                        dimension="repo-hygiene",
                        severity="warn",
                        check=f"audit:{parts[1]}",
                        title=parts[3],
                        evidence=[entry],
                    )
                )

    return findings
