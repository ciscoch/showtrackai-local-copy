# Weight Tracker Database Migration - Deployment Guide

## 📋 Overview
This guide provides comprehensive instructions for deploying the weight tracker database schema to your Supabase instance.

**Migration File**: `supabase/migrations/20250128_weight_tracker_schema.sql`
**Verification Script**: `supabase/migrations/20250128_weight_tracker_verification.sql`

## 🎯 Migration Summary

### What This Migration Creates:

#### **4 Core Tables**
1. `weights` - Main weight measurements table
2. `weight_goals` - Weight targets and progress tracking
3. `weight_audit_log` - Complete audit trail
4. `weight_statistics_cache` - Performance optimization cache

#### **4 ENUM Types**
- `weight_unit` - Measurement units (lb, kg)
- `weight_status` - Entry status tracking
- `measurement_method` - How weight was measured
- `goal_status` - Goal achievement tracking

#### **4 Views**
- `v_latest_weights` - Most recent weight per animal
- `v_adg_calculations` - ADG calculations
- `v_weight_history` - Complete history with calculations
- `v_active_weight_goals` - Active goals with progress

#### **9 Functions**
- Automatic ADG calculations
- Goal progress tracking
- Audit logging
- Statistics caching
- Trend analysis
- Outlier detection

#### **5 Triggers**
- Auto-calculate weight metrics
- Update goal progress
- Audit trail logging
- Statistics cache updates

#### **16 RLS Policies**
- Full row-level security implementation
- User-based access control
- Audit trail protection

## 🚀 Pre-Deployment Checklist

### ✅ Prerequisites
- [ ] Supabase project access with admin privileges
- [ ] `animals` table exists (required dependency)
- [ ] `auth.users` table exists (Supabase Auth enabled)
- [ ] Database backup completed
- [ ] Maintenance window scheduled (if production)

### ⚠️ Dependency Check
```sql
-- Run this BEFORE migration to verify dependencies
SELECT 
    tablename,
    CASE 
        WHEN tablename IS NOT NULL THEN '✅ Ready'
        ELSE '❌ Missing - Migration will fail'
    END as status
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'animals';
```

## 📝 Deployment Steps

### Step 1: Backup Current Database
```bash
# Using Supabase CLI
supabase db dump -f backup_before_weight_tracker.sql

# Or using pg_dump directly
pg_dump $DATABASE_URL > backup_$(date +%Y%m%d_%H%M%S).sql
```

### Step 2: Review Migration Script
1. Open `supabase/migrations/20250128_weight_tracker_schema.sql`
2. Verify all components are included
3. Check for any custom modifications needed

### Step 3: Deploy Migration

#### Option A: Using Supabase Dashboard (Recommended)
1. Navigate to SQL Editor in Supabase Dashboard
2. Copy entire contents of `20250128_weight_tracker_schema.sql`
3. Paste into SQL editor
4. Click "Run" to execute
5. Monitor for any errors

#### Option B: Using Supabase CLI
```bash
# From project root
supabase migration up

# Or specific file
supabase db push --file supabase/migrations/20250128_weight_tracker_schema.sql
```

#### Option C: Using psql
```bash
psql $DATABASE_URL -f supabase/migrations/20250128_weight_tracker_schema.sql
```

### Step 4: Verify Deployment
Run the verification script:
```sql
-- Execute contents of 20250128_weight_tracker_verification.sql
-- This will show detailed status of all components
```

Expected Output:
```
✅ 4 tables created
✅ 4 enum types created
✅ 15+ indexes created
✅ 4 views created
✅ 9 functions created
✅ 5 triggers active
✅ RLS enabled on all tables
✅ 16 RLS policies active
```

## 🔍 Post-Deployment Verification

### 1. Test Basic Operations
```sql
-- Test weight insert (replace with actual IDs)
INSERT INTO weights (
    animal_id,
    user_id,
    recorded_by,
    weight_value,
    weight_unit,
    measurement_date
) VALUES (
    'your-animal-id',
    auth.uid(),
    auth.uid(),
    150.5,
    'lb',
    CURRENT_DATE
);

-- Verify ADG calculation triggered
SELECT weight_value, adg, weight_change 
FROM weights 
WHERE animal_id = 'your-animal-id'
ORDER BY measurement_date DESC;

-- Check audit log created
SELECT action, performed_at 
FROM weight_audit_log 
WHERE animal_id = 'your-animal-id';
```

### 2. Test RLS Policies
```sql
-- As authenticated user, should only see own data
SELECT COUNT(*) FROM weights; -- Should only show user's animals

-- Test goal creation
INSERT INTO weight_goals (
    animal_id,
    user_id,
    goal_name,
    target_weight,
    target_date,
    starting_weight,
    starting_date
) VALUES (
    'your-animal-id',
    auth.uid(),
    'Show Weight Goal',
    180,
    CURRENT_DATE + INTERVAL '30 days',
    150,
    CURRENT_DATE
);
```

### 3. Test Views
```sql
-- Latest weights view
SELECT * FROM v_latest_weights WHERE user_id = auth.uid();

-- ADG calculations
SELECT * FROM v_adg_calculations WHERE animal_id = 'your-animal-id';

-- Active goals
SELECT * FROM v_active_weight_goals WHERE user_id = auth.uid();
```

## 🛠️ Troubleshooting

### Common Issues and Solutions

#### Issue: Foreign key constraint violation
**Error**: `violates foreign key constraint "weights_animal_id_fkey"`
**Solution**: Ensure `animals` table exists and has data
```sql
-- Check if animals table exists
SELECT EXISTS (
    SELECT FROM pg_tables 
    WHERE schemaname = 'public' AND tablename = 'animals'
);
```

#### Issue: ENUM type already exists
**Error**: `type "weight_unit" already exists`
**Solution**: Drop existing types first
```sql
DROP TYPE IF EXISTS weight_unit CASCADE;
DROP TYPE IF EXISTS weight_status CASCADE;
DROP TYPE IF EXISTS measurement_method CASCADE;
DROP TYPE IF EXISTS goal_status CASCADE;
```

#### Issue: Permission denied
**Error**: `permission denied for schema public`
**Solution**: Ensure you're using admin credentials or service role key

#### Issue: RLS blocking access
**Error**: No data returned despite records existing
**Solution**: Check RLS policies and user authentication
```sql
-- Temporarily disable RLS for testing (re-enable after!)
ALTER TABLE weights DISABLE ROW LEVEL SECURITY;
-- Test your queries
ALTER TABLE weights ENABLE ROW LEVEL SECURITY;
```

## 🔄 Rollback Procedure

If issues arise, rollback the migration:

```sql
-- Drop all weight tracker components
DROP TABLE IF EXISTS weight_statistics_cache CASCADE;
DROP TABLE IF EXISTS weight_audit_log CASCADE;
DROP TABLE IF EXISTS weight_goals CASCADE;
DROP TABLE IF EXISTS weights CASCADE;

DROP VIEW IF EXISTS v_active_weight_goals CASCADE;
DROP VIEW IF EXISTS v_weight_history CASCADE;
DROP VIEW IF EXISTS v_adg_calculations CASCADE;
DROP VIEW IF EXISTS v_latest_weights CASCADE;

DROP FUNCTION IF EXISTS recalculate_all_pending_statistics() CASCADE;
DROP FUNCTION IF EXISTS cleanup_old_audit_logs() CASCADE;
DROP FUNCTION IF EXISTS detect_weight_outliers(UUID) CASCADE;
DROP FUNCTION IF EXISTS get_weight_trend(UUID, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS recalculate_weight_statistics(UUID) CASCADE;
DROP FUNCTION IF EXISTS update_weight_statistics() CASCADE;
DROP FUNCTION IF EXISTS log_weight_changes() CASCADE;
DROP FUNCTION IF EXISTS update_weight_goal_progress() CASCADE;
DROP FUNCTION IF EXISTS calculate_weight_metrics() CASCADE;

DROP TYPE IF EXISTS goal_status CASCADE;
DROP TYPE IF EXISTS measurement_method CASCADE;
DROP TYPE IF EXISTS weight_status CASCADE;
DROP TYPE IF EXISTS weight_unit CASCADE;

-- Restore from backup
psql $DATABASE_URL < backup_before_weight_tracker.sql
```

## 📊 Performance Considerations

### Indexes Created
The migration creates 15+ indexes optimized for:
- Animal-based queries (most common)
- Date-based queries (trending)
- Status filtering (active records)
- Audit trail queries

### Statistics Cache
- Automatically maintained via triggers
- Periodic recalculation function available
- Reduces query complexity for dashboards

### Recommended Maintenance
```sql
-- Run weekly to maintain statistics
SELECT recalculate_all_pending_statistics();

-- Run monthly to clean old audit logs
SELECT cleanup_old_audit_logs();

-- Analyze tables for query optimization
ANALYZE weights;
ANALYZE weight_goals;
```

## 🔐 Security Features

### Row Level Security (RLS)
- ✅ Users can only see their own animal weights
- ✅ Audit logs are read-only
- ✅ Statistics cache is system-managed
- ✅ Goals are user-specific

### Audit Trail
- Every INSERT, UPDATE, DELETE is logged
- Includes user ID, timestamp, and changes
- Cannot be modified by users

### Data Validation
- Weight ranges enforced (1-5000 lbs, 0.5-2500 kg)
- Date consistency checks
- Measurement method validation
- Confidence level constraints

## 📈 Usage Patterns

### Common Queries After Deployment

```sql
-- Get latest weight for all user's animals
SELECT * FROM v_latest_weights WHERE user_id = auth.uid();

-- Track progress toward goals
SELECT * FROM v_active_weight_goals 
WHERE user_id = auth.uid() 
  AND urgency_status IN ('urgent', 'overdue');

-- Analyze ADG trends
SELECT 
    animal_name,
    AVG(calculated_adg) as avg_adg,
    COUNT(*) as measurements
FROM v_adg_calculations
WHERE animal_id IN (
    SELECT id FROM animals WHERE user_id = auth.uid()
)
GROUP BY animal_name;

-- Detect potential data issues
SELECT * FROM detect_weight_outliers('your-animal-id');
```

## ✅ Success Criteria

Your deployment is successful when:

1. **All Verification Checks Pass**
   - 4 tables exist with correct schemas
   - All indexes are created
   - Views return data correctly
   - Functions execute without errors

2. **Functional Tests Pass**
   - Can insert weight records
   - ADG auto-calculates
   - Goals update automatically
   - Audit logs are created

3. **Security Tests Pass**
   - RLS policies enforce access control
   - Users see only their data
   - Audit logs are immutable

4. **Performance Acceptable**
   - Weight queries < 100ms
   - Dashboard loads < 500ms
   - Statistics update < 1s

## 📞 Support

If you encounter issues:

1. Run the verification script and review output
2. Check Supabase logs for detailed errors
3. Review the troubleshooting section
4. Ensure all prerequisites are met
5. Consider running a partial migration for testing

## 🎉 Next Steps

After successful deployment:

1. **Integrate with Application**
   - Update API endpoints to use new tables
   - Implement weight entry forms
   - Create ADG visualization components
   - Add goal tracking UI

2. **Set Up Monitoring**
   - Configure alerts for outliers
   - Monitor statistics cache performance
   - Track audit log growth

3. **Schedule Maintenance**
   - Weekly statistics recalculation
   - Monthly audit log cleanup
   - Quarterly performance review

---

**Migration Status**: ✅ Ready for Deployment
**Last Updated**: January 28, 2025
**Version**: 1.0.0