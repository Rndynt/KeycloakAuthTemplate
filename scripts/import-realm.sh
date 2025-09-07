#!/bin/bash

# Import Keycloak Realm Script
# This script is idempotent - safe to run multiple times

set -euo pipefail

# Configuration
KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
REALM_NAME="${PROJECT_REALM:-project-realm}"
REALM_FILE="${REALM_FILE:-./realm/realm-singletenant.json}"
ADMIN_USER="${KEYCLOAK_ADMIN:-admin}"
ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
MAX_RETRIES=30
RETRY_INTERVAL=10

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Wait for Keycloak to be ready
wait_for_keycloak() {
    log "Waiting for Keycloak to be ready..."
    for i in $(seq 1 $MAX_RETRIES); do
        if curl -s -f "${KEYCLOAK_URL}/health/ready" > /dev/null 2>&1; then
            log "Keycloak is ready!"
            return 0
        fi
        warn "Keycloak not ready yet (attempt $i/$MAX_RETRIES), waiting ${RETRY_INTERVAL}s..."
        sleep $RETRY_INTERVAL
    done
    error "Keycloak failed to become ready after $MAX_RETRIES attempts"
    exit 1
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
    
    if [ $? -ne 0 ]; then
        error "Failed to get admin token"
        exit 1
    fi
    
    local token
    token=$(echo "$response" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$token" ]; then
        error "Failed to parse access token from response"
        echo "Response: $response"
        exit 1
    fi
    
    echo "$token"
}

# Check if realm exists
realm_exists() {
    local token="$1"
    local status_code
    
    status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $token" \
        "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}")
    
    [ "$status_code" = "200" ]
}

# Import realm
import_realm() {
    local token="$1"
    log "Importing realm from $REALM_FILE..."
    
    if [ ! -f "$REALM_FILE" ]; then
        error "Realm file not found: $REALM_FILE"
        exit 1
    fi
    
    local response
    response=$(curl -s -X POST \
        "${KEYCLOAK_URL}/admin/realms" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d @"$REALM_FILE")
    
    if [ $? -eq 0 ]; then
        log "Realm '$REALM_NAME' imported successfully!"
    else
        error "Failed to import realm"
        echo "Response: $response"
        exit 1
    fi
}

# Update existing realm
update_realm() {
    local token="$1"
    log "Updating existing realm '$REALM_NAME'..."
    
    curl -s -X PUT \
        "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d @"$REALM_FILE"
    
    if [ $? -eq 0 ]; then
        log "Realm '$REALM_NAME' updated successfully!"
    else
        error "Failed to update realm"
        exit 1
    fi
}

# Configure token lifetimes
configure_token_lifetimes() {
    local token="$1"
    log "Configuring token lifetimes..."
    
    # Update realm token settings
    curl -s -X PUT \
        "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d '{
            "accessTokenLifespan": 600,
            "accessTokenLifespanForImplicitFlow": 600,
            "ssoSessionIdleTimeout": 1800,
            "ssoSessionMaxLifespan": 36000,
            "offlineSessionIdleTimeout": 604800,
            "refreshTokenMaxReuse": 0
        }'
    
    log "Token lifetimes configured: Access 10min, Refresh 7days, SSO Idle 30min"
}

# Main execution
main() {
    log "Starting Keycloak realm import process..."
    log "Target: $KEYCLOAK_URL"
    log "Realm: $REALM_NAME"
    log "File: $REALM_FILE"
    
    # Wait for Keycloak
    wait_for_keycloak
    
    # Get admin token
    ADMIN_TOKEN=$(get_admin_token)
    
    # Check if realm exists
    if realm_exists "$ADMIN_TOKEN"; then
        warn "Realm '$REALM_NAME' already exists"
        
        if [ "${FORCE_UPDATE:-false}" = "true" ]; then
            update_realm "$ADMIN_TOKEN"
        else
            log "Use FORCE_UPDATE=true to update existing realm"
            log "Realm import completed (no changes made)"
            exit 0
        fi
    else
        import_realm "$ADMIN_TOKEN"
    fi
    
    # Configure additional settings
    configure_token_lifetimes "$ADMIN_TOKEN"
    
    log "Realm import process completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--force]"
        echo "Import or update Keycloak realm configuration"
        echo ""
        echo "Environment variables:"
        echo "  KEYCLOAK_URL: Keycloak server URL (default: http://localhost:8080)"
        echo "  PROJECT_REALM: Realm name (default: project-realm)"
        echo "  REALM_FILE: Path to realm JSON file (default: ./realm/realm-singletenant.json)"
        echo "  KEYCLOAK_ADMIN: Admin username (default: admin)"
        echo "  KEYCLOAK_ADMIN_PASSWORD: Admin password (default: admin)"
        echo "  FORCE_UPDATE: Set to 'true' to update existing realm"
        exit 0
        ;;
    --force)
        export FORCE_UPDATE=true
        ;;
esac

main "$@"