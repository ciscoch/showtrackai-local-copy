# Enhanced User Profiles Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the Enhanced User Profiles system to ShowTrackAI. The migration includes new database fields, tables, security policies, and comprehensive FFA degree tracking.

## Pre-Deployment Checklist

### 1. Database Backup
**CRITICAL**: Always backup your database before running migrations.

```sql
-- In Supabase SQL Editor, verify current state
SELECT 
  COUNT(*) as user_count,
  MIN(created_at) as oldest_user,
  MAX(created_at) as newest_user
FROM user_profiles;

-- Backup current user_profiles structure
CREATE TABLE user_profiles_backup_20250227 AS 
SELECT * FROM user_profiles;
```

### 2. Verify Prerequisites
- [ ] Supabase project is accessible
- [ ] You have admin access to SQL Editor
- [ ] Current schema version is compatible (check security_config table)
- [ ] No active long-running queries

### 3. Environment Preparation
- [ ] Schedule maintenance window (recommended 30 minutes)
- [ ] Notify users of potential downtime
- [ ] Prepare rollback plan if needed

## Deployment Steps

### Step 1: Execute Migration Script

1. **Open Supabase Dashboard**
   - Navigate to your ShowTrackAI project
   - Go to SQL Editor

2. **Load Migration Script**
   - Copy the entire contents of `20250227_enhanced_user_profiles.sql`
   - Paste into a new SQL Editor query

3. **Execute Migration**
   ```sql
   -- The migration runs in a single transaction
   -- Either all changes succeed or all are rolled back
   ```

4. **Monitor Execution**
   - Watch for any error messages
   - Typical execution time: 2-5 minutes
   - Look for "COMMIT" at the end confirming success

### Step 2: Post-Migration Verification

Execute these verification queries immediately after migration:

```sql
-- 1. Verify new columns exist
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
AND table_schema = 'public'
AND column_name IN ('bio', 'phone', 'ffa_chapter', 'ffa_degree', 'ffa_state', 'member_since')
ORDER BY column_name;

-- Expected: 6 rows showing the new columns

-- 2. Check new tables were created
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('ffa_chapters', 'ffa_degrees', 'user_ffa_progress', 'skills_catalog', 'user_skills');

-- Expected: 5 rows

-- 3. Verify sample data inserted
SELECT 'ffa_chapters' as table_name, COUNT(*) as count FROM ffa_chapters
UNION ALL
SELECT 'ffa_degrees', COUNT(*) FROM ffa_degrees  
UNION ALL  
SELECT 'skills_catalog', COUNT(*) FROM skills_catalog;

-- Expected: ffa_chapters=5, ffa_degrees=5, skills_catalog=10

-- 4. Test profile completion function
SELECT 
  email,
  calculate_profile_completion(id) as completion_percentage
FROM user_profiles 
LIMIT 3;

-- Expected: Returns completion percentages (likely 20-40% for existing users)

-- 5. Verify RLS policies are active
SELECT tablename, COUNT(*) as policy_count 
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename IN ('ffa_chapters', 'ffa_degrees', 'user_ffa_progress', 'skills_catalog', 'user_skills')
GROUP BY tablename;

-- Expected: Each table should have 1-4 policies

-- 6. Test new validation functions
SELECT 
  validate_phone('555-123-4567') as valid_phone,
  validate_state_code('NE') as valid_state,
  validate_phone('invalid') as invalid_phone,
  validate_state_code('XX') as invalid_state;

-- Expected: true, true, false, false
```

### Step 3: Frontend Integration Preparation

1. **Update API Endpoints**
   - Add new profile fields to existing GET/PUT endpoints
   - Implement FFA degree progress endpoints
   - Add skills management endpoints

2. **Update Frontend Components**
   - Modify profile forms to include new fields
   - Add profile completion widget
   - Create FFA degree progress tracker

3. **Update Mobile App (if applicable)**
   - Synchronize profile schema changes
   - Test offline/online sync with new fields

## Common Issues and Solutions

### Issue 1: Migration Timeout
**Symptoms**: Migration stops executing, no COMMIT message
**Solution**: 
```sql
-- Check if migration is still running
SELECT 
  pid,
  now() - pg_stat_activity.query_start AS duration,
  query 
FROM pg_stat_activity 
WHERE state = 'active';

-- If stuck, cancel and retry in smaller chunks
SELECT pg_cancel_backend(<pid_from_above>);
```

### Issue 2: Constraint Violations
**Symptoms**: Errors about duplicate keys or invalid data
**Solution**:
```sql
-- Check for existing conflicting data
SELECT email, COUNT(*) 
FROM user_profiles 
GROUP BY email 
HAVING COUNT(*) > 1;

-- Clean up duplicates before retrying migration
```

### Issue 3: RLS Policy Conflicts
**Symptoms**: Users can't access their own data after migration
**Solution**:
```sql
-- Verify RLS is working correctly
SET request.jwt.claim.sub = 'actual-user-uuid-here';
SELECT * FROM user_profiles WHERE id = 'actual-user-uuid-here';

-- If no results, check policy syntax
SELECT policyname, qual 
FROM pg_policies 
WHERE tablename = 'user_profiles' 
AND schemaname = 'public';
```

### Issue 4: Function Permission Errors
**Symptoms**: "permission denied for function" errors
**Solution**:
```sql
-- Re-grant function permissions
GRANT EXECUTE ON FUNCTION calculate_profile_completion TO authenticated;
GRANT EXECUTE ON FUNCTION validate_phone TO authenticated;
GRANT EXECUTE ON FUNCTION validate_state_code TO authenticated;
```

## Testing Procedures

### Database Testing

```sql
-- Test 1: Profile completion calculation
SELECT 
  id,
  email,
  calculate_profile_completion(id) as completion,
  -- Manual verification
  CASE WHEN email IS NOT NULL THEN 1 ELSE 0 END +
  CASE WHEN birth_date IS NOT NULL THEN 1 ELSE 0 END +
  CASE WHEN bio IS NOT NULL AND LENGTH(bio) > 0 THEN 1 ELSE 0 END as manual_count
FROM user_profiles 
LIMIT 5;

-- Test 2: FFA degree suggestion
UPDATE user_profiles 
SET ffa_degree = 'Greenhand FFA Degree' 
WHERE email = 'test@example.com';

SELECT suggest_next_ffa_degree(id) as suggested_degree
FROM user_profiles 
WHERE email = 'test@example.com';

-- Expected: Should suggest "Chapter FFA Degree"

-- Test 3: Skills catalog search
SELECT * FROM skills_catalog 
WHERE category = 'animal_science' 
AND skill_name ILIKE '%animal handling%';

-- Test 4: User skills tracking
INSERT INTO user_skills (user_id, skill_id, proficiency_level)
VALUES (
  (SELECT id FROM user_profiles WHERE email = 'test@example.com' LIMIT 1),
  (SELECT id FROM skills_catalog WHERE skill_name = 'Animal Handling' LIMIT 1),
  'developing'
);

SELECT * FROM user_skills_summary 
WHERE user_id = (SELECT id FROM user_profiles WHERE email = 'test@example.com');
```

### API Testing (after backend updates)

```bash
# Test profile retrieval with new fields
curl -X GET "http://localhost:3000/api/user/profile" \
  -H "Authorization: Bearer $JWT_TOKEN"

# Test profile update with new fields
curl -X PUT "http://localhost:3000/api/user/profile" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{
    "bio": "Test bio for migration verification",
    "phone": "555-123-4567",
    "ffa_chapter": "Lincoln FFA",
    "ffa_state": "NE",
    "member_since": "2023-08-15"
  }'

# Test FFA chapters search
curl -X GET "http://localhost:3000/api/ffa/chapters?state=NE" \
  -H "Authorization: Bearer $JWT_TOKEN"

# Test skills catalog
curl -X GET "http://localhost:3000/api/skills/catalog?category=animal_science" \
  -H "Authorization: Bearer $JWT_TOKEN"
```

## Performance Monitoring

After deployment, monitor these metrics:

### Database Performance
```sql
-- Query performance for profile completion
EXPLAIN ANALYZE 
SELECT calculate_profile_completion(id) 
FROM user_profiles 
LIMIT 10;

-- Index usage verification
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes 
WHERE tablename IN ('user_profiles', 'ffa_chapters', 'user_ffa_progress', 'user_skills')
ORDER BY tablename, indexname;

-- Table sizes after migration
SELECT 
  tablename,
  pg_size_pretty(pg_total_relation_size(tablename::regclass)) as size
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('user_profiles', 'ffa_chapters', 'ffa_degrees', 'user_ffa_progress', 'skills_catalog', 'user_skills')
ORDER BY pg_total_relation_size(tablename::regclass) DESC;
```

### Application Performance
- Monitor API response times for profile endpoints
- Track profile completion widget load times
- Monitor database connection pool usage
- Check for N+1 query problems in skills/FFA data loading

## Rollback Procedures

If critical issues arise, follow these rollback steps:

### Emergency Rollback (Database Only)
```sql
-- 1. Drop new tables (this will lose any new data!)
DROP TABLE IF EXISTS user_skills CASCADE;
DROP TABLE IF EXISTS user_ffa_progress CASCADE;
DROP TABLE IF EXISTS skills_catalog CASCADE;
DROP TABLE IF EXISTS ffa_degrees CASCADE;
DROP TABLE IF EXISTS ffa_chapters CASCADE;

-- 2. Remove new columns from user_profiles
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

-- 3. Drop new functions
DROP FUNCTION IF EXISTS calculate_profile_completion;
DROP FUNCTION IF EXISTS get_ffa_degree_progress;
DROP FUNCTION IF EXISTS suggest_next_ffa_degree;
DROP FUNCTION IF EXISTS validate_phone;
DROP FUNCTION IF EXISTS validate_state_code;
DROP FUNCTION IF EXISTS validate_ffa_degree;

-- 4. Drop new views
DROP VIEW IF EXISTS user_profile_summary CASCADE;
DROP VIEW IF EXISTS ffa_degree_progress_view CASCADE;  
DROP VIEW IF EXISTS user_skills_summary CASCADE;
```

### Partial Rollback (Keep Data, Remove Features)
```sql
-- Keep tables and data but disable features
UPDATE security_config 
SET value = 'false' 
WHERE key IN ('enhanced_profiles_enabled', 'ffa_tracking_enabled', 'skills_tracking_enabled');

-- Disable new RLS policies temporarily
ALTER TABLE user_ffa_progress DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_skills DISABLE ROW LEVEL SECURITY;
```

## Post-Deployment Tasks

### 1. Data Population (Optional)
```sql
-- Populate additional FFA chapters from official data
-- Add more skills to the catalog based on curriculum
-- Import existing user achievements if available

-- Example: Bulk chapter import
INSERT INTO ffa_chapters (chapter_name, state_code, school_name)
SELECT DISTINCT 
  ffa_chapter,
  ffa_state,
  educational_info->>'school'
FROM user_profiles 
WHERE ffa_chapter IS NOT NULL 
  AND ffa_state IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM ffa_chapters fc 
    WHERE fc.chapter_name = user_profiles.ffa_chapter 
    AND fc.state_code = user_profiles.ffa_state
  );
```

### 2. User Communication
- Send email to users about new profile features
- Update help documentation
- Create tutorial videos for FFA degree tracking
- Announce new features in app notifications

### 3. Analytics Setup
```sql
-- Create views for analytics
CREATE VIEW profile_completion_analytics AS
SELECT 
  ffa_state,
  AVG(calculate_profile_completion(id)) as avg_completion,
  COUNT(*) as user_count,
  COUNT(CASE WHEN calculate_profile_completion(id) >= 80 THEN 1 END) as complete_profiles
FROM user_profiles 
GROUP BY ffa_state
ORDER BY avg_completion DESC;

-- Track feature adoption
CREATE VIEW feature_adoption_analytics AS
SELECT 
  COUNT(CASE WHEN bio IS NOT NULL AND LENGTH(bio) > 0 THEN 1 END) as bio_users,
  COUNT(CASE WHEN phone IS NOT NULL THEN 1 END) as phone_users,
  COUNT(CASE WHEN ffa_chapter IS NOT NULL THEN 1 END) as chapter_users,
  COUNT(CASE WHEN member_since IS NOT NULL THEN 1 END) as member_date_users,
  COUNT(*) as total_users
FROM user_profiles;
```

### 4. Monitoring Setup
- Set up alerts for migration-related errors
- Monitor new endpoint performance
- Track profile completion rates
- Monitor FFA degree progress adoption

## Success Criteria

The migration is considered successful when:

- [ ] All verification queries return expected results
- [ ] No errors in Supabase logs
- [ ] Existing users can still access their profiles
- [ ] New profile fields are editable through UI
- [ ] Profile completion percentages calculate correctly
- [ ] FFA chapters are searchable
- [ ] Skills catalog is accessible
- [ ] RLS policies protect user data appropriately
- [ ] No performance degradation on existing queries
- [ ] Mobile app (if applicable) syncs new fields correctly

## Support Contacts

- **Database Issues**: Check Supabase dashboard and logs
- **API Issues**: Review application server logs  
- **Frontend Issues**: Check browser console for errors
- **Performance Issues**: Monitor query execution times

## Next Steps After Deployment

1. **Phase 2 Features**:
   - Advanced FFA degree requirement verification
   - Skills certification workflow
   - Educational institution partnerships
   - Achievement badge system

2. **Data Integration**:
   - Import official FFA chapter database
   - Connect with state agricultural education systems
   - Integrate with learning management systems

3. **Mobile Enhancements**:
   - Offline profile editing
   - Photo upload for achievements
   - Push notifications for degree milestones

This deployment guide ensures a smooth transition to the enhanced user profile system while maintaining data integrity and system performance.