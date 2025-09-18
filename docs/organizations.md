# Organizations (Multi-Tenant SaaS) with Keycloak ≥ 26

## Overview

Keycloak 26+ introduces **Organizations** as a first-class feature for multi-tenant SaaS applications. This document explains when to use Organizations vs multi-realm approaches and how tokens surface organizational claims.

## Single-Realm + Organizations vs Multi-Realm

### Single-Realm + Organizations (Recommended for SaaS)

**Use when:**
- Shared user experience across tenants
- Users may belong to multiple organizations
- Centralized user management
- Simplified administration
- Cross-tenant collaboration needed

**Benefits:**
- Single realm to manage
- Users can switch between organizations
- Shared identity pool
- Easier user onboarding
- Built-in organization management UI

**Token Claims:**
```json
{
  "sub": "user-uuid",
  "organization": "acme-corp", 
  "org_id": "org-uuid-123",
  "realm_access": {
    "roles": ["TENANT_MEMBER"]
  }
}
```

### Multi-Realm (Traditional Approach)

**Use when:**
- Complete tenant isolation required
- Different authentication requirements per tenant
- Regulatory compliance needs strict separation
- Custom branding per tenant
- Different user schemas per tenant

**Benefits:**
- Complete data isolation
- Custom configurations per realm
- Independent admin consoles
- Separate user stores

## Setting Up Organizations

### 1. Enable Organizations in Realm

```json
{
  "realm": "your-realm",
  "attributes": {
    "organizationsEnabled": "true"
  }
}
```

### 2. Create Organization Client Scope

The `organization` client scope includes mappers for:
- `organization`: Organization name/slug
- `org_id`: Organization UUID

### 3. Example Organizations

```bash
# Create organizations via Admin API
curl -X POST "http://localhost:8080/admin/realms/event-platform-organizations/orgs" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "music-events",
    "displayName": "Music Events Co",
    "description": "Concert and festival organizer"
  }'
```

## Token Validation

Your application should validate both the standard JWT claims and organization-specific claims:

```javascript
// Express.js middleware example
function validateOrgToken(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  const decoded = jwt.verify(token, publicKey);
  
  // Validate organization claim
  if (!decoded.organization || !decoded.org_id) {
    return res.status(403).json({ error: 'Missing organization claims' });
  }
  
  // Validate user belongs to expected organization
  if (decoded.organization !== req.params.orgSlug) {
    return res.status(403).json({ error: 'Organization mismatch' });
  }
  
  req.user = decoded;
  next();
}
```

## Fine-Grained Admin Permissions (FGAP)

Organizations support delegated administration:

1. Create organization-specific admin roles
2. Grant users organization management permissions
3. Users can manage their organization without realm admin access

## Best Practices

1. **URL Structure**: Use organization in URL paths (`/org/{orgSlug}/...`)
2. **Token Validation**: Always validate organization claims
3. **Data Isolation**: Filter data by organization at application level
4. **User Experience**: Allow users to switch organizations easily
5. **Admin Delegation**: Use FGAP for organization-level administration