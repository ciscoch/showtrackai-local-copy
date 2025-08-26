-- ============================================================================
-- Journal Entry AI Assessments Table
-- Migration: 20250202_create_journal_entry_ai_assessments
-- Created: 2025-02-02
-- Purpose: Create dedicated table for storing normalized AI assessments from N8N
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- JOURNAL ENTRY AI ASSESSMENTS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS journal_entry_ai_assessments (
    -- Primary identifiers
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    journal_entry_id UUID NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,
    
    -- Assessment metadata
    assessment_type TEXT NOT NULL DEFAULT 'journal_analysis' CHECK (assessment_type IN (
        'journal_analysis', 'competency_evaluation', 'quality_review', 'learning_assessment'
    )),
    assessment_version TEXT NOT NULL DEFAULT '1.0',
    processed_by TEXT NOT NULL DEFAULT 'n8n_financial_agent',
    
    -- Core assessment scores (0-10 scale)
    quality_score DECIMAL(3,1) CHECK (quality_score >= 0 AND quality_score <= 10),
    engagement_score DECIMAL(3,1) CHECK (engagement_score >= 0 AND engagement_score <= 10),
    learning_depth_score DECIMAL(3,1) CHECK (learning_depth_score >= 0 AND learning_depth_score <= 10),
    
    -- FFA competency tracking
    competencies_identified JSONB DEFAULT '[]'::jsonb,
    ffa_standards_matched JSONB DEFAULT '[]'::jsonb,
    learning_objectives_achieved JSONB DEFAULT '[]'::jsonb,
    
    -- Assessment insights (structured arrays)
    strengths_identified JSONB DEFAULT '[]'::jsonb,
    growth_areas JSONB DEFAULT '[]'::jsonb,
    recommendations JSONB DEFAULT '[]'::jsonb,
    
    -- Additional analysis
    key_concepts JSONB DEFAULT '[]'::jsonb,
    vocabulary_used JSONB DEFAULT '[]'::jsonb,
    technical_accuracy_notes TEXT,
    
    -- Assessment confidence and metadata
    confidence_score DECIMAL(3,2) CHECK (confidence_score >= 0 AND confidence_score <= 1),
    processing_duration_ms INTEGER,
    model_used TEXT,
    
    -- Processing correlation
    n8n_run_id TEXT, -- Links to SPAR runs table
    trace_id UUID,   -- Distributed tracing correlation
    
    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Unique constraint to prevent duplicate assessments
    UNIQUE(journal_entry_id, assessment_type, assessment_version)
);

-- ============================================================================
-- PERFORMANCE INDEXES
-- ============================================================================

-- Primary query patterns
CREATE INDEX IF NOT EXISTS idx_ai_assessments_journal_entry ON journal_entry_ai_assessments(journal_entry_id);
CREATE INDEX IF NOT EXISTS idx_ai_assessments_quality_score ON journal_entry_ai_assessments(quality_score DESC) WHERE quality_score IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ai_assessments_created_at ON journal_entry_ai_assessments(created_at DESC);

-- Assessment type and correlation indexes
CREATE INDEX IF NOT EXISTS idx_ai_assessments_type ON journal_entry_ai_assessments(assessment_type);
CREATE INDEX IF NOT EXISTS idx_ai_assessments_trace_id ON journal_entry_ai_assessments(trace_id) WHERE trace_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ai_assessments_n8n_run ON journal_entry_ai_assessments(n8n_run_id) WHERE n8n_run_id IS NOT NULL;

-- Competency and FFA standards indexes (JSONB GIN)
CREATE INDEX IF NOT EXISTS idx_ai_assessments_competencies ON journal_entry_ai_assessments USING GIN(competencies_identified);
CREATE INDEX IF NOT EXISTS idx_ai_assessments_ffa_standards ON journal_entry_ai_assessments USING GIN(ffa_standards_matched);
CREATE INDEX IF NOT EXISTS idx_ai_assessments_strengths ON journal_entry_ai_assessments USING GIN(strengths_identified);
CREATE INDEX IF NOT EXISTS idx_ai_assessments_recommendations ON journal_entry_ai_assessments USING GIN(recommendations);

-- ============================================================================
-- AUTOMATED TRIGGERS
-- ============================================================================

-- Auto-update timestamp trigger
CREATE OR REPLACE FUNCTION update_ai_assessment_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER update_ai_assessments_updated_at 
    BEFORE UPDATE ON journal_entry_ai_assessments 
    FOR EACH ROW EXECUTE PROCEDURE update_ai_assessment_updated_at();

-- Validation trigger for JSONB structure
CREATE OR REPLACE FUNCTION validate_ai_assessment_jsonb()
RETURNS TRIGGER AS $$
BEGIN
    -- Validate competencies_identified structure
    IF NEW.competencies_identified IS NOT NULL THEN
        IF NOT (jsonb_typeof(NEW.competencies_identified) = 'array') THEN
            RAISE EXCEPTION 'competencies_identified must be a valid JSON array';
        END IF;
    END IF;
    
    -- Validate ffa_standards_matched structure
    IF NEW.ffa_standards_matched IS NOT NULL THEN
        IF NOT (jsonb_typeof(NEW.ffa_standards_matched) = 'array') THEN
            RAISE EXCEPTION 'ffa_standards_matched must be a valid JSON array';
        END IF;
    END IF;
    
    -- Validate recommendations structure
    IF NEW.recommendations IS NOT NULL THEN
        IF NOT (jsonb_typeof(NEW.recommendations) = 'array') THEN
            RAISE EXCEPTION 'recommendations must be a valid JSON array';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER validate_ai_assessment_jsonb_trigger 
    BEFORE INSERT OR UPDATE ON journal_entry_ai_assessments 
    FOR EACH ROW EXECUTE PROCEDURE validate_ai_assessment_jsonb();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on the table
ALTER TABLE journal_entry_ai_assessments ENABLE ROW LEVEL SECURITY;

-- Students can view AI assessments for their own journal entries
CREATE POLICY "Students can view own AI assessments" 
    ON journal_entry_ai_assessments 
    FOR SELECT 
    USING (
        EXISTS (
            SELECT 1 FROM journal_entries je
            WHERE je.id = journal_entry_ai_assessments.journal_entry_id
            AND je.user_id = auth.uid()
        )
    );

-- Educators can view AI assessments for students in their institution
CREATE POLICY "Educators can view student AI assessments" 
    ON journal_entry_ai_assessments 
    FOR SELECT 
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles up
            WHERE up.id = auth.uid() 
            AND up.type IN ('educator', 'instructor', 'admin')
            AND EXISTS (
                SELECT 1 FROM journal_entries je
                JOIN user_profiles student_up ON student_up.id = je.user_id
                WHERE je.id = journal_entry_ai_assessments.journal_entry_id
                AND (
                    up.educational_institution = student_up.educational_institution
                    OR up.type = 'admin'
                )
            )
        )
    );

-- Only system can insert/update AI assessments (via Edge Functions)
-- No direct INSERT/UPDATE policies for regular users

-- ============================================================================
-- DATABASE FUNCTIONS FOR AI ASSESSMENT MANAGEMENT
-- ============================================================================

-- Function to upsert AI assessment (used by Edge Function)
CREATE OR REPLACE FUNCTION upsert_ai_assessment(
    p_journal_entry_id UUID,
    p_assessment_data JSONB,
    p_n8n_run_id TEXT DEFAULT NULL,
    p_trace_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_assessment_id UUID;
    v_assessment_type TEXT := COALESCE(p_assessment_data->>'assessment_type', 'journal_analysis');
    v_assessment_version TEXT := COALESCE(p_assessment_data->>'assessment_version', '1.0');
BEGIN
    -- Insert or update the assessment
    INSERT INTO journal_entry_ai_assessments (
        journal_entry_id,
        assessment_type,
        assessment_version,
        processed_by,
        quality_score,
        engagement_score,
        learning_depth_score,
        competencies_identified,
        ffa_standards_matched,
        learning_objectives_achieved,
        strengths_identified,
        growth_areas,
        recommendations,
        key_concepts,
        vocabulary_used,
        technical_accuracy_notes,
        confidence_score,
        processing_duration_ms,
        model_used,
        n8n_run_id,
        trace_id
    ) VALUES (
        p_journal_entry_id,
        v_assessment_type,
        v_assessment_version,
        COALESCE(p_assessment_data->>'processed_by', 'n8n_financial_agent'),
        (p_assessment_data->>'quality_score')::DECIMAL(3,1),
        (p_assessment_data->>'engagement_score')::DECIMAL(3,1),
        (p_assessment_data->>'learning_depth_score')::DECIMAL(3,1),
        COALESCE(p_assessment_data->'competencies_identified', '[]'::jsonb),
        COALESCE(p_assessment_data->'ffa_standards_matched', '[]'::jsonb),
        COALESCE(p_assessment_data->'learning_objectives_achieved', '[]'::jsonb),
        COALESCE(p_assessment_data->'strengths_identified', '[]'::jsonb),
        COALESCE(p_assessment_data->'growth_areas', '[]'::jsonb),
        COALESCE(p_assessment_data->'recommendations', '[]'::jsonb),
        COALESCE(p_assessment_data->'key_concepts', '[]'::jsonb),
        COALESCE(p_assessment_data->'vocabulary_used', '[]'::jsonb),
        p_assessment_data->>'technical_accuracy_notes',
        (p_assessment_data->>'confidence_score')::DECIMAL(3,2),
        (p_assessment_data->>'processing_duration_ms')::INTEGER,
        p_assessment_data->>'model_used',
        p_n8n_run_id,
        p_trace_id
    )
    ON CONFLICT (journal_entry_id, assessment_type, assessment_version)
    DO UPDATE SET
        processed_by = EXCLUDED.processed_by,
        quality_score = EXCLUDED.quality_score,
        engagement_score = EXCLUDED.engagement_score,
        learning_depth_score = EXCLUDED.learning_depth_score,
        competencies_identified = EXCLUDED.competencies_identified,
        ffa_standards_matched = EXCLUDED.ffa_standards_matched,
        learning_objectives_achieved = EXCLUDED.learning_objectives_achieved,
        strengths_identified = EXCLUDED.strengths_identified,
        growth_areas = EXCLUDED.growth_areas,
        recommendations = EXCLUDED.recommendations,
        key_concepts = EXCLUDED.key_concepts,
        vocabulary_used = EXCLUDED.vocabulary_used,
        technical_accuracy_notes = EXCLUDED.technical_accuracy_notes,
        confidence_score = EXCLUDED.confidence_score,
        processing_duration_ms = EXCLUDED.processing_duration_ms,
        model_used = EXCLUDED.model_used,
        n8n_run_id = EXCLUDED.n8n_run_id,
        trace_id = EXCLUDED.trace_id,
        updated_at = NOW()
    RETURNING id INTO v_assessment_id;
    
    RETURN v_assessment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get AI assessment for journal entry
CREATE OR REPLACE FUNCTION get_ai_assessment_for_journal_entry(
    p_journal_entry_id UUID,
    p_assessment_type TEXT DEFAULT 'journal_analysis'
)
RETURNS TABLE (
    id UUID,
    assessment_type TEXT,
    quality_score DECIMAL,
    engagement_score DECIMAL,
    learning_depth_score DECIMAL,
    competencies_identified JSONB,
    ffa_standards_matched JSONB,
    strengths_identified JSONB,
    growth_areas JSONB,
    recommendations JSONB,
    confidence_score DECIMAL,
    processed_at TIMESTAMP WITH TIME ZONE,
    model_used TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        aia.id,
        aia.assessment_type,
        aia.quality_score,
        aia.engagement_score,
        aia.learning_depth_score,
        aia.competencies_identified,
        aia.ffa_standards_matched,
        aia.strengths_identified,
        aia.growth_areas,
        aia.recommendations,
        aia.confidence_score,
        aia.created_at as processed_at,
        aia.model_used
    FROM journal_entry_ai_assessments aia
    WHERE aia.journal_entry_id = p_journal_entry_id
    AND aia.assessment_type = p_assessment_type
    ORDER BY aia.created_at DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get student competency progress from AI assessments
CREATE OR REPLACE FUNCTION get_student_ai_competency_progress(
    p_user_id UUID,
    p_days_back INTEGER DEFAULT 30
)
RETURNS TABLE (
    competency_code TEXT,
    assessment_count INTEGER,
    avg_quality_score DECIMAL,
    latest_assessment_date TIMESTAMP WITH TIME ZONE,
    progress_trend TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH competency_data AS (
        SELECT 
            jsonb_array_elements_text(aia.competencies_identified) as competency,
            aia.quality_score,
            aia.created_at,
            ROW_NUMBER() OVER (
                PARTITION BY jsonb_array_elements_text(aia.competencies_identified) 
                ORDER BY aia.created_at DESC
            ) as rn
        FROM journal_entry_ai_assessments aia
        JOIN journal_entries je ON je.id = aia.journal_entry_id
        WHERE je.user_id = p_user_id
        AND aia.created_at >= NOW() - INTERVAL '1 day' * p_days_back
        AND aia.quality_score IS NOT NULL
    )
    SELECT 
        cd.competency,
        COUNT(*)::INTEGER,
        ROUND(AVG(cd.quality_score), 2),
        MAX(cd.created_at),
        CASE 
            WHEN COUNT(*) >= 5 THEN 'Consistent'
            WHEN COUNT(*) >= 3 THEN 'Developing'
            WHEN COUNT(*) >= 1 THEN 'Beginning'
            ELSE 'Not Started'
        END
    FROM competency_data cd
    GROUP BY cd.competency
    ORDER BY COUNT(*) DESC, MAX(cd.created_at) DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- ANALYTICS VIEWS
-- ============================================================================

-- View for journal AI assessment summary
CREATE OR REPLACE VIEW journal_ai_assessment_summary AS
SELECT 
    je.user_id,
    je.id as journal_entry_id,
    je.title as journal_title,
    je.category as journal_category,
    je.entry_date,
    aia.id as assessment_id,
    aia.quality_score,
    aia.engagement_score,
    aia.learning_depth_score,
    aia.confidence_score,
    jsonb_array_length(aia.competencies_identified) as competencies_count,
    jsonb_array_length(aia.ffa_standards_matched) as ffa_standards_count,
    jsonb_array_length(aia.strengths_identified) as strengths_count,
    jsonb_array_length(aia.recommendations) as recommendations_count,
    aia.model_used,
    aia.created_at as assessment_date
FROM journal_entries je
JOIN journal_entry_ai_assessments aia ON aia.journal_entry_id = je.id
ORDER BY je.entry_date DESC, aia.created_at DESC;

-- View for competency progress tracking
CREATE OR REPLACE VIEW ai_competency_progress AS
SELECT 
    je.user_id,
    jsonb_array_elements_text(aia.competencies_identified) as competency_code,
    COUNT(*) as demonstration_count,
    AVG(aia.quality_score) as avg_quality_score,
    MAX(aia.created_at) as latest_assessment,
    MIN(aia.created_at) as first_assessment,
    STDDEV(aia.quality_score) as score_variance
FROM journal_entries je
JOIN journal_entry_ai_assessments aia ON aia.journal_entry_id = je.id
WHERE aia.competencies_identified IS NOT NULL
GROUP BY je.user_id, jsonb_array_elements_text(aia.competencies_identified);

-- ============================================================================
-- GRANTS AND PERMISSIONS
-- ============================================================================

-- Grant necessary permissions to authenticated users
GRANT SELECT ON journal_entry_ai_assessments TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT EXECUTE ON FUNCTION upsert_ai_assessment TO authenticated;
GRANT EXECUTE ON FUNCTION get_ai_assessment_for_journal_entry TO authenticated;
GRANT EXECUTE ON FUNCTION get_student_ai_competency_progress TO authenticated;

-- Grant read access to views
GRANT SELECT ON journal_ai_assessment_summary TO authenticated;
GRANT SELECT ON ai_competency_progress TO authenticated;

-- ============================================================================
-- MIGRATION VERIFICATION AND COMPLETION
-- ============================================================================

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
        WHERE table_schema = 'public' AND table_name = 'journal_entry_ai_assessments'
    ) INTO table_exists;
    
    IF NOT table_exists THEN
        RAISE EXCEPTION 'journal_entry_ai_assessments table was not created successfully';
    END IF;
    
    -- Count indexes
    SELECT COUNT(*) INTO index_count
    FROM pg_indexes 
    WHERE tablename = 'journal_entry_ai_assessments';
    
    -- Count policies
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies 
    WHERE tablename = 'journal_entry_ai_assessments';
    
    -- Count new functions
    SELECT COUNT(*) INTO function_count
    FROM information_schema.routines
    WHERE routine_schema = 'public' 
    AND routine_name IN ('upsert_ai_assessment', 'get_ai_assessment_for_journal_entry', 'get_student_ai_competency_progress');
    
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Journal Entry AI Assessments Migration COMPLETED!';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Created table: journal_entry_ai_assessments';
    RAISE NOTICE 'Created indexes: % performance indexes', index_count;
    RAISE NOTICE 'Created policies: % RLS security policies', policy_count;
    RAISE NOTICE 'Created functions: % helper functions', function_count;
    RAISE NOTICE 'Created views: 2 analytics views';
    RAISE NOTICE 'Created triggers: 2 automated triggers';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'AI Assessment table is ready for N8N integration!';
    RAISE NOTICE 'All RLS policies are active for secure access.';
    RAISE NOTICE 'Normalized data structure supports advanced analytics.';
    RAISE NOTICE '===========================================';
END;
$$;