# Database Operations Runbook

## ShowTrackAI Database Administration Guide
**Version:** 1.0  
**Date:** February 27, 2025  
**Author:** Database Administrator  
**Criticality:** Production Database

---

## Table of Contents
1. [System Overview](#system-overview)
2. [Emergency Contacts](#emergency-contacts)
3. [Daily Operations](#daily-operations)
4. [Emergency Procedures](#emergency-procedures)
5. [Backup & Recovery](#backup-recovery)
6. [Performance Troubleshooting](#performance-troubleshooting)
7. [Security Procedures](#security-procedures)
8. [Maintenance Windows](#maintenance-windows)
9. [Monitoring & Alerts](#monitoring-alerts)
10. [Common Issues & Solutions](#common-issues-solutions)

---

## System Overview

### Database Architecture
- **Database System:** PostgreSQL (via Supabase)
- **Primary Tables:** animals, journal_entries, user_profiles, feed_brands, spar_runs
- **Critical Features:** Real-time subscriptions, RLS policies, AI assessment integration
- **Connection Method:** Supabase client library with connection pooling
- **Current Load:** ~1000 active users, ~10K animals tracked

### Key Metrics Targets
- **Availability:** 99.9% uptime
- **Response Time:** < 200ms for 95% of queries
- **Cache Hit Ratio:** > 95%
- **Recovery Time Objective (RTO):** 1 hour
- **Recovery Point Objective (RPO):** 15 minutes

---

## Emergency Contacts

| Role | Contact | When to Call |
|------|---------|--------------|
| Database Admin | On-call DBA | Database down, data corruption |
| Supabase Support | support@supabase.io | Platform issues |
| Application Team | Dev Team Slack | Application errors |
| Security Team | Security Channel | Data breach, unauthorized access |

---

## Daily Operations

### Morning Health Check (9 AM)
```sql
-- Run comprehensive health check
SELECT * FROM performance.dashboard();
SELECT * FROM performance.check_alerts();
SELECT * FROM backup_recovery.health_check();
```

### Hourly Monitoring
```sql
-- Check active connections and queries
SELECT * FROM performance.active_queries;
SELECT * FROM performance.connection_pool_status;
```

### End of Day Tasks (6 PM)
```sql
-- Review slow queries
SELECT * FROM performance.slow_query_log 
WHERE captured_at > CURRENT_DATE 
ORDER BY execution_time_ms DESC LIMIT 10;

-- Check for maintenance needs
SELECT * FROM performance.table_access_patterns 
WHERE hot_update_ratio < 90;
```

---

## Emergency Procedures

### 🚨 Database Down
1. **Immediate Actions:**
   ```sql
   -- Check connection from multiple sources
   psql -h [host] -U [user] -d [database]
   
   -- Check Supabase dashboard status
   -- https://status.supabase.com
   ```

2. **Diagnostics:**
   ```sql
   -- If accessible, check for locks
   SELECT * FROM pg_stat_activity WHERE state = 'active';
   
   -- Check for blocking queries
   SELECT blocked_locks.pid AS blocked_pid,
          blocking_locks.pid AS blocking_pid
   FROM pg_catalog.pg_locks blocked_locks
   JOIN pg_catalog.pg_locks blocking_locks 
     ON blocking_locks.locktype = blocked_locks.locktype
   WHERE NOT blocked_locks.granted;
   ```

3. **Recovery Steps:**
   - Contact Supabase support if platform issue
   - Terminate blocking connections if needed
   - Initiate failover if primary is unrecoverable

### 🔥 High Load Emergency
1. **Identify Problem:**
   ```sql
   -- Find resource-intensive queries
   SELECT pid, now() - query_start AS duration, query 
   FROM pg_stat_activity 
   WHERE state = 'active' 
   ORDER BY duration DESC;
   ```

2. **Immediate Mitigation:**
   ```sql
   -- Kill long-running queries (> 30 minutes)
   SELECT * FROM performance.kill_long_queries(30);
   
   -- Force connection pool reset
   SELECT pg_terminate_backend(pid) 
   FROM pg_stat_activity 
   WHERE state = 'idle in transaction' 
   AND state_change < NOW() - INTERVAL '10 minutes';
   ```

3. **Scale Resources:**
   - Upgrade Supabase plan if needed
   - Implement read replicas
   - Enable connection pooling

### 💾 Data Corruption
1. **Stop All Write Operations:**
   ```sql
   -- Revoke write permissions temporarily
   REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM authenticated;
   ```

2. **Assess Damage:**
   ```sql
   -- Check data integrity
   SELECT * FROM backup_recovery.validate_backup('last_known_good_backup');
   ```

3. **Recovery:**
   ```sql
   -- Restore from backup
   SELECT backup_recovery.restore_table('backup_table_name', 'target_table', 'replace');
   ```

---

## Backup & Recovery

### Backup Schedule
| Type | Frequency | Retention | Location |
|------|-----------|-----------|----------|
| Full Backup | Daily 2 AM | 30 days | backup_recovery schema |
| Incremental | Every 6 hours | 7 days | WAL logs |
| Snapshot | Weekly Sunday | 90 days | External storage |

### Backup Procedures
```sql
-- Manual full backup
SELECT * FROM backup_recovery.create_full_backup();

-- Backup specific table
SELECT backup_recovery.create_table_backup('animals');

-- Verify backup integrity
SELECT * FROM backup_recovery.validate_backup('backup_recovery.bak_animals_20250227');
```

### Recovery Procedures
```sql
-- Point-in-time recovery
SELECT backup_recovery.restore_table(
    'backup_recovery.bak_animals_20250227_020000', 
    'animals', 
    'replace'
);

-- Disaster recovery drill (run monthly)
SELECT * FROM backup_recovery.disaster_recovery_drill();
```

---

## Performance Troubleshooting

### Slow Query Investigation
1. **Identify Slow Queries:**
   ```sql
   SELECT * FROM pg_stat_statements 
   WHERE mean_exec_time > 1000 -- queries over 1 second
   ORDER BY mean_exec_time DESC LIMIT 10;
   ```

2. **Analyze Query Plan:**
   ```sql
   EXPLAIN (ANALYZE, BUFFERS) 
   [paste slow query here];
   ```

3. **Optimization Actions:**
   ```sql
   -- Get index recommendations
   SELECT * FROM performance.recommend_indexes();
   
   -- Analyze specific query
   SELECT * FROM performance.analyze_query('[query_text]');
   ```

### Cache Performance Issues
```sql
-- Check cache hit ratio
SELECT * FROM performance.optimize_cache();

-- If cache hit ratio < 90%:
-- 1. Increase shared_buffers
-- 2. Optimize frequently accessed tables
-- 3. Review and remove unused indexes
```

### Connection Pool Exhaustion
```sql
-- Check pool status
SELECT * FROM performance.connection_pool_status;

-- Reset idle connections
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE state = 'idle' 
AND state_change < NOW() - INTERVAL '30 minutes';
```

---

## Security Procedures

### Regular Security Audit
```sql
-- Check RLS status (run daily)
SELECT tablename, 
       CASE WHEN rowsecurity THEN '✅' ELSE '❌ CRITICAL' END as rls_enabled
FROM pg_tables WHERE schemaname = 'public';

-- Review access logs
SELECT * FROM data_access_audit 
WHERE timestamp > NOW() - INTERVAL '24 hours'
AND access_type = 'cross_user_access';
```

### Suspicious Activity Response
1. **Identify Threat:**
   ```sql
   -- Check for unusual access patterns
   SELECT user_id, COUNT(*) as access_count, 
          array_agg(DISTINCT resource_type) as accessed_resources
   FROM data_access_audit
   WHERE timestamp > NOW() - INTERVAL '1 hour'
   GROUP BY user_id
   HAVING COUNT(*) > 1000;
   ```

2. **Immediate Response:**
   ```sql
   -- Revoke access for suspicious user
   REVOKE ALL ON ALL TABLES IN SCHEMA public FROM suspicious_user;
   
   -- Force logout
   SELECT pg_terminate_backend(pid) 
   FROM pg_stat_activity 
   WHERE usename = 'suspicious_user';
   ```

---

## Maintenance Windows

### Weekly Maintenance (Sunday 3 AM)
```sql
-- Run VACUUM ANALYZE
SELECT * FROM backup_recovery.perform_maintenance();

-- Update statistics
ANALYZE;

-- Clean old backups
SELECT backup_recovery.cleanup_old_backups(30);
```

### Monthly Tasks (First Sunday)
```sql
-- Reindex critical tables
REINDEX TABLE animals;
REINDEX TABLE journal_entries;

-- Review and drop unused indexes
SELECT * FROM performance.unused_indexes;

-- Disaster recovery drill
SELECT * FROM backup_recovery.disaster_recovery_drill();
```

---

## Monitoring & Alerts

### Alert Thresholds
| Metric | Warning | Critical | Action |
|--------|---------|----------|---------|
| Cache Hit Ratio | < 90% | < 80% | Increase shared_buffers |
| Active Connections | > 50 | > 80 | Scale connection pool |
| Longest Query | > 5 min | > 10 min | Kill query, investigate |
| Dead Tuples | > 10K | > 50K | Run VACUUM |
| DB Size | > 5 GB | > 10 GB | Archive old data |

### Alert Response
```sql
-- Check current alerts
SELECT * FROM performance.check_alerts();

-- Respond based on alert level
-- WARNING: Monitor closely, plan remediation
-- CRITICAL: Immediate action required
```

---

## Common Issues & Solutions

### Issue: "PGRST204" Error
**Symptom:** Column not found errors in API calls  
**Solution:**
```sql
-- Run emergency fix
\i /path/to/20250227_emergency_quick_fix.sql

-- Force schema reload
NOTIFY pgrst, 'reload schema';
```

### Issue: High Table Bloat
**Symptom:** Slow queries, large dead tuple count  
**Solution:**
```sql
-- Check bloat
SELECT * FROM performance.table_bloat_analysis;

-- Run aggressive vacuum
VACUUM (FULL, ANALYZE) table_name;
```

### Issue: Connection Refused
**Symptom:** Cannot connect to database  
**Solution:**
1. Check Supabase dashboard status
2. Verify connection string
3. Check IP allowlist in Supabase settings
4. Contact Supabase support if persistent

### Issue: Slow Animal Queries
**Symptom:** Animal list/search taking > 1 second  
**Solution:**
```sql
-- Create missing indexes
CREATE INDEX idx_animals_user_species ON animals(user_id, species);
CREATE INDEX idx_animals_created_at ON animals(created_at DESC);

-- Update statistics
ANALYZE animals;
```

---

## Automation Scripts

### Daily Health Report
```bash
#!/bin/bash
# Save as: daily_health_check.sh

psql $DATABASE_URL -f /scripts/database_operations_audit.sql > /reports/daily_$(date +%Y%m%d).txt
psql $DATABASE_URL -c "SELECT * FROM performance.dashboard();" >> /reports/daily_$(date +%Y%m%d).txt
psql $DATABASE_URL -c "SELECT * FROM backup_recovery.health_check();" >> /reports/daily_$(date +%Y%m%d).txt

# Send alert if issues found
if grep -q "CRITICAL\|FAILED" /reports/daily_$(date +%Y%m%d).txt; then
    mail -s "Database Alert - Critical Issues Found" dba@company.com < /reports/daily_$(date +%Y%m%d).txt
fi
```

### Automated Backup
```bash
#!/bin/bash
# Save as: automated_backup.sh
# Run via cron: 0 2 * * * /path/to/automated_backup.sh

psql $DATABASE_URL -c "SELECT * FROM backup_recovery.create_full_backup();"
psql $DATABASE_URL -c "SELECT * FROM backup_recovery.cleanup_old_backups(30);"
```

---

## Post-Incident Review Template

### Incident Details
- **Date/Time:** 
- **Duration:** 
- **Impact:** 
- **Root Cause:** 

### Timeline
1. Detection:
2. Response:
3. Resolution:
4. Verification:

### Lessons Learned
- What went well:
- What could improve:
- Action items:

### Prevention Measures
- Technical changes:
- Process improvements:
- Monitoring additions:

---

## Quick Reference Commands

```sql
-- Show database size
SELECT pg_size_pretty(pg_database_size(current_database()));

-- Active connections
SELECT COUNT(*) FROM pg_stat_activity;

-- Kill specific PID
SELECT pg_terminate_backend(12345);

-- Force schema reload (Supabase)
NOTIFY pgrst, 'reload schema';

-- Emergency maintenance mode
ALTER DATABASE showtrack SET default_transaction_read_only = true;

-- Exit maintenance mode
ALTER DATABASE showtrack SET default_transaction_read_only = false;

-- Check for locks
SELECT * FROM pg_locks WHERE NOT granted;

-- Table sizes
SELECT tablename, pg_size_pretty(pg_total_relation_size(tablename::regclass)) 
FROM pg_tables WHERE schemaname = 'public' ORDER BY 2 DESC;
```

---

## Appendix: File Locations

| File Type | Location |
|-----------|----------|
| Audit Scripts | `/scripts/database_operations_audit.sql` |
| Backup Procedures | `/scripts/backup_recovery_procedures.sql` |
| Performance Scripts | `/scripts/performance_monitoring.sql` |
| Migration Files | `/supabase/migrations/` |
| Emergency Fixes | `/supabase/migrations/20250227_emergency_quick_fix.sql` |

---

**Remember:** When in doubt, prioritize data integrity over performance. Always test in development first when possible.

**Last Updated:** February 27, 2025  
**Next Review:** March 27, 2025