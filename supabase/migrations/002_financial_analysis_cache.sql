-- Create table for caching N8N financial analysis results
CREATE TABLE IF NOT EXISTS financial_analysis_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  analysis_type TEXT NOT NULL CHECK (analysis_type IN (
    'feed_cost_analysis',
    'health_expense_analysis',
    'roi_calculation',
    'break_even_analysis',
    'cost_optimization',
    'budget_forecast',
    'expense_trends',
    'comparative_analysis'
  )),
  analysis_result JSONB NOT NULL,
  status TEXT DEFAULT 'completed' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  cost_savings DECIMAL(10,2) DEFAULT 0,
  expenses_analyzed INTEGER DEFAULT 0,
  insights_count INTEGER DEFAULT 0,
  recommendations JSONB DEFAULT '[]'::jsonb,
  insights JSONB DEFAULT '{}'::jsonb,
  metadata JSONB DEFAULT '{}'::jsonb,
  error_message TEXT,
  processing_time_ms INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '30 days')
);

-- Add RLS policies
ALTER TABLE financial_analysis_cache ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own analysis results" 
  ON financial_analysis_cache 
  FOR SELECT 
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own analysis results" 
  ON financial_analysis_cache 
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own analysis results"
  ON financial_analysis_cache
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own analysis results"
  ON financial_analysis_cache
  FOR DELETE
  USING (auth.uid() = user_id);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_financial_analysis_cache_user_type 
  ON financial_analysis_cache(user_id, analysis_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_financial_analysis_cache_status
  ON financial_analysis_cache(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_financial_analysis_cache_expires 
  ON financial_analysis_cache(expires_at) 
  WHERE expires_at IS NOT NULL;

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_financial_analysis_cache_updated_at
  BEFORE UPDATE ON financial_analysis_cache
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Add comment for documentation
COMMENT ON TABLE financial_analysis_cache IS 'Stores cached results from N8N Financial Agent AI analysis for faster retrieval and historical tracking';
COMMENT ON COLUMN financial_analysis_cache.analysis_type IS 'Type of analysis: feed_cost_analysis, break_even_analysis, roi_projection, etc.';
COMMENT ON COLUMN financial_analysis_cache.analysis_result IS 'Full JSON result from N8N containing insights, recommendations, and calculations';
COMMENT ON COLUMN financial_analysis_cache.cost_savings IS 'Calculated cost savings from the analysis';
COMMENT ON COLUMN financial_analysis_cache.recommendations IS 'AI-generated recommendations array';
COMMENT ON COLUMN financial_analysis_cache.insights IS 'Key insights extracted from the analysis';
COMMENT ON COLUMN financial_analysis_cache.metadata IS 'Additional metadata about the analysis';
COMMENT ON COLUMN financial_analysis_cache.expires_at IS 'When this cache entry should be deleted';
COMMENT ON COLUMN financial_analysis_cache.processing_time_ms IS 'Time taken to process the analysis in milliseconds';

-- Create function to clean up expired cache entries
CREATE OR REPLACE FUNCTION cleanup_expired_financial_analysis_cache()
RETURNS void AS $$
BEGIN
  DELETE FROM financial_analysis_cache 
  WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Create view for recent analysis results
CREATE OR REPLACE VIEW recent_financial_analysis AS
SELECT 
  fac.id,
  fac.user_id,
  fac.analysis_type,
  fac.status,
  fac.cost_savings,
  fac.created_at,
  fac.analysis_result->>'summary' as summary,
  fac.recommendations,
  u.email as user_email
FROM financial_analysis_cache fac
LEFT JOIN auth.users u ON u.id = fac.user_id
WHERE fac.created_at > NOW() - INTERVAL '7 days'
  AND fac.status = 'completed'
ORDER BY fac.created_at DESC;

-- Grant access to the view
GRANT SELECT ON recent_financial_analysis TO authenticated;

-- Create materialized view for analysis statistics
CREATE MATERIALIZED VIEW IF NOT EXISTS financial_analysis_stats AS
SELECT 
  user_id,
  analysis_type,
  COUNT(*) as analysis_count,
  AVG(cost_savings) as avg_cost_savings,
  SUM(cost_savings) as total_cost_savings,
  AVG(processing_time_ms) as avg_processing_time,
  MAX(created_at) as last_analysis_date,
  COUNT(CASE WHEN status = 'completed' THEN 1 END) as successful_analyses,
  COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_analyses
FROM financial_analysis_cache
WHERE created_at > NOW() - INTERVAL '90 days'
GROUP BY user_id, analysis_type;

-- Create index on materialized view
CREATE INDEX idx_financial_analysis_stats_user 
  ON financial_analysis_stats(user_id);

-- Function to refresh materialized view
CREATE OR REPLACE FUNCTION refresh_financial_analysis_stats()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY financial_analysis_stats;
END;
$$ LANGUAGE plpgsql;

-- Grant necessary permissions
GRANT SELECT ON financial_analysis_stats TO authenticated;