-- ============================================================================
-- APPLY THIS MIGRATION IN SUPABASE SQL EDITOR
-- ============================================================================
-- Instructions:
-- 1. Open Supabase Dashboard (https://supabase.com/dashboard)
-- 2. Navigate to your project
-- 3. Go to SQL Editor
-- 4. Create a new query
-- 5. Copy this entire file and paste it
-- 6. Click "Run" to execute
-- ============================================================================

-- First, let's check the current state
DO $$
BEGIN
    RAISE NOTICE 'Starting Enhanced User Profiles Migration...';
    RAISE NOTICE 'Checking current database state...';
END $$;

-- Check if migration already applied
SELECT 
    EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profiles' 
        AND column_name = 'bio'
    ) as bio_exists,
    EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'ffa_chapters'
    ) as ffa_chapters_exists,
    EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'skills_catalog'
    ) as skills_catalog_exists;

-- ============================================================================
-- MAIN MIGRATION (Part 1: Schema Changes)
-- ============================================================================

-- Add new columns to user_profiles (safe with IF NOT EXISTS)
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

-- Create FFA chapters table
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

-- Create FFA degrees table
CREATE TABLE IF NOT EXISTS ffa_degrees (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  degree_name VARCHAR(50) NOT NULL UNIQUE,
  degree_level INTEGER NOT NULL,
  requirements JSONB DEFAULT '[]',
  prerequisites JSONB DEFAULT '[]',
  description TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create user FFA progress table
CREATE TABLE IF NOT EXISTS user_ffa_progress (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  degree_id UUID REFERENCES ffa_degrees(id) ON DELETE CASCADE NOT NULL,
  progress_percentage DECIMAL(5,2) DEFAULT 0.00,
  requirements_met JSONB DEFAULT '[]',
  requirements_pending JSONB DEFAULT '[]',
  date_started DATE DEFAULT CURRENT_DATE,
  date_completed DATE,
  verification_status VARCHAR(50) DEFAULT 'in_progress',
  verified_by UUID REFERENCES auth.users(id),
  verification_date TIMESTAMP WITH TIME ZONE,
  notes TEXT,
  evidence_files JSONB DEFAULT '[]',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, degree_id)
);

-- Create skills catalog table
CREATE TABLE IF NOT EXISTS skills_catalog (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  skill_name VARCHAR(255) NOT NULL UNIQUE,
  category VARCHAR(100) NOT NULL,
  subcategory VARCHAR(100),
  description TEXT,
  certification_available BOOLEAN DEFAULT FALSE,
  certification_body VARCHAR(255),
  skill_level VARCHAR(50) DEFAULT 'beginner',
  prerequisites JSONB DEFAULT '[]',
  learning_resources JSONB DEFAULT '[]',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create user skills table
CREATE TABLE IF NOT EXISTS user_skills (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  skill_id UUID REFERENCES skills_catalog(id) ON DELETE CASCADE NOT NULL,
  proficiency_level VARCHAR(50) DEFAULT 'learning',
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

-- ============================================================================
-- VERIFICATION QUERY 1: Check Tables Created
-- ============================================================================

SELECT 
    'Tables Created' as check_type,
    COUNT(*) as tables_found,
    array_agg(table_name) as table_list
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('ffa_chapters', 'ffa_degrees', 'user_ffa_progress', 'skills_catalog', 'user_skills');