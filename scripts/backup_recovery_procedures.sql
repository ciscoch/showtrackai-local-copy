-- ============================================================================
-- BACKUP & RECOVERY PROCEDURES
-- Purpose: Comprehensive backup strategies and recovery procedures
-- Date: 2025-02-27
-- Author: Database Administrator
-- ============================================================================

-- ============================================================================
-- PART 1: BACKUP CONFIGURATION
-- ============================================================================

-- 1.1 Create backup schema for point-in-time recovery
CREATE SCHEMA IF NOT EXISTS backup_recovery;

-- 1.2 Create backup audit table
CREATE TABLE IF NOT EXISTS backup_recovery.backup_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    backup_type VARCHAR(50) NOT NULL,
    backup_status VARCHAR(20) NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    size_bytes BIGINT,
    table_count INTEGER,
    row_count BIGINT,
    error_message TEXT,
    metadata JSONB DEFAULT '{}',
    created_by VARCHAR(100) DEFAULT current_user
);

-- 1.3 Automated backup function
CREATE OR REPLACE FUNCTION backup_recovery.create_table_backup(
    p_table_name TEXT,
    p_backup_suffix TEXT DEFAULT NULL
) RETURNS TEXT AS $$
DECLARE
    v_backup_table_name TEXT;
    v_row_count BIGINT;
    v_backup_id UUID;
BEGIN
    -- Generate backup table name
    v_backup_table_name := 'backup_recovery.bak_' || p_table_name || '_' || 
                          COALESCE(p_backup_suffix, TO_CHAR(NOW(), 'YYYYMMDD_HH24MISS'));
    
    -- Log backup start
    INSERT INTO backup_recovery.backup_audit (backup_type, backup_status, metadata)
    VALUES ('table_backup', 'in_progress', 
            jsonb_build_object('source_table', p_table_name, 'backup_table', v_backup_table_name))
    RETURNING id INTO v_backup_id;
    
    -- Create backup table
    EXECUTE format('CREATE TABLE %s AS SELECT * FROM public.%I', v_backup_table_name, p_table_name);
    
    -- Get row count
    EXECUTE format('SELECT COUNT(*) FROM %s', v_backup_table_name) INTO v_row_count;
    
    -- Update backup audit
    UPDATE backup_recovery.backup_audit
    SET backup_status = 'completed',
        completed_at = NOW(),
        row_count = v_row_count
    WHERE id = v_backup_id;
    
    RETURN format('Backup created: %s with %s rows', v_backup_table_name, v_row_count);
EXCEPTION
    WHEN OTHERS THEN
        -- Log error
        UPDATE backup_recovery.backup_audit
        SET backup_status = 'failed',
            completed_at = NOW(),
            error_message = SQLERRM
        WHERE id = v_backup_id;
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- 1.4 Full database backup procedure
CREATE OR REPLACE FUNCTION backup_recovery.create_full_backup() 
RETURNS TABLE(backup_summary TEXT) AS $$
DECLARE
    v_table_name TEXT;
    v_backup_count INTEGER := 0;
    v_total_rows BIGINT := 0;
    v_backup_suffix TEXT;
BEGIN
    -- Generate unique backup suffix
    v_backup_suffix := TO_CHAR(NOW(), 'YYYYMMDD_HH24MISS');
    
    -- Backup all critical tables
    FOR v_table_name IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename IN ('animals', 'journal_entries', 'user_profiles', 
                         'feed_brands', 'journal_entry_ai_assessments', 'spar_runs')
    LOOP
        PERFORM backup_recovery.create_table_backup(v_table_name, v_backup_suffix);
        v_backup_count := v_backup_count + 1;
    END LOOP;
    
    RETURN QUERY
    SELECT format('Full backup completed: %s tables backed up with suffix %s', 
                  v_backup_count, v_backup_suffix);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 2: RECOVERY PROCEDURES
-- ============================================================================

-- 2.1 Point-in-time recovery function
CREATE OR REPLACE FUNCTION backup_recovery.restore_table(
    p_backup_table_name TEXT,
    p_target_table_name TEXT DEFAULT NULL,
    p_restore_mode TEXT DEFAULT 'replace'  -- 'replace', 'merge', 'append'
) RETURNS TEXT AS $$
DECLARE
    v_target_table TEXT;
    v_row_count BIGINT;
    v_restore_id UUID;
BEGIN
    -- Determine target table
    v_target_table := COALESCE(p_target_table_name, 
                               REPLACE(REPLACE(p_backup_table_name, 'backup_recovery.bak_', ''), 
                                      '_' || SUBSTRING(p_backup_table_name FROM '_[0-9]{8}_[0-9]{6}$'), ''));
    
    -- Log restore start
    INSERT INTO backup_recovery.backup_audit (backup_type, backup_status, metadata)
    VALUES ('table_restore', 'in_progress', 
            jsonb_build_object('backup_table', p_backup_table_name, 
                             'target_table', v_target_table,
                             'restore_mode', p_restore_mode))
    RETURNING id INTO v_restore_id;
    
    -- Execute restore based on mode
    CASE p_restore_mode
        WHEN 'replace' THEN
            -- Create temp table with current data
            EXECUTE format('CREATE TEMP TABLE temp_restore_backup AS SELECT * FROM public.%I', v_target_table);
            
            -- Truncate and restore
            EXECUTE format('TRUNCATE TABLE public.%I CASCADE', v_target_table);
            EXECUTE format('INSERT INTO public.%I SELECT * FROM %s', v_target_table, p_backup_table_name);
            
        WHEN 'merge' THEN
            -- Merge data (upsert)
            EXECUTE format('
                INSERT INTO public.%I 
                SELECT * FROM %s
                ON CONFLICT (id) DO UPDATE SET
                    updated_at = EXCLUDED.updated_at
            ', v_target_table, p_backup_table_name);
            
        WHEN 'append' THEN
            -- Simply append data
            EXECUTE format('INSERT INTO public.%I SELECT * FROM %s', v_target_table, p_backup_table_name);
    END CASE;
    
    -- Get restored row count
    EXECUTE format('SELECT COUNT(*) FROM public.%I', v_target_table) INTO v_row_count;
    
    -- Update audit
    UPDATE backup_recovery.backup_audit
    SET backup_status = 'completed',
        completed_at = NOW(),
        row_count = v_row_count
    WHERE id = v_restore_id;
    
    RETURN format('Restore completed: %s rows restored to %s', v_row_count, v_target_table);
EXCEPTION
    WHEN OTHERS THEN
        -- Log error and rollback
        UPDATE backup_recovery.backup_audit
        SET backup_status = 'failed',
            completed_at = NOW(),
            error_message = SQLERRM
        WHERE id = v_restore_id;
        
        -- Attempt to restore from temp backup if exists
        IF p_restore_mode = 'replace' THEN
            EXECUTE format('TRUNCATE TABLE public.%I CASCADE', v_target_table);
            EXECUTE format('INSERT INTO public.%I SELECT * FROM temp_restore_backup', v_target_table);
        END IF;
        
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- 2.2 Disaster recovery validation
CREATE OR REPLACE FUNCTION backup_recovery.validate_backup(
    p_backup_table_name TEXT
) RETURNS TABLE(
    validation_check TEXT,
    status TEXT,
    details TEXT
) AS $$
DECLARE
    v_row_count BIGINT;
    v_column_count INTEGER;
    v_has_primary_key BOOLEAN;
BEGIN
    -- Check if backup table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'backup_recovery' 
        AND table_name = REPLACE(p_backup_table_name, 'backup_recovery.', '')
    ) THEN
        RETURN QUERY SELECT 'Table Exists', 'FAILED', 'Backup table does not exist';
        RETURN;
    END IF;
    
    -- Check row count
    EXECUTE format('SELECT COUNT(*) FROM %s', p_backup_table_name) INTO v_row_count;
    RETURN QUERY SELECT 'Row Count', 'PASSED', format('%s rows in backup', v_row_count);
    
    -- Check column count
    SELECT COUNT(*) INTO v_column_count
    FROM information_schema.columns
    WHERE table_schema = 'backup_recovery'
    AND table_name = REPLACE(p_backup_table_name, 'backup_recovery.', '');
    RETURN QUERY SELECT 'Column Count', 'PASSED', format('%s columns in backup', v_column_count);
    
    -- Check for data integrity
    RETURN QUERY SELECT 'Data Integrity', 
                       CASE WHEN v_row_count > 0 THEN 'PASSED' ELSE 'WARNING' END,
                       CASE WHEN v_row_count > 0 
                            THEN 'Data present in backup' 
                            ELSE 'Backup is empty' 
                       END;
    
    -- Check for corrupted data (null IDs)
    EXECUTE format('SELECT COUNT(*) FROM %s WHERE id IS NULL', p_backup_table_name) INTO v_row_count;
    RETURN QUERY SELECT 'ID Integrity', 
                       CASE WHEN v_row_count = 0 THEN 'PASSED' ELSE 'FAILED' END,
                       format('%s rows with NULL IDs', v_row_count);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 3: AUTOMATED MAINTENANCE PROCEDURES
-- ============================================================================

-- 3.1 Automated VACUUM and ANALYZE
CREATE OR REPLACE FUNCTION backup_recovery.perform_maintenance() 
RETURNS TABLE(maintenance_log TEXT) AS $$
DECLARE
    v_table_name TEXT;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    -- Log start
    RETURN QUERY SELECT 'Starting maintenance at ' || NOW()::TEXT;
    
    -- Vacuum and analyze each table
    FOR v_table_name IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public'
    LOOP
        v_start_time := clock_timestamp();
        
        -- VACUUM ANALYZE
        EXECUTE format('VACUUM ANALYZE public.%I', v_table_name);
        
        v_end_time := clock_timestamp();
        
        RETURN QUERY 
        SELECT format('Maintained %s in %s ms', 
                     v_table_name, 
                     EXTRACT(MILLISECOND FROM v_end_time - v_start_time));
    END LOOP;
    
    -- Update statistics
    EXECUTE 'ANALYZE';
    
    RETURN QUERY SELECT 'Maintenance completed at ' || NOW()::TEXT;
END;
$$ LANGUAGE plpgsql;

-- 3.2 Automated cleanup of old backups
CREATE OR REPLACE FUNCTION backup_recovery.cleanup_old_backups(
    p_retention_days INTEGER DEFAULT 30
) RETURNS TABLE(cleanup_summary TEXT) AS $$
DECLARE
    v_table_name TEXT;
    v_dropped_count INTEGER := 0;
BEGIN
    -- Find and drop old backup tables
    FOR v_table_name IN 
        SELECT table_name 
        FROM information_schema.tables
        WHERE table_schema = 'backup_recovery'
        AND table_name LIKE 'bak_%'
        AND table_name ~ '_[0-9]{8}_[0-9]{6}$'
        AND TO_DATE(SUBSTRING(table_name FROM '_([0-9]{8})_[0-9]{6}$'), 'YYYYMMDD') < 
            CURRENT_DATE - INTERVAL '1 day' * p_retention_days
    LOOP
        EXECUTE format('DROP TABLE backup_recovery.%I', v_table_name);
        v_dropped_count := v_dropped_count + 1;
    END LOOP;
    
    -- Clean audit logs
    DELETE FROM backup_recovery.backup_audit
    WHERE started_at < NOW() - INTERVAL '1 day' * (p_retention_days * 2);
    
    RETURN QUERY 
    SELECT format('Cleanup completed: %s old backup tables removed', v_dropped_count);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 4: MONITORING & ALERTING
-- ============================================================================

-- 4.1 Health check function
CREATE OR REPLACE FUNCTION backup_recovery.health_check()
RETURNS TABLE(
    check_name TEXT,
    status TEXT,
    message TEXT
) AS $$
BEGIN
    -- Check last backup time
    RETURN QUERY
    SELECT 
        'Last Backup',
        CASE 
            WHEN MAX(completed_at) > NOW() - INTERVAL '24 hours' THEN 'OK'
            WHEN MAX(completed_at) > NOW() - INTERVAL '48 hours' THEN 'WARNING'
            ELSE 'CRITICAL'
        END,
        'Last backup: ' || COALESCE(MAX(completed_at)::TEXT, 'Never')
    FROM backup_recovery.backup_audit
    WHERE backup_status = 'completed';
    
    -- Check backup success rate
    RETURN QUERY
    WITH backup_stats AS (
        SELECT 
            COUNT(*) FILTER (WHERE backup_status = 'completed') as successful,
            COUNT(*) as total
        FROM backup_recovery.backup_audit
        WHERE started_at > NOW() - INTERVAL '7 days'
    )
    SELECT 
        'Backup Success Rate',
        CASE 
            WHEN successful::FLOAT / NULLIF(total, 0) > 0.95 THEN 'OK'
            WHEN successful::FLOAT / NULLIF(total, 0) > 0.8 THEN 'WARNING'
            ELSE 'CRITICAL'
        END,
        format('%s/%s backups successful (%.1f%%)', 
               successful, total, 
               100.0 * successful / NULLIF(total, 0))
    FROM backup_stats;
    
    -- Check disk space
    RETURN QUERY
    SELECT 
        'Disk Space',
        CASE 
            WHEN pg_database_size(current_database()) < 5368709120 THEN 'OK'  -- 5GB
            WHEN pg_database_size(current_database()) < 10737418240 THEN 'WARNING'  -- 10GB
            ELSE 'CRITICAL'
        END,
        'Database size: ' || pg_size_pretty(pg_database_size(current_database()));
    
    -- Check table bloat
    RETURN QUERY
    WITH bloat_check AS (
        SELECT MAX(n_dead_tup) as max_dead
        FROM pg_stat_user_tables
        WHERE schemaname = 'public'
    )
    SELECT 
        'Table Bloat',
        CASE 
            WHEN max_dead < 1000 THEN 'OK'
            WHEN max_dead < 10000 THEN 'WARNING'
            ELSE 'CRITICAL'
        END,
        'Max dead tuples: ' || max_dead
    FROM bloat_check;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 5: RECOVERY TESTING PROCEDURES
-- ============================================================================

-- 5.1 Disaster recovery drill
CREATE OR REPLACE FUNCTION backup_recovery.disaster_recovery_drill()
RETURNS TABLE(drill_step TEXT, result TEXT) AS $$
DECLARE
    v_test_table TEXT := 'dr_test_' || TO_CHAR(NOW(), 'YYYYMMDD_HH24MISS');
    v_backup_name TEXT;
BEGIN
    -- Step 1: Create test data
    EXECUTE format('CREATE TABLE %s AS SELECT * FROM animals LIMIT 10', v_test_table);
    RETURN QUERY SELECT 'Create test data', 'SUCCESS';
    
    -- Step 2: Create backup
    v_backup_name := backup_recovery.create_table_backup(v_test_table);
    RETURN QUERY SELECT 'Create backup', v_backup_name;
    
    -- Step 3: Corrupt test data
    EXECUTE format('DELETE FROM %s WHERE id IN (SELECT id FROM %s LIMIT 5)', 
                   v_test_table, v_test_table);
    RETURN QUERY SELECT 'Simulate data loss', 'SUCCESS';
    
    -- Step 4: Restore from backup
    PERFORM backup_recovery.restore_table('backup_recovery.bak_' || v_test_table, v_test_table);
    RETURN QUERY SELECT 'Restore from backup', 'SUCCESS';
    
    -- Step 5: Validate restore
    RETURN QUERY 
    SELECT 'Validation', 
           CASE 
               WHEN (SELECT COUNT(*) FROM dr_test_20250227_120000) = 10 
               THEN 'SUCCESS - All data recovered'
               ELSE 'FAILED - Data mismatch'
           END;
    
    -- Cleanup
    EXECUTE format('DROP TABLE IF EXISTS %s', v_test_table);
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT 'Drill failed', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 6: SCHEDULED JOBS (To be set up in Supabase Dashboard)
-- ============================================================================

-- Daily backup job (run at 2 AM)
-- SELECT backup_recovery.create_full_backup();

-- Weekly maintenance (run Sunday at 3 AM)
-- SELECT backup_recovery.perform_maintenance();

-- Monthly cleanup (run first of month at 4 AM)
-- SELECT backup_recovery.cleanup_old_backups(30);

-- Daily health check (run every 6 hours)
-- SELECT * FROM backup_recovery.health_check();

-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================

/*
-- Create immediate backup of critical table
SELECT backup_recovery.create_table_backup('animals');

-- Create full database backup
SELECT * FROM backup_recovery.create_full_backup();

-- Restore from specific backup
SELECT backup_recovery.restore_table('backup_recovery.bak_animals_20250227_120000', 'animals', 'replace');

-- Validate backup integrity
SELECT * FROM backup_recovery.validate_backup('backup_recovery.bak_animals_20250227_120000');

-- Run maintenance
SELECT * FROM backup_recovery.perform_maintenance();

-- Check system health
SELECT * FROM backup_recovery.health_check();

-- Run disaster recovery drill
SELECT * FROM backup_recovery.disaster_recovery_drill();

-- View backup history
SELECT * FROM backup_recovery.backup_audit 
ORDER BY started_at DESC 
LIMIT 20;
*/

-- ============================================================================
-- End of Backup & Recovery Procedures
-- ============================================================================