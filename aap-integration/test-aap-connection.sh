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
    
    # Clean up URL (remove trailing slash)
    local clean_url="${AAP_SERVER%/}"
    
    # Test 1: Basic URL reachability
    if curl -k -s --connect-timeout 10 --max-time 30 "${clean_url}" >/dev/null 2>&1; then
        success "✓ AAP server is reachable"
    else
        error "✗ Cannot reach AAP server"
        echo "  URL: ${clean_url}"
        echo "  Check if URL is correct and server is running"
        return 1
    fi
    
    # Test 2: AAP API ping endpoint
    log "Testing AAP API ping endpoint..."
    local ping_response
    ping_response=$(curl -k -s --connect-timeout 10 "${clean_url}/api/v2/ping/" 2>/dev/null || echo "FAILED")
    
    if echo "$ping_response" | grep -q -E '"version"|"ha"|"instances"'; then
        success "✓ AAP API is responding"
        local aap_version=$(echo "$ping_response" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
        echo "  AAP Version: ${aap_version:-unknown}"
        
        # Show cluster info
        local ha_status=$(echo "$ping_response" | grep -o '"ha":[^,]*' | cut -d':' -f2)
        echo "  High Availability: ${ha_status:-unknown}"
        
        local instance_count=$(echo "$ping_response" | grep -o '"instances":\[[^]]*\]' | grep -o '{"node"' | wc -l | tr -d ' ')
        echo "  Active Instances: ${instance_count:-0}"
    else
        warning "⚠ AAP API ping endpoint response unexpected"
        echo "  Response: ${ping_response:0:200}..."
        echo "  This might indicate authentication requirements"
    fi
    
    # Test 3: API version endpoint  
    log "Testing API version endpoint..."
    local version_response
    version_response=$(curl -k -s --connect-timeout 10 "${clean_url}/api/v2/" 2>/dev/null || echo "FAILED")
    
    if echo "$version_response" | grep -q "current_version\|description"; then
        success "✓ AAP API v2 is accessible"
    else
        warning "⚠ AAP API v2 endpoint requires authentication"
    fi
}

# Test authentication
test_authentication() {
    log "Testing authentication..."
    
    # Clean up URL
    local clean_url="${AAP_SERVER%/}"
    
    # Test with curl first
    local auth_test
    auth_test=$(curl -k -s --connect-timeout 10 \
        -u "${AAP_USERNAME}:${AAP_PASSWORD}" \
        "${clean_url}/api/v2/me/" 2>/dev/null || echo "AUTH_FAILED")
    
    if echo "$auth_test" | grep -q "username\|id"; then
        success "✓ Authentication successful via curl"
        local username=$(echo "$auth_test" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
        local user_id=$(echo "$auth_test" | grep -o '"id":[^,]*' | cut -d':' -f2)
        echo "  Authenticated as: ${username:-unknown} (ID: ${user_id:-unknown})"
    else
        error "✗ Authentication failed via curl"
        echo "  Response: ${auth_test:0:200}..."
        echo "  Check username and password"
        
        # Try to determine if it's a credential issue or something else
        if echo "$auth_test" | grep -q "401\|403\|Unauthorized\|Forbidden"; then
            error "  Likely cause: Invalid credentials"
        elif echo "$auth_test" | grep -q "404\|Not Found"; then
            error "  Likely cause: Wrong API endpoint or AAP version"
        else
            error "  Likely cause: Network or server issue"
        fi
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
    local clean_url="${AAP_SERVER%/}"
    
    awx config set --key "default.host" --value "${clean_url}"
    awx config set --key "default.username" --value "${AAP_USERNAME}"
    awx config set --key "default.password" --value "${AAP_PASSWORD}"
    
    # Test AWX CLI connection with correct syntax
    log "Testing AWX CLI connection..."
    if awx --conf.host "${clean_url}" \
           --conf.username "${AAP_USERNAME}" \
           --conf.password "${AAP_PASSWORD}" \
           -k \
           organizations list >/dev/null 2>&1; then
        success "✓ AWX CLI connection successful"
        local org_count
        org_count=$(awx organizations list --format json 2>/dev/null | jq length 2>/dev/null || echo "unknown")
        echo "  Found $org_count organization(s)"
        
        # Show available organizations
        log "Available organizations:"
        awx organizations list --format json 2>/dev/null | jq -r '.results[]? | "  - \(.name) (ID: \(.id))"' 2>/dev/null || echo "  Could not list organizations"
    else
        error "✗ AWX CLI connection failed"
        
        # Show more details
        log "Attempting direct AWX command with explicit parameters..."
        awx --conf.host "${clean_url}" \
            --conf.username "${AAP_USERNAME}" \
            --conf.password "${AAP_PASSWORD}" \
            -k \
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
