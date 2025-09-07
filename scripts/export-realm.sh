#!/bin/bash

# Export Keycloak Realm Script
# Exports current realm configuration to JSON

set -euo pipefail

# Configuration
KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
REALM_NAME="${PROJECT_REALM:-project-realm}"
ADMIN_USER="${KEYCLOAK_ADMIN:-admin}"
ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
OUTPUT_DIR="${OUTPUT_DIR:-./realm}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
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

# Export realm
export_realm() {
    local token="$1"
    local output_file="$2"
    
    log "Exporting realm '$REALM_NAME'..."
    
    local response
    response=$(curl -s \
        -H "Authorization: Bearer $token" \
        "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}")
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        echo "$response" | jq '.' > "$output_file"
        log "Realm exported to: $output_file"
    else
        error "Failed to export realm"
        exit 1
    fi
}

# Export users (optional)
export_users() {
    local token="$1"
    local output_file="$2"
    
    log "Exporting users..."
    
    local response
    response=$(curl -s \
        -H "Authorization: Bearer $token" \
        "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users")
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        echo "$response" | jq '.' > "$output_file"
        log "Users exported to: $output_file"
    else
        warn "Failed to export users (continuing anyway)"
    fi
}

# Export clients
export_clients() {
    local token="$1"
    local output_file="$2"
    
    log "Exporting clients..."
    
    local response
    response=$(curl -s \
        -H "Authorization: Bearer $token" \
        "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients")
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        echo "$response" | jq '.' > "$output_file"
        log "Clients exported to: $output_file"
    else
        warn "Failed to export clients (continuing anyway)"
    fi
}

# Main execution
main() {
    log "Starting realm export process..."
    log "Realm: $REALM_NAME"
    log "Output directory: $OUTPUT_DIR"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Get admin token
    ADMIN_TOKEN=$(get_admin_token)
    
    # Define output files
    REALM_FILE="${OUTPUT_DIR}/realm-export-${TIMESTAMP}.json"
    USERS_FILE="${OUTPUT_DIR}/users-export-${TIMESTAMP}.json"
    CLIENTS_FILE="${OUTPUT_DIR}/clients-export-${TIMESTAMP}.json"
    
    # Export realm configuration
    export_realm "$ADMIN_TOKEN" "$REALM_FILE"
    
    # Export additional data if requested
    if [ "${EXPORT_USERS:-false}" = "true" ]; then
        export_users "$ADMIN_TOKEN" "$USERS_FILE"
    fi
    
    if [ "${EXPORT_CLIENTS:-false}" = "true" ]; then
        export_clients "$ADMIN_TOKEN" "$CLIENTS_FILE"
    fi
    
    # Create backup info
    cat > "${OUTPUT_DIR}/export-info-${TIMESTAMP}.txt" << EOF
Keycloak Realm Export
=====================
Date: $(date)
Realm: $REALM_NAME
Keycloak URL: $KEYCLOAK_URL
Export Type: Realm Configuration

Files:
- Realm: $(basename "$REALM_FILE")
$([ "${EXPORT_USERS:-false}" = "true" ] && echo "- Users: $(basename "$USERS_FILE")")
$([ "${EXPORT_CLIENTS:-false}" = "true" ] && echo "- Clients: $(basename "$CLIENTS_FILE")")

Restore Command:
./scripts/import-realm.sh --force
EOF
    
    log "Export process completed successfully!"
    log "Files created in: $OUTPUT_DIR"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--users] [--clients]"
        echo "Export Keycloak realm configuration"
        echo ""
        echo "Options:"
        echo "  --users    Also export users"
        echo "  --clients  Also export clients"
        echo ""
        echo "Environment variables:"
        echo "  KEYCLOAK_URL: Keycloak server URL (default: http://localhost:8080)"
        echo "  PROJECT_REALM: Realm name (default: project-realm)"
        echo "  OUTPUT_DIR: Output directory (default: ./realm)"
        echo "  KEYCLOAK_ADMIN: Admin username (default: admin)"
        echo "  KEYCLOAK_ADMIN_PASSWORD: Admin password (default: admin)"
        exit 0
        ;;
    --users)
        export EXPORT_USERS=true
        ;;
    --clients)
        export EXPORT_CLIENTS=true
        ;;
    --all)
        export EXPORT_USERS=true
        export EXPORT_CLIENTS=true
        ;;
esac

# Check for jq
if ! command -v jq &> /dev/null; then
    error "jq is required but not installed. Please install jq first."
    exit 1
fi

main "$@"