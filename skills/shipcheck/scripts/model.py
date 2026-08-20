#!/usr/bin/env python3
"""shipcheck model — Finding / DimensionResult dataclasses (shared, no deps)."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class Finding:
    dimension: str
    severity: str  # blocking | warn | info
    check: str
    title: str
    detail: str = ""
    evidence: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "dimension": self.dimension,
            "severity": self.severity,
            "check": self.check,
            "title": self.title,
            "detail": self.detail,
            "evidence": self.evidence,
        }


@dataclass
class DimensionResult:
    name: str
    severity: str
    status: str = ""  # PASS | WARN | BLOCKING | NOT_CHECKED
    findings: list[Finding] = field(default_factory=list)
    reason: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {
            "dimension": self.name,
            "status": self.status,
            "findings": [f.to_dict() for f in self.findings],
            "reason": self.reason,
        }
