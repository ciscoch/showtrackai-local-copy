-- ============================================================================
-- PART 4: HELPER FUNCTIONS AND VIEWS
-- ============================================================================
-- Run this after Part 3 is successful

-- Function to validate phone numbers
CREATE OR REPLACE FUNCTION validate_phone(phone_number TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  -- Remove all non-digit characters for validation
  phone_number := REGEXP_REPLACE(phone_number, '[^0-9]', '', 'g');
  
  -- Check if it's a valid US phone number (10 digits)
  RETURN phone_number ~ '^[0-9]{10}$';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to validate state codes
CREATE OR REPLACE FUNCTION validate_state_code(state_code TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN state_code ~ '^[A-Z]{2}$' AND state_code IN (
    'AL','AK','AZ','AR','CA','CO','CT','DE','FL','GA',
    'HI','ID','IL','IN','IA','KS','KY','LA','ME','MD',
    'MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ',
    'NM','NY','NC','ND','OH','OK','OR','PA','RI','SC',
    'SD','TN','TX','UT','VT','VA','WA','WV','WI','WY'
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to calculate profile completion percentage
CREATE OR REPLACE FUNCTION calculate_profile_completion(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_total_fields INTEGER := 15;
  v_completed_fields INTEGER := 0;
  v_profile user_profiles%ROWTYPE;
BEGIN
  SELECT * INTO v_profile FROM user_profiles WHERE id = p_user_id;
  
  IF v_profile IS NULL THEN
    RETURN 0;
  END IF;
  
  -- Count completed fields
  IF v_profile.email IS NOT NULL AND LENGTH(v_profile.email) > 0 THEN v_completed_fields := v_completed_fields + 1; END IF;
  IF v_profile.birth_date IS NOT NULL THEN v_completed_fields := v_completed_fields + 1; END IF;
  IF v_profile.bio IS NOT NULL AND LENGTH(v_profile.bio) > 0 THEN v_completed_fields := v_completed_fields + 1; END IF;
  IF v_profile.phone IS NOT NULL AND LENGTH(v_profile.phone) > 0 THEN v_completed_fields := v_completed_fields + 1; END IF;
  IF v_profile.ffa_chapter IS NOT NULL AND LENGTH(v_profile.ffa_chapter) > 0 THEN v_completed_fields := v_completed_fields + 1; END IF;
  IF v_profile.ffa_degree IS NOT NULL AND LENGTH(v_profile.ffa_degree) > 0 THEN v_completed_fields := v_completed_fields + 1; END IF;
  IF v_profile.ffa_state IS NOT NULL THEN v_completed_fields := v_completed_fields + 1; END IF;
  IF v_profile.member_since IS NOT NULL THEN v_completed_fields := v_completed_fields + 1; END IF;
  IF v_profile.profile_image_url IS NOT NULL AND LENGTH(v_profile.profile_image_url) > 0 THEN v_completed_fields := v_completed_fields + 1; END IF;
  
  RETURN (v_completed_fields * 100 / v_total_fields);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Function to get user's current FFA degree progress
CREATE OR REPLACE FUNCTION get_ffa_degree_progress(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_progress JSONB;
BEGIN
  SELECT jsonb_build_object(
    'current_degree', up.ffa_degree,
    'progress', COALESCE(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'degree_name', fd.degree_name,
            'degree_level', fd.degree_level,
            'progress_percentage', ufp.progress_percentage,
            'status', ufp.verification_status,
            'requirements_met', ufp.requirements_met,
            'requirements_pending', ufp.requirements_pending
          )
        )
        FROM user_ffa_progress ufp
        JOIN ffa_degrees fd ON fd.id = ufp.degree_id
        WHERE ufp.user_id = p_user_id
        ORDER BY fd.degree_level
      ),
      '[]'::jsonb
    )
  ) INTO v_progress
  FROM user_profiles up
  WHERE up.id = p_user_id;
  
  RETURN v_progress;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Create useful views
CREATE OR REPLACE VIEW user_profile_summary AS
SELECT 
  up.id,
  up.email,
  up.bio,
  up.phone,
  up.ffa_chapter,
  up.ffa_degree,
  up.ffa_state,
  up.member_since,
  up.profile_image_url,
  fc.school_name,
  fc.advisor_name,
  calculate_profile_completion(up.id) as profile_completion_percentage,
  up.is_minor,
  up.parent_consent,
  up.created_at,
  up.updated_at
FROM user_profiles up
LEFT JOIN ffa_chapters fc ON fc.chapter_name = up.ffa_chapter AND fc.state_code = up.ffa_state;

-- View for FFA degree progress tracking
CREATE OR REPLACE VIEW ffa_degree_progress_view AS
SELECT 
  up.id as user_id,
  up.email,
  up.ffa_chapter,
  up.ffa_state,
  fd.degree_name,
  fd.degree_level,
  ufp.progress_percentage,
  ufp.verification_status,
  ufp.date_started,
  ufp.date_completed,
  ufp.verified_by,
  jsonb_array_length(ufp.requirements_met) as requirements_completed,
  jsonb_array_length(ufp.requirements_pending) as requirements_remaining
FROM user_profiles up
JOIN user_ffa_progress ufp ON ufp.user_id = up.id
JOIN ffa_degrees fd ON fd.id = ufp.degree_id
ORDER BY up.email, fd.degree_level;

-- Grant permissions on functions and views
GRANT EXECUTE ON FUNCTION validate_phone TO authenticated;
GRANT EXECUTE ON FUNCTION validate_state_code TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_profile_completion TO authenticated;
GRANT EXECUTE ON FUNCTION get_ffa_degree_progress TO authenticated;
GRANT SELECT ON user_profile_summary TO authenticated;
GRANT SELECT ON ffa_degree_progress_view TO authenticated;

-- ============================================================================
-- VERIFICATION QUERY 4: Check Functions and Views
-- ============================================================================

SELECT 
    'Functions' as object_type,
    COUNT(*) as count
FROM pg_proc 
WHERE proname IN ('validate_phone', 'validate_state_code', 'calculate_profile_completion', 'get_ffa_degree_progress')
UNION ALL
SELECT 
    'Views' as object_type,
    COUNT(*) as count
FROM information_schema.views 
WHERE table_schema = 'public' 
AND table_name IN ('user_profile_summary', 'ffa_degree_progress_view');