# RHOAI Deploy

Simplified deployment of Red Hat OpenShift AI (RHOAI) platform using GitOps.

## Overview

This repository provides a streamlined approach to deploying the RHOAI platform:
- **Platform**: RHOAI operator and dependencies (NFD, Kueue, NVIDIA GPU Operator)
- **GitOps**: ArgoCD-based deployment automation

**Note:** These deployment steps are specifically for **RHOAI 3.x**. RHOAI 3.x requires OpenShift 4.16+ and uses the `fast-3.x` subscription channel.

For GPU infrastructure (MachineSets), see the [openshift-infra](https://github.com/redhat-ai-americas/openshift-infra) repository.

## Prerequisites

- **OpenShift 4.16+** with cluster-admin access
- **`oc` CLI** installed and configured
- **GPU nodes** (optional, for model serving and training)
  - See [openshift-infra](https://github.com/redhat-ai-americas/openshift-infra) for GPU node deployment

**Prerequisites Check:**
```bash
# Verify OpenShift version (4.16+ required)
oc version

# Verify cluster-admin access
oc whoami
oc auth can-i create namespace
```

## Deployment Steps

### Step 1: Install OpenShift GitOps (2-3 minutes)

```bash
# Install operator subscription
oc apply -k platform/gitops-operator/base/

# Wait for operator
oc wait --for=condition=Available \
  deployment/openshift-gitops-operator-controller-manager \
  -n openshift-operators --timeout=300s

# Create ArgoCD instance
oc apply -k platform/gitops-operator/instance/

# Wait for ArgoCD
oc wait --for=condition=Ready \
  pod -l app.kubernetes.io/name=openshift-gitops-server \
  -n openshift-gitops --timeout=300s
```

**Verify GitOps Installation:**
```bash
# Get ArgoCD URL and credentials
ARGOCD_URL=$(oc get route openshift-gitops-server \
  -n openshift-gitops -o jsonpath='{.spec.host}')
ARGOCD_PASS=$(oc get secret openshift-gitops-cluster \
  -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d)

echo "ArgoCD URL: https://${ARGOCD_URL}"
echo "Username: admin"
echo "Password: ${ARGOCD_PASS}"
```

### Step 2: Deploy GPU Nodes (Optional, 10-15 minutes)

GPU node deployment is managed in a separate repository. See the [openshift-infra](https://github.com/redhat-ai-americas/openshift-infra) repository for:
- Multi-GPU instance type support (g4dn, g6)
- Automated deployment scripts
- Cost optimization guidance

```bash
# Clone openshift-infra repo
git clone https://github.com/dandawg/openshift-infra.git
cd openshift-infra

# Deploy GPU nodes (see openshift-infra README for details)
INSTANCE_TYPE=g6.2xlarge ./infra/gpu-machineset/aws/deploy.sh

# Return to rhoai-deploy
cd ../rhoai-deploy
```

### Step 3: Deploy RHOAI Platform (5-10 minutes)

**Option A: Deploy as one Application (Recommended)**
```bash
# Single command deploys RHOAI + dependencies + GPU Operator
oc apply -f gitops/platform/rhoai-platform.yaml
```

**Option B: Step-by-step**
```bash
# 1. Deploy RHOAI dependencies (NFD + Kueue)
oc apply -f gitops/platform/rhoai-dependencies.yaml

# Wait for dependencies
oc wait --for=condition=Ready \
  pod -l app=nfd-master -n openshift-nfd --timeout=300s
oc wait --for=condition=Ready \
  pod -l control-plane=controller-manager \
  -n openshift-kueue --timeout=300s

# 2. Deploy NVIDIA GPU Operator (required for GPU support)
oc apply -f gitops/platform/nvidia-gpu-operator.yaml

# Wait for GPU operator (3-5 minutes, only if GPU nodes exist)
oc wait --for=condition=Ready \
  pod -l app=gpu-operator -n nvidia-gpu-operator --timeout=300s

# 3. Deploy RHOAI Operator
oc apply -f gitops/platform/rhoai-operator.yaml
```

## Verification

### Check ArgoCD Applications

```bash
# List all applications
oc get applications -n openshift-gitops

# Check specific application status
oc describe application <name> -n openshift-gitops

# Watch applications sync
watch oc get applications -n openshift-gitops
```

### Check RHOAI Status

```bash
# Check RHOAI operator
oc get csv -n redhat-ods-operator

# Check DataScienceCluster
oc get datasciencecluster

# Check RHOAI pods
oc get pods -n redhat-ods-applications

# Get RHOAI Dashboard URL
RHOAI_URL=$(oc get route rhods-dashboard \
  -n redhat-ods-applications -o jsonpath='{.spec.host}')
echo "RHOAI Dashboard: https://${RHOAI_URL}"
```

### Check GPU Status (if GPU nodes deployed)

```bash
# List GPU nodes
oc get nodes -l nvidia.com/gpu.present=true

# Check GPU allocatable resources
oc describe node <gpu-node-name> | grep -A 5 "Allocatable:"

# Check NVIDIA GPU Operator pods
oc get pods -n nvidia-gpu-operator

# Verify GPU device plugin is running
oc get daemonset nvidia-device-plugin-daemonset -n nvidia-gpu-operator
```

## Repository Structure

```
rhoai-deploy/
├── README.md              # This file
├── gitops/               # ArgoCD Application manifests
│   └── platform/        # RHOAI, GPU Operator, dependencies
└── platform/            # Platform component definitions
    ├── gitops-operator/ # OpenShift GitOps/ArgoCD
    ├── rhoai-operator/  # RHOAI with dependencies (NFD, Kueue)
    └── nvidia-gpu-operator/  # NVIDIA GPU Operator
```

## Components

### Platform Layer

**RHOAI Operator** - Red Hat OpenShift AI platform
- Dashboard, Workbenches, Model Serving, Pipelines
- Requires OpenShift 4.16+ for RHOAI 3.x
- Currently using `fast-3.x` subscription channel

**RHOAI Dependencies**
- Node Feature Discovery (NFD) - Hardware feature detection
- Red Hat Build for Kueue - Job queuing and resource management

**NVIDIA GPU Operator** - GPU infrastructure
- GPU drivers, CUDA runtime, device plugin
- DCGM monitoring and metrics

See [platform/rhoai-operator/README.md](platform/rhoai-operator/README.md) and [platform/nvidia-gpu-operator/README.md](platform/nvidia-gpu-operator/README.md) for details.

## GPU Infrastructure

For GPU node provisioning and management, see the [openshift-infra](https://github.com/redhat-ai-americas/openshift-infra) repository, which provides:
- Multi-GPU instance type support (g4dn, g6)
- Automated deployment scripts
- Cost optimization guidance
- GitOps-ready manifests

## Customization

### Forking the Repository

If you fork this repository, update the `repoURL` in all GitOps manifests:

```bash
# Update all ArgoCD Application manifests
find gitops/ -name "*.yaml" -type f -exec sed -i '' \
  's|repoURL: .*|repoURL: https://github.com/YOUR-ORG/rhoai-deploy|g' {} \;
```

### GPU Instance Configuration

For GPU instance configuration, see the [openshift-infra](https://github.com/redhat-ai-americas/openshift-infra) repository.

## Troubleshooting

### GPU Scheduling Issues

**Problem:** Pods fail to schedule with error: `0/N nodes are available: X Insufficient nvidia.com/gpu, Y node(s) didn't match Pod's node affinity/selector`

**Root Cause:** NVIDIA GPU Operator not deployed or GPU device plugin not running.

**Solution:**
```bash
# 1. Verify GPU Operator is deployed
oc get applications -n openshift-gitops | grep nvidia-gpu-operator

# If not deployed, deploy it:
oc apply -f gitops/platform/nvidia-gpu-operator.yaml

# 2. Check GPU Operator pods
oc get pods -n nvidia-gpu-operator

# 3. Verify GPU device plugin is running on GPU nodes
oc get daemonset nvidia-device-plugin-daemonset -n nvidia-gpu-operator

# 4. Check GPU resources are advertised
oc get nodes -o json | jq '.items[] | {name: .metadata.name, gpuAllocatable: .status.allocatable["nvidia.com/gpu"]}'

# 5. If GPU nodes exist but show 0 allocatable GPUs, restart device plugin
oc rollout restart daemonset/nvidia-device-plugin-daemonset -n nvidia-gpu-operator
```

### GPU Nodes Issues

For GPU node provisioning and troubleshooting, see the [openshift-infra](https://github.com/redhat-ai-americas/openshift-infra) repository.

```bash
# Check GPU nodes exist
oc get nodes -l nvidia.com/gpu.present=true

# Check GPU node labels
oc get nodes --show-labels | grep gpu
```

### RHOAI Not Ready

```bash
# Check operator logs
oc logs -l name=rhods-operator -n redhat-ods-operator

# Check DataScienceCluster status
oc describe datasciencecluster default-dsc

# Check RHOAI component pods
oc get pods -n redhat-ods-applications
oc get pods -n redhat-ods-monitoring
```

### ArgoCD Application OutOfSync

```bash
# Force sync
oc patch application <name> -n openshift-gitops \
  --type merge -p '{"operation":{"sync":{}}}'

# Check sync status
oc get application <name> -n openshift-gitops -o yaml
```

## Resources

- [Red Hat OpenShift AI Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai)
- [OpenShift GitOps Documentation](https://docs.openshift.com/gitops/latest/)
- [NVIDIA GPU Operator Documentation](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/)

## Next Steps

After successful deployment:

1. **Explore RHOAI Dashboard**
   - Access the dashboard using the URL from verification steps
   - Login with your OpenShift credentials
   - Create a workbench for data science work
   - Access Jupyter notebooks

2. **Deploy AI Models** (see [rhoai-app-demos](https://github.com/redhat-ai-americas/rhoai-app-demos) repository)
   - Download models to storage
   - Configure model serving with KServe
   - Test inference endpoints

3. **Build Applications** (see [rhoai-app-demos](https://github.com/redhat-ai-americas/rhoai-app-demos) repository)
   - Deploy AnythingLLM for RAG applications
   - Set up n8n for workflow automation
   - Create custom AI applications

## Related Repositories

- [openshift-infra](https://github.com/redhat-ai-americas/openshift-infra) - GPU infrastructure and MachineSets
- [rhoai-app-demos](https://github.com/redhat-ai-americas/rhoai-app-demos) - Application-level demos and examples
- [rhoai-model-serving](https://github.com/redhat-ai-americas/rhoai-model-serving) - Model serving configurations
