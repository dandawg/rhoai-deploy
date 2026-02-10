# Quick Reference Guide

This guide provides the essential commands for deploying the RHOAI platform.

## Prerequisites Check

```bash
# Verify OpenShift version (4.16+ required)
oc version

# Verify cluster-admin access
oc whoami
oc auth can-i create namespace
```

## Deployment Sequence

### Step 1: Install OpenShift GitOps (2-3 minutes)

```bash
# Install operator
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

**Verification:**
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

---

### Step 2: Deploy RHOAI Platform (5-10 minutes)

**Note:** If you need GPU nodes for model serving or training, deploy them using the [openshift-infra](https://github.com/redhat-ai-americas/openshift-infra) repository before proceeding.

**Option A: All-in-one (Recommended)**
```bash
# Single command deploys RHOAI + dependencies
oc apply -f gitops/platform/rhoai-operator.yaml
```

**Option B: Step-by-step**
```bash
# Deploy dependencies first
oc apply -f gitops/platform/rhoai-dependencies.yaml

# Wait for dependencies (2-3 minutes)
oc wait --for=condition=Ready \
  pod -l app=nfd-master -n openshift-nfd --timeout=300s
oc wait --for=condition=Ready \
  pod -l control-plane=controller-manager \
  -n openshift-kueue --timeout=300s

# Deploy NVIDIA GPU Operator
oc apply -f gitops/platform/nvidia-gpu-operator.yaml

# Deploy RHOAI
oc apply -f gitops/platform/rhoai-operator.yaml
```

**Verification:**
```bash
# Check RHOAI operator
oc get csv -n redhat-ods-operator

# Check DataScienceCluster
oc get datasciencecluster

# Check RHOAI dashboard
oc get route rhods-dashboard -n redhat-ods-applications

# Get RHOAI URL
RHOAI_URL=$(oc get route rhods-dashboard \
  -n redhat-ods-applications -o jsonpath='{.spec.host}')
echo "RHOAI Dashboard: https://${RHOAI_URL}"
```

---

## ArgoCD Application Status

```bash
# List all applications
oc get applications -n openshift-gitops

# Check specific application
oc describe application <name> -n openshift-gitops

# Watch applications sync
watch oc get applications -n openshift-gitops
```

---

## Common Operations

### Access RHOAI

```bash
# Get dashboard URL
oc get route rhods-dashboard -n redhat-ods-applications

# Login with OpenShift credentials
```

### Check GPU Status

```bash
# List GPU nodes
oc get nodes -l nvidia.com/gpu.present=true

# Check GPU allocatable resources
oc describe node <gpu-node-name> | grep -A 5 "Allocatable:"

# Check NVIDIA GPU Operator pods
oc get pods -n nvidia-gpu-operator
```

---

## Troubleshooting

### GPU Nodes Issues

For GPU node troubleshooting, see the [openshift-infra](https://github.com/redhat-ai-americas/openshift-infra) repository.

### RHOAI Not Ready

```bash
# Check operator logs
oc logs -l name=rhods-operator -n redhat-ods-operator

# Check DataScienceCluster status
oc describe datasciencecluster default-dsc

# Check component pods
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

---

## Next Steps

After successful deployment:

1. **Explore RHOAI Dashboard**
   - Create a workbench
   - Access Jupyter notebooks
   - Explore model serving options

2. **Deploy Models** (see rhoai-app-demos repo)
   - Download models to storage
   - Configure model serving
   - Test inference endpoints

3. **Deploy Applications** (see rhoai-app-demos repo)
   - AnythingLLM for RAG
   - n8n for workflow automation
   - Custom AI applications

---

## Useful Links

- [RHOAI Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai)
- [OpenShift GitOps Docs](https://docs.openshift.com/gitops/latest/)
- [NVIDIA GPU Operator Docs](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

---

## Getting Help

For issues or questions:
1. Check the component-specific READMEs in this repository
2. Review the EXTRACTION-NOTES.md for architecture details
3. Consult the troubleshooting sections above
4. For RHOAI support: Contact Red Hat Support
