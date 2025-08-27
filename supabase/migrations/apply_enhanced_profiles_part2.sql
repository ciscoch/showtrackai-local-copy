-- ============================================================================
-- PART 2: INDEXES AND SAMPLE DATA
-- ============================================================================
-- Run this after Part 1 is successful

-- Create all necessary indexes
CREATE INDEX IF NOT EXISTS idx_ffa_chapters_state ON ffa_chapters(state_code);
CREATE INDEX IF NOT EXISTS idx_ffa_chapters_active ON ffa_chapters(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_ffa_chapters_name ON ffa_chapters(chapter_name);
CREATE INDEX IF NOT EXISTS idx_user_ffa_progress_user ON user_ffa_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_user_ffa_progress_degree ON user_ffa_progress(degree_id);
CREATE INDEX IF NOT EXISTS idx_user_ffa_progress_status ON user_ffa_progress(verification_status);
CREATE INDEX IF NOT EXISTS idx_skills_catalog_category ON skills_catalog(category, subcategory);
CREATE INDEX IF NOT EXISTS idx_user_skills_user ON user_skills(user_id);
CREATE INDEX IF NOT EXISTS idx_user_skills_proficiency ON user_skills(proficiency_level);
CREATE INDEX IF NOT EXISTS idx_user_skills_certification ON user_skills(certification_earned) WHERE certification_earned = TRUE;
CREATE INDEX IF NOT EXISTS idx_user_profiles_ffa_chapter ON user_profiles(ffa_chapter);
CREATE INDEX IF NOT EXISTS idx_user_profiles_ffa_state ON user_profiles(ffa_state);
CREATE INDEX IF NOT EXISTS idx_user_profiles_ffa_degree ON user_profiles(ffa_degree);
CREATE INDEX IF NOT EXISTS idx_user_profiles_member_since ON user_profiles(member_since);

-- Insert FFA degrees
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

-- Insert sample FFA chapters
INSERT INTO ffa_chapters (chapter_name, state_code, school_name, advisor_email) VALUES
  ('Lincoln FFA', 'NE', 'Lincoln High School', 'advisor@lincolnffa.org'),
  ('Valley View FFA', 'CA', 'Valley View High School', 'advisor@valleyviewffa.org'),
  ('Prairie Plains FFA', 'KS', 'Prairie Plains High School', 'advisor@prairieplainsffa.org'),
  ('Oak Ridge FFA', 'TN', 'Oak Ridge High School', 'advisor@oakridgeffa.org'),
  ('Cedar Creek FFA', 'TX', 'Cedar Creek High School', 'advisor@cedarcreekffa.org')
ON CONFLICT (chapter_name, state_code) DO NOTHING;

-- Insert agricultural skills
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
-- VERIFICATION QUERY 2: Check Data Inserted
-- ============================================================================

SELECT 
    'FFA Degrees' as data_type,
    COUNT(*) as count
FROM ffa_degrees
UNION ALL
SELECT 
    'FFA Chapters' as data_type,
    COUNT(*) as count
FROM ffa_chapters
UNION ALL
SELECT 
    'Skills Catalog' as data_type,
    COUNT(*) as count
FROM skills_catalog;