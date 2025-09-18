# Client Registration API

## Overview

The Client Registration API allows automated provisioning of OpenID Connect clients without manual admin console configuration. This is essential for SaaS platforms that need to create clients dynamically for new tenants or applications.

## Security Model

### Initial Access Tokens (IAT)

Initial Access Tokens provide time-limited access to register new clients:

```bash
# Create IAT (requires admin access)
curl -X POST "http://localhost:8080/admin/realms/event-platform-organizations/clients-initial-access" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "count": 5,
    "expiration": 300
  }'
```

### Registration Access Tokens (RAT)

After registration, each client receives a RAT for managing its own configuration:

```json
{
  "client_id": "my-new-client",
  "registration_access_token": "eyJhbGciOiJSUzI1NiIs...",
  "registration_client_uri": "http://localhost:8080/realms/event-platform-organizations/clients-registrations/default/my-new-client"
}
```

## Client Types

### SPA (Single Page Application)

```bash
./scripts/register-client.sh spa my-spa http://localhost:3000 "http://localhost:3000/*"
```

Creates:
- Public client (no client secret)
- PKCE enabled (S256)
- Authorization Code flow
- Proper CORS configuration

### Backend API

```bash
./scripts/register-client.sh backend my-api
```

Creates:
- Confidential client (with secret)
- Service account enabled
- Client credentials flow
- No redirect URIs

### IoT Device

```bash
./scripts/register-client.sh device my-iot-device
```

Creates:
- Public client
- Device authorization grant enabled
- No standard flows
- Suitable for IoT/smart devices

## Script Usage

The `register-client.sh` script provides automated client registration:

```bash
# Set environment variables
export KEYCLOAK_BASE="http://localhost:8080"
export REALM="event-platform-organizations"
export ADMIN_USER="admin"
export ADMIN_PASS="admin"

# Register different client types
./scripts/register-client.sh spa myapp-web http://localhost:3000 "http://localhost:3000/*"
./scripts/register-client.sh backend myapp-api
./scripts/register-client.sh device myapp-sensor
```

## Security Considerations

### IAT Management

1. **Short expiration**: Keep IAT lifetime minimal (5-15 minutes)
2. **Limited count**: Only create what you need immediately
3. **Secure storage**: Store IATs securely, never in version control
4. **Audit logging**: Monitor IAT creation and usage

### Client Validation

Always validate registration requests:

```javascript
// Example validation middleware
function validateClientRegistration(req, res, next) {
  const { clientId, redirectUris } = req.body;
  
  // Validate client ID format
  if (!/^[a-zA-Z0-9-_]+$/.test(clientId)) {
    return res.status(400).json({ error: 'Invalid client ID format' });
  }
  
  // Validate redirect URIs
  for (const uri of redirectUris || []) {
    try {
      const url = new URL(uri);
      if (!['http:', 'https:'].includes(url.protocol)) {
        return res.status(400).json({ error: 'Invalid redirect URI protocol' });
      }
    } catch (e) {
      return res.status(400).json({ error: 'Invalid redirect URI format' });
    }
  }
  
  next();
}
```

## Idempotent Operations

The registration script handles idempotent re-runs:

1. **Check existing**: Query for existing client first
2. **Update vs create**: Update configuration if client exists
3. **Error handling**: Handle registration conflicts gracefully

```bash
# Safe to run multiple times
./scripts/register-client.sh spa my-spa http://localhost:3000 "http://localhost:3000/*"
./scripts/register-client.sh spa my-spa http://localhost:3000 "http://localhost:3000/*"  # No error
```

## Client Configuration Templates

### Production SPA Template

```json
{
  "clientId": "prod-spa",
  "publicClient": true,
  "standardFlowEnabled": true,
  "attributes": {
    "pkce.code.challenge.method": "S256",
    "post.logout.redirect.uris": "https://myapp.com/logout",
    "backchannel.logout.session.required": "true",
    "backchannel.logout.revoke.offline.tokens": "true"
  },
  "redirectUris": ["https://myapp.com/*"],
  "webOrigins": ["https://myapp.com"],
  "defaultClientScopes": ["openid", "profile", "email", "organization"]
}
```

### Production API Template

```json
{
  "clientId": "prod-api",
  "publicClient": false,
  "serviceAccountsEnabled": true,
  "attributes": {
    "access.token.lifespan": "300",
    "client.secret.creation.time": "1640995200",
    "oauth2.device.authorization.grant.enabled": "false"
  },
  "defaultClientScopes": ["organization"]
}
```

## Best Practices

1. **Principle of least privilege**: Only enable needed flows and scopes
2. **Environment separation**: Use different clients for dev/staging/prod
3. **Secret rotation**: Regularly rotate client secrets
4. **Monitoring**: Monitor client usage and registration patterns
5. **Documentation**: Document all registered clients and their purposes
6. **Cleanup**: Remove unused clients regularly