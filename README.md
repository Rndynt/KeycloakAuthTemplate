# 🔐 Keycloak Enterprise Auth Template

**Enterprise-Grade Multi-Tenant Authentication Platform** - Production-Ready Keycloak 26.2+ Template

A comprehensive Keycloak authentication platform template featuring Organizations support, IoT device authentication, token exchange, authorization services, and production-ready configurations. Built for SaaS applications requiring multi-tenant isolation, device management, and enterprise security.

## ✨ Enterprise Features

### 🏢 Multi-Tenant SaaS
- **Organizations Support**: Native Keycloak 26+ Organizations for tenant isolation
- **Organization Claims**: Automatic tenant context in JWT tokens
- **Delegated Administration**: Fine-Grained Admin Permissions (FGAP) examples
- **Tenant Isolation**: Complete separation of users, roles, and data

### 📱 IoT Device Authentication
- **Device Authorization Grant**: RFC 8628 compliant device pairing flow
- **Device Verification Server**: Web-based device token validation
- **Headless Device Support**: Perfect for IoT sensors, smart devices
- **Complete Examples**: cURL walkthrough and integration guides

### 🔄 Token Exchange & Service Integration
- **Standard Token Exchange**: Service-to-service authentication
- **Audience Swapping**: Secure API-to-API communication
- **Client Registration API**: Automated client provisioning
- **Multiple Signature Algorithms**: RS256, ES256, EdDSA support

### 🛡️ Authorization Services
- **Resource-Based Permissions**: Fine-grained access control
- **Requesting Party Tokens (RPT)**: UMA 2.0 authorization
- **Policy Engine**: Rule-based permission evaluation
- **Scope Management**: Granular operation permissions

### 🚀 Production Infrastructure
- **High Availability**: Multi-site deployment configurations
- **Kubernetes Ready**: Production Helm charts with secrets management
- **Monitoring & Alerting**: Prometheus metrics and Grafana dashboards
- **Backup & Recovery**: Automated procedures and disaster recovery
- **Security Hardening**: Client policies, PKCE enforcement, algorithm allowlisting

## 🎯 Quick Start

### 1. Clone and Configure

```bash
# Clone this template
git clone [your-repo] my-auth-system
cd my-auth-system

# Copy environment template
cp .env.example .env

# Edit credentials (IMPORTANT: Change default passwords!)
nano .env
```

### 2. Start Enterprise Services

```bash
# Start Keycloak 26.2+ with Organizations, PostgreSQL, and MailHog
docker-compose up -d

# Wait for services to be ready (2-3 minutes)
docker-compose logs -f keycloak
```

### 3. Import Organizations Realm

```bash
# Import complete Organizations realm with test data
./scripts/import-organizations-realm.sh

# Test all features end-to-end
./scripts/test-end-to-end.sh

# Access Keycloak Admin Console
open http://localhost:8080/admin
```

**That's it!** 🎉 Your authentication system is ready.

## 📋 Default Configuration

### Token Lifetimes
- **Access Token**: 10 minutes
- **Refresh Token**: 7 days (with rotation)
- **SSO Session Idle**: 30 minutes

### Enterprise Clients
- **`event-platform-web`**: Public SPA client (Authorization Code + PKCE)
- **`event-platform-backend`**: Confidential API client with Authorization Services
- **`device-bootstrap`**: IoT device client (Device Authorization Grant)
- **`api-a` / `api-b`**: Token exchange demonstration clients
- **Auto-provisioning**: Client Registration API scripts

### Enterprise Roles & Organizations
- **`TENANT_ADMIN`**: Full administrative access within organization
- **`TENANT_MEMBER`**: Standard user access within organization
- **`owner`**: Cross-organization ownership (super admin)
- **`operator`**: Operational access across resources
- **`admin`**: Administrative access (MFA required)

### Example Organizations
- **music-events** (org-music-123): Event management for music industry
- **workshop-events** (org-workshop-456): Corporate workshop management
- **wedding-events** (org-wedding-789): Wedding planning services

### Security Features
- Password policy: 8+ chars, mixed case, numbers
- MFA: TOTP required for admin role
- Brute force protection enabled
- Email verification supported

## 🚀 Integration Examples

### Multi-Tenant SPA Integration

```javascript
// Multi-tenant configuration
const keycloakConfig = {
  url: 'http://localhost:8080',
  realm: 'event-platform-organizations',
  clientId: 'event-platform-web'
};

// Authorization URL with organization scope
const authUrl = `${keycloakConfig.url}/realms/${keycloakConfig.realm}/protocol/openid-connect/auth?client_id=${keycloakConfig.clientId}&response_type=code&scope=openid organization profile email&redirect_uri=${redirectUri}&code_challenge=${codeChallenge}&code_challenge_method=S256`;

// Token will include organization claims:
// {
//   "organization": "music-events",
//   "org_id": "org-music-123",
//   "sub": "user-uuid",
//   // ... other claims
// }
```

### Enterprise API Protection

```javascript
// Enhanced middleware with organization validation
const { KeycloakOIDCMiddleware } = require('./middleware-examples/node/express-oidc-mw');

const keycloakAuth = new KeycloakOIDCMiddleware({
  keycloakUrl: 'http://localhost:8080',
  realm: 'event-platform-organizations',
  clientId: 'event-platform-web'
});

// Organization-aware protected route
app.get('/api/orgs/:orgSlug/events', 
  keycloakAuth.authenticate(),
  keycloakAuth.authorize(['TENANT_MEMBER'], { 
    requireOrganization: true,
    requiredScopes: ['events:read']
  }),
  (req, res) => {
    // req.user.organization is validated against req.params.orgSlug
    res.json({ 
      organization: req.user.organization,
      events: getEventsForOrg(req.user.org_id) 
    });
  }
);

// Admin-only route with tenant isolation
app.get('/api/orgs/:orgSlug/admin', 
  keycloakAuth.protect(['TENANT_ADMIN'], { requireOrganization: true }),
  (req, res) => {
    res.json({ 
      message: 'Tenant admin access',
      organization: req.user.organization 
    });
  }
);
```

### Token Exchange & Service Authentication

```bash
# Service account token
curl -X POST 'http://localhost:8080/realms/event-platform-organizations/protocol/openid-connect/token' \
  -d 'grant_type=client_credentials' \
  -d 'client_id=event-platform-backend' \
  -d 'client_secret=changeme-backend-client-secret'

# Token exchange (API-A to API-B)
curl -X POST 'http://localhost:8080/realms/event-platform-organizations/protocol/openid-connect/token' \
  -d 'grant_type=urn:ietf:params:oauth:grant-type:token-exchange' \
  -d 'client_id=api-a' \
  -d 'client_secret=changeme-api-a-secret' \
  -d 'subject_token=ORIGINAL_TOKEN' \
  -d 'audience=api-b'

# Device authorization grant
curl -X POST 'http://localhost:8080/realms/event-platform-organizations/protocol/openid-connect/device/auth' \
  -d 'client_id=device-bootstrap' \
  -d 'scope=openid organization'

# Authorization Services (UMA)
curl -X POST 'http://localhost:8080/realms/event-platform-organizations/protocol/openid-connect/token' \
  -H 'Authorization: Bearer ACCESS_TOKEN' \
  -d 'grant_type=urn:ietf:params:oauth:grant-type:uma-ticket' \
  -d 'audience=event-platform-backend' \
  -d 'permission=event#event:read'
```

## 🏗 Enterprise Project Structure

```
keycloak-enterprise-template/
├── docker-compose.yml                    # Keycloak 26.2+ with Organizations
├── .env.example                          # Environment template
├── realm/
│   ├── realm-organizations.json          # Basic Organizations realm
│   └── realm-organizations-complete.json # Full realm with test data
├── scripts/
│   ├── import-organizations-realm.sh     # Import Organizations realm
│   ├── register-client.sh                # Client Registration API
│   ├── test-end-to-end.sh                # Complete feature testing
│   ├── backup-production.sh              # Production backup
│   └── rotate-certificates.sh            # Key rotation
├── client-configs/
│   ├── authorization/                     # Authorization Services
│   │   ├── resources.json                # Protected resources
│   │   ├── scopes.json                   # Permission scopes
│   │   ├── policies.json                 # Authorization policies
│   │   └── permissions.json              # Resource permissions
│   ├── spa-client.json                   # SPA client template
│   ├── api-client.json                   # API client template
│   └── device-client.json                # IoT device template
├── middleware-examples/
│   ├── node/express-oidc-mw.js           # Enhanced Express middleware
│   └── python/fastapi_oidc_mw.py         # FastAPI middleware
├── attached_assets/
│   └── device-verify/                    # Device verification server
│       ├── server.js                     # Verification web interface
│       └── package.json                  # Dependencies
├── helm/
│   ├── values.yaml                       # Development values
│   ├── values-prod.yaml                  # Production configuration
│   └── templates/                        # Kubernetes manifests
├── docs/
│   ├── organizations.md                  # Multi-tenant guide
│   ├── authz-services.md                 # Authorization Services
│   ├── client-registration.md            # Client management
│   └── ha-multisite.md                   # HA deployment
├── curl_examples_device.md               # Device flow examples
├── curl_examples_token_exchange.md       # Token exchange examples
└── CHANGELOG.md                          # Version history
```

## 🏢 Organizations Multi-Tenant Setup

### Native Organizations (Recommended for SaaS)

Use Keycloak 26+ Organizations for true multi-tenant isolation:

```bash
# Organizations are automatically configured in the imported realm
# Example organizations included:

# Music Events Organization
# User: admin-music / admin-music-password
# Claims: { "organization": "music-events", "org_id": "org-music-123" }

# Workshop Events Organization  
# User: member-workshop / member-workshop-password
# Claims: { "organization": "workshop-events", "org_id": "org-workshop-456" }

# Wedding Events Organization
# User: owner-wedding / owner-wedding-password
# Claims: { "organization": "wedding-events", "org_id": "org-wedding-789" }
```

### Benefits of Organizations vs Multi-Realm

| Feature | Organizations | Multi-Realm |
|---------|---------------|-------------|
| **Tenant Isolation** | ✅ Native claims | ✅ Complete separation |
| **Operational Overhead** | ✅ Single realm to manage | ❌ Multiple realms |
| **Cross-tenant Features** | ✅ Easy to implement | ❌ Complex federation |
| **Delegated Admin** | ✅ FGAP built-in | ❌ Manual configuration |
| **Scale** | ✅ Thousands of orgs | ⚠️ Hundreds of realms |
| **Token Claims** | ✅ Automatic org context | ❌ Manual implementation |

### Fine-Grained Admin Permissions (FGAP)

Delegate organization management to tenant administrators:

```bash
# Tenant admins can manage their organization users
# FGAP configuration included in realm export
# Role mappings: TENANT_ADMIN -> manage-users (scoped to organization)
```

## ☸️ Kubernetes Deployment

Deploy to Kubernetes using the included Helm chart:

```bash
# Install with Helm
helm install my-keycloak ./helm \
  --set keycloak.admin.password=SecureAdminPassword \
  --set postgresql.auth.password=SecureDbPassword \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=auth.yourdomain.com

# Or customize with your values
helm install my-keycloak ./helm -f your-values.yaml
```

## 🔧 Management Scripts

### Backup & Restore

```bash
# Backup database
./scripts/backup-db.sh

# List available backups
./scripts/restore-db.sh --list

# Restore from backup
./scripts/restore-db.sh latest
```

### Import & Export

```bash
# Export current realm configuration
./scripts/export-realm.sh

# Import updated configuration
FORCE_UPDATE=true ./scripts/import-realm.sh
```

## 🔍 Enterprise Testing & Verification

### Automated End-to-End Testing

```bash
# Test all enterprise features
./scripts/test-end-to-end.sh

# Covers:
# ✅ Organizations realm health
# ✅ Device authorization grant
# ✅ Client credentials flow
# ✅ Token exchange
# ✅ Device verification server
# ✅ Authorization services (UMA)
```

### Device Flow Testing

See [curl_examples_device.md](curl_examples_device.md) for IoT device authentication:

```bash
# Start device pairing
curl -X POST 'http://localhost:8080/realms/event-platform-organizations/protocol/openid-connect/device/auth' \
  -d 'client_id=device-bootstrap' \
  -d 'scope=openid organization'

# User completes verification at verification_uri_complete
# Device polls for token

# Test token with device verification server
open http://localhost:4000
```

### Token Exchange Testing

See [curl_examples_token_exchange.md](curl_examples_token_exchange.md):

```bash
# Service A exchanges token for Service B access
# Audience swapping and scope validation
# Complete service-to-service auth chain
```

### Health Checks

```bash
# Keycloak health
curl http://localhost:8080/health/ready

# Database health  
pg_isready -h localhost -p 5432 -U keycloak

# MailHog UI
open http://localhost:8025
```

## 🛡 Enterprise Security & Production

### Security Hardening Features

**Client Policies (Built-in):**
- ✅ PKCE enforcement for public clients
- ✅ Secure redirect URI validation
- ✅ Allowed signature algorithms (RS256, ES256, EdDSA)
- ✅ Token binding and rotation

**Organization Security:**
- ✅ Tenant isolation through native Organizations
- ✅ Cross-tenant data leakage prevention
- ✅ Fine-grained admin permissions (FGAP)
- ✅ Organization-aware authorization

**Production Deployment:**

```bash
# Use production Helm values
helm install keycloak ./helm -f helm/values-prod.yaml \
  --set keycloak.auth.adminPassword=SECURE_PASSWORD \
  --set postgresql.auth.password=SECURE_DB_PASSWORD \
  --set ingress.tls.enabled=true

# Features included in production config:
# ✅ HA PostgreSQL with read replicas
# ✅ TLS termination and certificate management
# ✅ Resource limits and autoscaling
# ✅ Secrets management integration
# ✅ Monitoring and alerting (Prometheus)
# ✅ Backup and disaster recovery
```

**High Availability Setup:**

See [docs/ha-multisite.md](docs/ha-multisite.md) for complete guide:
- Multi-zone deployment
- Database backup and restore
- Certificate rotation
- Disaster recovery procedures
- Monitoring and alerting

**Security Checklist:**
- [ ] Use `start --optimized` (not start-dev)
- [ ] Enable HTTPS with valid certificates  
- [ ] Use external managed database
- [ ] Change all default passwords and secrets
- [ ] Enable client policies and PKCE
- [ ] Configure monitoring and log aggregation
- [ ] Set up automated backups
- [ ] Implement key rotation procedures
- [ ] Review and test disaster recovery
- [ ] Enable network policies in Kubernetes

### Environment Variables

Never commit these secrets to version control:

```bash
# Critical secrets to change
KEYCLOAK_ADMIN_PASSWORD=      # Keycloak admin password
POSTGRES_PASSWORD=            # Database password  
PROJECT_BACKEND_CLIENT_SECRET= # Backend client secret
KC_SMTP_PASSWORD=             # SMTP password (production)
```

## 📊 Monitoring & Observability

### Metrics

Keycloak exposes metrics at `/metrics`:

```bash
# Enable metrics in production
KC_METRICS_ENABLED=true

# Prometheus configuration included in helm/values.yaml
```

### Logging

```bash
# View logs
docker-compose logs -f keycloak

# Export events
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  "http://localhost:8080/admin/realms/project-realm/events"
```

## 🔄 Refresh Token Rotation

This template enables refresh token rotation for enhanced security:

```bash
# Test token refresh rotation
# (tokens are invalidated after use)
curl -X POST 'http://localhost:8080/realms/project-realm/protocol/openid-connect/token' \
  -d 'grant_type=refresh_token' \
  -d 'client_id=project-web' \
  -d 'refresh_token=YOUR_REFRESH_TOKEN'
```

## 🆘 Troubleshooting

### Common Issues

**Keycloak won't start:**
```bash
# Check database connection
docker-compose logs postgres

# Reset database
docker-compose down -v
docker-compose up -d
```

**Import fails:**
```bash
# Check Keycloak is ready
./scripts/import-realm.sh --help

# Force realm update
FORCE_UPDATE=true ./scripts/import-realm.sh
```

**Token validation fails:**
```bash
# Verify JWKS endpoint for Organizations realm
curl http://localhost:8080/realms/event-platform-organizations/protocol/openid-connect/certs

# Check client configuration  
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  "http://localhost:8080/admin/realms/event-platform-organizations/clients"

# Test organization claims in token
curl -X POST 'http://localhost:8080/realms/event-platform-organizations/protocol/openid-connect/token' \
  -d 'grant_type=password' \
  -d 'client_id=event-platform-web' \
  -d 'username=admin-music' \
  -d 'password=admin-music-password' \
  -d 'scope=openid organization'
```

### 📚 Documentation

**Feature Guides:**
- [Organizations (Multi-tenant)](docs/organizations.md) - Complete multi-tenant setup
- [Authorization Services](docs/authz-services.md) - Fine-grained permissions
- [Client Registration](docs/client-registration.md) - Automated provisioning
- [High Availability](docs/ha-multisite.md) - Production deployment

**API Examples:**
- [Device Flow Examples](curl_examples_device.md) - IoT authentication
- [Token Exchange Examples](curl_examples_token_exchange.md) - Service-to-service
- [Validation Server](http://localhost:5000) - Interactive testing

**Troubleshooting:**
1. Run end-to-end tests: `./scripts/test-end-to-end.sh`
2. Check Docker logs: `docker-compose logs keycloak`
3. Verify Organizations realm import
4. Test device verification server: `http://localhost:4000`
5. Review [Changelog](CHANGELOG.md) for version updates

### 🚀 What's New in v2.0

- **🏢 Native Organizations**: Keycloak 26+ multi-tenant support
- **📱 IoT Device Auth**: Device Authorization Grant (RFC 8628)
- **🔄 Token Exchange**: Standard service-to-service authentication
- **🛡️ Authorization Services**: UMA 2.0 resource permissions
- **⚡ Production Ready**: HA deployment, monitoring, backup procedures
- **🔒 Enhanced Security**: Client policies, algorithm allowlisting, FGAP

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch  
3. Test with `./scripts/test-end-to-end.sh`
4. Update documentation as needed
5. Submit a pull request

---

**Enterprise Authentication Made Simple!** 🏢🔐

*From basic auth to multi-tenant SaaS platform in minutes. Built for Keycloak 26+ with Organizations, Device Flow, Token Exchange, and Authorization Services.*