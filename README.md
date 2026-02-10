# RHOAI Deploy

Simplified deployment of Red Hat OpenShift AI (RHOAI) platform.

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

## Quick Start

### 1. Install OpenShift GitOps

```bash
# Install operator subscription
oc apply -k platform/gitops-operator/base/

# Wait for operator (1-2 minutes)
oc wait --for=condition=Available deployment/openshift-gitops-operator-controller-manager \
  -n openshift-operators --timeout=300s

# Create ArgoCD instance
oc apply -k platform/gitops-operator/instance/

# Wait for ArgoCD (1-2 minutes)
oc wait --for=condition=Ready pod -l app.kubernetes.io/name=openshift-gitops-server \
  -n openshift-gitops --timeout=300s
```

### 2. Deploy GPU MachineSets (Optional)

If you need GPU nodes for model serving or training, deploy them first using the [openshift-infra](https://github.com/redhat-ai-americas/openshift-infra) repository:

```bash
# Clone openshift-infra repo
git clone https://github.com/redhat-ai-americas/openshift-infra.git
cd openshift-infra

# Deploy GPU nodes (see openshift-infra README for details)
INSTANCE_TYPE=g6.2xlarge ./infra/gpu-machineset/aws/deploy.sh

# Return to rhoai-deploy
cd ../rhoai-deploy
```

### 3. Deploy RHOAI Platform

```bash
# Option 1: Deploy RHOAI with dependencies (recommended)
oc apply -f gitops/platform/rhoai-operator.yaml

# Option 2: Deploy dependencies and RHOAI separately
oc apply -f gitops/platform/rhoai-dependencies.yaml  # NFD + Kueue
oc apply -f gitops/platform/nvidia-gpu-operator.yaml
oc apply -f gitops/platform/rhoai-operator.yaml
```

## Verification

```bash
# Check ArgoCD applications
oc get applications -n openshift-gitops

# Check GPU nodes
oc get nodes -l nvidia.com/gpu.present=true

# Check RHOAI dashboard
oc get route rhods-dashboard -n redhat-ods-applications

# Access RHOAI
RHOAI_URL=$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.host}')
echo "RHOAI Dashboard: https://${RHOAI_URL}"
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

### GPU Nodes Issues

For GPU node troubleshooting, see the [openshift-infra](https://github.com/redhat-ai-americas/openshift-infra) repository.

```bash
# Check GPU Operator pods
oc get pods -n nvidia-gpu-operator

# Check GPU nodes
oc get nodes -l nvidia.com/gpu.present=true
```

### RHOAI Not Ready

```bash
# Check operator status
oc get csv -n redhat-ods-operator

# Check DataScienceCluster
oc get datasciencecluster

# Check RHOAI pods
oc get pods -n redhat-ods-applications
```

## Resources

- [Red Hat OpenShift AI Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai)
- [OpenShift GitOps Documentation](https://docs.openshift.com/gitops/latest/)
- [NVIDIA GPU Operator Documentation](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/)

## Next Steps

After deploying the base platform, you can:
1. Deploy AI models for inference
2. Create workbenches for data science work
3. Set up model serving with KServe
4. Build ML pipelines

Related repositories:
- [openshift-infra](https://github.com/redhat-ai-americas/openshift-infra) - GPU infrastructure and MachineSets
- [rhoai-app-demos](https://github.com/redhat-ai-americas/rhoai-app-demos) - Application-level demos and examples
