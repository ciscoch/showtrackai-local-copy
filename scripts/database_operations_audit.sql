-- ============================================================================
-- DATABASE OPERATIONS AUDIT & HEALTH CHECK
-- Purpose: Comprehensive database assessment for operational excellence
-- Date: 2025-02-27
-- Author: Database Administrator
-- ============================================================================

-- ============================================================================
-- 1. DATABASE SCHEMA AUDIT
-- ============================================================================

-- 1.1 List all tables with row counts and size
WITH table_info AS (
    SELECT 
        schemaname,
        tablename,
        pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
        pg_stat_user_tables.n_live_tup as row_count,
        pg_stat_user_tables.n_dead_tup as dead_rows,
        ROUND(100 * pg_stat_user_tables.n_dead_tup::numeric / 
              NULLIF(pg_stat_user_tables.n_live_tup, 0), 2) as dead_ratio
    FROM pg_tables
    LEFT JOIN pg_stat_user_tables 
        ON pg_tables.schemaname = pg_stat_user_tables.schemaname 
        AND pg_tables.tablename = pg_stat_user_tables.relname
    WHERE pg_tables.schemaname = 'public'
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
)
SELECT 
    '📊 TABLE ANALYSIS' as section,
    tablename as table_name,
    size as table_size,
    row_count as live_rows,
    dead_rows,
    dead_ratio || '%' as bloat_percentage
FROM table_info;

-- 1.2 Check critical tables exist
WITH required_tables AS (
    SELECT unnest(ARRAY[
        'animals', 'users', 'journal_entries', 'feed_brands', 
        'user_profiles', 'journal_entry_ai_assessments', 'spar_runs'
    ]) as table_name
)
SELECT 
    '✅ CRITICAL TABLES CHECK' as section,
    rt.table_name,
    CASE WHEN t.tablename IS NOT NULL THEN '✅ EXISTS' ELSE '❌ MISSING' END as status
FROM required_tables rt
LEFT JOIN pg_tables t ON rt.table_name = t.tablename AND t.schemaname = 'public';

-- 1.3 Verify animals table schema (most critical table)
SELECT 
    '🐄 ANIMALS TABLE SCHEMA' as section,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'animals'
ORDER BY ordinal_position;

-- ============================================================================
-- 2. INDEX PERFORMANCE ANALYSIS
-- ============================================================================

-- 2.1 Index usage statistics
SELECT 
    '📈 INDEX USAGE' as section,
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC
LIMIT 20;

-- 2.2 Identify missing indexes based on slow queries
WITH slow_queries AS (
    SELECT 
        query,
        calls,
        mean_exec_time,
        total_exec_time
    FROM pg_stat_statements
    WHERE query NOT LIKE '%pg_%'
    AND mean_exec_time > 100  -- queries slower than 100ms
    ORDER BY mean_exec_time DESC
    LIMIT 10
)
SELECT 
    '⚠️ SLOW QUERIES (Need Indexes?)' as section,
    LEFT(query, 100) as query_snippet,
    calls as execution_count,
    ROUND(mean_exec_time::numeric, 2) || ' ms' as avg_time,
    ROUND(total_exec_time::numeric / 1000, 2) || ' sec' as total_time
FROM slow_queries;

-- 2.3 Unused indexes (candidates for removal)
SELECT 
    '🗑️ UNUSED INDEXES' as section,
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
AND idx_scan = 0
AND indexrelname NOT LIKE '%pkey%';

-- ============================================================================
-- 3. SECURITY & RLS AUDIT
-- ============================================================================

-- 3.1 Check RLS status on all tables
SELECT 
    '🔒 ROW LEVEL SECURITY STATUS' as section,
    schemaname,
    tablename,
    CASE 
        WHEN rowsecurity THEN '✅ ENABLED' 
        ELSE '❌ DISABLED - SECURITY RISK!' 
    END as rls_status
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY rowsecurity DESC, tablename;

-- 3.2 Count policies per table
WITH policy_counts AS (
    SELECT 
        tablename,
        COUNT(*) as policy_count
    FROM pg_policies
    WHERE schemaname = 'public'
    GROUP BY tablename
)
SELECT 
    '📋 RLS POLICY COVERAGE' as section,
    t.tablename,
    COALESCE(pc.policy_count, 0) as policies,
    CASE 
        WHEN COALESCE(pc.policy_count, 0) = 0 THEN '❌ NO POLICIES'
        WHEN pc.policy_count < 4 THEN '⚠️ LIMITED POLICIES'
        ELSE '✅ GOOD COVERAGE'
    END as coverage_status
FROM pg_tables t
LEFT JOIN policy_counts pc ON t.tablename = pc.tablename
WHERE t.schemaname = 'public'
ORDER BY pc.policy_count DESC NULLS LAST;

-- 3.3 Check for dangerous SECURITY DEFINER functions
SELECT 
    '⚠️ SECURITY DEFINER FUNCTIONS' as section,
    proname as function_name,
    proowner::regrole as owner,
    prosecdef as security_definer
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
AND prosecdef = true;

-- ============================================================================
-- 4. BACKUP & RECOVERY READINESS
-- ============================================================================

-- 4.1 Check last vacuum and analyze times
SELECT 
    '🧹 MAINTENANCE STATUS' as section,
    schemaname,
    tablename,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze,
    CASE 
        WHEN last_autovacuum < NOW() - INTERVAL '7 days' THEN '⚠️ NEEDS VACUUM'
        ELSE '✅ OK'
    END as vacuum_status
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY last_autovacuum ASC NULLS FIRST
LIMIT 10;

-- 4.2 Database size and growth tracking
SELECT 
    '💾 DATABASE SIZE' as section,
    current_database() as database_name,
    pg_size_pretty(pg_database_size(current_database())) as total_size,
    (SELECT COUNT(*) FROM pg_stat_user_tables WHERE schemaname = 'public') as table_count,
    (SELECT COUNT(*) FROM pg_stat_user_indexes WHERE schemaname = 'public') as index_count,
    (SELECT COUNT(*) FROM pg_stat_user_functions WHERE schemaname = 'public') as function_count;

-- 4.3 Check for long-running transactions (potential locks)
SELECT 
    '🔐 LONG TRANSACTIONS' as section,
    pid,
    usename,
    application_name,
    state,
    NOW() - xact_start as transaction_duration,
    query
FROM pg_stat_activity
WHERE state != 'idle'
AND xact_start < NOW() - INTERVAL '5 minutes'
ORDER BY xact_start;

-- ============================================================================
-- 5. PERFORMANCE METRICS
-- ============================================================================

-- 5.1 Connection pool status
SELECT 
    '🔌 CONNECTION POOL' as section,
    COUNT(*) as total_connections,
    SUM(CASE WHEN state = 'active' THEN 1 ELSE 0 END) as active,
    SUM(CASE WHEN state = 'idle' THEN 1 ELSE 0 END) as idle,
    SUM(CASE WHEN state = 'idle in transaction' THEN 1 ELSE 0 END) as idle_in_transaction,
    MAX(EXTRACT(EPOCH FROM (NOW() - backend_start))) as longest_connection_seconds
FROM pg_stat_activity;

-- 5.2 Cache hit ratio (should be > 95%)
SELECT 
    '📊 CACHE PERFORMANCE' as section,
    ROUND(100 * sum(blks_hit) / NULLIF(sum(blks_hit) + sum(blks_read), 0), 2) as cache_hit_ratio,
    CASE 
        WHEN ROUND(100 * sum(blks_hit) / NULLIF(sum(blks_hit) + sum(blks_read), 0), 2) > 95 THEN '✅ EXCELLENT'
        WHEN ROUND(100 * sum(blks_hit) / NULLIF(sum(blks_hit) + sum(blks_read), 0), 2) > 90 THEN '👍 GOOD'
        ELSE '⚠️ NEEDS OPTIMIZATION'
    END as status
FROM pg_stat_database
WHERE datname = current_database();

-- 5.3 Table bloat analysis
WITH bloat AS (
    SELECT 
        schemaname,
        tablename,
        n_live_tup,
        n_dead_tup,
        ROUND(100 * n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup, 0), 2) as bloat_ratio
    FROM pg_stat_user_tables
    WHERE schemaname = 'public'
    AND n_dead_tup > 1000
)
SELECT 
    '🗑️ TABLE BLOAT' as section,
    tablename,
    n_live_tup as live_tuples,
    n_dead_tup as dead_tuples,
    bloat_ratio || '%' as bloat_percentage,
    CASE 
        WHEN bloat_ratio > 20 THEN '❌ HIGH BLOAT - VACUUM NEEDED'
        WHEN bloat_ratio > 10 THEN '⚠️ MODERATE BLOAT'
        ELSE '✅ ACCEPTABLE'
    END as status
FROM bloat
ORDER BY bloat_ratio DESC;

-- ============================================================================
-- 6. DATA INTEGRITY CHECKS
-- ============================================================================

-- 6.1 Check for orphaned records in animals table
SELECT 
    '👻 ORPHANED ANIMALS' as section,
    COUNT(*) as orphaned_count
FROM animals a
LEFT JOIN users u ON a.user_id = u.id
WHERE u.id IS NULL;

-- 6.2 Check for duplicate entries (potential data integrity issues)
WITH duplicates AS (
    SELECT 
        user_id,
        name,
        species,
        COUNT(*) as duplicate_count
    FROM animals
    GROUP BY user_id, name, species
    HAVING COUNT(*) > 1
)
SELECT 
    '⚠️ DUPLICATE ANIMALS' as section,
    COUNT(*) as users_with_duplicates,
    SUM(duplicate_count) as total_duplicates
FROM duplicates;

-- 6.3 Check foreign key constraint violations
SELECT 
    '🔗 FOREIGN KEY INTEGRITY' as section,
    conname as constraint_name,
    conrelid::regclass as table_name,
    confrelid::regclass as referenced_table
FROM pg_constraint
WHERE contype = 'f'
AND connamespace = 'public'::regnamespace
AND NOT EXISTS (
    SELECT 1 FROM pg_constraint c2
    WHERE c2.contype = 'f'
    AND c2.connamespace = connamespace
    AND c2.conrelid = conrelid
    AND c2.confrelid = confrelid
    AND c2.conkey = conkey
    AND c2.confkey = confkey
    AND c2.oid != pg_constraint.oid
);

-- ============================================================================
-- 7. OPERATIONAL RECOMMENDATIONS
-- ============================================================================

WITH recommendations AS (
    SELECT 
        CASE 
            WHEN (SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public' AND rowsecurity = false) > 0 
                THEN '🚨 CRITICAL: Enable RLS on all tables'
            ELSE NULL
        END as rec1,
        CASE 
            WHEN (SELECT MAX(n_dead_tup) FROM pg_stat_user_tables WHERE schemaname = 'public') > 10000 
                THEN '⚠️ HIGH: Run VACUUM on bloated tables'
            ELSE NULL
        END as rec2,
        CASE 
            WHEN (SELECT COUNT(*) FROM pg_stat_user_indexes WHERE schemaname = 'public' AND idx_scan = 0) > 5 
                THEN '💡 MEDIUM: Remove unused indexes'
            ELSE NULL
        END as rec3,
        CASE 
            WHEN (SELECT ROUND(100 * sum(blks_hit) / NULLIF(sum(blks_hit) + sum(blks_read), 0), 2) 
                  FROM pg_stat_database WHERE datname = current_database()) < 90 
                THEN '📈 HIGH: Optimize cache performance'
            ELSE NULL
        END as rec4
)
SELECT 
    '📝 OPERATIONAL RECOMMENDATIONS' as section,
    unnest(ARRAY[rec1, rec2, rec3, rec4]) as recommendation
FROM recommendations
WHERE unnest(ARRAY[rec1, rec2, rec3, rec4]) IS NOT NULL;

-- ============================================================================
-- 8. SUMMARY DASHBOARD
-- ============================================================================

SELECT 
    '📊 DATABASE HEALTH SUMMARY' as section,
    'Tables: ' || (SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public') || ' | ' ||
    'Indexes: ' || (SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public') || ' | ' ||
    'RLS Enabled: ' || (SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public' AND rowsecurity = true) || ' | ' ||
    'Size: ' || pg_size_pretty(pg_database_size(current_database())) as metrics;

-- ============================================================================
-- End of Database Operations Audit
-- Run this script regularly to monitor database health
-- ============================================================================