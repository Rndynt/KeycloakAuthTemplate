# 🔐 Keycloak Auth Template

**Independent Keycloak Authentication Template** - Copy and Run for Any Project

A production-ready, copy-and-paste Keycloak authentication setup with Docker Compose, supporting both single-tenant and multi-tenant deployments. This template provides everything you need to add enterprise-grade authentication to your project in minutes.

## ✨ Features

- **🚀 Copy-and-Run**: Complete setup with Docker Compose
- **🔒 Production-Ready**: Secure defaults, MFA support, proper token lifetimes
- **🏢 Multi-Tenant**: Support for single or multi-tenant deployments
- **📱 All Clients**: Web (SPA), Backend (API), Mobile app configurations
- **🛠 Complete Tooling**: Scripts for import, export, backup, restore
- **📚 Rich Examples**: Middleware, cURL examples, PKCE demos
- **☸️ Kubernetes Ready**: Helm charts included
- **🔧 Developer Friendly**: MailHog for email testing, comprehensive docs

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

### 2. Start Services

```bash
# Start Keycloak, PostgreSQL, and MailHog
docker-compose up -d

# Wait for services to be ready (2-3 minutes)
docker-compose logs -f keycloak
```

### 3. Import Configuration

```bash
# Import realm and create admin user
./scripts/import-realm.sh
./scripts/seed-admin.sh

# Access Keycloak Admin Console
open http://localhost:8080
```

**That's it!** 🎉 Your authentication system is ready.

## 📋 Default Configuration

### Token Lifetimes
- **Access Token**: 10 minutes
- **Refresh Token**: 7 days (with rotation)
- **SSO Session Idle**: 30 minutes

### Default Clients
- **`project-web`**: Public SPA client (Authorization Code + PKCE)
- **`project-backend`**: Confidential service client (Client Credentials)
- **`project-mobile`**: Public mobile client (Authorization Code + PKCE)

### Realm Roles
- **`owner`**: Full access to all resources
- **`operator`**: Operational access to resources  
- **`admin`**: Administrative access (MFA required)

### Security Features
- Password policy: 8+ chars, mixed case, numbers
- MFA: TOTP required for admin role
- Brute force protection enabled
- Email verification supported

## 🚀 Integration Examples

### Web Application (SPA)

```javascript
// Using project-web client
const keycloakConfig = {
  url: 'http://localhost:8080',
  realm: 'project-realm',
  clientId: 'project-web'
};

// Authorization URL for login
const authUrl = `${keycloakConfig.url}/realms/${keycloakConfig.realm}/protocol/openid-connect/auth?client_id=${keycloakConfig.clientId}&response_type=code&scope=openid&redirect_uri=${redirectUri}&code_challenge=${codeChallenge}&code_challenge_method=S256`;
```

### Backend API Protection

```javascript
// Node.js Express middleware
const { KeycloakOIDCMiddleware } = require('./middleware-examples/node/express-oidc-mw');

const keycloakAuth = new KeycloakOIDCMiddleware({
  keycloakUrl: 'http://localhost:8080',
  realm: 'project-realm',
  clientId: 'project-web'
});

// Protect routes
app.get('/api/protected', keycloakAuth.authenticate(), (req, res) => {
  res.json({ user: req.user });
});

// Require specific roles
app.get('/api/admin', keycloakAuth.protect(['admin']), (req, res) => {
  res.json({ message: 'Admin access granted' });
});
```

### Service-to-Service Authentication

```bash
# Get service account token
curl -X POST 'http://localhost:8080/realms/project-realm/protocol/openid-connect/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=client_credentials' \
  -d 'client_id=project-backend' \
  -d 'client_secret=your-backend-secret'
```

## 🏗 Project Structure

```
keycloak-auth-template/
├── docker-compose.yml              # Main service definition
├── .env.example                    # Environment template
├── realm/
│   ├── realm-singletenant.json     # Single-tenant realm config
│   └── realm-multitenant.json      # Multi-tenant realm template
├── scripts/
│   ├── import-realm.sh             # Import realm configuration
│   ├── export-realm.sh             # Export realm configuration  
│   ├── seed-admin.sh               # Create admin user
│   ├── backup-db.sh                # Database backup
│   ├── restore-db.sh               # Database restore
│   └── create-tenant-realm.sh      # Multi-tenant realm creation
├── client-configs/
│   ├── project-web.json            # SPA client configuration
│   ├── project-backend.json        # Backend client configuration
│   └── project-mobile.json         # Mobile client configuration
├── middleware-examples/
│   ├── node/express-oidc-mw.js     # Express.js middleware
│   └── python/fastapi_oidc_mw.py   # FastAPI middleware
├── helm/                           # Kubernetes deployment
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
└── curl_examples.md                # Complete API examples
```

## 🌐 Multi-Tenant Setup

### Option 1: Multi-Realm (Recommended)

Each tenant gets their own realm with isolated users and configurations:

```bash
# Create tenant realm from template
./scripts/create-tenant-realm.sh tenants/acme.json

# Tenant data file (tenants/acme.json)
{
  "tenant_id": "acme",
  "tenant_name": "Acme Corporation",
  "tenant_domain": "acme.com",
  "tenant_display_name": "Acme Corp"
}
```

### Option 2: Single-Realm with Tenant Claims

Use one realm with tenant identification in JWT tokens:

- Add tenant claim mappers to clients
- Include tenant_id in all tokens
- Implement tenant-based authorization in your app

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

## 🔍 Testing & Verification

### PKCE Flow Testing

See [curl_examples.md](curl_examples.md) for complete testing scenarios:

```bash
# Generate PKCE parameters
CODE_VERIFIER=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-43)
CODE_CHALLENGE=$(echo -n $CODE_VERIFIER | openssl dgst -sha256 -binary | openssl base64 -A)

# Complete authorization flow
# ... (see curl_examples.md for full flow)
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

## 🛡 Security Best Practices

### Development vs Production

**Development (current setup):**
- Uses `start-dev` mode
- HTTP enabled for localhost
- MailHog for email testing
- Default admin credentials

**Production checklist:**
- [ ] Use `start --optimized` mode
- [ ] Enable HTTPS with valid certificates
- [ ] Use managed database (RDS, Cloud SQL, etc.)
- [ ] Configure real SMTP server
- [ ] Change all default passwords
- [ ] Use secrets management (Vault, K8s secrets)
- [ ] Enable monitoring and logging
- [ ] Restrict admin console access
- [ ] Configure backup strategy

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
# Verify JWKS endpoint
curl http://localhost:8080/realms/project-realm/protocol/openid-connect/certs

# Check client configuration
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  "http://localhost:8080/admin/realms/project-realm/clients"
```

### Support

1. Check [curl_examples.md](curl_examples.md) for API testing
2. Review Docker Compose logs: `docker-compose logs`
3. Verify configuration with validation server: `http://localhost:5000`
4. Consult Keycloak documentation: [keycloak.org/docs](https://www.keycloak.org/docs/)

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Test thoroughly with provided examples
4. Submit a pull request

---

**Happy authenticating!** 🔐✨

*This template provides enterprise-grade authentication in minutes, not months.*