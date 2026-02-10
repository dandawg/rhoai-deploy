# RHOAI Dependencies

This directory contains the required and optional operator dependencies for Red Hat OpenShift AI (RHOAI) 3.x.

## Required Dependencies

These operators **must** be installed before RHOAI 3.x for proper functionality:

### 1. Node Feature Discovery (NFD) Operator
- **Directory**: `nfd-operator/`
- **Purpose**: Detects and labels hardware features on cluster nodes, essential for GPU node discovery
- **Namespace**: `openshift-nfd`
- **Channel**: `stable`

### 2. Red Hat Build for Kueue Operator
- **Directory**: `kueue-operator/`
- **Purpose**: Provides job queuing and resource management for AI workloads
- **Namespace**: `openshift-kueue`
- **Channel**: `stable`

## Optional Dependencies

These components provide additional monitoring capabilities:

### 3. NVIDIA DCGM Dashboard
- **Directory**: `nvidia-dcgm-dashboard/`
- **Purpose**: Configures GPU monitoring dashboard in OpenShift console
- **Namespace**: `openshift-config-managed`
- **Prerequisites**: NVIDIA GPU Operator must be installed first
- **Note**: Only needed if you're using NVIDIA GPUs and want console-based monitoring

> **Note**: The NVIDIA GPU Operator is installed separately via `gitops/platform/nvidia-gpu-operator.yaml`, not as part of dependencies.

## Installation

### Install All Dependencies via GitOps

```bash
# Install RHOAI dependencies (NFD, Kueue, DCGM Dashboard)
oc apply -f gitops/platform/rhoai-dependencies.yaml
```

### Install Individual Dependencies

```bash
# NFD Operator
oc apply -k platform/rhoai-operator/dependencies/nfd-operator/

# Kueue Operator
oc apply -k platform/rhoai-operator/dependencies/kueue-operator/

# NVIDIA DCGM Dashboard (requires GPU operator to be installed first)
oc apply -k platform/rhoai-operator/dependencies/nvidia-dcgm-dashboard/
```

### Wait for Operators to Be Ready

```bash
# Wait for NFD operator
oc wait --for=condition=Ready pod -l app=nfd-master \
  -n openshift-nfd --timeout=300s

# Wait for Kueue operator
oc wait --for=condition=Ready pod -l control-plane=controller-manager \
  -n openshift-kueue --timeout=300s

# Verify DCGM Dashboard Job completed (if installed)
oc get job nvidia-dcgm-dashboard-setup -n openshift-config-managed
```

## Deployment Order

For a complete RHOAI deployment with GPU support, follow this order:

1. **OpenShift GitOps** - Install ArgoCD first
2. **RHOAI Dependencies** - Install NFD and Kueue
3. **RHOAI Operator** - Install the RHOAI operator subscription
4. **NVIDIA GPU Operator** - Install GPU support (if using GPUs)
5. **GPU Infrastructure** - Deploy GPU nodes (AWS/Azure/etc)
6. **NVIDIA DCGM Dashboard** - Configure GPU monitoring (optional)

See `platform-deployment.ipynb` for the complete interactive deployment walkthrough.

## Version Notes

- **RHOAI 3.x**: Currently uses the `fast-3.x` subscription channel (will change to `stable` when 3.2 is released)
- These dependency versions are compatible with RHOAI 3.x
- See the main RHOAI operator configuration for channel updates

## Troubleshooting

### Check Operator Installation Status

```bash
# Check subscriptions
oc get subscriptions -n openshift-nfd
oc get subscriptions -n openshift-kueue

# Check operator pods
oc get pods -n openshift-nfd
oc get pods -n openshift-kueue

# Check install plans
oc get installplan -n openshift-nfd
oc get installplan -n openshift-kueue
```

### Common Issues

**NFD not detecting GPUs:**
- Ensure GPU nodes are properly provisioned
- Check NFD daemon set is running: `oc get daemonset -n openshift-nfd`
- Verify node labels: `oc get nodes --show-labels | grep feature.node.kubernetes.io`

**Kueue not available:**
- Verify the operator is installed: `oc get csv -n openshift-kueue`
- Check CRDs are present: `oc get crd | grep kueue`

## Resources

- [Node Feature Discovery Documentation](https://docs.openshift.com/container-platform/latest/hardware_enablement/psap-node-feature-discovery-operator.html)
- [Kueue Documentation](https://kueue.sigs.k8s.io/)
- [NVIDIA GPU Operator Documentation](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/index.html)
