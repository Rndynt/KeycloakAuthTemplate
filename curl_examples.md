# Keycloak API Examples with cURL

This document provides comprehensive cURL examples for interacting with your Keycloak instance.

## Environment Setup

First, set these environment variables:

```bash
export KEYCLOAK_URL="http://localhost:8080"
export REALM_NAME="project-realm"
export ADMIN_USER="admin"
export ADMIN_PASSWORD="admin"
export CLIENT_ID="project-web"
export BACKEND_CLIENT_ID="project-backend"
export BACKEND_CLIENT_SECRET="changeme-backend-client-secret"
```

## 1. Admin Operations

### Get Admin Access Token

```bash
ADMIN_TOKEN=$(curl -s -X POST \
  "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASSWORD}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | \
  jq -r '.access_token')

echo "Admin token: ${ADMIN_TOKEN}"
```

### Get Realm Information

```bash
curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" | jq '.'
```

### List Users

```bash
curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users" | jq '.'
```

### Create User

```bash
curl -X POST \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "firstName": "Test",
    "lastName": "User",
    "enabled": true,
    "emailVerified": true,
    "credentials": [{
      "type": "password",
      "value": "TestPassword123!",
      "temporary": false
    }]
  }'
```

## 2. Client Credentials Flow (Backend Service)

### Get Service Account Token

```bash
SERVICE_TOKEN=$(curl -s -X POST \
  "${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=${BACKEND_CLIENT_ID}" \
  -d "client_secret=${BACKEND_CLIENT_SECRET}" | \
  jq -r '.access_token')

echo "Service token: ${SERVICE_TOKEN}"
```

### Validate Service Token

```bash
curl -s -X POST \
  "${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/token/introspect" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "token=${SERVICE_TOKEN}" \
  -d "client_id=${BACKEND_CLIENT_ID}" \
  -d "client_secret=${BACKEND_CLIENT_SECRET}" | jq '.'
```

## 3. Authorization Code + PKCE Flow (SPA)

### Generate PKCE Parameters

```bash
# Generate code verifier (random string)
CODE_VERIFIER=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-43)
echo "Code verifier: ${CODE_VERIFIER}"

# Generate code challenge (SHA256 hash of verifier, base64url encoded)
CODE_CHALLENGE=$(echo -n $CODE_VERIFIER | \
  openssl dgst -sha256 -binary | \
  openssl base64 -A | \
  tr -d "=+/" | \
  tr "_-" "/+")
echo "Code challenge: ${CODE_CHALLENGE}"

# Alternative using Node.js
# CODE_VERIFIER=$(node -e "console.log(require('crypto').randomBytes(32).toString('base64url'))")
# CODE_CHALLENGE=$(node -e "console.log(require('crypto').createHash('sha256').update('$CODE_VERIFIER').digest('base64url'))")
```

### Step 1: Authorization URL

```bash
REDIRECT_URI="http://localhost:3000/auth/callback"
STATE=$(openssl rand -hex 16)

AUTH_URL="${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/auth?client_id=${CLIENT_ID}&response_type=code&scope=openid%20profile%20email&redirect_uri=${REDIRECT_URI}&state=${STATE}&code_challenge=${CODE_CHALLENGE}&code_challenge_method=S256"

echo "Visit this URL to authorize:"
echo "${AUTH_URL}"
```

### Step 2: Exchange Authorization Code for Tokens

```bash
# After user authorization, extract the code from callback URL
# AUTHORIZATION_CODE="..." # From callback URL parameter

# Exchange code for tokens
curl -s -X POST \
  "${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "client_id=${CLIENT_ID}" \
  -d "code=${AUTHORIZATION_CODE}" \
  -d "redirect_uri=${REDIRECT_URI}" \
  -d "code_verifier=${CODE_VERIFIER}" | jq '.'
```

## 4. Token Operations

### Introspect Token

```bash
# Using access token
ACCESS_TOKEN="your_access_token_here"

curl -s -X POST \
  "${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/token/introspect" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "token=${ACCESS_TOKEN}" \
  -d "client_id=${CLIENT_ID}" | jq '.'
```

### Refresh Token

```bash
REFRESH_TOKEN="your_refresh_token_here"

curl -s -X POST \
  "${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token" \
  -d "client_id=${CLIENT_ID}" \
  -d "refresh_token=${REFRESH_TOKEN}" | jq '.'
```

### Revoke Token

```bash
curl -s -X POST \
  "${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/revoke" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "token=${ACCESS_TOKEN}" \
  -d "client_id=${CLIENT_ID}"
```

## 5. User Info and Profile

### Get User Info

```bash
curl -s -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/userinfo" | jq '.'
```

### Logout

```bash
curl -s -X POST \
  "${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/logout" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${CLIENT_ID}" \
  -d "refresh_token=${REFRESH_TOKEN}"
```

## 6. OIDC Discovery

### Get OIDC Configuration

```bash
curl -s "${KEYCLOAK_URL}/realms/${REALM_NAME}/.well-known/openid-configuration" | jq '.'
```

### Get JWKS (JSON Web Key Set)

```bash
curl -s "${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/certs" | jq '.'
```

## 7. Testing Scenarios

### Complete PKCE Flow Test

```bash
#!/bin/bash
# Complete PKCE flow test script

# 1. Generate PKCE parameters
CODE_VERIFIER=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-43)
CODE_CHALLENGE=$(echo -n $CODE_VERIFIER | openssl dgst -sha256 -binary | openssl base64 -A | tr -d "=+/" | tr "_-" "/+")

# 2. Print authorization URL
echo "1. Visit this URL:"
echo "${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/auth?client_id=${CLIENT_ID}&response_type=code&scope=openid%20profile%20email&redirect_uri=http://localhost:3000/auth/callback&code_challenge=${CODE_CHALLENGE}&code_challenge_method=S256"

# 3. Wait for user input
read -p "2. Enter the authorization code from callback: " AUTH_CODE

# 4. Exchange for tokens
echo "3. Exchanging code for tokens..."
TOKENS=$(curl -s -X POST \
  "${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "client_id=${CLIENT_ID}" \
  -d "code=${AUTH_CODE}" \
  -d "redirect_uri=http://localhost:3000/auth/callback" \
  -d "code_verifier=${CODE_VERIFIER}")

echo "Tokens received:"
echo $TOKENS | jq '.'

ACCESS_TOKEN=$(echo $TOKENS | jq -r '.access_token')
REFRESH_TOKEN=$(echo $TOKENS | jq -r '.refresh_token')

# 5. Test user info
echo "4. Getting user info..."
curl -s -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/userinfo" | jq '.'

# 6. Test token refresh
echo "5. Testing token refresh..."
curl -s -X POST \
  "${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token" \
  -d "client_id=${CLIENT_ID}" \
  -d "refresh_token=${REFRESH_TOKEN}" | jq '.'
```

## 8. Error Testing

### Invalid Token Test

```bash
curl -s -H "Authorization: Bearer invalid_token" \
  "${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/userinfo"
```

### Expired Token Test

```bash
# This will show introspection of an expired token
curl -s -X POST \
  "${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/token/introspect" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "token=expired_token_here" \
  -d "client_id=${CLIENT_ID}" | jq '.'
```

## 9. Multi-Factor Authentication Testing

### Check Required Actions

```bash
# After creating a user, check required actions
curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users/{user-id}" | jq '.requiredActions'
```

### Trigger MFA Setup

```bash
# Add CONFIGURE_TOTP to required actions
curl -X PUT \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users/{user-id}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "requiredActions": ["CONFIGURE_TOTP"]
  }'
```

## Notes

1. Replace `{user-id}` with actual user UUID from Keycloak
2. For production, use HTTPS URLs
3. Store sensitive values (tokens, secrets) securely
4. Implement proper error handling in your applications
5. Consider token refresh strategies for long-running applications

## Useful Helper Functions

```bash
# Decode JWT token (requires jq)
decode_jwt() {
  local token=$1
  echo $token | cut -d. -f2 | base64 -d 2>/dev/null | jq '.'
}

# Get token expiry
get_token_exp() {
  local token=$1
  decode_jwt $token | jq -r '.exp | todate'
}

# Check if token is expired
is_token_expired() {
  local token=$1
  local exp=$(decode_jwt $token | jq -r '.exp')
  local now=$(date +%s)
  [ $now -gt $exp ]
}
```