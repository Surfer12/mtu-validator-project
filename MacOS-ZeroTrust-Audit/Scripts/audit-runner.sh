#!/bin/bash

# Main Audit Runner Script for macOS Zero Trust Audit System
# Orchestrates all monitoring components and manages the overall audit system

set -euo pipefail

# Script directory and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/Config/audit.conf"
LOG_DIR="$PROJECT_DIR/Logs"
MAIN_LOG="$LOG_DIR/audit_runner.log"
PID_FILE="$LOG_DIR/audit_runner.pid"

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

# Initialize log directory
mkdir -p "$LOG_DIR"

# Function to log with timestamp
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$MAIN_LOG"
}

# Function to check if process is running
is_process_running() {
    local pid_file="$1"
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            rm -f "$pid_file"
            return 1
        fi
    fi
    return 1
}

# Function to start network monitoring
start_network_monitoring() {
    if [ "$ENABLE_NETWORK_MONITORING" = "true" ]; then
        log_message "INFO" "Starting network monitoring"
        "$SCRIPT_DIR/network-monitor.sh" --start &
        echo $! > "$LOG_DIR/network_monitor.pid"
        log_message "INFO" "Network monitoring started with PID $(cat "$LOG_DIR/network_monitor.pid")"
    else
        log_message "INFO" "Network monitoring is disabled"
    fi
}

# Function to start file monitoring
start_file_monitoring() {
    if [ "$ENABLE_FILE_MONITORING" = "true" ]; then
        log_message "INFO" "Starting file monitoring"
        "$SCRIPT_DIR/file-watcher.sh" --start &
        echo $! > "$LOG_DIR/file_monitor.pid"
        log_message "INFO" "File monitoring started with PID $(cat "$LOG_DIR/file_monitor.pid")"
    else
        log_message "INFO" "File monitoring is disabled"
    fi
}

# Function to start compliance checking
start_compliance_monitoring() {
    if [ "$ENABLE_COMPLIANCE_CHECKING" = "true" ]; then
        log_message "INFO" "Starting compliance monitoring"
        "$SCRIPT_DIR/compliance-check.sh" --start &
        echo $! > "$LOG_DIR/compliance_monitor.pid"
        log_message "INFO" "Compliance monitoring started with PID $(cat "$LOG_DIR/compliance_monitor.pid")"
    else
        log_message "INFO" "Compliance monitoring is disabled"
    fi
}

# Function to start process monitoring
start_process_monitoring() {
    if [ "$ENABLE_PROCESS_MONITORING" = "true" ]; then
        log_message "INFO" "Starting process monitoring"
        "$SCRIPT_DIR/process-monitor.sh" --start &
        echo $! > "$LOG_DIR/process_monitor.pid"
        log_message "INFO" "Process monitoring started with PID $(cat "$LOG_DIR/process_monitor.pid")"
    else
        log_message "INFO" "Process monitoring is disabled"
    fi
}

# Function to check system health
check_system_health() {
    log_message "INFO" "Checking system health"
    
    local health_status="healthy"
    local issues=()
    
    # Check disk space
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        health_status="warning"
        issues+=("High disk usage: ${disk_usage}%")
    fi
    
    # Check memory usage
    local memory_usage=$(vm_stat | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
    local total_memory=$(sysctl -n hw.memsize)
    local memory_percent=$((memory_usage * 4096 * 100 / total_memory))
    if [ "$memory_percent" -gt 85 ]; then
        health_status="warning"
        issues+=("High memory usage: ${memory_percent}%")
    fi
    
    # Check CPU load
    local cpu_load=$(uptime | awk '{print $10}' | sed 's/,//')
    if (( $(echo "$cpu_load > 3.0" | bc -l) )); then
        health_status="warning"
        issues+=("High CPU load: $cpu_load")
    fi
    
    # Check if monitoring processes are running
    if ! is_process_running "$LOG_DIR/network_monitor.pid" && [ "$ENABLE_NETWORK_MONITORING" = "true" ]; then
        health_status="critical"
        issues+=("Network monitoring not running")
    fi
    
    if ! is_process_running "$LOG_DIR/file_monitor.pid" && [ "$ENABLE_FILE_MONITORING" = "true" ]; then
        health_status="critical"
        issues+=("File monitoring not running")
    fi
    
    # Log health status
    if [ "$health_status" = "healthy" ]; then
        log_message "INFO" "System health: OK"
    else
        log_message "WARN" "System health: $health_status - Issues: ${issues[*]}"
    fi
    
    # Create health report
    local health_report="{
        \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\",
        \"status\": \"$health_status\",
        \"issues\": [$(printf '"%s",' "${issues[@]}" | sed 's/,$//')]
    }"
    
    echo "$health_report" | jq '.' > "$LOG_DIR/health_status.json"
}

# Function to generate consolidated audit report
generate_audit_report() {
    log_message "INFO" "Generating consolidated audit report"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local report_file="$LOG_DIR/consolidated_audit_report_$(date +%Y%m%d_%H%M%S).json"
    
    # Get individual reports
    local network_report="{}"
    local file_report="{}"
    local compliance_report="{}"
    local process_report="{}"
    
    # Generate individual reports
    if [ "$ENABLE_NETWORK_MONITORING" = "true" ]; then
        "$SCRIPT_DIR/network-monitor.sh" --report &>/dev/null || true
        local latest_network_report=$(ls -t "$LOG_DIR"/network_report_*.json 2>/dev/null | head -1)
        if [ -n "$latest_network_report" ]; then
            network_report=$(cat "$latest_network_report")
        fi
    fi
    
    if [ "$ENABLE_FILE_MONITORING" = "true" ]; then
        "$SCRIPT_DIR/file-watcher.sh" --report &>/dev/null || true
        local latest_file_report=$(ls -t "$LOG_DIR"/file_report_*.json 2>/dev/null | head -1)
        if [ -n "$latest_file_report" ]; then
            file_report=$(cat "$latest_file_report")
        fi
    fi
    
    if [ "$ENABLE_COMPLIANCE_CHECKING" = "true" ]; then
        "$SCRIPT_DIR/compliance-check.sh" --report &>/dev/null || true
        local latest_compliance_report=$(ls -t "$LOG_DIR"/compliance_report_*.json 2>/dev/null | head -1)
        if [ -n "$latest_compliance_report" ]; then
            compliance_report=$(cat "$latest_compliance_report")
        fi
    fi
    
    # Create consolidated report
    local consolidated_report="{
        \"timestamp\": \"$timestamp\",
        \"report_type\": \"consolidated_audit\",
        \"user\": \"$USER_NAME\",
        \"device\": \"$(hostname)\",
        \"system_info\": {
            \"os_version\": \"$(sw_vers -productVersion)\",
            \"uptime\": \"$(uptime | awk '{print $3, $4}' | sed 's/,//')\",
            \"disk_usage\": \"$(df -h / | awk 'NR==2 {print $5}')\",
            \"memory_usage\": \"$(vm_stat | grep 'Pages active' | awk '{print $3}' | sed 's/\.//')\"
        },
        \"monitoring_status\": {
            \"network_monitoring\": $([ "$ENABLE_NETWORK_MONITORING" = "true" ] && echo "true" || echo "false"),
            \"file_monitoring\": $([ "$ENABLE_FILE_MONITORING" = "true" ] && echo "true" || echo "false"),
            \"compliance_monitoring\": $([ "$ENABLE_COMPLIANCE_CHECKING" = "true" ] && echo "true" || echo "false"),
            \"process_monitoring\": $([ "$ENABLE_PROCESS_MONITORING" = "true" ] && echo "true" || echo "false")
        },
        \"health_status\": $(cat "$LOG_DIR/health_status.json" 2>/dev/null || echo '{}'),
        \"network_report\": $network_report,
        \"file_report\": $file_report,
        \"compliance_report\": $compliance_report,
        \"process_report\": $process_report,
        \"summary\": {
            \"total_alerts\": $(grep -c \"ALERT\" "$LOG_DIR"/*.log 2>/dev/null || echo 0),
            \"high_severity_alerts\": $(grep -c \"ALERT-HIGH\" "$LOG_DIR"/*.log 2>/dev/null || echo 0),
            \"medium_severity_alerts\": $(grep -c \"ALERT-MEDIUM\" "$LOG_DIR"/*.log 2>/dev/null || echo 0),
            \"low_severity_alerts\": $(grep -c \"ALERT-LOW\" "$LOG_DIR"/*.log 2>/dev/null || echo 0)
        }
    }"
    
    echo "$consolidated_report" | jq '.' > "$report_file"
    log_message "INFO" "Consolidated audit report generated: $report_file"
    
    # Send to Swift app if running
    if pgrep -f "ZeroTrustAudit" > /dev/null; then
        log_message "INFO" "Sending report to Swift application"
        # Use osascript to send data to Swift app
        osascript -e "tell application \"ZeroTrustAudit\" to set audit_report to \"$report_file\""
    fi
}

# Function to cleanup and stop all monitoring
cleanup() {
    log_message "INFO" "Stopping all monitoring processes"
    
    # Stop network monitoring
    if is_process_running "$LOG_DIR/network_monitor.pid"; then
        local pid=$(cat "$LOG_DIR/network_monitor.pid")
        kill "$pid" 2>/dev/null || true
        rm -f "$LOG_DIR/network_monitor.pid"
        log_message "INFO" "Network monitoring stopped"
    fi
    
    # Stop file monitoring
    if is_process_running "$LOG_DIR/file_monitor.pid"; then
        local pid=$(cat "$LOG_DIR/file_monitor.pid")
        kill "$pid" 2>/dev/null || true
        rm -f "$LOG_DIR/file_monitor.pid"
        log_message "INFO" "File monitoring stopped"
    fi
    
    # Stop compliance monitoring
    if is_process_running "$LOG_DIR/compliance_monitor.pid"; then
        local pid=$(cat "$LOG_DIR/compliance_monitor.pid")
        kill "$pid" 2>/dev/null || true
        rm -f "$LOG_DIR/compliance_monitor.pid"
        log_message "INFO" "Compliance monitoring stopped"
    fi
    
    # Stop process monitoring
    if is_process_running "$LOG_DIR/process_monitor.pid"; then
        local pid=$(cat "$LOG_DIR/process_monitor.pid")
        kill "$pid" 2>/dev/null || true
        rm -f "$LOG_DIR/process_monitor.pid"
        log_message "INFO" "Process monitoring stopped"
    fi
    
    # Generate final report
    generate_audit_report
    
    # Remove main PID file
    rm -f "$PID_FILE"
    
    log_message "INFO" "Zero Trust Audit System stopped"
    exit 0
}

# Function to restart monitoring components
restart_monitoring() {
    log_message "INFO" "Restarting monitoring components"
    
    # Stop all monitoring
    cleanup
    
    # Wait a moment
    sleep 2
    
    # Start all monitoring
    start_all_monitoring
}

# Function to start all monitoring components
start_all_monitoring() {
    log_message "INFO" "Starting Zero Trust Audit System"
    
    # Check if already running
    if is_process_running "$PID_FILE"; then
        log_message "WARN" "Audit system is already running"
        return 1
    fi
    
    # Store main PID
    echo $$ > "$PID_FILE"
    
    # Start individual monitoring components
    start_network_monitoring
    start_file_monitoring
    start_compliance_monitoring
    start_process_monitoring
    
    # Send startup notification
    if [[ "$ALERT_METHODS" == *"notification"* ]]; then
        osascript -e "display notification \"Zero Trust Audit System started\" with title \"Security Monitor\" sound name \"Glass\""
    fi
    
    log_message "INFO" "All monitoring components started successfully"
}

# Function to show system status
show_status() {
    echo -e "${BLUE}🔐 Zero Trust Audit System Status${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
    
    # Check main process
    if is_process_running "$PID_FILE"; then
        echo -e "${GREEN}✅ Main audit system: Running${NC}"
    else
        echo -e "${RED}❌ Main audit system: Not running${NC}"
    fi
    
    # Check individual components
    if is_process_running "$LOG_DIR/network_monitor.pid"; then
        echo -e "${GREEN}✅ Network monitoring: Running${NC}"
    else
        echo -e "${RED}❌ Network monitoring: Not running${NC}"
    fi
    
    if is_process_running "$LOG_DIR/file_monitor.pid"; then
        echo -e "${GREEN}✅ File monitoring: Running${NC}"
    else
        echo -e "${RED}❌ File monitoring: Not running${NC}"
    fi
    
    if is_process_running "$LOG_DIR/compliance_monitor.pid"; then
        echo -e "${GREEN}✅ Compliance monitoring: Running${NC}"
    else
        echo -e "${RED}❌ Compliance monitoring: Not running${NC}"
    fi
    
    if is_process_running "$LOG_DIR/process_monitor.pid"; then
        echo -e "${GREEN}✅ Process monitoring: Running${NC}"
    else
        echo -e "${RED}❌ Process monitoring: Not running${NC}"
    fi
    
    echo
    echo -e "${BLUE}Recent Activity:${NC}"
    tail -5 "$MAIN_LOG" 2>/dev/null || echo "No recent activity"
    
    echo
    echo -e "${BLUE}Alert Summary:${NC}"
    local total_alerts=$(grep -c "ALERT" "$LOG_DIR"/*.log 2>/dev/null || echo 0)
    local high_alerts=$(grep -c "ALERT-HIGH" "$LOG_DIR"/*.log 2>/dev/null || echo 0)
    local medium_alerts=$(grep -c "ALERT-MEDIUM" "$LOG_DIR"/*.log 2>/dev/null || echo 0)
    local low_alerts=$(grep -c "ALERT-LOW" "$LOG_DIR"/*.log 2>/dev/null || echo 0)
    
    echo "Total alerts: $total_alerts"
    echo "High severity: $high_alerts"
    echo "Medium severity: $medium_alerts"
    echo "Low severity: $low_alerts"
}

# Function to run in background mode
run_background() {
    log_message "INFO" "Running in background mode"
    
    # Start all monitoring
    start_all_monitoring
    
    # Main monitoring loop
    while true; do
        # Check system health every 10 minutes
        if [ $(($(date +%s) % 600)) -eq 0 ]; then
            check_system_health
        fi
        
        # Generate report every hour
        if [ $(($(date +%s) % 3600)) -eq 0 ]; then
            generate_audit_report
        fi
        
        # Check if monitoring processes are still running
        if [ "$ENABLE_NETWORK_MONITORING" = "true" ] && ! is_process_running "$LOG_DIR/network_monitor.pid"; then
            log_message "WARN" "Network monitoring stopped unexpectedly, restarting"
            start_network_monitoring
        fi
        
        if [ "$ENABLE_FILE_MONITORING" = "true" ] && ! is_process_running "$LOG_DIR/file_monitor.pid"; then
            log_message "WARN" "File monitoring stopped unexpectedly, restarting"
            start_file_monitoring
        fi
        
        if [ "$ENABLE_COMPLIANCE_CHECKING" = "true" ] && ! is_process_running "$LOG_DIR/compliance_monitor.pid"; then
            log_message "WARN" "Compliance monitoring stopped unexpectedly, restarting"
            start_compliance_monitoring
        fi
        
        if [ "$ENABLE_PROCESS_MONITORING" = "true" ] && ! is_process_running "$LOG_DIR/process_monitor.pid"; then
            log_message "WARN" "Process monitoring stopped unexpectedly, restarting"
            start_process_monitoring
        fi
        
        sleep 60
    done
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Handle command line arguments
case "${1:-}" in
    --start)
        start_all_monitoring
        ;;
    --stop)
        cleanup
        ;;
    --restart)
        restart_monitoring
        ;;
    --status)
        show_status
        ;;
    --report)
        generate_audit_report
        ;;
    --background)
        run_background
        ;;
    --health)
        check_system_health
        ;;
    *)
        echo "Usage: $0 [--start|--stop|--restart|--status|--report|--background|--health]"
        echo "  --start      Start all monitoring components"
        echo "  --stop       Stop all monitoring components"
        echo "  --restart    Restart all monitoring components"
        echo "  --status     Show system status"
        echo "  --report     Generate consolidated audit report"
        echo "  --background Run in background mode (continuous monitoring)"
        echo "  --health     Check system health"
        echo
        echo "Examples:"
        echo "  $0 --start          # Start monitoring"
        echo "  $0 --status         # Check status"
        echo "  $0 --background     # Run continuously"
        echo "  $0 --stop           # Stop all monitoring"
        exit 1
        ;;
esac