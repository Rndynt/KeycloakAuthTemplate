#!/bin/bash

# Backup Keycloak Database Script
# Creates timestamped backup of PostgreSQL database

set -euo pipefail

# Configuration
DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_NAME="${POSTGRES_DB:-keycloak}"
DB_USER="${POSTGRES_USER:-keycloak}"
DB_PASSWORD="${POSTGRES_PASSWORD:-keycloak}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS="${RETENTION_DAYS:-30}"

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

# Create backup directory
create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        log "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
    fi
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

# Create database backup
create_backup() {
    local backup_file="$1"
    
    log "Creating database backup..."
    log "Database: $DB_NAME"
    log "Output: $backup_file"
    
    export PGPASSWORD="$DB_PASSWORD"
    
    if pg_dump \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        --verbose \
        --clean \
        --no-owner \
        --no-privileges \
        --format=custom \
        --file="$backup_file"; then
        
        log "Backup created successfully!"
        
        # Get file size
        local size
        size=$(du -h "$backup_file" | cut -f1)
        log "Backup size: $size"
        
    else
        error "Backup failed!"
        exit 1
    fi
}

# Compress backup (optional)
compress_backup() {
    local backup_file="$1"
    local compressed_file="${backup_file}.gz"
    
    if [ "${COMPRESS_BACKUP:-true}" = "true" ]; then
        log "Compressing backup..."
        
        if gzip "$backup_file"; then
            log "Backup compressed: $compressed_file"
            echo "$compressed_file"
        else
            warn "Compression failed, keeping uncompressed backup"
            echo "$backup_file"
        fi
    else
        echo "$backup_file"
    fi
}

# Clean old backups
cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days..."
    
    find "$BACKUP_DIR" -name "keycloak-backup-*.sql*" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    
    local remaining
    remaining=$(find "$BACKUP_DIR" -name "keycloak-backup-*.sql*" -type f | wc -l)
    log "Remaining backups: $remaining"
}

# Create backup info file
create_backup_info() {
    local backup_file="$1"
    local info_file="${backup_file}.info"
    
    cat > "$info_file" << EOF
Keycloak Database Backup Information
====================================
Date: $(date)
Database: $DB_NAME
Host: $DB_HOST:$DB_PORT
User: $DB_USER
Backup File: $(basename "$backup_file")
Size: $(du -h "$backup_file" 2>/dev/null | cut -f1 || echo "Unknown")

Restore Command:
./scripts/restore-db.sh "$(basename "$backup_file")"

Docker Restore Command:
docker exec -i keycloak-db pg_restore -h localhost -p 5432 -U keycloak -d keycloak --clean --if-exists < "$(basename "$backup_file")"
EOF
    
    log "Backup info created: $info_file"
}

# Main execution
main() {
    log "Starting database backup process..."
    log "Database: $DB_NAME@$DB_HOST:$DB_PORT"
    log "Backup directory: $BACKUP_DIR"
    
    # Create backup directory
    create_backup_dir
    
    # Test connection
    test_connection
    
    # Define backup file
    local backup_file="${BACKUP_DIR}/keycloak-backup-${TIMESTAMP}.sql"
    
    # Create backup
    create_backup "$backup_file"
    
    # Compress if requested
    backup_file=$(compress_backup "$backup_file")
    
    # Create info file
    create_backup_info "$backup_file"
    
    # Cleanup old backups
    if [ "${CLEANUP_OLD:-true}" = "true" ]; then
        cleanup_old_backups
    fi
    
    log "Backup process completed successfully!"
    log "Backup file: $backup_file"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0"
        echo "Create backup of Keycloak database"
        echo ""
        echo "Environment variables:"
        echo "  POSTGRES_HOST: Database host (default: localhost)"
        echo "  POSTGRES_PORT: Database port (default: 5432)"
        echo "  POSTGRES_DB: Database name (default: keycloak)"
        echo "  POSTGRES_USER: Database user (default: keycloak)"
        echo "  POSTGRES_PASSWORD: Database password (default: keycloak)"
        echo "  BACKUP_DIR: Backup directory (default: ./backups)"
        echo "  RETENTION_DAYS: Keep backups for N days (default: 30)"
        echo "  COMPRESS_BACKUP: Compress backups (default: true)"
        echo "  CLEANUP_OLD: Clean old backups (default: true)"
        exit 0
        ;;
esac

# Check for required tools
for tool in pg_dump pg_isready; do
    if ! command -v $tool &> /dev/null; then
        error "$tool is required but not installed. Please install PostgreSQL client tools."
        exit 1
    fi
done

main "$@"