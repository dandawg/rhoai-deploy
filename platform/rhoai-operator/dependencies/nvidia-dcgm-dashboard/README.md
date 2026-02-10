# NVIDIA DCGM Dashboard

Configures the NVIDIA DCGM Exporter Dashboard for GPU monitoring in the OpenShift console.

## Overview

This component automatically:
- Downloads the latest NVIDIA DCGM Exporter Dashboard JSON from GitHub
- Creates a ConfigMap in `openshift-config-managed` namespace
- Labels the ConfigMap to expose it in both Administrator and Developer perspectives

## Prerequisites

- NVIDIA GPU Operator installed and running
- GPU nodes with DCGM exporter daemonsets deployed
- OpenShift cluster with Prometheus monitoring enabled

## What is DCGM?

NVIDIA Data Center GPU Manager (DCGM) is a suite of tools for managing and monitoring NVIDIA datacenter GPUs. The DCGM Exporter exposes GPU metrics in Prometheus format, including:
- GPU utilization
- Memory usage
- Temperature
- Power consumption
- Clock speeds
- PCIe throughput

## Deployment

This component is automatically deployed as part of RHOAI dependencies:

```bash
oc apply -f gitops/platform/rhoai-dependencies.yaml
```

Or deploy standalone:

```bash
oc apply -k platform/rhoai-operator/dependencies/nvidia-dcgm-dashboard
```

## Verification

Check the ConfigMap was created:

```bash
oc get configmap nvidia-dcgm-exporter-dashboard -n openshift-config-managed --show-labels
```

Expected labels:
- `console.openshift.io/dashboard=true`
- `console.openshift.io/odc-dashboard=true`

## Accessing the Dashboard

Once deployed, the NVIDIA DCGM Exporter Dashboard will be available in the OpenShift web console:

1. **Administrator Perspective**: Observe → Dashboards → NVIDIA DCGM Exporter Dashboard
2. **Developer Perspective**: Observe → Dashboard → NVIDIA DCGM Exporter Dashboard

## Metrics Available

The dashboard provides visualizations for:
- GPU Utilization (%)
- GPU Memory Usage (GB)
- GPU Temperature (°C)
- GPU Power Usage (W)
- GPU Clock Speeds (MHz)
- PCIe Throughput (MB/s)
- GPU Error Counts
- Per-Pod GPU allocation

## Troubleshooting

### Dashboard not appearing

```bash
# Verify ConfigMap exists with correct labels
oc get configmap nvidia-dcgm-exporter-dashboard -n openshift-config-managed -o yaml

# Check job completed successfully
oc get job nvidia-dcgm-dashboard-setup -n openshift-config-managed
oc logs job/nvidia-dcgm-dashboard-setup -n openshift-config-managed
```

### No metrics showing

```bash
# Verify DCGM exporter is running on GPU nodes
oc get pods -n nvidia-gpu-operator -l app=nvidia-dcgm-exporter

# Check DCGM exporter logs
oc logs -n nvidia-gpu-operator -l app=nvidia-dcgm-exporter
```

The DCGM exporter is deployed automatically by the GPU Operator when `dcgmExporter.enabled: true` in the ClusterPolicy.

## References

- [NVIDIA DCGM Exporter GitHub](https://github.com/NVIDIA/dcgm-exporter)
- [NVIDIA GPU Operator Documentation](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/enable-gpu-monitoring-dashboard.html)
