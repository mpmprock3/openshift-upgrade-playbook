# OpenShift Cluster Upgrade Pre/Post Hook Checks

A comprehensive Ansible playbook for performing health checks before and after OpenShift cluster upgrades. This playbook helps ensure cluster stability and validates successful upgrades through automated checks.

## 🚀 Features

- **Pre-upgrade checks**: Validate cluster health before upgrades
- **Post-upgrade checks**: Verify successful upgrade completion
- **Comprehensive monitoring**: Checks nodes, operators, etcd, storage, and networking
- **HTML reporting**: Generated detailed reports with visual status indicators
- **Flexible configuration**: Support for multiple clusters and environments
- **Error handling**: Configurable failure thresholds and warnings
- **Logging**: Detailed logging for audit and troubleshooting

## 📋 Prerequisites

- Ansible 2.9 or higher
- Python 3.6+
- OpenShift CLI (`oc`) - optional but recommended for troubleshooting
- Valid OpenShift cluster access token with appropriate permissions

### Required OpenShift Permissions

The service account or user token must have the following permissions:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: openshift-upgrade-checker
rules:
- apiGroups: [""]
  resources: ["nodes", "pods", "services", "persistentvolumes", "namespaces"]
  verbs: ["get", "list"]
- apiGroups: ["config.openshift.io"]
  resources: ["clusterversions", "clusteroperators"]
  verbs: ["get", "list"]
- apiGroups: ["machineconfiguration.openshift.io"]
  resources: ["machineconfigpools"]
  verbs: ["get", "list"]
- apiGroups: ["operator.openshift.io"]
  resources: ["ingresscontrollers"]
  verbs: ["get", "list"]
- apiGroups: ["metrics.k8s.io"]
  resources: ["nodes", "pods"]
  verbs: ["get", "list"]
```

## 📁 Project Structure

```
openshift-upgrade-playbook/
├── openshift-upgrade-hooks.yml    # Main playbook
├── ansible.cfg                    # Ansible configuration
├── inventory/
│   └── hosts.yml                  # Inventory file
├── vars/
│   └── openshift-vars.yml         # Variables and configuration
├── tasks/
│   ├── pre-upgrade-checks.yml     # Pre-upgrade validation tasks
│   └── post-upgrade-checks.yml    # Post-upgrade validation tasks
├── templates/
│   └── upgrade-report.j2          # HTML report template
├── logs/                          # Generated log files
├── reports/                       # Generated HTML reports
└── README.md                      # This file
```

## ⚙️ Configuration

### 1. Update Inventory

Edit `inventory/hosts.yml` to match your cluster configuration:

```yaml
all:
  children:
    openshift_clusters:
      hosts:
        localhost:
          cluster_api_url: "https://api.your-cluster.example.com:6443"
          cluster_token: "sha256~YOUR_TOKEN_HERE"
          cluster_name: "production"
          cluster_environment: "prod"
```

### 2. Configure Variables

Edit `vars/openshift-vars.yml` to customize behavior:

```yaml
# Cluster connection
cluster_api_url: "https://api.your-cluster.example.com:6443"
cluster_token: "{{ vault_openshift_token }}"

# Behavior settings
fail_on_pre_check_errors: true
fail_on_post_check_errors: true
post_upgrade_wait_time: 60
```

### 3. Secure Token Storage

For production use, store tokens securely using Ansible Vault:

```bash
# Create encrypted variable file
ansible-vault create vars/secrets.yml

# Add your token
vault_openshift_token: "sha256~YOUR_SECURE_TOKEN_HERE"
```

Update your playbook to include the vault file:

```yaml
vars_files:
  - vars/openshift-vars.yml
  - vars/secrets.yml
```

## 🔧 Usage

### Basic Usage

Run both pre and post-upgrade checks:

```bash
ansible-playbook -i inventory/hosts.yml openshift-upgrade-hooks.yml
```

### Run Only Pre-upgrade Checks

```bash
ansible-playbook -i inventory/hosts.yml openshift-upgrade-hooks.yml -e "mode=pre"
```

### Run Only Post-upgrade Checks

```bash
ansible-playbook -i inventory/hosts.yml openshift-upgrade-hooks.yml -e "mode=post"
```

### With Vault Password

```bash
ansible-playbook -i inventory/hosts.yml openshift-upgrade-hooks.yml --ask-vault-pass
```

### Targeting Specific Checks

Use tags to run specific check categories:

```bash
# Run only pre-upgrade checks
ansible-playbook -i inventory/hosts.yml openshift-upgrade-hooks.yml --tags "pre-checks"

# Run only post-upgrade checks
ansible-playbook -i inventory/hosts.yml openshift-upgrade-hooks.yml --tags "post-checks"
```

## 📊 Output and Reports

### Console Output
The playbook provides real-time status updates and summary information during execution.

### Log Files
Detailed logs are stored in `logs/upgrade-checks-YYYY-MM-DD-HHMM.log`

### HTML Reports
Comprehensive HTML reports are generated in `reports/upgrade-summary-YYYY-MM-DD-HHMM.html`

## 🔍 Check Categories

### Pre-upgrade Checks
- ✅ Cluster version and update channel validation
- ✅ Node health and readiness status
- ✅ Cluster operator health (kube-apiserver, etcd, dns, etc.)
- ✅ etcd cluster health and quorum
- ✅ Persistent volume status
- ✅ Critical namespace pod health
- ✅ Resource utilization monitoring
- ✅ Pending/stuck operations detection

### Post-upgrade Checks
- ✅ Version upgrade verification
- ✅ Cluster operator health post-upgrade
- ✅ Node health after upgrade
- ✅ etcd health post-upgrade
- ✅ API server responsiveness
- ✅ Critical pod health validation
- ✅ DNS and networking functionality
- ✅ Ingress controller health
- ✅ Machine config pool status
- ✅ Storage system validation

## 🚨 Error Handling

The playbook includes several levels of error handling:

1. **Critical Failures**: Issues that prevent upgrade or indicate serious problems
2. **Warnings**: Non-critical issues that should be monitored
3. **Information**: Status updates and successful check confirmations

Configure failure behavior using these variables:

```yaml
fail_on_pre_check_errors: true   # Stop on pre-upgrade failures
fail_on_post_check_errors: true  # Stop on post-upgrade failures
```

## 🔧 Customization

### Adding Custom Checks

Create additional task files in the `tasks/` directory and include them in the main playbook:

```yaml
- name: Custom application health check
  include_tasks: tasks/custom-app-checks.yml
  when: custom_checks.enabled | default(false)
```

### Notification Integration

Configure notifications in `vars/openshift-vars.yml`:

```yaml
notification:
  enabled: true
  webhook_url: "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
  slack_channel: "#openshift-alerts"
```

### Multiple Cluster Support

Define multiple clusters in your inventory:

```yaml
production_clusters:
  hosts:
    prod_east:
      cluster_api_url: "https://api.prod-east.example.com:6443"
    prod_west:
      cluster_api_url: "https://api.prod-west.example.com:6443"
```

Run against specific cluster groups:

```bash
ansible-playbook -i inventory/hosts.yml openshift-upgrade-hooks.yml -l production_clusters
```

## 🐛 Troubleshooting

### Common Issues

1. **Authentication Errors**
   - Verify token validity: `oc whoami`
   - Check token permissions
   - Ensure cluster URL is correct

2. **Network Connectivity**
   - Test cluster reachability: `curl -k https://api.your-cluster.example.com:6443/healthz`
   - Verify firewall rules
   - Check DNS resolution

3. **Permission Denied**
   - Verify service account has required cluster roles
   - Check namespace access permissions

### Debug Mode

Enable verbose output for troubleshooting:

```bash
ansible-playbook -i inventory/hosts.yml openshift-upgrade-hooks.yml -vvv
```

### Manual Verification

Use `oc` commands to manually verify check results:

```bash
# Check cluster version
oc get clusterversion

# Check node status
oc get nodes

# Check cluster operators
oc get clusteroperators

# Check critical pods
oc get pods -n openshift-etcd
```

## 🔐 Security Considerations

- Store tokens securely using Ansible Vault
- Use service accounts with minimal required permissions
- Regularly rotate access tokens
- Monitor and audit playbook execution logs
- Avoid storing credentials in version control

## 📝 Best Practices

1. **Before Upgrades**:
   - Run pre-checks at least 24 hours before scheduled upgrades
   - Address all critical failures before proceeding
   - Document any warnings for post-upgrade verification

2. **After Upgrades**:
   - Run post-checks immediately after upgrade completion
   - Monitor cluster for 24-48 hours after upgrades
   - Keep reports for compliance and audit purposes

3. **Regular Maintenance**:
   - Run health checks weekly during maintenance windows
   - Update playbook variables as cluster configuration changes
   - Review and update check thresholds based on cluster growth

## 🏢 Ansible Automation Platform Integration

This playbook is fully compatible with **Red Hat Ansible Automation Platform (AAP)**! For enterprise deployments, AAP provides:

- **Centralized Management**: Single pane of glass for all automation
- **RBAC Integration**: Role-based access control
- **Scheduled Execution**: Automated recurring health checks
- **Workflow Orchestration**: Complex upgrade workflows with approvals
- **Audit Logging**: Complete audit trail
- **API Integration**: REST API for external system integration

### Quick AAP Deployment

```bash
# 1. Push to Git repository
git init && git add . && git commit -m "OpenShift upgrade playbook"
git remote add origin https://github.com/your-org/openshift-upgrade-playbook.git
git push -u origin main

# 2. Deploy to AAP using the provided script
./aap-integration/aap-deploy.sh --server https://your-aap.example.com

# 3. Configure OpenShift cluster credentials in AAP
# 4. Run job templates or workflows from AAP web interface
```

See the complete **[AAP Integration Guide](aap-integration/project-setup.md)** for detailed setup instructions, workflow templates, and best practices.

## 📚 Additional Resources

- [OpenShift Documentation](https://docs.openshift.com/)
- [OpenShift Cluster Upgrades](https://docs.openshift.com/container-platform/latest/updating/understanding_updates/intro-to-update-process.html)
- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Automation Platform](https://www.redhat.com/en/technologies/management/ansible)
- [OpenShift Health Monitoring](https://docs.openshift.com/container-platform/latest/monitoring/monitoring-overview.html)

## 🤝 Contributing

1. Fork the repository
2. Create feature branches for improvements
3. Test changes against multiple OpenShift versions
4. Submit pull requests with detailed descriptions

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Note**: This playbook is designed for OpenShift 4.x clusters. For OpenShift 3.x, modifications may be required for API endpoints and resource types.
