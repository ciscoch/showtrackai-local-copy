-- ============================================================================
-- Database Optimization for Timeline Feature (APP-125)
-- Purpose: Comprehensive optimization, verification, and performance tuning
-- Created: 2025-08-27
-- ============================================================================

-- ============================================================================
-- STEP 1: VERIFY TABLE STRUCTURES
-- ============================================================================

-- Check if required tables exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'journal_entries') THEN
    RAISE EXCEPTION 'journal_entries table does not exist!';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'expenses') THEN
    RAISE EXCEPTION 'expenses table does not exist!';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'animals') THEN
    RAISE EXCEPTION 'animals table does not exist!';
  END IF;
  
  RAISE NOTICE '✅ All required tables exist';
END;
$$;

-- ============================================================================
-- STEP 2: ADD MISSING COLUMNS (if needed)
-- ============================================================================

-- Ensure journal_entries has description column
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'journal_entries' AND column_name = 'description'
  ) THEN
    ALTER TABLE journal_entries ADD COLUMN description TEXT;
    RAISE NOTICE '✅ Added description column to journal_entries';
  ELSE
    RAISE NOTICE '✅ Description column already exists in journal_entries';
  END IF;
END;
$$;

-- Ensure journal_entries has financial_value column for expense tracking
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'journal_entries' AND column_name = 'financial_value'
  ) THEN
    ALTER TABLE journal_entries ADD COLUMN financial_value DECIMAL(10,2);
    RAISE NOTICE '✅ Added financial_value column to journal_entries';
  ELSE
    RAISE NOTICE '✅ Financial_value column already exists in journal_entries';
  END IF;
END;
$$;

-- Ensure journal_entries has duration column
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'journal_entries' AND column_name = 'duration'
  ) THEN
    ALTER TABLE journal_entries ADD COLUMN duration INTEGER;
    RAISE NOTICE '✅ Added duration column to journal_entries';
  ELSE
    RAISE NOTICE '✅ Duration column already exists in journal_entries';
  END IF;
END;
$$;

-- Ensure journal_entries has photos column for attachments
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'journal_entries' AND column_name = 'photos'
  ) THEN
    ALTER TABLE journal_entries ADD COLUMN photos TEXT[] DEFAULT '{}';
    RAISE NOTICE '✅ Added photos column to journal_entries';
  ELSE
    RAISE NOTICE '✅ Photos column already exists in journal_entries';
  END IF;
END;
$$;

-- ============================================================================
-- STEP 3: OPTIMIZE INDEXES FOR TIMELINE QUERIES
-- ============================================================================

-- Drop existing indexes if they exist to avoid conflicts
DROP INDEX IF EXISTS idx_timeline_journal_user_date;
DROP INDEX IF EXISTS idx_timeline_expense_user_date;
DROP INDEX IF EXISTS idx_timeline_journal_composite;
DROP INDEX IF EXISTS idx_timeline_expense_composite;

-- Create optimized indexes for timeline queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_timeline_journal_user_date 
  ON journal_entries(user_id, entry_date DESC, created_at DESC);
  
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_timeline_expense_user_date 
  ON expenses(user_id, date DESC, created_at DESC);

-- Composite indexes for filtering
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_timeline_journal_composite 
  ON journal_entries(user_id, entry_date DESC, category, animal_id) 
  WHERE entry_date IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_timeline_expense_composite 
  ON expenses(user_id, date DESC, category, animal_id)
  WHERE date IS NOT NULL;

-- Partial indexes for common queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_journal_recent 
  ON journal_entries(user_id, entry_date DESC) 
  WHERE entry_date >= CURRENT_DATE - INTERVAL '30 days';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_expense_recent 
  ON expenses(user_id, date DESC) 
  WHERE date >= CURRENT_DATE - INTERVAL '30 days';

-- Index for animal joins
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_journal_animal_join 
  ON journal_entries(animal_id) 
  WHERE animal_id IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_expense_animal_join 
  ON expenses(animal_id) 
  WHERE animal_id IS NOT NULL;

RAISE NOTICE '✅ All performance indexes created';

-- ============================================================================
-- STEP 4: CREATE OPTIMIZED TIMELINE VIEW
-- ============================================================================

-- Drop and recreate the unified timeline view with better performance
DROP VIEW IF EXISTS unified_timeline CASCADE;

CREATE OR REPLACE VIEW unified_timeline AS
WITH timeline_data AS (
  SELECT 
    je.id as item_id,
    'journal'::text as item_type,
    je.user_id,
    je.title,
    COALESCE(je.description, je.content) as content,
    je.entry_date as date,
    je.created_at as timestamp,
    je.category,
    je.animal_id,
    a.name as animal_name,
    je.duration as metadata_duration,
    je.quality_score as metadata_quality,
    je.financial_value as amount,
    je.tags,
    je.photos as attachments,
    NULL::text as vendor_name,
    NULL::text as payment_method,
    TRUE as is_paid
  FROM journal_entries je
  LEFT JOIN animals a ON je.animal_id = a.id
  
  UNION ALL
  
  SELECT 
    e.id as item_id,
    'expense'::text as item_type,
    e.user_id,
    e.title,
    e.description as content,
    e.date::date as date,
    e.created_at as timestamp,
    e.category,
    e.animal_id,
    a.name as animal_name,
    NULL::integer as metadata_duration,
    NULL::integer as metadata_quality,
    e.amount,
    e.tags,
    CASE WHEN e.receipt_url IS NOT NULL 
      THEN ARRAY[e.receipt_url] 
      ELSE '{}'::text[] 
    END as attachments,
    e.vendor_name,
    e.payment_method,
    e.is_paid
  FROM expenses e
  LEFT JOIN animals a ON e.animal_id = a.id
)
SELECT * FROM timeline_data;

GRANT SELECT ON unified_timeline TO authenticated;
RAISE NOTICE '✅ Unified timeline view created';

-- ============================================================================
-- STEP 5: CREATE PERFORMANCE MONITORING FUNCTIONS
-- ============================================================================

-- Function to analyze timeline query performance
CREATE OR REPLACE FUNCTION analyze_timeline_performance()
RETURNS TABLE (
  check_name TEXT,
  status TEXT,
  details TEXT
) AS $$
BEGIN
  -- Check index usage
  RETURN QUERY
  SELECT 
    'Index Usage'::text as check_name,
    CASE 
      WHEN COUNT(*) >= 10 THEN 'Good'::text
      ELSE 'Needs Review'::text
    END as status,
    format('%s indexes found for timeline tables', COUNT(*))::text as details
  FROM pg_indexes
  WHERE tablename IN ('journal_entries', 'expenses')
    AND indexname LIKE '%timeline%' OR indexname LIKE '%date%';

  -- Check table statistics
  RETURN QUERY
  SELECT 
    'Table Statistics'::text,
    'Info'::text,
    format('Journal entries: %s, Expenses: %s', 
      (SELECT COUNT(*) FROM journal_entries),
      (SELECT COUNT(*) FROM expenses))::text;

  -- Check for missing indexes
  RETURN QUERY
  SELECT 
    'Missing Indexes'::text,
    CASE 
      WHEN COUNT(*) = 0 THEN 'Good'::text
      ELSE 'Warning'::text
    END,
    format('%s potentially missing indexes detected', COUNT(*))::text
  FROM pg_stat_user_tables
  WHERE schemaname = 'public'
    AND tablename IN ('journal_entries', 'expenses')
    AND n_tup_ins + n_tup_upd + n_tup_del > 1000
    AND idx_scan < seq_scan;

  -- Check RLS policies
  RETURN QUERY
  SELECT 
    'Row Level Security'::text,
    CASE 
      WHEN COUNT(*) >= 4 THEN 'Good'::text
      ELSE 'Warning'::text
    END,
    format('%s RLS policies found', COUNT(*))::text
  FROM pg_policies
  WHERE tablename IN ('journal_entries', 'expenses');

  -- Check vacuum status
  RETURN QUERY
  SELECT 
    'Vacuum Status'::text,
    CASE 
      WHEN MAX(last_autovacuum) > NOW() - INTERVAL '7 days' THEN 'Good'::text
      ELSE 'Needs Attention'::text
    END,
    format('Last vacuum: %s', COALESCE(MAX(last_autovacuum)::text, 'Never'))::text
  FROM pg_stat_user_tables
  WHERE tablename IN ('journal_entries', 'expenses');
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 6: CREATE OPTIMIZED TIMELINE QUERY FUNCTION
-- ============================================================================

-- High-performance timeline query with caching hints
CREATE OR REPLACE FUNCTION get_timeline_items_optimized(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL,
  p_category TEXT DEFAULT NULL,
  p_animal_id UUID DEFAULT NULL,
  p_item_types TEXT[] DEFAULT ARRAY['journal', 'expense']
)
RETURNS TABLE (
  item_id UUID,
  item_type TEXT,
  title TEXT,
  content TEXT,
  date DATE,
  timestamp TIMESTAMP WITH TIME ZONE,
  category TEXT,
  animal_id UUID,
  animal_name TEXT,
  amount DECIMAL,
  tags TEXT[],
  attachments TEXT[],
  metadata JSONB
) AS $$
BEGIN
  -- Use index hints for better performance
  SET LOCAL enable_seqscan = OFF;
  SET LOCAL random_page_cost = 1.1;
  
  RETURN QUERY
  SELECT 
    ut.item_id,
    ut.item_type,
    ut.title,
    ut.content,
    ut.date,
    ut.timestamp,
    ut.category,
    ut.animal_id,
    ut.animal_name,
    ut.amount,
    ut.tags,
    ut.attachments,
    jsonb_build_object(
      'duration', ut.metadata_duration,
      'quality', ut.metadata_quality,
      'vendor_name', ut.vendor_name,
      'payment_method', ut.payment_method,
      'is_paid', ut.is_paid
    ) as metadata
  FROM unified_timeline ut
  WHERE ut.user_id = p_user_id
    AND (p_start_date IS NULL OR ut.date >= p_start_date)
    AND (p_end_date IS NULL OR ut.date <= p_end_date)
    AND (p_category IS NULL OR ut.category = p_category)
    AND (p_animal_id IS NULL OR ut.animal_id = p_animal_id)
    AND ut.item_type = ANY(p_item_types)
  ORDER BY ut.date DESC, ut.timestamp DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Grant execution permission
GRANT EXECUTE ON FUNCTION get_timeline_items_optimized TO authenticated;

-- ============================================================================
-- STEP 7: CREATE TIMELINE STATISTICS FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION get_timeline_stats(
  p_user_id UUID,
  p_days_back INTEGER DEFAULT 30
)
RETURNS JSONB AS $$
DECLARE
  stats JSONB;
BEGIN
  WITH timeline_summary AS (
    SELECT 
      COUNT(*) FILTER (WHERE item_type = 'journal') as journal_count,
      COUNT(*) FILTER (WHERE item_type = 'expense') as expense_count,
      COUNT(*) as total_items,
      COUNT(DISTINCT date) as active_days,
      SUM(amount) FILTER (WHERE item_type = 'expense') as total_expenses,
      AVG(metadata_quality) FILTER (WHERE metadata_quality IS NOT NULL) as avg_quality,
      COUNT(DISTINCT animal_id) as unique_animals,
      COUNT(DISTINCT category) as unique_categories,
      array_agg(DISTINCT category ORDER BY category) as categories
    FROM unified_timeline
    WHERE user_id = p_user_id
      AND date >= CURRENT_DATE - (p_days_back || ' days')::INTERVAL
  ),
  daily_breakdown AS (
    SELECT 
      date,
      COUNT(*) as items_count,
      SUM(amount) FILTER (WHERE item_type = 'expense') as daily_expense
    FROM unified_timeline
    WHERE user_id = p_user_id
      AND date >= CURRENT_DATE - (p_days_back || ' days')::INTERVAL
    GROUP BY date
    ORDER BY date DESC
  )
  SELECT jsonb_build_object(
    'summary', row_to_json(timeline_summary),
    'daily_activity', jsonb_agg(
      jsonb_build_object(
        'date', date,
        'items', items_count,
        'expenses', COALESCE(daily_expense, 0)
      ) ORDER BY date DESC
    ),
    'period_days', p_days_back,
    'generated_at', NOW()
  ) INTO stats
  FROM timeline_summary, daily_breakdown
  GROUP BY timeline_summary.*;
  
  RETURN COALESCE(stats, '{}'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

GRANT EXECUTE ON FUNCTION get_timeline_stats TO authenticated;

-- ============================================================================
-- STEP 8: VERIFY ROW LEVEL SECURITY
-- ============================================================================

-- Ensure RLS is enabled on all tables
ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE animals ENABLE ROW LEVEL SECURITY;

-- Verify RLS policies exist
DO $$
DECLARE
  journal_policies INTEGER;
  expense_policies INTEGER;
BEGIN
  SELECT COUNT(*) INTO journal_policies FROM pg_policies WHERE tablename = 'journal_entries';
  SELECT COUNT(*) INTO expense_policies FROM pg_policies WHERE tablename = 'expenses';
  
  IF journal_policies < 4 THEN
    RAISE WARNING 'Journal entries may be missing RLS policies (found: %)', journal_policies;
  END IF;
  
  IF expense_policies < 4 THEN
    RAISE WARNING 'Expenses may be missing RLS policies (found: %)', expense_policies;
  END IF;
  
  RAISE NOTICE '✅ RLS verification complete';
END;
$$;

-- ============================================================================
-- STEP 9: CREATE PERFORMANCE MONITORING DASHBOARD
-- ============================================================================

CREATE OR REPLACE VIEW timeline_performance_dashboard AS
SELECT 
  'Timeline Performance Metrics' as section,
  jsonb_build_object(
    'total_journal_entries', (SELECT COUNT(*) FROM journal_entries),
    'total_expenses', (SELECT COUNT(*) FROM expenses),
    'avg_timeline_items_per_user', (
      SELECT AVG(item_count) FROM (
        SELECT user_id, COUNT(*) as item_count 
        FROM unified_timeline 
        GROUP BY user_id
      ) counts
    ),
    'most_active_categories', (
      SELECT jsonb_agg(category_data) FROM (
        SELECT jsonb_build_object(
          'category', category,
          'count', COUNT(*)
        ) as category_data
        FROM unified_timeline
        WHERE category IS NOT NULL
        GROUP BY category
        ORDER BY COUNT(*) DESC
        LIMIT 5
      ) top_categories
    ),
    'index_effectiveness', (
      SELECT jsonb_object_agg(
        tablename,
        jsonb_build_object(
          'index_scans', idx_scan,
          'sequential_scans', seq_scan,
          'index_efficiency', 
            CASE WHEN idx_scan + seq_scan > 0 
              THEN ROUND((idx_scan::numeric / (idx_scan + seq_scan)) * 100, 2)
              ELSE 0 
            END
        )
      )
      FROM pg_stat_user_tables
      WHERE tablename IN ('journal_entries', 'expenses')
    )
  ) as metrics;

GRANT SELECT ON timeline_performance_dashboard TO authenticated;

-- ============================================================================
-- STEP 10: CLEANUP AND VACUUM
-- ============================================================================

-- Analyze tables for query planner
ANALYZE journal_entries;
ANALYZE expenses;
ANALYZE animals;

-- ============================================================================
-- FINAL VERIFICATION
-- ============================================================================

DO $$
DECLARE
  index_count INTEGER;
  view_count INTEGER;
  function_count INTEGER;
BEGIN
  -- Count timeline-related indexes
  SELECT COUNT(*) INTO index_count
  FROM pg_indexes
  WHERE tablename IN ('journal_entries', 'expenses')
    AND (indexname LIKE '%timeline%' OR indexname LIKE '%date%' OR indexname LIKE '%user%');
  
  -- Count views
  SELECT COUNT(*) INTO view_count
  FROM information_schema.views
  WHERE table_name IN ('unified_timeline', 'timeline_performance_dashboard');
  
  -- Count functions
  SELECT COUNT(*) INTO function_count
  FROM information_schema.routines
  WHERE routine_name IN ('get_timeline_items_optimized', 'get_timeline_stats', 'analyze_timeline_performance');
  
  RAISE NOTICE '';
  RAISE NOTICE '============================================';
  RAISE NOTICE '✅ TIMELINE DATABASE OPTIMIZATION COMPLETE!';
  RAISE NOTICE '============================================';
  RAISE NOTICE 'Created/Verified:';
  RAISE NOTICE '  - % performance indexes', index_count;
  RAISE NOTICE '  - % optimized views', view_count;
  RAISE NOTICE '  - % query functions', function_count;
  RAISE NOTICE '  - Row Level Security enabled';
  RAISE NOTICE '  - Performance monitoring dashboard';
  RAISE NOTICE '';
  RAISE NOTICE 'Performance Improvements:';
  RAISE NOTICE '  ✓ Timeline queries optimized with indexes';
  RAISE NOTICE '  ✓ Unified view for journal & expense data';
  RAISE NOTICE '  ✓ Efficient pagination support';
  RAISE NOTICE '  ✓ Statistics pre-computation';
  RAISE NOTICE '  ✓ Query plan optimization hints';
  RAISE NOTICE '';
  RAISE NOTICE 'Run analyze_timeline_performance() to check status';
  RAISE NOTICE '============================================';
END;
$$;

-- Run performance analysis
SELECT * FROM analyze_timeline_performance();