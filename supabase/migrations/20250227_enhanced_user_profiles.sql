-- ============================================================================
-- ShowTrackAI Enhanced User Profile System Migration
-- Version: 3.0
-- Date: 2025-02-27
-- Description: Adds comprehensive user profile fields including bio, phone, 
--              FFA information, and enhanced educational tracking
-- ============================================================================

-- Start transaction for atomic execution
BEGIN;

-- ============================================================================
-- SECTION 1: Enhanced User Profiles Schema
-- ============================================================================

-- Add new fields to user_profiles table
ALTER TABLE user_profiles 
  ADD COLUMN IF NOT EXISTS bio TEXT,
  ADD COLUMN IF NOT EXISTS phone VARCHAR(20),
  ADD COLUMN IF NOT EXISTS ffa_chapter VARCHAR(255),
  ADD COLUMN IF NOT EXISTS ffa_degree VARCHAR(50),
  ADD COLUMN IF NOT EXISTS ffa_state VARCHAR(2),
  ADD COLUMN IF NOT EXISTS member_since DATE,
  ADD COLUMN IF NOT EXISTS profile_image_url TEXT,
  ADD COLUMN IF NOT EXISTS address JSONB DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS emergency_contact JSONB DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS educational_info JSONB DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS preferences JSONB DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS social_links JSONB DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS achievements JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS skills_certifications JSONB DEFAULT '[]';

-- ============================================================================
-- SECTION 2: FFA Degree and Chapter Management
-- ============================================================================

-- Create FFA chapters reference table for data integrity
CREATE TABLE IF NOT EXISTS ffa_chapters (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  chapter_name VARCHAR(255) NOT NULL,
  chapter_number VARCHAR(10),
  state_code VARCHAR(2) NOT NULL,
  district VARCHAR(100),
  advisor_name VARCHAR(255),
  advisor_email TEXT,
  school_name VARCHAR(255) NOT NULL,
  address JSONB DEFAULT '{}',
  contact_info JSONB DEFAULT '{}',
  charter_date DATE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(chapter_name, state_code)
);

-- Create index for FFA chapters
CREATE INDEX IF NOT EXISTS idx_ffa_chapters_state ON ffa_chapters(state_code);
CREATE INDEX IF NOT EXISTS idx_ffa_chapters_active ON ffa_chapters(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_ffa_chapters_name ON ffa_chapters(chapter_name);

-- Create FFA degrees reference table
CREATE TABLE IF NOT EXISTS ffa_degrees (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  degree_name VARCHAR(50) NOT NULL UNIQUE,
  degree_level INTEGER NOT NULL, -- 1=Discovery, 2=Greenhand, 3=Chapter, 4=State, 5=American
  requirements JSONB DEFAULT '[]',
  prerequisites JSONB DEFAULT '[]',
  description TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert standard FFA degrees
INSERT INTO ffa_degrees (degree_name, degree_level, description, requirements) VALUES
  ('Discovery FFA Degree', 1, 'For students in grades 7-8 enrolled in an agricultural education course', 
   '["Be enrolled in an agricultural education course", "Demonstrate knowledge of FFA history", "Submit written application"]'::jsonb),
  ('Greenhand FFA Degree', 2, 'For first-year agriculture students', 
   '["Enroll in agricultural education course", "Learn and explain FFA Creed", "Describe FFA history", "Know opportunities in agricultural career", "Submit Supervised Agricultural Experience (SAE) plan"]'::jsonb),
  ('Chapter FFA Degree', 3, 'Earned at the local chapter level', 
   '["Have Greenhand Degree", "Complete 180 hours of instruction", "Have satisfactory SAE", "Participate in chapter activities", "Lead a group discussion", "Complete 10 hours of community service"]'::jsonb),
  ('State FFA Degree', 4, 'Highest degree earned at the state level', 
   '["Have Chapter Degree", "Complete 2 years of instruction", "Have productive SAE worth $1000", "Earn and invest $150", "Participate in state activities", "Complete 25 hours of community service"]'::jsonb),
  ('American FFA Degree', 5, 'Highest degree in the National FFA Organization', 
   '["Have State Degree", "Complete 3 years of instruction", "Graduate from high school", "Have productive SAE worth $7500", "Earn and invest $1000", "Complete 50 hours of community service", "Demonstrate outstanding leadership"]'::jsonb)
ON CONFLICT (degree_name) DO NOTHING;

-- ============================================================================
-- SECTION 3: User Progress Tracking
-- ============================================================================

-- Create user FFA progress tracking table
CREATE TABLE IF NOT EXISTS user_ffa_progress (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  degree_id UUID REFERENCES ffa_degrees(id) ON DELETE CASCADE NOT NULL,
  progress_percentage DECIMAL(5,2) DEFAULT 0.00,
  requirements_met JSONB DEFAULT '[]',
  requirements_pending JSONB DEFAULT '[]',
  date_started DATE DEFAULT CURRENT_DATE,
  date_completed DATE,
  verification_status VARCHAR(50) DEFAULT 'in_progress', -- in_progress, submitted, verified, awarded
  verified_by UUID REFERENCES auth.users(id),
  verification_date TIMESTAMP WITH TIME ZONE,
  notes TEXT,
  evidence_files JSONB DEFAULT '[]',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, degree_id)
);

-- Create indexes for FFA progress tracking
CREATE INDEX IF NOT EXISTS idx_user_ffa_progress_user ON user_ffa_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_user_ffa_progress_degree ON user_ffa_progress(degree_id);
CREATE INDEX IF NOT EXISTS idx_user_ffa_progress_status ON user_ffa_progress(verification_status);

-- ============================================================================
-- SECTION 4: User Skills and Certifications
-- ============================================================================

-- Create skills catalog table
CREATE TABLE IF NOT EXISTS skills_catalog (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  skill_name VARCHAR(255) NOT NULL UNIQUE,
  category VARCHAR(100) NOT NULL, -- animal_science, plant_science, agricultural_mechanics, etc.
  subcategory VARCHAR(100),
  description TEXT,
  certification_available BOOLEAN DEFAULT FALSE,
  certification_body VARCHAR(255),
  skill_level VARCHAR(50) DEFAULT 'beginner', -- beginner, intermediate, advanced, expert
  prerequisites JSONB DEFAULT '[]',
  learning_resources JSONB DEFAULT '[]',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create user skills tracking
CREATE TABLE IF NOT EXISTS user_skills (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  skill_id UUID REFERENCES skills_catalog(id) ON DELETE CASCADE NOT NULL,
  proficiency_level VARCHAR(50) DEFAULT 'learning', -- learning, developing, proficient, expert
  date_acquired DATE DEFAULT CURRENT_DATE,
  certification_earned BOOLEAN DEFAULT FALSE,
  certification_date DATE,
  certification_number VARCHAR(255),
  certification_expiry DATE,
  verified_by UUID REFERENCES auth.users(id),
  verification_date TIMESTAMP WITH TIME ZONE,
  evidence_files JSONB DEFAULT '[]',
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, skill_id)
);

-- Create indexes for skills
CREATE INDEX IF NOT EXISTS idx_skills_catalog_category ON skills_catalog(category, subcategory);
CREATE INDEX IF NOT EXISTS idx_user_skills_user ON user_skills(user_id);
CREATE INDEX IF NOT EXISTS idx_user_skills_proficiency ON user_skills(proficiency_level);
CREATE INDEX IF NOT EXISTS idx_user_skills_certification ON user_skills(certification_earned) WHERE certification_earned = TRUE;

-- ============================================================================
-- SECTION 5: Enhanced Validation Functions
-- ============================================================================

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

-- Function to validate FFA degree
CREATE OR REPLACE FUNCTION validate_ffa_degree(degree_name TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM ffa_degrees 
    WHERE degree_name = validate_ffa_degree.degree_name 
    AND is_active = TRUE
  );
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- SECTION 6: Add Constraints and Validation
-- ============================================================================

-- Add check constraints for new fields
ALTER TABLE user_profiles 
  ADD CONSTRAINT valid_phone_format 
    CHECK (phone IS NULL OR validate_phone(phone)),
  ADD CONSTRAINT valid_state_code 
    CHECK (ffa_state IS NULL OR validate_state_code(ffa_state)),
  ADD CONSTRAINT valid_bio_length 
    CHECK (LENGTH(bio) <= 1000),
  ADD CONSTRAINT valid_member_since 
    CHECK (member_since IS NULL OR member_since <= CURRENT_DATE);

-- Add constraint for FFA degree validation
-- (This will be added after initial data cleanup)

-- ============================================================================
-- SECTION 7: Enhanced RLS Policies
-- ============================================================================

-- Enable RLS on new tables
ALTER TABLE ffa_chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE ffa_degrees ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_ffa_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE skills_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_skills ENABLE ROW LEVEL SECURITY;

-- Policies for ffa_chapters (public read, admin write)
CREATE POLICY "ffa_chapters_select_policy" ON ffa_chapters FOR SELECT
  USING (TRUE); -- Chapters are public information

CREATE POLICY "ffa_chapters_admin_only" ON ffa_chapters 
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() 
      AND user_role IN ('admin', 'educator')
    )
  );

-- Policies for ffa_degrees (public read)
CREATE POLICY "ffa_degrees_select_policy" ON ffa_degrees FOR SELECT
  USING (is_active = TRUE);

-- Policies for user_ffa_progress (user owns their progress)
CREATE POLICY "user_ffa_progress_select_policy" ON user_ffa_progress FOR SELECT
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() 
      AND user_role IN ('admin', 'educator')
    )
  );

CREATE POLICY "user_ffa_progress_insert_policy" ON user_ffa_progress FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_ffa_progress_update_policy" ON user_ffa_progress FOR UPDATE
  USING (
    auth.uid() = user_id
    OR (
      EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() 
        AND user_role IN ('admin', 'educator')
      )
      AND verification_status = 'submitted' -- Educators can verify submitted work
    )
  );

-- Policies for skills_catalog (public read, admin write)
CREATE POLICY "skills_catalog_select_policy" ON skills_catalog FOR SELECT
  USING (is_active = TRUE);

CREATE POLICY "skills_catalog_admin_only" ON skills_catalog 
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() 
      AND user_role IN ('admin', 'educator')
    )
  );

-- Policies for user_skills (user owns their skills)
CREATE POLICY "user_skills_select_policy" ON user_skills FOR SELECT
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() 
      AND user_role IN ('admin', 'educator')
    )
  );

CREATE POLICY "user_skills_insert_policy" ON user_skills FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_skills_update_policy" ON user_skills FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "user_skills_delete_policy" ON user_skills FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- SECTION 8: Profile Completion and Helper Functions
-- ============================================================================

-- Function to calculate profile completion percentage
CREATE OR REPLACE FUNCTION calculate_profile_completion(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_total_fields INTEGER := 15; -- Total number of profile fields
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
  IF COALESCE(jsonb_array_length(v_profile.address->'street'), 0) > 0 THEN v_completed_fields := v_completed_fields + 1; END IF;
  IF COALESCE(jsonb_array_length(v_profile.emergency_contact->'name'), 0) > 0 THEN v_completed_fields := v_completed_fields + 1; END IF;
  IF COALESCE(jsonb_array_length(v_profile.educational_info->'school'), 0) > 0 THEN v_completed_fields := v_completed_fields + 1; END IF;
  IF COALESCE(jsonb_array_length(v_profile.achievements), 0) > 0 THEN v_completed_fields := v_completed_fields + 1; END IF;
  IF COALESCE(jsonb_array_length(v_profile.skills_certifications), 0) > 0 THEN v_completed_fields := v_completed_fields + 1; END IF;
  IF COALESCE(jsonb_array_length(v_profile.social_links->'website'), 0) > 0 THEN v_completed_fields := v_completed_fields + 1; END IF;
  
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

-- Function to suggest next FFA degree
CREATE OR REPLACE FUNCTION suggest_next_ffa_degree(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_current_max_level INTEGER;
  v_next_degree JSONB;
BEGIN
  -- Get the highest degree level user has completed or is working on
  SELECT COALESCE(MAX(fd.degree_level), 0) INTO v_current_max_level
  FROM user_ffa_progress ufp
  JOIN ffa_degrees fd ON fd.id = ufp.degree_id
  WHERE ufp.user_id = p_user_id
  AND ufp.verification_status IN ('verified', 'awarded');
  
  -- Get next degree
  SELECT jsonb_build_object(
    'degree_name', degree_name,
    'degree_level', degree_level,
    'description', description,
    'requirements', requirements,
    'prerequisites', prerequisites
  ) INTO v_next_degree
  FROM ffa_degrees
  WHERE degree_level = v_current_max_level + 1
  AND is_active = TRUE;
  
  RETURN v_next_degree;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================================
-- SECTION 9: Data Migration and Cleanup
-- ============================================================================

-- Update existing profiles to set default values for new fields
UPDATE user_profiles SET
  bio = CASE 
    WHEN bio IS NULL THEN '' 
    ELSE bio 
  END,
  address = CASE 
    WHEN address IS NULL THEN '{}'::jsonb 
    ELSE address 
  END,
  emergency_contact = CASE 
    WHEN emergency_contact IS NULL THEN '{}'::jsonb 
    ELSE emergency_contact 
  END,
  educational_info = CASE 
    WHEN educational_info IS NULL THEN '{}'::jsonb 
    ELSE educational_info 
  END,
  preferences = CASE 
    WHEN preferences IS NULL THEN '{}'::jsonb 
    ELSE preferences 
  END,
  social_links = CASE 
    WHEN social_links IS NULL THEN '{}'::jsonb 
    ELSE social_links 
  END,
  achievements = CASE 
    WHEN achievements IS NULL THEN '[]'::jsonb 
    ELSE achievements 
  END,
  skills_certifications = CASE 
    WHEN skills_certifications IS NULL THEN '[]'::jsonb 
    ELSE skills_certifications 
  END
WHERE bio IS NULL 
   OR address IS NULL 
   OR emergency_contact IS NULL 
   OR educational_info IS NULL 
   OR preferences IS NULL 
   OR social_links IS NULL 
   OR achievements IS NULL 
   OR skills_certifications IS NULL;

-- ============================================================================
-- SECTION 10: Sample FFA Chapters and Skills Data
-- ============================================================================

-- Insert sample FFA chapters (these should be replaced with real data)
INSERT INTO ffa_chapters (chapter_name, state_code, school_name, advisor_email) VALUES
  ('Lincoln FFA', 'NE', 'Lincoln High School', 'advisor@lincolnffa.org'),
  ('Valley View FFA', 'CA', 'Valley View High School', 'advisor@valleyviewffa.org'),
  ('Prairie Plains FFA', 'KS', 'Prairie Plains High School', 'advisor@prairieplainsffa.org'),
  ('Oak Ridge FFA', 'TN', 'Oak Ridge High School', 'advisor@oakridgeffa.org'),
  ('Cedar Creek FFA', 'TX', 'Cedar Creek High School', 'advisor@cedarcreekffa.org')
ON CONFLICT (chapter_name, state_code) DO NOTHING;

-- Insert common agricultural skills
INSERT INTO skills_catalog (skill_name, category, subcategory, description, certification_available) VALUES
  ('Animal Handling', 'animal_science', 'livestock_management', 'Safe and effective handling of various livestock species', true),
  ('Feed Ration Calculation', 'animal_science', 'nutrition', 'Calculating proper feed rations for optimal animal growth', false),
  ('Vaccination Administration', 'animal_science', 'health_management', 'Proper techniques for administering vaccines to livestock', true),
  ('Welding - MIG', 'agricultural_mechanics', 'welding', 'Metal Inert Gas welding techniques for agricultural applications', true),
  ('Small Engine Repair', 'agricultural_mechanics', 'engines', 'Diagnosis and repair of small engines used in agriculture', true),
  ('Soil Testing', 'plant_science', 'soil_management', 'Conducting and interpreting soil tests for crop production', false),
  ('Crop Identification', 'plant_science', 'crops', 'Identification of common agricultural crops and varieties', false),
  ('Record Keeping', 'business_management', 'finance', 'Maintaining accurate records for agricultural enterprises', false),
  ('Public Speaking', 'leadership', 'communication', 'Effective public speaking and presentation skills', true),
  ('Parliamentary Procedure', 'leadership', 'governance', 'Knowledge and application of parliamentary procedure', true)
ON CONFLICT (skill_name) DO NOTHING;

-- ============================================================================
-- SECTION 11: Triggers for Automatic Updates
-- ============================================================================

-- Trigger to automatically update FFA degree progress
CREATE OR REPLACE FUNCTION update_ffa_progress()
RETURNS TRIGGER AS $$
BEGIN
  -- Update the user's current FFA degree in their profile
  IF NEW.verification_status = 'awarded' THEN
    UPDATE user_profiles 
    SET ffa_degree = (
      SELECT degree_name 
      FROM ffa_degrees 
      WHERE id = NEW.degree_id
    )
    WHERE id = NEW.user_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for FFA progress updates
DROP TRIGGER IF EXISTS trigger_update_ffa_progress ON user_ffa_progress;
CREATE TRIGGER trigger_update_ffa_progress
  AFTER UPDATE ON user_ffa_progress
  FOR EACH ROW
  WHEN (NEW.verification_status = 'awarded' AND OLD.verification_status != 'awarded')
  EXECUTE FUNCTION update_ffa_progress();

-- ============================================================================
-- SECTION 12: Indexes for Performance Optimization
-- ============================================================================

-- Enhanced indexes for user_profiles
CREATE INDEX IF NOT EXISTS idx_user_profiles_ffa_chapter ON user_profiles(ffa_chapter);
CREATE INDEX IF NOT EXISTS idx_user_profiles_ffa_state ON user_profiles(ffa_state);
CREATE INDEX IF NOT EXISTS idx_user_profiles_ffa_degree ON user_profiles(ffa_degree);
CREATE INDEX IF NOT EXISTS idx_user_profiles_member_since ON user_profiles(member_since);

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_user_profiles_state_chapter ON user_profiles(ffa_state, ffa_chapter);
CREATE INDEX IF NOT EXISTS idx_user_profiles_degree_state ON user_profiles(ffa_degree, ffa_state);

-- GIN indexes for JSONB fields for better search performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_address_gin ON user_profiles USING gin(address);
CREATE INDEX IF NOT EXISTS idx_user_profiles_educational_gin ON user_profiles USING gin(educational_info);
CREATE INDEX IF NOT EXISTS idx_user_profiles_achievements_gin ON user_profiles USING gin(achievements);
CREATE INDEX IF NOT EXISTS idx_user_profiles_skills_gin ON user_profiles USING gin(skills_certifications);

-- ============================================================================
-- SECTION 13: Views for Easy Querying
-- ============================================================================

-- View for user profile summary
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

-- View for skills summary by category
CREATE OR REPLACE VIEW user_skills_summary AS
SELECT 
  us.user_id,
  up.email,
  sc.category,
  COUNT(*) as total_skills,
  COUNT(CASE WHEN us.certification_earned THEN 1 END) as certified_skills,
  AVG(CASE 
    WHEN us.proficiency_level = 'learning' THEN 1
    WHEN us.proficiency_level = 'developing' THEN 2
    WHEN us.proficiency_level = 'proficient' THEN 3
    WHEN us.proficiency_level = 'expert' THEN 4
    ELSE 0
  END) as avg_proficiency_score
FROM user_skills us
JOIN skills_catalog sc ON sc.id = us.skill_id
JOIN user_profiles up ON up.id = us.user_id
GROUP BY us.user_id, up.email, sc.category
ORDER BY up.email, sc.category;

-- ============================================================================
-- SECTION 14: Grant Permissions
-- ============================================================================

-- Grant permissions on new tables
GRANT SELECT, INSERT, UPDATE, DELETE ON ffa_chapters TO authenticated;
GRANT SELECT ON ffa_degrees TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON user_ffa_progress TO authenticated;
GRANT SELECT ON skills_catalog TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON user_skills TO authenticated;

-- Grant permissions on sequences
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant execute permissions on new functions
GRANT EXECUTE ON FUNCTION validate_phone TO authenticated;
GRANT EXECUTE ON FUNCTION validate_state_code TO authenticated;
GRANT EXECUTE ON FUNCTION validate_ffa_degree TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_profile_completion TO authenticated;
GRANT EXECUTE ON FUNCTION get_ffa_degree_progress TO authenticated;
GRANT EXECUTE ON FUNCTION suggest_next_ffa_degree TO authenticated;

-- Grant select permissions on views
GRANT SELECT ON user_profile_summary TO authenticated;
GRANT SELECT ON ffa_degree_progress_view TO authenticated;
GRANT SELECT ON user_skills_summary TO authenticated;

-- ============================================================================
-- SECTION 15: Clean up and Optimize
-- ============================================================================

-- Analyze tables for optimal query performance
ANALYZE user_profiles;
ANALYZE ffa_chapters;
ANALYZE ffa_degrees;
ANALYZE user_ffa_progress;
ANALYZE skills_catalog;
ANALYZE user_skills;

-- ============================================================================
-- SECTION 16: Migration Completion
-- ============================================================================

-- Update schema version
INSERT INTO security_config (key, value, description) VALUES
  ('schema_version', '3.0', 'Enhanced user profiles with FFA tracking'),
  ('migration_date', NOW()::TEXT, 'Last migration date'),
  ('profile_fields_count', '15', 'Number of profile completion fields')
ON CONFLICT (key) DO UPDATE SET 
  value = EXCLUDED.value,
  updated_at = NOW();

-- Log successful migration
INSERT INTO security_audit_log (
  event_type,
  user_id,
  action,
  success,
  metadata
) VALUES (
  'profile_enhancement_migration',
  NULL,
  'migration_complete',
  TRUE,
  jsonb_build_object(
    'version', '3.0',
    'migration_date', NOW(),
    'description', 'Enhanced user profiles with FFA degree tracking and skills management'
  )
);

-- Commit the transaction
COMMIT;

-- ============================================================================
-- POST-MIGRATION VERIFICATION QUERIES
-- Execute these to verify the migration was successful
-- ============================================================================

/*
-- Verify new columns exist
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check new tables were created
SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('ffa_chapters', 'ffa_degrees', 'user_ffa_progress', 'skills_catalog', 'user_skills');

-- Verify sample data inserted
SELECT COUNT(*) as ffa_chapters_count FROM ffa_chapters;
SELECT COUNT(*) as ffa_degrees_count FROM ffa_degrees;
SELECT COUNT(*) as skills_count FROM skills_catalog;

-- Test profile completion function
SELECT calculate_profile_completion(id) as completion_percentage 
FROM user_profiles 
LIMIT 5;

-- Verify RLS policies
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename IN ('ffa_chapters', 'ffa_degrees', 'user_ffa_progress', 'skills_catalog', 'user_skills')
ORDER BY tablename, policyname;

-- Check indexes
SELECT schemaname, tablename, indexname 
FROM pg_indexes 
WHERE schemaname = 'public' 
AND tablename IN ('user_profiles', 'ffa_chapters', 'user_ffa_progress', 'user_skills')
ORDER BY tablename, indexname;

-- Verify views
SELECT table_name, view_definition 
FROM information_schema.views 
WHERE table_schema = 'public' 
AND table_name LIKE '%profile%' OR table_name LIKE '%ffa%' OR table_name LIKE '%skills%';
*/