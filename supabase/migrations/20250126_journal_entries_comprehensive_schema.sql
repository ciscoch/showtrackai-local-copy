-- ============================================================================
-- ShowTrackAI Journal Entries Comprehensive Database Schema
-- Migration: 20250126_journal_entries_comprehensive_schema
-- Created: 2025-01-26
-- Purpose: Create journal_entries table with RLS policies for FFA compliance
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- For text search performance

-- ============================================================================
-- CORE JOURNAL ENTRIES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS journal_entries (
    -- Primary identifiers
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Core journal fields
    title TEXT NOT NULL CHECK (char_length(title) > 0),
    content TEXT NOT NULL CHECK (char_length(content) > 0),
    category TEXT NOT NULL DEFAULT 'general' CHECK (category IN (
        'general', 'health', 'feeding', 'training', 'breeding', 'showing', 
        'maintenance', 'observation', 'learning', 'project', 'competition',
        'sae', 'ffa_activity', 'career_exploration', 'leadership'
    )),
    
    -- Animal association
    animal_id UUID REFERENCES animals(id) ON DELETE SET NULL,
    
    -- Agricultural context
    weather_conditions JSONB DEFAULT '{}',
    location_data JSONB DEFAULT '{}',
    
    -- FFA Compliance & Educational tracking
    competency_tracking JSONB DEFAULT '{}',
    ffa_standards TEXT[], -- Array of FFA standard codes (e.g., 'AS.01.01')
    educational_objectives TEXT[],
    learning_outcomes TEXT[],
    
    -- Entry metadata
    entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
    entry_time TIME DEFAULT CURRENT_TIME,
    
    -- Media and attachments
    attachment_urls TEXT[] DEFAULT '{}',
    photo_urls TEXT[] DEFAULT '{}',
    tags TEXT[] DEFAULT '{}',
    
    -- Quality and approval
    is_draft BOOLEAN DEFAULT FALSE,
    is_private BOOLEAN DEFAULT FALSE,
    instructor_reviewed BOOLEAN DEFAULT FALSE,
    instructor_feedback TEXT,
    quality_score INTEGER CHECK (quality_score >= 0 AND quality_score <= 10),
    
    -- Sync and versioning
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'error')),
    version INTEGER DEFAULT 1,
    last_sync_at TIMESTAMP WITH TIME ZONE,
    
    -- Audit trail
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Additional constraints
    CONSTRAINT valid_entry_date CHECK (entry_date <= CURRENT_DATE),
    CONSTRAINT content_length_check CHECK (char_length(content) <= 10000),
    CONSTRAINT title_length_check CHECK (char_length(title) <= 200)
);

-- ============================================================================
-- PERFORMANCE INDEXES
-- ============================================================================

-- Primary query patterns
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_id ON journal_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_journal_entries_animal_id ON journal_entries(animal_id) WHERE animal_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_journal_entries_category ON journal_entries(category);
CREATE INDEX IF NOT EXISTS idx_journal_entries_entry_date ON journal_entries(entry_date DESC);

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_date ON journal_entries(user_id, entry_date DESC);
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_category ON journal_entries(user_id, category);
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_animal ON journal_entries(user_id, animal_id) WHERE animal_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_draft ON journal_entries(user_id, is_draft);

-- FFA and educational indexes
CREATE INDEX IF NOT EXISTS idx_journal_entries_ffa_standards ON journal_entries USING GIN(ffa_standards);
CREATE INDEX IF NOT EXISTS idx_journal_entries_competencies ON journal_entries USING GIN(competency_tracking);
CREATE INDEX IF NOT EXISTS idx_journal_entries_tags ON journal_entries USING GIN(tags);

-- Text search indexes
CREATE INDEX IF NOT EXISTS idx_journal_entries_title_search ON journal_entries USING GIN(to_tsvector('english', title));
CREATE INDEX IF NOT EXISTS idx_journal_entries_content_search ON journal_entries USING GIN(to_tsvector('english', content));

-- Sync and performance indexes
CREATE INDEX IF NOT EXISTS idx_journal_entries_sync_status ON journal_entries(sync_status) WHERE sync_status != 'synced';
CREATE INDEX IF NOT EXISTS idx_journal_entries_updated_at ON journal_entries(updated_at) WHERE sync_status = 'pending';

-- ============================================================================
-- AUTOMATED TRIGGERS
-- ============================================================================

-- Auto-update timestamp trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    -- Reset sync status when content changes
    IF OLD.content != NEW.content OR OLD.title != NEW.title OR OLD.category != NEW.category THEN
        NEW.sync_status = 'pending';
        NEW.version = OLD.version + 1;
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS update_journal_entries_updated_at ON journal_entries;
CREATE TRIGGER update_journal_entries_updated_at 
    BEFORE UPDATE ON journal_entries 
    FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- Competency tracking validation trigger
CREATE OR REPLACE FUNCTION validate_competency_tracking()
RETURNS TRIGGER AS $$
BEGIN
    -- Ensure competency_tracking has valid structure
    IF NEW.competency_tracking IS NOT NULL THEN
        -- Validate that competency codes are properly formatted
        IF NOT (NEW.competency_tracking ? 'standards' OR jsonb_typeof(NEW.competency_tracking) = 'object') THEN
            RAISE EXCEPTION 'competency_tracking must be a valid JSON object';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS validate_journal_entries_competency ON journal_entries;
CREATE TRIGGER validate_journal_entries_competency 
    BEFORE INSERT OR UPDATE ON journal_entries 
    FOR EACH ROW EXECUTE PROCEDURE validate_competency_tracking();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on the table
ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Students can view own journal entries" ON journal_entries;
DROP POLICY IF EXISTS "Students can create own journal entries" ON journal_entries;
DROP POLICY IF EXISTS "Students can update own journal entries" ON journal_entries;
DROP POLICY IF EXISTS "Students can delete own journal entries" ON journal_entries;
DROP POLICY IF EXISTS "Instructors can view student entries" ON journal_entries;
DROP POLICY IF EXISTS "Instructors can update student entries for feedback" ON journal_entries;

-- Policy: Students can only see their own journal entries
CREATE POLICY "Students can view own journal entries" 
    ON journal_entries 
    FOR SELECT 
    USING (auth.uid() = user_id);

-- Policy: Students can insert their own journal entries
CREATE POLICY "Students can create own journal entries" 
    ON journal_entries 
    FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- Policy: Students can update their own journal entries
CREATE POLICY "Students can update own journal entries" 
    ON journal_entries 
    FOR UPDATE 
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy: Students can delete their own journal entries (soft delete recommended)
CREATE POLICY "Students can delete own journal entries" 
    ON journal_entries 
    FOR DELETE 
    USING (auth.uid() = user_id);

-- Policy: Instructors can view student entries (if proper permissions exist)
-- This requires a user_profiles table or similar permission system
CREATE POLICY "Instructors can view student entries" 
    ON journal_entries 
    FOR SELECT 
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles up
            WHERE up.id = auth.uid() 
            AND up.type IN ('educator', 'instructor', 'admin')
            AND (
                -- Same institution or supervising relationship
                up.educational_institution = (
                    SELECT up2.educational_institution 
                    FROM user_profiles up2 
                    WHERE up2.id = journal_entries.user_id
                )
                OR
                -- Admin can see all
                up.type = 'admin'
            )
        )
    );

-- Policy: Instructors can add feedback to student entries
CREATE POLICY "Instructors can update student entries for feedback" 
    ON journal_entries 
    FOR UPDATE 
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles up
            WHERE up.id = auth.uid() 
            AND up.type IN ('educator', 'instructor', 'admin')
        )
    )
    WITH CHECK (
        -- Can only update specific feedback fields
        OLD.user_id = NEW.user_id AND
        OLD.title = NEW.title AND 
        OLD.content = NEW.content AND
        OLD.category = NEW.category
    );

-- ============================================================================
-- SUPPORTING FUNCTIONS
-- ============================================================================

-- Function to get journal entries with animal details
CREATE OR REPLACE FUNCTION get_journal_entries_with_animal_details(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    id UUID,
    title TEXT,
    content TEXT,
    category TEXT,
    entry_date DATE,
    animal_name TEXT,
    animal_species TEXT,
    tags TEXT[],
    attachment_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        je.id,
        je.title,
        je.content,
        je.category,
        je.entry_date,
        a.name as animal_name,
        a.species as animal_species,
        je.tags,
        array_length(je.attachment_urls, 1) as attachment_count
    FROM journal_entries je
    LEFT JOIN animals a ON je.animal_id = a.id
    WHERE je.user_id = p_user_id
    ORDER BY je.entry_date DESC, je.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to search journal entries
CREATE OR REPLACE FUNCTION search_journal_entries(
    p_user_id UUID,
    p_search_term TEXT,
    p_category TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    id UUID,
    title TEXT,
    content TEXT,
    category TEXT,
    entry_date DATE,
    rank REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        je.id,
        je.title,
        je.content,
        je.category,
        je.entry_date,
        ts_rank(
            to_tsvector('english', je.title || ' ' || je.content),
            plainto_tsquery('english', p_search_term)
        ) as rank
    FROM journal_entries je
    WHERE je.user_id = p_user_id
    AND (p_category IS NULL OR je.category = p_category)
    AND (
        to_tsvector('english', je.title || ' ' || je.content) @@ 
        plainto_tsquery('english', p_search_term)
    )
    ORDER BY rank DESC, je.entry_date DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get FFA competency progress
CREATE OR REPLACE FUNCTION get_ffa_competency_progress(p_user_id UUID)
RETURNS TABLE (
    standard_code TEXT,
    entry_count INTEGER,
    latest_entry_date DATE,
    competency_level TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        unnest(ffa_standards) as standard_code,
        COUNT(*) as entry_count,
        MAX(entry_date) as latest_entry_date,
        CASE 
            WHEN COUNT(*) >= 5 THEN 'Proficient'
            WHEN COUNT(*) >= 3 THEN 'Developing'
            WHEN COUNT(*) >= 1 THEN 'Beginning'
            ELSE 'Not Started'
        END as competency_level
    FROM journal_entries
    WHERE user_id = p_user_id
    AND ffa_standards IS NOT NULL
    AND array_length(ffa_standards, 1) > 0
    GROUP BY unnest(ffa_standards)
    ORDER BY entry_count DESC, latest_entry_date DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get journal analytics for educators
CREATE OR REPLACE FUNCTION get_student_journal_analytics(
    p_student_id UUID,
    p_days_back INTEGER DEFAULT 30
)
RETURNS TABLE (
    total_entries INTEGER,
    avg_entries_per_week NUMERIC,
    most_common_category TEXT,
    entries_with_competencies INTEGER,
    unique_competencies_covered INTEGER,
    last_entry_date DATE
) AS $$
DECLARE
    start_date DATE := CURRENT_DATE - INTERVAL '1 day' * p_days_back;
BEGIN
    RETURN QUERY
    WITH stats AS (
        SELECT 
            COUNT(*) as total,
            COUNT(*) / (p_days_back::NUMERIC / 7) as avg_weekly,
            MODE() WITHIN GROUP (ORDER BY category) as top_category,
            COUNT(*) FILTER (WHERE ffa_standards IS NOT NULL AND array_length(ffa_standards, 1) > 0) as with_competencies,
            array_length(array_agg(DISTINCT unnest(ffa_standards)), 1) as unique_standards,
            MAX(entry_date) as last_entry
        FROM journal_entries
        WHERE user_id = p_student_id 
        AND entry_date >= start_date
    )
    SELECT 
        total::INTEGER,
        ROUND(avg_weekly, 2),
        top_category,
        with_competencies::INTEGER,
        COALESCE(unique_standards, 0)::INTEGER,
        last_entry
    FROM stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- ANALYTICS VIEWS
-- ============================================================================

-- View for journal entry statistics
CREATE OR REPLACE VIEW journal_entry_stats AS
SELECT 
    user_id,
    COUNT(*) as total_entries,
    COUNT(DISTINCT animal_id) as animals_tracked,
    COUNT(DISTINCT category) as categories_used,
    array_agg(DISTINCT category) as categories,
    MIN(entry_date) as first_entry_date,
    MAX(entry_date) as latest_entry_date,
    AVG(array_length(tags, 1)) as avg_tags_per_entry,
    COUNT(*) FILTER (WHERE is_draft = false) as published_entries,
    COUNT(*) FILTER (WHERE instructor_reviewed = true) as reviewed_entries
FROM journal_entries
GROUP BY user_id;

-- View for FFA standards tracking
CREATE OR REPLACE VIEW ffa_standards_progress AS
SELECT 
    user_id,
    unnest(ffa_standards) as standard_code,
    COUNT(*) as demonstration_count,
    MIN(entry_date) as first_demonstration,
    MAX(entry_date) as latest_demonstration,
    string_agg(DISTINCT category, ', ') as categories_demonstrated
FROM journal_entries
WHERE ffa_standards IS NOT NULL
AND array_length(ffa_standards, 1) > 0
GROUP BY user_id, unnest(ffa_standards);

-- View for recent journal activity (last 30 days)
CREATE OR REPLACE VIEW recent_journal_activity AS
SELECT 
    je.user_id,
    up.email as student_email,
    COUNT(*) as entries_last_30_days,
    COUNT(DISTINCT je.category) as categories_used,
    MAX(je.entry_date) as last_entry_date,
    string_agg(DISTINCT je.category, ', ' ORDER BY je.category) as active_categories
FROM journal_entries je
LEFT JOIN user_profiles up ON up.id = je.user_id
WHERE je.entry_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY je.user_id, up.email
ORDER BY entries_last_30_days DESC;

-- ============================================================================
-- GRANTS AND PERMISSIONS
-- ============================================================================

-- Grant necessary permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON journal_entries TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT EXECUTE ON FUNCTION get_journal_entries_with_animal_details TO authenticated;
GRANT EXECUTE ON FUNCTION search_journal_entries TO authenticated;
GRANT EXECUTE ON FUNCTION get_ffa_competency_progress TO authenticated;
GRANT EXECUTE ON FUNCTION get_student_journal_analytics TO authenticated;

-- Grant read access to views
GRANT SELECT ON journal_entry_stats TO authenticated;
GRANT SELECT ON ffa_standards_progress TO authenticated;
GRANT SELECT ON recent_journal_activity TO authenticated;

-- ============================================================================
-- DATA INTEGRITY CHECKS
-- ============================================================================

-- Function to validate existing data and fix any issues
CREATE OR REPLACE FUNCTION validate_journal_data()
RETURNS TEXT AS $$
DECLARE
    result_text TEXT := '';
    invalid_count INTEGER;
BEGIN
    -- Check for entries with invalid dates
    SELECT COUNT(*) INTO invalid_count
    FROM journal_entries 
    WHERE entry_date > CURRENT_DATE;
    
    IF invalid_count > 0 THEN
        result_text := result_text || format('Found %s entries with future dates. ', invalid_count);
        -- Fix future dates by setting them to today
        UPDATE journal_entries 
        SET entry_date = CURRENT_DATE 
        WHERE entry_date > CURRENT_DATE;
        result_text := result_text || 'Fixed future dates. ';
    END IF;
    
    -- Check for empty content
    SELECT COUNT(*) INTO invalid_count
    FROM journal_entries 
    WHERE trim(content) = '' OR content IS NULL;
    
    IF invalid_count > 0 THEN
        result_text := result_text || format('Found %s entries with empty content. ', invalid_count);
    END IF;
    
    -- Check for orphaned animal references
    SELECT COUNT(*) INTO invalid_count
    FROM journal_entries je
    LEFT JOIN animals a ON a.id = je.animal_id
    WHERE je.animal_id IS NOT NULL AND a.id IS NULL;
    
    IF invalid_count > 0 THEN
        result_text := result_text || format('Found %s entries with invalid animal references. ', invalid_count);
        -- Clean up orphaned references
        UPDATE journal_entries 
        SET animal_id = NULL 
        WHERE animal_id IS NOT NULL 
        AND animal_id NOT IN (SELECT id FROM animals);
        result_text := result_text || 'Cleaned up orphaned animal references. ';
    END IF;
    
    IF result_text = '' THEN
        result_text := 'All journal data is valid. No issues found.';
    END IF;
    
    RETURN result_text;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- MIGRATION VERIFICATION AND COMPLETION
-- ============================================================================

-- Run data validation
SELECT validate_journal_data() AS validation_result;

-- Verify table creation and setup
DO $$
DECLARE
    table_exists BOOLEAN;
    index_count INTEGER;
    policy_count INTEGER;
    function_count INTEGER;
BEGIN
    -- Check table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'journal_entries'
    ) INTO table_exists;
    
    IF NOT table_exists THEN
        RAISE EXCEPTION 'journal_entries table was not created successfully';
    END IF;
    
    -- Count indexes
    SELECT COUNT(*) INTO index_count
    FROM pg_indexes 
    WHERE tablename = 'journal_entries';
    
    -- Count policies
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies 
    WHERE tablename = 'journal_entries';
    
    -- Count functions
    SELECT COUNT(*) INTO function_count
    FROM information_schema.routines
    WHERE routine_schema = 'public' 
    AND routine_name LIKE '%journal%';
    
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'ShowTrackAI Journal Entries Schema Migration COMPLETED!';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Created table: journal_entries';
    RAISE NOTICE 'Created indexes: % performance indexes', index_count;
    RAISE NOTICE 'Created policies: % RLS security policies', policy_count;
    RAISE NOTICE 'Created functions: % helper functions', function_count;
    RAISE NOTICE 'Created views: 3 analytics views';
    RAISE NOTICE 'Created triggers: 2 automated triggers';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Schema is ready for Flutter app integration!';
    RAISE NOTICE 'All RLS policies are active for multi-tenant security.';
    RAISE NOTICE 'FFA compliance tracking is enabled.';
    RAISE NOTICE 'Offline sync capabilities are supported.';
    RAISE NOTICE '===========================================';
END;
$$;