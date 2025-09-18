# Authorization Services with Keycloak

## Overview

Keycloak Authorization Services provides fine-grained authorization through policies, permissions, and scopes. This document explains when to use KC Authorization Services vs API-side checks and how to validate permissions using RPT (Requesting Party Tokens).

## When to Use Authorization Services vs API-Side Checks

### Use Keycloak Authorization Services When:

- **Complex policies**: Role-based, attribute-based, time-based, or group-based policies
- **Centralized policy management**: Non-developers need to modify access rules
- **Audit requirements**: Need detailed authorization logs and decisions
- **Dynamic permissions**: Permissions change frequently or based on external data
- **Resource sharing**: Multiple applications need consistent authorization

### Use API-Side Checks When:

- **Simple role-based access**: Basic role or scope checking is sufficient
- **Performance critical**: Microsecond response times required
- **Custom business logic**: Complex business rules that don't map to standard policies
- **Offline scenarios**: Authorization needed without network calls

## Setting Up Authorization Services

### 1. Enable Authorization on Client

```json
{
  "clientId": "event-platform-backend",
  "authorizationServicesEnabled": true,
  "serviceAccountsEnabled": true
}
```

### 2. Define Resources, Scopes, and Policies

Resources represent protected assets:
```json
{
  "name": "event",
  "type": "urn:resource:event",
  "scopes": ["event:read", "event:manage"]
}
```

Policies define access rules:
```json
{
  "name": "policy-tenant-admin",
  "type": "role",
  "config": {
    "roles": ["TENANT_ADMIN"]
  }
}
```

Permissions link resources to policies:
```json
{
  "name": "event-manage",
  "type": "scope",
  "scopes": ["event:manage"],
  "policies": ["policy-tenant-admin"]
}
```

### 3. Request RPT (Requesting Party Token)

```bash
# Get RPT for specific resource and scope
curl -X POST "http://localhost:8080/realms/event-platform-organizations/protocol/openid-connect/token" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:uma-ticket" \
  -d "audience=event-platform-backend" \
  -d "permission=event#event:manage"
```

## Validating Permissions in Your API

### Method 1: RPT Validation

```javascript
// Validate RPT contains required permissions
function validateRPT(req, res, next) {
  const rpt = req.headers['x-rpt-token'];
  const decoded = jwt.verify(rpt, publicKey);
  
  // Check if RPT contains required permission
  const requiredPermission = `${req.params.resource}#${req.method === 'GET' ? 'read' : 'manage'}`;
  const hasPermission = decoded.authorization?.permissions?.some(p => 
    p.rsname === req.params.resource && 
    p.scopes?.includes(req.method === 'GET' ? 'read' : 'manage')
  );
  
  if (!hasPermission) {
    return res.status(403).json({ error: 'Insufficient permissions' });
  }
  
  next();
}
```

### Method 2: Policy Evaluation API

```javascript
// Real-time policy evaluation
async function checkPermission(accessToken, resource, scope) {
  const response = await fetch(`${keycloakUrl}/realms/${realm}/authz/protection/permission`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify([{
      resource_id: resource,
      resource_scopes: [scope]
    }])
  });
  
  return response.ok;
}
```

## Performance Considerations

1. **Cache policies**: Cache policy decisions for short periods
2. **Batch permissions**: Request multiple permissions in single RPT
3. **Lazy loading**: Only check permissions when needed
4. **Token caching**: Cache and reuse RPTs until expiry

## Example: Event Management Permissions

```bash
# Admin can manage all events
curl -X POST "$KC_BASE/realms/$REALM/protocol/openid-connect/token" \
  -H "Authorization: Bearer $ADMIN_ACCESS_TOKEN" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:uma-ticket" \
  -d "audience=event-platform-backend" \
  -d "permission=event#event:manage"

# Member can only read events
curl -X POST "$KC_BASE/realms/$REALM/protocol/openid-connect/token" \
  -H "Authorization: Bearer $MEMBER_ACCESS_TOKEN" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:uma-ticket" \
  -d "audience=event-platform-backend" \
  -d "permission=event#event:read"
```

## Best Practices

1. **Resource Modeling**: Model resources at appropriate granularity
2. **Policy Composition**: Combine simple policies for complex rules
3. **Testing**: Test all permission combinations thoroughly
4. **Monitoring**: Monitor authorization performance and decisions
5. **Documentation**: Keep resource and policy documentation updated