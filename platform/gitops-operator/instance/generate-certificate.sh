#!/bin/bash
# Configure cert-manager Certificate for ArgoCD server
# Run this after deploying ArgoCD instance to enable CLI login without --insecure flag

set -e

echo "🔧 Configuring cert-manager certificate for ArgoCD..."
echo ""

# Check if cert-manager is available
if ! oc get crd certificates.cert-manager.io &>/dev/null; then
    echo "❌ cert-manager CRD not found. Install cert-manager first."
    echo "   ArgoCD CLI will require --insecure flag: argocd login \$SERVER --sso --insecure"
    exit 1
fi

# Get available ClusterIssuers
ISSUERS=$(oc get clusterissuer -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -z "$ISSUERS" ]; then
    echo "❌ No ClusterIssuers found. Configure a ClusterIssuer (e.g., Let's Encrypt) first."
    exit 1
fi

# Use first available ClusterIssuer
ISSUER_ARRAY=($ISSUERS)
ISSUER_NAME="${1:-${ISSUER_ARRAY[0]}}"

echo "📋 Available ClusterIssuers: $ISSUERS"
echo "✅ Using ClusterIssuer: $ISSUER_NAME"
echo ""

# Get route hostname (wait for route to exist)
echo "⏳ Waiting for ArgoCD route to be created..."
for i in {1..30}; do
    ROUTE_HOST=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
    if [ -n "$ROUTE_HOST" ]; then
        break
    fi
    sleep 2
done

if [ -z "$ROUTE_HOST" ]; then
    echo "❌ ArgoCD route not found. Deploy ArgoCD instance first:"
    echo "   oc apply -k platform/gitops-operator/instance/"
    exit 1
fi

echo "✅ ArgoCD Route: $ROUTE_HOST"
echo ""

# Create and apply certificate
echo "📝 Creating Certificate resource..."
cat <<EOF | oc apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: argocd-server-tls
  namespace: openshift-gitops
spec:
  secretName: argocd-server-tls
  issuerRef:
    name: ${ISSUER_NAME}
    kind: ClusterIssuer
  dnsNames:
    - ${ROUTE_HOST}
  usages:
    - digital signature
    - key encipherment
    - server auth
EOF

echo ""
echo "⏳ Waiting for certificate to be ready (this may take a minute)..."
if oc wait --for=condition=Ready certificate/argocd-server-tls -n openshift-gitops --timeout=300s; then
    echo "✅ Certificate issued successfully"
    echo ""
    echo "🔄 Restarting ArgoCD server to pick up new certificate..."
    oc rollout restart deployment/openshift-gitops-server -n openshift-gitops
    oc rollout status deployment/openshift-gitops-server -n openshift-gitops --timeout=300s
    echo ""
    echo "✅ Done! You can now login without --insecure:"
    echo "   argocd login ${ROUTE_HOST} --sso"
else
    echo "❌ Certificate issuance timed out. Check cert-manager logs:"
    echo "   oc get certificate argocd-server-tls -n openshift-gitops -o yaml"
    echo "   oc logs -n cert-manager -l app=cert-manager"
    exit 1
fi
