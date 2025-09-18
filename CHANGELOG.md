# Changelog

All notable changes to this Keycloak Auth Template will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2024-12-18

### Added

#### Multi-Tenant SaaS Support
- **Organizations support** (Keycloak ≥ 26) for native multi-tenant SaaS applications
- New realm configuration `realm/realm-organizations.json` with Organizations enabled
- Organization claims in JWT tokens (`organization`, `org_id`)
- Fine-Grained Admin Permissions (FGAP) examples for per-tenant delegated administration
- Documentation for choosing between single-realm+Organizations vs multi-realm architectures

#### IoT Device Authentication
- **Device Authorization Grant** (RFC 8628) support for IoT device pairing
- Device flow walkthrough with complete cURL examples in `curl_examples_device.md`
- Device verification server at `attached_assets/device-verify/` for pairing validation
- Device client configuration templates and registration scripts

#### Token Exchange & Client Management
- **Standard Token Exchange** (Keycloak ≥ 26.2) implementation
- Automated client provisioning via Client Registration API
- Client registration script `scripts/register-client.sh` supporting SPA, backend, and device clients
- Token exchange examples with audience swapping in `curl_examples_token_exchange.md`

#### Authorization Services
- Resource-based authorization with minimal example configuration
- Authorization policies, permissions, and scopes in `client-configs/authorization/`
- Requesting Party Token (RPT) validation examples
- Documentation comparing Authorization Services vs API-side permission checking

#### Security & Production Hardening
- Client Policies enforcing PKCE, strict redirect URIs, and signature algorithms
- Production Helm values in `helm/values-prod.yaml` with security best practices
- Enhanced Docker Compose configuration for Keycloak 26.2+ with new features enabled
- TLS configuration, SMTP setup, and secrets management examples

#### High Availability & Operations
- Comprehensive HA deployment guide in `docs/ha-multisite.md`
- Automated backup/restore procedures with Kubernetes CronJobs
- Certificate and password rotation scripts
- Prometheus monitoring configuration with alerts
- Disaster recovery procedures and testing scripts

#### Enhanced Middleware & Validation
- Updated Express.js middleware with organization claims validation
- Enhanced token validation supporting multiple signature algorithms (RS256, ES256, EdDSA)
- Scope and resource permission validation methods
- Device verification server with web UI for testing IoT device tokens

### Changed

#### Breaking Changes
- **Minimum Keycloak version requirement: 26.2+**
- Docker Compose now uses Keycloak 26.2.0 image
- Enabled new features: `organizations`, `token-exchange`, `client-policies`, `device-flow`, `authorization`

#### Enhanced Features
- Validation server now provides better information about Replit preview vs local deployment
- Improved middleware with caching, rate limiting, and comprehensive error handling
- Enhanced documentation structure with dedicated guides for each feature

#### Configuration Updates
- Updated environment variables for new Keycloak features
- Production-ready Helm chart with HA PostgreSQL configuration
- Network policies and security contexts for Kubernetes deployments

### Technical Specifications

#### Supported Keycloak Features
- Organizations (Multi-tenant SaaS)
- Device Authorization Grant (IoT)
- Standard Token Exchange
- Client Registration API
- Authorization Services
- Client Policies
- PKCE enforcement

#### Deployment Targets
- **Development**: Docker Compose with Keycloak 26.2+
- **Production**: Kubernetes with Helm charts
- **Cloud**: AWS, GCP, Azure with managed services

#### Authentication Flows Supported
- Authorization Code + PKCE (SPA)
- Client Credentials (Backend APIs)
- Device Authorization Grant (IoT)
- Token Exchange (Service-to-service)

### Dependencies

#### Updated
- Keycloak: 23.0.0 → 26.2.0
- Node.js middleware: Enhanced with new validation features
- Helm charts: Production-ready configuration

#### New
- `jsonwebtoken`: ^9.0.0 (device verification server)
- `jwks-rsa`: ^3.0.1 (enhanced JWKS caching)

### Migration Guide

#### From v1.x to v2.0

1. **Update Keycloak Version**
   ```bash
   # Update docker-compose.yml
   docker-compose down
   docker-compose pull
   docker-compose up -d
   ```

2. **Enable New Features**
   ```bash
   # Set environment variables
   KC_FEATURES=organizations,token-exchange,client-policies,device-flow,authorization
   KC_ORGANIZATIONS_ENABLED=true
   KC_TOKEN_EXCHANGE_ENABLED=true
   ```

3. **Update Client Applications**
   - Validate new token claims (`organization`, `org_id`)
   - Update middleware to handle enhanced features
   - Test with new authentication flows

4. **Review Security Settings**
   - Update client policies for PKCE enforcement
   - Review and update redirect URI configurations
   - Implement new authorization policies if needed

### Documentation

#### New Guides
- [Organizations (Multi-tenant)](docs/organizations.md)
- [Authorization Services](docs/authz-services.md)
- [Client Registration API](docs/client-registration.md)
- [High Availability & Multi-site](docs/ha-multisite.md)

#### Updated Examples
- Device flow cURL walkthrough
- Token exchange examples
- Production deployment configurations
- Security hardening checklists

---

## [1.0.0] - 2024-01-15

### Added
- Initial Keycloak Auth Template release
- Docker Compose setup with Keycloak 23.0.0
- Basic realm configuration for single-tenant deployments
- Express.js and FastAPI middleware examples
- PostgreSQL database integration
- MailHog for email testing
- Helm charts for Kubernetes deployment
- Basic backup and restore scripts
- Single-tenant realm configuration
- Client configurations for web, backend, and mobile applications

### Features
- Single-realm authentication
- Role-based access control
- JWT token validation
- OIDC integration examples
- Development environment setup
- Production deployment guidelines

### Documentation
- Complete README with quick start guide
- API examples with cURL
- Security best practices
- Troubleshooting guide

---

## Unreleased

### Planned Features
- Enhanced multi-tenant organizations management UI
- Advanced authorization policies and examples
- Integration with popular frameworks (React, Vue, Angular)
- Mobile application examples (React Native, Flutter)
- Additional identity provider integrations
- Performance optimization guides
- Cost optimization for cloud deployments