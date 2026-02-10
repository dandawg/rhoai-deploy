# NVIDIA GPU Operator

The NVIDIA GPU Operator enables GPU workload scheduling on OpenShift by deploying and managing GPU drivers, device plugins, and monitoring tools.

> **Note**: This is separate from the NVIDIA DCGM Dashboard component. The GPU Operator installs the core GPU infrastructure and DCGM exporters, while the DCGM Dashboard component configures the OpenShift console visualization.

## Overview

The GPU operator provides:
- **GPU drivers** - NVIDIA kernel modules
- **CUDA runtime** - GPU computing platform
- **GPU device plugin** - Exposes GPUs to Kubernetes scheduler
- **DCGM Exporter** - GPU monitoring and Prometheus metrics
- **Node Feature Discovery integration** - Works with NFD to detect GPU hardware

## Deployment

Deploy via GitOps:

```bash
oc apply -f gitops/platform/nvidia-gpu-operator.yaml
```

This creates an ArgoCD Application that deploys:
- Namespace: `nvidia-gpu-operator`
- OperatorGroup
- Subscription (from certified-operators catalog)
- ClusterPolicy with GPU node tolerations

### Deployment Order (Sync Waves)

The resources use ArgoCD sync waves to ensure proper deployment order:

1. **Wave 0**: Namespace and OperatorGroup
2. **Wave 1**: Subscription (installs the GPU operator)
3. **Wave 2**: ClusterPolicy (created after operator installs CRDs)

This prevents the common error: `no matches for kind "ClusterPolicy"` which occurs when the ClusterPolicy is applied before the operator has installed its CRDs.

The ClusterPolicy also uses `SkipDryRunOnMissingResource=true` to allow ArgoCD to skip validation before the CRD exists.

### Manual Deployment with Kustomize

If deploying manually without ArgoCD, you need to wait for the operator to install before creating the ClusterPolicy:

```bash
# Deploy operator components first
oc apply -k platform/nvidia-gpu-operator --prune=false

# Wait for the operator to be ready (this can take 1-2 minutes)
oc wait --for=condition=available --timeout=300s \
  deployment/gpu-operator -n nvidia-gpu-operator

# Wait for CRD to be installed
oc wait --for condition=established --timeout=60s \
  crd/clusterpolicies.nvidia.com

# Now apply the ClusterPolicy
oc apply -f platform/nvidia-gpu-operator/clusterpolicy.yaml
```

Alternatively, apply everything at once and ignore the ClusterPolicy error, then re-apply:

```bash
oc apply -k platform/nvidia-gpu-operator
# Wait 1-2 minutes, then re-apply
oc apply -k platform/nvidia-gpu-operator
```

## Verification

Check operator installation:

```bash
# Verify CSV is installed
oc get csv -n nvidia-gpu-operator

# Check operator pods
oc get pods -n nvidia-gpu-operator

# Verify ClusterPolicy
oc get clusterpolicy -n nvidia-gpu-operator
```

Once GPU nodes are available, verify GPU resources:

```bash
# Check GPU nodes show allocatable GPUs
oc get nodes -l nvidia.com/gpu.present=true -o json | jq '.items[].status.allocatable'

# Should show:
# {
#   "nvidia.com/gpu": "1",
#   ...
# }
```

## Configuration

The ClusterPolicy is configured with tolerations to deploy on GPU nodes:

```yaml
spec:
  daemonsets:
    tolerations:
      - effect: NoSchedule
        operator: Exists
        key: nvidia.com/gpu
```

This matches the taints on GPU MachineSets.

## Architecture

```
NVIDIA GPU Operator
├── gpu-operator (deployment)
├── nvidia-driver-daemonset (on GPU nodes)
├── nvidia-container-toolkit-daemonset (on GPU nodes)
├── nvidia-device-plugin-daemonset (on GPU nodes)
├── nvidia-dcgm (daemonset for monitoring)
└── nvidia-dcgm-exporter (daemonset for Prometheus metrics)
```

## Troubleshooting

### Operator not installing

```bash
oc describe subscription gpu-operator-certified -n nvidia-gpu-operator
```

Check for:
- Catalog source availability
- InstallPlan status

### ClusterPolicy not creating resources

```bash
oc describe clusterpolicy gpu-cluster-policy -n nvidia-gpu-operator
```

### GPU not showing as allocatable on nodes

```bash
# Check device plugin logs
oc logs -n nvidia-gpu-operator -l app=nvidia-device-plugin-daemonset

# Check driver logs
oc logs -n nvidia-gpu-operator -l app=nvidia-driver-daemonset
```

Common issues:
- Driver daemonset waiting for GPU node (normal if no GPU nodes exist yet)
- Kernel module compilation in progress
- GPU node doesn't have proper labels/taints

## DCGM Monitoring

The GPU Operator includes DCGM (Data Center GPU Manager) components:
- **nvidia-dcgm** - DaemonSet running DCGM monitoring service on GPU nodes
- **nvidia-dcgm-exporter** - DaemonSet exposing GPU metrics to Prometheus

To visualize these metrics in the OpenShift console, deploy the NVIDIA DCGM Dashboard component:

```bash
oc apply -k platform/rhoai-operator/dependencies/nvidia-dcgm-dashboard
```

See `platform/rhoai-operator/dependencies/nvidia-dcgm-dashboard/README.md` for details.

## References

- [NVIDIA GPU Operator Documentation](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/overview.html)
- [OpenShift GPU Support](https://docs.openshift.com/container-platform/latest/hardware_enablement/psap-node-feature-discovery-operator.html)
- [NVIDIA DCGM Documentation](https://docs.nvidia.com/datacenter/dcgm/latest/user-guide/index.html)