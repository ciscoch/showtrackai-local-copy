-- ============================================================================
-- PERFORMANCE MONITORING & OPTIMIZATION
-- Purpose: Real-time performance monitoring and optimization procedures
-- Date: 2025-02-27
-- Author: Database Administrator
-- ============================================================================

-- ============================================================================
-- PART 1: PERFORMANCE MONITORING VIEWS
-- ============================================================================

-- 1.1 Create monitoring schema
CREATE SCHEMA IF NOT EXISTS performance;

-- 1.2 Real-time query performance view
CREATE OR REPLACE VIEW performance.active_queries AS
SELECT 
    pid,
    usename,
    application_name,
    client_addr,
    backend_start,
    xact_start,
    query_start,
    state,
    wait_event_type,
    wait_event,
    EXTRACT(EPOCH FROM (NOW() - query_start))::INTEGER as query_duration_seconds,
    LEFT(query, 200) as query_snippet
FROM pg_stat_activity
WHERE state != 'idle'
AND query NOT LIKE '%pg_stat_activity%'
ORDER BY query_start;

-- 1.3 Slow query tracking
CREATE TABLE IF NOT EXISTS performance.slow_query_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    query_hash TEXT,
    query_text TEXT,
    execution_time_ms NUMERIC,
    calls INTEGER,
    mean_time_ms NUMERIC,
    max_time_ms NUMERIC,
    min_time_ms NUMERIC,
    total_time_ms NUMERIC,
    captured_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 1.4 Connection pool monitoring view
CREATE OR REPLACE VIEW performance.connection_pool_status AS
WITH connection_stats AS (
    SELECT 
        state,
        COUNT(*) as count,
        MAX(EXTRACT(EPOCH FROM (NOW() - backend_start))) as max_age_seconds,
        AVG(EXTRACT(EPOCH FROM (NOW() - backend_start))) as avg_age_seconds
    FROM pg_stat_activity
    GROUP BY state
)
SELECT 
    state,
    count,
    ROUND(max_age_seconds) as max_connection_age_sec,
    ROUND(avg_age_seconds) as avg_connection_age_sec,
    CASE 
        WHEN state = 'active' AND count > 50 THEN 'WARNING: High active connections'
        WHEN state = 'idle in transaction' AND count > 10 THEN 'WARNING: Too many idle transactions'
        WHEN state = 'idle' AND max_age_seconds > 3600 THEN 'WARNING: Stale connections'
        ELSE 'OK'
    END as status
FROM connection_stats;

-- 1.5 Table access patterns
CREATE OR REPLACE VIEW performance.table_access_patterns AS
SELECT 
    schemaname,
    tablename,
    seq_scan,
    seq_tup_read,
    idx_scan,
    idx_tup_fetch,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_tup_hot_upd as hot_updates,
    ROUND(100.0 * n_tup_hot_upd / NULLIF(n_tup_upd, 0), 2) as hot_update_ratio,
    ROUND(100.0 * idx_scan / NULLIF(seq_scan + idx_scan, 0), 2) as index_usage_ratio
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY seq_scan + idx_scan DESC;

-- ============================================================================
-- PART 2: PERFORMANCE OPTIMIZATION FUNCTIONS
-- ============================================================================

-- 2.1 Automatic index recommendations
CREATE OR REPLACE FUNCTION performance.recommend_indexes()
RETURNS TABLE(
    recommendation_type TEXT,
    table_name TEXT,
    column_names TEXT,
    reason TEXT,
    estimated_improvement TEXT
) AS $$
BEGIN
    -- Find tables with high sequential scans
    RETURN QUERY
    SELECT 
        'Missing Index'::TEXT,
        tablename::TEXT,
        'Analyze query patterns to determine columns'::TEXT,
        format('Table has %s seq scans vs %s index scans', seq_scan, idx_scan)::TEXT,
        format('Could reduce %s sequential scans', seq_scan - idx_scan)::TEXT
    FROM pg_stat_user_tables
    WHERE schemaname = 'public'
    AND seq_scan > idx_scan * 2
    AND seq_scan > 1000;
    
    -- Find columns frequently used in WHERE clauses without indexes
    RETURN QUERY
    WITH column_usage AS (
        SELECT 
            t.tablename,
            a.attname as column_name,
            COUNT(*) as usage_count
        FROM pg_stat_user_tables t
        JOIN pg_attribute a ON a.attrelid = t.relid
        WHERE t.schemaname = 'public'
        AND a.attnum > 0
        AND NOT a.attisdropped
        AND NOT EXISTS (
            SELECT 1 FROM pg_index i
            WHERE i.indrelid = a.attrelid
            AND a.attnum = ANY(i.indkey)
        )
        GROUP BY t.tablename, a.attname
        HAVING COUNT(*) > 100
    )
    SELECT 
        'Frequent Filter Column'::TEXT,
        tablename::TEXT,
        column_name::TEXT,
        format('Column used in %s queries without index', usage_count)::TEXT,
        'High impact - frequently filtered'::TEXT
    FROM column_usage;
    
    -- Find foreign keys without indexes
    RETURN QUERY
    SELECT DISTINCT
        'Foreign Key Index'::TEXT,
        tc.table_name::TEXT,
        kcu.column_name::TEXT,
        'Foreign key without supporting index'::TEXT,
        'Improves JOIN performance'::TEXT
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu 
        ON tc.constraint_name = kcu.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
    AND NOT EXISTS (
        SELECT 1 FROM pg_index i
        JOIN pg_attribute a ON a.attrelid = i.indrelid
        WHERE a.attname = kcu.column_name
        AND a.attnum = ANY(i.indkey)
    );
END;
$$ LANGUAGE plpgsql;

-- 2.2 Query optimization advisor
CREATE OR REPLACE FUNCTION performance.analyze_query(p_query TEXT)
RETURNS TABLE(
    optimization_type TEXT,
    suggestion TEXT,
    impact_level TEXT
) AS $$
BEGIN
    -- Check for SELECT *
    IF p_query ~* 'SELECT\s+\*' THEN
        RETURN QUERY SELECT 
            'Column Selection'::TEXT,
            'Avoid SELECT *, specify needed columns'::TEXT,
            'MEDIUM'::TEXT;
    END IF;
    
    -- Check for missing WHERE clause in DELETE/UPDATE
    IF p_query ~* '(DELETE|UPDATE)' AND p_query !~* 'WHERE' THEN
        RETURN QUERY SELECT 
            'Missing WHERE'::TEXT,
            'DELETE/UPDATE without WHERE affects all rows!'::TEXT,
            'CRITICAL'::TEXT;
    END IF;
    
    -- Check for NOT IN subqueries
    IF p_query ~* 'NOT\s+IN\s*\(' THEN
        RETURN QUERY SELECT 
            'Subquery Pattern'::TEXT,
            'Consider using NOT EXISTS instead of NOT IN'::TEXT,
            'HIGH'::TEXT;
    END IF;
    
    -- Check for LIKE with leading wildcard
    IF p_query ~* 'LIKE\s+[''"]%' THEN
        RETURN QUERY SELECT 
            'Index Usage'::TEXT,
            'Leading wildcard prevents index usage'::TEXT,
            'MEDIUM'::TEXT;
    END IF;
    
    -- Check for OR conditions
    IF p_query ~* '\sOR\s' THEN
        RETURN QUERY SELECT 
            'OR Condition'::TEXT,
            'Consider using UNION for OR conditions on different columns'::TEXT,
            'LOW'::TEXT;
    END IF;
    
    -- Check for functions in WHERE clause
    IF p_query ~* 'WHERE.*\(.*\)' THEN
        RETURN QUERY SELECT 
            'Function in WHERE'::TEXT,
            'Functions in WHERE clause may prevent index usage'::TEXT,
            'MEDIUM'::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 2.3 Connection killer for long-running queries
CREATE OR REPLACE FUNCTION performance.kill_long_queries(
    p_max_duration_minutes INTEGER DEFAULT 30
) RETURNS TABLE(
    killed_pid INTEGER,
    query_duration_minutes INTEGER,
    query_text TEXT
) AS $$
DECLARE
    v_pid INTEGER;
    v_duration INTEGER;
    v_query TEXT;
BEGIN
    FOR v_pid, v_duration, v_query IN
        SELECT 
            pid,
            EXTRACT(EPOCH FROM (NOW() - query_start)) / 60,
            LEFT(query, 100)
        FROM pg_stat_activity
        WHERE state = 'active'
        AND query_start < NOW() - INTERVAL '1 minute' * p_max_duration_minutes
        AND query NOT LIKE '%pg_stat_activity%'
        AND query NOT LIKE 'autovacuum:%'
    LOOP
        -- Terminate the query
        PERFORM pg_terminate_backend(v_pid);
        
        RETURN QUERY SELECT v_pid, v_duration::INTEGER, v_query;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 3: AUTOMATED PERFORMANCE TUNING
-- ============================================================================

-- 3.1 Auto-vacuum configuration optimizer
CREATE OR REPLACE FUNCTION performance.optimize_autovacuum()
RETURNS TABLE(setting_name TEXT, old_value TEXT, new_value TEXT, reason TEXT) AS $$
DECLARE
    v_total_memory BIGINT;
    v_connections INTEGER;
BEGIN
    -- Get system metrics
    SELECT setting::BIGINT * 8192 INTO v_total_memory 
    FROM pg_settings WHERE name = 'shared_buffers';
    
    SELECT setting::INTEGER INTO v_connections 
    FROM pg_settings WHERE name = 'max_connections';
    
    -- Recommend autovacuum_max_workers
    RETURN QUERY
    SELECT 
        'autovacuum_max_workers',
        current_setting('autovacuum_max_workers'),
        CASE 
            WHEN v_connections > 200 THEN '6'
            WHEN v_connections > 100 THEN '4'
            ELSE '3'
        END,
        'Based on connection count';
    
    -- Recommend autovacuum_naptime
    RETURN QUERY
    SELECT 
        'autovacuum_naptime',
        current_setting('autovacuum_naptime'),
        '30s',
        'Frequent checks for better maintenance';
    
    -- Recommend vacuum cost settings
    RETURN QUERY
    SELECT 
        'autovacuum_vacuum_cost_delay',
        current_setting('autovacuum_vacuum_cost_delay'),
        '10ms',
        'Balance between performance and maintenance';
        
    RETURN QUERY
    SELECT 
        'autovacuum_vacuum_cost_limit',
        current_setting('autovacuum_vacuum_cost_limit'),
        '1000',
        'Allow more aggressive vacuuming';
END;
$$ LANGUAGE plpgsql;

-- 3.2 Cache optimization
CREATE OR REPLACE FUNCTION performance.optimize_cache()
RETURNS TABLE(
    metric TEXT,
    current_value TEXT,
    recommendation TEXT,
    action_required TEXT
) AS $$
DECLARE
    v_cache_hit_ratio NUMERIC;
    v_table_cache_ratio NUMERIC;
    v_index_cache_ratio NUMERIC;
BEGIN
    -- Calculate cache hit ratios
    SELECT 
        ROUND(100 * sum(blks_hit)::NUMERIC / NULLIF(sum(blks_hit) + sum(blks_read), 0), 2)
    INTO v_cache_hit_ratio
    FROM pg_stat_database
    WHERE datname = current_database();
    
    -- Table cache ratio
    SELECT 
        ROUND(100 * sum(heap_blks_hit)::NUMERIC / 
              NULLIF(sum(heap_blks_hit) + sum(heap_blks_read), 0), 2)
    INTO v_table_cache_ratio
    FROM pg_statio_user_tables;
    
    -- Index cache ratio
    SELECT 
        ROUND(100 * sum(idx_blks_hit)::NUMERIC / 
              NULLIF(sum(idx_blks_hit) + sum(idx_blks_read), 0), 2)
    INTO v_index_cache_ratio
    FROM pg_statio_user_indexes;
    
    -- Overall cache performance
    RETURN QUERY
    SELECT 
        'Overall Cache Hit Ratio',
        v_cache_hit_ratio || '%',
        CASE 
            WHEN v_cache_hit_ratio > 95 THEN 'Excellent'
            WHEN v_cache_hit_ratio > 90 THEN 'Good'
            ELSE 'Needs Improvement'
        END,
        CASE 
            WHEN v_cache_hit_ratio < 90 THEN 'Increase shared_buffers'
            ELSE 'No action needed'
        END;
    
    -- Table cache performance
    RETURN QUERY
    SELECT 
        'Table Cache Hit Ratio',
        v_table_cache_ratio || '%',
        CASE 
            WHEN v_table_cache_ratio > 95 THEN 'Excellent'
            WHEN v_table_cache_ratio > 90 THEN 'Good'
            ELSE 'Needs Improvement'
        END,
        CASE 
            WHEN v_table_cache_ratio < 90 THEN 'Consider table partitioning'
            ELSE 'No action needed'
        END;
    
    -- Index cache performance
    RETURN QUERY
    SELECT 
        'Index Cache Hit Ratio',
        v_index_cache_ratio || '%',
        CASE 
            WHEN v_index_cache_ratio > 95 THEN 'Excellent'
            WHEN v_index_cache_ratio > 90 THEN 'Good'
            ELSE 'Needs Improvement'
        END,
        CASE 
            WHEN v_index_cache_ratio < 90 THEN 'Review index usage'
            ELSE 'No action needed'
        END;
    
    -- Shared buffers recommendation
    RETURN QUERY
    SELECT 
        'Shared Buffers',
        current_setting('shared_buffers'),
        pg_size_pretty((pg_database_size(current_database()) * 0.25)::BIGINT),
        'Recommended: 25% of database size';
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 4: REAL-TIME MONITORING DASHBOARD
-- ============================================================================

-- 4.1 Performance dashboard
CREATE OR REPLACE FUNCTION performance.dashboard()
RETURNS TABLE(
    category TEXT,
    metric TEXT,
    value TEXT,
    status TEXT
) AS $$
BEGIN
    -- Active connections
    RETURN QUERY
    SELECT 
        'Connections',
        'Active/Total',
        format('%s/%s', 
               (SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active'),
               (SELECT COUNT(*) FROM pg_stat_activity)),
        CASE 
            WHEN (SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active') > 50 
            THEN '⚠️ HIGH'
            ELSE '✅ OK'
        END;
    
    -- Longest running query
    RETURN QUERY
    SELECT 
        'Queries',
        'Longest Running',
        COALESCE((SELECT format('%s seconds', 
                        EXTRACT(EPOCH FROM (NOW() - query_start))::INTEGER)
                 FROM pg_stat_activity 
                 WHERE state = 'active' 
                 ORDER BY query_start 
                 LIMIT 1), 'None'),
        CASE 
            WHEN (SELECT MAX(EXTRACT(EPOCH FROM (NOW() - query_start))) 
                  FROM pg_stat_activity WHERE state = 'active') > 300 
            THEN '⚠️ SLOW'
            ELSE '✅ OK'
        END;
    
    -- Transaction rate
    RETURN QUERY
    WITH tx_rate AS (
        SELECT 
            xact_commit + xact_rollback as total_transactions
        FROM pg_stat_database 
        WHERE datname = current_database()
    )
    SELECT 
        'Transactions',
        'Total Processed',
        total_transactions::TEXT,
        '✅ OK'
    FROM tx_rate;
    
    -- Cache hit ratio
    RETURN QUERY
    SELECT 
        'Cache',
        'Hit Ratio',
        ROUND(100 * sum(blks_hit)::NUMERIC / 
              NULLIF(sum(blks_hit) + sum(blks_read), 0), 2) || '%',
        CASE 
            WHEN ROUND(100 * sum(blks_hit)::NUMERIC / 
                      NULLIF(sum(blks_hit) + sum(blks_read), 0), 2) < 90 
            THEN '⚠️ LOW'
            ELSE '✅ OK'
        END
    FROM pg_stat_database
    WHERE datname = current_database();
    
    -- Database size
    RETURN QUERY
    SELECT 
        'Storage',
        'Database Size',
        pg_size_pretty(pg_database_size(current_database())),
        CASE 
            WHEN pg_database_size(current_database()) > 10737418240  -- 10GB
            THEN '⚠️ LARGE'
            ELSE '✅ OK'
        END;
    
    -- Table bloat
    RETURN QUERY
    SELECT 
        'Maintenance',
        'Max Dead Tuples',
        MAX(n_dead_tup)::TEXT,
        CASE 
            WHEN MAX(n_dead_tup) > 10000 THEN '⚠️ HIGH BLOAT'
            ELSE '✅ OK'
        END
    FROM pg_stat_user_tables
    WHERE schemaname = 'public';
    
    -- Lock count
    RETURN QUERY
    SELECT 
        'Locks',
        'Current Locks',
        COUNT(*)::TEXT,
        CASE 
            WHEN COUNT(*) > 100 THEN '⚠️ HIGH'
            ELSE '✅ OK'
        END
    FROM pg_locks
    WHERE NOT granted;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 5: PERFORMANCE ALERTS
-- ============================================================================

-- 5.1 Alert configuration table
CREATE TABLE IF NOT EXISTS performance.alert_thresholds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    metric_name TEXT UNIQUE NOT NULL,
    warning_threshold NUMERIC,
    critical_threshold NUMERIC,
    check_interval_seconds INTEGER DEFAULT 60,
    enabled BOOLEAN DEFAULT true,
    last_checked TIMESTAMP WITH TIME ZONE,
    last_alert_sent TIMESTAMP WITH TIME ZONE
);

-- Insert default thresholds
INSERT INTO performance.alert_thresholds (metric_name, warning_threshold, critical_threshold)
VALUES 
    ('cache_hit_ratio', 90, 80),
    ('active_connections', 50, 80),
    ('longest_query_seconds', 300, 600),
    ('dead_tuples', 10000, 50000),
    ('database_size_gb', 5, 10)
ON CONFLICT (metric_name) DO NOTHING;

-- 5.2 Alert checking function
CREATE OR REPLACE FUNCTION performance.check_alerts()
RETURNS TABLE(
    alert_level TEXT,
    metric TEXT,
    current_value NUMERIC,
    threshold NUMERIC,
    message TEXT
) AS $$
DECLARE
    v_cache_hit NUMERIC;
    v_active_conn INTEGER;
    v_longest_query NUMERIC;
    v_max_dead_tuples BIGINT;
    v_db_size_gb NUMERIC;
BEGIN
    -- Get current metrics
    SELECT ROUND(100 * sum(blks_hit)::NUMERIC / 
                 NULLIF(sum(blks_hit) + sum(blks_read), 0), 2)
    INTO v_cache_hit
    FROM pg_stat_database WHERE datname = current_database();
    
    SELECT COUNT(*) INTO v_active_conn
    FROM pg_stat_activity WHERE state = 'active';
    
    SELECT COALESCE(MAX(EXTRACT(EPOCH FROM (NOW() - query_start))), 0)
    INTO v_longest_query
    FROM pg_stat_activity WHERE state = 'active';
    
    SELECT MAX(n_dead_tup) INTO v_max_dead_tuples
    FROM pg_stat_user_tables WHERE schemaname = 'public';
    
    SELECT pg_database_size(current_database()) / 1073741824.0 INTO v_db_size_gb;
    
    -- Check cache hit ratio
    IF v_cache_hit < 80 THEN
        RETURN QUERY SELECT 'CRITICAL', 'Cache Hit Ratio', v_cache_hit, 80::NUMERIC,
                           format('Cache hit ratio critically low: %.2f%%', v_cache_hit);
    ELSIF v_cache_hit < 90 THEN
        RETURN QUERY SELECT 'WARNING', 'Cache Hit Ratio', v_cache_hit, 90::NUMERIC,
                           format('Cache hit ratio below optimal: %.2f%%', v_cache_hit);
    END IF;
    
    -- Check active connections
    IF v_active_conn > 80 THEN
        RETURN QUERY SELECT 'CRITICAL', 'Active Connections', v_active_conn::NUMERIC, 80::NUMERIC,
                           format('Too many active connections: %s', v_active_conn);
    ELSIF v_active_conn > 50 THEN
        RETURN QUERY SELECT 'WARNING', 'Active Connections', v_active_conn::NUMERIC, 50::NUMERIC,
                           format('High number of active connections: %s', v_active_conn);
    END IF;
    
    -- Check longest query
    IF v_longest_query > 600 THEN
        RETURN QUERY SELECT 'CRITICAL', 'Long Running Query', v_longest_query, 600::NUMERIC,
                           format('Query running for %s seconds', v_longest_query::INTEGER);
    ELSIF v_longest_query > 300 THEN
        RETURN QUERY SELECT 'WARNING', 'Long Running Query', v_longest_query, 300::NUMERIC,
                           format('Query running for %s seconds', v_longest_query::INTEGER);
    END IF;
    
    -- Update last checked time
    UPDATE performance.alert_thresholds SET last_checked = NOW();
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================

/*
-- View real-time dashboard
SELECT * FROM performance.dashboard();

-- Get index recommendations
SELECT * FROM performance.recommend_indexes();

-- Analyze a specific query
SELECT * FROM performance.analyze_query('SELECT * FROM animals WHERE species = ''goat''');

-- Check for alerts
SELECT * FROM performance.check_alerts();

-- View active queries
SELECT * FROM performance.active_queries;

-- View connection pool status
SELECT * FROM performance.connection_pool_status;

-- Optimize cache settings
SELECT * FROM performance.optimize_cache();

-- Kill long-running queries (over 30 minutes)
SELECT * FROM performance.kill_long_queries(30);

-- View table access patterns
SELECT * FROM performance.table_access_patterns;
*/

-- ============================================================================
-- End of Performance Monitoring & Optimization
-- ============================================================================