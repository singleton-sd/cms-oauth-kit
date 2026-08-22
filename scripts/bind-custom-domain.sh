#!/usr/bin/env bash
# Bind auth.singletonsd.com to the Function App and attach a managed cert.
#
# Prerequisites:
#   1. Function already deployed (./scripts/deploy.sh).
#   2. Route53 CNAME: auth.singletonsd.com -> <function>.azurewebsites.net
#      Optional TXT: asuid.auth.singletonsd.com = <domain verification id>
#
# Usage:
#   ./scripts/bind-custom-domain.sh
#   ./scripts/bind-custom-domain.sh --print-dns
set -euo pipefail

RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-ssd-global}"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-01c0bb8b-3770-4765-979a-cb13ae7e3dd2}"
FUNCTION_APP_NAME="${AZURE_FUNCTIONAPP_NAME:-ssd-cmsoauth-func-prod-ae}"
HOSTNAME="${CUSTOM_HOSTNAME:-auth.singletonsd.com}"
PRINT_DNS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --print-dns)
      PRINT_DNS=1
      shift
      ;;
    --hostname)
      HOSTNAME="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

az account set --subscription "${SUBSCRIPTION_ID}"

DEFAULT_HOST="$(az functionapp show -g "${RESOURCE_GROUP}" -n "${FUNCTION_APP_NAME}" --query defaultHostName -o tsv)"
VERIFICATION_ID="$(az functionapp show -g "${RESOURCE_GROUP}" -n "${FUNCTION_APP_NAME}" --query customDomainVerificationId -o tsv)"

echo "Function default host: ${DEFAULT_HOST}"
echo "DNS required before bind:"
echo "  CNAME  ${HOSTNAME}              -> ${DEFAULT_HOST}"
echo "  TXT    asuid.${HOSTNAME}        -> ${VERIFICATION_ID}"

if [[ "${PRINT_DNS}" -eq 1 ]]; then
  exit 0
fi

echo "Adding hostname ${HOSTNAME} ..."
az webapp config hostname add \
  --webapp-name "${FUNCTION_APP_NAME}" \
  -g "${RESOURCE_GROUP}" \
  --hostname "${HOSTNAME}"

echo "Creating managed certificate (can take several minutes) ..."
az webapp config ssl create \
  -g "${RESOURCE_GROUP}" \
  -n "${FUNCTION_APP_NAME}" \
  --hostname "${HOSTNAME}" \
  -o none || true

THUMB=""
for i in $(seq 1 24); do
  THUMB="$(az webapp config ssl show -g "${RESOURCE_GROUP}" --certificate-name "${HOSTNAME}" --query "thumbprint" -o tsv 2>/dev/null || true)"
  if [[ -z "${THUMB}" || "${THUMB}" == "None" ]]; then
    THUMB="$(az webapp config ssl show -g "${RESOURCE_GROUP}" --certificate-name "${HOSTNAME}" --query "properties.thumbprint" -o tsv 2>/dev/null || true)"
  fi
  if [[ -n "${THUMB}" && "${THUMB}" != "None" ]]; then
    break
  fi
  echo "  waiting for managed cert (attempt ${i}/24)..."
  sleep 15
done

if [[ -z "${THUMB}" ]]; then
  echo "Managed cert for ${HOSTNAME} not ready. Re-run after DNS/cert issuance." >&2
  exit 1
fi

echo "Binding SNI cert ${THUMB} ..."
az webapp config ssl bind \
  -g "${RESOURCE_GROUP}" \
  -n "${FUNCTION_APP_NAME}" \
  --certificate-thumbprint "${THUMB}" \
  --ssl-type SNI

echo "Done. Smoke: https://${HOSTNAME}/health"
