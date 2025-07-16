#!/usr/bin/env bash
# ----------------------------------------
# audit_runner.sh
# Collects multiple evidence sources on macOS and generates a consolidated
# JSON report that the SwiftUI dashboard can ingest.
# ----------------------------------------

set -euo pipefail

# Where raw artefacts & final report will be stored
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/.local/audit_reports}"
mkdir -p "$OUTPUT_DIR"

# Timestamp used for all artefacts
TS=$(date -u +"%Y-%m-%dT%H-%M-%SZ")

echo "[audit] Starting audit cycle @ $TS"

echo "[audit] 1/4  Running Gitleaks (source = $HOME)"
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks detect \
    --source "$HOME" \
    --report-format json \
    --report-path "$OUTPUT_DIR/gitleaks_${TS}.json" || true
else
  echo "[audit] WARN: gitleaks is not installed; skipping"
fi

echo "[audit] 2/4  Running OSQuery"
if command -v osqueryi >/dev/null 2>&1; then
  osqueryi --json "SELECT * FROM processes WHERE name = 'curl' AND cmdline LIKE '%sensitive_file%';" \
    > "$OUTPUT_DIR/osquery_${TS}.json" || true
else
  echo "[audit] WARN: osquery is not installed; skipping"
fi

echo "[audit] 3/4  Capturing fs_usage (10 s window)"
# Needs sudo for full visibility; fall back silently if not authorised
if command -v fs_usage >/dev/null 2>&1; then
  { sudo -n true 2>/dev/null && SUDO="sudo"; } || SUDO=""
  $SUDO fs_usage -w -t 10 2>/dev/null | grep -i "Documents" \
      > "$OUTPUT_DIR/fsusage_${TS}.log" || true
else
  echo "[audit] WARN: fs_usage not available; skipping"
fi

echo "[audit] 4/4  Querying macOS Unified Logs (last 1 h)"
log show --last 1h --predicate 'eventMessage CONTAINS[c] "export"' \
    --info --debug --style syslog \
    > "$OUTPUT_DIR/macos_logs_${TS}.log" || true

# Consolidate using Python helper
python3 "$(dirname "$0")/generate_report.py" "$TS" "$OUTPUT_DIR" || {
  echo "[audit] ERROR: failed to consolidate report" >&2
  exit 1
}

echo "[audit] Audit completed – report @ $OUTPUT_DIR/audit_${TS}.json"