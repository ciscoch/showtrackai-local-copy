# Fix PGRST204 Error - Complete Solution

## Problem Summary
- **Error**: `PGRST204 - Could not find the 'description' column of 'animals' in the schema cache`
- **Cause**: Animals table missing `description` column that application expects
- **Impact**: Users cannot update animals in the ShowTrackAI app

## Root Cause
1. **Missing Column**: The `description` column was never added to the `animals` table
2. **Schema Cache**: PostgREST cached the old schema without the description column
3. **Application Mismatch**: Dart model expects `description` but database doesn't have it

## Solution Steps

### Step 1: Run Database Migration
1. Go to your Supabase dashboard
2. Navigate to SQL Editor
3. Run the migration file: `20250227_fix_animals_table_description_column.sql`

### Step 2: Force PostgREST Schema Cache Refresh

**Option A: Supabase Dashboard**
1. Go to Supabase Dashboard → Settings → API
2. Click "Restart API" or "Refresh Schema"

**Option B: SQL Command**
```sql
-- Run this in Supabase SQL Editor
NOTIFY pgrst, 'reload schema';
```

**Option C: REST API Call**
```bash
# Replace with your actual project URL
curl -X POST "https://zifbuzsdhparxlhsifdi.supabase.co/rest/v1/rpc/notify_pgrst" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Content-Type: application/json"
```

**Option D: Supabase CLI** (if you have it installed)
```bash
supabase db reset --linked
# or
supabase db push --linked
```

### Step 3: Verify the Fix

**Test 1: Check Column Exists**
```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'animals' AND column_name = 'description';
```

**Test 2: Try the Failing Update**
Use the exact same request that was failing:
```
PATCH https://zifbuzsdhparxlhsifdi.supabase.co/rest/v1/animals?id=eq.d034dfb7-c604-4080-aa4b-ad75b0ce2fd1&user_id=eq.6d80d64d-186f-4eb1-83fd-a6deba59387b&select=*
```

**Test 3: Check Schema Cache**
```sql
-- Verify PostgREST can see the description column
SELECT * FROM animals LIMIT 1;
```

## Expected Results After Fix
- ✅ No more PGRST204 errors
- ✅ Animal updates work normally in the app
- ✅ Description field can be read and written
- ✅ All other animal fields remain functional

## Alternative Quick Fix (Emergency Only)
If the migration doesn't work immediately, you can manually add the column:

```sql
-- Emergency fix - add column manually
ALTER TABLE animals ADD COLUMN IF NOT EXISTS description TEXT;

-- Force cache refresh
NOTIFY pgrst, 'reload schema';
```

## Prevention for Future
1. **Always use migrations** for schema changes (not application code)
2. **Test column existence** before deploying application updates
3. **Monitor PostgREST logs** for schema cache issues
4. **Version control database schema** alongside application code

## Rollback Plan (if needed)
If this somehow breaks other functionality:

```sql
-- Remove description column (emergency only)
ALTER TABLE animals DROP COLUMN IF EXISTS description;
NOTIFY pgrst, 'reload schema';
```

Then update the Dart application to not expect the description field.

## Testing Checklist
- [ ] Migration runs without errors
- [ ] Description column exists in animals table
- [ ] PostgREST schema cache refreshed
- [ ] Animal update requests succeed
- [ ] No PGRST204 errors in logs
- [ ] App functionality restored
- [ ] All existing animal data preserved

This fix should resolve the PGRST204 error completely. The issue was simply a missing database column that the application expected to exist.