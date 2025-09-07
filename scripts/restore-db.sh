#!/bin/bash

# Restore Keycloak Database Script
# Restores database from backup file

set -euo pipefail

# Configuration
DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_NAME="${POSTGRES_DB:-keycloak}"
DB_USER="${POSTGRES_USER:-keycloak}"
DB_PASSWORD="${POSTGRES_PASSWORD:-keycloak}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"

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

# Test database connection
test_connection() {
    log "Testing database connection..."
    
    export PGPASSWORD="$DB_PASSWORD"
    
    if pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" > /dev/null 2>&1; then
        log "Database connection successful"
    else
        error "Cannot connect to database"
        exit 1
    fi
}

# Find backup file
find_backup_file() {
    local backup_name="$1"
    
    # If full path provided
    if [ -f "$backup_name" ]; then
        echo "$backup_name"
        return 0
    fi
    
    # Look in backup directory
    local backup_path="${BACKUP_DIR}/${backup_name}"
    if [ -f "$backup_path" ]; then
        echo "$backup_path"
        return 0
    fi
    
    # Try with .gz extension
    if [ -f "${backup_path}.gz" ]; then
        echo "${backup_path}.gz"
        return 0
    fi
    
    # Search for latest backup if no name provided
    if [ -z "$backup_name" ] || [ "$backup_name" = "latest" ]; then
        local latest_backup
        latest_backup=$(find "$BACKUP_DIR" -name "keycloak-backup-*.sql*" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
        
        if [ -n "$latest_backup" ]; then
            echo "$latest_backup"
            return 0
        fi
    fi
    
    return 1
}

# Decompress if needed
prepare_backup_file() {
    local backup_file="$1"
    
    if [[ "$backup_file" == *.gz ]]; then
        log "Decompressing backup file..."
        local temp_file="/tmp/keycloak-restore-$(date +%s).sql"
        
        if gunzip -c "$backup_file" > "$temp_file"; then
            echo "$temp_file"
        else
            error "Failed to decompress backup file"
            exit 1
        fi
    else
        echo "$backup_file"
    fi
}

# Create pre-restore backup
create_pre_restore_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/pre-restore-backup-${timestamp}.sql"
    
    log "Creating pre-restore backup..."
    
    export PGPASSWORD="$DB_PASSWORD"
    
    mkdir -p "$BACKUP_DIR"
    
    if pg_dump \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        --format=custom \
        --file="$backup_file" 2>/dev/null; then
        
        log "Pre-restore backup created: $backup_file"
    else
        warn "Failed to create pre-restore backup (continuing anyway)"
    fi
}

# Restore database
restore_database() {
    local backup_file="$1"
    
    log "Restoring database from: $backup_file"
    log "Target database: $DB_NAME@$DB_HOST:$DB_PORT"
    
    export PGPASSWORD="$DB_PASSWORD"
    
    # Check if backup file is compressed format or SQL
    local restore_cmd
    if file "$backup_file" | grep -q "PostgreSQL custom database dump"; then
        # Custom format - use pg_restore
        restore_cmd="pg_restore -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME --clean --if-exists --verbose"
    else
        # SQL format - use psql
        restore_cmd="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f"
    fi
    
    log "Executing restore command..."
    
    if $restore_cmd "$backup_file"; then
        log "Database restored successfully!"
    else
        error "Database restore failed!"
        exit 1
    fi
}

# Cleanup temporary files
cleanup() {
    if [ -n "${TEMP_FILE:-}" ] && [ -f "$TEMP_FILE" ]; then
        rm -f "$TEMP_FILE"
        log "Temporary files cleaned up"
    fi
}

# Main execution
main() {
    local backup_name="${1:-latest}"
    
    log "Starting database restore process..."
    log "Backup: $backup_name"
    
    # Find backup file
    local backup_file
    if ! backup_file=$(find_backup_file "$backup_name"); then
        error "Backup file not found: $backup_name"
        echo "Available backups:"
        find "$BACKUP_DIR" -name "keycloak-backup-*.sql*" -type f 2>/dev/null | sort || echo "No backups found"
        exit 1
    fi
    
    log "Found backup file: $backup_file"
    
    # Test connection
    test_connection
    
    # Confirm restore
    if [ "${FORCE_RESTORE:-false}" != "true" ]; then
        echo ""
        warn "This will REPLACE all data in database '$DB_NAME'"
        echo "Backup file: $backup_file"
        echo "Target: $DB_HOST:$DB_PORT"
        echo ""
        read -p "Are you sure you want to continue? (yes/no): " confirm
        
        if [ "$confirm" != "yes" ]; then
            log "Restore cancelled by user"
            exit 0
        fi
    fi
    
    # Create pre-restore backup
    if [ "${SKIP_PRE_BACKUP:-false}" != "true" ]; then
        create_pre_restore_backup
    fi
    
    # Prepare backup file (decompress if needed)
    TEMP_FILE=$(prepare_backup_file "$backup_file")
    
    # Restore database
    restore_database "$TEMP_FILE"
    
    # Cleanup
    cleanup
    
    log "Database restore completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [backup_file]"
        echo "Restore Keycloak database from backup"
        echo ""
        echo "Arguments:"
        echo "  backup_file    Backup file name or 'latest' for most recent (default: latest)"
        echo ""
        echo "Environment variables:"
        echo "  POSTGRES_HOST: Database host (default: localhost)"
        echo "  POSTGRES_PORT: Database port (default: 5432)"
        echo "  POSTGRES_DB: Database name (default: keycloak)"
        echo "  POSTGRES_USER: Database user (default: keycloak)"
        echo "  POSTGRES_PASSWORD: Database password (default: keycloak)"
        echo "  BACKUP_DIR: Backup directory (default: ./backups)"
        echo "  FORCE_RESTORE: Skip confirmation (default: false)"
        echo "  SKIP_PRE_BACKUP: Skip pre-restore backup (default: false)"
        echo ""
        echo "Examples:"
        echo "  $0                              # Restore latest backup"
        echo "  $0 keycloak-backup-20231201.sql # Restore specific backup"
        echo "  FORCE_RESTORE=true $0          # Restore without confirmation"
        exit 0
        ;;
    --list)
        echo "Available backups:"
        find "${BACKUP_DIR:-./backups}" -name "keycloak-backup-*.sql*" -type f 2>/dev/null | sort || echo "No backups found"
        exit 0
        ;;
esac

# Check for required tools
for tool in pg_restore psql pg_isready; do
    if ! command -v $tool &> /dev/null; then
        error "$tool is required but not installed. Please install PostgreSQL client tools."
        exit 1
    fi
done

# Set trap for cleanup
trap cleanup EXIT

main "$@"