#!/usr/bin/env bash
set -euo pipefail

# Import Organizations realm with all clients and test data
# Usage: ./scripts/import-organizations-realm.sh

: "${KEYCLOAK_URL:=http://localhost:8080}"
: "${ADMIN_USER:=admin}"
: "${ADMIN_PASS:=admin}"
: "${REALM_FILE:=realm/realm-organizations-complete.json}"

echo "🔄 Importing Organizations realm from ${REALM_FILE}..."

# Wait for Keycloak to be ready
echo "⏳ Waiting for Keycloak to be ready..."
timeout 300 bash -c 'until curl -sf ${KEYCLOAK_URL}/health/ready; do sleep 2; done'

# Get admin token
echo "🔑 Getting admin token..."
ADMIN_TOKEN=$(curl -sS -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASS}" | jq -r '.access_token')

if [[ "${ADMIN_TOKEN}" == "null" || -z "${ADMIN_TOKEN}" ]]; then
  echo "❌ Failed to get admin token"
  exit 1
fi

# Check if realm already exists
REALM_EXISTS=$(curl -sS -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${KEYCLOAK_URL}/admin/realms/event-platform-organizations" \
  -w "%{http_code}" -o /dev/null)

if [[ "${REALM_EXISTS}" == "200" ]]; then
  echo "⚠️  Realm already exists. Updating..."
  # Delete existing realm
  curl -sS -X DELETE -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "${KEYCLOAK_URL}/admin/realms/event-platform-organizations"
  echo "🗑️  Deleted existing realm"
fi

# Import realm
echo "📥 Importing realm..."
curl -sS -X POST "${KEYCLOAK_URL}/admin/realms" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @"${REALM_FILE}"

# Verify realm was created
echo "✅ Verifying realm creation..."
REALM_CHECK=$(curl -sS -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${KEYCLOAK_URL}/admin/realms/event-platform-organizations" \
  -w "%{http_code}" -o /dev/null)

if [[ "${REALM_CHECK}" != "200" ]]; then
  echo "❌ Failed to verify realm creation"
  exit 1
fi

echo "✅ Organizations realm imported successfully!"
echo ""
echo "🔗 Access points:"
echo "  - Admin Console: ${KEYCLOAK_URL}/admin/master/console/#/event-platform-organizations"
echo "  - Account Console: ${KEYCLOAK_URL}/realms/event-platform-organizations/account/"
echo ""
echo "👤 Test users created:"
echo "  - admin-music / admin-music-password (TENANT_ADMIN for music-events)"
echo "  - member-workshop / member-workshop-password (TENANT_MEMBER for workshop-events)"  
echo "  - owner-wedding / owner-wedding-password (TENANT_ADMIN for wedding-events)"
echo ""
echo "🏢 Organizations:"
echo "  - music-events (org-music-123)"
echo "  - workshop-events (org-workshop-456)"
echo "  - wedding-events (org-wedding-789)"
echo ""
echo "📱 Clients configured:"
echo "  - event-platform-web (SPA with PKCE)"
echo "  - event-platform-backend (Service account with Authorization Services)"
echo "  - device-bootstrap (Device flow for IoT)"
echo "  - api-a (Token exchange source)"
echo "  - api-b (Token exchange target)"