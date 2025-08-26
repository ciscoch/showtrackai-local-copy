-- Create SPAR (Strategic Planning AI Reasoning) runs table
-- This table tracks the full lifecycle of AI processing orchestration for journal entries

CREATE TABLE IF NOT EXISTS public.spar_runs (
    -- Primary identification
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id TEXT NOT NULL UNIQUE, -- The trace_id used for correlation
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    journal_entry_id UUID REFERENCES public.journal_entries(id) ON DELETE SET NULL,
    
    -- SPAR orchestration data
    goal TEXT NOT NULL, -- The intent/goal (e.g., 'edu_context', 'analysis', 'feedback')
    inputs JSONB NOT NULL DEFAULT '{}', -- Input data sent to SPAR
    plan JSONB, -- AI-generated execution plan
    step_results JSONB, -- Results from each execution step
    reflections JSONB, -- AI reflections and insights
    
    -- Status tracking
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'timeout')),
    error TEXT, -- Error message if failed
    error_details JSONB, -- Detailed error information
    retry_count INTEGER DEFAULT 0,
    
    -- Performance metrics
    processing_started_at TIMESTAMP WITH TIME ZONE,
    processing_completed_at TIMESTAMP WITH TIME ZONE,
    processing_duration_ms INTEGER, -- Processing time in milliseconds
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    failed_at TIMESTAMP WITH TIME ZONE,
    retried_at TIMESTAMP WITH TIME ZONE,
    
    -- Indexes for performance
    CONSTRAINT spar_runs_run_id_unique UNIQUE (run_id)
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_spar_runs_user_id ON public.spar_runs(user_id);
CREATE INDEX IF NOT EXISTS idx_spar_runs_journal_entry_id ON public.spar_runs(journal_entry_id);
CREATE INDEX IF NOT EXISTS idx_spar_runs_status ON public.spar_runs(status);
CREATE INDEX IF NOT EXISTS idx_spar_runs_created_at ON public.spar_runs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_spar_runs_user_status ON public.spar_runs(user_id, status, created_at DESC);

-- Create a composite index for monitoring active runs
CREATE INDEX IF NOT EXISTS idx_spar_runs_active ON public.spar_runs(status, created_at) 
WHERE status IN ('pending', 'processing');

-- Add trigger to automatically update updated_at
CREATE OR REPLACE FUNCTION update_spar_runs_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_spar_runs_updated_at
    BEFORE UPDATE ON public.spar_runs
    FOR EACH ROW
    EXECUTE FUNCTION update_spar_runs_updated_at();

-- Row Level Security (RLS)
ALTER TABLE public.spar_runs ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own SPAR runs
CREATE POLICY "Users can view own SPAR runs" ON public.spar_runs
    FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Users can create SPAR runs for themselves
CREATE POLICY "Users can create own SPAR runs" ON public.spar_runs
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own SPAR runs
CREATE POLICY "Users can update own SPAR runs" ON public.spar_runs
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy: Service role can do everything (for N8N webhook callbacks)
CREATE POLICY "Service role full access to SPAR runs" ON public.spar_runs
    FOR ALL
    USING (auth.role() = 'service_role');

-- Create a view for SPAR run statistics
CREATE OR REPLACE VIEW public.spar_run_statistics AS
SELECT 
    user_id,
    COUNT(*) as total_runs,
    COUNT(*) FILTER (WHERE status = 'completed') as completed_runs,
    COUNT(*) FILTER (WHERE status = 'failed') as failed_runs,
    COUNT(*) FILTER (WHERE status = 'timeout') as timeout_runs,
    COUNT(*) FILTER (WHERE status IN ('pending', 'processing')) as active_runs,
    AVG(processing_duration_ms) FILTER (WHERE status = 'completed') as avg_duration_ms,
    MAX(created_at) as last_run_at,
    CASE 
        WHEN COUNT(*) > 0 THEN 
            ROUND(COUNT(*) FILTER (WHERE status = 'completed')::NUMERIC / COUNT(*)::NUMERIC * 100, 2)
        ELSE 0 
    END as success_rate
FROM public.spar_runs
GROUP BY user_id;

-- Grant permissions on the view
GRANT SELECT ON public.spar_run_statistics TO authenticated;

-- Function to clean up old SPAR runs (maintenance)
CREATE OR REPLACE FUNCTION cleanup_old_spar_runs(days_to_keep INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM public.spar_runs
    WHERE created_at < NOW() - INTERVAL '1 day' * days_to_keep
    AND status IN ('completed', 'failed', 'timeout');
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Function to monitor and timeout stuck SPAR runs
CREATE OR REPLACE FUNCTION timeout_stuck_spar_runs(timeout_seconds INTEGER DEFAULT 60)
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE public.spar_runs
    SET 
        status = 'timeout',
        error = CONCAT('Processing timeout after ', timeout_seconds, ' seconds'),
        error_details = jsonb_build_object(
            'timeout_seconds', timeout_seconds,
            'timeout_at', NOW()
        ),
        updated_at = NOW()
    WHERE status IN ('pending', 'processing')
    AND created_at < NOW() - INTERVAL '1 second' * timeout_seconds;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$ LANGUAGE plpgsql;

-- Add comment to the table for documentation
COMMENT ON TABLE public.spar_runs IS 'Tracks SPAR (Strategic Planning AI Reasoning) orchestration runs for AI processing of journal entries';
COMMENT ON COLUMN public.spar_runs.run_id IS 'Unique trace ID for end-to-end correlation across systems';
COMMENT ON COLUMN public.spar_runs.goal IS 'The intent or goal of the SPAR run (edu_context, analysis, feedback, etc.)';
COMMENT ON COLUMN public.spar_runs.inputs IS 'Input data sent to the SPAR orchestrator including journal data and settings';
COMMENT ON COLUMN public.spar_runs.plan IS 'AI-generated execution plan for processing the journal entry';
COMMENT ON COLUMN public.spar_runs.step_results IS 'Results from each step of the SPAR orchestration';
COMMENT ON COLUMN public.spar_runs.reflections IS 'AI reflections, insights, and recommendations from the processing';