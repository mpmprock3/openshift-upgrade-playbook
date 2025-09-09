#!/bin/bash

# Simple AAP Connection Test Script
# ================================
# This script helps debug AAP connectivity issues independently

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Collect AAP details
collect_details() {
    echo ""
    echo -e "${BLUE}AAP Connection Test${NC}"
    echo "=================="
    echo ""
    
    if [[ -z "${AAP_SERVER:-}" ]]; then
        read -p "Enter AAP Server URL: " AAP_SERVER
    fi
    
    if [[ -z "${AAP_USERNAME:-}" ]]; then
        read -p "Enter AAP Username (default: admin): " AAP_USERNAME
        AAP_USERNAME="${AAP_USERNAME:-admin}"
    fi
    
    if [[ -z "${AAP_PASSWORD:-}" ]]; then
        read -s -p "Enter AAP Password: " AAP_PASSWORD
        echo ""
    fi
}

# Test basic connectivity
test_connectivity() {
    log "Testing basic connectivity to ${AAP_SERVER}..."
    
    # Test 1: Basic URL reachability
    if curl -k -s --connect-timeout 10 --max-time 30 "${AAP_SERVER}" >/dev/null 2>&1; then
        success "✓ AAP server is reachable"
    else
        error "✗ Cannot reach AAP server"
        echo "  URL: ${AAP_SERVER}"
        echo "  Check if URL is correct and server is running"
        return 1
    fi
    
    # Test 2: AAP API ping endpoint
    log "Testing AAP API ping endpoint..."
    local ping_response
    ping_response=$(curl -k -s --connect-timeout 10 "${AAP_SERVER}/api/v2/ping/" 2>/dev/null || echo "FAILED")
    
    if echo "$ping_response" | grep -q "ping"; then
        success "✓ AAP API is responding"
    else
        warning "⚠ AAP API ping endpoint not accessible"
        echo "  Response: $ping_response"
        echo "  This might be normal if AAP requires authentication for all endpoints"
    fi
    
    # Test 3: API version endpoint  
    log "Testing API version endpoint..."
    local version_response
    version_response=$(curl -k -s --connect-timeout 10 "${AAP_SERVER}/api/v2/" 2>/dev/null || echo "FAILED")
    
    if echo "$version_response" | grep -q "current_version\|description"; then
        success "✓ AAP API v2 is accessible"
    else
        warning "⚠ AAP API v2 endpoint not accessible without auth"
    fi
}

# Test authentication
test_authentication() {
    log "Testing authentication..."
    
    # Test with curl first
    local auth_test
    auth_test=$(curl -k -s --connect-timeout 10 \
        -u "${AAP_USERNAME}:${AAP_PASSWORD}" \
        "${AAP_SERVER}/api/v2/me/" 2>/dev/null || echo "AUTH_FAILED")
    
    if echo "$auth_test" | grep -q "username\|id"; then
        success "✓ Authentication successful via curl"
        echo "  User info: $(echo "$auth_test" | grep -o '"username":"[^"]*"' || echo "Username not found")"
    else
        error "✗ Authentication failed via curl"
        echo "  Response: $auth_test"
        echo "  Check username and password"
        return 1
    fi
}

# Test AWX CLI
test_awx_cli() {
    log "Testing AWX CLI..."
    
    # Check if AWX CLI is installed
    if ! command -v awx &> /dev/null; then
        error "✗ AWX CLI not installed"
        echo "  Install with: pip install awxkit"
        return 1
    fi
    
    success "✓ AWX CLI is installed"
    awx --version || true
    
    # Clear existing config
    rm -rf ~/.awx/cli.cfg ~/.config/awx 2>/dev/null || true
    
    # Configure AWX CLI
    log "Configuring AWX CLI..."
    awx config set --key "default.host" --value "${AAP_SERVER}"
    awx config set --key "default.username" --value "${AAP_USERNAME}"
    awx config set --key "default.password" --value "${AAP_PASSWORD}"
    awx config set --key "default.verify_ssl" --value "false"
    
    # Test AWX CLI connection
    log "Testing AWX CLI connection..."
    if awx organizations list >/dev/null 2>&1; then
        success "✓ AWX CLI connection successful"
        local org_count
        org_count=$(awx organizations list --format json 2>/dev/null | jq length 2>/dev/null || echo "unknown")
        echo "  Found $org_count organization(s)"
    else
        error "✗ AWX CLI connection failed"
        
        # Show more details
        log "Attempting direct AWX command with explicit parameters..."
        awx --conf.host "${AAP_SERVER}" \
            --conf.username "${AAP_USERNAME}" \
            --conf.password "${AAP_PASSWORD}" \
            --conf.verify_ssl false \
            organizations list 2>&1 || true
        return 1
    fi
}

# Main test function
run_tests() {
    collect_details
    
    echo ""
    log "Starting AAP connection tests..."
    echo ""
    
    # Test 1: Basic connectivity
    if ! test_connectivity; then
        error "Basic connectivity test failed - stopping"
        exit 1
    fi
    
    echo ""
    
    # Test 2: Authentication
    if ! test_authentication; then
        error "Authentication test failed - stopping"  
        exit 1
    fi
    
    echo ""
    
    # Test 3: AWX CLI
    if ! test_awx_cli; then
        error "AWX CLI test failed"
        exit 1
    fi
    
    echo ""
    success "🎉 All AAP connection tests passed!"
    echo ""
    echo "Your AAP instance is ready for deployment."
    echo "You can now run: ./aap-integration/aap-deploy.sh"
}

# Usage info
show_usage() {
    echo "AAP Connection Test Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --server URL     AAP server URL"
    echo "  --username USER  AAP username" 
    echo "  --password PASS  AAP password"
    echo "  --help          Show this help"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 --server https://aap.example.com"
    echo "  AAP_SERVER=https://aap.example.com $0"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --server)
            AAP_SERVER="$2"
            shift 2
            ;;
        --username)
            AAP_USERNAME="$2"
            shift 2
            ;;
        --password)
            AAP_PASSWORD="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Run the tests
run_tests
