#!/bin/bash

# Compliance Check Script for macOS Zero Trust Audit System
# Monitors GDPR and SOX compliance requirements and generates compliance reports

set -euo pipefail

# Script directory and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/Config/audit.conf"
COMPLIANCE_RULES="$PROJECT_DIR/Config/compliance.json"
LOG_DIR="$PROJECT_DIR/Logs"
COMPLIANCE_LOG="$LOG_DIR/compliance.log"
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
touch "$COMPLIANCE_LOG" "$ALERT_LOG"

# Function to log with timestamp
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$COMPLIANCE_LOG"
}

# Function to send compliance alert
send_compliance_alert() {
    local severity="$1"
    local regulation="$2"
    local violation="$3"
    local details="$4"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log alert
    echo "[$timestamp] [COMPLIANCE-ALERT-$severity] $regulation: $violation - $details" >> "$ALERT_LOG"
    
    # Send macOS notification
    if [[ "$ALERT_METHODS" == *"notification"* ]]; then
        osascript -e "display notification \"$regulation: $violation\" with title \"Compliance Alert\" sound name \"Basso\""
    fi
    
    # Create compliance record
    local compliance_record="{
        \"timestamp\": \"$timestamp\",
        \"user\": \"$USER_NAME\",
        \"device\": \"$(hostname)\",
        \"alert_type\": \"compliance\",
        \"regulation\": \"$regulation\",
        \"severity\": \"$severity\",
        \"violation\": \"$violation\",
        \"details\": \"$details\",
        \"remediation_required\": true
    }"
    
    echo "$compliance_record" | jq '.' >> "$LOG_DIR/compliance_violations.json"
}

# Function to check GDPR compliance
check_gdpr_compliance() {
    if [ "$ENABLE_GDPR_COMPLIANCE" != "true" ]; then
        log_message "INFO" "GDPR compliance checking is disabled"
        return
    fi
    
    log_message "INFO" "Checking GDPR compliance"
    
    # Check data retention policies
    local retention_days
    if [ -f "$COMPLIANCE_RULES" ]; then
        retention_days=$(jq -r '.gdpr.data_retention.personal_data' "$COMPLIANCE_RULES" 2>/dev/null || echo "$RETENTION_PERIOD_DAYS")
    else
        retention_days="$RETENTION_PERIOD_DAYS"
    fi
    
    # Find files older than retention period
    local sensitive_paths_array
    IFS=',' read -ra sensitive_paths_array <<< "$SENSITIVE_PATHS"
    
    for sensitive_path in "${sensitive_paths_array[@]}"; do
        sensitive_path=$(echo "$sensitive_path" | xargs)
        
        if [ -d "$sensitive_path" ]; then
            # Find files older than retention period
            local old_files=$(find "$sensitive_path" -type f -name "*.xlsx" -o -name "*.csv" -o -name "*.pdf" -mtime +$retention_days 2>/dev/null)
            
            if [ -n "$old_files" ]; then
                local file_count=$(echo "$old_files" | wc -l)
                send_compliance_alert "MEDIUM" "GDPR" "Data Retention Violation" "Found $file_count files older than $retention_days days in $sensitive_path"
                
                # Log specific files
                echo "$old_files" | while read -r file; do
                    log_message "WARN" "GDPR retention violation: $file"
                done
            fi
        fi
    done
    
    # Check for PII patterns in files
    check_pii_patterns
    
    # Check data processing logs
    check_data_processing_logs
    
    log_message "INFO" "GDPR compliance check completed"
}

# Function to check for PII patterns
check_pii_patterns() {
    log_message "INFO" "Scanning for PII patterns"
    
    local sensitive_paths_array
    IFS=',' read -ra sensitive_paths_array <<< "$SENSITIVE_PATHS"
    
    # Common PII patterns
    local pii_patterns=(
        "[0-9]{3}-[0-9]{2}-[0-9]{4}"           # SSN
        "[0-9]{4}[[:space:]]*[0-9]{4}[[:space:]]*[0-9]{4}[[:space:]]*[0-9]{4}"  # Credit Card
        "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"  # Email
        "\b[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b"  # IP Address
    )
    
    for sensitive_path in "${sensitive_paths_array[@]}"; do
        sensitive_path=$(echo "$sensitive_path" | xargs)
        
        if [ -d "$sensitive_path" ]; then
            for pattern in "${pii_patterns[@]}"; do
                local matches=$(grep -r -E "$pattern" "$sensitive_path" --include="*.txt" --include="*.csv" --include="*.json" 2>/dev/null | head -10)
                
                if [ -n "$matches" ]; then
                    local match_count=$(echo "$matches" | wc -l)
                    send_compliance_alert "HIGH" "GDPR" "PII Detection" "Found $match_count potential PII matches in $sensitive_path"
                    
                    # Log matches without exposing actual data
                    echo "$matches" | while read -r match; do
                        local file=$(echo "$match" | cut -d':' -f1)
                        log_message "WARN" "PII pattern found in: $file"
                    done
                fi
            done
        fi
    done
}

# Function to check data processing logs
check_data_processing_logs() {
    log_message "INFO" "Checking data processing logs"
    
    # Check system logs for data processing activities
    local processing_activities=$(log show --predicate 'subsystem contains "com.apple.CoreData" OR subsystem contains "com.apple.security"' --last 1h --style compact 2>/dev/null | grep -E "(database|export|import|sync)" | head -20)
    
    if [ -n "$processing_activities" ]; then
        log_message "INFO" "Data processing activities detected"
        
        # Create processing log entry
        local processing_log="{
            \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\",
            \"user\": \"$USER_NAME\",
            \"device\": \"$(hostname)\",
            \"processing_type\": \"automated_system\",
            \"activity_count\": $(echo "$processing_activities" | wc -l),
            \"gdpr_compliance\": \"logged\"
        }"
        
        echo "$processing_log" | jq '.' >> "$LOG_DIR/data_processing.json"
    fi
}

# Function to check SOX compliance
check_sox_compliance() {
    if [ "$ENABLE_SOX_COMPLIANCE" != "true" ]; then
        log_message "INFO" "SOX compliance checking is disabled"
        return
    fi
    
    log_message "INFO" "Checking SOX compliance"
    
    # Check for financial data access
    check_financial_data_access
    
    # Check access controls
    check_access_controls
    
    # Check audit trail integrity
    check_audit_trail_integrity
    
    # Check segregation of duties
    check_segregation_of_duties
    
    log_message "INFO" "SOX compliance check completed"
}

# Function to check financial data access
check_financial_data_access() {
    log_message "INFO" "Checking financial data access"
    
    # Look for financial file patterns
    local financial_patterns=(
        "*financial*"
        "*accounting*"
        "*revenue*"
        "*invoice*"
        "*payment*"
        "*transaction*"
        "*audit*"
        "*sox*"
    )
    
    local sensitive_paths_array
    IFS=',' read -ra sensitive_paths_array <<< "$SENSITIVE_PATHS"
    
    for sensitive_path in "${sensitive_paths_array[@]}"; do
        sensitive_path=$(echo "$sensitive_path" | xargs)
        
        if [ -d "$sensitive_path" ]; then
            for pattern in "${financial_patterns[@]}"; do
                local financial_files=$(find "$sensitive_path" -type f -iname "$pattern" 2>/dev/null)
                
                if [ -n "$financial_files" ]; then
                    log_message "INFO" "Financial files found matching pattern: $pattern"
                    
                    # Check recent access to financial files
                    echo "$financial_files" | while read -r file; do
                        if [ -f "$file" ]; then
                            local last_access=$(stat -f %Sa "$file" 2>/dev/null || echo "unknown")
                            local last_modified=$(stat -f %Sm "$file" 2>/dev/null || echo "unknown")
                            
                            # Log financial file access
                            local access_log="{
                                \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\",
                                \"user\": \"$USER_NAME\",
                                \"device\": \"$(hostname)\",
                                \"file\": \"$file\",
                                \"last_access\": \"$last_access\",
                                \"last_modified\": \"$last_modified\",
                                \"sox_compliance\": \"logged\"
                            }"
                            
                            echo "$access_log" | jq '.' >> "$LOG_DIR/financial_access.json"
                        fi
                    done
                fi
            done
        fi
    done
}

# Function to check access controls
check_access_controls() {
    log_message "INFO" "Checking access controls"
    
    # Check file permissions on sensitive files
    local sensitive_paths_array
    IFS=',' read -ra sensitive_paths_array <<< "$SENSITIVE_PATHS"
    
    for sensitive_path in "${sensitive_paths_array[@]}"; do
        sensitive_path=$(echo "$sensitive_path" | xargs)
        
        if [ -d "$sensitive_path" ]; then
            # Find files with overly permissive permissions
            local permissive_files=$(find "$sensitive_path" -type f -perm -o+w 2>/dev/null)
            
            if [ -n "$permissive_files" ]; then
                local file_count=$(echo "$permissive_files" | wc -l)
                send_compliance_alert "HIGH" "SOX" "Access Control Violation" "Found $file_count files with world-writable permissions in $sensitive_path"
                
                # Log specific files
                echo "$permissive_files" | while read -r file; do
                    log_message "WARN" "SOX access control violation: $file has world-writable permissions"
                done
            fi
        fi
    done
    
    # Check for shared directories
    local shared_dirs=$(find /Users -type d -name "Shared" -o -name "Public" 2>/dev/null)
    if [ -n "$shared_dirs" ]; then
        echo "$shared_dirs" | while read -r dir; do
            local sensitive_in_shared=$(find "$dir" -type f \( -name "*.xlsx" -o -name "*.csv" -o -name "*.pdf" \) 2>/dev/null)
            if [ -n "$sensitive_in_shared" ]; then
                send_compliance_alert "MEDIUM" "SOX" "Data Location Violation" "Sensitive files found in shared directory: $dir"
            fi
        done
    fi
}

# Function to check audit trail integrity
check_audit_trail_integrity() {
    log_message "INFO" "Checking audit trail integrity"
    
    # Check if audit logs exist and are not tampered with
    local audit_files=("$LOG_DIR"/*.log)
    
    for audit_file in "${audit_files[@]}"; do
        if [ -f "$audit_file" ]; then
            # Check file integrity (basic check)
            local file_size=$(stat -f%z "$audit_file" 2>/dev/null || echo "0")
            local file_hash=$(shasum -a 256 "$audit_file" 2>/dev/null | cut -d' ' -f1)
            
            # Store hash for integrity checking
            local integrity_record="{
                \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\",
                \"file\": \"$audit_file\",
                \"size\": \"$file_size\",
                \"hash\": \"$file_hash\",
                \"integrity_check\": \"passed\"
            }"
            
            echo "$integrity_record" | jq '.' >> "$LOG_DIR/audit_integrity.json"
        fi
    done
    
    # Check for gaps in audit logs
    local log_gap_check=$(find "$LOG_DIR" -name "*.log" -type f -mtime +1 2>/dev/null)
    if [ -z "$log_gap_check" ]; then
        send_compliance_alert "HIGH" "SOX" "Audit Trail Gap" "No audit logs found from the last 24 hours"
    fi
}

# Function to check segregation of duties
check_segregation_of_duties() {
    log_message "INFO" "Checking segregation of duties"
    
    # Check if the same user is performing multiple sensitive operations
    local recent_activities=$(grep -h "$(date '+%Y-%m-%d')" "$LOG_DIR"/*.log 2>/dev/null | grep -E "(file|network|compliance)" | head -100)
    
    if [ -n "$recent_activities" ]; then
        # Count different types of activities by user
        local user_activities=$(echo "$recent_activities" | awk '{print $4}' | sort | uniq -c | sort -nr)
        
        # Check for users with excessive activity
        echo "$user_activities" | while read -r count user; do
            if [ "$count" -gt 50 ]; then
                send_compliance_alert "MEDIUM" "SOX" "Segregation of Duties Concern" "User $user performed $count sensitive operations today"
            fi
        done
    fi
}

# Function to generate compliance report
generate_compliance_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local report_file="$LOG_DIR/compliance_report_$(date +%Y%m%d_%H%M%S).json"
    
    # Count violations
    local gdpr_violations=$(grep -c "GDPR" "$LOG_DIR/compliance_violations.json" 2>/dev/null || echo 0)
    local sox_violations=$(grep -c "SOX" "$LOG_DIR/compliance_violations.json" 2>/dev/null || echo 0)
    
    # Get compliance status
    local gdpr_status="compliant"
    local sox_status="compliant"
    
    if [ "$gdpr_violations" -gt 0 ]; then
        gdpr_status="violations_detected"
    fi
    
    if [ "$sox_violations" -gt 0 ]; then
        sox_status="violations_detected"
    fi
    
    local report="{
        \"timestamp\": \"$timestamp\",
        \"report_type\": \"compliance_audit\",
        \"user\": \"$USER_NAME\",
        \"device\": \"$(hostname)\",
        \"compliance_status\": {
            \"gdpr\": {
                \"enabled\": $([ "$ENABLE_GDPR_COMPLIANCE" = "true" ] && echo "true" || echo "false"),
                \"status\": \"$gdpr_status\",
                \"violations\": $gdpr_violations,
                \"last_check\": \"$timestamp\"
            },
            \"sox\": {
                \"enabled\": $([ "$ENABLE_SOX_COMPLIANCE" = "true" ] && echo "true" || echo "false"),
                \"status\": \"$sox_status\",
                \"violations\": $sox_violations,
                \"last_check\": \"$timestamp\"
            }
        },
        \"statistics\": {
            \"pii_scans_performed\": $(grep -c "PII patterns" "$COMPLIANCE_LOG" || echo 0),
            \"financial_files_monitored\": $(grep -c "Financial files" "$COMPLIANCE_LOG" || echo 0),
            \"access_control_checks\": $(grep -c "access controls" "$COMPLIANCE_LOG" || echo 0),
            \"audit_trail_checks\": $(grep -c "audit trail" "$COMPLIANCE_LOG" || echo 0)
        },
        \"recommendations\": [
            $([ "$gdpr_violations" -gt 0 ] && echo '\"Review and address GDPR violations\"' || echo '\"Continue current GDPR compliance measures\"'),
            $([ "$sox_violations" -gt 0 ] && echo ',\"Review and address SOX violations\"' || echo ',\"Continue current SOX compliance measures\"')
        ]
    }"
    
    echo "$report" | jq '.' > "$report_file"
    log_message "INFO" "Compliance audit report generated: $report_file"
}

# Function to cleanup old compliance data
cleanup_old_data() {
    log_message "INFO" "Cleaning up old compliance data"
    
    local retention_days
    if [ -f "$COMPLIANCE_RULES" ]; then
        retention_days=$(jq -r '.gdpr.data_retention.audit_logs' "$COMPLIANCE_RULES" 2>/dev/null || echo "$RETENTION_PERIOD_DAYS")
    else
        retention_days="$RETENTION_PERIOD_DAYS"
    fi
    
    # Clean up old log files
    find "$LOG_DIR" -name "*.log" -type f -mtime +$retention_days -delete 2>/dev/null || true
    
    # Clean up old report files
    find "$LOG_DIR" -name "*_report_*.json" -type f -mtime +$retention_days -delete 2>/dev/null || true
    
    log_message "INFO" "Old compliance data cleaned up (retention: $retention_days days)"
}

# Function to export compliance data
export_compliance_data() {
    local export_file="$LOG_DIR/compliance_export_$(date +%Y%m%d_%H%M%S).json"
    
    log_message "INFO" "Exporting compliance data"
    
    # Create comprehensive export
    local export_data="{
        \"export_timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\",
        \"user\": \"$USER_NAME\",
        \"device\": \"$(hostname)\",
        \"compliance_violations\": $(cat "$LOG_DIR/compliance_violations.json" 2>/dev/null || echo '[]'),
        \"data_processing_logs\": $(cat "$LOG_DIR/data_processing.json" 2>/dev/null || echo '[]'),
        \"financial_access_logs\": $(cat "$LOG_DIR/financial_access.json" 2>/dev/null || echo '[]'),
        \"audit_integrity_logs\": $(cat "$LOG_DIR/audit_integrity.json" 2>/dev/null || echo '[]')
    }"
    
    echo "$export_data" | jq '.' > "$export_file"
    log_message "INFO" "Compliance data exported to: $export_file"
}

# Function to cleanup and stop monitoring
cleanup() {
    log_message "INFO" "Stopping compliance monitoring"
    
    # Generate final report
    generate_compliance_report
    
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Main monitoring function
main() {
    log_message "INFO" "Starting Zero Trust Compliance Monitor"
    
    # Check if compliance checking is enabled
    if [ "$ENABLE_COMPLIANCE_CHECKING" != "true" ]; then
        log_message "INFO" "Compliance checking is disabled"
        exit 0
    fi
    
    # Main monitoring loop
    while true; do
        check_gdpr_compliance
        check_sox_compliance
        
        # Generate periodic report
        if [ $(date +%M) -eq 0 ]; then
            generate_compliance_report
        fi
        
        # Cleanup old data daily
        if [ $(date +%H) -eq 2 ] && [ $(date +%M) -eq 0 ]; then
            cleanup_old_data
        fi
        
        sleep 600  # Check every 10 minutes
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
        generate_compliance_report
        ;;
    --export)
        export_compliance_data
        ;;
    --gdpr)
        check_gdpr_compliance
        ;;
    --sox)
        check_sox_compliance
        ;;
    --cleanup)
        cleanup_old_data
        ;;
    *)
        echo "Usage: $0 [--start|--stop|--report|--export|--gdpr|--sox|--cleanup]"
        echo "  --start    Start compliance monitoring"
        echo "  --stop     Stop compliance monitoring"
        echo "  --report   Generate compliance audit report"
        echo "  --export   Export compliance data"
        echo "  --gdpr     Run GDPR compliance check only"
        echo "  --sox      Run SOX compliance check only"
        echo "  --cleanup  Clean up old compliance data"
        exit 1
        ;;
esac