# ShowTrackAI Journal Entries Database Schema Usage Guide

## Overview

This guide explains how to use the comprehensive journal entries database schema created for ShowTrackAI. The schema includes full RLS policies, FFA compliance tracking, and offline sync support.

## 🚀 Quick Start

### 1. Run the Migration

In your Supabase SQL Editor, run:
```sql
-- Execute the migration file
\i supabase/migrations/20250126_journal_entries_comprehensive_schema.sql
```

### 2. Verify Installation

```sql
-- Check that everything was created successfully
SELECT 
    table_name, 
    is_insertable_into as can_insert,
    is_updatable as can_update
FROM information_schema.tables 
WHERE table_name = 'journal_entries';

-- Check RLS is enabled
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'journal_entries';
```

## 📋 Table Structure

### Core Fields
- `id` - UUID primary key
- `user_id` - References auth.users(id) with CASCADE delete
- `title` - Entry title (required, max 200 chars)
- `content` - Entry content (required, max 10,000 chars)
- `category` - Predefined categories for agricultural activities
- `animal_id` - Optional reference to animals table

### FFA Compliance Fields
- `ffa_standards` - Array of FFA standard codes (e.g., ['AS.01.01', 'AS.07.02'])
- `competency_tracking` - JSONB for flexible competency data
- `educational_objectives` - Array of learning objectives
- `learning_outcomes` - Array of achieved outcomes

### Metadata Fields
- `weather_conditions` - JSONB for weather data
- `location_data` - JSONB for geolocation data
- `tags` - Array of searchable tags
- `attachment_urls` - Array of file URLs
- `photo_urls` - Array of photo URLs

### Quality Control
- `is_draft` - Boolean for draft entries
- `instructor_reviewed` - Boolean for educator review
- `instructor_feedback` - Text feedback from educators
- `quality_score` - Integer 0-10 rating

### Sync Support
- `sync_status` - 'pending', 'synced', or 'error'
- `version` - Auto-incrementing version number
- `last_sync_at` - Timestamp of last sync

## 🔐 Security (RLS Policies)

### Student Access
- ✅ Students can view/edit/delete their own entries
- ❌ Students cannot see other students' entries

### Educator Access  
- ✅ Educators can view student entries from same institution
- ✅ Educators can add feedback to student entries
- ❌ Educators cannot modify student content

### Admin Access
- ✅ Admins have full access to all entries

## 🔍 Usage Examples

### Insert a New Journal Entry

```sql
INSERT INTO journal_entries (
    user_id,
    title,
    content,
    category,
    animal_id,
    ffa_standards,
    tags,
    weather_conditions
) VALUES (
    auth.uid(),
    'Daily Health Check - Holstein #247',
    'Performed comprehensive health assessment. Temperature 101.2°F, clear eyes, good appetite. Slight favoring of right front hoof - monitoring closely.',
    'health',
    'animal-uuid-here',
    ARRAY['AS.07.01', 'AS.07.02'],
    ARRAY['health-check', 'holstein', 'monitoring'],
    '{"temperature": 72, "humidity": 65, "conditions": "partly cloudy"}'::jsonb
);
```

### Search Journal Entries

```sql
-- Search by text content
SELECT * FROM search_journal_entries(
    auth.uid(),
    'health check temperature',
    'health',
    10
);

-- Get entries with animal details
SELECT * FROM get_journal_entries_with_animal_details(
    auth.uid(),
    20,
    0
);
```

### Track FFA Competency Progress

```sql
-- Get competency progress for current user
SELECT * FROM get_ffa_competency_progress(auth.uid());

-- View FFA standards tracking across all entries
SELECT 
    standard_code,
    demonstration_count,
    latest_demonstration,
    categories_demonstrated
FROM ffa_standards_progress 
WHERE user_id = auth.uid()
ORDER BY demonstration_count DESC;
```

### Educator Analytics

```sql
-- Get student journal analytics (for educators)
SELECT * FROM get_student_journal_analytics(
    'student-uuid-here',
    30  -- last 30 days
);

-- View recent activity across all students
SELECT * FROM recent_journal_activity
WHERE student_email LIKE '%@school.edu';
```

## 🛠️ Integration with Flutter

### Dart Model Mapping

The schema matches your Flutter `JournalEntry` model fields:

```dart
class JournalEntry {
  final String id;                    // maps to id
  final String userId;                // maps to user_id  
  final String title;                 // maps to title
  final String content;               // maps to content
  final String category;              // maps to category
  final String? animalId;             // maps to animal_id
  final DateTime entryDate;           // maps to entry_date
  final List<String> tags;            // maps to tags
  final List<String> attachmentUrls;  // maps to attachment_urls
  final Map<String, dynamic> metadata;// maps to competency_tracking
  final bool isDraft;                 // maps to is_draft
  final String syncStatus;            // maps to sync_status
  // ... other fields
}
```

### Supabase Dart Client Usage

```dart
// Insert new entry
final response = await supabase
    .from('journal_entries')
    .insert({
      'title': 'Daily Health Check',
      'content': 'Animal health assessment...',
      'category': 'health',
      'animal_id': animalId,
      'ffa_standards': ['AS.07.01'],
      'tags': ['health', 'daily-check'],
      'weather_conditions': {
        'temperature': 75,
        'humidity': 68
      }
    });

// Get user's entries
final entries = await supabase
    .from('journal_entries')
    .select('''
      *,
      animals(name, species)
    ''')
    .eq('user_id', userId)
    .order('entry_date', ascending: false);

// Search entries
final results = await supabase
    .rpc('search_journal_entries', params: {
      'p_user_id': userId,
      'p_search_term': 'health check',
      'p_category': 'health'
    });
```

## 📊 Analytics and Reporting

### Pre-built Views Available

1. **journal_entry_stats** - Entry counts, categories, date ranges per user
2. **ffa_standards_progress** - FFA standard demonstrations and progress
3. **recent_journal_activity** - Last 30 days activity summary

### Custom Analytics Queries

```sql
-- Most active students (last 30 days)
SELECT 
    up.email,
    COUNT(*) as entry_count,
    COUNT(DISTINCT je.category) as categories_used
FROM journal_entries je
JOIN user_profiles up ON up.id = je.user_id
WHERE je.entry_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY up.email
ORDER BY entry_count DESC;

-- FFA standards coverage analysis
SELECT 
    unnest(ffa_standards) as standard,
    COUNT(*) as demonstration_count,
    COUNT(DISTINCT user_id) as students_demonstrating
FROM journal_entries
WHERE ffa_standards IS NOT NULL
GROUP BY unnest(ffa_standards)
ORDER BY demonstration_count DESC;
```

## 🔧 Maintenance and Monitoring

### Data Validation

Run periodic data validation:

```sql
-- Check for data integrity issues
SELECT validate_journal_data();
```

### Performance Monitoring

```sql
-- Check index usage
SELECT 
    indexname,
    idx_scan as times_used,
    idx_tup_read as rows_read
FROM pg_stat_user_indexes 
WHERE relname = 'journal_entries'
ORDER BY idx_scan DESC;

-- Monitor query performance
EXPLAIN ANALYZE 
SELECT * FROM journal_entries 
WHERE user_id = 'test-uuid' 
AND entry_date >= '2024-01-01';
```

### Cleanup Operations

```sql
-- Archive old draft entries (older than 90 days)
DELETE FROM journal_entries 
WHERE is_draft = true 
AND created_at < NOW() - INTERVAL '90 days';

-- Update sync status for stuck entries
UPDATE journal_entries 
SET sync_status = 'pending' 
WHERE sync_status = 'error' 
AND updated_at < NOW() - INTERVAL '1 hour';
```

## 🚨 Troubleshooting

### Common Issues

1. **RLS Policy Blocking Access**
   ```sql
   -- Check if user has proper profile
   SELECT * FROM user_profiles WHERE id = auth.uid();
   ```

2. **Slow Queries**
   ```sql
   -- Analyze query performance
   EXPLAIN (ANALYZE, BUFFERS) 
   SELECT * FROM journal_entries WHERE user_id = 'uuid-here';
   ```

3. **Orphaned Animal References**
   ```sql
   -- Clean up invalid animal_id references
   UPDATE journal_entries 
   SET animal_id = NULL 
   WHERE animal_id NOT IN (SELECT id FROM animals);
   ```

### Debug Mode

Enable detailed logging:

```sql
-- Enable statement logging (run as superuser)
ALTER SYSTEM SET log_statement = 'all';
SELECT pg_reload_conf();
```

## 📈 Future Enhancements

The schema is designed to support future features:

- **Multimedia Attachments**: attachment_urls field ready for files
- **Collaborative Entries**: Framework for shared entries between students
- **Advanced Analytics**: JSONB fields for flexible reporting
- **AI Integration**: Content analysis and suggestion system
- **Mobile Sync**: Complete offline sync capability

## 🎯 Next Steps

1. Run the migration in your Supabase instance
2. Test with sample data using the provided functions
3. Integrate with your Flutter app using the Supabase Dart client
4. Set up monitoring for performance and data integrity
5. Configure backup schedules for production data

---

**Need Help?** Check the comprehensive migration file at:
`/supabase/migrations/20250126_journal_entries_comprehensive_schema.sql`