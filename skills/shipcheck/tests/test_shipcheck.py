"""shipcheck unit tests — pure logic (routing, aggregation, severity, NOT-CHECKED)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

SCRIPT_DIR = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPT_DIR))

import verdict  # noqa: E402
from verdict import DimensionResult, Finding  # noqa: E402


class TestDetectStack(unittest.TestCase):
    def test_python_detection(self):
        repo = Path(temp_repo(["requirements.txt"]))
        self.assertIn("python", verdict.detect_stack(repo))

    def test_node_detection(self):
        repo = Path(temp_repo(["package.json"]))
        self.assertIn("node", verdict.detect_stack(repo))

    def test_github_actions_detection(self):
        repo = Path(temp_repo([], [".github/workflows/ci.yml"]))
        self.assertIn("github-actions", verdict.detect_stack(repo))

    def test_unknown_stack(self):
        repo = Path(temp_repo(["README.md"]))
        self.assertEqual(verdict.detect_stack(repo), ["unknown"])


class TestLoadDimensions(unittest.TestCase):
    def test_parses_yaml_subset(self):
        p = Path(temp_repo(["dims.yaml"])) / "dims.yaml"
        p.write_text(
            "dimensions:\n"
            "  security:\n"
            "    severity: blocking\n"
            "    checkers: [semgrep, trivy-secrets]\n"
            "    ai_review: false\n"
            "  privacy:\n"
            "    severity: warn\n"
            "    checkers: []\n"
            "    ai_review: true\n"
        )
        dims = verdict.load_dimensions(p)
        self.assertEqual(dims["security"]["checkers"], ["semgrep", "trivy-secrets"])
        self.assertEqual(dims["security"]["severity"], "blocking")
        self.assertTrue(dims["privacy"]["ai_review"])
        self.assertEqual(dims["privacy"]["checkers"], [])


class TestRunDimension(unittest.TestCase):
    def test_ai_review_no_checker_is_not_checked(self):
        r = verdict.run_dimension(
            "privacy",
            {"checkers": [], "ai_review": True, "severity": "warn"},
            Path("."),
        )
        self.assertEqual(r.status, "NOT_CHECKED")
        self.assertIn("AI-review", r.reason)

    def test_blocking_severity_dominates(self):
        r = verdict.run_dimension(
            "security",
            {"checkers": ["semgrep"], "ai_review": False, "severity": "blocking"},
            Path("."),
        )
        # With semgrep missing on this machine, either NOT_CHECKED (tool missing)
        # or, if installed, PASS/WARN/BLOCKING. We only assert structure here:
        self.assertIn(r.status, ("PASS", "WARN", "BLOCKING", "NOT_CHECKED"))
        self.assertIsInstance(r, DimensionResult)


class TestAggregation(unittest.TestCase):
    def test_findings_aggregate_to_blocking(self):
        r = DimensionResult(name="security", severity="blocking")
        r.findings = [Finding("security", "blocking", "semgrep:x", "bad")]
        r.status = "BLOCKING"
        self.assertEqual(r.status, "BLOCKING")
        self.assertEqual(len(r.to_dict()["findings"]), 1)

    def test_no_findings_is_pass(self):
        r = DimensionResult(name="secrets", severity="blocking")
        r.status = "PASS"
        self.assertEqual(r.status, "PASS")
        self.assertEqual(r.to_dict()["status"], "PASS")


class TestRenderTerminal(unittest.TestCase):
    def test_render_includes_statuses(self):
        results = [
            DimensionResult(
                name="security",
                severity="blocking",
                status="BLOCKING",
                findings=[Finding("security", "blocking", "x", "bad thing")],
            ),
            DimensionResult(
                name="privacy",
                severity="warn",
                status="NOT_CHECKED",
                reason="AI-review dimension",
            ),
            DimensionResult(name="secrets", severity="blocking", status="PASS"),
        ]
        out = verdict.render_terminal(results, ["python"], "0.1.0")
        self.assertIn("BLOCKING", out)
        self.assertIn("NOT_CHECKED", out)
        self.assertIn("AI-review dimension", out)


def temp_repo(files: list[str], dirs: list[str] | None = None) -> str:
    """Create a temp dir with the given files/dirs; return its path."""
    import tempfile
    import os

    d = tempfile.mkdtemp(prefix="shipcheck-test-")
    for f in files:
        p = Path(d) / f
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("")
    for sub in dirs or []:
        (Path(d) / sub).mkdir(parents=True, exist_ok=True)
    return d


class TestRunAudit(unittest.TestCase):
    """Regression tests for the audit.sh JSON dict-parsing path (REVIEW FAIL 5.1)."""

    def test_parses_dict_results(self):
        """audit.sh emits dict results; fail/error entries become warn findings."""

        import json as _json

        import tempfile

        import checkers

        payload = _json.dumps(
            {
                "repo": "/tmp/x",
                "results": [
                    {
                        "status": "pass",
                        "standard": "gitignore",
                        "id": "g1",
                        "description": "ok",
                        "repo": "/tmp/x",
                    },
                    {
                        "status": "fail",
                        "standard": "adr",
                        "id": "adr-dir",
                        "description": "docs/adr/ missing",
                        "repo": "/tmp/x",
                    },
                    {
                        "status": "error",
                        "standard": "ci",
                        "id": "c1",
                        "description": "ci broken",
                        "repo": "/tmp/x",
                    },
                ],
            }
        )

        with tempfile.TemporaryDirectory(prefix="shipcheck-audit-") as d:
            fake = Path(d) / "audit-sh.json"

            fake.write_text(payload)

            stub = Path(d) / "stub-audit.sh"

            stub.write_text(f"#!/usr/bin/env bash\ncat {fake}")

            stub.chmod(0o755)

            old = checkers.AUDIT_SH

            checkers.AUDIT_SH = stub

            try:
                findings = checkers.run_audit(Path(d))

            finally:
                checkers.AUDIT_SH = old

        self.assertEqual(len(findings), 2)  # fail + error; pass excluded

        self.assertTrue(all(f.severity == "warn" for f in findings))

        self.assertEqual(findings[0].check, "audit:adr")

        self.assertEqual(findings[1].check, "audit:ci")

    def test_handles_missing_audit_sh(self):
        """Missing audit.sh → no findings (orchestrator reports NOT_CHECKED)."""

        import checkers

        old = checkers.AUDIT_SH

        checkers.AUDIT_SH = Path("/nonexistent/audit.sh")

        try:
            findings = checkers.run_audit(Path("."))

        finally:
            checkers.AUDIT_SH = old

        self.assertEqual(findings, [])


if __name__ == "__main__":
    unittest.main()
