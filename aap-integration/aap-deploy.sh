#!/bin/bash

# AAP Deployment Script for OpenShift Upgrade Checks
# ===================================================
# 
# This script automates the deployment of OpenShift upgrade check
# playbooks to Red Hat Ansible Automation Platform (AAP).
#
# Prerequisites:
# - AAP CLI tools installed (ansible-navigator, awx CLI, etc.)
# - AAP credentials configured
# - Git repository with playbook code

set -euo pipefail

# Configuration
AAP_SERVER="${AAP_SERVER:-}"
AAP_USERNAME="${AAP_USERNAME:-}"
AAP_PASSWORD="${AAP_PASSWORD:-}"
AAP_ORG="${AAP_ORG:-Default}"
GIT_REPO="${GIT_REPO:-https://github.com/mpmprock3/openshift-upgrade-playbook.git}"
GIT_BRANCH="${GIT_BRANCH:-main}"
PROJECT_NAME="OpenShift Upgrade Checks"

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

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check AWX CLI
    if ! command -v awx &> /dev/null; then
        error "AWX CLI not found. Please install: pip install awxkit"
        exit 1
    fi
    
    # Check ansible-navigator
    if ! command -v ansible-navigator &> /dev/null; then
        warning "ansible-navigator not found. Some features may not work."
    fi
    
    # Check git
    if ! command -v git &> /dev/null; then
        error "Git not found. Please install git."
        exit 1
    fi
    
    success "Prerequisites check completed"
}

# Collect AAP connection details interactively
collect_aap_details() {
    log "Collecting AAP connection details..."
    echo ""
    
    # Get AAP Server URL
    if [[ -z "$AAP_SERVER" ]]; then
        echo -e "${BLUE}Enter your AAP server URL:${NC}"
        echo "Examples:"
        echo "  - https://automation-controller.apps.cluster.example.com"
        echo "  - https://aap.company.com"
        echo ""
        while [[ -z "$AAP_SERVER" ]]; do
            read -p "AAP Server URL: " AAP_SERVER
            if [[ -z "$AAP_SERVER" ]]; then
                error "AAP Server URL is required"
            elif [[ ! "$AAP_SERVER" =~ ^https?:// ]]; then
                warning "URL should start with http:// or https://"
                read -p "Continue with '$AAP_SERVER'? (y/N): " confirm
                if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                    AAP_SERVER=""
                fi
            fi
        done
    fi
    
    # Get AAP Username
    if [[ -z "$AAP_USERNAME" ]]; then
        echo ""
        read -p "AAP Username (default: admin): " AAP_USERNAME
        AAP_USERNAME="${AAP_USERNAME:-admin}"
    fi
    
    # Get AAP Password
    if [[ -z "$AAP_PASSWORD" ]]; then
        echo ""
        while [[ -z "$AAP_PASSWORD" ]]; do
            read -s -p "AAP Password for ${AAP_USERNAME}: " AAP_PASSWORD
            echo ""
            if [[ -z "$AAP_PASSWORD" ]]; then
                error "Password is required"
            fi
        done
    fi
    
    # Get Organization (optional)
    echo ""
    read -p "AAP Organization (default: Default): " input_org
    if [[ -n "$input_org" ]]; then
        AAP_ORG="$input_org"
    fi
    
    # Get Git Repository (optional override)
    echo ""
    echo -e "${YELLOW}Git repository configuration:${NC}"
    echo "Current: $GIT_REPO"
    read -p "Use different repository URL? (leave blank to keep current): " input_repo
    if [[ -n "$input_repo" ]]; then
        GIT_REPO="$input_repo"
    fi
    
    # Display summary
    echo ""
    log "Configuration Summary:"
    echo "  AAP Server: $AAP_SERVER"
    echo "  Username: $AAP_USERNAME"  
    echo "  Organization: $AAP_ORG"
    echo "  Git Repository: $GIT_REPO"
    echo "  Git Branch: $GIT_BRANCH"
    echo ""
    
    read -p "Proceed with these settings? (Y/n): " confirm
    if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
        error "Configuration cancelled by user"
        exit 1
    fi
    
    success "AAP connection details collected"
}

# Configure AWX CLI
configure_awx() {
    log "Configuring AWX CLI..."
    
    # Remove any existing AWX CLI configuration
    rm -rf ~/.awx/cli.cfg ~/.config/awx 2>/dev/null || true
    
    # Set configuration with explicit format
    log "Setting AAP server: ${AAP_SERVER}"
    awx config set \
        --key "default.host" \
        --value "${AAP_SERVER}"
    
    log "Setting username: ${AAP_USERNAME}"
    awx config set \
        --key "default.username" \
        --value "${AAP_USERNAME}"
    
    log "Setting password: [HIDDEN]"
    awx config set \
        --key "default.password" \
        --value "${AAP_PASSWORD}"
    
    # Disable SSL verification if needed (common for self-signed certs)
    awx config set \
        --key "default.verify_ssl" \
        --value "false"
    
    # Show current configuration (without password)
    log "Current AWX CLI configuration:"
    awx config list --format json | jq 'del(.default.password)' || echo "Could not display config"
    
    # Test connection with more specific error handling
    log "Testing connection to AAP..."
    if awx --conf.host "${AAP_SERVER}" --conf.username "${AAP_USERNAME}" --conf.password "${AAP_PASSWORD}" --conf.verify_ssl false organizations list > /dev/null 2>&1; then
        success "AWX CLI configured and connected successfully"
    else
        error "Failed to connect to AAP. Debugging information:"
        echo "  AAP Server: ${AAP_SERVER}"
        echo "  Username: ${AAP_USERNAME}"
        echo "  SSL Verification: Disabled"
        
        # Try a manual curl test
        log "Testing basic connectivity with curl..."
        if curl -k -s --connect-timeout 10 "${AAP_SERVER}/api/v2/ping/" | grep -q "ping"; then
            success "AAP server is reachable"
            error "Authentication or API issue - check username/password"
        else
            error "Cannot reach AAP server - check URL and network connectivity"
            echo "  Trying: curl -k ${AAP_SERVER}/api/v2/ping/"
        fi
        exit 1
    fi
}

# Create or update project
setup_project() {
    log "Setting up AAP project..."
    
    local org_id
    org_id=$(awx organizations list --name "${AAP_ORG}" --format json | jq -r '.results[0].id')
    
    if [[ "$org_id" == "null" ]]; then
        error "Organization '${AAP_ORG}' not found"
        exit 1
    fi
    
    # Check if project exists
    local project_id
    project_id=$(awx projects list --name "${PROJECT_NAME}" --format json | jq -r '.results[0].id // empty')
    
    if [[ -n "$project_id" ]]; then
        log "Updating existing project (ID: ${project_id})"
        awx projects modify "${project_id}" \
            --scm_url "${GIT_REPO}" \
            --scm_branch "${GIT_BRANCH}" \
            --scm_update_on_launch true \
            --scm_update_cache_timeout 0
    else
        log "Creating new project"
        awx projects create \
            --name "${PROJECT_NAME}" \
            --organization "${org_id}" \
            --scm_type git \
            --scm_url "${GIT_REPO}" \
            --scm_branch "${GIT_BRANCH}" \
            --scm_update_on_launch true \
            --scm_update_cache_timeout 0
    fi
    
    success "Project setup completed"
}

# Create inventory
setup_inventory() {
    log "Setting up inventory..."
    
    local org_id
    org_id=$(awx organizations list --name "${AAP_ORG}" --format json | jq -r '.results[0].id')
    
    # Create inventory
    local inventory_name="OpenShift Clusters"
    local inventory_id
    inventory_id=$(awx inventories list --name "${inventory_name}" --format json | jq -r '.results[0].id // empty')
    
    if [[ -z "$inventory_id" ]]; then
        log "Creating inventory: ${inventory_name}"
        inventory_id=$(awx inventories create \
            --name "${inventory_name}" \
            --organization "${org_id}" \
            --format json | jq -r '.id')
    fi
    
    # Add localhost host
    local host_id
    host_id=$(awx hosts list --inventory "${inventory_id}" --name "localhost" --format json | jq -r '.results[0].id // empty')
    
    if [[ -z "$host_id" ]]; then
        log "Creating localhost host"
        awx hosts create \
            --name "localhost" \
            --inventory "${inventory_id}" \
            --variables '{
                "ansible_connection": "local",
                "ansible_python_interpreter": "{{ ansible_playbook_python }}"
            }'
    fi
    
    success "Inventory setup completed"
}

# Create custom credential type
setup_credential_type() {
    log "Setting up OpenShift credential type..."
    
    local cred_type_name="OpenShift Cluster Access"
    local cred_type_id
    cred_type_id=$(awx credential_types list --name "${cred_type_name}" --format json | jq -r '.results[0].id // empty')
    
    if [[ -z "$cred_type_id" ]]; then
        log "Creating OpenShift credential type"
        cat > /tmp/openshift_cred_type.json << 'EOF'
{
  "name": "OpenShift Cluster Access",
  "description": "Credential type for OpenShift cluster API access",
  "kind": "cloud",
  "inputs": {
    "fields": [
      {
        "id": "cluster_api_url",
        "type": "string",
        "label": "Cluster API URL"
      },
      {
        "id": "openshift_token", 
        "type": "string",
        "label": "OpenShift Token",
        "secret": true
      },
      {
        "id": "validate_certs",
        "type": "boolean", 
        "label": "Validate SSL Certificates",
        "default": true
      }
    ],
    "required": ["cluster_api_url", "openshift_token"]
  },
  "injectors": {
    "env": {
      "CLUSTER_API_URL": "{{ cluster_api_url }}",
      "OPENSHIFT_TOKEN": "{{ openshift_token }}",
      "VALIDATE_SSL_CERTS": "{{ validate_certs }}"
    },
    "extra_vars": {
      "cluster_api_url": "{{ cluster_api_url }}",
      "cluster_token": "{{ openshift_token }}",
      "validate_ssl_certs": "{{ validate_certs }}"
    }
  }
}
EOF
        
        awx credential_types create --conf.json /tmp/openshift_cred_type.json
        rm /tmp/openshift_cred_type.json
    fi
    
    success "Credential type setup completed"
}

# Create job templates
setup_job_templates() {
    log "Setting up job templates..."
    
    local org_id project_id inventory_id machine_cred_id
    org_id=$(awx organizations list --name "${AAP_ORG}" --format json | jq -r '.results[0].id')
    project_id=$(awx projects list --name "${PROJECT_NAME}" --format json | jq -r '.results[0].id')
    inventory_id=$(awx inventories list --name "OpenShift Clusters" --format json | jq -r '.results[0].id')
    machine_cred_id=$(awx credentials list --credential_type "Machine" --format json | jq -r '.results[0].id')
    
    # Pre-upgrade checks template
    local pre_template_id
    pre_template_id=$(awx job_templates list --name "OpenShift Pre-Upgrade Checks" --format json | jq -r '.results[0].id // empty')
    
    if [[ -z "$pre_template_id" ]]; then
        log "Creating pre-upgrade checks job template"
        awx job_templates create \
            --name "OpenShift Pre-Upgrade Checks" \
            --description "Run comprehensive pre-upgrade health checks" \
            --organization "${org_id}" \
            --project "${project_id}" \
            --inventory "${inventory_id}" \
            --playbook "openshift-upgrade-hooks.yml" \
            --credential "${machine_cred_id}" \
            --extra_vars '{"mode": "pre", "fail_on_pre_check_errors": true}' \
            --job_tags "pre-checks" \
            --timeout 3600 \
            --ask_variables_on_launch true \
            --ask_limit_on_launch true
    fi
    
    # Post-upgrade checks template  
    local post_template_id
    post_template_id=$(awx job_templates list --name "OpenShift Post-Upgrade Checks" --format json | jq -r '.results[0].id // empty')
    
    if [[ -z "$post_template_id" ]]; then
        log "Creating post-upgrade checks job template"
        awx job_templates create \
            --name "OpenShift Post-Upgrade Checks" \
            --description "Validate cluster health after upgrade" \
            --organization "${org_id}" \
            --project "${project_id}" \
            --inventory "${inventory_id}" \
            --playbook "openshift-upgrade-hooks.yml" \
            --credential "${machine_cred_id}" \
            --extra_vars '{"mode": "post", "fail_on_post_check_errors": true}' \
            --job_tags "post-checks" \
            --timeout 3600 \
            --ask_variables_on_launch true \
            --ask_limit_on_launch true
    fi
    
    success "Job templates setup completed"
}

# Create workflow template
setup_workflow() {
    log "Setting up workflow template..."
    
    local org_id inventory_id
    org_id=$(awx organizations list --name "${AAP_ORG}" --format json | jq -r '.results[0].id')
    inventory_id=$(awx inventories list --name "OpenShift Clusters" --format json | jq -r '.results[0].id')
    
    # Create workflow template
    local workflow_id
    workflow_id=$(awx workflow_job_templates list --name "OpenShift Upgrade Complete Workflow" --format json | jq -r '.results[0].id // empty')
    
    if [[ -z "$workflow_id" ]]; then
        log "Creating upgrade workflow template"
        workflow_id=$(awx workflow_job_templates create \
            --name "OpenShift Upgrade Complete Workflow" \
            --description "Complete upgrade workflow with pre/post checks" \
            --organization "${org_id}" \
            --inventory "${inventory_id}" \
            --ask_variables_on_launch true \
            --format json | jq -r '.id')
    fi
    
    success "Workflow template setup completed"
}

# Create schedules
setup_schedules() {
    log "Setting up scheduled jobs..."
    
    local pre_template_id
    pre_template_id=$(awx job_templates list --name "OpenShift Pre-Upgrade Checks" --format json | jq -r '.results[0].id')
    
    # Weekly health check schedule
    local schedule_id
    schedule_id=$(awx schedules list --name "Weekly OpenShift Health Check" --format json | jq -r '.results[0].id // empty')
    
    if [[ -z "$schedule_id" ]]; then
        log "Creating weekly health check schedule"
        awx schedules create \
            --name "Weekly OpenShift Health Check" \
            --description "Automated weekly cluster health check" \
            --unified_job_template "${pre_template_id}" \
            --rrule "DTSTART:20240101T020000Z RRULE:FREQ=WEEKLY;BYDAY=SU" \
            --extra_data '{"mode": "pre", "fail_on_pre_check_errors": false}'
    fi
    
    success "Schedules setup completed"
}

# Display welcome banner
show_banner() {
    echo ""
    echo -e "${BLUE}==========================================================${NC}"
    echo -e "${BLUE}    AAP Deployment for OpenShift Upgrade Checks${NC}"
    echo -e "${BLUE}==========================================================${NC}"
    echo ""
    echo "This script will deploy the OpenShift upgrade check playbook"
    echo "to your Red Hat Ansible Automation Platform (AAP) instance."
    echo ""
    echo -e "${YELLOW}What this script will create:${NC}"
    echo "  ✓ AAP Project pointing to your Git repository"
    echo "  ✓ Job Templates for pre/post upgrade checks"
    echo "  ✓ Workflow Templates for complete upgrade process"
    echo "  ✓ Custom Credential Types for OpenShift access"
    echo "  ✓ Scheduled jobs for automated health checks"
    echo ""
}

# Main deployment function
deploy_to_aap() {
    show_banner
    log "Starting AAP deployment for OpenShift Upgrade Checks"
    
    check_prerequisites
    collect_aap_details
    configure_awx
    setup_project
    setup_inventory
    setup_credential_type
    setup_job_templates
    setup_workflow
    setup_schedules
    
    success "AAP deployment completed successfully!"
    
    cat << EOF

🎉 Deployment Summary
====================
✅ Project: ${PROJECT_NAME}
✅ Git Repository: ${GIT_REPO}  
✅ Inventory: OpenShift Clusters
✅ Job Templates: Pre & Post Upgrade Checks
✅ Workflow: Complete Upgrade Workflow
✅ Schedule: Weekly Health Checks

Next Steps:
1. Create OpenShift cluster credentials in AAP
2. Test job templates with your clusters  
3. Configure notifications
4. Set up additional schedules as needed

AAP Server: ${AAP_SERVER}
EOF
}

# Script usage
usage() {
    cat << EOF
AAP Deployment Script for OpenShift Upgrade Checks

Usage: $0 [OPTIONS]

Options:
    --server URL        AAP server URL
    --username USER     AAP username
    --password PASS     AAP password (not recommended, use interactive mode)
    --org ORG          Organization name (default: ${AAP_ORG})
    --repo URL         Git repository URL (default: ${GIT_REPO})
    --branch BRANCH    Git branch (default: ${GIT_BRANCH})
    --help             Show this help message

Environment Variables (optional - script will prompt if not set):
    AAP_SERVER         AAP server URL
    AAP_USERNAME       AAP username
    AAP_PASSWORD       AAP password
    AAP_ORG           Organization name
    GIT_REPO          Git repository URL
    GIT_BRANCH        Git branch

Examples:
    $0                                                    # Interactive mode (recommended)
    $0 --server https://aap.company.com --org Production # Pre-configure some options
    AAP_SERVER=https://aap.company.com $0                # Set server via env var

EOF
}

# Parse command line arguments
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
        --org)
            AAP_ORG="$2"
            shift 2
            ;;
        --repo)
            GIT_REPO="$2"
            shift 2
            ;;
        --branch)
            GIT_BRANCH="$2" 
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Run deployment
deploy_to_aap
