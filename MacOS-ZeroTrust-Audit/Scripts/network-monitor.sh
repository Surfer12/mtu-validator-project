#!/bin/bash

# Network Monitor Script for macOS Zero Trust Audit System
# Monitors network connections, DNS queries, and potential data exfiltration

set -euo pipefail

# Script directory and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/Config/audit.conf"
NETWORK_RULES="$PROJECT_DIR/Config/network-rules.json"
LOG_DIR="$PROJECT_DIR/Logs"
NETWORK_LOG="$LOG_DIR/network.log"
ALERT_LOG="$LOG_DIR/alerts.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo -e "${RED}❌ Configuration file not found: $CONFIG_FILE${NC}"
    exit 1
fi

# Initialize log files
mkdir -p "$LOG_DIR"
touch "$NETWORK_LOG" "$ALERT_LOG"

# Function to log with timestamp
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$NETWORK_LOG"
}

# Function to send alert
send_alert() {
    local severity="$1"
    local title="$2"
    local message="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log alert
    echo "[$timestamp] [ALERT-$severity] $title: $message" >> "$ALERT_LOG"
    
    # Send macOS notification
    if [[ "$ALERT_METHODS" == *"notification"* ]]; then
        osascript -e "display notification \"$message\" with title \"Zero Trust Alert: $title\" sound name \"Glass\""
    fi
    
    # Create audit record
    local audit_record="{
        \"timestamp\": \"$timestamp\",
        \"user\": \"$USER_NAME\",
        \"device\": \"$(hostname)\",
        \"alert_type\": \"network\",
        \"severity\": \"$severity\",
        \"title\": \"$title\",
        \"message\": \"$message\",
        \"compliance_flags\": {
            \"GDPR\": \"$([ "$ENABLE_GDPR_COMPLIANCE" = "true" ] && echo "MONITORED" || echo "DISABLED")\",
            \"SOX\": \"$([ "$ENABLE_SOX_COMPLIANCE" = "true" ] && echo "MONITORED" || echo "DISABLED")\"
        }
    }"
    
    echo "$audit_record" | jq '.' >> "$LOG_DIR/audit_records.json"
}

# Function to check if domain is blocked
is_blocked_domain() {
    local domain="$1"
    if [ -f "$NETWORK_RULES" ]; then
        local blocked_domains=$(jq -r '.rules.blocked_domains[]' "$NETWORK_RULES" 2>/dev/null || echo "")
        echo "$blocked_domains" | grep -q "^$domain$" && return 0
    fi
    return 1
}

# Function to check if domain is allowed
is_allowed_domain() {
    local domain="$1"
    if [ -f "$NETWORK_RULES" ]; then
        local allowed_domains=$(jq -r '.rules.allowed_domains[]' "$NETWORK_RULES" 2>/dev/null || echo "")
        echo "$allowed_domains" | grep -q "^$domain$" && return 0
    fi
    return 1
}

# Function to monitor network connections
monitor_connections() {
    log_message "INFO" "Starting network connection monitoring"
    
    # Monitor active connections
    lsof -i -n -P | grep -v "LISTEN" | while read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+([0-9]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)->([^[:space:]]+) ]]; then
            local process="${BASH_REMATCH[1]}"
            local pid="${BASH_REMATCH[2]}"
            local user="${BASH_REMATCH[3]}"
            local connection_info="${BASH_REMATCH[9]}"
            
            # Extract remote address
            local remote_addr=$(echo "$connection_info" | cut -d':' -f1)
            local remote_port=$(echo "$connection_info" | cut -d':' -f2)
            
            # Skip local connections
            [[ "$remote_addr" =~ ^127\.|^192\.168\.|^10\.|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-1]\. ]] && continue
            
            # Check if connection is suspicious
            if is_blocked_domain "$remote_addr"; then
                send_alert "HIGH" "Blocked Domain Access" "Process $process (PID: $pid) attempted to connect to blocked domain: $remote_addr"
                # Block the connection (requires additional firewall rules)
                log_message "WARN" "Blocked connection from $process to $remote_addr:$remote_port"
            elif ! is_allowed_domain "$remote_addr"; then
                send_alert "MEDIUM" "Unknown Domain Access" "Process $process (PID: $pid) connected to unknown domain: $remote_addr:$remote_port"
                log_message "INFO" "New connection: $process -> $remote_addr:$remote_port"
            fi
        fi
    done
}

# Function to monitor DNS queries
monitor_dns() {
    log_message "INFO" "Starting DNS query monitoring"
    
    # Monitor DNS queries using system log
    log stream --predicate 'subsystem == "com.apple.network.stateprovider"' --style syslog | while read -r line; do
        if [[ "$line" =~ DNS.*query.*([a-zA-Z0-9.-]+\.[a-zA-Z]{2,}) ]]; then
            local domain="${BASH_REMATCH[1]}"
            
            # Check domain against rules
            if is_blocked_domain "$domain"; then
                send_alert "HIGH" "Blocked DNS Query" "DNS query to blocked domain: $domain"
                log_message "WARN" "Blocked DNS query: $domain"
            elif [[ "$domain" =~ \.(tk|ml|ga|cf)$ ]]; then
                send_alert "MEDIUM" "Suspicious TLD" "DNS query to suspicious TLD: $domain"
                log_message "WARN" "Suspicious DNS query: $domain"
            else
                log_message "INFO" "DNS query: $domain"
            fi
        fi
    done &
    
    DNS_MONITOR_PID=$!
    echo $DNS_MONITOR_PID > "$LOG_DIR/dns_monitor.pid"
}

# Function to detect data exfiltration
detect_exfiltration() {
    log_message "INFO" "Starting data exfiltration detection"
    
    # Monitor for large data transfers
    netstat -I en0 -b | tail -n +2 | while read -r line; do
        local bytes_in=$(echo "$line" | awk '{print $7}')
        local bytes_out=$(echo "$line" | awk '{print $10}')
        
        # Check for abnormal upload activity (threshold: 100MB)
        if [ "$bytes_out" -gt 104857600 ]; then
            send_alert "HIGH" "Large Data Upload" "Detected large outbound data transfer: $bytes_out bytes"
            log_message "WARN" "Large upload detected: $bytes_out bytes"
        fi
    done
}

# Function to monitor file uploads
monitor_uploads() {
    log_message "INFO" "Starting file upload monitoring"
    
    # Monitor common upload processes
    ps aux | grep -E "(curl|wget|scp|rsync|rclone)" | grep -v grep | while read -r line; do
        local process_info=$(echo "$line" | awk '{print $2, $11}')
        local pid=$(echo "$process_info" | cut -d' ' -f1)
        local command=$(echo "$process_info" | cut -d' ' -f2-)
        
        # Check if process is uploading to external server
        if [[ "$command" =~ (ftp|sftp|http|https):// ]]; then
            send_alert "HIGH" "File Upload Detected" "Process $command (PID: $pid) uploading to external server"
            log_message "WARN" "File upload detected: $command"
            
            # Get file being uploaded
            local files=$(lsof -p "$pid" | grep -E "\.(xlsx|csv|pdf|docx|txt|json)$" | awk '{print $9}')
            if [ -n "$files" ]; then
                send_alert "HIGH" "Sensitive File Upload" "Sensitive files being uploaded: $files"
                log_message "CRITICAL" "Sensitive file upload: $files"
            fi
        fi
    done
}

# Function to check cloudflare warp status
check_zero_trust_status() {
    log_message "INFO" "Checking Zero Trust network status"
    
    # Check if Cloudflare WARP is running
    if pgrep -f "Cloudflare WARP" > /dev/null; then
        log_message "INFO" "Cloudflare WARP is running - Zero Trust network active"
        return 0
    else
        send_alert "MEDIUM" "Zero Trust Network Inactive" "Cloudflare WARP is not running - Zero Trust network protection disabled"
        log_message "WARN" "Zero Trust network protection is disabled"
        return 1
    fi
}

# Function to monitor VPN connections
monitor_vpn() {
    log_message "INFO" "Monitoring VPN connections"
    
    # Check active VPN connections
    local vpn_status=$(scutil --nc list | grep Connected || echo "")
    
    if [ -n "$vpn_status" ]; then
        log_message "INFO" "VPN connection detected: $vpn_status"
        
        # Check if VPN is authorized
        if [[ "$vpn_status" =~ (company|corporate|authorized) ]]; then
            log_message "INFO" "Authorized VPN connection active"
        else
            send_alert "MEDIUM" "Unauthorized VPN" "Unauthorized VPN connection detected: $vpn_status"
        fi
    fi
}

# Function to generate network audit report
generate_network_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local report_file="$LOG_DIR/network_report_$(date +%Y%m%d_%H%M%S).json"
    
    local report="{
        \"timestamp\": \"$timestamp\",
        \"report_type\": \"network_audit\",
        \"user\": \"$USER_NAME\",
        \"device\": \"$(hostname)\",
        \"zero_trust_status\": \"$(check_zero_trust_status && echo "active" || echo "inactive")\",
        \"monitoring_status\": {
            \"network_connections\": true,
            \"dns_queries\": true,
            \"data_exfiltration\": true,
            \"file_uploads\": true,
            \"vpn_monitoring\": true
        },
        \"compliance_status\": {
            \"gdpr\": \"$([ "$ENABLE_GDPR_COMPLIANCE" = "true" ] && echo "enabled" || echo "disabled")\",
            \"sox\": \"$([ "$ENABLE_SOX_COMPLIANCE" = "true" ] && echo "enabled" || echo "disabled")\"
        },
        \"statistics\": {
            \"connections_monitored\": $(grep -c "New connection" "$NETWORK_LOG" || echo 0),
            \"dns_queries_logged\": $(grep -c "DNS query" "$NETWORK_LOG" || echo 0),
            \"alerts_generated\": $(grep -c "ALERT" "$ALERT_LOG" || echo 0),
            \"blocked_attempts\": $(grep -c "Blocked" "$NETWORK_LOG" || echo 0)
        }
    }"
    
    echo "$report" | jq '.' > "$report_file"
    log_message "INFO" "Network audit report generated: $report_file"
}

# Function to cleanup and stop monitoring
cleanup() {
    log_message "INFO" "Stopping network monitoring"
    
    # Kill DNS monitor if running
    if [ -f "$LOG_DIR/dns_monitor.pid" ]; then
        local dns_pid=$(cat "$LOG_DIR/dns_monitor.pid")
        kill "$dns_pid" 2>/dev/null || true
        rm -f "$LOG_DIR/dns_monitor.pid"
    fi
    
    # Generate final report
    generate_network_report
    
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Main monitoring loop
main() {
    log_message "INFO" "Starting Zero Trust Network Monitor"
    
    # Check if network monitoring is enabled
    if [ "$ENABLE_NETWORK_MONITORING" != "true" ]; then
        log_message "INFO" "Network monitoring is disabled"
        exit 0
    fi
    
    # Check Zero Trust status
    check_zero_trust_status
    
    # Start DNS monitoring in background
    monitor_dns
    
    # Main monitoring loop
    while true; do
        monitor_connections
        detect_exfiltration
        monitor_uploads
        monitor_vpn
        
        # Generate periodic report
        if [ $(date +%M) -eq 0 ]; then
            generate_network_report
        fi
        
        sleep 30
    done
}

# Handle command line arguments
case "${1:-}" in
    --start)
        main
        ;;
    --stop)
        cleanup
        ;;
    --report)
        generate_network_report
        ;;
    --status)
        check_zero_trust_status
        ;;
    *)
        echo "Usage: $0 [--start|--stop|--report|--status]"
        echo "  --start   Start network monitoring"
        echo "  --stop    Stop network monitoring"
        echo "  --report  Generate network audit report"
        echo "  --status  Check Zero Trust network status"
        exit 1
        ;;
esac