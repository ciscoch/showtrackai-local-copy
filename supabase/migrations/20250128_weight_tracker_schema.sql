-- =====================================================================
-- Weight Tracker Database Schema Migration
-- =====================================================================
-- Description: Comprehensive schema for livestock weight tracking with
-- support for ADG calculations, goals, audit trails, and performance optimization
-- Author: ShowTrackAI Database Team
-- Date: 2025-01-28
-- =====================================================================

-- =====================================================================
-- 1. ENUM TYPES
-- =====================================================================

-- Weight measurement units
CREATE TYPE weight_unit AS ENUM ('lb', 'kg');

-- Weight entry status
CREATE TYPE weight_status AS ENUM ('active', 'deleted', 'flagged', 'adjusted');

-- Weight measurement method
CREATE TYPE measurement_method AS ENUM (
    'digital_scale',
    'mechanical_scale', 
    'tape_measure',
    'visual_estimate',
    'veterinary',
    'show_official'
);

-- Goal status
CREATE TYPE goal_status AS ENUM ('active', 'achieved', 'missed', 'cancelled', 'paused');

-- =====================================================================
-- 2. MAIN WEIGHTS TABLE
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.weights (
    -- Primary identification
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Foreign key relationships
    animal_id UUID NOT NULL REFERENCES public.animals(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    recorded_by UUID NOT NULL REFERENCES auth.users(id),
    
    -- Core weight data
    weight_value DECIMAL(10,2) NOT NULL CHECK (weight_value > 0 AND weight_value < 10000),
    weight_unit weight_unit NOT NULL DEFAULT 'lb',
    
    -- Measurement context
    measurement_date DATE NOT NULL,
    measurement_time TIME,
    measurement_method measurement_method NOT NULL DEFAULT 'digital_scale',
    
    -- Environmental factors
    feed_status VARCHAR(50) CHECK (feed_status IN ('fasted', 'fed', 'unknown')),
    water_status VARCHAR(50) CHECK (water_status IN ('watered', 'restricted', 'unknown')),
    time_since_feeding INTEGER, -- minutes
    
    -- Quality indicators
    confidence_level INTEGER CHECK (confidence_level BETWEEN 1 AND 10),
    is_verified BOOLEAN DEFAULT FALSE,
    verified_by UUID REFERENCES auth.users(id),
    verified_at TIMESTAMPTZ,
    
    -- Show/competition context
    is_show_weight BOOLEAN DEFAULT FALSE,
    show_name VARCHAR(255),
    show_class VARCHAR(100),
    
    -- Notes and metadata
    notes TEXT,
    weather_conditions JSONB, -- {temperature: 75, humidity: 60, conditions: 'sunny'}
    health_status VARCHAR(50),
    medication_notes TEXT,
    
    -- Calculated fields (denormalized for performance)
    days_since_last_weight INTEGER,
    weight_change DECIMAL(10,2),
    adg DECIMAL(5,3), -- Average Daily Gain
    
    -- Status and audit
    status weight_status NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Data quality
    is_outlier BOOLEAN DEFAULT FALSE,
    outlier_reason TEXT,
    
    -- Constraints
    CONSTRAINT unique_animal_date_time UNIQUE(animal_id, measurement_date, measurement_time),
    CONSTRAINT valid_weight_range CHECK (
        (weight_unit = 'lb' AND weight_value BETWEEN 1 AND 5000) OR
        (weight_unit = 'kg' AND weight_value BETWEEN 0.5 AND 2500)
    )
);

-- =====================================================================
-- 3. WEIGHT GOALS TABLE
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.weight_goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Relationships
    animal_id UUID NOT NULL REFERENCES public.animals(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Goal parameters
    goal_name VARCHAR(255) NOT NULL,
    target_weight DECIMAL(10,2) NOT NULL CHECK (target_weight > 0),
    weight_unit weight_unit NOT NULL DEFAULT 'lb',
    target_date DATE NOT NULL,
    
    -- Starting point
    starting_weight DECIMAL(10,2) NOT NULL,
    starting_date DATE NOT NULL,
    
    -- Target metrics
    target_adg DECIMAL(5,3), -- Target Average Daily Gain
    min_adg DECIMAL(5,3),
    max_adg DECIMAL(5,3),
    
    -- Progress tracking
    current_weight DECIMAL(10,2),
    last_weight_date DATE,
    progress_percentage DECIMAL(5,2),
    projected_weight DECIMAL(10,2),
    projected_date DATE,
    days_remaining INTEGER GENERATED ALWAYS AS (target_date - CURRENT_DATE) STORED,
    
    -- Show/competition goals
    show_name VARCHAR(255),
    show_date DATE,
    weight_class_min DECIMAL(10,2),
    weight_class_max DECIMAL(10,2),
    
    -- Status and metadata
    status goal_status NOT NULL DEFAULT 'active',
    achieved_date DATE,
    achievement_notes TEXT,
    
    -- Alerts and notifications
    alert_enabled BOOLEAN DEFAULT TRUE,
    alert_threshold_days INTEGER DEFAULT 7,
    last_alert_sent TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT valid_goal_dates CHECK (target_date > starting_date),
    CONSTRAINT valid_weight_range CHECK (target_weight != starting_weight)
);

-- =====================================================================
-- 4. WEIGHT AUDIT LOG TABLE
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.weight_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Reference to original weight entry
    weight_id UUID REFERENCES public.weights(id) ON DELETE SET NULL,
    animal_id UUID NOT NULL,
    user_id UUID NOT NULL,
    
    -- Audit information
    action VARCHAR(50) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE', 'RESTORE')),
    performed_by UUID NOT NULL REFERENCES auth.users(id),
    performed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Changed data
    old_values JSONB,
    new_values JSONB,
    change_reason TEXT,
    
    -- Context
    ip_address INET,
    user_agent TEXT,
    session_id UUID,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================================
-- 5. WEIGHT STATISTICS CACHE TABLE (for performance)
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.weight_statistics_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    animal_id UUID NOT NULL REFERENCES public.animals(id) ON DELETE CASCADE,
    
    -- Basic statistics
    total_weights INTEGER NOT NULL DEFAULT 0,
    first_weight_date DATE,
    last_weight_date DATE,
    
    -- Current metrics
    current_weight DECIMAL(10,2),
    starting_weight DECIMAL(10,2),
    highest_weight DECIMAL(10,2),
    lowest_weight DECIMAL(10,2),
    
    -- Performance metrics
    average_adg DECIMAL(5,3),
    best_adg_period DECIMAL(5,3),
    worst_adg_period DECIMAL(5,3),
    current_week_adg DECIMAL(5,3),
    current_month_adg DECIMAL(5,3),
    
    -- Trend analysis
    weight_trend VARCHAR(20), -- 'increasing', 'decreasing', 'stable'
    trend_strength DECIMAL(5,2), -- percentage
    
    -- Goal metrics
    active_goals_count INTEGER DEFAULT 0,
    achieved_goals_count INTEGER DEFAULT 0,
    
    -- Update tracking
    last_calculated TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    needs_recalculation BOOLEAN DEFAULT FALSE,
    
    CONSTRAINT unique_animal_stats UNIQUE(animal_id)
);

-- =====================================================================
-- 6. INDEXES FOR PERFORMANCE
-- =====================================================================

-- Primary query patterns
CREATE INDEX idx_weights_animal_date ON public.weights(animal_id, measurement_date DESC);
CREATE INDEX idx_weights_user_date ON public.weights(user_id, measurement_date DESC);
CREATE INDEX idx_weights_status ON public.weights(status) WHERE status = 'active';
CREATE INDEX idx_weights_show ON public.weights(is_show_weight) WHERE is_show_weight = TRUE;

-- Date-based queries
CREATE INDEX idx_weights_measurement_date ON public.weights(measurement_date DESC);
CREATE INDEX idx_weights_created_at ON public.weights(created_at DESC);

-- Goals indexes
CREATE INDEX idx_goals_animal ON public.weight_goals(animal_id);
CREATE INDEX idx_goals_status ON public.weight_goals(status) WHERE status = 'active';
CREATE INDEX idx_goals_target_date ON public.weight_goals(target_date);

-- Audit log indexes
CREATE INDEX idx_audit_weight_id ON public.weight_audit_log(weight_id);
CREATE INDEX idx_audit_animal_id ON public.weight_audit_log(animal_id);
CREATE INDEX idx_audit_performed_at ON public.weight_audit_log(performed_at DESC);

-- Statistics cache index
CREATE INDEX idx_stats_needs_recalc ON public.weight_statistics_cache(needs_recalculation) 
    WHERE needs_recalculation = TRUE;

-- =====================================================================
-- 7. VIEWS FOR COMMON QUERIES
-- =====================================================================

-- Latest weight for each animal
CREATE OR REPLACE VIEW public.v_latest_weights AS
SELECT DISTINCT ON (w.animal_id)
    w.id,
    w.animal_id,
    w.user_id,
    w.weight_value,
    w.weight_unit,
    w.measurement_date,
    w.measurement_time,
    w.adg,
    w.days_since_last_weight,
    w.weight_change,
    w.notes,
    a.name as animal_name,
    a.tag as animal_tag,
    a.species,
    a.breed
FROM public.weights w
JOIN public.animals a ON a.id = w.animal_id
WHERE w.status = 'active'
ORDER BY w.animal_id, w.measurement_date DESC, w.measurement_time DESC NULLS LAST;

-- ADG calculations view
CREATE OR REPLACE VIEW public.v_adg_calculations AS
WITH weight_pairs AS (
    SELECT 
        w1.animal_id,
        w1.weight_value as current_weight,
        w1.measurement_date as current_date,
        w2.weight_value as previous_weight,
        w2.measurement_date as previous_date,
        w1.weight_unit,
        (w1.weight_value - w2.weight_value) as weight_gain,
        (w1.measurement_date - w2.measurement_date) as days_between,
        CASE 
            WHEN (w1.measurement_date - w2.measurement_date) > 0 
            THEN ROUND((w1.weight_value - w2.weight_value)::DECIMAL / (w1.measurement_date - w2.measurement_date), 3)
            ELSE 0
        END as calculated_adg
    FROM public.weights w1
    JOIN LATERAL (
        SELECT weight_value, measurement_date
        FROM public.weights w2
        WHERE w2.animal_id = w1.animal_id
        AND w2.measurement_date < w1.measurement_date
        AND w2.status = 'active'
        ORDER BY w2.measurement_date DESC
        LIMIT 1
    ) w2 ON true
    WHERE w1.status = 'active'
)
SELECT 
    wp.*,
    a.name as animal_name,
    a.species,
    a.breed
FROM weight_pairs wp
JOIN public.animals a ON a.id = wp.animal_id;

-- Weight history with calculations
CREATE OR REPLACE VIEW public.v_weight_history AS
SELECT 
    w.*,
    a.name as animal_name,
    a.tag as animal_tag,
    a.species,
    a.breed,
    LAG(w.weight_value) OVER (PARTITION BY w.animal_id ORDER BY w.measurement_date, w.measurement_time) as previous_weight,
    LAG(w.measurement_date) OVER (PARTITION BY w.animal_id ORDER BY w.measurement_date, w.measurement_time) as previous_date,
    LEAD(w.weight_value) OVER (PARTITION BY w.animal_id ORDER BY w.measurement_date, w.measurement_time) as next_weight,
    LEAD(w.measurement_date) OVER (PARTITION BY w.animal_id ORDER BY w.measurement_date, w.measurement_time) as next_date
FROM public.weights w
JOIN public.animals a ON a.id = w.animal_id
WHERE w.status = 'active'
ORDER BY w.animal_id, w.measurement_date DESC, w.measurement_time DESC;

-- Active goals with progress
CREATE OR REPLACE VIEW public.v_active_weight_goals AS
SELECT 
    wg.*,
    a.name as animal_name,
    a.species,
    a.breed,
    lw.weight_value as latest_weight,
    lw.measurement_date as latest_weight_date,
    ROUND(
        CASE 
            WHEN wg.target_weight > wg.starting_weight 
            THEN ((lw.weight_value - wg.starting_weight) / (wg.target_weight - wg.starting_weight) * 100)
            WHEN wg.target_weight < wg.starting_weight
            THEN ((wg.starting_weight - lw.weight_value) / (wg.starting_weight - wg.target_weight) * 100)
            ELSE 0
        END, 2
    ) as calculated_progress,
    CASE 
        WHEN wg.target_date < CURRENT_DATE THEN 'overdue'
        WHEN wg.days_remaining <= 7 THEN 'urgent'
        WHEN wg.days_remaining <= 30 THEN 'approaching'
        ELSE 'on_track'
    END as urgency_status
FROM public.weight_goals wg
JOIN public.animals a ON a.id = wg.animal_id
LEFT JOIN public.v_latest_weights lw ON lw.animal_id = wg.animal_id
WHERE wg.status = 'active';

-- =====================================================================
-- 8. ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================================

-- Enable RLS on all tables
ALTER TABLE public.weights ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weight_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weight_audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weight_statistics_cache ENABLE ROW LEVEL SECURITY;

-- Weights table policies
CREATE POLICY "Users can view their own weight records" ON public.weights
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own weight records" ON public.weights
    FOR INSERT WITH CHECK (auth.uid() = user_id AND auth.uid() = recorded_by);

CREATE POLICY "Users can update their own weight records" ON public.weights
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own weight records" ON public.weights
    FOR DELETE USING (auth.uid() = user_id);

-- Weight goals policies
CREATE POLICY "Users can view their own weight goals" ON public.weight_goals
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own weight goals" ON public.weight_goals
    FOR ALL USING (auth.uid() = user_id);

-- Audit log policies
CREATE POLICY "Users can view audit logs for their animals" ON public.weight_audit_log
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "System can insert audit logs" ON public.weight_audit_log
    FOR INSERT WITH CHECK (true);

-- Statistics cache policies
CREATE POLICY "Users can view their own statistics" ON public.weight_statistics_cache
    FOR SELECT USING (
        animal_id IN (SELECT id FROM public.animals WHERE user_id = auth.uid())
    );

CREATE POLICY "System can manage statistics cache" ON public.weight_statistics_cache
    FOR ALL USING (true);

-- =====================================================================
-- 9. FUNCTIONS FOR CALCULATIONS AND TRIGGERS
-- =====================================================================

-- Function to calculate ADG and weight changes
CREATE OR REPLACE FUNCTION calculate_weight_metrics()
RETURNS TRIGGER AS $$
DECLARE
    v_previous_weight RECORD;
    v_days_between INTEGER;
    v_weight_change DECIMAL(10,2);
    v_adg DECIMAL(5,3);
BEGIN
    -- Get the previous weight entry for this animal
    SELECT weight_value, measurement_date 
    INTO v_previous_weight
    FROM public.weights 
    WHERE animal_id = NEW.animal_id 
        AND status = 'active'
        AND (measurement_date < NEW.measurement_date 
            OR (measurement_date = NEW.measurement_date 
                AND measurement_time < NEW.measurement_time))
    ORDER BY measurement_date DESC, measurement_time DESC NULLS LAST
    LIMIT 1;
    
    IF v_previous_weight IS NOT NULL THEN
        -- Calculate days between weights
        v_days_between := NEW.measurement_date - v_previous_weight.measurement_date;
        NEW.days_since_last_weight := v_days_between;
        
        -- Calculate weight change
        v_weight_change := NEW.weight_value - v_previous_weight.weight_value;
        NEW.weight_change := v_weight_change;
        
        -- Calculate ADG (Average Daily Gain)
        IF v_days_between > 0 THEN
            v_adg := ROUND((v_weight_change / v_days_between)::DECIMAL, 3);
            NEW.adg := v_adg;
        END IF;
    ELSE
        -- This is the first weight entry
        NEW.days_since_last_weight := NULL;
        NEW.weight_change := NULL;
        NEW.adg := NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to calculate metrics before insert or update
CREATE TRIGGER trg_calculate_weight_metrics
    BEFORE INSERT OR UPDATE OF weight_value, measurement_date, measurement_time
    ON public.weights
    FOR EACH ROW
    EXECUTE FUNCTION calculate_weight_metrics();

-- Function to update weight goals progress
CREATE OR REPLACE FUNCTION update_weight_goal_progress()
RETURNS TRIGGER AS $$
BEGIN
    -- Update all active goals for this animal
    UPDATE public.weight_goals
    SET 
        current_weight = NEW.weight_value,
        last_weight_date = NEW.measurement_date,
        progress_percentage = CASE 
            WHEN target_weight > starting_weight 
            THEN ROUND(((NEW.weight_value - starting_weight) / (target_weight - starting_weight) * 100)::DECIMAL, 2)
            WHEN target_weight < starting_weight
            THEN ROUND(((starting_weight - NEW.weight_value) / (starting_weight - target_weight) * 100)::DECIMAL, 2)
            ELSE 0
        END,
        projected_weight = CASE 
            WHEN NEW.adg IS NOT NULL AND days_remaining > 0
            THEN ROUND((NEW.weight_value + (NEW.adg * days_remaining))::DECIMAL, 2)
            ELSE NEW.weight_value
        END,
        projected_date = CASE
            WHEN NEW.adg IS NOT NULL AND NEW.adg != 0
            THEN CURRENT_DATE + ROUND(((target_weight - NEW.weight_value) / NEW.adg)::INTEGER)
            ELSE target_date
        END,
        updated_at = NOW()
    WHERE animal_id = NEW.animal_id 
        AND status = 'active';
    
    -- Check if any goals have been achieved
    UPDATE public.weight_goals
    SET 
        status = 'achieved',
        achieved_date = NEW.measurement_date,
        achievement_notes = 'Target weight reached on ' || NEW.measurement_date
    WHERE animal_id = NEW.animal_id 
        AND status = 'active'
        AND (
            (target_weight >= starting_weight AND NEW.weight_value >= target_weight) OR
            (target_weight < starting_weight AND NEW.weight_value <= target_weight)
        );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update goals when new weight is added
CREATE TRIGGER trg_update_weight_goals
    AFTER INSERT ON public.weights
    FOR EACH ROW
    WHEN (NEW.status = 'active')
    EXECUTE FUNCTION update_weight_goal_progress();

-- Function to log weight changes for audit
CREATE OR REPLACE FUNCTION log_weight_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.weight_audit_log (
            weight_id, animal_id, user_id, action, 
            performed_by, new_values
        ) VALUES (
            NEW.id, NEW.animal_id, NEW.user_id, 'INSERT',
            NEW.recorded_by, to_jsonb(NEW)
        );
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO public.weight_audit_log (
            weight_id, animal_id, user_id, action,
            performed_by, old_values, new_values
        ) VALUES (
            NEW.id, NEW.animal_id, NEW.user_id, 'UPDATE',
            NEW.recorded_by, to_jsonb(OLD), to_jsonb(NEW)
        );
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO public.weight_audit_log (
            weight_id, animal_id, user_id, action,
            performed_by, old_values
        ) VALUES (
            OLD.id, OLD.animal_id, OLD.user_id, 'DELETE',
            auth.uid(), to_jsonb(OLD)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for audit logging
CREATE TRIGGER trg_log_weight_changes
    AFTER INSERT OR UPDATE OR DELETE ON public.weights
    FOR EACH ROW
    EXECUTE FUNCTION log_weight_changes();

-- Function to update statistics cache
CREATE OR REPLACE FUNCTION update_weight_statistics()
RETURNS TRIGGER AS $$
BEGIN
    -- Mark statistics as needing recalculation
    INSERT INTO public.weight_statistics_cache (animal_id, needs_recalculation)
    VALUES (NEW.animal_id, TRUE)
    ON CONFLICT (animal_id) 
    DO UPDATE SET needs_recalculation = TRUE;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to mark statistics for update
CREATE TRIGGER trg_update_statistics_flag
    AFTER INSERT OR UPDATE OR DELETE ON public.weights
    FOR EACH ROW
    EXECUTE FUNCTION update_weight_statistics();

-- Function to recalculate statistics (to be called periodically)
CREATE OR REPLACE FUNCTION recalculate_weight_statistics(p_animal_id UUID)
RETURNS VOID AS $$
DECLARE
    v_stats RECORD;
BEGIN
    -- Calculate all statistics for the animal
    WITH weight_data AS (
        SELECT 
            COUNT(*) as total_weights,
            MIN(measurement_date) as first_date,
            MAX(measurement_date) as last_date,
            MIN(weight_value) as min_weight,
            MAX(weight_value) as max_weight,
            AVG(adg) FILTER (WHERE adg IS NOT NULL) as avg_adg,
            MAX(adg) FILTER (WHERE adg IS NOT NULL) as max_adg,
            MIN(adg) FILTER (WHERE adg IS NOT NULL) as min_adg
        FROM public.weights
        WHERE animal_id = p_animal_id AND status = 'active'
    ),
    latest_weight AS (
        SELECT weight_value, adg
        FROM public.weights
        WHERE animal_id = p_animal_id AND status = 'active'
        ORDER BY measurement_date DESC, measurement_time DESC NULLS LAST
        LIMIT 1
    ),
    first_weight AS (
        SELECT weight_value
        FROM public.weights
        WHERE animal_id = p_animal_id AND status = 'active'
        ORDER BY measurement_date ASC, measurement_time ASC NULLS LAST
        LIMIT 1
    ),
    recent_adg AS (
        SELECT 
            AVG(adg) FILTER (WHERE measurement_date >= CURRENT_DATE - INTERVAL '7 days') as week_adg,
            AVG(adg) FILTER (WHERE measurement_date >= CURRENT_DATE - INTERVAL '30 days') as month_adg
        FROM public.weights
        WHERE animal_id = p_animal_id AND status = 'active' AND adg IS NOT NULL
    )
    INSERT INTO public.weight_statistics_cache (
        animal_id, total_weights, first_weight_date, last_weight_date,
        current_weight, starting_weight, highest_weight, lowest_weight,
        average_adg, best_adg_period, worst_adg_period,
        current_week_adg, current_month_adg,
        last_calculated, needs_recalculation
    )
    SELECT 
        p_animal_id,
        wd.total_weights,
        wd.first_date,
        wd.last_date,
        lw.weight_value,
        fw.weight_value,
        wd.max_weight,
        wd.min_weight,
        ROUND(wd.avg_adg::DECIMAL, 3),
        ROUND(wd.max_adg::DECIMAL, 3),
        ROUND(wd.min_adg::DECIMAL, 3),
        ROUND(ra.week_adg::DECIMAL, 3),
        ROUND(ra.month_adg::DECIMAL, 3),
        NOW(),
        FALSE
    FROM weight_data wd
    CROSS JOIN latest_weight lw
    CROSS JOIN first_weight fw
    CROSS JOIN recent_adg ra
    ON CONFLICT (animal_id)
    DO UPDATE SET
        total_weights = EXCLUDED.total_weights,
        first_weight_date = EXCLUDED.first_weight_date,
        last_weight_date = EXCLUDED.last_weight_date,
        current_weight = EXCLUDED.current_weight,
        starting_weight = EXCLUDED.starting_weight,
        highest_weight = EXCLUDED.highest_weight,
        lowest_weight = EXCLUDED.lowest_weight,
        average_adg = EXCLUDED.average_adg,
        best_adg_period = EXCLUDED.best_adg_period,
        worst_adg_period = EXCLUDED.worst_adg_period,
        current_week_adg = EXCLUDED.current_week_adg,
        current_month_adg = EXCLUDED.current_month_adg,
        last_calculated = EXCLUDED.last_calculated,
        needs_recalculation = FALSE;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- 10. HELPER FUNCTIONS FOR COMMON OPERATIONS
-- =====================================================================

-- Function to get weight trend for an animal
CREATE OR REPLACE FUNCTION get_weight_trend(p_animal_id UUID, p_days INTEGER DEFAULT 30)
RETURNS TABLE(
    trend VARCHAR(20),
    trend_percentage DECIMAL(5,2),
    average_change DECIMAL(5,2)
) AS $$
BEGIN
    RETURN QUERY
    WITH recent_weights AS (
        SELECT weight_value, measurement_date
        FROM public.weights
        WHERE animal_id = p_animal_id 
            AND status = 'active'
            AND measurement_date >= CURRENT_DATE - p_days * INTERVAL '1 day'
        ORDER BY measurement_date
    ),
    regression AS (
        SELECT 
            regr_slope(weight_value, EXTRACT(EPOCH FROM measurement_date)) as slope,
            regr_r2(weight_value, EXTRACT(EPOCH FROM measurement_date)) as r_squared,
            AVG(weight_value) as avg_weight
        FROM recent_weights
    )
    SELECT 
        CASE 
            WHEN r.slope > 0.01 THEN 'increasing'
            WHEN r.slope < -0.01 THEN 'decreasing'
            ELSE 'stable'
        END::VARCHAR(20) as trend,
        ROUND((r.slope * 86400 * p_days / r.avg_weight * 100)::DECIMAL, 2) as trend_percentage,
        ROUND((r.slope * 86400)::DECIMAL, 2) as average_change
    FROM regression r;
END;
$$ LANGUAGE plpgsql;

-- Function to detect outliers in weight data
CREATE OR REPLACE FUNCTION detect_weight_outliers(p_animal_id UUID)
RETURNS TABLE(
    weight_id UUID,
    weight_value DECIMAL(10,2),
    measurement_date DATE,
    deviation DECIMAL(5,2)
) AS $$
BEGIN
    RETURN QUERY
    WITH stats AS (
        SELECT 
            AVG(weight_value) as mean_weight,
            STDDEV(weight_value) as std_dev
        FROM public.weights
        WHERE animal_id = p_animal_id AND status = 'active'
    ),
    weight_deviations AS (
        SELECT 
            w.id,
            w.weight_value,
            w.measurement_date,
            ABS((w.weight_value - s.mean_weight) / NULLIF(s.std_dev, 0)) as z_score
        FROM public.weights w
        CROSS JOIN stats s
        WHERE w.animal_id = p_animal_id AND w.status = 'active'
    )
    SELECT 
        id as weight_id,
        weight_value,
        measurement_date,
        ROUND(z_score::DECIMAL, 2) as deviation
    FROM weight_deviations
    WHERE z_score > 3  -- Weights more than 3 standard deviations from mean
    ORDER BY measurement_date DESC;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- 11. SCHEDULED MAINTENANCE FUNCTIONS
-- =====================================================================

-- Function to clean up old audit logs (call periodically)
CREATE OR REPLACE FUNCTION cleanup_old_audit_logs()
RETURNS INTEGER AS $$
DECLARE
    v_deleted_count INTEGER;
BEGIN
    DELETE FROM public.weight_audit_log
    WHERE performed_at < NOW() - INTERVAL '1 year';
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Function to recalculate all pending statistics (call periodically)
CREATE OR REPLACE FUNCTION recalculate_all_pending_statistics()
RETURNS INTEGER AS $$
DECLARE
    v_animal_id UUID;
    v_count INTEGER := 0;
BEGIN
    FOR v_animal_id IN 
        SELECT animal_id 
        FROM public.weight_statistics_cache 
        WHERE needs_recalculation = TRUE
    LOOP
        PERFORM recalculate_weight_statistics(v_animal_id);
        v_count := v_count + 1;
    END LOOP;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- 12. GRANT PERMISSIONS FOR VIEWS
-- =====================================================================

GRANT SELECT ON public.v_latest_weights TO authenticated;
GRANT SELECT ON public.v_adg_calculations TO authenticated;
GRANT SELECT ON public.v_weight_history TO authenticated;
GRANT SELECT ON public.v_active_weight_goals TO authenticated;

-- =====================================================================
-- 13. COMMENTS FOR DOCUMENTATION
-- =====================================================================

COMMENT ON TABLE public.weights IS 'Core table for tracking livestock weight measurements with full audit trail';
COMMENT ON TABLE public.weight_goals IS 'Weight targets and goals for animals with progress tracking';
COMMENT ON TABLE public.weight_audit_log IS 'Complete audit trail for all weight data modifications';
COMMENT ON TABLE public.weight_statistics_cache IS 'Cached statistics for performance optimization';

COMMENT ON COLUMN public.weights.adg IS 'Average Daily Gain calculated from previous weight entry';
COMMENT ON COLUMN public.weights.confidence_level IS 'Subjective confidence in measurement accuracy (1-10)';
COMMENT ON COLUMN public.weights.is_outlier IS 'Flag for statistical outliers based on z-score analysis';

COMMENT ON VIEW public.v_latest_weights IS 'Most recent weight entry for each animal';
COMMENT ON VIEW public.v_adg_calculations IS 'ADG calculations between consecutive weight entries';
COMMENT ON VIEW public.v_weight_history IS 'Complete weight history with previous/next references';
COMMENT ON VIEW public.v_active_weight_goals IS 'Active weight goals with real-time progress calculations';

-- =====================================================================
-- END OF MIGRATION
-- =====================================================================