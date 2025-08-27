# 🚨 URGENT: Fix Animal Update Error (PGRST204)

## Problem Identified
**Error**: `PostgrestException: Could not find the 'description' column of 'animals' in the schema cache`

The production database is **missing the description column** that the application expects. This causes ALL animal updates to fail.

## Immediate Fix Required

### Option 1: Quick Fix via Supabase Dashboard (RECOMMENDED - 2 minutes)

1. **Open Supabase SQL Editor**
   - Go to your Supabase project
   - Navigate to SQL Editor
   
2. **Run This Emergency Fix**
   ```sql
   -- Emergency fix - add missing description column
   ALTER TABLE animals 
   ADD COLUMN IF NOT EXISTS description TEXT;
   
   -- Refresh PostgREST cache
   NOTIFY pgrst, 'reload schema';
   ```

3. **Verify It Worked**
   ```sql
   SELECT column_name, data_type 
   FROM information_schema.columns 
   WHERE table_name = 'animals' 
   AND column_name = 'description';
   ```
   
   You should see:
   ```
   column_name | data_type
   ------------|----------
   description | text
   ```

### Option 2: Full Migration (More Comprehensive)

Run the complete migration file: `supabase/migrations/20250227_fix_missing_description_column.sql`

This migration:
- ✅ Adds the missing description column
- ✅ Checks for other potentially missing columns (metadata, photo_url)  
- ✅ Refreshes PostgREST schema cache automatically
- ✅ Includes verification and rollback options
- ✅ Is safe to run multiple times (idempotent)

## Why This Happened

1. **Schema Drift**: The database table was created without all the columns the application expects
2. **Missing Migration**: The `description` field exists in the Dart model but wasn't added to the production database
3. **PostgREST Cache**: PostgREST cached the incomplete schema and doesn't know about the missing column

## After Applying Fix

1. **Test Animal Updates**: Try editing an animal in the app - it should work now
2. **Check Logs**: Monitor for any other missing column errors
3. **Consider Full Schema Audit**: Run this query to see all columns:
   ```sql
   SELECT column_name, data_type, is_nullable
   FROM information_schema.columns
   WHERE table_name = 'animals'
   ORDER BY ordinal_position;
   ```

## Expected Columns in Animals Table

Your application expects these columns:
- id (UUID)
- user_id (UUID)
- name (VARCHAR)
- tag (VARCHAR)
- species (VARCHAR)
- breed (VARCHAR)
- gender (VARCHAR)
- birth_date (DATE)
- purchase_weight (DECIMAL)
- current_weight (DECIMAL)
- purchase_date (DATE)
- purchase_price (DECIMAL)
- **description (TEXT)** ← This was missing!
- photo_url (TEXT)
- metadata (JSONB)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)

## Prevention for Future

1. **Always run migrations** when deploying model changes
2. **Keep schema in sync** between development and production
3. **Use migration files** instead of manual table creation
4. **Test in staging** before production deployment

---

**Action Required**: Apply the emergency fix NOW to restore animal update functionality!