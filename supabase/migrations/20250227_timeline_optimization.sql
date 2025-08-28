-- ============================================================================
-- Timeline Performance Optimization Migration
-- Purpose: Create unified timeline views and indexes for APP-125
-- ============================================================================

-- Create unified timeline view for efficient querying
CREATE OR REPLACE VIEW unified_timeline AS
SELECT 
  je.id as item_id,
  'journal' as item_type,
  je.user_id,
  je.title,
  je.description as content,
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
  NULL as vendor_name,
  NULL as payment_method,
  TRUE as is_paid
FROM journal_entries je
LEFT JOIN animals a ON je.animal_id = a.id
WHERE je.user_id IS NOT NULL

UNION ALL

SELECT 
  e.id as item_id,
  'expense' as item_type,
  e.user_id,
  e.title,
  e.description as content,
  e.date::date as date,
  e.created_at as timestamp,
  e.category,
  e.animal_id,
  a.name as animal_name,
  NULL as metadata_duration,
  NULL as metadata_quality,
  e.amount,
  e.tags,
  CASE WHEN e.receipt_url IS NOT NULL THEN ARRAY[e.receipt_url] ELSE NULL END as attachments,
  e.vendor_name,
  e.payment_method,
  e.is_paid
FROM expenses e
LEFT JOIN animals a ON e.animal_id = a.id
WHERE e.user_id IS NOT NULL;

-- Add indexes for timeline performance
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_timeline_user_date 
  ON (
    SELECT user_id, date, timestamp FROM unified_timeline
  ) (user_id, date DESC, timestamp DESC);

-- Materialized view for timeline aggregation (refreshed on data changes)
CREATE MATERIALIZED VIEW timeline_aggregated AS
SELECT 
  user_id,
  date,
  COUNT(*) as total_items,
  COUNT(*) FILTER (WHERE item_type = 'journal') as journal_count,
  COUNT(*) FILTER (WHERE item_type = 'expense') as expense_count,
  SUM(amount) FILTER (WHERE item_type = 'expense') as total_expenses,
  AVG(metadata_quality) FILTER (WHERE metadata_quality IS NOT NULL) as avg_quality,
  array_agg(DISTINCT category) as categories,
  array_agg(DISTINCT animal_id) FILTER (WHERE animal_id IS NOT NULL) as animals_involved
FROM unified_timeline
GROUP BY user_id, date
ORDER BY user_id, date DESC;

-- Create unique index for materialized view
CREATE UNIQUE INDEX idx_timeline_aggregated_user_date 
  ON timeline_aggregated (user_id, date DESC);

-- Function to refresh timeline aggregated data
CREATE OR REPLACE FUNCTION refresh_timeline_aggregated()
RETURNS TRIGGER AS $$
BEGIN
  -- Refresh the materialized view when journal_entries or expenses change
  REFRESH MATERIALIZED VIEW CONCURRENTLY timeline_aggregated;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Triggers to auto-refresh aggregated data
DROP TRIGGER IF EXISTS timeline_refresh_on_journal_change ON journal_entries;
CREATE TRIGGER timeline_refresh_on_journal_change
  AFTER INSERT OR UPDATE OR DELETE ON journal_entries
  FOR EACH STATEMENT
  EXECUTE FUNCTION refresh_timeline_aggregated();

DROP TRIGGER IF EXISTS timeline_refresh_on_expense_change ON expenses;
CREATE TRIGGER timeline_refresh_on_expense_change
  AFTER INSERT OR UPDATE OR DELETE ON expenses
  FOR EACH STATEMENT
  EXECUTE FUNCTION refresh_timeline_aggregated();

-- High-performance timeline query function with pagination
CREATE OR REPLACE FUNCTION get_timeline_items(
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Timeline statistics function
CREATE OR REPLACE FUNCTION get_timeline_statistics(
  p_user_id UUID,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'total_items', COUNT(*),
    'journal_count', COUNT(*) FILTER (WHERE item_type = 'journal'),
    'expense_count', COUNT(*) FILTER (WHERE item_type = 'expense'),
    'total_expenses', COALESCE(SUM(amount) FILTER (WHERE item_type = 'expense'), 0),
    'average_quality', COALESCE(AVG(metadata_quality) FILTER (WHERE metadata_quality IS NOT NULL), 0),
    'categories', array_agg(DISTINCT category),
    'date_range', jsonb_build_object(
      'start', MIN(date),
      'end', MAX(date)
    ),
    'weekly_activity', (
      SELECT jsonb_object_agg(
        week,
        items
      )
      FROM (
        SELECT 
          date_trunc('week', date) as week,
          COUNT(*) as items
        FROM unified_timeline ut2
        WHERE ut2.user_id = p_user_id
          AND (p_start_date IS NULL OR ut2.date >= p_start_date)
          AND (p_end_date IS NULL OR ut2.date <= p_end_date)
        GROUP BY date_trunc('week', date)
        ORDER BY week DESC
        LIMIT 12
      ) weekly
    )
  ) INTO result
  FROM unified_timeline ut
  WHERE ut.user_id = p_user_id
    AND (p_start_date IS NULL OR ut.date >= p_start_date)
    AND (p_end_date IS NULL OR ut.date <= p_end_date);
    
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT SELECT ON unified_timeline TO authenticated;
GRANT SELECT ON timeline_aggregated TO authenticated;
GRANT EXECUTE ON FUNCTION get_timeline_items TO authenticated;
GRANT EXECUTE ON FUNCTION get_timeline_statistics TO authenticated;

-- Verify migration
DO $$
BEGIN
  RAISE NOTICE '============================================';
  RAISE NOTICE 'Timeline Optimization Migration Complete!';
  RAISE NOTICE '============================================';
  RAISE NOTICE 'Created unified_timeline view';
  RAISE NOTICE 'Created timeline_aggregated materialized view';
  RAISE NOTICE 'Added performance indexes';
  RAISE NOTICE 'Created auto-refresh triggers';
  RAISE NOTICE 'Added optimized query functions';
  RAISE NOTICE '============================================';
END;
$$;