#!/bin/bash

# OpenShift Upgrade Check Runner Script
# ====================================
# 
# This script provides convenient wrapper functions for running
# the OpenShift upgrade check playbook with different configurations.
#
# Usage:
#   ./run-checks.sh pre                    # Run pre-upgrade checks
#   ./run-checks.sh post                   # Run post-upgrade checks  
#   ./run-checks.sh both                   # Run both pre and post checks
#   ./run-checks.sh help                   # Show help

set -euo pipefail

# Configuration
PLAYBOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INVENTORY="${PLAYBOOK_DIR}/inventory/hosts.yml"
PLAYBOOK="${PLAYBOOK_DIR}/openshift-upgrade-hooks.yml"
VAULT_PASSWORD_FILE="${PLAYBOOK_DIR}/.vault_pass"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if ansible is installed
    if ! command -v ansible-playbook &> /dev/null; then
        error "ansible-playbook is not installed. Please install Ansible."
        exit 1
    fi
    
    # Check if playbook exists
    if [[ ! -f "$PLAYBOOK" ]]; then
        error "Playbook not found: $PLAYBOOK"
        exit 1
    fi
    
    # Check if inventory exists
    if [[ ! -f "$INVENTORY" ]]; then
        error "Inventory not found: $INVENTORY"
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Show help
show_help() {
    cat << EOF
OpenShift Upgrade Check Runner

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    pre         Run pre-upgrade checks only
    post        Run post-upgrade checks only
    both        Run both pre and post-upgrade checks (default)
    help        Show this help message

Options:
    --vault     Use vault password file for encrypted variables
    --verbose   Enable verbose output (-vv)
    --debug     Enable debug output (-vvv)
    --check     Run in check mode (dry-run)
    --cluster   Target specific cluster from inventory

Examples:
    $0 pre --verbose
    $0 post --vault
    $0 both --cluster production_east
    $0 pre --check --verbose

Environment Variables:
    OPENSHIFT_TOKEN    - Override cluster token
    CLUSTER_URL        - Override cluster API URL
    ANSIBLE_VAULT_PASSWORD - Vault password (instead of file)

Files:
    .vault_pass        - Vault password file (if using vault)
    logs/              - Generated log files
    reports/           - Generated HTML reports

EOF
}

# Run playbook with specified mode
run_checks() {
    local mode="$1"
    shift
    local extra_args=()
    local cluster=""
    local use_vault=false
    local verbose=""
    local check_mode=""
    
    # Parse additional arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --vault)
                use_vault=true
                shift
                ;;
            --verbose)
                verbose="-vv"
                shift
                ;;
            --debug)
                verbose="-vvv"
                shift
                ;;
            --check)
                check_mode="--check"
                shift
                ;;
            --cluster)
                cluster="$2"
                shift 2
                ;;
            *)
                extra_args+=("$1")
                shift
                ;;
        esac
    done
    
    # Build ansible command
    local ansible_cmd=(
        "ansible-playbook"
        "-i" "$INVENTORY"
        "$PLAYBOOK"
        "-e" "mode=${mode}"
    )
    
    # Add vault password if requested
    if [[ "$use_vault" == true ]]; then
        if [[ -f "$VAULT_PASSWORD_FILE" ]]; then
            ansible_cmd+=("--vault-password-file" "$VAULT_PASSWORD_FILE")
        elif [[ -n "${ANSIBLE_VAULT_PASSWORD:-}" ]]; then
            ansible_cmd+=("--vault-password-file" <(echo "$ANSIBLE_VAULT_PASSWORD"))
        else
            ansible_cmd+=("--ask-vault-pass")
        fi
    fi
    
    # Add cluster targeting
    if [[ -n "$cluster" ]]; then
        ansible_cmd+=("-l" "$cluster")
    fi
    
    # Add verbosity
    if [[ -n "$verbose" ]]; then
        ansible_cmd+=("$verbose")
    fi
    
    # Add check mode
    if [[ -n "$check_mode" ]]; then
        ansible_cmd+=("$check_mode")
    fi
    
    # Add extra arguments
    ansible_cmd+=("${extra_args[@]}")
    
    # Override with environment variables if set
    local env_vars=()
    if [[ -n "${OPENSHIFT_TOKEN:-}" ]]; then
        env_vars+=("-e" "cluster_token=${OPENSHIFT_TOKEN}")
    fi
    if [[ -n "${CLUSTER_URL:-}" ]]; then
        env_vars+=("-e" "cluster_api_url=${CLUSTER_URL}")
    fi
    
    log "Running ${mode} upgrade checks..."
    log "Command: ${ansible_cmd[*]} ${env_vars[*]}"
    
    # Execute the playbook
    if "${ansible_cmd[@]}" "${env_vars[@]}"; then
        success "${mode} upgrade checks completed successfully"
        
        # Show where to find results
        echo
        log "Results available in:"
        echo "  - Logs: ${PLAYBOOK_DIR}/logs/"
        echo "  - Reports: ${PLAYBOOK_DIR}/reports/"
        
        # Find and display latest report
        local latest_report
        latest_report=$(find "${PLAYBOOK_DIR}/reports/" -name "*.html" -type f -exec ls -t {} + 2>/dev/null | head -n1)
        if [[ -n "$latest_report" ]]; then
            log "Latest report: $latest_report"
            if command -v open &> /dev/null; then
                echo "  Run 'open \"$latest_report\"' to view the report"
            fi
        fi
    else
        error "${mode} upgrade checks failed"
        exit 1
    fi
}

# Main script logic
main() {
    local mode="both"
    
    if [[ $# -eq 0 ]]; then
        warning "No command specified, running both pre and post checks"
    else
        case "$1" in
            pre|post|both)
                mode="$1"
                shift
                ;;
            help|--help|-h)
                show_help
                exit 0
                ;;
            *)
                error "Unknown command: $1"
                show_help
                exit 1
                ;;
        esac
    fi
    
    check_prerequisites
    run_checks "$mode" "$@"
}

# Trap errors and cleanup
cleanup() {
    if [[ $? -ne 0 ]]; then
        error "Script failed. Check the output above for details."
    fi
}
trap cleanup EXIT

# Run main function
main "$@"
