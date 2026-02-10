# GitOps Application Catalog

ArgoCD Application manifests for deploying RHOAI platform and infrastructure.

## Overview

This catalog provides a modular approach to deployment:
1. **Browse** the catalog to see available components
2. **Apply** ArgoCD Applications: `oc apply -f <application-yaml>`
3. **Let ArgoCD** manage the deployment and lifecycle

## Prerequisites

- OpenShift GitOps operator installed (see `../platform/gitops-operator/`)
- ArgoCD server ready in `openshift-gitops` namespace
- `oc` CLI with cluster-admin access

## Deployment Order

### 1. Infrastructure Layer

Deploy GPU nodes first (if using GPU workloads):

```bash
# AWS g6.2xlarge (1x NVIDIA L4, recommended)
oc apply -f infra/gpu-machineset-aws-g6.yaml

# OR AWS g6.4xlarge (1x NVIDIA L4, larger instance)
oc apply -f infra/gpu-machineset-aws-g6-4xlarge.yaml
```

**Deploy Time**: 5-10 minutes per GPU node

### 2. Platform Layer

Deploy RHOAI and dependencies:

```bash
# Option 1: All-in-one (recommended)
oc apply -f platform/rhoai-operator.yaml

# Option 2: Step-by-step
oc apply -f platform/rhoai-dependencies.yaml  # NFD + Kueue
oc apply -f platform/nvidia-gpu-operator.yaml  # NVIDIA GPU support
# Wait for dependencies, then:
oc apply -f platform/rhoai-operator.yaml
```

**Deploy Time**: 
- Dependencies: 2-3 minutes
- GPU Operator: 3-5 minutes
- RHOAI: 5-10 minutes

## Component Catalog

### Infrastructure

#### `infra/gpu-machineset-aws-g6.yaml`

Creates AWS g6.2xlarge GPU nodes (1x NVIDIA L4, 8 vCPU, 32GB RAM)

**Prerequisites**: AWS-based OpenShift cluster

**Configuration**: Edit cluster-specific parameters in the Application manifest:
- `clusterName`: Your OpenShift cluster name
- `region`: AWS region (e.g., us-east-1)
- `availabilityZone`: AZ where nodes should be created
- `infraID`: OpenShift infrastructure ID

To get these values:
```bash
# Cluster name
oc get infrastructure cluster -o jsonpath='{.status.infrastructureName}' | sed 's/-[^-]*$//'

# Region
oc get infrastructure cluster -o jsonpath='{.status.platformStatus.aws.region}'

# Availability zone (use one from existing nodes)
oc get machines -n openshift-machine-api -o jsonpath='{.items[0].spec.providerSpec.value.placement.availabilityZone}'

# Infrastructure ID
oc get infrastructure cluster -o jsonpath='{.status.infrastructureName}'
```

**Usage**:
```bash
oc apply -f infra/gpu-machineset-aws-g6.yaml
```

#### `infra/gpu-machineset-aws-g6-4xlarge.yaml`

Creates AWS g6.4xlarge GPU nodes (1x NVIDIA L4, 16 vCPU, 64GB RAM)

Same configuration requirements as g6.2xlarge above.

---

### Platform

#### `platform/rhoai-dependencies.yaml`

Installs required operator dependencies for RHOAI 3.x:
- Node Feature Discovery (NFD) operator
- Red Hat Build for Kueue operator

**Prerequisites**: OpenShift 4.16+

**Usage**:
```bash
oc apply -f platform/rhoai-dependencies.yaml
```

---

#### `platform/nvidia-gpu-operator.yaml`

Installs NVIDIA GPU Operator for GPU support:
- GPU drivers and CUDA runtime
- GPU device plugin
- DCGM monitoring

**Prerequisites**: None (can be deployed anytime)

**Usage**:
```bash
oc apply -f platform/nvidia-gpu-operator.yaml
```

---

#### `platform/rhoai-operator.yaml`

Installs Red Hat OpenShift AI operator and DataScienceCluster.

Automatically includes dependencies (NFD, Kueue), so you can use this alone or after deploying dependencies separately.

**Prerequisites**: OpenShift 4.16+

**RHOAI 3.x Notes**:
- Uses `fast-3.x` subscription channel
- Will change to `stable` when RHOAI 3.2 is released

**Usage**:
```bash
oc apply -f platform/rhoai-operator.yaml
```

---

## Verification

### Check Application Status

```bash
# List all ArgoCD Applications
oc get applications -n openshift-gitops

# Check specific application
oc describe application <app-name> -n openshift-gitops
```

### Check Component Health

```bash
# GPU nodes
oc get nodes -l nvidia.com/gpu.present=true

# RHOAI operator
oc get csv -n redhat-ods-operator

# RHOAI DataScienceCluster
oc get datasciencecluster

# RHOAI dashboard
oc get route rhods-dashboard -n redhat-ods-applications
```

## Accessing ArgoCD UI

```bash
# Get ArgoCD URL
ARGOCD_URL=$(oc get route openshift-gitops-server \
  -n openshift-gitops -o jsonpath='{.spec.host}')
echo "ArgoCD UI: https://${ARGOCD_URL}"

# Get admin password
ARGOCD_PASSWORD=$(oc get secret openshift-gitops-cluster \
  -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d)
echo "Username: admin"
echo "Password: ${ARGOCD_PASSWORD}"
```

## Customization

### Forking the Repository

If you fork this repository, update the `repoURL` in all Application manifests:

```bash
find gitops/ -name "*.yaml" -type f -exec sed -i '' \
  's|repoURL: .*|repoURL: https://github.com/YOUR-ORG/rhoai-deploy|g' {} \;
```

### Using Different Branches

To track a different branch:

```yaml
spec:
  source:
    repoURL: https://github.com/YOUR-ORG/rhoai-deploy
    targetRevision: develop  # Change from 'main'
```

## Troubleshooting

### Application Shows "OutOfSync"

```bash
# Force sync
oc patch application <app-name> -n openshift-gitops \
  --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"syncStrategy":{"hook":{}}}}}'
```

### Application Health is "Unknown"

This is normal for:
- Namespaces (no health check)
- Jobs (shows "Progressing" then "Healthy")
- Some Custom Resources

### Repository Not Accessible

- Verify `repoURL` is correct in the Application manifest
- Check if repository is public (or configure credentials in ArgoCD)
- Check network connectivity from cluster to Git

## Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [OpenShift GitOps Documentation](https://docs.openshift.com/gitops/latest/)
