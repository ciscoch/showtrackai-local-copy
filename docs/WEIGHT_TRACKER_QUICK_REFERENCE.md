# Weight Tracker Database - Quick Reference

## 📊 Core Tables

### `weights`
Primary table for weight measurements
```sql
-- Insert new weight
INSERT INTO weights (animal_id, user_id, recorded_by, weight_value, weight_unit, measurement_date)
VALUES (?, auth.uid(), auth.uid(), 150.5, 'lb', CURRENT_DATE);

-- Get latest weight
SELECT * FROM v_latest_weights WHERE animal_id = ?;

-- Get weight history
SELECT * FROM weights WHERE animal_id = ? ORDER BY measurement_date DESC;
```

### `weight_goals`
Track weight targets and progress
```sql
-- Create goal
INSERT INTO weight_goals (animal_id, user_id, goal_name, target_weight, target_date, starting_weight, starting_date)
VALUES (?, auth.uid(), 'Show Goal', 180, '2025-04-01', 150, CURRENT_DATE);

-- Check active goals
SELECT * FROM v_active_weight_goals WHERE user_id = auth.uid();
```

### `weight_audit_log`
Automatic audit trail (read-only for users)
```sql
-- View audit history
SELECT action, performed_at, change_reason 
FROM weight_audit_log 
WHERE animal_id = ?
ORDER BY performed_at DESC;
```

### `weight_statistics_cache`
Performance optimization cache
```sql
-- Force recalculation
SELECT recalculate_weight_statistics(?::UUID);

-- View statistics
SELECT * FROM weight_statistics_cache WHERE animal_id = ?;
```

## 🎯 Key Views

### `v_latest_weights`
Most recent weight for each animal
```sql
SELECT animal_name, weight_value, measurement_date, adg
FROM v_latest_weights
WHERE user_id = auth.uid();
```

### `v_adg_calculations`
ADG between consecutive weights
```sql
SELECT current_date, current_weight, calculated_adg, days_between
FROM v_adg_calculations
WHERE animal_id = ?
ORDER BY current_date DESC;
```

### `v_weight_history`
Complete history with calculations
```sql
SELECT measurement_date, weight_value, weight_change, adg, previous_weight
FROM v_weight_history
WHERE animal_id = ?;
```

### `v_active_weight_goals`
Goals with real-time progress
```sql
SELECT goal_name, target_weight, current_weight, progress_percentage, urgency_status
FROM v_active_weight_goals
WHERE user_id = auth.uid() AND urgency_status IN ('urgent', 'overdue');
```

## 🔧 Useful Functions

### Calculate Weight Trend
```sql
SELECT * FROM get_weight_trend(
    animal_id := '123e4567-e89b-12d3-a456-426614174000',
    days := 30
);
-- Returns: trend ('increasing'/'decreasing'/'stable'), trend_percentage, average_change
```

### Detect Outliers
```sql
SELECT * FROM detect_weight_outliers('animal-uuid');
-- Returns weights that are statistical outliers
```

### Recalculate Statistics
```sql
-- Single animal
SELECT recalculate_weight_statistics('animal-uuid');

-- All pending
SELECT recalculate_all_pending_statistics();
```

### Cleanup Old Audit Logs
```sql
SELECT cleanup_old_audit_logs(); -- Removes logs > 1 year old
```

## 📝 Common Queries

### Dashboard Summary
```sql
-- Animal weight summary for dashboard
SELECT 
    a.name,
    a.tag,
    lw.weight_value as current_weight,
    lw.adg as current_adg,
    lw.measurement_date as last_weighed,
    lw.days_since_last_weight,
    g.goal_name,
    g.target_weight,
    g.progress_percentage
FROM animals a
LEFT JOIN v_latest_weights lw ON lw.animal_id = a.id
LEFT JOIN v_active_weight_goals g ON g.animal_id = a.id
WHERE a.user_id = auth.uid()
ORDER BY a.name;
```

### Weight Entry Form Data
```sql
-- Get data for weight entry form
WITH last_weight AS (
    SELECT weight_value, measurement_date
    FROM weights
    WHERE animal_id = ? AND status = 'active'
    ORDER BY measurement_date DESC
    LIMIT 1
)
SELECT 
    a.name,
    a.species,
    lw.weight_value as last_weight,
    lw.measurement_date as last_date,
    CURRENT_DATE - lw.measurement_date as days_since_last
FROM animals a
LEFT JOIN last_weight lw ON true
WHERE a.id = ?;
```

### ADG Performance Report
```sql
-- ADG performance over time
SELECT 
    DATE_TRUNC('week', measurement_date) as week,
    AVG(adg) as avg_weekly_adg,
    MIN(adg) as min_adg,
    MAX(adg) as max_adg,
    COUNT(*) as measurements
FROM weights
WHERE animal_id = ? 
    AND status = 'active'
    AND adg IS NOT NULL
GROUP BY week
ORDER BY week DESC;
```

### Show Weight History
```sql
-- Get all show weights
SELECT 
    a.name,
    w.measurement_date,
    w.weight_value,
    w.show_name,
    w.show_class
FROM weights w
JOIN animals a ON a.id = w.animal_id
WHERE w.user_id = auth.uid()
    AND w.is_show_weight = true
ORDER BY w.measurement_date DESC;
```

## 🚨 Important Notes

### ADG Calculation
- Automatically calculated on insert/update
- Formula: `(current_weight - previous_weight) / days_between`
- NULL for first weight entry
- Stored in `adg` column for performance

### RLS Policies
- Users can only see/edit their own animals' weights
- Audit logs are read-only
- Statistics cache is system-managed

### Triggers Active
1. `calculate_weight_metrics` - Calculates ADG before insert/update
2. `update_weight_goal_progress` - Updates goals after weight insert
3. `log_weight_changes` - Creates audit log entries
4. `update_weight_statistics` - Marks cache for recalculation

### Constraints
- Weight ranges: 1-5000 lbs or 0.5-2500 kg
- Unique constraint on (animal_id, measurement_date, measurement_time)
- Foreign keys to animals and auth.users tables

## 🔍 Debugging

### Check if migration succeeded
```sql
SELECT COUNT(*) as table_count
FROM pg_tables
WHERE schemaname = 'public' 
AND tablename IN ('weights', 'weight_goals', 'weight_audit_log', 'weight_statistics_cache');
-- Should return 4
```

### Verify RLS is enabled
```sql
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public' AND tablename LIKE '%weight%';
-- rowsecurity should be true for all
```

### Check trigger status
```sql
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE trigger_schema = 'public'
AND event_object_table IN ('weights', 'weight_goals');
```

### View recent errors
```sql
-- Check audit log for issues
SELECT action, performed_at, change_reason
FROM weight_audit_log
WHERE change_reason IS NOT NULL
ORDER BY performed_at DESC
LIMIT 10;
```

## 🔗 Integration Points

### API Endpoints (Suggested)
```
POST   /api/weights                 - Add new weight
GET    /api/weights/:animalId       - Get weight history
GET    /api/weights/latest/:animalId - Get latest weight
PUT    /api/weights/:id            - Update weight
DELETE /api/weights/:id            - Delete weight (soft delete)

POST   /api/weight-goals           - Create goal
GET    /api/weight-goals/active    - Get active goals
PUT    /api/weight-goals/:id       - Update goal
GET    /api/weight-goals/progress/:animalId - Get progress

GET    /api/weight-stats/:animalId - Get statistics
GET    /api/weight-trends/:animalId - Get trend analysis
```

### Required Frontend Components
- Weight entry form
- Weight history chart
- ADG trend chart
- Goal progress bars
- Weight comparison table
- Audit log viewer

---

**Migration File**: `/supabase/migrations/20250128_weight_tracker_schema.sql`
**Verification Script**: `/supabase/migrations/20250128_weight_tracker_verification.sql`
**Test Script**: `/supabase/migrations/20250128_weight_tracker_test.sql`
**Full Guide**: `/docs/WEIGHT_TRACKER_DEPLOYMENT_GUIDE.md`