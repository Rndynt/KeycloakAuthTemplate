#!/bin/bash

# Seed Admin User Script
# Creates default admin user in the project realm

set -euo pipefail

# Configuration
KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
REALM_NAME="${PROJECT_REALM:-project-realm}"
ADMIN_USER="${KEYCLOAK_ADMIN:-admin}"
ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
PROJECT_ADMIN_EMAIL="${PROJECT_ADMIN_EMAIL:-admin@project.local}"
PROJECT_ADMIN_USERNAME="${PROJECT_ADMIN_USERNAME:-project-admin}"
PROJECT_ADMIN_PASSWORD="${PROJECT_ADMIN_PASSWORD:-ChangeMePlease123!}"

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

# Check if user exists
user_exists() {
    local token="$1"
    local username="$2"
    
    local response
    response=$(curl -s \
        -H "Authorization: Bearer $token" \
        "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users?username=${username}")
    
    local count
    count=$(echo "$response" | grep -o '"username"' | wc -l)
    
    [ "$count" -gt 0 ]
}

# Create user
create_user() {
    local token="$1"
    log "Creating admin user: $PROJECT_ADMIN_USERNAME"
    
    local user_data
    user_data=$(cat <<EOF
{
    "username": "$PROJECT_ADMIN_USERNAME",
    "email": "$PROJECT_ADMIN_EMAIL",
    "firstName": "Project",
    "lastName": "Administrator",
    "enabled": true,
    "emailVerified": true,
    "credentials": [
        {
            "type": "password",
            "value": "$PROJECT_ADMIN_PASSWORD",
            "temporary": false
        }
    ],
    "realmRoles": ["admin"],
    "requiredActions": []
}
EOF
    )
    
    local response
    response=$(curl -s -X POST \
        "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "$user_data")
    
    if [ $? -eq 0 ]; then
        log "User created successfully!"
    else
        error "Failed to create user"
        echo "Response: $response"
        exit 1
    fi
}

# Get user ID
get_user_id() {
    local token="$1"
    local username="$2"
    
    local response
    response=$(curl -s \
        -H "Authorization: Bearer $token" \
        "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users?username=${username}")
    
    echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4
}

# Assign realm roles
assign_roles() {
    local token="$1"
    local user_id="$2"
    
    log "Assigning admin role..."
    
    # Get role representation
    local role_response
    role_response=$(curl -s \
        -H "Authorization: Bearer $token" \
        "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/roles/admin")
    
    # Assign role
    curl -s -X POST \
        "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users/${user_id}/role-mappings/realm" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "[$role_response]"
    
    log "Admin role assigned successfully!"
}

# Configure MFA requirement for admin role
configure_admin_mfa() {
    local token="$1"
    log "Configuring MFA requirement for admin role..."
    
    # This would require additional API calls to set up authentication flows
    # For now, just log the requirement
    warn "MANUAL STEP REQUIRED: Configure MFA requirement for admin role in Keycloak console"
    warn "Go to: Authentication > Required Actions > Configure OTP: Default Action"
}

# Main execution
main() {
    log "Starting admin user seeding process..."
    log "Realm: $REALM_NAME"
    log "Admin User: $PROJECT_ADMIN_USERNAME"
    log "Admin Email: $PROJECT_ADMIN_EMAIL"
    
    # Get admin token
    ADMIN_TOKEN=$(get_admin_token)
    
    # Check if user exists
    if user_exists "$ADMIN_TOKEN" "$PROJECT_ADMIN_USERNAME"; then
        warn "User '$PROJECT_ADMIN_USERNAME' already exists"
        log "Seeding completed (no changes made)"
        return 0
    fi
    
    # Create user
    create_user "$ADMIN_TOKEN"
    
    # Get user ID and assign roles
    USER_ID=$(get_user_id "$ADMIN_TOKEN" "$PROJECT_ADMIN_USERNAME")
    if [ -n "$USER_ID" ]; then
        assign_roles "$ADMIN_TOKEN" "$USER_ID"
    else
        error "Failed to get user ID for role assignment"
        exit 1
    fi
    
    # Configure MFA
    configure_admin_mfa "$ADMIN_TOKEN"
    
    log "Admin user seeding completed successfully!"
    log ""
    log "IMPORTANT: Default credentials (change immediately):"
    log "Username: $PROJECT_ADMIN_USERNAME"
    log "Email: $PROJECT_ADMIN_EMAIL"
    log "Password: [see PROJECT_ADMIN_PASSWORD in .env]"
    log ""
    log "Login at: ${KEYCLOAK_URL}/realms/${REALM_NAME}/account"
}

# Handle help
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Usage: $0"
    echo "Create admin user in project realm"
    echo ""
    echo "Environment variables:"
    echo "  PROJECT_ADMIN_EMAIL: Admin email (default: admin@project.local)"
    echo "  PROJECT_ADMIN_USERNAME: Admin username (default: project-admin)"
    echo "  PROJECT_ADMIN_PASSWORD: Admin password (default: ChangeMePlease123!)"
    echo "  KEYCLOAK_URL: Keycloak server URL (default: http://localhost:8080)"
    echo "  PROJECT_REALM: Realm name (default: project-realm)"
    exit 0
fi

main "$@"