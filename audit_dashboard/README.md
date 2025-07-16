# Personal Zero-Trust Data Audit Dashboard (macOS ＋ watchOS)

This directory contains a self-service toolkit for detecting, preventing, and auditing data-leakage and privacy risks on macOS while following Zero-Trust principles.  It consists of two layers:

1. **Shell-based Audit Pipeline** – collects evidence from your Mac (network, file-system, OS logs, Gitleaks, OSQuery, …) and produces machine-readable JSON reports.
2. **SwiftUI Dashboard** – a universal SwiftUI application (macOS ＆ watchOS) that visualises the reports in near real-time so you can track compliance posture at a glance.

---

## 1  Shell-based Audit Pipeline

### Prerequisites
```bash
brew install gitleaks osquery
# LuLu firewall is optional but recommended – https://objective-see.org/products/lulu.html
```

### Usage
```bash
chmod +x scripts/audit_runner.sh
./scripts/audit_runner.sh
```
This generates timestamped artefacts under **`$HOME/.local/audit_reports/`**:
```
~/.local/audit_reports/
├── audit_2025-07-16T02-00-00Z.json   # consolidated summary
├── gitleaks_2025-07-16T02-00-00Z.json
├── osquery_2025-07-16T02-00-00Z.json
├── fsusage_2025-07-16T02-00-00Z.log
└── macos_logs_2025-07-16T02-00-00Z.log
```

### Automating via _launchd_
Create `~/Library/LaunchAgents/com.example.audit.plist` to trigger the script every hour.  See Apple’s launchd documentation for details.

---

## 2  SwiftUI Dashboard

Open **`Swift/DataAuditDashboard.xcodeproj`** (or add the Swift sources to a new Xcode project) and build for:
* **macOS app** – shows a list of audit entries and compliance flags.
* **watchOS companion app** – lightweight glance view that mirrors the most recent entry.

The dashboard watches **`~/.local/audit_reports/`** for file changes and refreshes automatically.

---

## Directory Layout
```
audit_dashboard/
├── README.md
├── scripts/
│   ├── audit_runner.sh
│   └── generate_report.py
└── Swift/
    ├── Shared/            # models & business logic shared by all platforms
    ├── macOS/             # macOS-specific App entry point
    └── Watch/             # watchOS App
```

---

## Roadmap / TODO
* Harden JSON schema & add cryptographic signing for chain-of-custody.
* Integrate Cloudflare WARP posture checks via REST API.
* macOS menubar helper for quick status.
* Push notifications to the Watch when a **FLAG** is detected.