#!/usr/bin/env python3
"""generate_report.py
Consolidate raw audit artefacts created by audit_runner.sh into a single
JSON document that matches the data model consumed by the SwiftUI dashboard.

Usage:
    generate_report.py <timestamp> <output_dir>
"""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path


def load_json(path: Path):
    if not path.exists():
        return None
    try:
        with path.open("r", encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError:
        return None


def main():
    if len(sys.argv) != 3:
        print("Usage: generate_report.py <timestamp> <output_dir>", file=sys.stderr)
        sys.exit(1)

    ts_str, output_dir = sys.argv[1:]
    out_dir = Path(output_dir).expanduser()

    # Build paths
    gitleaks_path = out_dir / f"gitleaks_{ts_str}.json"
    osquery_path = out_dir / f"osquery_{ts_str}.json"
    fsusage_path = out_dir / f"fsusage_{ts_str}.log"

    # Data Access section (very coarse PoC)
    data_access = {
        "file": "N/A",
        "app": "N/A",
        "network_exfil": "Unknown",
        "zero_trust_verified": False,
    }

    # Use osquery result to populate data_access.app if possible
    osquery_data = load_json(osquery_path)
    if osquery_data:
        if isinstance(osquery_data, list) and osquery_data:
            first = osquery_data[0]
            data_access["app"] = first.get("name", "curl")

    # Determine compliance flags – placeholder logic
    compliance = {
        "GDPR": "PASS",
        "SOX": "PASS",
    }

    if gitleaks_path.exists() and gitleaks_path.stat().st_size > 0:
        compliance["SOX"] = "FLAG - secrets in repo"

    # Assemble final document
    report = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "user": os.getenv("USER", "unknown"),
        "device": os.uname().nodename,
        "data_access": data_access,
        "compliance_flags": compliance,
    }

    final_path = out_dir / f"audit_{ts_str}.json"
    with final_path.open("w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    print(f"[audit] Consolidated report written to {final_path}")


if __name__ == "__main__":
    main()