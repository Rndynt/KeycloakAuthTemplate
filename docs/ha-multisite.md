# High Availability and Multi-Site Deployment Guide

## Overview

This guide covers deploying Keycloak in high-availability configurations, backup/restore procedures, key rotation, and comprehensive monitoring for production environments.

## High Availability Architecture

### Single-Site HA

```yaml
# Minimum production setup
keycloak:
  replicaCount: 2
  resources:
    requests:
      cpu: "1"
      memory: "1Gi"
    limits:
      cpu: "2"
      memory: "2Gi"

postgresql:
  architecture: replication
  primary:
    persistence:
      size: "100Gi"
  readReplicas:
    replicaCount: 1
```

### Multi-Site Active-Passive

For disaster recovery with geographic distribution:

**Primary Site (Active):**
- Full Keycloak deployment with database
- Real-time backup to secondary site
- Active monitoring and alerting

**Secondary Site (Passive):**
- Standby Keycloak deployment (scaled to 0)
- Database replica with continuous replication
- Ready for quick failover

### Multi-Site Active-Active

For global load distribution:

**Requirements:**
- Shared database or cross-site replication
- Session affinity or distributed sessions
- Consistent configuration across sites
- Global load balancer

## Database High Availability

### PostgreSQL Configuration

```yaml
postgresql:
  architecture: replication
  auth:
    existingSecret: postgresql-credentials
  
  primary:
    persistence:
      enabled: true
      size: "100Gi"
      storageClass: "fast-ssd"
    
    extraEnvVars:
      - name: POSTGRESQL_SYNCHRONOUS_COMMIT
        value: "on"
      - name: POSTGRESQL_WAL_LEVEL
        value: "replica"
      - name: POSTGRESQL_MAX_WAL_SENDERS
        value: "5"
    
    resources:
      requests:
        cpu: "2"
        memory: "4Gi"
      limits:
        cpu: "4"
        memory: "8Gi"
  
  readReplicas:
    replicaCount: 2
    persistence:
      enabled: true
      size: "100Gi"
    resources:
      requests:
        cpu: "1"
        memory: "2Gi"
```

### External Database (Recommended for Production)

Use managed database services:
- **AWS RDS PostgreSQL** with Multi-AZ
- **Google Cloud SQL** with HA configuration
- **Azure Database for PostgreSQL** with zone redundancy

```yaml
# External database configuration
keycloak:
  extraEnv:
    - name: KC_DB_URL
      value: "jdbc:postgresql://your-db-endpoint:5432/keycloak"
    - name: KC_DB_USERNAME
      valueFrom:
        secretKeyRef:
          name: database-credentials
          key: username
    - name: KC_DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: database-credentials
          key: password
```

## Backup and Restore

### Automated Database Backup

```bash
#!/bin/bash
# scripts/backup-production.sh

set -euo pipefail

BACKUP_DIR="/opt/backups/keycloak"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="keycloak_backup_${TIMESTAMP}.sql"

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Database backup
pg_dump \
  --host="${DB_HOST}" \
  --port="${DB_PORT}" \
  --username="${DB_USER}" \
  --dbname="${DB_NAME}" \
  --format=custom \
  --compress=9 \
  --file="${BACKUP_DIR}/${BACKUP_FILE}"

# Verify backup
pg_restore --list "${BACKUP_DIR}/${BACKUP_FILE}" > /dev/null

# Upload to S3/cloud storage
aws s3 cp "${BACKUP_DIR}/${BACKUP_FILE}" "s3://your-backup-bucket/keycloak/"

# Cleanup old local backups (keep last 7 days)
find "${BACKUP_DIR}" -name "keycloak_backup_*.sql" -mtime +7 -delete

echo "Backup completed: ${BACKUP_FILE}"
```

### Kubernetes CronJob for Backups

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: keycloak-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:15
            command:
            - /bin/bash
            - -c
            - |
              pg_dump \
                --host=$DB_HOST \
                --port=$DB_PORT \
                --username=$DB_USER \
                --dbname=$DB_NAME \
                --format=custom \
                --compress=9 \
                --file=/backup/keycloak_$(date +%Y%m%d_%H%M%S).sql
            env:
            - name: DB_HOST
              value: "postgresql-primary"
            - name: DB_PORT
              value: "5432"
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: postgresql-credentials
                  key: username
            - name: DB_NAME
              value: "keycloak"
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgresql-credentials
                  key: password
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-pvc
          restartPolicy: OnFailure
```

### Restore Procedure

```bash
#!/bin/bash
# scripts/restore-production.sh

set -euo pipefail

BACKUP_FILE="${1:?Backup file required}"

# Validate backup file
if [[ ! -f "${BACKUP_FILE}" ]]; then
  echo "Backup file not found: ${BACKUP_FILE}"
  exit 1
fi

# Verify backup integrity
pg_restore --list "${BACKUP_FILE}" > /dev/null
echo "Backup file verified: ${BACKUP_FILE}"

# Stop Keycloak instances
kubectl scale deployment keycloak --replicas=0

# Wait for shutdown
kubectl wait --for=condition=ready pod -l app=keycloak --timeout=300s || true

# Drop and recreate database (DANGEROUS - requires confirmation)
read -p "This will destroy the current database. Continue? (yes/no): " -r
if [[ $REPLY != "yes" ]]; then
  echo "Restore cancelled"
  exit 1
fi

# Restore database
psql -h "${DB_HOST}" -U "${DB_USER}" -c "DROP DATABASE IF EXISTS keycloak;"
psql -h "${DB_HOST}" -U "${DB_USER}" -c "CREATE DATABASE keycloak;"
pg_restore \
  --host="${DB_HOST}" \
  --port="${DB_PORT}" \
  --username="${DB_USER}" \
  --dbname="keycloak" \
  --clean \
  --if-exists \
  "${BACKUP_FILE}"

# Restart Keycloak
kubectl scale deployment keycloak --replicas=2

echo "Restore completed successfully"
```

## Key Rotation

### Certificate Rotation

```bash
#!/bin/bash
# scripts/rotate-certificates.sh

# Generate new certificate
openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
  -keyout /tmp/tls.key \
  -out /tmp/tls.crt \
  -subj "/CN=auth.yourdomain.com"

# Update Kubernetes secret
kubectl create secret tls keycloak-tls \
  --cert=/tmp/tls.crt \
  --key=/tmp/tls.key \
  --dry-run=client -o yaml | kubectl apply -f -

# Rolling restart
kubectl rollout restart deployment keycloak

# Cleanup
rm -f /tmp/tls.key /tmp/tls.crt
```

### Database Password Rotation

```bash
#!/bin/bash
# scripts/rotate-db-password.sh

NEW_PASSWORD=$(openssl rand -base64 32)

# Update database password
psql -h "${DB_HOST}" -U postgres -c "ALTER USER keycloak PASSWORD '${NEW_PASSWORD}';"

# Update Kubernetes secret
kubectl patch secret postgresql-credentials \
  -p="{\"data\":{\"password\":\"$(echo -n ${NEW_PASSWORD} | base64)\"}}"

# Rolling restart
kubectl rollout restart deployment keycloak

echo "Database password rotated successfully"
```

## Monitoring and Observability

### Prometheus Metrics

```yaml
# ServiceMonitor for Prometheus
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: keycloak-metrics
spec:
  selector:
    matchLabels:
      app: keycloak
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
```

### Key Metrics to Monitor

```yaml
# alerts.yaml
groups:
- name: keycloak
  rules:
  - alert: KeycloakDown
    expr: up{job="keycloak"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Keycloak instance is down"
  
  - alert: KeycloakHighMemoryUsage
    expr: container_memory_usage_bytes{pod=~"keycloak-.*"} / container_spec_memory_limit_bytes > 0.8
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Keycloak high memory usage"
  
  - alert: KeycloakDatabaseConnectionFails
    expr: keycloak_database_connections_total{state="failed"} > 10
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "Keycloak database connection failures"
  
  - alert: KeycloakSlowResponse
    expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job="keycloak"}[5m])) > 2
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Keycloak slow response times"
```

### Log Aggregation

```yaml
# Fluentd configuration for log collection
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-keycloak-config
data:
  fluent.conf: |
    <source>
      @type tail
      path /var/log/containers/keycloak-*.log
      pos_file /var/log/fluentd-keycloak.log.pos
      tag keycloak
      format json
    </source>
    
    <filter keycloak>
      @type parser
      key_name message
      reserve_data true
      <parse>
        @type json
      </parse>
    </filter>
    
    <match keycloak>
      @type elasticsearch
      host elasticsearch.logging.svc.cluster.local
      port 9200
      index_name keycloak-logs
      type_name _doc
    </match>
```

## Disaster Recovery Procedures

### RTO and RPO Targets

- **RTO (Recovery Time Objective)**: 15 minutes
- **RPO (Recovery Point Objective)**: 1 hour

### Failover Checklist

1. **Detect Failure**
   - Monitor alerts indicate primary site down
   - Manual verification of services

2. **Initiate Failover**
   ```bash
   # Switch DNS to secondary site
   aws route53 change-resource-record-sets \
     --hosted-zone-id Z1234567890 \
     --change-batch file://failover-dns.json
   
   # Scale up secondary site
   kubectl --context=secondary scale deployment keycloak --replicas=2
   ```

3. **Verify Recovery**
   - Health checks pass
   - Authentication flows work
   - Monitor error rates

4. **Communication**
   - Update status page
   - Notify stakeholders
   - Document incident

### Testing DR Procedures

```bash
#!/bin/bash
# scripts/test-disaster-recovery.sh

echo "Starting DR test..."

# 1. Create test backup
./scripts/backup-production.sh

# 2. Deploy to staging environment
kubectl --context=staging apply -f helm/templates/

# 3. Restore test backup
./scripts/restore-production.sh latest_backup.sql

# 4. Run smoke tests
curl -f https://auth-staging.yourdomain.com/health || exit 1

# 5. Test authentication flow
./scripts/test-auth-flow.sh staging

echo "DR test completed successfully"
```

## Security Considerations

### Network Security

```yaml
# Network policies
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: keycloak-network-policy
spec:
  podSelector:
    matchLabels:
      app: keycloak
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: database
    ports:
    - protocol: TCP
      port: 5432
```

### Secrets Management

```yaml
# External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.company.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "keycloak"
```

## Performance Tuning

### JVM Settings

```yaml
keycloak:
  extraEnv:
    - name: JAVA_OPTS
      value: >-
        -Xms2g -Xmx4g
        -XX:+UseG1GC
        -XX:MaxGCPauseMillis=200
        -XX:+UnlockExperimentalVMOptions
        -XX:+UseCGroupMemoryLimitForHeap
        -Djava.net.preferIPv4Stack=true
```

### Database Tuning

```sql
-- PostgreSQL optimization
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET random_page_cost = 1.1;
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
SELECT pg_reload_conf();
```

## Best Practices Summary

1. **Always use external managed databases** for production
2. **Implement automated backups** with point-in-time recovery
3. **Test disaster recovery procedures** regularly
4. **Monitor key metrics** and set up alerting
5. **Rotate certificates and passwords** regularly
6. **Use infrastructure as code** for reproducible deployments
7. **Implement proper network security** with policies
8. **Use secrets management** solutions
9. **Plan for capacity** and performance testing
10. **Document all procedures** and keep them updated