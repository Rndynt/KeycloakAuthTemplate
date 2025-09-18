#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   KEYCLOAK_BASE="http://localhost:8080" REALM="event-platform-organizations" \
#   ADMIN_USER="admin" ADMIN_PASS="admin" \
#   ./scripts/register-client.sh spa my-spa http://localhost:3000 http://localhost:3000/*

TYPE="${1:-spa}"          # spa|backend|device
CLIENT_ID="${2:-my-spa}"
BASE_URL="${3:-http://localhost:3000}"
REDIRECT_URI="${4:-http://localhost:3000/*}"

: "${KEYCLOAK_BASE:?KEYCLOAK_BASE required}"
: "${REALM:?REALM required}"
: "${ADMIN_USER:?ADMIN_USER required}"
: "${ADMIN_PASS:?ADMIN_PASS required}"

# Get admin access token
ADMIN_TOKEN="$(curl -sS -X POST "${KEYCLOAK_BASE}/realms/master/protocol/openid-connect/token" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASS}" | jq -r '.access_token')"

# Create Initial Access Token
IAT="$(curl -sS -X POST "${KEYCLOAK_BASE}/admin/realms/${REALM}/clients-initial-access" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"count":1,"expiration":300}' | jq -r '.token')"

REG_URL="${KEYCLOAK_BASE}/realms/${REALM}/clients-registrations/default"
COMMON='{"protocol":"openid-connect"}'

if [[ "${TYPE}" == "spa" ]]; then
  PAYLOAD=$(jq -n --arg cid "${CLIENT_ID}" --arg burl "${BASE_URL}" --arg ruri "${REDIRECT_URI}" '
    {
      "clientId": $cid,
      "publicClient": true,
      "standardFlowEnabled": true,
      "attributes": {"pkce.code.challenge.method":"S256"},
      "redirectUris": [$ruri],
      "webOrigins": ["+"]
    }')
elif [[ "${TYPE}" == "backend" ]]; then
  PAYLOAD=$(jq -n --arg cid "${CLIENT_ID}" '
    {
      "clientId": $cid,
      "publicClient": false,
      "serviceAccountsEnabled": true,
      "standardFlowEnabled": false,
      "directAccessGrantsEnabled": false
    }')
elif [[ "${TYPE}" == "device" ]]; then
  PAYLOAD=$(jq -n --arg cid "${CLIENT_ID}" '
    {
      "clientId": $cid,
      "publicClient": true,
      "standardFlowEnabled": false,
      "directAccessGrantsEnabled": false,
      "attributes": {"oauth2.device.authorization.grant.enabled":"true"}
    }')
else
  echo "Unknown TYPE: ${TYPE}" >&2; exit 1
fi

echo "Registering client ${CLIENT_ID} (${TYPE}) ..."
curl -sS -X POST "${REG_URL}" \
  -H "Authorization: Bearer ${IAT}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --argjson x "${PAYLOAD}" --argjson c "${COMMON}" '$x + $c')" | jq '.'
echo "Done."