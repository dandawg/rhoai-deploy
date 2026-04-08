#!/bin/bash
# bootstrap.sh - Smart GitOps installer for RHOAI Deploy
set -e

echo "🔍 Checking for OpenShift GitOps..."

# Check if GitOps is already installed
if oc get deployment openshift-gitops-server -n openshift-gitops &>/dev/null; then
  echo "✅ OpenShift GitOps is already installed. Skipping operator installation."
else
  echo "📦 Installing OpenShift GitOps Operator..."
  oc apply -k bootstrap/gitops-operator/base/

  echo "⏳ Waiting for GitOps Operator to be ready..."
  oc wait --for=condition=Available \
    deployment/openshift-gitops-operator-controller-manager \
    -n openshift-operators --timeout=300s

  echo "🚀 Creating ArgoCD instance..."
  oc apply -k bootstrap/gitops-operator/instance/

  echo "⏳ Waiting for ArgoCD to be ready..."
  oc wait --for=condition=Ready \
    pod -l app.kubernetes.io/name=openshift-gitops-server \
    -n openshift-gitops --timeout=300s
fi

# Always ensure the cluster-admin ClusterRoleBinding exists.
# This is required even when GitOps was pre-installed by another repo,
# because without it ArgoCD cannot patch resources in system namespaces
# (openshift-config-managed, openshift-ingress, etc.).
echo "🔒 Ensuring ArgoCD cluster-admin ClusterRoleBinding..."
oc apply -f bootstrap/gitops-operator/instance/clusterrolebinding.yaml

echo ""
echo "✅ GitOps installation complete!"
echo ""
echo "ArgoCD Details:"
echo "  URL: https://$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')"
echo "  Username: admin"
echo "  Password: $(oc get secret openshift-gitops-cluster -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d)"
echo ""
