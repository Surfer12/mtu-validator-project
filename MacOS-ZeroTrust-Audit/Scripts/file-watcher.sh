#!/bin/bash

# File Watcher Script for macOS Zero Trust Audit System
# Monitors file access, modifications, and potential data exfiltration

set -euo pipefail

# Script directory and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/Config/audit.conf"
COMPLIANCE_RULES="$PROJECT_DIR/Config/compliance.json"
LOG_DIR="$PROJECT_DIR/Logs"
FILE_LOG="$LOG_DIR/file_access.log"
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
touch "$FILE_LOG" "$ALERT_LOG"

# Function to log with timestamp
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$FILE_LOG"
}

# Function to send alert
send_alert() {
    local severity="$1"
    local title="$2"
    local message="$3"
    local file_path="${4:-}"
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
        \"alert_type\": \"file_access\",
        \"severity\": \"$severity\",
        \"title\": \"$title\",
        \"message\": \"$message\",
        \"file_path\": \"$file_path\",
        \"data_access\": {
            \"file\": \"$file_path\",
            \"access_type\": \"$(get_access_type "$file_path")\",
            \"size\": \"$(get_file_size "$file_path")\",
            \"permissions\": \"$(get_file_permissions "$file_path")\"
        },
        \"compliance_flags\": {
            \"GDPR\": \"$(check_gdpr_compliance "$file_path")\",
            \"SOX\": \"$(check_sox_compliance "$file_path")\"
        }
    }"
    
    echo "$audit_record" | jq '.' >> "$LOG_DIR/audit_records.json"
}

# Function to get access type
get_access_type() {
    local file_path="$1"
    if [[ "$file_path" =~ \.(xlsx|csv|pdf|docx|txt|json)$ ]]; then
        echo "sensitive_document"
    elif [[ "$file_path" =~ \.(jpg|png|gif|mp4|mov)$ ]]; then
        echo "media_file"
    elif [[ "$file_path" =~ \.(zip|tar|gz|7z)$ ]]; then
        echo "archive"
    else
        echo "general_file"
    fi
}

# Function to get file size
get_file_size() {
    local file_path="$1"
    if [ -f "$file_path" ]; then
        stat -f%z "$file_path" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to get file permissions
get_file_permissions() {
    local file_path="$1"
    if [ -f "$file_path" ]; then
        stat -f%Op "$file_path" 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# Function to check GDPR compliance
check_gdpr_compliance() {
    local file_path="$1"
    if [ "$ENABLE_GDPR_COMPLIANCE" != "true" ]; then
        echo "DISABLED"
        return
    fi
    
    # Check if file contains personal data patterns
    if [[ "$file_path" =~ (personal|private|confidential|gdpr) ]]; then
        echo "SENSITIVE"
    elif [[ "$file_path" =~ \.(xlsx|csv)$ ]]; then
        echo "POTENTIAL_PII"
    else
        echo "PASS"
    fi
}

# Function to check SOX compliance
check_sox_compliance() {
    local file_path="$1"
    if [ "$ENABLE_SOX_COMPLIANCE" != "true" ]; then
        echo "DISABLED"
        return
    fi
    
    # Check if file contains financial data patterns
    if [[ "$file_path" =~ (financial|accounting|revenue|audit|sox) ]]; then
        echo "FINANCIAL_DATA"
    elif [[ "$file_path" =~ (invoice|receipt|payment|transaction) ]]; then
        echo "FINANCIAL_TRANSACTION"
    else
        echo "PASS"
    fi
}

# Function to check if file is sensitive
is_sensitive_file() {
    local file_path="$1"
    
    # Check file extension
    if [[ "$file_path" =~ \.(xlsx|csv|pdf|docx|key|numbers|pages)$ ]]; then
        return 0
    fi
    
    # Check file path patterns
    if [[ "$file_path" =~ (Documents|Desktop|Downloads|Private|Confidential) ]]; then
        return 0
    fi
    
    # Check custom patterns from compliance rules
    if [ -f "$COMPLIANCE_RULES" ]; then
        local patterns=$(jq -r '.custom_rules[].pattern' "$COMPLIANCE_RULES" 2>/dev/null || echo "")
        while IFS= read -r pattern; do
            if [[ "$file_path" =~ $pattern ]]; then
                return 0
            fi
        done <<< "$patterns"
    fi
    
    return 1
}

# Function to monitor file system using fs_usage
monitor_file_system() {
    log_message "INFO" "Starting file system monitoring with fs_usage"
    
    # Monitor file system calls
    sudo fs_usage -w -f pathname | while read -r line; do
        # Parse fs_usage output
        if [[ "$line" =~ ([0-9]+\.[0-9]+)[[:space:]]+([A-Za-z_]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+([^[:space:]]+)[[:space:]]+(.+) ]]; then
            local timestamp="${BASH_REMATCH[1]}"
            local syscall="${BASH_REMATCH[2]}"
            local file_path="${BASH_REMATCH[7]}"
            local process="${BASH_REMATCH[6]}"
            local pid="${BASH_REMATCH[4]}"
            
            # Skip system files and directories
            [[ "$file_path" =~ ^(/System|/Library|/private|/dev|/tmp) ]] && continue
            
            # Check if file is in sensitive paths
            local sensitive_paths_array
            IFS=',' read -ra sensitive_paths_array <<< "$SENSITIVE_PATHS"
            
            local is_sensitive_path=false
            for sensitive_path in "${sensitive_paths_array[@]}"; do
                if [[ "$file_path" == "$sensitive_path"* ]]; then
                    is_sensitive_path=true
                    break
                fi
            done
            
            if [ "$is_sensitive_path" = true ] || is_sensitive_file "$file_path"; then
                case "$syscall" in
                    open|read_nocancel)
                        log_message "INFO" "File access: $process (PID: $pid) accessed $file_path"
                        
                        # Check for unauthorized access
                        if [[ "$process" =~ (curl|wget|scp|rsync|python|ruby|node) ]]; then
                            send_alert "HIGH" "Unauthorized File Access" "Process $process (PID: $pid) accessed sensitive file: $file_path" "$file_path"
                        fi
                        ;;
                    write|write_nocancel)
                        log_message "INFO" "File modification: $process (PID: $pid) modified $file_path"
                        
                        # Check for sensitive file modifications
                        if is_sensitive_file "$file_path"; then
                            send_alert "MEDIUM" "Sensitive File Modified" "Process $process (PID: $pid) modified sensitive file: $file_path" "$file_path"
                        fi
                        ;;
                    rename|unlink)
                        log_message "WARN" "File operation: $process (PID: $pid) performed $syscall on $file_path"
                        
                        if is_sensitive_file "$file_path"; then
                            send_alert "HIGH" "Sensitive File Operation" "Process $process (PID: $pid) performed $syscall on sensitive file: $file_path" "$file_path"
                        fi
                        ;;
                esac
            fi
        fi
    done &
    
    FS_MONITOR_PID=$!
    echo $FS_MONITOR_PID > "$LOG_DIR/fs_monitor.pid"
}

# Function to monitor file changes using fswatch
monitor_file_changes() {
    log_message "INFO" "Starting file change monitoring with fswatch"
    
    # Convert sensitive paths to array and monitor each
    local sensitive_paths_array
    IFS=',' read -ra sensitive_paths_array <<< "$SENSITIVE_PATHS"
    
    for sensitive_path in "${sensitive_paths_array[@]}"; do
        # Trim whitespace
        sensitive_path=$(echo "$sensitive_path" | xargs)
        
        if [ -d "$sensitive_path" ]; then
            fswatch -r "$sensitive_path" | while read -r changed_file; do
                log_message "INFO" "File change detected: $changed_file"
                
                # Get the process that changed the file
                local lsof_output=$(lsof "$changed_file" 2>/dev/null | tail -n +2 | head -1)
                if [ -n "$lsof_output" ]; then
                    local process=$(echo "$lsof_output" | awk '{print $1}')
                    local pid=$(echo "$lsof_output" | awk '{print $2}')
                    
                    # Check if change is suspicious
                    if [[ "$process" =~ (curl|wget|scp|rsync|python|ruby|node|dropbox|gdrive|onedrive) ]]; then
                        send_alert "HIGH" "Suspicious File Change" "Process $process (PID: $pid) changed file: $changed_file" "$changed_file"
                    elif is_sensitive_file "$changed_file"; then
                        send_alert "MEDIUM" "Sensitive File Changed" "Sensitive file changed: $changed_file" "$changed_file"
                    fi
                fi
            done &
        fi
    done
}

# Function to monitor cloud sync activity
monitor_cloud_sync() {
    log_message "INFO" "Starting cloud sync monitoring"
    
    # Monitor common cloud sync processes
    while true; do
        # Check for Dropbox activity
        if pgrep -f "Dropbox" > /dev/null; then
            local dropbox_log="/Users/$USER/.dropbox/logs/sync.log"
            if [ -f "$dropbox_log" ]; then
                tail -n 1 "$dropbox_log" | while read -r line; do
                    if [[ "$line" =~ upload.*\.(xlsx|csv|pdf|docx) ]]; then
                        send_alert "HIGH" "Cloud Upload Detected" "Dropbox uploading sensitive file: $line"
                    fi
                done
            fi
        fi
        
        # Check for Google Drive activity
        if pgrep -f "Google Drive" > /dev/null; then
            log_message "INFO" "Google Drive sync active"
            # Monitor Google Drive sync folder
            local gdrive_folder="/Users/$USER/Google Drive"
            if [ -d "$gdrive_folder" ]; then
                find "$gdrive_folder" -type f -name "*.xlsx" -o -name "*.csv" -o -name "*.pdf" -newer "$LOG_DIR/last_check" 2>/dev/null | while read -r file; do
                    send_alert "MEDIUM" "Google Drive Sync" "Sensitive file synced to Google Drive: $file" "$file"
                done
            fi
        fi
        
        # Check for iCloud activity
        local icloud_folder="/Users/$USER/Library/Mobile Documents/com~apple~CloudDocs"
        if [ -d "$icloud_folder" ]; then
            find "$icloud_folder" -type f -name "*.xlsx" -o -name "*.csv" -o -name "*.pdf" -newer "$LOG_DIR/last_check" 2>/dev/null | while read -r file; do
                send_alert "MEDIUM" "iCloud Sync" "Sensitive file synced to iCloud: $file" "$file"
            done
        fi
        
        # Update last check timestamp
        touch "$LOG_DIR/last_check"
        
        sleep 60
    done &
    
    CLOUD_MONITOR_PID=$!
    echo $CLOUD_MONITOR_PID > "$LOG_DIR/cloud_monitor.pid"
}

# Function to detect data exfiltration patterns
detect_data_exfiltration() {
    log_message "INFO" "Starting data exfiltration detection"
    
    # Monitor for gitleaks patterns
    if command -v gitleaks &> /dev/null; then
        local sensitive_paths_array
        IFS=',' read -ra sensitive_paths_array <<< "$SENSITIVE_PATHS"
        
        for sensitive_path in "${sensitive_paths_array[@]}"; do
            # Trim whitespace
            sensitive_path=$(echo "$sensitive_path" | xargs)
            
            if [ -d "$sensitive_path" ]; then
                gitleaks detect --source "$sensitive_path" --report-format json --report-path "$LOG_DIR/gitleaks_report.json" --no-git || {
                    # If gitleaks finds secrets, send alert
                    if [ -f "$LOG_DIR/gitleaks_report.json" ] && [ -s "$LOG_DIR/gitleaks_report.json" ]; then
                        local secret_count=$(jq length "$LOG_DIR/gitleaks_report.json" 2>/dev/null || echo 0)
                        if [ "$secret_count" -gt 0 ]; then
                            send_alert "HIGH" "Secrets Detected" "Gitleaks detected $secret_count potential secrets in $sensitive_path"
                        fi
                    fi
                }
            fi
        done
    fi
}

# Function to generate file access report
generate_file_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local report_file="$LOG_DIR/file_report_$(date +%Y%m%d_%H%M%S).json"
    
    local report="{
        \"timestamp\": \"$timestamp\",
        \"report_type\": \"file_access_audit\",
        \"user\": \"$USER_NAME\",
        \"device\": \"$(hostname)\",
        \"monitoring_status\": {
            \"file_system_monitoring\": true,
            \"file_change_monitoring\": true,
            \"cloud_sync_monitoring\": true,
            \"data_exfiltration_detection\": true
        },
        \"compliance_status\": {
            \"gdpr\": \"$([ "$ENABLE_GDPR_COMPLIANCE" = "true" ] && echo "enabled" || echo "disabled")\",
            \"sox\": \"$([ "$ENABLE_SOX_COMPLIANCE" = "true" ] && echo "enabled" || echo "disabled")\"
        },
        \"statistics\": {
            \"file_accesses_monitored\": $(grep -c "File access" "$FILE_LOG" || echo 0),
            \"file_modifications_detected\": $(grep -c "File modification" "$FILE_LOG" || echo 0),
            \"sensitive_file_alerts\": $(grep -c "Sensitive File" "$ALERT_LOG" || echo 0),
            \"cloud_sync_events\": $(grep -c "Cloud.*Sync" "$ALERT_LOG" || echo 0),
            \"data_exfiltration_attempts\": $(grep -c "exfiltration" "$ALERT_LOG" || echo 0)
        },
        \"sensitive_paths\": [$(echo "$SENSITIVE_PATHS" | sed 's/,/", "/g' | sed 's/^/"/;s/$/"/')]
    }"
    
    echo "$report" | jq '.' > "$report_file"
    log_message "INFO" "File access audit report generated: $report_file"
}

# Function to cleanup and stop monitoring
cleanup() {
    log_message "INFO" "Stopping file monitoring"
    
    # Kill file system monitor if running
    if [ -f "$LOG_DIR/fs_monitor.pid" ]; then
        local fs_pid=$(cat "$LOG_DIR/fs_monitor.pid")
        sudo kill "$fs_pid" 2>/dev/null || true
        rm -f "$LOG_DIR/fs_monitor.pid"
    fi
    
    # Kill cloud monitor if running
    if [ -f "$LOG_DIR/cloud_monitor.pid" ]; then
        local cloud_pid=$(cat "$LOG_DIR/cloud_monitor.pid")
        kill "$cloud_pid" 2>/dev/null || true
        rm -f "$LOG_DIR/cloud_monitor.pid"
    fi
    
    # Generate final report
    generate_file_report
    
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Main monitoring function
main() {
    log_message "INFO" "Starting Zero Trust File Monitor"
    
    # Check if file monitoring is enabled
    if [ "$ENABLE_FILE_MONITORING" != "true" ]; then
        log_message "INFO" "File monitoring is disabled"
        exit 0
    fi
    
    # Check if we have necessary permissions
    if [ "$EUID" -ne 0 ] && [[ "$*" == *"--start"* ]]; then
        echo -e "${YELLOW}⚠️  Some monitoring features require sudo privileges${NC}"
        echo -e "${YELLOW}⚠️  Run with sudo for full functionality${NC}"
    fi
    
    # Start file system monitoring
    monitor_file_system
    
    # Start file change monitoring
    monitor_file_changes
    
    # Start cloud sync monitoring
    monitor_cloud_sync
    
    # Main monitoring loop
    while true; do
        detect_data_exfiltration
        
        # Generate periodic report
        if [ $(date +%M) -eq 0 ]; then
            generate_file_report
        fi
        
        sleep 300  # Check every 5 minutes
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
        generate_file_report
        ;;
    --test)
        # Test mode - check a specific file
        if [ -n "${2:-}" ]; then
            if is_sensitive_file "$2"; then
                echo "File $2 is classified as sensitive"
                echo "GDPR compliance: $(check_gdpr_compliance "$2")"
                echo "SOX compliance: $(check_sox_compliance "$2")"
            else
                echo "File $2 is not classified as sensitive"
            fi
        else
            echo "Usage: $0 --test <file_path>"
        fi
        ;;
    *)
        echo "Usage: $0 [--start|--stop|--report|--test <file>]"
        echo "  --start           Start file monitoring"
        echo "  --stop            Stop file monitoring"
        echo "  --report          Generate file access audit report"
        echo "  --test <file>     Test if a file is classified as sensitive"
        exit 1
        ;;
esac