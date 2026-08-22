#!/usr/bin/env bash
# Deploy cms-oauth-kit Azure Function (Bicep + zip) into rg-ssd-global.
#
# Usage:
#   ./scripts/deploy.sh --oauth-client-id '<id>'
#   ./scripts/deploy.sh --oauth-client-id '<id>' --skip-infra
#   ./scripts/deploy.sh --oauth-client-id '<id>' --skip-zip
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-ssd-global}"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-01c0bb8b-3770-4765-979a-cb13ae7e3dd2}"
FUNCTION_APP_NAME="${AZURE_FUNCTIONAPP_NAME:-ssd-cmsoauth-func-prod-ae}"
OAUTH_CLIENT_ID="${DECAP_OAUTH_CLIENT_ID:-}"
SKIP_INFRA=0
SKIP_ZIP=0
SKU="${AZURE_FUNCTION_SKU:-Y1}"

usage() {
  sed -n '2,8p' "$0" | sed 's/^# \?//'
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --oauth-client-id)
      OAUTH_CLIENT_ID="${2:-}"
      shift 2
      ;;
    --resource-group)
      RESOURCE_GROUP="${2:-}"
      shift 2
      ;;
    --function-app-name)
      FUNCTION_APP_NAME="${2:-}"
      shift 2
      ;;
    --sku)
      SKU="${2:-}"
      shift 2
      ;;
    --skip-infra)
      SKIP_INFRA=1
      shift
      ;;
    --skip-zip)
      SKIP_ZIP=1
      shift
      ;;
    -h | --help)
      usage
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      ;;
  esac
done

if [[ -z "${OAUTH_CLIENT_ID}" ]]; then
  echo "Missing --oauth-client-id (or DECAP_OAUTH_CLIENT_ID)." >&2
  exit 1
fi

az account set --subscription "${SUBSCRIPTION_ID}"

if [[ "${SKIP_INFRA}" -eq 0 ]]; then
  echo "Deploying infra/main.bicep to ${RESOURCE_GROUP} (sku=${SKU}) ..."
  az deployment group create \
    --resource-group "${RESOURCE_GROUP}" \
    --template-file "${ROOT}/infra/main.bicep" \
    --parameters oauthClientId="${OAUTH_CLIENT_ID}" sku="${SKU}" \
    --name "cms-oauth-$(date -u +%Y%m%d%H%M%S)"
fi

if [[ "${SKIP_ZIP}" -eq 1 ]]; then
  echo "Skipping zip deploy."
  exit 0
fi

echo "Building Function ..."
(
  cd "${ROOT}"
  pnpm install --frozen-lockfile
  pnpm run build
)

STAGE="$(mktemp -d)"
cleanup() { rm -rf "${STAGE}"; }
trap cleanup EXIT

cp "${ROOT}/host.json" "${STAGE}/"
# Zip cannot resolve workspace-only fields; keep runtime name/main/deps.
node -e "
  const fs = require('fs');
  const pkg = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
  const out = {
    name: pkg.name,
    version: pkg.version,
    private: true,
    main: pkg.main,
    dependencies: pkg.dependencies || {},
  };
  fs.writeFileSync(process.argv[2], JSON.stringify(out, null, 2));
" "${ROOT}/package.json" "${STAGE}/package.json"
cp -r "${ROOT}/dist" "${STAGE}/dist"

(
  cd "${STAGE}"
  npm install --omit=dev --package-lock=false
)

ZIP="${ROOT}/.deploy/cms-oauth-kit.zip"
mkdir -p "${ROOT}/.deploy"
rm -f "${ZIP}"
(
  cd "${STAGE}"
  zip -r "${ZIP}" .
)

echo "Zip deploying to ${FUNCTION_APP_NAME} ..."
az functionapp deployment source config-zip \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${FUNCTION_APP_NAME}" \
  --src "${ZIP}" \
  --timeout 600

echo "Done."
echo "Default host: https://${FUNCTION_APP_NAME}.azurewebsites.net/health"
echo "Public host:  https://auth.singletonsd.com/health (after DNS + ./scripts/bind-custom-domain.sh)"
