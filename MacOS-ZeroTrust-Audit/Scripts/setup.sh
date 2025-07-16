#!/bin/bash

# macOS Zero Trust Audit System Setup Script
# This script installs dependencies and configures the audit system

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🔐 macOS Zero Trust Audit System Setup${NC}"
echo -e "${BLUE}======================================${NC}"

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}❌ This script is designed for macOS only${NC}"
    exit 1
fi

# Check macOS version
MACOS_VERSION=$(sw_vers -productVersion)
echo -e "${BLUE}📱 macOS Version: $MACOS_VERSION${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Homebrew if not present
if ! command_exists brew; then
    echo -e "${YELLOW}📦 Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo -e "${GREEN}✅ Homebrew already installed${NC}"
fi

# Update Homebrew
echo -e "${BLUE}🔄 Updating Homebrew...${NC}"
brew update

# Install required packages
echo -e "${BLUE}📦 Installing required packages...${NC}"
PACKAGES=(
    "osquery"        # System monitoring
    "gitleaks"       # Secret detection
    "jq"             # JSON processing
    "fswatch"        # File system monitoring
    "lsof"           # Process monitoring
    "netstat"        # Network monitoring
    "htop"           # Process monitoring
    "git"            # Version control
    "curl"           # HTTP requests
    "openssl"        # Encryption
)

for package in "${PACKAGES[@]}"; do
    if brew list "$package" &>/dev/null; then
        echo -e "${GREEN}✅ $package already installed${NC}"
    else
        echo -e "${YELLOW}📦 Installing $package...${NC}"
        brew install "$package"
    fi
done

# Install optional GUI tools
echo -e "${BLUE}🎨 Installing optional GUI tools...${NC}"
GUI_TOOLS=(
    "lulu"                  # Network monitoring
    "little-snitch"         # Network monitoring (if available)
    "oversight"             # Process monitoring
)

for tool in "${GUI_TOOLS[@]}"; do
    if brew list --cask "$tool" &>/dev/null; then
        echo -e "${GREEN}✅ $tool already installed${NC}"
    else
        echo -e "${YELLOW}📦 Installing $tool...${NC}"
        brew install --cask "$tool" || echo -e "${YELLOW}⚠️  $tool not available or failed to install${NC}"
    fi
done

# Create directory structure
echo -e "${BLUE}📁 Creating directory structure...${NC}"
mkdir -p "$PROJECT_DIR/Logs"
mkdir -p "$PROJECT_DIR/Config"
mkdir -p "$PROJECT_DIR/Documentation"
mkdir -p "$PROJECT_DIR/Scripts/lib"

# Set permissions
echo -e "${BLUE}🔐 Setting permissions...${NC}"
chmod +x "$PROJECT_DIR/Scripts"/*.sh
chmod 700 "$PROJECT_DIR/Logs"
chmod 644 "$PROJECT_DIR/Config"/*

# Create launchd plist for background service
echo -e "${BLUE}🔧 Creating background service...${NC}"
cat > "$PROJECT_DIR/Config/com.zerotrust.audit.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.zerotrust.audit</string>
    <key>ProgramArguments</key>
    <array>
        <string>SCRIPT_DIR_PLACEHOLDER/audit-runner.sh</string>
        <string>--background</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>PROJECT_DIR_PLACEHOLDER/Logs/audit.log</string>
    <key>StandardErrorPath</key>
    <string>PROJECT_DIR_PLACEHOLDER/Logs/audit-error.log</string>
    <key>WorkingDirectory</key>
    <string>PROJECT_DIR_PLACEHOLDER</string>
</dict>
</plist>
EOF

# Replace placeholders
sed -i '' "s|SCRIPT_DIR_PLACEHOLDER|$SCRIPT_DIR|g" "$PROJECT_DIR/Config/com.zerotrust.audit.plist"
sed -i '' "s|PROJECT_DIR_PLACEHOLDER|$PROJECT_DIR|g" "$PROJECT_DIR/Config/com.zerotrust.audit.plist"

# Create initial configuration files
echo -e "${BLUE}⚙️  Creating configuration files...${NC}"
if [ ! -f "$PROJECT_DIR/Config/audit.conf" ]; then
    cat > "$PROJECT_DIR/Config/audit.conf" << 'EOF'
# macOS Zero Trust Audit Configuration

# Monitoring Settings
ENABLE_NETWORK_MONITORING=true
ENABLE_FILE_MONITORING=true
ENABLE_PROCESS_MONITORING=true
ENABLE_COMPLIANCE_CHECKING=true

# Network Settings
MONITOR_OUTBOUND_CONNECTIONS=true
BLOCK_SUSPICIOUS_DOMAINS=true
LOG_DNS_QUERIES=true
ALERT_ON_DATA_EXFILTRATION=true

# File System Settings
SENSITIVE_PATHS="/Users/$(whoami)/Documents,/Users/$(whoami)/Desktop,/Users/$(whoami)/Downloads"
MONITOR_FILE_CHANGES=true
TRACK_FILE_EXPORTS=true
ALERT_ON_UNAUTHORIZED_ACCESS=true

# Process Settings
MONITOR_PRIVILEGE_ESCALATION=true
TRACK_RESOURCE_USAGE=true
ALERT_ON_SUSPICIOUS_BEHAVIOR=true

# Compliance Settings
ENABLE_GDPR_COMPLIANCE=true
ENABLE_SOX_COMPLIANCE=true
RETENTION_PERIOD_DAYS=90
ENCRYPT_AUDIT_LOGS=true

# Alert Settings
ALERT_METHODS="notification,log,email"
ALERT_THRESHOLD_HIGH=3
ALERT_THRESHOLD_MEDIUM=5
ALERT_THRESHOLD_LOW=10

# User Settings
USER_NAME="$(whoami)"
USER_EMAIL=""
NOTIFICATION_LEVEL="medium"
EOF
fi

# Create network rules configuration
if [ ! -f "$PROJECT_DIR/Config/network-rules.json" ]; then
    cat > "$PROJECT_DIR/Config/network-rules.json" << 'EOF'
{
    "version": "1.0",
    "rules": {
        "blocked_domains": [
            "suspicious-domain.com",
            "known-malware.net"
        ],
        "allowed_domains": [
            "github.com",
            "apple.com",
            "icloud.com"
        ],
        "sensitive_ports": [22, 23, 3389, 5900],
        "monitoring": {
            "log_all_connections": true,
            "alert_on_new_connections": true,
            "track_data_volume": true
        },
        "zero_trust": {
            "verify_all_connections": true,
            "require_authentication": true,
            "continuous_monitoring": true
        }
    }
}
EOF
fi

# Create compliance rules
if [ ! -f "$PROJECT_DIR/Config/compliance.json" ]; then
    cat > "$PROJECT_DIR/Config/compliance.json" << 'EOF'
{
    "version": "1.0",
    "gdpr": {
        "enabled": true,
        "data_processing_log": true,
        "consent_tracking": true,
        "data_retention": {
            "personal_data": 90,
            "audit_logs": 365
        },
        "data_subject_rights": {
            "access": true,
            "rectification": true,
            "erasure": true,
            "portability": true
        }
    },
    "sox": {
        "enabled": true,
        "financial_data_monitoring": true,
        "access_controls": true,
        "audit_trail": true,
        "segregation_of_duties": true
    },
    "custom_rules": [
        {
            "name": "sensitive_file_access",
            "pattern": ".*\\.(xlsx|csv|pdf|docx)$",
            "action": "log_and_alert",
            "severity": "medium"
        },
        {
            "name": "external_data_transfer",
            "pattern": "curl|wget|scp|rsync",
            "action": "block_and_alert",
            "severity": "high"
        }
    ]
}
EOF
fi

# Install osquery configuration
echo -e "${BLUE}🔧 Configuring osquery...${NC}"
if [ ! -f "/var/osquery/osquery.conf" ]; then
    sudo mkdir -p /var/osquery
    sudo cat > /var/osquery/osquery.conf << 'EOF'
{
    "options": {
        "config_plugin": "filesystem",
        "logger_plugin": "filesystem",
        "log_result_events": false,
        "schedule_splay_percent": 10,
        "pidfile": "/var/osquery/osquery.pid",
        "events_expiry": 3600,
        "database_path": "/var/osquery/osquery.db",
        "verbose": false,
        "worker_threads": 2,
        "enable_monitor": true
    },
    "schedule": {
        "system_info": {
            "query": "SELECT hostname, cpu_brand, physical_memory FROM system_info;",
            "interval": 3600
        },
        "network_connections": {
            "query": "SELECT pid, fd, socket, family, protocol, local_address, remote_address, local_port, remote_port FROM process_open_sockets WHERE remote_address != '';",
            "interval": 60
        },
        "file_events": {
            "query": "SELECT * FROM file_events WHERE path LIKE '/Users/%/Documents/%' OR path LIKE '/Users/%/Desktop/%';",
            "interval": 30
        }
    },
    "packs": {
        "osquery-monitoring": "/usr/local/share/osquery/packs/osquery-monitoring.conf"
    }
}
EOF
fi

# Create log rotation configuration
echo -e "${BLUE}📄 Setting up log rotation...${NC}"
cat > "$PROJECT_DIR/Config/logrotate.conf" << 'EOF'
/PROJECT_DIR_PLACEHOLDER/Logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 $(whoami) staff
}
EOF

sed -i '' "s|PROJECT_DIR_PLACEHOLDER|$PROJECT_DIR|g" "$PROJECT_DIR/Config/logrotate.conf"

# Request necessary permissions
echo -e "${BLUE}🔐 Requesting system permissions...${NC}"
echo -e "${YELLOW}⚠️  Please grant the following permissions when prompted:${NC}"
echo -e "  • Full Disk Access"
echo -e "  • Network monitoring"
echo -e "  • System events"
echo -e "  • Notifications"

# Open System Preferences to security settings
echo -e "${BLUE}🔧 Opening System Preferences for permissions...${NC}"
open "x-apple.systempreferences:com.apple.preference.security?Privacy"

# Final setup steps
echo -e "${GREEN}✅ Setup completed successfully!${NC}"
echo -e "${BLUE}Next steps:${NC}"
echo -e "1. Grant necessary permissions in System Preferences"
echo -e "2. Review and customize Config/audit.conf"
echo -e "3. Run: ./Scripts/audit-runner.sh --start"
echo -e "4. Open ZeroTrustAudit.app for dashboard"

echo -e "${YELLOW}📝 Configuration files created:${NC}"
echo -e "  • $PROJECT_DIR/Config/audit.conf"
echo -e "  • $PROJECT_DIR/Config/network-rules.json"
echo -e "  • $PROJECT_DIR/Config/compliance.json"

echo -e "${GREEN}🎉 Zero Trust Audit System ready!${NC}"