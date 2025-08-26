-- ============================================================================
-- ShowTrackAI Journal Entries Field Mapping Fix
-- Migration: 20250202_fix_journal_entries_field_mapping
-- Created: 2025-02-02
-- Purpose: Ensure all journal fields from Flutter model are properly stored
-- ============================================================================

-- Add missing columns to journal_entries table
ALTER TABLE journal_entries 
ADD COLUMN IF NOT EXISTS entry_text TEXT,
ADD COLUMN IF NOT EXISTS duration_minutes INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS aet_skills TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}',
ADD COLUMN IF NOT EXISTS learning_objectives TEXT[],
ADD COLUMN IF NOT EXISTS challenges_faced TEXT,
ADD COLUMN IF NOT EXISTS improvements_planned TEXT,
ADD COLUMN IF NOT EXISTS learning_concepts TEXT[],
ADD COLUMN IF NOT EXISTS competency_level TEXT,
ADD COLUMN IF NOT EXISTS ai_insights JSONB,
ADD COLUMN IF NOT EXISTS location_latitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS location_longitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS location_address TEXT,
ADD COLUMN IF NOT EXISTS location_name TEXT,
ADD COLUMN IF NOT EXISTS location_accuracy DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS location_captured_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS location_city TEXT,
ADD COLUMN IF NOT EXISTS location_state TEXT,
ADD COLUMN IF NOT EXISTS weather_temperature DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS weather_condition TEXT,
ADD COLUMN IF NOT EXISTS weather_humidity INTEGER,
ADD COLUMN IF NOT EXISTS weather_wind_speed DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS weather_description TEXT,
ADD COLUMN IF NOT EXISTS weather_data_json JSONB,
ADD COLUMN IF NOT EXISTS supervisor_id UUID,
ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS ffa_degree_type TEXT,
ADD COLUMN IF NOT EXISTS counts_for_degree BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS sae_type TEXT,
ADD COLUMN IF NOT EXISTS hours_logged DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS financial_value DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS evidence_type TEXT,
ADD COLUMN IF NOT EXISTS is_synced BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS last_sync_attempt TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS sync_error TEXT,
ADD COLUMN IF NOT EXISTS trace_id TEXT;

-- Update existing content column to sync with entry_text
CREATE OR REPLACE FUNCTION sync_entry_text_content()
RETURNS TRIGGER AS $$
BEGIN
    -- If entry_text is provided, copy to content
    IF NEW.entry_text IS NOT NULL AND NEW.entry_text != '' THEN
        NEW.content = NEW.entry_text;
    -- If content is provided, copy to entry_text
    ELSIF NEW.content IS NOT NULL AND NEW.content != '' THEN
        NEW.entry_text = NEW.content;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS sync_journal_text_fields ON journal_entries;

-- Create trigger to sync entry_text and content fields
CREATE TRIGGER sync_journal_text_fields
    BEFORE INSERT OR UPDATE ON journal_entries
    FOR EACH ROW EXECUTE FUNCTION sync_entry_text_content();

-- Create indexes for new fields
CREATE INDEX IF NOT EXISTS idx_journal_entries_aet_skills ON journal_entries USING GIN(aet_skills);
CREATE INDEX IF NOT EXISTS idx_journal_entries_metadata ON journal_entries USING GIN(metadata);
CREATE INDEX IF NOT EXISTS idx_journal_entries_location ON journal_entries(location_latitude, location_longitude) 
    WHERE location_latitude IS NOT NULL AND location_longitude IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_journal_entries_weather ON journal_entries(weather_condition) 
    WHERE weather_condition IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_journal_entries_sae_type ON journal_entries(sae_type) 
    WHERE sae_type IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_journal_entries_trace_id ON journal_entries(trace_id) 
    WHERE trace_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_journal_entries_sync_pending ON journal_entries(is_synced, last_sync_attempt) 
    WHERE is_synced = FALSE;

-- Update category check constraint to include all Flutter model categories
ALTER TABLE journal_entries DROP CONSTRAINT IF EXISTS journal_entries_category_check;
ALTER TABLE journal_entries ADD CONSTRAINT journal_entries_category_check 
    CHECK (category IN (
        'general', 'health', 'feeding', 'training', 'breeding', 'showing',
        'maintenance', 'observation', 'learning', 'project', 'competition',
        'sae', 'ffa_activity', 'career_exploration', 'leadership',
        'daily_care', 'health_check', 'show_prep', 'veterinary',
        'record_keeping', 'financial', 'learning_reflection',
        'project_planning', 'community_service', 'leadership_activity',
        'safety_training', 'research', 'other'
    ));

-- Function to validate field mapping
CREATE OR REPLACE FUNCTION validate_journal_field_mapping()
RETURNS TABLE(
    field_name TEXT,
    field_type TEXT,
    is_nullable TEXT,
    has_default TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        column_name::TEXT,
        data_type::TEXT,
        is_nullable::TEXT,
        CASE 
            WHEN column_default IS NOT NULL THEN 'YES'
            ELSE 'NO'
        END::TEXT
    FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'journal_entries'
    AND column_name IN (
        'id', 'user_id', 'title', 'entry_text', 'entry_date',
        'duration_minutes', 'category', 'aet_skills', 'animal_id',
        'metadata', 'learning_objectives', 'learning_outcomes',
        'challenges_faced', 'improvements_planned', 'photos',
        'quality_score', 'ffa_standards', 'learning_concepts',
        'competency_level', 'ai_insights', 'created_at', 'updated_at',
        'location_latitude', 'location_longitude', 'location_address',
        'location_name', 'location_accuracy', 'location_captured_at',
        'location_city', 'location_state', 'weather_temperature',
        'weather_condition', 'weather_humidity', 'weather_wind_speed',
        'weather_description', 'weather_data_json', 'attachment_urls',
        'tags', 'supervisor_id', 'is_public', 'ffa_degree_type',
        'counts_for_degree', 'sae_type', 'hours_logged', 'financial_value',
        'evidence_type', 'is_synced', 'last_sync_attempt', 'sync_error',
        'trace_id'
    )
    ORDER BY column_name;
END;
$$ LANGUAGE plpgsql;

-- Verification query
DO $$
DECLARE
    missing_fields TEXT[] := '{}';
    required_fields TEXT[] := ARRAY[
        'entry_text', 'duration_minutes', 'aet_skills', 'metadata',
        'learning_objectives', 'challenges_faced', 'improvements_planned',
        'learning_concepts', 'competency_level', 'ai_insights',
        'location_latitude', 'location_longitude', 'weather_temperature',
        'weather_condition', 'sae_type', 'hours_logged', 'financial_value',
        'trace_id'
    ];
    field TEXT;
BEGIN
    -- Check for missing required fields
    FOREACH field IN ARRAY required_fields
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public' 
            AND table_name = 'journal_entries'
            AND column_name = field
        ) THEN
            missing_fields := array_append(missing_fields, field);
        END IF;
    END LOOP;
    
    IF array_length(missing_fields, 1) > 0 THEN
        RAISE WARNING 'Missing fields detected: %', missing_fields;
    ELSE
        RAISE NOTICE '✅ All required fields are present in journal_entries table';
    END IF;
    
    RAISE NOTICE '===========================================';    
    RAISE NOTICE 'Journal Field Mapping Migration COMPLETED!';
    RAISE NOTICE '===========================================';    
    RAISE NOTICE 'Added missing columns for Flutter model compatibility';
    RAISE NOTICE 'Created sync trigger for entry_text/content fields';
    RAISE NOTICE 'Added indexes for performance optimization';
    RAISE NOTICE 'Updated category constraints';
    RAISE NOTICE '===========================================';    
    RAISE NOTICE 'Journal entries now support all fields:';
    RAISE NOTICE '- Core fields: title, entry_text, category';
    RAISE NOTICE '- Time tracking: duration_minutes, entry_date';
    RAISE NOTICE '- Educational: ffa_standards, learning_objectives';
    RAISE NOTICE '- Location: latitude, longitude, address';
    RAISE NOTICE '- Weather: temperature, condition, humidity';
    RAISE NOTICE '- Metadata: source, notes, trace_id';
    RAISE NOTICE '===========================================';    
END;
$$;

-- Sample test to verify field mapping
SELECT * FROM validate_journal_field_mapping();
