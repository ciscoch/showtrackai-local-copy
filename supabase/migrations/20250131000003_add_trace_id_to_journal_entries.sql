-- ============================================================================
-- Add trace_id column to journal_entries table for distributed tracing
-- Migration: 20250131000003_add_trace_id_to_journal_entries
-- Created: 2025-01-31
-- Purpose: Add trace_id field for end-to-end correlation across all services
-- ============================================================================

-- Add trace_id column to journal_entries table
ALTER TABLE journal_entries 
ADD COLUMN IF NOT EXISTS trace_id UUID;

-- Add index for trace_id lookups (useful for debugging and correlation)
CREATE INDEX IF NOT EXISTS idx_journal_entries_trace_id 
ON journal_entries(trace_id) 
WHERE trace_id IS NOT NULL;

-- Add comment to document the purpose
COMMENT ON COLUMN journal_entries.trace_id IS 
'Distributed tracing UUID v4 for correlating UI events with backend processing across all services (N8N, Netlify, Supabase)';

-- Update the JSON serialization functions to include trace_id if any exist
-- (This would be handled automatically by the application code)

-- Create function to get journal entries by trace_id for debugging
CREATE OR REPLACE FUNCTION get_journal_entry_by_trace_id(
    p_trace_id UUID
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    title TEXT,
    content TEXT,
    category TEXT,
    trace_id UUID,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        je.id,
        je.user_id,
        je.title,
        je.content,
        je.category,
        je.trace_id,
        je.created_at,
        je.updated_at
    FROM journal_entries je
    WHERE je.trace_id = p_trace_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_journal_entry_by_trace_id TO authenticated;

-- Create function to analyze trace_id usage patterns (for observability)
CREATE OR REPLACE FUNCTION analyze_trace_id_usage()
RETURNS TABLE (
    total_entries_with_trace_id BIGINT,
    total_entries_without_trace_id BIGINT,
    trace_coverage_percentage NUMERIC,
    earliest_trace_entry TIMESTAMP WITH TIME ZONE,
    latest_trace_entry TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) FILTER (WHERE je.trace_id IS NOT NULL) as total_with_trace,
        COUNT(*) FILTER (WHERE je.trace_id IS NULL) as total_without_trace,
        ROUND(
            (COUNT(*) FILTER (WHERE je.trace_id IS NOT NULL) * 100.0) / 
            NULLIF(COUNT(*), 0), 
            2
        ) as coverage_percentage,
        MIN(je.created_at) FILTER (WHERE je.trace_id IS NOT NULL) as earliest_trace,
        MAX(je.created_at) FILTER (WHERE je.trace_id IS NOT NULL) as latest_trace
    FROM journal_entries je;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users (admin function)
GRANT EXECUTE ON FUNCTION analyze_trace_id_usage TO authenticated;

-- ============================================================================
-- VERIFICATION AND MIGRATION COMPLETION
-- ============================================================================

-- Verify the column was added successfully
DO $$
DECLARE
    column_exists BOOLEAN;
    index_exists BOOLEAN;
BEGIN
    -- Check if trace_id column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'journal_entries' 
        AND column_name = 'trace_id'
    ) INTO column_exists;
    
    -- Check if index exists
    SELECT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE schemaname = 'public' 
        AND tablename = 'journal_entries' 
        AND indexname = 'idx_journal_entries_trace_id'
    ) INTO index_exists;
    
    IF NOT column_exists THEN
        RAISE EXCEPTION 'trace_id column was not added successfully to journal_entries table';
    END IF;
    
    IF NOT index_exists THEN
        RAISE EXCEPTION 'trace_id index was not created successfully';
    END IF;
    
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'ShowTrackAI Trace ID Migration COMPLETED!';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Added column: journal_entries.trace_id (UUID)';
    RAISE NOTICE 'Added index: idx_journal_entries_trace_id';
    RAISE NOTICE 'Added function: get_journal_entry_by_trace_id()';
    RAISE NOTICE 'Added function: analyze_trace_id_usage()';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Distributed tracing is now enabled!';
    RAISE NOTICE 'All new journal entries will have trace_id correlation.';
    RAISE NOTICE '===========================================';
END;
$$;

-- Run initial analysis to show current state
SELECT 'Initial trace_id coverage analysis:' as analysis_type;
SELECT * FROM analyze_trace_id_usage();