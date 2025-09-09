# Ansible Automation Platform Integration Guide

This guide explains how to deploy the OpenShift Upgrade Check playbook to Red Hat Ansible Automation Platform (AAP).

## Prerequisites

- Ansible Automation Platform 2.x (Controller + Hub)
- Git repository (GitHub, GitLab, or internal Git)
- AAP administrator access
- OpenShift cluster credentials

## Deployment Steps

### 1. Repository Preparation

First, push your playbook to a Git repository:

```bash
# Initialize git repository
git init
git add .
git commit -m "Initial OpenShift upgrade check playbook"

# Add your remote repository
git remote add origin https://github.com/your-org/openshift-upgrade-playbook.git
git push -u origin main
```

### 2. AAP Project Configuration

1. **Login to AAP Controller Web UI**
2. **Navigate to Resources > Projects**
3. **Click "Add" to create a new project**

#### Project Settings:
- **Name**: `OpenShift Upgrade Checks`
- **Organization**: Select your organization
- **Source Control Credential Type**: Git (if private repo)
- **Source Control URL**: `https://github.com/your-org/openshift-upgrade-playbook.git`
- **Source Control Branch/Tag/Commit**: `main`
- **Update Revision on Launch**: ✓ (recommended)
- **Cache Timeout**: 0 (always fetch latest)

### 3. Credential Configuration

Create credentials for OpenShift cluster access:

#### Machine Credential (for localhost execution):
- **Name**: `Localhost`
- **Credential Type**: Machine
- **Username**: Leave empty (uses connection: local)

#### Custom Credential for OpenShift Token:
- **Name**: `OpenShift Cluster Token`
- **Credential Type**: Custom
- **Custom Fields**:
  ```yaml
  fields:
    - id: openshift_token
      label: OpenShift Token
      type: string
      secret: true
    - id: cluster_api_url
      label: Cluster API URL
      type: string
  ```

### 4. Inventory Setup

Create a simple inventory in AAP:

#### Inventory Settings:
- **Name**: `OpenShift Clusters`
- **Organization**: Select your organization

#### Add Host:
- **Host Name**: `localhost`
- **Variables**:
  ```yaml
  ansible_connection: local
  ansible_python_interpreter: "{{ ansible_playbook_python }}"
  ```

### 5. Job Template Configuration

Create job templates for different check types:

#### Pre-Upgrade Checks Template:
- **Name**: `OpenShift Pre-Upgrade Checks`
- **Job Type**: Run
- **Inventory**: OpenShift Clusters
- **Project**: OpenShift Upgrade Checks
- **Playbook**: `openshift-upgrade-hooks.yml`
- **Credentials**: 
  - Localhost (Machine)
  - OpenShift Cluster Token (Custom)
- **Variables**:
  ```yaml
  mode: "pre"
  cluster_api_url: "{{ cluster_api_url }}"
  cluster_token: "{{ openshift_token }}"
  ```
- **Options**:
  - ✓ Prompt on Launch (Variables)
  - ✓ Enable Concurrent Jobs

#### Post-Upgrade Checks Template:
- **Name**: `OpenShift Post-Upgrade Checks`
- **Job Type**: Run
- **Inventory**: OpenShift Clusters  
- **Project**: OpenShift Upgrade Checks
- **Playbook**: `openshift-upgrade-hooks.yml`
- **Credentials**: Same as above
- **Variables**:
  ```yaml
  mode: "post"
  cluster_api_url: "{{ cluster_api_url }}"
  cluster_token: "{{ openshift_token }}"
  ```

### 6. Survey Configuration (Optional)

Add surveys to job templates for dynamic input:

#### Survey Questions:
1. **Cluster Selection**:
   - Question: "Select OpenShift Cluster"
   - Answer Variable Name: `selected_cluster`
   - Answer Type: Multiple Choice
   - Choices: `production-east|production-west|staging|development`

2. **Failure Behavior**:
   - Question: "Fail on check errors?"
   - Answer Variable Name: `fail_on_errors`
   - Answer Type: Multiple Choice
   - Choices: `true|false`
   - Default: `true`

### 7. Workflow Template (Advanced)

Create a workflow that runs both pre and post checks:

#### Workflow Steps:
1. **Pre-Upgrade Checks** → Success → **Approval Node**
2. **Approval Node** → Approved → **Post-Upgrade Checks**
3. **Post-Upgrade Checks** → Always → **Generate Report**

### 8. Scheduling

Set up scheduled runs for regular health checks:

#### Schedule Settings:
- **Name**: `Weekly OpenShift Health Check`
- **Job Template**: OpenShift Pre-Upgrade Checks
- **Schedule Type**: Cron
- **Cron Schedule**: `0 2 * * 0` (2 AM every Sunday)
- **Timezone**: Your local timezone

## AAP-Specific Considerations

### Environment Variables
In AAP, credentials are injected as environment variables. Update your playbook variables:

```yaml
# In vars/openshift-vars.yml
cluster_api_url: "{{ cluster_api_url | default(lookup('env', 'CLUSTER_API_URL')) }}"
cluster_token: "{{ cluster_token | default(lookup('env', 'OPENSHIFT_TOKEN')) }}"
```

### Logging and Artifacts
Configure artifact collection in job templates:

- **Artifact Path**: `logs/*.log,reports/*.html`
- **Artifact Cleanup**: 30 days

### Notifications

Set up notifications for job results:

#### Notification Types:
- **Email**: Send reports to infrastructure team
- **Slack**: Post status to #openshift-alerts channel  
- **Webhook**: Integrate with monitoring systems

#### Notification Triggers:
- ✓ Start
- ✓ Success  
- ✓ Failure
- ✓ Approval

## Multi-Cluster Management

For managing multiple clusters, create separate inventories or use inventory groups:

### Inventory Group Structure:
```
OpenShift Clusters/
├── Production/
│   ├── prod-east-cluster
│   └── prod-west-cluster
├── Staging/
│   └── staging-cluster
└── Development/
    └── dev-cluster
```

### Group Variables:
```yaml
# Production group vars
fail_on_pre_check_errors: true
fail_on_post_check_errors: true
notification:
  enabled: true
  slack_channel: "#openshift-prod-alerts"

# Development group vars  
fail_on_pre_check_errors: false
fail_on_post_check_errors: false
development_mode:
  enabled: true
```

## Security Best Practices

### Credential Management:
- Use AAP's built-in credential encryption
- Rotate OpenShift tokens regularly
- Limit credential access with RBAC

### Network Security:
- Ensure AAP can reach OpenShift API endpoints
- Use private networks where possible
- Configure firewall rules appropriately

### Audit and Compliance:
- Enable job audit logging
- Archive reports for compliance
- Set up retention policies

## Monitoring and Alerting

### Job Monitoring:
- Monitor job success/failure rates
- Set up alerts for consecutive failures
- Track execution time trends

### Integration with Monitoring Stack:
- Send metrics to Prometheus
- Create Grafana dashboards
- Alert on critical check failures

## Benefits of Using AAP

1. **Centralized Management**: Single pane of glass for all automation
2. **RBAC Integration**: Role-based access control
3. **Audit Logging**: Complete audit trail of all executions
4. **Scheduling**: Automated recurring checks
5. **Workflows**: Complex automation orchestration
6. **Notifications**: Built-in alerting capabilities
7. **Scalability**: Execute across multiple clusters simultaneously
8. **API Integration**: REST API for external system integration

## Next Steps

1. Deploy playbook to Git repository
2. Configure AAP project and credentials
3. Create and test job templates
4. Set up notifications and scheduling
5. Create workflows for complex scenarios
6. Monitor and optimize execution
