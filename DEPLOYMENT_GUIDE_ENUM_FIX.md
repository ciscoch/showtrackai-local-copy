# 🚨 CRITICAL: Production Database Schema Fix - Deployment Guide

## Issue Summary
Your production database has **missing columns** causing PGRST204 errors when updating animals. The key issue is that the `species` column is an **ENUM type** (not VARCHAR), which requires special handling.

## Current Errors Being Fixed
- ✅ Missing `description` column → PGRST204 error
- ✅ Missing `gender` column → PGRST204 error  
- ✅ Invalid enum value for 'goat' in species
- ✅ Other potentially missing columns

## Pre-Deployment Checklist

### 1. Verify Current Database State
Run this in Supabase SQL Editor to see what you're dealing with:

```sql
-- Check what type the species column is
SELECT 
    column_name,
    data_type,
    udt_name
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'animals'
AND column_name IN ('species', 'gender', 'description');

-- Check if species is an ENUM and what values it has
SELECT 
    n.nspname as schema,
    t.typname as enum_name,
    array_agg(e.enumlabel ORDER BY e.enumsortorder) as enum_values
FROM pg_type t 
JOIN pg_enum e ON t.oid = e.enumtypid  
JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
WHERE t.typname = 'animal_species'
GROUP BY schema, enum_name;
```

### 2. Backup Critical Data
```sql
-- Create backup of existing animals (if any)
CREATE TABLE animals_backup_20250227 AS 
SELECT * FROM animals;

-- Verify backup
SELECT COUNT(*) FROM animals_backup_20250227;
```

## Deployment Steps

### Option A: Use the Comprehensive v2 Migration (RECOMMENDED)

This migration intelligently handles both ENUM and VARCHAR types:

1. **Open Supabase SQL Editor**
2. **Copy the ENTIRE contents** of `/Users/francisco/Documents/CALUDE/showtrackai-local-copy/supabase/migrations/20250227_fix_animals_schema_complete_v2.sql`
3. **Run as a single transaction**
4. **Check for success messages**

The v2 migration will:
- ✅ Detect if species is ENUM or VARCHAR
- ✅ Add 'goat' to enum if it's missing
- ✅ Add all missing columns (description, gender, etc.)
- ✅ Skip constraints that would conflict with ENUMs
- ✅ Refresh PostgREST cache

### Option B: Quick Fix for Immediate Relief

If you need to fix just the critical issues RIGHT NOW:

```sql
-- QUICK FIX: Add missing columns and handle ENUM
BEGIN;

-- 1. Add goat to species enum if it's an enum
DO $$
DECLARE
    species_type TEXT;
BEGIN
    SELECT data_type INTO species_type
    FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'animals'
    AND column_name = 'species';
    
    IF species_type = 'USER-DEFINED' THEN
        -- It's an ENUM, add goat if missing
        ALTER TYPE animal_species ADD VALUE IF NOT EXISTS 'goat';
        RAISE NOTICE 'Added goat to species ENUM';
    END IF;
END $$;

-- 2. Add missing description column
ALTER TABLE animals 
ADD COLUMN IF NOT EXISTS description TEXT;

-- 3. Add missing gender column
ALTER TABLE animals 
ADD COLUMN IF NOT EXISTS gender VARCHAR(50);

-- 4. Force PostgREST to refresh
NOTIFY pgrst, 'reload schema';

COMMIT;

-- Verify the fix worked
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'animals'
AND column_name IN ('description', 'gender');
```

### Option C: If Species ENUM is Blocking Everything

If the ENUM is causing too many problems, convert it to VARCHAR:

```sql
-- NUCLEAR OPTION: Convert ENUM to VARCHAR
BEGIN;

-- Step 1: Add temporary column
ALTER TABLE animals ADD COLUMN species_temp VARCHAR(50);

-- Step 2: Copy data
UPDATE animals SET species_temp = species::text;

-- Step 3: Drop old column
ALTER TABLE animals DROP COLUMN species;

-- Step 4: Rename temp column
ALTER TABLE animals RENAME COLUMN species_temp TO species;

-- Step 5: Add check constraint for valid values
ALTER TABLE animals ADD CONSTRAINT animals_species_check 
CHECK (species IN ('cattle', 'swine', 'sheep', 'goat', 'poultry', 'rabbit', 'other'));

-- Step 6: Add other missing columns
ALTER TABLE animals ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE animals ADD COLUMN IF NOT EXISTS gender VARCHAR(50);

COMMIT;
```

## Post-Deployment Verification

### 1. Verify All Columns Exist
```sql
-- Should show 17 columns including description and gender
SELECT COUNT(*) as column_count
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'animals';

-- Check specific columns
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'animals'
AND column_name IN ('description', 'gender', 'species')
ORDER BY column_name;
```

### 2. Test Animal Updates
```sql
-- Test creating a goat
INSERT INTO animals (
    user_id, 
    name, 
    species, 
    gender, 
    description
) VALUES (
    auth.uid(), 
    'Test Goat', 
    'goat', 
    'female', 
    'Test goat to verify schema'
) 
RETURNING id, name, species, gender, description;

-- Test updating with all fields
UPDATE animals 
SET 
    description = 'Updated description',
    gender = 'male',
    updated_at = NOW()
WHERE name = 'Test Goat'
RETURNING *;

-- Clean up test
DELETE FROM animals WHERE name = 'Test Goat';
```

### 3. Force PostgREST Cache Refresh
Sometimes PostgREST caches the old schema. Force refresh:

```sql
-- Method 1: Standard notification
NOTIFY pgrst, 'reload schema';

-- Method 2: If using Supabase, restart from dashboard
-- Go to Settings → Database → Restart database

-- Method 3: Wait for automatic refresh (usually ~10 seconds)
```

### 4. Test from Application
After deployment, test in your app:
1. Try updating an existing animal
2. Try creating a new goat
3. Check that gender and description fields work

## Troubleshooting

### Error: "invalid input value for enum animal_species: 'goat'"
**Solution**: The species column is an ENUM. Use Option A or the quick fix to add 'goat' to the enum.

### Error: "column animals.gender does not exist"
**Solution**: The migration didn't run completely. Re-run the v2 migration.

### Error: Still getting PGRST204 after migration
**Solution**: PostgREST cache needs refresh. Wait 30 seconds or restart the database.

### Error: "duplicate key value violates unique constraint"
**Solution**: You may have duplicate migration entries. Safe to ignore if columns exist.

## Rollback Plan

If something goes wrong:

```sql
-- Restore from backup
BEGIN;

-- Drop the modified table
DROP TABLE animals CASCADE;

-- Restore from backup
CREATE TABLE animals AS SELECT * FROM animals_backup_20250227;

-- Recreate constraints and indexes
-- (copy from original schema)

COMMIT;
```

## Success Criteria

You'll know the deployment succeeded when:
- ✅ No more PGRST204 errors when updating animals
- ✅ Can create and update goats
- ✅ Gender field works properly
- ✅ Description field can be edited
- ✅ All 17 expected columns are present

## Migration Files Reference

1. **USE THIS**: `20250227_fix_animals_schema_complete_v2.sql` - Handles ENUM types properly
2. **DON'T USE**: `20250227_fix_animals_schema_complete.sql` - Fails with ENUM types
3. **ALTERNATIVE**: `20250128_add_goat_support_fixed.sql` - Focused on goat support only

## Final Notes

- The v2 migration is **idempotent** - safe to run multiple times
- Always run in a transaction (BEGIN/COMMIT)
- Monitor Supabase logs during deployment
- The gender UI already shows only Male/Female (confirmed in code)

---

**Ready to Deploy?** Start with the pre-deployment checks, then run the v2 migration. The entire process should take less than 5 minutes.

Good luck! 🚀