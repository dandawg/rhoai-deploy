# Red Hat OpenShift AI (RHOAI) Operator

This directory contains the configuration for deploying Red Hat OpenShift AI operator and creating a DataScienceCluster instance.

## Overview

Red Hat OpenShift AI (RHOAI) is an enterprise AI/ML platform that provides:
- **Dashboard**: Web UI for data scientists and ML engineers
- **Workbenches**: Jupyter notebooks and development environments
- **Model Serving**: Deploy models with KServe and ModelMesh
- **Pipelines**: Build and orchestrate ML workflows
- **Distributed Training**: Scale training across multiple nodes

## RHOAI 3.x Deployment

### Subscription Channel

RHOAI 3.x is currently deployed using the **`fast-3.x`** subscription channel. This provides early access to RHOAI 3.x features.

**Important**: When RHOAI 3.2 is released, the recommended channel will change to **`stable`**.

The subscription channel is configured in `base/kustomization.yaml` and can be easily updated:

```yaml
patches:
  - target:
      kind: Subscription
      name: rhods-operator
    patch: |-
      - op: replace
        path: /spec/channel
        value: fast-3.x  # Change this value as needed
```

**Available channels:**
- `fast-3.x` - Early access to RHOAI 3.x (current)
- `stable` - Production-ready releases (use after 3.2 release)
- `fast` - Latest features across all versions

### Required Dependencies

RHOAI 3.x requires the following operators to be installed **before** the RHOAI operator:

1. **Node Feature Discovery (NFD) Operator**
   - Detects hardware features on nodes
   - Required for GPU discovery and labeling
   
2. **Red Hat Build for Kueue Operator**
   - Provides job queuing and resource management
   - Required for workload scheduling

See the [`dependencies/`](dependencies/) directory for installation instructions.

### Optional Dependencies

For enhanced GPU support and monitoring:

3. **NVIDIA DCGM Operator** (GPU Operator)
   - Provides GPU health monitoring and telemetry
   - Recommended if using NVIDIA GPUs

## Directory Structure

```
rhoai-operator/
├── README.md                    # This file
├── kustomization.yaml           # Main kustomization file
├── base/                        # Base operator installation
│   ├── kustomization.yaml       # Channel configuration (patch)
│   ├── namespace.yaml           # redhat-ods-operator namespace
│   ├── operatorgroup.yaml       # Operator group
│   └── subscription.yaml        # Operator subscription
├── instance/                    # DataScienceCluster instance
│   ├── kustomization.yaml
│   └── datasciencecluster.yaml  # RHOAI components configuration
└── dependencies/                # Required operator dependencies
    ├── README.md                # Dependencies documentation
    ├── kustomization.yaml       # Deploy all dependencies
    ├── nfd-operator/            # Node Feature Discovery
    ├── kueue-operator/          # Red Hat Build for Kueue
    └── nvidia-dcgm-operator/    # NVIDIA GPU Operator (optional)
```

## Installation

### Option 1: Complete Installation (GitOps)

Use the ArgoCD Application manifest for automated deployment:

```bash
# This will deploy dependencies, operator, and instance
oc apply -f gitops/platform/rhoai-operator.yaml
```

### Option 2: Manual Step-by-Step Installation

#### Step 1: Install Dependencies

```bash
# Install required operators (NFD + Kueue)
oc apply -k platform/rhoai-operator/dependencies/

# Wait for operators to be ready (2-3 minutes)
oc wait --for=condition=Ready pod -l app=nfd-master \
  -n openshift-nfd --timeout=300s
oc wait --for=condition=Ready pod -l control-plane=controller-manager \
  -n openshift-kueue --timeout=300s
```

#### Step 2: Install RHOAI Operator

```bash
# Install the operator subscription
oc apply -k platform/rhoai-operator/base/

# Wait for operator to be ready (3-5 minutes)
oc wait --for=condition=Ready pod -l name=rhods-operator \
  -n redhat-ods-operator --timeout=600s
```

#### Step 3: Create DataScienceCluster

```bash
# Deploy the RHOAI instance
oc apply -k platform/rhoai-operator/instance/

# Wait for all components to be ready (5-10 minutes)
oc wait --for=condition=Ready datasciencecluster default-dsc \
  --timeout=600s
```

### Verification

```bash
# Check operator status
oc get csv -n redhat-ods-operator

# Check DataScienceCluster status
oc get datasciencecluster

# Check RHOAI dashboard
oc get route rhods-dashboard -n redhat-ods-applications
```

## Configuration

### Changing the Subscription Channel

Edit `base/kustomization.yaml` and update the patch value:

```yaml
patches:
  - target:
      kind: Subscription
      name: rhods-operator
    patch: |-
      - op: replace
        path: /spec/channel
        value: stable  # Change from fast-3.x to stable
```

Then apply the changes:

```bash
oc apply -k platform/rhoai-operator/base/
```

### Customizing DataScienceCluster Components

Edit `instance/datasciencecluster.yaml` to enable/disable components:

```yaml
spec:
  components:
    dashboard:
      managementState: Managed    # Enable
    workbenches:
      managementState: Managed    # Enable
    kserve:
      managementState: Managed    # Enable model serving
    modelmeshserving:
      managementState: Managed    # Enable ModelMesh
    datasciencepipelines:
      managementState: Managed    # Enable pipelines
    codeflare:
      managementState: Removed    # Disable distributed training
    ray:
      managementState: Removed    # Disable Ray
    kueue:
      managementState: Removed    # Use external Kueue operator
    trainingoperator:
      managementState: Removed    # Disable training operator
    trustyai:
      managementState: Removed    # Disable TrustyAI
```

Available states:
- `Managed` - Component is deployed and managed
- `Removed` - Component is not deployed

## Accessing RHOAI Dashboard

```bash
# Get the dashboard URL
RHOAI_URL=$(oc get route rhods-dashboard \
  -n redhat-ods-applications -o jsonpath='{.spec.host}')
echo "RHOAI Dashboard: https://${RHOAI_URL}"

# Login with your OpenShift credentials
```

## Troubleshooting

### Check Operator Installation

```bash
# Check subscription
oc get subscription rhods-operator -n redhat-ods-operator

# Check CSV (ClusterServiceVersion)
oc get csv -n redhat-ods-operator

# Check operator pods
oc get pods -n redhat-ods-operator

# Check operator logs
oc logs -l name=rhods-operator -n redhat-ods-operator
```

### Check DataScienceCluster Status

```bash
# Get cluster status
oc describe datasciencecluster default-dsc

# Check component status
oc get pods -n redhat-ods-applications
oc get pods -n redhat-ods-monitoring

# Check dashboard status
oc get deployment rhods-dashboard -n redhat-ods-applications
```

### Common Issues

**Operator stuck in "Installing":**
- Check install plan: `oc get installplan -n redhat-ods-operator`
- Check operator logs for errors
- Ensure dependencies (NFD, Kueue) are installed first

**DataScienceCluster not ready:**
- Check operator is running: `oc get pods -n redhat-ods-operator`
- Check for failed pods: `oc get pods -A | grep Error`
- Review DataScienceCluster status: `oc describe datasciencecluster default-dsc`

**Dashboard not accessible:**
- Check route exists: `oc get route -n redhat-ods-applications`
- Verify dashboard deployment: `oc get deployment rhods-dashboard -n redhat-ods-applications`
- Check pod logs: `oc logs -l app=rhods-dashboard -n redhat-ods-applications`

## Version Compatibility

| RHOAI Version | OpenShift Version | Subscription Channel |
|---------------|-------------------|----------------------|
| 3.x (current) | 4.16+            | fast-3.x             |
| 3.2+ (future) | 4.16+            | stable               |

## Resources

- [RHOAI Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai)
- [RHOAI Release Notes](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai/3.x/html/release_notes/)
- [Dependencies Documentation](dependencies/README.md)
- [DataScienceCluster API Reference](https://github.com/opendatahub-io/opendatahub-operator/blob/main/docs/api-overview.md)

## Next Steps

After RHOAI is deployed:
1. **Deploy GPU nodes** - See [infra/gpu-machineset/](../../infra/gpu-machineset/)
2. **Download models** - See [platform/models/](../models/)
3. **Deploy applications** - See [apps/](../../apps/)
4. **Run demos** - See [demos/](../../demos/)
