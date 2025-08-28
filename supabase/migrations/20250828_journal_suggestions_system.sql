-- ============================================================================
-- ShowTrackAI Journal Suggestions System Database Schema
-- Migration: 20250828_journal_suggestions_system
-- Created: 2025-08-28
-- Purpose: Journal Entry Content auto-populate with COPPA compliance
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- For text similarity search

BEGIN;

-- ============================================================================
-- SECTION 1: JOURNAL SUGGESTION TEMPLATES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS journal_suggestion_templates (
    -- Primary identifiers
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    template_id VARCHAR(50) UNIQUE NOT NULL, -- e.g., "daily_care_pig_001"
    
    -- Content structure
    title_template TEXT NOT NULL, -- e.g., "Daily Care Check - {{animal_name}}"
    content_template TEXT NOT NULL, -- With placeholders like {{weather}}, {{date}}
    category TEXT NOT NULL CHECK (category IN (
        'daily_care', 'health_check', 'feeding', 'training', 'show_prep', 
        'veterinary', 'breeding', 'record_keeping', 'financial', 
        'learning_reflection', 'project_planning', 'competition'
    )),
    
    -- Targeting and filtering
    species_filter TEXT[] DEFAULT '{}', -- ['pig', 'goat', 'cattle'] or NULL for all
    age_group TEXT[] DEFAULT '{}' CHECK (
        age_group IS NULL OR 
        age_group <@ ARRAY['elementary', 'middle_school', 'high_school', 'adult']
    ), -- COPPA compliance filtering
    competency_level TEXT[] DEFAULT '{}', -- ['novice', 'developing', 'proficient']
    ffa_standards TEXT[] DEFAULT '{}', -- Relevant FFA standards
    
    -- Template metadata
    difficulty_level INTEGER DEFAULT 1 CHECK (difficulty_level >= 1 AND difficulty_level <= 5),
    estimated_time_minutes INTEGER DEFAULT 15,
    required_fields JSONB DEFAULT '[]', -- Fields that must be filled
    optional_fields JSONB DEFAULT '[]', -- Optional enhancement fields
    
    -- Usage and quality metrics
    usage_count INTEGER DEFAULT 0,
    success_rate DECIMAL(5,2) DEFAULT 0.0, -- Percentage of users who complete after using
    average_rating DECIMAL(3,2) DEFAULT 0.0,
    
    -- Administrative
    is_active BOOLEAN DEFAULT TRUE,
    coppa_compliant BOOLEAN DEFAULT TRUE, -- Age-appropriate content verified
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- SECTION 2: USER SUGGESTION PREFERENCES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_suggestion_preferences (
    -- Primary identifiers
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Suggestion preferences
    enable_suggestions BOOLEAN DEFAULT TRUE,
    auto_populate_weather BOOLEAN DEFAULT TRUE,
    auto_populate_location BOOLEAN DEFAULT FALSE, -- Disabled by default for privacy
    auto_populate_previous_context BOOLEAN DEFAULT TRUE,
    
    -- Content preferences by age group (COPPA compliance)
    suggestion_complexity TEXT DEFAULT 'age_appropriate' CHECK (
        suggestion_complexity IN ('simple', 'age_appropriate', 'advanced')
    ),
    include_educational_prompts BOOLEAN DEFAULT TRUE,
    include_reflection_questions BOOLEAN DEFAULT TRUE,
    
    -- Filtering preferences
    preferred_categories TEXT[] DEFAULT '{}',
    blocked_categories TEXT[] DEFAULT '{}',
    preferred_templates TEXT[] DEFAULT '{}', -- Template IDs user likes
    blocked_templates TEXT[] DEFAULT '{}', -- Template IDs user dislikes
    
    -- Privacy and safety (COPPA compliance)
    parent_supervised BOOLEAN DEFAULT FALSE, -- For users under 13
    content_review_required BOOLEAN DEFAULT FALSE,
    safe_content_only BOOLEAN DEFAULT TRUE,
    
    -- Personalization data
    learning_style TEXT DEFAULT 'visual' CHECK (
        learning_style IN ('visual', 'auditory', 'kinesthetic', 'mixed')
    ),
    experience_level TEXT DEFAULT 'beginner' CHECK (
        experience_level IN ('beginner', 'intermediate', 'advanced', 'expert')
    ),
    primary_animal_species TEXT, -- Most worked with animal
    primary_ffa_interest TEXT, -- Career interest area
    
    -- Usage analytics
    suggestions_used INTEGER DEFAULT 0,
    suggestions_dismissed INTEGER DEFAULT 0,
    custom_modifications INTEGER DEFAULT 0, -- How often they edit suggestions
    
    -- Audit trail
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- SECTION 3: SUGGESTION ANALYTICS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS suggestion_analytics (
    -- Primary identifiers
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    template_id UUID REFERENCES journal_suggestion_templates(id) ON DELETE CASCADE,
    
    -- Event tracking
    event_type TEXT NOT NULL CHECK (event_type IN (
        'suggested', 'viewed', 'accepted', 'modified', 'dismissed', 'completed'
    )),
    session_id UUID NOT NULL, -- Groups related events together
    
    -- Context when suggestion was made
    trigger_context JSONB DEFAULT '{}', -- What triggered the suggestion
    animal_context JSONB DEFAULT '{}', -- Animal data at time of suggestion
    weather_context JSONB DEFAULT '{}', -- Weather data if available
    location_context JSONB DEFAULT '{}', -- Location data if available
    
    -- Outcome tracking
    suggestion_content TEXT, -- What was actually suggested
    user_modifications TEXT, -- How the user modified it (if any)
    final_content TEXT, -- Final journal entry content
    time_to_completion INTEGER, -- Seconds from suggestion to completion
    quality_score INTEGER, -- AI-assessed quality of final entry
    
    -- User feedback
    user_rating INTEGER CHECK (user_rating >= 1 AND user_rating <= 5),
    user_feedback TEXT,
    
    -- Performance metrics
    response_time_ms INTEGER, -- How long to generate suggestion
    ai_processing_time_ms INTEGER, -- AI service processing time
    cache_hit BOOLEAN DEFAULT FALSE, -- Was suggestion served from cache
    
    -- Privacy compliance (COPPA)
    user_age_group TEXT CHECK (
        user_age_group IN ('under_13', '13_to_17', '18_plus', 'unknown')
    ),
    parent_consent_verified BOOLEAN DEFAULT FALSE,
    content_filtered BOOLEAN DEFAULT FALSE, -- Was content age-filtered
    
    -- Audit trail
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- SECTION 4: SUGGESTION PERFORMANCE METRICS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS suggestion_performance_metrics (
    -- Primary identifiers
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    metric_date DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Aggregated daily metrics
    total_suggestions_generated INTEGER DEFAULT 0,
    total_suggestions_accepted INTEGER DEFAULT 0,
    total_suggestions_modified INTEGER DEFAULT 0,
    total_suggestions_dismissed INTEGER DEFAULT 0,
    
    -- Performance metrics
    average_response_time_ms DECIMAL(10,2) DEFAULT 0,
    cache_hit_rate DECIMAL(5,2) DEFAULT 0, -- Percentage
    success_rate DECIMAL(5,2) DEFAULT 0, -- Acceptance rate
    
    -- Popular templates (top 10 by usage)
    popular_templates JSONB DEFAULT '[]',
    
    -- Age group breakdown (COPPA compliance)
    under_13_suggestions INTEGER DEFAULT 0,
    teen_suggestions INTEGER DEFAULT 0,
    adult_suggestions INTEGER DEFAULT 0,
    
    -- Category breakdown
    category_usage JSONB DEFAULT '{}', -- Category -> usage count
    
    -- Quality metrics
    average_quality_score DECIMAL(3,2) DEFAULT 0,
    high_quality_entries_count INTEGER DEFAULT 0, -- Score >= 8
    
    -- System performance
    n8n_availability_percentage DECIMAL(5,2) DEFAULT 0,
    fallback_suggestions_used INTEGER DEFAULT 0,
    
    -- Audit trail
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure one record per day
    UNIQUE(metric_date)
);

-- ============================================================================
-- SECTION 5: SUGGESTION CACHE TABLE (Performance Optimization)
-- ============================================================================

CREATE TABLE IF NOT EXISTS suggestion_cache (
    -- Primary identifiers
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cache_key TEXT UNIQUE NOT NULL, -- Hash of context parameters
    
    -- Context parameters (for cache invalidation)
    category TEXT NOT NULL,
    species TEXT,
    age_group TEXT NOT NULL,
    competency_level TEXT,
    weather_pattern TEXT, -- General weather type for grouping
    
    -- Cached content
    suggestions_data JSONB NOT NULL, -- Array of suggestion objects
    template_ids UUID[] DEFAULT '{}', -- Template IDs used for this cache
    
    -- Cache metadata
    cache_hits INTEGER DEFAULT 0,
    cache_version INTEGER DEFAULT 1,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Performance tracking
    generation_time_ms INTEGER NOT NULL, -- Time to originally generate
    average_quality_score DECIMAL(3,2) DEFAULT 0,
    usage_success_rate DECIMAL(5,2) DEFAULT 0,
    
    -- Audit trail
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_accessed TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- SECTION 6: PERFORMANCE INDEXES
-- ============================================================================

-- Suggestion templates indexes
CREATE INDEX IF NOT EXISTS idx_suggestion_templates_category ON journal_suggestion_templates(category);
CREATE INDEX IF NOT EXISTS idx_suggestion_templates_species ON journal_suggestion_templates USING GIN(species_filter);
CREATE INDEX IF NOT EXISTS idx_suggestion_templates_age_group ON journal_suggestion_templates USING GIN(age_group);
CREATE INDEX IF NOT EXISTS idx_suggestion_templates_active ON journal_suggestion_templates(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_suggestion_templates_coppa ON journal_suggestion_templates(coppa_compliant) WHERE coppa_compliant = TRUE;
CREATE INDEX IF NOT EXISTS idx_suggestion_templates_usage ON journal_suggestion_templates(usage_count DESC, success_rate DESC);

-- User preferences indexes
CREATE INDEX IF NOT EXISTS idx_user_preferences_user_id ON user_suggestion_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_user_preferences_enabled ON user_suggestion_preferences(enable_suggestions) WHERE enable_suggestions = TRUE;
CREATE INDEX IF NOT EXISTS idx_user_preferences_supervised ON user_suggestion_preferences(parent_supervised);

-- Analytics indexes
CREATE INDEX IF NOT EXISTS idx_suggestion_analytics_user ON suggestion_analytics(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_suggestion_analytics_template ON suggestion_analytics(template_id, event_type);
CREATE INDEX IF NOT EXISTS idx_suggestion_analytics_session ON suggestion_analytics(session_id);
CREATE INDEX IF NOT EXISTS idx_suggestion_analytics_age_group ON suggestion_analytics(user_age_group);
CREATE INDEX IF NOT EXISTS idx_suggestion_analytics_event_time ON suggestion_analytics(event_type, created_at);

-- Performance metrics indexes
CREATE INDEX IF NOT EXISTS idx_suggestion_metrics_date ON suggestion_performance_metrics(metric_date DESC);

-- Cache indexes
CREATE INDEX IF NOT EXISTS idx_suggestion_cache_key ON suggestion_cache(cache_key);
CREATE INDEX IF NOT EXISTS idx_suggestion_cache_context ON suggestion_cache(category, species, age_group);
CREATE INDEX IF NOT EXISTS idx_suggestion_cache_expires ON suggestion_cache(expires_at);
CREATE INDEX IF NOT EXISTS idx_suggestion_cache_accessed ON suggestion_cache(last_accessed) WHERE expires_at > NOW();

-- ============================================================================
-- SECTION 7: ROW LEVEL SECURITY POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE journal_suggestion_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_suggestion_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE suggestion_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE suggestion_performance_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE suggestion_cache ENABLE ROW LEVEL SECURITY;

-- Templates: Public read for active templates, admin write
CREATE POLICY "suggestion_templates_public_read" ON journal_suggestion_templates
    FOR SELECT USING (is_active = TRUE AND coppa_compliant = TRUE);

CREATE POLICY "suggestion_templates_admin_write" ON journal_suggestion_templates
    FOR ALL TO authenticated USING (
        EXISTS (
            SELECT 1 FROM user_profiles up
            WHERE up.id = auth.uid() AND up.type = 'admin'
        )
    );

-- User preferences: Users own their preferences
CREATE POLICY "user_preferences_own_data" ON user_suggestion_preferences
    FOR ALL USING (auth.uid() = user_id);

-- Analytics: Users can view their own analytics, admins can view all
CREATE POLICY "suggestion_analytics_user_own" ON suggestion_analytics
    FOR SELECT USING (
        auth.uid() = user_id
        OR EXISTS (
            SELECT 1 FROM user_profiles up
            WHERE up.id = auth.uid() AND up.type IN ('admin', 'educator')
        )
    );

CREATE POLICY "suggestion_analytics_user_insert" ON suggestion_analytics
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Performance metrics: Admins only
CREATE POLICY "suggestion_metrics_admin_only" ON suggestion_performance_metrics
    FOR ALL TO authenticated USING (
        EXISTS (
            SELECT 1 FROM user_profiles up
            WHERE up.id = auth.uid() AND up.type = 'admin'
        )
    );

-- Cache: Public read for performance
CREATE POLICY "suggestion_cache_public_read" ON suggestion_cache
    FOR SELECT USING (expires_at > NOW());

CREATE POLICY "suggestion_cache_admin_write" ON suggestion_cache
    FOR ALL TO authenticated USING (
        EXISTS (
            SELECT 1 FROM user_profiles up
            WHERE up.id = auth.uid() AND up.type = 'admin'
        )
    );

-- ============================================================================
-- SECTION 8: SUPABASE RPC FUNCTIONS
-- ============================================================================

-- Function to get journal suggestions based on context
CREATE OR REPLACE FUNCTION get_journal_suggestions(
    p_category TEXT,
    p_species TEXT DEFAULT NULL,
    p_user_age INTEGER DEFAULT NULL,
    p_competency_level TEXT DEFAULT 'developing',
    p_weather_condition TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 5
)
RETURNS TABLE (
    template_id VARCHAR(50),
    title_template TEXT,
    content_template TEXT,
    difficulty_level INTEGER,
    estimated_time_minutes INTEGER,
    ffa_standards TEXT[],
    success_rate DECIMAL(5,2),
    is_popular BOOLEAN
) AS $$
DECLARE
    v_age_group TEXT;
    v_cache_key TEXT;
    v_cached_result JSONB;
BEGIN
    -- Determine age group for COPPA compliance
    v_age_group := CASE 
        WHEN p_user_age IS NULL THEN 'unknown'
        WHEN p_user_age < 13 THEN 'under_13'
        WHEN p_user_age <= 17 THEN '13_to_17'
        ELSE '18_plus'
    END;

    -- Create cache key
    v_cache_key := md5(concat(
        p_category, '|', 
        COALESCE(p_species, 'any'), '|',
        v_age_group, '|',
        p_competency_level, '|',
        COALESCE(p_weather_condition, 'any')
    ));

    -- Check cache first
    SELECT suggestions_data INTO v_cached_result
    FROM suggestion_cache 
    WHERE cache_key = v_cache_key 
    AND expires_at > NOW()
    LIMIT 1;

    IF v_cached_result IS NOT NULL THEN
        -- Update cache hit count and last accessed
        UPDATE suggestion_cache 
        SET cache_hits = cache_hits + 1,
            last_accessed = NOW()
        WHERE cache_key = v_cache_key;

        -- Return cached results
        RETURN QUERY
        SELECT 
            (item->>'template_id')::VARCHAR(50),
            item->>'title_template',
            item->>'content_template', 
            (item->>'difficulty_level')::INTEGER,
            (item->>'estimated_time_minutes')::INTEGER,
            ARRAY(SELECT jsonb_array_elements_text(item->'ffa_standards')),
            (item->>'success_rate')::DECIMAL(5,2),
            (item->>'is_popular')::BOOLEAN
        FROM jsonb_array_elements(v_cached_result) AS item
        LIMIT p_limit;
        RETURN;
    END IF;

    -- Generate fresh suggestions if no cache
    RETURN QUERY
    SELECT 
        jst.template_id,
        jst.title_template,
        jst.content_template,
        jst.difficulty_level,
        jst.estimated_time_minutes,
        jst.ffa_standards,
        jst.success_rate,
        (jst.usage_count > 100) as is_popular
    FROM journal_suggestion_templates jst
    WHERE jst.is_active = TRUE
    AND jst.coppa_compliant = TRUE
    AND jst.category = p_category
    AND (
        -- Age group filtering (COPPA compliance)
        jst.age_group IS NULL 
        OR v_age_group = ANY(jst.age_group)
        OR (v_age_group = 'under_13' AND 'elementary' = ANY(jst.age_group))
        OR (v_age_group = '13_to_17' AND ('middle_school' = ANY(jst.age_group) OR 'high_school' = ANY(jst.age_group)))
    )
    AND (
        -- Species filtering
        jst.species_filter IS NULL 
        OR p_species IS NULL 
        OR p_species = ANY(jst.species_filter)
    )
    AND (
        -- Competency filtering
        array_length(jst.competency_level, 1) IS NULL
        OR p_competency_level = ANY(jst.competency_level)
    )
    ORDER BY 
        jst.success_rate DESC,
        jst.usage_count DESC,
        jst.average_rating DESC
    LIMIT p_limit;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to track suggestion usage and feedback
CREATE OR REPLACE FUNCTION track_suggestion_usage(
    p_template_id VARCHAR(50),
    p_accepted BOOLEAN,
    p_user_rating INTEGER DEFAULT NULL,
    p_user_feedback TEXT DEFAULT NULL,
    p_session_id UUID DEFAULT NULL,
    p_completion_time INTEGER DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_user_id UUID;
    v_template_uuid UUID;
    v_session_id UUID;
    v_user_age_group TEXT;
BEGIN
    -- Get current user
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    -- Get template UUID
    SELECT id INTO v_template_uuid
    FROM journal_suggestion_templates
    WHERE template_id = p_template_id;

    IF v_template_uuid IS NULL THEN
        RAISE EXCEPTION 'Template not found: %', p_template_id;
    END IF;

    -- Generate session ID if not provided
    v_session_id := COALESCE(p_session_id, uuid_generate_v4());

    -- Determine user age group from profile
    SELECT CASE 
        WHEN up.birth_date IS NULL THEN 'unknown'
        WHEN DATE_PART('year', AGE(up.birth_date)) < 13 THEN 'under_13'
        WHEN DATE_PART('year', AGE(up.birth_date)) <= 17 THEN '13_to_17'
        ELSE '18_plus'
    END INTO v_user_age_group
    FROM user_profiles up
    WHERE up.id = v_user_id;

    -- Record analytics event
    INSERT INTO suggestion_analytics (
        user_id,
        template_id,
        event_type,
        session_id,
        user_rating,
        user_feedback,
        time_to_completion,
        user_age_group,
        parent_consent_verified
    ) VALUES (
        v_user_id,
        v_template_uuid,
        CASE WHEN p_accepted THEN 'accepted' ELSE 'dismissed' END,
        v_session_id,
        p_user_rating,
        p_user_feedback,
        p_completion_time,
        v_user_age_group,
        COALESCE(
            (SELECT parent_consent FROM user_profiles WHERE id = v_user_id),
            FALSE
        )
    );

    -- Update template usage statistics
    UPDATE journal_suggestion_templates
    SET 
        usage_count = usage_count + 1,
        success_rate = (
            SELECT 
                ROUND(
                    (COUNT(*) FILTER (WHERE event_type = 'accepted')::DECIMAL / 
                     COUNT(*)::DECIMAL) * 100, 
                    2
                )
            FROM suggestion_analytics sa
            WHERE sa.template_id = v_template_uuid
        ),
        average_rating = (
            SELECT ROUND(AVG(user_rating), 2)
            FROM suggestion_analytics sa
            WHERE sa.template_id = v_template_uuid
            AND user_rating IS NOT NULL
        )
    WHERE id = v_template_uuid;

    -- Update user preferences
    UPDATE user_suggestion_preferences
    SET 
        suggestions_used = CASE WHEN p_accepted THEN suggestions_used + 1 ELSE suggestions_used END,
        suggestions_dismissed = CASE WHEN NOT p_accepted THEN suggestions_dismissed + 1 ELSE suggestions_dismissed END,
        updated_at = NOW()
    WHERE user_id = v_user_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get personalized templates for a user
CREATE OR REPLACE FUNCTION get_personalized_templates(p_user_id UUID)
RETURNS TABLE (
    template_id VARCHAR(50),
    title_template TEXT,
    content_template TEXT,
    category TEXT,
    success_rate DECIMAL(5,2),
    user_preference_score DECIMAL(5,2)
) AS $$
DECLARE
    v_user_prefs user_suggestion_preferences%ROWTYPE;
    v_user_age_group TEXT;
BEGIN
    -- Get user preferences
    SELECT * INTO v_user_prefs
    FROM user_suggestion_preferences
    WHERE user_id = p_user_id;

    -- If no preferences exist, create defaults
    IF v_user_prefs IS NULL THEN
        INSERT INTO user_suggestion_preferences (user_id)
        VALUES (p_user_id);
        
        SELECT * INTO v_user_prefs
        FROM user_suggestion_preferences
        WHERE user_id = p_user_id;
    END IF;

    -- Determine user age group from profile
    SELECT CASE 
        WHEN up.birth_date IS NULL THEN 'unknown'
        WHEN DATE_PART('year', AGE(up.birth_date)) < 13 THEN 'under_13'
        WHEN DATE_PART('year', AGE(up.birth_date)) <= 17 THEN '13_to_17'
        ELSE '18_plus'
    END INTO v_user_age_group
    FROM user_profiles up
    WHERE up.id = p_user_id;

    RETURN QUERY
    WITH user_template_stats AS (
        SELECT 
            jst.template_id,
            COUNT(*) FILTER (WHERE sa.event_type = 'accepted') as user_accepted,
            COUNT(*) as user_total_interactions,
            AVG(sa.user_rating) as user_avg_rating
        FROM journal_suggestion_templates jst
        LEFT JOIN suggestion_analytics sa ON sa.template_id = jst.id AND sa.user_id = p_user_id
        WHERE jst.is_active = TRUE
        AND jst.coppa_compliant = TRUE
        GROUP BY jst.template_id
    )
    SELECT 
        jst.template_id,
        jst.title_template,
        jst.content_template,
        jst.category,
        jst.success_rate,
        -- Calculate user preference score
        COALESCE(
            (uts.user_accepted::DECIMAL / NULLIF(uts.user_total_interactions, 0) * 50) + -- 50% weight for user acceptance
            (COALESCE(uts.user_avg_rating, 3) * 10) + -- 40% weight for user rating (scale 1-5 to 10-50)
            (jst.success_rate * 0.5), -- 10% weight for global success rate  
            jst.success_rate * 0.5 + 30 -- Default score for new templates
        ) as user_preference_score
    FROM journal_suggestion_templates jst
    LEFT JOIN user_template_stats uts ON uts.template_id = jst.template_id
    WHERE jst.is_active = TRUE
    AND jst.coppa_compliant = TRUE
    AND (
        -- Age group filtering (COPPA compliance)
        jst.age_group IS NULL 
        OR v_user_age_group = ANY(jst.age_group)
        OR (v_user_age_group = 'under_13' AND 'elementary' = ANY(jst.age_group))
    )
    AND (
        -- Category preferences
        array_length(v_user_prefs.preferred_categories, 1) IS NULL
        OR jst.category = ANY(v_user_prefs.preferred_categories)
    )
    AND (
        -- Blocked categories
        array_length(v_user_prefs.blocked_categories, 1) IS NULL
        OR NOT (jst.category = ANY(v_user_prefs.blocked_categories))
    )
    AND (
        -- Blocked templates
        array_length(v_user_prefs.blocked_templates, 1) IS NULL
        OR NOT (jst.template_id = ANY(v_user_prefs.blocked_templates))
    )
    ORDER BY user_preference_score DESC, jst.success_rate DESC
    LIMIT 20;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- SECTION 9: CACHE MANAGEMENT FUNCTIONS
-- ============================================================================

-- Function to invalidate expired cache entries
CREATE OR REPLACE FUNCTION cleanup_suggestion_cache()
RETURNS INTEGER AS $$
DECLARE
    v_deleted_count INTEGER;
BEGIN
    DELETE FROM suggestion_cache 
    WHERE expires_at <= NOW() 
    OR last_accessed < NOW() - INTERVAL '7 days';
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update daily performance metrics
CREATE OR REPLACE FUNCTION update_daily_suggestion_metrics(p_target_date DATE DEFAULT CURRENT_DATE)
RETURNS VOID AS $$
DECLARE
    v_metrics suggestion_performance_metrics%ROWTYPE;
BEGIN
    -- Calculate daily metrics from analytics
    SELECT 
        p_target_date,
        COUNT(*) FILTER (WHERE event_type = 'suggested'),
        COUNT(*) FILTER (WHERE event_type = 'accepted'),
        COUNT(*) FILTER (WHERE event_type = 'modified'),
        COUNT(*) FILTER (WHERE event_type = 'dismissed'),
        ROUND(AVG(response_time_ms), 2),
        ROUND((COUNT(*) FILTER (WHERE cache_hit = TRUE)::DECIMAL / COUNT(*)) * 100, 2),
        ROUND((COUNT(*) FILTER (WHERE event_type = 'accepted')::DECIMAL / 
               COUNT(*) FILTER (WHERE event_type = 'suggested')) * 100, 2),
        COUNT(*) FILTER (WHERE user_age_group = 'under_13'),
        COUNT(*) FILTER (WHERE user_age_group = '13_to_17'),
        COUNT(*) FILTER (WHERE user_age_group = '18_plus'),
        ROUND(AVG(quality_score), 2),
        COUNT(*) FILTER (WHERE quality_score >= 8)
    INTO 
        v_metrics.metric_date,
        v_metrics.total_suggestions_generated,
        v_metrics.total_suggestions_accepted,
        v_metrics.total_suggestions_modified,
        v_metrics.total_suggestions_dismissed,
        v_metrics.average_response_time_ms,
        v_metrics.cache_hit_rate,
        v_metrics.success_rate,
        v_metrics.under_13_suggestions,
        v_metrics.teen_suggestions,
        v_metrics.adult_suggestions,
        v_metrics.average_quality_score,
        v_metrics.high_quality_entries_count
    FROM suggestion_analytics
    WHERE DATE(created_at) = p_target_date;

    -- Insert or update metrics
    INSERT INTO suggestion_performance_metrics (
        metric_date,
        total_suggestions_generated,
        total_suggestions_accepted,
        total_suggestions_modified,
        total_suggestions_dismissed,
        average_response_time_ms,
        cache_hit_rate,
        success_rate,
        under_13_suggestions,
        teen_suggestions,
        adult_suggestions,
        average_quality_score,
        high_quality_entries_count
    ) VALUES (
        v_metrics.metric_date,
        v_metrics.total_suggestions_generated,
        v_metrics.total_suggestions_accepted,
        v_metrics.total_suggestions_modified,
        v_metrics.total_suggestions_dismissed,
        v_metrics.average_response_time_ms,
        v_metrics.cache_hit_rate,
        v_metrics.success_rate,
        v_metrics.under_13_suggestions,
        v_metrics.teen_suggestions,
        v_metrics.adult_suggestions,
        v_metrics.average_quality_score,
        v_metrics.high_quality_entries_count
    )
    ON CONFLICT (metric_date) DO UPDATE SET
        total_suggestions_generated = EXCLUDED.total_suggestions_generated,
        total_suggestions_accepted = EXCLUDED.total_suggestions_accepted,
        total_suggestions_modified = EXCLUDED.total_suggestions_modified,
        total_suggestions_dismissed = EXCLUDED.total_suggestions_dismissed,
        average_response_time_ms = EXCLUDED.average_response_time_ms,
        cache_hit_rate = EXCLUDED.cache_hit_rate,
        success_rate = EXCLUDED.success_rate,
        under_13_suggestions = EXCLUDED.under_13_suggestions,
        teen_suggestions = EXCLUDED.teen_suggestions,
        adult_suggestions = EXCLUDED.adult_suggestions,
        average_quality_score = EXCLUDED.average_quality_score,
        high_quality_entries_count = EXCLUDED.high_quality_entries_count;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- SECTION 10: AUTOMATED TRIGGERS
-- ============================================================================

-- Trigger to update user preference timestamps
CREATE OR REPLACE FUNCTION update_user_preferences_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_user_suggestion_preferences_timestamp ON user_suggestion_preferences;
CREATE TRIGGER update_user_suggestion_preferences_timestamp
    BEFORE UPDATE ON user_suggestion_preferences
    FOR EACH ROW EXECUTE FUNCTION update_user_preferences_timestamp();

-- Trigger to update template timestamps and recalculate metrics
CREATE OR REPLACE FUNCTION update_template_metrics()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    
    -- Recalculate average rating when usage increases
    IF NEW.usage_count > OLD.usage_count THEN
        NEW.average_rating = (
            SELECT ROUND(AVG(user_rating), 2)
            FROM suggestion_analytics sa
            JOIN journal_suggestion_templates jst ON jst.id = sa.template_id
            WHERE jst.template_id = NEW.template_id
            AND user_rating IS NOT NULL
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_suggestion_templates_metrics ON journal_suggestion_templates;
CREATE TRIGGER update_suggestion_templates_metrics
    BEFORE UPDATE ON journal_suggestion_templates
    FOR EACH ROW EXECUTE FUNCTION update_template_metrics();

-- ============================================================================
-- SECTION 11: SEED DATA - COPPA COMPLIANT TEMPLATES
-- ============================================================================

-- Insert age-appropriate journal suggestion templates
INSERT INTO journal_suggestion_templates (
    template_id, title_template, content_template, category, 
    species_filter, age_group, competency_level, ffa_standards,
    difficulty_level, estimated_time_minutes, coppa_compliant
) VALUES 
-- Daily Care Templates (Age-appropriate)
(
    'daily_care_pig_001',
    'Daily Care for {{animal_name}}',
    'Today I checked on {{animal_name}}. The weather was {{weather_condition}}. I observed: [Describe what you noticed about your pig''s health, behavior, and environment]. I fed {{animal_name}} [amount] of [feed type]. The water was [clean/needed refilling]. Next time I will: [What will you do differently?]',
    'daily_care',
    ARRAY['pig'],
    ARRAY['elementary', 'middle_school', 'high_school'],
    ARRAY['novice', 'developing'],
    ARRAY['AS.01.01', 'AS.02.01'],
    1,
    10,
    true
),
(
    'daily_care_goat_001', 
    'Daily Goat Care - {{animal_name}}',
    'I spent time with {{animal_name}} today. Weather: {{weather_condition}}. My goat seemed [happy/calm/active]. I checked: □ Feed and water □ Hooves □ Eyes and nose □ General health. Today my goat ate [describe feed]. I learned: [What did you discover?] Tomorrow I will: [Your plan]',
    'daily_care',
    ARRAY['goat'],
    ARRAY['elementary', 'middle_school', 'high_school'],
    ARRAY['novice', 'developing'],
    ARRAY['AS.01.01', 'AS.03.01'],
    1,
    10,
    true
),

-- Health Check Templates (Age-appropriate)
(
    'health_check_general_001',
    'Health Check - {{animal_name}}',
    'Health check for {{animal_name}} on {{date}}. Temperature: {{temperature}}°F. What I observed: Eyes: [clear/discharge] Nose: [clean/runny] Appetite: [good/poor/normal] Energy level: [active/tired/normal] Any concerns: [describe any issues]. Action needed: [what will you do about any problems?]',
    'health_check', 
    ARRAY['pig', 'goat', 'cattle', 'sheep'],
    ARRAY['middle_school', 'high_school'],
    ARRAY['developing', 'proficient'],
    ARRAY['AS.07.01', 'AS.07.02'],
    2,
    15,
    true
),

-- Learning Reflection Templates (Educational focus)
(
    'reflection_learning_001',
    'What I Learned About {{activity_type}}',
    'Today I learned about {{activity_type}}. The most interesting thing was: [describe what caught your attention]. This relates to my FFA goals because: [connect to your bigger picture]. I was surprised by: [what was unexpected?]. I want to learn more about: [what questions do you have?]. This will help me in my SAE because: [practical application]',
    'learning_reflection',
    NULL, -- All species
    ARRAY['elementary', 'middle_school', 'high_school'],
    ARRAY['novice', 'developing', 'proficient'],
    ARRAY['CC.01.01', 'CC.02.01'],
    2,
    20,
    true
),

-- Project Planning Templates (Goal-oriented)
(
    'project_plan_sae_001',
    'My SAE Project Planning',
    'I am planning my {{sae_type}} SAE project. My main goal is: [what do you want to achieve?]. Resources I need: [list what you''ll need]. Timeline: Week 1: [first steps] Week 2-4: [middle phase] Final weeks: [completion]. Challenges I might face: [what could go wrong?]. How I''ll measure success: [your success criteria]',
    'project_planning',
    NULL,
    ARRAY['middle_school', 'high_school'],
    ARRAY['developing', 'proficient'],
    ARRAY['CC.03.01', 'CC.04.01'],
    3,
    25,
    true
),

-- Competition Templates (Achievement focused)
(
    'competition_prep_001',
    'Show Preparation for {{animal_name}}',
    'Preparing {{animal_name}} for {{competition_name}}. Training focus today: [what did you work on?]. {{animal_name}} is improving at: [specific progress]. Still needs work on: [areas to improve]. Training plan for next week: [your strategy]. Goal for competition: [what do you hope to achieve?]',
    'competition',
    ARRAY['pig', 'goat', 'cattle', 'sheep'],
    ARRAY['middle_school', 'high_school'],
    ARRAY['developing', 'proficient', 'advanced'],
    ARRAY['AS.05.01', 'AS.06.01'],
    3,
    20,
    true
)

ON CONFLICT (template_id) DO NOTHING;

-- ============================================================================
-- SECTION 12: AUTOMATED MAINTENANCE
-- ============================================================================

-- Schedule daily cache cleanup (requires pg_cron extension)
-- SELECT cron.schedule('cleanup-suggestion-cache', '0 2 * * *', 'SELECT cleanup_suggestion_cache();');

-- Schedule daily metrics update
-- SELECT cron.schedule('update-suggestion-metrics', '0 1 * * *', 'SELECT update_daily_suggestion_metrics();');

-- ============================================================================
-- SECTION 13: GRANT PERMISSIONS
-- ============================================================================

-- Grant permissions to authenticated users
GRANT SELECT, INSERT, UPDATE ON journal_suggestion_templates TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON user_suggestion_preferences TO authenticated;
GRANT SELECT, INSERT ON suggestion_analytics TO authenticated;
GRANT SELECT ON suggestion_performance_metrics TO authenticated;
GRANT SELECT ON suggestion_cache TO authenticated;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION get_journal_suggestions TO authenticated;
GRANT EXECUTE ON FUNCTION track_suggestion_usage TO authenticated;
GRANT EXECUTE ON FUNCTION get_personalized_templates TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_suggestion_cache TO authenticated;
GRANT EXECUTE ON FUNCTION update_daily_suggestion_metrics TO authenticated;

-- ============================================================================
-- SECTION 14: VIEWS FOR EASY QUERYING
-- ============================================================================

-- View for suggestion analytics dashboard
CREATE OR REPLACE VIEW suggestion_analytics_dashboard AS
SELECT 
    DATE(sa.created_at) as analytics_date,
    sa.user_age_group,
    jst.category,
    COUNT(*) as total_events,
    COUNT(*) FILTER (WHERE sa.event_type = 'accepted') as accepted_count,
    COUNT(*) FILTER (WHERE sa.event_type = 'dismissed') as dismissed_count,
    ROUND(AVG(sa.response_time_ms), 2) as avg_response_time,
    ROUND(AVG(sa.quality_score), 2) as avg_quality_score,
    COUNT(DISTINCT sa.user_id) as unique_users
FROM suggestion_analytics sa
JOIN journal_suggestion_templates jst ON jst.id = sa.template_id
WHERE sa.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(sa.created_at), sa.user_age_group, jst.category
ORDER BY analytics_date DESC, accepted_count DESC;

-- View for top performing templates
CREATE OR REPLACE VIEW top_suggestion_templates AS
SELECT 
    jst.template_id,
    jst.title_template,
    jst.category,
    jst.usage_count,
    jst.success_rate,
    jst.average_rating,
    COUNT(DISTINCT sa.user_id) as unique_users_served,
    ROUND(AVG(sa.quality_score), 2) as avg_resulting_quality
FROM journal_suggestion_templates jst
LEFT JOIN suggestion_analytics sa ON sa.template_id = jst.id
WHERE jst.is_active = TRUE
GROUP BY jst.id, jst.template_id, jst.title_template, jst.category, 
         jst.usage_count, jst.success_rate, jst.average_rating
ORDER BY jst.success_rate DESC, jst.usage_count DESC
LIMIT 50;

COMMIT;

-- ============================================================================
-- POST-MIGRATION VERIFICATION
-- ============================================================================

-- Verify tables created
SELECT 'Tables created successfully' as status,
       COUNT(*) as table_count
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name LIKE '%suggestion%';

-- Verify templates inserted
SELECT 'Templates inserted successfully' as status,
       COUNT(*) as template_count
FROM journal_suggestion_templates 
WHERE coppa_compliant = TRUE;

-- Verify RLS policies
SELECT 'RLS policies created successfully' as status,
       COUNT(*) as policy_count
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename LIKE '%suggestion%';

-- Verify functions
SELECT 'Functions created successfully' as status,
       COUNT(*) as function_count
FROM information_schema.routines
WHERE routine_schema = 'public' 
AND routine_name LIKE '%suggestion%';