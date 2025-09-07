#!/bin/bash

# Create Tenant Realm Script
# Creates a new tenant realm based on multi-tenant template

set -euo pipefail

# Configuration
KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
ADMIN_USER="${KEYCLOAK_ADMIN:-admin}"
ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
TEMPLATE_FILE="${TEMPLATE_FILE:-./realm/realm-multitenant.json}"
TENANT_DATA_FILE="${1:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

usage() {
    cat << EOF
Usage: $0 [tenant_data_file]

Create a new tenant realm from template.

Arguments:
  tenant_data_file    JSON file with tenant data (optional, will prompt if not provided)

Environment variables:
  KEYCLOAK_URL: Keycloak server URL (default: http://localhost:8080)
  KEYCLOAK_ADMIN: Admin username (default: admin)
  KEYCLOAK_ADMIN_PASSWORD: Admin password (default: admin)
  TEMPLATE_FILE: Tenant realm template file (default: ./realm/realm-multitenant.json)

Tenant data file format:
{
  "tenant_id": "acme",
  "tenant_name": "Acme Corporation", 
  "tenant_display_name": "Acme Corp",
  "tenant_domain": "acme.com",
  "tenant_prefix": "acme",
  "tenant_mobile_scheme": "com.acme.app",
  "backend_client_secret": "auto-generated-if-empty",
  "smtp_host": "smtp.acme.com",
  "smtp_port": "587",
  "smtp_ssl": "false",
  "smtp_starttls": "true", 
  "smtp_auth": "true",
  "smtp_user": "noreply@acme.com",
  "smtp_password": "smtp-password"
}

Examples:
  $0 tenants/acme.json         # Create tenant from file
  $0                           # Interactive mode
  cat tenants.csv | $0 --batch # Batch create from CSV
EOF
}

# Get admin access token
get_admin_token() {
    log "Getting admin access token..."
    
    local response
    response=$(curl -s -X POST \
        "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=${ADMIN_USER}" \
        -d "password=${ADMIN_PASSWORD}" \
        -d "grant_type=password" \
        -d "client_id=admin-cli")
    
    local token
    token=$(echo "$response" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$token" ]; then
        error "Failed to get admin token"
        exit 1
    fi
    
    echo "$token"
}

# Check if realm exists
realm_exists() {
    local token="$1"
    local realm_name="$2"
    
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $token" \
        "${KEYCLOAK_URL}/admin/realms/${realm_name}")
    
    [ "$status_code" = "200" ]
}

# Generate secret if empty
generate_secret() {
    local provided_secret="$1"
    
    if [ -z "$provided_secret" ] || [ "$provided_secret" = "auto-generated-if-empty" ]; then
        openssl rand -hex 32
    else
        echo "$provided_secret"
    fi
}

# Interactive tenant data collection
collect_tenant_data_interactive() {
    echo ""
    info "Creating new tenant realm - please provide the following information:"
    echo ""
    
    read -p "Tenant ID (lowercase, no spaces): " TENANT_ID
    read -p "Tenant Name: " TENANT_NAME
    read -p "Tenant Display Name: " TENANT_DISPLAY_NAME
    read -p "Tenant Domain: " TENANT_DOMAIN
    read -p "Mobile App Scheme (e.g., com.company.app): " TENANT_MOBILE_SCHEME
    
    echo ""
    info "SMTP Configuration (optional - press Enter to skip):"
    read -p "SMTP Host: " SMTP_HOST
    read -p "SMTP Port [587]: " SMTP_PORT
    read -p "SMTP User: " SMTP_USER
    read -p "SMTP Password: " SMTP_PASSWORD
    
    # Set defaults
    TENANT_PREFIX="${TENANT_ID}"
    SMTP_PORT="${SMTP_PORT:-587}"
    SMTP_SSL="false"
    SMTP_STARTTLS="true"
    SMTP_AUTH="true"
    BACKEND_CLIENT_SECRET=$(generate_secret "")
    
    # Create tenant data JSON
    cat > "/tmp/tenant-${TENANT_ID}.json" << EOF
{
  "tenant_id": "${TENANT_ID}",
  "tenant_name": "${TENANT_NAME}",
  "tenant_display_name": "${TENANT_DISPLAY_NAME}",
  "tenant_domain": "${TENANT_DOMAIN}",
  "tenant_prefix": "${TENANT_PREFIX}",
  "tenant_mobile_scheme": "${TENANT_MOBILE_SCHEME}",
  "backend_client_secret": "${BACKEND_CLIENT_SECRET}",
  "smtp_host": "${SMTP_HOST}",
  "smtp_port": "${SMTP_PORT}",
  "smtp_ssl": "${SMTP_SSL}",
  "smtp_starttls": "${SMTP_STARTTLS}",
  "smtp_auth": "${SMTP_AUTH}",
  "smtp_user": "${SMTP_USER}",
  "smtp_password": "${SMTP_PASSWORD}"
}
EOF
    
    echo "/tmp/tenant-${TENANT_ID}.json"
}

# Parse tenant data from file
parse_tenant_data() {
    local data_file="$1"
    
    if [ ! -f "$data_file" ]; then
        error "Tenant data file not found: $data_file"
        exit 1
    fi
    
    # Validate JSON
    if ! jq empty "$data_file" 2>/dev/null; then
        error "Invalid JSON in tenant data file: $data_file"
        exit 1
    fi
    
    # Extract values
    TENANT_ID=$(jq -r '.tenant_id' "$data_file")
    TENANT_NAME=$(jq -r '.tenant_name' "$data_file")
    TENANT_DISPLAY_NAME=$(jq -r '.tenant_display_name' "$data_file")
    TENANT_DOMAIN=$(jq -r '.tenant_domain' "$data_file")
    TENANT_PREFIX=$(jq -r '.tenant_prefix // .tenant_id' "$data_file")
    TENANT_MOBILE_SCHEME=$(jq -r '.tenant_mobile_scheme' "$data_file")
    BACKEND_CLIENT_SECRET=$(generate_secret "$(jq -r '.backend_client_secret // ""' "$data_file")")
    SMTP_HOST=$(jq -r '.smtp_host // ""' "$data_file")
    SMTP_PORT=$(jq -r '.smtp_port // "587"' "$data_file")
    SMTP_SSL=$(jq -r '.smtp_ssl // "false"' "$data_file")
    SMTP_STARTTLS=$(jq -r '.smtp_starttls // "true"' "$data_file")
    SMTP_AUTH=$(jq -r '.smtp_auth // "true"' "$data_file")
    SMTP_USER=$(jq -r '.smtp_user // ""' "$data_file")
    SMTP_PASSWORD=$(jq -r '.smtp_password // ""' "$data_file")
    
    # Validate required fields
    if [ -z "$TENANT_ID" ] || [ "$TENANT_ID" = "null" ]; then
        error "tenant_id is required in tenant data file"
        exit 1
    fi
    
    if [ -z "$TENANT_NAME" ] || [ "$TENANT_NAME" = "null" ]; then
        error "tenant_name is required in tenant data file"
        exit 1
    fi
}

# Create realm configuration from template
create_realm_config() {
    local output_file="$1"
    
    log "Creating realm configuration for tenant: $TENANT_ID"
    
    # Read template and substitute variables
    local realm_name="${TENANT_ID}-realm"
    
    cat "$TEMPLATE_FILE" | \
        sed "s/{{TENANT_REALM_NAME}}/${realm_name}/g" | \
        sed "s/{{TENANT_ID}}/${TENANT_ID}/g" | \
        sed "s/{{TENANT_NAME}}/${TENANT_NAME}/g" | \
        sed "s/{{TENANT_DISPLAY_NAME}}/${TENANT_DISPLAY_NAME}/g" | \
        sed "s/{{TENANT_DOMAIN}}/${TENANT_DOMAIN}/g" | \
        sed "s/{{TENANT_PREFIX}}/${TENANT_PREFIX}/g" | \
        sed "s/{{TENANT_MOBILE_SCHEME}}/${TENANT_MOBILE_SCHEME}/g" | \
        sed "s/{{BACKEND_CLIENT_SECRET}}/${BACKEND_CLIENT_SECRET}/g" | \
        sed "s/{{SMTP_HOST}}/${SMTP_HOST}/g" | \
        sed "s/{{SMTP_PORT}}/${SMTP_PORT}/g" | \
        sed "s/{{SMTP_SSL}}/${SMTP_SSL}/g" | \
        sed "s/{{SMTP_STARTTLS}}/${SMTP_STARTTLS}/g" | \
        sed "s/{{SMTP_AUTH}}/${SMTP_AUTH}/g" | \
        sed "s/{{SMTP_USER}}/${SMTP_USER}/g" | \
        sed "s/{{SMTP_PASSWORD}}/${SMTP_PASSWORD}/g" > "$output_file"
    
    log "Realm configuration created: $output_file"
}

# Import realm
import_realm() {
    local token="$1"
    local realm_file="$2"
    local realm_name="${TENANT_ID}-realm"
    
    log "Importing tenant realm: $realm_name"
    
    if realm_exists "$token" "$realm_name"; then
        warn "Realm '$realm_name' already exists"
        if [ "${FORCE_UPDATE:-false}" != "true" ]; then
            error "Use FORCE_UPDATE=true to update existing realm"
            exit 1
        fi
        
        # Update existing realm
        curl -s -X PUT \
            "${KEYCLOAK_URL}/admin/realms/${realm_name}" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -d @"$realm_file"
    else
        # Create new realm
        curl -s -X POST \
            "${KEYCLOAK_URL}/admin/realms" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -d @"$realm_file"
    fi
    
    if [ $? -eq 0 ]; then
        log "Tenant realm '$realm_name' created successfully!"
    else
        error "Failed to create tenant realm"
        exit 1
    fi
}

# Create tenant admin user
create_tenant_admin() {
    local token="$1"
    local realm_name="${TENANT_ID}-realm"
    local admin_email="${TENANT_ADMIN_EMAIL:-admin@${TENANT_DOMAIN}}"
    local admin_username="${TENANT_ADMIN_USERNAME:-${TENANT_ID}-admin}"
    local admin_password="${TENANT_ADMIN_PASSWORD:-ChangeMePlease123!}"
    
    log "Creating tenant admin user: $admin_username"
    
    local user_data
    user_data=$(cat <<EOF
{
    "username": "$admin_username",
    "email": "$admin_email",
    "firstName": "Tenant",
    "lastName": "Administrator",
    "enabled": true,
    "emailVerified": true,
    "credentials": [
        {
            "type": "password",
            "value": "$admin_password",
            "temporary": false
        }
    ],
    "realmRoles": ["admin", "owner"],
    "requiredActions": []
}
EOF
    )
    
    curl -s -X POST \
        "${KEYCLOAK_URL}/admin/realms/${realm_name}/users" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "$user_data"
    
    if [ $? -eq 0 ]; then
        log "Tenant admin user created successfully!"
        info "Admin credentials for $realm_name:"
        info "  Username: $admin_username"
        info "  Email: $admin_email"
        info "  Password: [see TENANT_ADMIN_PASSWORD]"
    else
        warn "Failed to create tenant admin user (continuing anyway)"
    fi
}

# Main execution
main() {
    log "Starting tenant realm creation process..."
    
    # Get tenant data
    if [ -z "$TENANT_DATA_FILE" ]; then
        TENANT_DATA_FILE=$(collect_tenant_data_interactive)
    fi
    
    parse_tenant_data "$TENANT_DATA_FILE"
    
    # Validate template file
    if [ ! -f "$TEMPLATE_FILE" ]; then
        error "Template file not found: $TEMPLATE_FILE"
        exit 1
    fi
    
    # Get admin token
    ADMIN_TOKEN=$(get_admin_token)
    
    # Create realm configuration
    REALM_CONFIG_FILE="/tmp/realm-${TENANT_ID}.json"
    create_realm_config "$REALM_CONFIG_FILE"
    
    # Import realm
    import_realm "$ADMIN_TOKEN" "$REALM_CONFIG_FILE"
    
    # Create tenant admin user
    create_tenant_admin "$ADMIN_TOKEN"
    
    # Output summary
    log "Tenant realm creation completed successfully!"
    echo ""
    info "Tenant Summary:"
    info "  Tenant ID: $TENANT_ID"
    info "  Realm Name: ${TENANT_ID}-realm"
    info "  Domain: $TENANT_DOMAIN"
    info "  Backend Client Secret: $BACKEND_CLIENT_SECRET"
    echo ""
    info "Next steps:"
    info "1. Configure your application to use realm '${TENANT_ID}-realm'"
    info "2. Update client redirect URIs if needed"
    info "3. Configure SMTP settings in Keycloak admin console"
    info "4. Set up tenant admin MFA requirements"
    
    # Cleanup
    rm -f "$REALM_CONFIG_FILE"
    if [ -f "/tmp/tenant-${TENANT_ID}.json" ]; then
        rm -f "/tmp/tenant-${TENANT_ID}.json"
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        usage
        exit 0
        ;;
    --batch)
        # TODO: Implement batch processing from CSV
        error "Batch mode not yet implemented"
        exit 1
        ;;
esac

# Check for required tools
for tool in curl jq openssl; do
    if ! command -v $tool &> /dev/null; then
        error "$tool is required but not installed."
        exit 1
    fi
done

main "$@"