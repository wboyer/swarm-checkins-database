#!/usr/bin/env bash
# One-time bootstrap script for a new Azure subscription.
# Run this locally with the az CLI authenticated as an account owner.
#
# Usage: ./infra/setup.sh

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
RESOURCE_GROUP="swarm-checkins"
LOCATION="southcentralus"
SP_NAME="swarm-checkins-deploy"
# ─────────────────────────────────────────────────────────────────────────────

echo "==> Using subscription: $(az account show --query '[name, id]' -o tsv | tr '\t' ' ')"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

echo ""
echo "==> Creating resource group '$RESOURCE_GROUP' in $LOCATION..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

echo ""
echo "==> Registering resource providers..."
az provider register --namespace Microsoft.DBforPostgreSQL --wait
az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.ContainerRegistry --wait
az provider register --namespace Microsoft.OperationalInsights --wait

echo ""
echo "==> Creating service principal '$SP_NAME'..."
SP=$(az ad sp create-for-rbac \
  --name "$SP_NAME" \
  --role Contributor \
  --scopes "/subscriptions/$SUBSCRIPTION_ID")

CLIENT_ID=$(echo "$SP" | python3 -c "import sys,json; print(json.load(sys.stdin)['appId'])")
CLIENT_SECRET=$(echo "$SP" | python3 -c "import sys,json; print(json.load(sys.stdin)['password'])")
TENANT_ID=$(echo "$SP" | python3 -c "import sys,json; print(json.load(sys.stdin)['tenant'])")

echo ""
echo "==> Granting Contributor at subscription scope (needed for provider registration)..."
az role assignment create \
  --assignee "$CLIENT_ID" \
  --role Contributor \
  --scope "/subscriptions/$SUBSCRIPTION_ID" \
  --output none

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Add these as GitHub Actions secrets (Settings → Secrets → Actions):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  AZURE_CLIENT_ID        = $CLIENT_ID"
echo "  AZURE_CLIENT_SECRET    = $CLIENT_SECRET"
echo "  AZURE_TENANT_ID        = $TENANT_ID"
echo "  AZURE_SUBSCRIPTION_ID  = $SUBSCRIPTION_ID"
echo ""
echo "And this as a GitHub Actions variable:"
echo ""
echo "  RESOURCE_GROUP         = $RESOURCE_GROUP"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Done. Push to main to trigger the first deployment."
