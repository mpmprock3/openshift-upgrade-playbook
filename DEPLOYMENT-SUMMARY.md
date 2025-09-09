# OpenShift Upgrade Playbook - Complete Deployment Package

## 📦 Package Contents

This complete package includes everything needed to deploy OpenShift upgrade checks both locally and to Red Hat Ansible Automation Platform (AAP).

### 📁 Project Structure
```
openshift-upgrade-playbook/
├── 📄 openshift-upgrade-hooks.yml     # Main playbook
├── 📄 ansible.cfg                     # Ansible configuration  
├── 📄 README.md                       # Comprehensive documentation
├── 📄 requirements.txt                # Python dependencies
├── 📄 DEPLOYMENT-SUMMARY.md          # This file
├── 📁 aap-integration/                # AAP-specific files
│   ├── 🚀 aap-deploy.sh              # Automated AAP deployment script
│   ├── 📋 project-setup.md           # Detailed AAP integration guide
│   ├── ⚙️ job-templates.yaml         # AAP job template definitions
│   ├── 🔄 workflow-template.yaml     # AAP workflow templates
│   └── 🔐 credentials.yaml           # AAP credential configurations
├── 📁 examples/                       # Example files and scripts
│   ├── 🎯 run-checks.sh              # Convenient wrapper script
│   └── 📝 sample-config.yml          # Sample configuration
├── 📁 inventory/                      # Inventory configurations
│   └── 🏠 hosts.yml                  # Ansible inventory
├── 📁 tasks/                         # Task files
│   ├── 🔍 pre-upgrade-checks.yml     # Pre-upgrade validation tasks
│   └── ✅ post-upgrade-checks.yml    # Post-upgrade validation tasks
├── 📁 templates/                     # Report templates
│   └── 📊 upgrade-report.j2          # HTML report template
├── 📁 vars/                          # Variable files
│   └── ⚙️ openshift-vars.yml         # Configuration variables
├── 📁 logs/                          # Generated log files (empty)
└── 📁 reports/                       # Generated HTML reports (empty)
```

## 🚀 Deployment Options

### Option 1: Local Execution
Perfect for testing, development, or one-off checks:

```bash
# 1. Configure your environment
cp examples/sample-config.yml vars/openshift-vars.yml
# Edit vars/openshift-vars.yml with your cluster details

# 2. Run checks
./examples/run-checks.sh pre          # Pre-upgrade only
./examples/run-checks.sh post         # Post-upgrade only  
./examples/run-checks.sh both         # Both checks
```

### Option 2: Ansible Automation Platform (AAP)
Enterprise-grade deployment with scheduling, workflows, and audit:

```bash
# 1. Push to Git repository
git init && git add . && git commit -m "Initial commit"
git remote add origin https://github.com/your-org/openshift-upgrade-playbook.git
git push -u origin main

# 2. Deploy to AAP
./aap-integration/aap-deploy.sh --server https://your-aap.example.com

# 3. Configure credentials and run from AAP web interface
```

## 🏢 AAP Integration Features

### ✅ What You Get with AAP Integration

**Immediate Benefits:**
- 🎛️ **Web UI Management**: Point-and-click job execution
- 📅 **Scheduled Checks**: Automated weekly health monitoring  
- 🔐 **Secure Credentials**: Encrypted token storage with AAP vault
- 👥 **Role-Based Access**: Control who can run checks on which clusters
- 📋 **Audit Logging**: Complete history of all check executions
- 🔔 **Notifications**: Email/Slack alerts for failures and successes

**Advanced Workflows:**
- 🔄 **Complete Upgrade Workflow**: Pre-checks → Manual Approval → Post-checks
- 🔀 **Multi-Cluster Operations**: Run checks across multiple clusters simultaneously
- ⏸️ **Approval Gates**: Require manual approval between workflow steps
- 📊 **Centralized Reporting**: All reports stored and accessible via AAP
- 🔗 **API Integration**: REST API for external system integration

### 🛠️ AAP Components Created

1. **Project**: Git-based project pointing to your repository
2. **Job Templates**: 
   - Pre-upgrade checks
   - Post-upgrade checks  
   - Complete workflow
3. **Workflow Templates**: Orchestrated upgrade processes with approvals
4. **Custom Credential Type**: Secure OpenShift token management
5. **Schedules**: Automated recurring health checks
6. **Notifications**: Integration with Slack, email, and webhooks

## 🔧 Quick Start Guide

### For Local Testing (5 minutes):
```bash
# 1. Clone/download this package
# 2. Update cluster details
vim vars/openshift-vars.yml

# 3. Run pre-upgrade checks
ansible-playbook -i inventory/hosts.yml openshift-upgrade-hooks.yml -e "mode=pre"
```

### For AAP Deployment (15 minutes):
```bash
# 1. Push to Git repository
git init && git add . && git commit -m "OpenShift upgrade playbook"
git remote add origin <your-repo-url>
git push -u origin main

# 2. Run AAP deployment script  
./aap-integration/aap-deploy.sh

# 3. Create OpenShift cluster credentials in AAP web interface
# 4. Run job templates from AAP dashboard
```

## 📋 Pre-Deployment Checklist

### Required Information:
- ✅ OpenShift cluster API URL
- ✅ Service account token with cluster-admin or appropriate permissions
- ✅ (For AAP) Git repository URL
- ✅ (For AAP) AAP server URL and credentials

### Prerequisites:
- ✅ Ansible 2.9+ installed locally (for local execution)
- ✅ Python 3.6+ with required packages (see requirements.txt)
- ✅ Network access to OpenShift cluster API endpoints
- ✅ (For AAP) AAP 2.x with Controller and Hub
- ✅ (For AAP) AWX CLI tools installed

### Permissions Required:
- ✅ Read access to cluster version, nodes, pods, services
- ✅ Read access to cluster operators and machine config pools  
- ✅ Read access to persistent volumes and storage classes
- ✅ Read access to metrics API (optional, for resource utilization)

## 🔍 What Gets Checked

### Pre-Upgrade Validation:
- 🏥 **Cluster Health**: Overall cluster status and version information
- 🖥️ **Node Status**: All nodes ready and healthy
- ⚙️ **Cluster Operators**: Critical operators not degraded
- 🗄️ **etcd Health**: Quorum status and pod health
- 💾 **Storage Systems**: Persistent volume status
- 🏢 **Critical Namespaces**: Essential system pods running
- 📊 **Resource Utilization**: CPU/Memory usage within thresholds
- ⏳ **Pending Operations**: No stuck upgrades or installations

### Post-Upgrade Validation:
- ✅ **Version Verification**: Confirms successful version upgrade
- 🔄 **Component Health**: All operators healthy after upgrade
- 🖥️ **Node Recovery**: All nodes operational post-upgrade
- 🌐 **API Responsiveness**: Cluster API accessible and responsive
- 🔗 **Network Connectivity**: DNS resolution and ingress functionality
- ⚙️ **Machine Configs**: Node configuration updates completed
- 💾 **Storage Integrity**: Persistent volumes intact and accessible

## 📊 Output and Reporting

### Console Output:
- Real-time status updates during execution
- Color-coded success/warning/failure indicators
- Summary of all check results

### Log Files (`logs/`):
- Timestamped detailed execution logs
- Structured logging for easy parsing
- Retained for audit and troubleshooting

### HTML Reports (`reports/`):
- Beautiful, professional HTML reports
- Visual status indicators and charts
- Detailed failure descriptions and recommendations
- Shareable for stakeholders and compliance

## 🎯 Use Cases

### Development Teams:
- Validate cluster health before/after upgrades
- Troubleshoot cluster issues
- Generate compliance reports

### Operations Teams:  
- Automate pre-upgrade validation processes
- Monitor cluster health continuously
- Standardize upgrade procedures across environments

### Enterprise Organizations:
- Centralized cluster health management via AAP
- Scheduled health monitoring and alerting
- Audit trail for compliance requirements
- Multi-cluster operations and reporting

## 🔐 Security Considerations

- 🔒 Tokens stored securely using Ansible Vault or AAP credentials
- 🎯 Minimal required permissions (read-only for most checks)
- 🔍 All actions logged for audit purposes
- 🌐 SSL certificate validation configurable
- 👥 RBAC integration with AAP for access control

## 📈 Next Steps After Deployment

1. **Test with Non-Production Cluster**: Validate playbook with dev/staging
2. **Customize Thresholds**: Adjust warning/critical thresholds for your environment
3. **Set Up Notifications**: Configure Slack/email alerts for failures
4. **Create Schedules**: Set up recurring health checks
5. **Train Teams**: Educate teams on using the playbooks and interpreting reports
6. **Integration**: Connect with monitoring systems and ticketing tools

## 🆘 Support and Troubleshooting

### Common Issues:
- **Authentication Errors**: Verify token and permissions
- **Network Connectivity**: Check firewall rules and DNS resolution
- **Resource Limits**: Ensure adequate CPU/memory for execution

### Debug Commands:
```bash
# Test cluster connectivity
curl -k https://api.your-cluster.example.com:6443/healthz

# Validate token
oc whoami --show-token

# Run in verbose mode
ansible-playbook -vvv -i inventory/hosts.yml openshift-upgrade-hooks.yml
```

---

**🎉 You now have a complete, production-ready OpenShift upgrade check solution that can be deployed locally or to Ansible Automation Platform!**
