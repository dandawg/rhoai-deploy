# OpenShift GitOps Operator

This component installs the Red Hat OpenShift GitOps operator, which provides ArgoCD for GitOps-based deployments.

### Installation

The installation requires two steps to avoid timing issues with CRD installation:

```bash
# Step 1: Install the operator subscription
oc apply -k platform/gitops-operator/base/

# Wait for the operator to install (1-2 minutes)
oc wait --for=condition=Available deployment/openshift-gitops-operator-controller-manager \
  -n openshift-operators --timeout=300s

# Step 2: Create the ArgoCD instance
oc apply -k platform/gitops-operator/instance/

# Wait for ArgoCD server to be ready (1-2 minutes)
oc wait --for=condition=Ready pod -l app.kubernetes.io/name=openshift-gitops-server \
  -n openshift-gitops --timeout=300s
```

**Why two steps?** The operator needs time to install its Custom Resource Definitions (CRDs) before the ArgoCD instance can be created. Applying both at once causes a timing issue.

### What Gets Installed

1. **Operator Subscription** (`base/subscription.yaml`)
   - OpenShift GitOps operator from Red Hat Operators catalog
   - Latest channel with automatic updates
   - Installed in `openshift-operators` namespace

2. **ArgoCD Instance** (`instance/argocd.yaml`)
   - Default ArgoCD instance created in `openshift-gitops` namespace
   - Cluster-wide ArgoCD server for managing applications
   - Integrated with OpenShift authentication

## Structure

```
platform/gitops-operator/
├── kustomization.yaml           # Main kustomization
├── base/
│   ├── kustomization.yaml       # Operator subscription
│   ├── namespace.yaml           # openshift-gitops namespace
│   └── subscription.yaml        # Operator subscription
└── instance/
    ├── kustomization.yaml       # ArgoCD instance
    └── argocd.yaml             # ArgoCD CR
```

## Verification

```bash
# Check operator is installed
oc get subscription openshift-gitops-operator -n openshift-operators

# Check operator is running
oc get csv -n openshift-operators | grep gitops

# Check ArgoCD instance
oc get argocd -n openshift-gitops

# Check ArgoCD pods
oc get pods -n openshift-gitops
```

## Accessing ArgoCD UI

```bash
# Get the route
ARGOCD_URL=$(oc get route openshift-gitops-server \
  -n openshift-gitops -o jsonpath='{.spec.host}')
echo "ArgoCD UI: https://${ARGOCD_URL}"

# Get admin password
ARGOCD_PASSWORD=$(oc get secret openshift-gitops-cluster \
  -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d)
echo "Username: admin"
echo "Password: ${ARGOCD_PASSWORD}"

# Or open directly
open "https://${ARGOCD_URL}"
```

## Using ArgoCD CLI

The ArgoCD instance uses **passthrough TLS termination** to support CLI access.

```bash
# Install CLI (macOS)
brew install argocd

# Login with OpenShift SSO
ARGOCD_SERVER=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')
argocd login $ARGOCD_SERVER --sso --insecure
```

**Optional**: Remove `--insecure` flag by configuring cert-manager certificates:
```bash
# Requires: cert-manager operator with a ClusterIssuer (e.g., Let's Encrypt)
./platform/gitops-operator/instance/generate-certificate.sh
```

## After Installation

Once GitOps is installed, you can deploy all other components using ArgoCD Applications:

```bash
# Deploy RHOAI platform
oc apply -f gitops/platform/rhoai-operator.yaml

# Deploy infrastructure
oc apply -f gitops/infra/gpu-machineset-aws-g5.yaml

# Deploy applications
oc apply -f gitops/apps/anythingllm.yaml

# Monitor all applications
oc get applications -n openshift-gitops
```

## Configuration

### Operator Channel

The operator uses the `latest` channel for automatic updates:

```yaml
# base/subscription.yaml
spec:
  channel: latest
  name: openshift-gitops-operator
```

### ArgoCD Customization

To customize the ArgoCD instance, edit `instance/argocd.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ArgoCD
metadata:
  name: openshift-gitops
  namespace: openshift-gitops
spec:
  # Add customizations here
  server:
    route:
      enabled: true
  rbac:
    defaultPolicy: 'role:readonly'
```

## Troubleshooting

### Operator Not Installing

```bash
# Check subscription status
oc describe subscription openshift-gitops-operator -n openshift-operators

# Check install plan
oc get installplan -n openshift-operators

# Check operator logs
oc logs -n openshift-operators -l name=gitops-operator
```

### ArgoCD Instance Not Created

```bash
# Check if operator is ready
oc get csv -n openshift-operators | grep gitops

# Check ArgoCD CR status
oc describe argocd openshift-gitops -n openshift-gitops

# Check for errors in events
oc get events -n openshift-gitops --sort-by='.lastTimestamp'
```

### Pods Not Starting

```bash
# Check pod status
oc get pods -n openshift-gitops

# Check specific pod logs
oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-server

# Check for image pull issues
oc describe pod -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-server
```

## Uninstallation

To completely remove GitOps:

```bash
# Delete all ArgoCD Applications first
oc delete applications --all -n openshift-gitops

# Delete the GitOps operator installation
oc delete -k platform/gitops-operator/

# Clean up remaining resources (if any)
oc delete namespace openshift-gitops
```

**Warning**: This will remove ArgoCD and stop managing all GitOps-deployed applications. The applications themselves will continue running but won't be managed by ArgoCD anymore.

## Resources

- [OpenShift GitOps Documentation](https://docs.openshift.com/gitops/latest/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Red Hat OpenShift GitOps Release Notes](https://docs.openshift.com/gitops/latest/release_notes/gitops-release-notes.html)

## Next Steps

After installing GitOps:
1. Access the ArgoCD UI
2. Review the [GitOps Application Catalog](../../gitops/README.md)
3. Deploy RHOAI platform: `oc apply -f gitops/platform/rhoai-operator.yaml`
