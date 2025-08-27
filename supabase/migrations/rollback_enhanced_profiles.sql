-- ============================================================================
-- ROLLBACK SCRIPT FOR ENHANCED USER PROFILES MIGRATION
-- ============================================================================
-- ONLY RUN THIS IF YOU NEED TO UNDO THE MIGRATION
-- WARNING: This will remove all data in the new tables!

-- Confirm before running
DO $$
BEGIN
    RAISE NOTICE '⚠️  WARNING: This will rollback the enhanced profiles migration!';
    RAISE NOTICE '⚠️  All data in new tables will be lost!';
    RAISE NOTICE '⚠️  Only proceed if you need to undo the migration.';
END $$;

-- Start rollback transaction
BEGIN;

-- 1. Drop views
DROP VIEW IF EXISTS user_profile_summary CASCADE;
DROP VIEW IF EXISTS ffa_degree_progress_view CASCADE;
DROP VIEW IF EXISTS user_skills_summary CASCADE;

-- 2. Drop functions
DROP FUNCTION IF EXISTS calculate_profile_completion(UUID) CASCADE;
DROP FUNCTION IF EXISTS get_ffa_degree_progress(UUID) CASCADE;
DROP FUNCTION IF EXISTS suggest_next_ffa_degree(UUID) CASCADE;
DROP FUNCTION IF EXISTS validate_phone(TEXT) CASCADE;
DROP FUNCTION IF EXISTS validate_state_code(TEXT) CASCADE;
DROP FUNCTION IF EXISTS validate_ffa_degree(TEXT) CASCADE;
DROP FUNCTION IF EXISTS update_ffa_progress() CASCADE;

-- 3. Drop triggers
DROP TRIGGER IF EXISTS trigger_update_ffa_progress ON user_ffa_progress;

-- 4. Drop foreign key constraints and tables (in correct order)
DROP TABLE IF EXISTS user_skills CASCADE;
DROP TABLE IF EXISTS skills_catalog CASCADE;
DROP TABLE IF EXISTS user_ffa_progress CASCADE;
DROP TABLE IF EXISTS ffa_degrees CASCADE;
DROP TABLE IF EXISTS ffa_chapters CASCADE;

-- 5. Remove new columns from user_profiles
-- Note: This will permanently delete any data in these columns!
ALTER TABLE user_profiles 
  DROP COLUMN IF EXISTS bio,
  DROP COLUMN IF EXISTS phone,
  DROP COLUMN IF EXISTS ffa_chapter,
  DROP COLUMN IF EXISTS ffa_degree,
  DROP COLUMN IF EXISTS ffa_state,
  DROP COLUMN IF EXISTS member_since,
  DROP COLUMN IF EXISTS profile_image_url,
  DROP COLUMN IF EXISTS address,
  DROP COLUMN IF EXISTS emergency_contact,
  DROP COLUMN IF EXISTS educational_info,
  DROP COLUMN IF EXISTS preferences,
  DROP COLUMN IF EXISTS social_links,
  DROP COLUMN IF EXISTS achievements,
  DROP COLUMN IF EXISTS skills_certifications;

-- 6. Drop constraints that were added
ALTER TABLE user_profiles 
  DROP CONSTRAINT IF EXISTS valid_phone_format,
  DROP CONSTRAINT IF EXISTS valid_state_code,
  DROP CONSTRAINT IF EXISTS valid_bio_length,
  DROP CONSTRAINT IF EXISTS valid_member_since;

-- 7. Remove any security config entries
DELETE FROM security_config WHERE key IN ('schema_version', 'migration_date', 'profile_fields_count');

-- 8. Remove audit log entry for this migration
DELETE FROM security_audit_log WHERE event_type = 'profile_enhancement_migration';

-- Commit the rollback
COMMIT;

-- Verify rollback
SELECT 
    'ROLLBACK STATUS' as status,
    CASE 
        WHEN NOT EXISTS(
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'user_profiles' AND column_name = 'bio'
        ) 
        AND NOT EXISTS(
            SELECT 1 FROM information_schema.tables 
            WHERE table_name = 'ffa_chapters'
        )
        THEN '✅ Rollback completed successfully'
        ELSE '⚠️  Rollback may be incomplete - check manually'
    END as result,
    NOW() as rolled_back_at;