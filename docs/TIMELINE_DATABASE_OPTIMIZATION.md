# Timeline Feature Database Optimization Guide (APP-125)

## Overview
This document provides comprehensive guidance for database optimization for the ShowTrackAI timeline feature, ensuring optimal performance for combined journal entries and expense tracking.

## Database Architecture

### Core Tables
1. **journal_entries** - Activity and learning logs
2. **expenses** - Financial transaction records  
3. **animals** - Livestock information (for joins)
4. **users** - User authentication (via auth.users)

### Key Relationships
```sql
journal_entries.user_id -> auth.users.id
journal_entries.animal_id -> animals.id
expenses.user_id -> auth.users.id
expenses.animal_id -> animals.id
```

## Performance Optimizations Applied

### 1. Index Strategy

#### Primary Indexes
- `idx_timeline_journal_user_date` - Optimizes user timeline queries
- `idx_timeline_expense_user_date` - Optimizes expense timeline queries

#### Composite Indexes
- `idx_timeline_journal_composite` - Multi-column filtering
- `idx_timeline_expense_composite` - Multi-column filtering

#### Partial Indexes (Recent Data)
- `idx_journal_recent` - Last 30 days optimization
- `idx_expense_recent` - Last 30 days optimization

#### Join Optimization
- `idx_journal_animal_join` - Animal relationship queries
- `idx_expense_animal_join` - Animal relationship queries

### 2. Unified Timeline View
The `unified_timeline` view provides a single query interface for both journals and expenses:

```sql
SELECT * FROM unified_timeline
WHERE user_id = $1 
  AND date >= $2
ORDER BY date DESC, timestamp DESC
LIMIT 20 OFFSET 0;
```

### 3. Optimized Query Functions

#### High-Performance Timeline Query
```sql
SELECT * FROM get_timeline_items_optimized(
  p_user_id := 'user-uuid',
  p_limit := 20,
  p_offset := 0,
  p_start_date := '2024-01-01',
  p_end_date := '2024-12-31'
);
```

#### Timeline Statistics
```sql
SELECT get_timeline_stats(
  p_user_id := 'user-uuid',
  p_days_back := 30
);
```

## Security Implementation

### Row Level Security (RLS)
All tables have RLS enabled with policies ensuring:
- Users can only access their own data
- No cross-user data leakage
- Proper authentication enforcement

### Policy Structure
```sql
-- Read Policy
CREATE POLICY "Users can view their own records"
  ON table_name FOR SELECT
  USING (auth.uid() = user_id);

-- Write Policy  
CREATE POLICY "Users can create their own records"
  ON table_name FOR INSERT
  WITH CHECK (auth.uid() = user_id);
```

## Performance Benchmarks

### Expected Query Times
- Timeline fetch (20 items): < 50ms
- Statistics calculation: < 100ms
- Filtered queries: < 75ms
- Animal joins: < 60ms

### Optimization Targets
- Index hit rate: > 95%
- Sequential scan ratio: < 5%
- Cache hit rate: > 90%
- Connection pool efficiency: > 80%

## Monitoring & Maintenance

### Performance Monitoring Query
```sql
SELECT * FROM analyze_timeline_performance();
```

### Key Metrics to Track
1. **Index Usage**
   - Monitor `pg_stat_user_indexes`
   - Ensure idx_scan > seq_scan

2. **Query Performance**
   - Use `EXPLAIN ANALYZE`
   - Check execution plans

3. **Table Statistics**
   - Regular `ANALYZE` runs
   - Monitor `pg_stat_user_tables`

### Maintenance Schedule
- **Daily**: Automatic VACUUM (autovacuum)
- **Weekly**: ANALYZE on high-traffic tables
- **Monthly**: Index usage review
- **Quarterly**: Full performance audit

## Troubleshooting Guide

### Common Issues & Solutions

#### Issue: Slow Timeline Queries
**Symptoms**: Queries taking > 100ms
**Solution**:
```sql
-- Check index usage
EXPLAIN ANALYZE SELECT * FROM unified_timeline WHERE user_id = 'xxx';

-- Rebuild indexes if needed
REINDEX INDEX idx_timeline_journal_user_date;
REINDEX INDEX idx_timeline_expense_user_date;

-- Update statistics
ANALYZE journal_entries;
ANALYZE expenses;
```

#### Issue: High Sequential Scans
**Symptoms**: seq_scan > idx_scan in pg_stat_user_tables
**Solution**:
```sql
-- Verify indexes exist
SELECT * FROM pg_indexes WHERE tablename IN ('journal_entries', 'expenses');

-- Create missing indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_name ON table(column);

-- Force index usage
SET enable_seqscan = OFF; -- For testing only
```

#### Issue: RLS Policy Conflicts
**Symptoms**: Users cannot access their own data
**Solution**:
```sql
-- Check RLS status
SELECT * FROM pg_tables WHERE rowsecurity = true;

-- Verify policies
SELECT * FROM pg_policies WHERE tablename = 'your_table';

-- Test as specific user
SET LOCAL role = 'authenticated';
SET LOCAL request.jwt.claim.sub = 'user-uuid';
SELECT * FROM journal_entries LIMIT 1;
```

## Migration Commands

### Apply Optimizations
```bash
# Run optimization migration
supabase db push

# Or directly in SQL editor
psql -f supabase/migrations/20250827_timeline_database_optimization.sql
```

### Verify Setup
```bash
# Run verification script
psql -f supabase/scripts/verify_timeline_database.sql
```

### Performance Testing
```sql
-- Test with sample user
WITH test_user AS (
  SELECT id FROM auth.users LIMIT 1
)
SELECT * FROM get_timeline_items_optimized(
  (SELECT id FROM test_user),
  20, 0
);
```

## Best Practices

### Query Optimization
1. Always use indexed columns in WHERE clauses
2. Limit result sets with LIMIT/OFFSET
3. Use prepared statements for repeated queries
4. Avoid SELECT * in production code

### Index Management
1. Monitor unused indexes monthly
2. Drop redundant indexes
3. Use CONCURRENTLY for production index creation
4. Consider partial indexes for filtered queries

### Data Hygiene
1. Regular cleanup of orphaned records
2. Archive old data (> 1 year)
3. Maintain referential integrity
4. Use soft deletes when appropriate

## API Integration Examples

### TypeScript/Supabase Client
```typescript
// Optimized timeline query
const getTimeline = async (userId: string, page: number = 0) => {
  const { data, error } = await supabase
    .rpc('get_timeline_items_optimized', {
      p_user_id: userId,
      p_limit: 20,
      p_offset: page * 20,
      p_start_date: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
    });
    
  return { data, error };
};

// Get statistics
const getStats = async (userId: string) => {
  const { data, error } = await supabase
    .rpc('get_timeline_stats', {
      p_user_id: userId,
      p_days_back: 30
    });
    
  return { data, error };
};
```

### Direct SQL Query
```sql
-- Production-ready timeline query
PREPARE timeline_query (uuid, int, int) AS
  SELECT * FROM get_timeline_items_optimized($1, $2, $3);

EXECUTE timeline_query('user-uuid', 20, 0);
```

## Performance Checklist

- [ ] All tables have appropriate indexes
- [ ] RLS policies are properly configured
- [ ] Views are created and accessible
- [ ] Functions are optimized with proper hints
- [ ] Statistics are up-to-date (ANALYZE run)
- [ ] Monitoring queries return expected results
- [ ] Query execution times meet benchmarks
- [ ] No sequential scans on large tables
- [ ] Connection pooling is configured
- [ ] Regular maintenance scheduled

## Support Resources

### Documentation
- [Supabase Performance Guide](https://supabase.com/docs/guides/performance)
- [PostgreSQL Index Types](https://www.postgresql.org/docs/current/indexes.html)
- [RLS Best Practices](https://supabase.com/docs/guides/auth/row-level-security)

### Monitoring Tools
- Supabase Dashboard → Database → Performance
- pg_stat_statements extension
- pgBadger for log analysis
- Custom analyze_timeline_performance() function

## Conclusion

The database has been optimized for high-performance timeline queries with:
- Strategic indexing for common access patterns
- Unified views for simplified querying
- Security through RLS policies
- Performance monitoring capabilities
- Maintenance automation

Regular monitoring and maintenance following this guide will ensure optimal performance as the application scales.