#!/usr/bin/env bash
# One-time setup, run by you (Azure Cloud Shell works well):
#   1. registers the Azure resource providers the project needs
#   2. creates the Terraform remote-state storage account
#   3. creates an Entra app registration trusted by GitHub Actions through OIDC (no secrets)
#   4. grants that identity the roles Terraform needs
#   5. writes the IDs into GitHub repository variables (if the gh CLI is logged in)
#
#   GITHUB_REPO=owner/repo ./bootstrap/bootstrap.sh
set -euo pipefail

: "${GITHUB_REPO:?Set GITHUB_REPO=owner/repo}"
LOCATION="${LOCATION:-centralindia}"
PROJECT="${PROJECT:-aksgitops}"
APP_NAME="sp-${PROJECT}-github-oidc"
TFSTATE_RG="rg-${PROJECT}-tfstate"

SUB_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"
echo "Subscription: $SUB_ID  Tenant: $TENANT_ID  Region: $LOCATION"

echo "== 1/5 Registering resource providers"
PROVIDERS=(
  Microsoft.Compute Microsoft.ContainerRegistry Microsoft.ContainerService
  Microsoft.Insights Microsoft.KeyVault Microsoft.ManagedIdentity
  Microsoft.Network Microsoft.OperationalInsights Microsoft.OperationsManagement
  Microsoft.PolicyInsights Microsoft.Storage
)
for rp in "${PROVIDERS[@]}"; do az provider register --namespace "$rp" >/dev/null; done
for rp in "${PROVIDERS[@]}"; do
  until [ "$(az provider show --namespace "$rp" --query registrationState -o tsv)" = "Registered" ]; do
    echo "   waiting for $rp ..."; sleep 10
  done
done

echo "== 2/5 Terraform state storage"
az group create -n "$TFSTATE_RG" -l "$LOCATION" -o none
TFSTATE_SA="$(az storage account list -g "$TFSTATE_RG" --query "[?starts_with(name,'sttfstate')].name | [0]" -o tsv)"
if [ -z "$TFSTATE_SA" ]; then
  TFSTATE_SA="sttfstate$(openssl rand -hex 4)"
  az storage account create -n "$TFSTATE_SA" -g "$TFSTATE_RG" -l "$LOCATION" \
    --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 \
    --allow-blob-public-access false -o none
fi
az storage account blob-service-properties update --account-name "$TFSTATE_SA" -g "$TFSTATE_RG" \
  --enable-versioning true -o none
az storage container create --account-name "$TFSTATE_SA" --name tfstate --auth-mode key -o none

echo "== 3/5 Entra app registration + GitHub OIDC federation"
APP_ID="$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)"
[ -n "$APP_ID" ] || APP_ID="$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)"
SP_OBJ_ID="$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" -o tsv)"
[ -n "$SP_OBJ_ID" ] || SP_OBJ_ID="$(az ad sp create --id "$APP_ID" --query id -o tsv)"

add_federated_credential() {
  local name="$1" subject="$2"
  if az ad app federated-credential list --id "$APP_ID" --query "[?name=='$name'].name" -o tsv | grep -q .; then
    echo "   $name exists"
  else
    az ad app federated-credential create --id "$APP_ID" --parameters "{
      \"name\": \"$name\",
      \"issuer\": \"https://token.actions.githubusercontent.com\",
      \"subject\": \"$subject\",
      \"audiences\": [\"api://AzureADTokenExchange\"]
    }" -o none
    echo "   $name created"
  fi
}
add_federated_credential github-pull-request "repo:${GITHUB_REPO}:pull_request"
add_federated_credential github-main         "repo:${GITHUB_REPO}:ref:refs/heads/main"
add_federated_credential github-env-dev      "repo:${GITHUB_REPO}:environment:dev"
add_federated_credential github-env-prod     "repo:${GITHUB_REPO}:environment:prod"

echo "== 4/5 Role assignments"
assign_role() {
  local role="$1" scope="$2"
  if [ -n "$(az role assignment list --assignee "$SP_OBJ_ID" --role "$role" --scope "$scope" --query "[0].id" -o tsv)" ]; then
    echo "   $role already assigned"
  else
    az role assignment create --assignee-object-id "$SP_OBJ_ID" --assignee-principal-type ServicePrincipal \
      --role "$role" --scope "$scope" -o none
    echo "   $role assigned"
  fi
}
SUB_SCOPE="/subscriptions/${SUB_ID}"
SA_SCOPE="$(az storage account show -n "$TFSTATE_SA" -g "$TFSTATE_RG" --query id -o tsv)"
# Broad on purpose for a single-subscription lab. Scope these down in a real organisation.
assign_role "Contributor"                   "$SUB_SCOPE"
assign_role "User Access Administrator"     "$SUB_SCOPE"
assign_role "Resource Policy Contributor"   "$SUB_SCOPE"
assign_role "Storage Blob Data Contributor" "$SA_SCOPE"

echo "== 5/5 GitHub repository variables"
declare -A VARS=(
  [AZURE_CLIENT_ID]="$APP_ID"
  [AZURE_TENANT_ID]="$TENANT_ID"
  [AZURE_SUBSCRIPTION_ID]="$SUB_ID"
  [TFSTATE_RG]="$TFSTATE_RG"
  [TFSTATE_SA]="$TFSTATE_SA"
)
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  for k in "${!VARS[@]}"; do gh variable set "$k" --body "${VARS[$k]}" --repo "$GITHUB_REPO"; done
  echo "   variables written with gh"
else
  echo "   gh CLI not available or not logged in. Add these under Settings > Secrets and variables > Actions > Variables:"
  for k in "${!VARS[@]}"; do echo "   $k = ${VARS[$k]}"; done
fi

echo
echo "Done. Optional: add ALERT_EMAIL as a repository variable to receive alert emails."
