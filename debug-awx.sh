#!/bin/bash

# Simple AWX CLI Debug Script
# ===========================

set -euo pipefail

# Your AAP details (update these)
AAP_SERVER="https://aap-route-aap-controller.apps.ck8786bi.eastus.aroapp.io"
AAP_USERNAME="admin"

# Get password
read -s -p "Enter AAP Password: " AAP_PASSWORD
echo ""

# Clean URL
CLEAN_URL="${AAP_SERVER%/}"

echo "=== AWX CLI Debug Test ==="
echo "Clean URL: $CLEAN_URL"
echo "Username: $AAP_USERNAME"
echo ""

# Step 1: Clear any existing config
echo "1. Clearing existing AWX CLI config..."
rm -rf ~/.awx/cli.cfg ~/.config/awx 2>/dev/null || true

# Step 2: Test basic AWX CLI
echo "2. Testing AWX CLI installation..."
awx --version || echo "AWX CLI version not available"

# Step 3: Test config commands
echo "3. Setting configuration..."
awx config set --key "default.host" --value "$CLEAN_URL"
awx config set --key "default.username" --value "$AAP_USERNAME"
awx config set --key "default.password" --value "$AAP_PASSWORD"

# Step 4: Show current config
echo "4. Current configuration:"
awx config list || echo "Could not show config"

# Step 5: Test connection with explicit parameters
echo "5. Testing with explicit parameters..."
echo "Command: awx --conf.host $CLEAN_URL --conf.username $AAP_USERNAME --conf.password [HIDDEN] -k me"
awx --conf.host "$CLEAN_URL" --conf.username "$AAP_USERNAME" --conf.password "$AAP_PASSWORD" -k me

# Step 6: Test organizations list
echo "6. Testing organizations list..."
awx --conf.host "$CLEAN_URL" --conf.username "$AAP_USERNAME" --conf.password "$AAP_PASSWORD" -k organizations list

echo ""
echo "=== Debug test completed ==="
