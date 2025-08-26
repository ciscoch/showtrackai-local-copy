-- ============================================================================
-- ShowTrackAI Comprehensive Security Enhancement Migration
-- Version: 2.0
-- Date: 2025-01-31
-- Description: Implements complete security hardening with COPPA compliance,
--              audit logging, role-based access, and vulnerability fixes
-- ============================================================================

-- Start transaction for atomic execution
BEGIN;

-- ============================================================================
-- SECTION 1: Security Audit Tables
-- ============================================================================

-- Create security audit log table
CREATE TABLE IF NOT EXISTS security_audit_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_type VARCHAR(100) NOT NULL, -- login, logout, data_access, permission_change, etc.
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  resource_type VARCHAR(100), -- animals, journal_entries, etc.
  resource_id UUID,
  action VARCHAR(50) NOT NULL, -- create, read, update, delete
  ip_address INET,
  user_agent TEXT,
  success BOOLEAN DEFAULT TRUE,
  error_message TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for efficient querying
CREATE INDEX idx_security_audit_user_date ON security_audit_log(user_id, created_at DESC);
CREATE INDEX idx_security_audit_event_type ON security_audit_log(event_type, created_at DESC);
CREATE INDEX idx_security_audit_resource ON security_audit_log(resource_type, resource_id);

-- ============================================================================
-- SECTION 2: Enhanced User Profiles with Roles and COPPA
-- ============================================================================

-- Extend user_profiles table for comprehensive security
ALTER TABLE user_profiles 
  ADD COLUMN IF NOT EXISTS user_role VARCHAR(50) DEFAULT 'student',
  ADD COLUMN IF NOT EXISTS account_status VARCHAR(50) DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS failed_login_attempts INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_failed_login TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS account_locked_until TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS two_factor_enabled BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS privacy_settings JSONB DEFAULT '{"shareData": false, "publicProfile": false}',
  ADD COLUMN IF NOT EXISTS coppa_verification_token VARCHAR(255),
  ADD COLUMN IF NOT EXISTS coppa_verification_sent_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS data_retention_consent BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS gdpr_consent BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS gdpr_consent_date TIMESTAMP WITH TIME ZONE;

-- Add check constraint for valid roles
ALTER TABLE user_profiles 
  DROP CONSTRAINT IF EXISTS valid_user_roles;
ALTER TABLE user_profiles 
  ADD CONSTRAINT valid_user_roles 
  CHECK (user_role IN ('student', 'educator', 'parent', 'admin', 'advisor', 'veterinarian'));

-- Add check constraint for account status
ALTER TABLE user_profiles 
  DROP CONSTRAINT IF EXISTS valid_account_status;
ALTER TABLE user_profiles 
  ADD CONSTRAINT valid_account_status 
  CHECK (account_status IN ('active', 'suspended', 'locked', 'pending_verification', 'deleted'));

-- ============================================================================
-- SECTION 3: Parent-Child Relationship Table for COPPA
-- ============================================================================

CREATE TABLE IF NOT EXISTS parent_child_relationships (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  parent_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  child_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  relationship_type VARCHAR(50) NOT NULL DEFAULT 'parent', -- parent, guardian, authorized_adult
  consent_granted BOOLEAN DEFAULT FALSE,
  consent_date TIMESTAMP WITH TIME ZONE,
  consent_ip_address INET,
  access_level VARCHAR(50) DEFAULT 'read_only', -- read_only, partial, full
  verified BOOLEAN DEFAULT FALSE,
  verification_method VARCHAR(100), -- email, document, in_person
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(parent_id, child_id)
);

CREATE INDEX idx_parent_child_parent ON parent_child_relationships(parent_id);
CREATE INDEX idx_parent_child_child ON parent_child_relationships(child_id);

-- ============================================================================
-- SECTION 4: Data Access Control Lists (ACL)
-- ============================================================================

CREATE TABLE IF NOT EXISTS data_access_control (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  resource_type VARCHAR(100) NOT NULL, -- animals, journal_entries, etc.
  resource_id UUID NOT NULL,
  owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  shared_with_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  permission_level VARCHAR(50) NOT NULL DEFAULT 'read', -- read, write, admin
  shared_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE,
  reason TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(resource_type, resource_id, owner_id, shared_with_id)
);

CREATE INDEX idx_acl_owner ON data_access_control(owner_id);
CREATE INDEX idx_acl_shared_with ON data_access_control(shared_with_id);
CREATE INDEX idx_acl_resource ON data_access_control(resource_type, resource_id);

-- ============================================================================
-- SECTION 5: Session Management for Security
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_sessions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  session_token VARCHAR(255) UNIQUE NOT NULL,
  ip_address INET,
  user_agent TEXT,
  device_info JSONB DEFAULT '{}',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() + INTERVAL '24 hours'
);

CREATE INDEX idx_sessions_user ON user_sessions(user_id, is_active);
CREATE INDEX idx_sessions_token ON user_sessions(session_token) WHERE is_active = TRUE;
CREATE INDEX idx_sessions_expiry ON user_sessions(expires_at) WHERE is_active = TRUE;

-- ============================================================================
-- SECTION 6: Enhanced RLS Policies with Role-Based Access
-- ============================================================================

-- Enhanced policies for animals table
DROP POLICY IF EXISTS "Users can view own animals" ON animals;
DROP POLICY IF EXISTS "Users can insert own animals" ON animals;
DROP POLICY IF EXISTS "Users can update own animals" ON animals;
DROP POLICY IF EXISTS "Users can delete own animals" ON animals;

-- Allow users to see their own animals or animals shared with them
CREATE POLICY "animals_select_policy" ON animals FOR SELECT
  USING (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM data_access_control 
      WHERE resource_type = 'animals' 
        AND resource_id = animals.id 
        AND shared_with_id = auth.uid()
        AND (expires_at IS NULL OR expires_at > NOW())
    )
    OR EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() 
        AND user_role IN ('admin', 'educator', 'veterinarian')
    )
  );

CREATE POLICY "animals_insert_policy" ON animals FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() 
        AND account_status = 'active'
    )
  );

CREATE POLICY "animals_update_policy" ON animals FOR UPDATE
  USING (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM data_access_control 
      WHERE resource_type = 'animals' 
        AND resource_id = animals.id 
        AND shared_with_id = auth.uid()
        AND permission_level IN ('write', 'admin')
        AND (expires_at IS NULL OR expires_at > NOW())
    )
  )
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "animals_delete_policy" ON animals FOR DELETE
  USING (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() 
        AND account_status = 'active'
    )
  );

-- Enhanced policies for journal_entries table with COPPA compliance
DROP POLICY IF EXISTS "Users can view own journal entries" ON journal_entries;
DROP POLICY IF EXISTS "Users can insert own journal entries" ON journal_entries;
DROP POLICY IF EXISTS "Users can update own journal entries" ON journal_entries;
DROP POLICY IF EXISTS "Users can delete own journal entries" ON journal_entries;

CREATE POLICY "journal_entries_select_policy" ON journal_entries FOR SELECT
  USING (
    -- Own entries
    auth.uid() = user_id
    -- Shared entries
    OR EXISTS (
      SELECT 1 FROM data_access_control 
      WHERE resource_type = 'journal_entries' 
        AND resource_id = journal_entries.id 
        AND shared_with_id = auth.uid()
        AND (expires_at IS NULL OR expires_at > NOW())
    )
    -- Parent access to minor's entries (COPPA)
    OR EXISTS (
      SELECT 1 FROM parent_child_relationships 
      WHERE parent_id = auth.uid() 
        AND child_id = journal_entries.user_id
        AND consent_granted = TRUE
    )
    -- Educator/Admin access
    OR EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() 
        AND user_role IN ('admin', 'educator')
        AND account_status = 'active'
    )
  );

CREATE POLICY "journal_entries_insert_policy" ON journal_entries FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() 
        AND account_status = 'active'
        AND (
          -- Adults can always create
          is_minor = FALSE 
          -- Minors need parent consent
          OR (is_minor = TRUE AND parent_consent = TRUE)
        )
    )
  );

CREATE POLICY "journal_entries_update_policy" ON journal_entries FOR UPDATE
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM data_access_control 
      WHERE resource_type = 'journal_entries' 
        AND resource_id = journal_entries.id 
        AND shared_with_id = auth.uid()
        AND permission_level IN ('write', 'admin')
    )
  )
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "journal_entries_delete_policy" ON journal_entries FOR DELETE
  USING (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() 
        AND account_status = 'active'
    )
  );

-- ============================================================================
-- SECTION 7: Security Functions
-- ============================================================================

-- Function to log security events
CREATE OR REPLACE FUNCTION log_security_event(
  p_event_type VARCHAR,
  p_resource_type VARCHAR DEFAULT NULL,
  p_resource_id UUID DEFAULT NULL,
  p_action VARCHAR DEFAULT NULL,
  p_success BOOLEAN DEFAULT TRUE,
  p_error_message TEXT DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'
) RETURNS UUID AS $$
DECLARE
  v_audit_id UUID;
BEGIN
  INSERT INTO security_audit_log (
    event_type,
    user_id,
    resource_type,
    resource_id,
    action,
    success,
    error_message,
    metadata
  ) VALUES (
    p_event_type,
    auth.uid(),
    p_resource_type,
    p_resource_id,
    p_action,
    p_success,
    p_error_message,
    p_metadata
  ) RETURNING id INTO v_audit_id;
  
  RETURN v_audit_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is minor and has parent consent
CREATE OR REPLACE FUNCTION check_coppa_compliance(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_profile user_profiles%ROWTYPE;
BEGIN
  SELECT * INTO v_profile FROM user_profiles WHERE id = p_user_id;
  
  -- If user not found or not a minor, return true (no COPPA needed)
  IF v_profile IS NULL OR v_profile.is_minor = FALSE THEN
    RETURN TRUE;
  END IF;
  
  -- Minor needs parent consent
  RETURN v_profile.parent_consent = TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to handle failed login attempts
CREATE OR REPLACE FUNCTION handle_failed_login(p_email TEXT)
RETURNS VOID AS $$
DECLARE
  v_profile user_profiles%ROWTYPE;
  v_max_attempts INTEGER := 5;
  v_lockout_duration INTERVAL := '30 minutes';
BEGIN
  SELECT * INTO v_profile FROM user_profiles WHERE email = p_email;
  
  IF v_profile IS NOT NULL THEN
    UPDATE user_profiles 
    SET 
      failed_login_attempts = failed_login_attempts + 1,
      last_failed_login = NOW(),
      account_locked_until = CASE 
        WHEN failed_login_attempts + 1 >= v_max_attempts 
        THEN NOW() + v_lockout_duration
        ELSE account_locked_until
      END,
      account_status = CASE 
        WHEN failed_login_attempts + 1 >= v_max_attempts 
        THEN 'locked'
        ELSE account_status
      END
    WHERE id = v_profile.id;
    
    -- Log security event
    PERFORM log_security_event(
      'failed_login',
      NULL,
      NULL,
      'login',
      FALSE,
      'Invalid credentials',
      jsonb_build_object('email', p_email, 'attempts', v_profile.failed_login_attempts + 1)
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to reset login attempts on successful login
CREATE OR REPLACE FUNCTION handle_successful_login(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE user_profiles 
  SET 
    failed_login_attempts = 0,
    last_failed_login = NULL,
    account_locked_until = NULL,
    account_status = CASE 
      WHEN account_status = 'locked' THEN 'active'
      ELSE account_status
    END
  WHERE id = p_user_id;
  
  -- Log security event
  PERFORM log_security_event(
    'successful_login',
    NULL,
    NULL,
    'login',
    TRUE,
    NULL,
    jsonb_build_object('user_id', p_user_id)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- SECTION 8: Triggers for Automatic Security
-- ============================================================================

-- Trigger to log data access
CREATE OR REPLACE FUNCTION log_data_access()
RETURNS TRIGGER AS $$
BEGIN
  -- Log SELECT operations (for sensitive tables)
  IF TG_OP = 'SELECT' AND TG_TABLE_NAME IN ('journal_entries', 'health_records') THEN
    PERFORM log_security_event(
      'data_access',
      TG_TABLE_NAME,
      NEW.id,
      'read',
      TRUE,
      NULL,
      jsonb_build_object('table', TG_TABLE_NAME)
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add updated_at triggers to all relevant tables
CREATE TRIGGER update_user_profiles_updated_at
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_parent_child_updated_at
  BEFORE UPDATE ON parent_child_relationships
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- ============================================================================
-- SECTION 9: Input Validation Functions
-- ============================================================================

-- Function to validate and sanitize text input
CREATE OR REPLACE FUNCTION sanitize_text(input_text TEXT, max_length INTEGER DEFAULT 5000)
RETURNS TEXT AS $$
BEGIN
  -- Remove null bytes
  input_text := REPLACE(input_text, E'\\x00', '');
  
  -- Trim whitespace
  input_text := TRIM(input_text);
  
  -- Limit length
  IF LENGTH(input_text) > max_length THEN
    input_text := LEFT(input_text, max_length);
  END IF;
  
  -- Remove potential SQL injection patterns (basic)
  input_text := REGEXP_REPLACE(input_text, '(;--|/\*|\*/|xp_|sp_|0x)', '', 'gi');
  
  RETURN input_text;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to validate email format
CREATE OR REPLACE FUNCTION validate_email(email TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- SECTION 10: Data Encryption Functions
-- ============================================================================

-- Function to encrypt sensitive data (requires pgcrypto extension)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Function to encrypt PII data
CREATE OR REPLACE FUNCTION encrypt_pii(data TEXT, key_id TEXT DEFAULT 'default')
RETURNS TEXT AS $$
DECLARE
  encryption_key TEXT;
BEGIN
  -- In production, retrieve key from secure key management service
  -- This is a placeholder - replace with actual KMS integration
  encryption_key := current_setting('app.encryption_key', TRUE);
  
  IF encryption_key IS NULL THEN
    RAISE EXCEPTION 'Encryption key not configured';
  END IF;
  
  RETURN encode(
    pgp_sym_encrypt(data, encryption_key),
    'base64'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to decrypt PII data
CREATE OR REPLACE FUNCTION decrypt_pii(encrypted_data TEXT, key_id TEXT DEFAULT 'default')
RETURNS TEXT AS $$
DECLARE
  encryption_key TEXT;
BEGIN
  encryption_key := current_setting('app.encryption_key', TRUE);
  
  IF encryption_key IS NULL THEN
    RAISE EXCEPTION 'Encryption key not configured';
  END IF;
  
  RETURN pgp_sym_decrypt(
    decode(encrypted_data, 'base64'),
    encryption_key
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- SECTION 11: Rate Limiting
-- ============================================================================

CREATE TABLE IF NOT EXISTS api_rate_limits (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  endpoint VARCHAR(255) NOT NULL,
  request_count INTEGER DEFAULT 1,
  window_start TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  window_end TIMESTAMP WITH TIME ZONE DEFAULT NOW() + INTERVAL '1 hour',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, endpoint, window_start)
);

CREATE INDEX idx_rate_limits_user_endpoint ON api_rate_limits(user_id, endpoint, window_end);

-- Function to check rate limit
CREATE OR REPLACE FUNCTION check_rate_limit(
  p_user_id UUID,
  p_endpoint VARCHAR,
  p_max_requests INTEGER DEFAULT 100
) RETURNS BOOLEAN AS $$
DECLARE
  v_current_count INTEGER;
BEGIN
  -- Get current request count in active window
  SELECT request_count INTO v_current_count
  FROM api_rate_limits
  WHERE user_id = p_user_id
    AND endpoint = p_endpoint
    AND window_end > NOW();
  
  -- If no record or under limit, allow request
  IF v_current_count IS NULL OR v_current_count < p_max_requests THEN
    -- Increment or create rate limit record
    INSERT INTO api_rate_limits (user_id, endpoint, request_count)
    VALUES (p_user_id, p_endpoint, 1)
    ON CONFLICT (user_id, endpoint, window_start)
    DO UPDATE SET request_count = api_rate_limits.request_count + 1;
    
    RETURN TRUE;
  ELSE
    -- Log rate limit exceeded
    PERFORM log_security_event(
      'rate_limit_exceeded',
      'api',
      NULL,
      p_endpoint,
      FALSE,
      'Rate limit exceeded',
      jsonb_build_object('user_id', p_user_id, 'endpoint', p_endpoint, 'count', v_current_count)
    );
    
    RETURN FALSE;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- SECTION 12: Data Retention and GDPR Compliance
-- ============================================================================

CREATE TABLE IF NOT EXISTS data_deletion_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  request_type VARCHAR(50) NOT NULL, -- gdpr_deletion, account_deletion, data_export
  status VARCHAR(50) DEFAULT 'pending', -- pending, processing, completed, failed
  requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  processed_at TIMESTAMP WITH TIME ZONE,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Function to handle GDPR data export
CREATE OR REPLACE FUNCTION export_user_data(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'user_profile', (SELECT row_to_json(u.*) FROM user_profiles u WHERE u.id = p_user_id),
    'animals', (SELECT jsonb_agg(row_to_json(a.*)) FROM animals a WHERE a.user_id = p_user_id),
    'journal_entries', (SELECT jsonb_agg(row_to_json(j.*)) FROM journal_entries j WHERE j.user_id = p_user_id),
    'health_records', (SELECT jsonb_agg(row_to_json(h.*)) FROM health_records h WHERE h.user_id = p_user_id),
    'weights', (SELECT jsonb_agg(row_to_json(w.*)) FROM weights w WHERE w.user_id = p_user_id)
  ) INTO v_result;
  
  -- Log data export
  PERFORM log_security_event(
    'data_export',
    NULL,
    NULL,
    'export',
    TRUE,
    NULL,
    jsonb_build_object('user_id', p_user_id)
  );
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to anonymize user data (for GDPR right to be forgotten)
CREATE OR REPLACE FUNCTION anonymize_user_data(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  -- Anonymize user profile
  UPDATE user_profiles
  SET 
    email = CONCAT('deleted_', p_user_id, '@anonymous.local'),
    birth_date = NULL,
    parent_email = NULL,
    metadata = '{}',
    account_status = 'deleted'
  WHERE id = p_user_id;
  
  -- Anonymize related data
  UPDATE animals
  SET 
    name = CONCAT('Animal_', SUBSTRING(id::TEXT, 1, 8)),
    tag_number = NULL
  WHERE user_id = p_user_id;
  
  UPDATE journal_entries
  SET 
    title = 'Deleted Entry',
    description = 'This content has been removed',
    weather = NULL,
    location = NULL
  WHERE user_id = p_user_id;
  
  -- Log anonymization
  PERFORM log_security_event(
    'data_anonymization',
    NULL,
    NULL,
    'anonymize',
    TRUE,
    NULL,
    jsonb_build_object('user_id', p_user_id)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- SECTION 13: Security Views for Monitoring
-- ============================================================================

-- View for active sessions
CREATE OR REPLACE VIEW active_sessions AS
SELECT 
  us.user_id,
  up.email,
  up.user_role,
  us.ip_address,
  us.created_at AS session_start,
  us.last_activity,
  us.expires_at
FROM user_sessions us
JOIN user_profiles up ON up.id = us.user_id
WHERE us.is_active = TRUE
  AND us.expires_at > NOW();

-- View for security events summary
CREATE OR REPLACE VIEW security_events_summary AS
SELECT 
  event_type,
  DATE(created_at) as event_date,
  COUNT(*) as event_count,
  COUNT(DISTINCT user_id) as unique_users,
  SUM(CASE WHEN success = FALSE THEN 1 ELSE 0 END) as failure_count
FROM security_audit_log
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY event_type, DATE(created_at)
ORDER BY event_date DESC, event_count DESC;

-- View for locked accounts
CREATE OR REPLACE VIEW locked_accounts AS
SELECT 
  id,
  email,
  failed_login_attempts,
  last_failed_login,
  account_locked_until,
  account_status
FROM user_profiles
WHERE account_status = 'locked'
  OR account_locked_until > NOW();

-- View for COPPA compliance status
CREATE OR REPLACE VIEW coppa_compliance_status AS
SELECT 
  up.id,
  up.email,
  up.birth_date,
  EXTRACT(YEAR FROM AGE(CURRENT_DATE, up.birth_date)) as age,
  up.is_minor,
  up.parent_email,
  up.parent_consent,
  up.parent_consent_date,
  pcr.parent_id,
  pcr.consent_granted as parent_relationship_consent,
  pcr.verified as parent_verified
FROM user_profiles up
LEFT JOIN parent_child_relationships pcr ON pcr.child_id = up.id
WHERE up.is_minor = TRUE;

-- ============================================================================
-- SECTION 14: Clean up and optimize
-- ============================================================================

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_role ON user_profiles(user_role);
CREATE INDEX IF NOT EXISTS idx_user_profiles_status ON user_profiles(account_status);
CREATE INDEX IF NOT EXISTS idx_user_profiles_minor ON user_profiles(is_minor) WHERE is_minor = TRUE;

-- Vacuum and analyze tables for optimal performance
VACUUM ANALYZE user_profiles;
VACUUM ANALYZE animals;
VACUUM ANALYZE journal_entries;
VACUUM ANALYZE security_audit_log;

-- ============================================================================
-- SECTION 15: Grant Permissions
-- ============================================================================

-- Revoke all existing permissions and re-grant with proper security
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon, authenticated;

-- Grant minimal required permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;

-- Grant table permissions based on RLS policies
GRANT SELECT, INSERT, UPDATE, DELETE ON animals TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON journal_entries TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON weights TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON health_records TO authenticated;
GRANT SELECT, INSERT, UPDATE ON user_profiles TO authenticated;
GRANT SELECT ON parent_child_relationships TO authenticated;
GRANT INSERT ON security_audit_log TO authenticated;
GRANT SELECT, INSERT ON user_sessions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON api_rate_limits TO authenticated;

-- Grant sequence permissions
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant function permissions (only specific security functions)
GRANT EXECUTE ON FUNCTION check_coppa_compliance TO authenticated;
GRANT EXECUTE ON FUNCTION sanitize_text TO authenticated;
GRANT EXECUTE ON FUNCTION validate_email TO authenticated;
GRANT EXECUTE ON FUNCTION check_rate_limit TO authenticated;

-- ============================================================================
-- SECTION 16: Final Security Checks
-- ============================================================================

-- Ensure all tables have RLS enabled
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT tablename 
    FROM pg_tables 
    WHERE schemaname = 'public' 
      AND tablename NOT IN ('schema_migrations', 'pg_stat_statements')
      AND tablename NOT LIKE 'pg_%'
  LOOP
    EXECUTE FORMAT('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', r.tablename);
  END LOOP;
END $$;

-- Create a security configuration table
CREATE TABLE IF NOT EXISTS security_config (
  key VARCHAR(100) PRIMARY KEY,
  value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert default security configurations
INSERT INTO security_config (key, value, description) VALUES
  ('max_login_attempts', '5', 'Maximum failed login attempts before account lockout'),
  ('lockout_duration_minutes', '30', 'Duration of account lockout in minutes'),
  ('session_timeout_hours', '24', 'Session timeout in hours'),
  ('password_min_length', '8', 'Minimum password length'),
  ('require_2fa_for_admins', 'true', 'Require 2FA for admin accounts'),
  ('coppa_age_limit', '13', 'Age limit for COPPA compliance'),
  ('rate_limit_requests_per_hour', '100', 'API rate limit per hour'),
  ('data_retention_days', '365', 'Default data retention period in days')
ON CONFLICT (key) DO UPDATE SET 
  value = EXCLUDED.value,
  updated_at = NOW();

-- ============================================================================
-- SECTION 17: Migration Completion Log
-- ============================================================================

-- Log successful migration
INSERT INTO security_audit_log (
  event_type,
  user_id,
  action,
  success,
  metadata
) VALUES (
  'security_migration',
  auth.uid(),
  'migration_complete',
  TRUE,
  jsonb_build_object(
    'version', '2.0',
    'migration_date', NOW(),
    'description', 'Comprehensive security enhancement with COPPA compliance'
  )
);

-- Commit the transaction
COMMIT;

-- ============================================================================
-- POST-MIGRATION VERIFICATION QUERIES
-- Run these to verify migration success
-- ============================================================================

/*
-- Check RLS is enabled on all critical tables
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename IN ('animals', 'journal_entries', 'user_profiles', 'health_records', 'weights');

-- Check security policies are created
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- Verify security tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('security_audit_log', 'parent_child_relationships', 'data_access_control', 'user_sessions', 'api_rate_limits');

-- Check user roles distribution
SELECT user_role, COUNT(*) 
FROM user_profiles 
GROUP BY user_role;

-- Verify COPPA compliance setup
SELECT COUNT(*) as minor_users 
FROM user_profiles 
WHERE is_minor = TRUE;
*/