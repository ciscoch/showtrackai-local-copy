# SPAR Runs Implementation Guide

## Overview

The SPAR (Strategic Planning AI Reasoning) Runs system tracks the complete lifecycle of AI processing orchestration for journal entries in ShowTrackAI. It provides comprehensive monitoring, error handling, and analytics for the AI processing pipeline.

## Architecture

### Data Flow

```
1. User submits journal entry
   ↓
2. Flutter app creates SPAR run (pending)
   ↓
3. N8N webhook called with trace_id
   ↓
4. SPAR run updated to processing
   ↓
5. N8N processes with AI agents
   ↓
6. N8N calls back via Edge Function
   ↓
7. SPAR run completed with results
   ↓
8. Journal entry updated with AI analysis
```

## Key Components

### 1. Database Table: `spar_runs`

Tracks every AI processing request with:
- **run_id**: Unique trace ID for correlation
- **status**: pending → processing → completed/failed/timeout
- **inputs**: Original journal data sent for processing
- **plan**: AI-generated execution plan
- **step_results**: Results from each orchestration step
- **reflections**: AI insights and recommendations
- **performance metrics**: Processing duration and timestamps

### 2. Flutter Services

#### SPARRunsService (`spar_runs_service.dart`)

Core service for SPAR run management:

```dart
// Create a new SPAR run when submitting
final runId = await SPARRunsService.createSPARRun(
  runId: traceId,
  userId: userId,
  journalEntryId: journalId,
  intent: 'edu_context',
  inputs: journalData,
  sparSettings: settings,
);

// Update status during processing
await SPARRunsService.updateSPARRunProcessing(runId: runId);

// Complete with results
await SPARRunsService.updateSPARRunCompleted(
  runId: runId,
  results: aiResults,
  reflections: insights,
);
```

#### SPARCallbackService (`spar_callback_service.dart`)

Handles callbacks from N8N workflow:

```dart
// Process callback from N8N
final result = await SPARCallbackService.processSPARCallback(
  runId: runId,
  status: 'completed',
  results: analysisResults,
);
```

### 3. N8N Integration

#### Webhook Headers

The N8N webhook receives these headers for correlation:
- `X-Trace-ID`: Unique run identifier
- `X-SPAR-Run-ID`: SPAR run ID for callbacks
- `X-Request-ID`: Request identifier
- `X-Timestamp`: Submission timestamp

#### Callback Mechanism

N8N can update SPAR runs by calling the Edge Function:

```javascript
// In N8N workflow
const response = await fetch('https://your-project.supabase.co/functions/v1/spar-callback', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'x-spar-auth': 'your-secret-key'
  },
  body: JSON.stringify({
    runId: traceId,
    status: 'completed',
    results: {
      quality_score: 85,
      competencies: ['AS.01.01'],
      recommendations: ['Add more detail'],
      insights: ['Strong understanding']
    }
  })
});
```

### 4. Supabase Edge Function

The Edge Function (`spar-callback/index.ts`) provides a secure endpoint for N8N to update SPAR runs:

```bash
# Deploy the Edge Function
supabase functions deploy spar-callback

# Set the secret
supabase secrets set SPAR_CALLBACK_SECRET=your-secret-key
```

## Implementation Steps

### 1. Deploy Database Migration

```bash
# Apply the migration to create spar_runs table
supabase db push
```

### 2. Deploy Edge Function

```bash
# Deploy the callback function
supabase functions deploy spar-callback

# Set environment variables
supabase secrets set SPAR_CALLBACK_SECRET=your-secure-secret
```

### 3. Update N8N Workflow

Add a callback step to your N8N workflow:

1. After AI processing completes
2. Add HTTP Request node
3. Set URL: `https://your-project.supabase.co/functions/v1/spar-callback`
4. Set Method: POST
5. Add header: `x-spar-auth: your-secure-secret`
6. Set body with results

### 4. Configure Flutter App

No additional configuration needed - the services automatically track SPAR runs when journal entries are submitted with AI processing enabled.

## Monitoring & Analytics

### View User Statistics

```dart
// Get SPAR run statistics for a user
final stats = await SPARRunsService.getUserSPARStats(userId);
print('Success rate: ${stats['success_rate']}%');
print('Average duration: ${stats['average_duration_ms']}ms');
```

### Monitor Active Runs

```dart
// Check for stuck runs and timeout if needed
await SPARRunsService.monitorActiveRuns(timeoutSeconds: 60);
```

### Clean Up Old Runs

```dart
// Remove old completed runs (maintenance)
final deleted = await SPARRunsService.cleanupOldRuns(daysToKeep: 30);
print('Cleaned up $deleted old runs');
```

## SQL Queries for Monitoring

### View Recent SPAR Runs

```sql
-- View recent SPAR runs with status
SELECT 
    run_id,
    status,
    goal,
    created_at,
    processing_duration_ms
FROM spar_runs
WHERE created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC
LIMIT 20;
```

### Get Success Rate by User

```sql
-- User success rates
SELECT 
    user_id,
    COUNT(*) as total_runs,
    COUNT(*) FILTER (WHERE status = 'completed') as successful,
    ROUND(
        COUNT(*) FILTER (WHERE status = 'completed')::NUMERIC / 
        COUNT(*)::NUMERIC * 100, 2
    ) as success_rate
FROM spar_runs
GROUP BY user_id
ORDER BY total_runs DESC;
```

### Find Stuck Runs

```sql
-- Find runs stuck in processing
SELECT 
    run_id,
    user_id,
    created_at,
    NOW() - created_at as stuck_duration
FROM spar_runs
WHERE status IN ('pending', 'processing')
AND created_at < NOW() - INTERVAL '5 minutes'
ORDER BY created_at;
```

### Performance Metrics

```sql
-- Average processing time by intent
SELECT 
    goal as intent,
    COUNT(*) as total_runs,
    AVG(processing_duration_ms) as avg_duration_ms,
    MIN(processing_duration_ms) as min_duration_ms,
    MAX(processing_duration_ms) as max_duration_ms
FROM spar_runs
WHERE status = 'completed'
AND processing_duration_ms IS NOT NULL
GROUP BY goal
ORDER BY total_runs DESC;
```

## Error Handling

### Retry Failed Runs

```dart
// Retry a failed SPAR run
await SPARRunsService.retrySPARRun(runId);

// Then resubmit to N8N
await N8NWebhookService.sendJournalEntry(journalEntry);
```

### Handle Timeouts

The system automatically marks runs as timeout if they don't complete within the specified timeframe:

```dart
// Runs are marked as timeout after 60 seconds by default
await SPARRunsService.monitorActiveRuns(timeoutSeconds: 60);
```

## Security Considerations

1. **Authentication**: The Edge Function uses a shared secret for authentication
2. **RLS Policies**: Users can only view/modify their own SPAR runs
3. **Service Role**: Only the service role can update runs via Edge Function
4. **Input Validation**: All inputs are validated before processing

## Testing

Run the integration tests:

```bash
flutter test test/integration/spar_runs_integration_test.dart
```

## Troubleshooting

### SPAR Run Stuck in Processing

1. Check N8N workflow execution logs
2. Verify Edge Function is deployed and accessible
3. Run timeout monitor: `SPARRunsService.monitorActiveRuns()`

### Callbacks Not Working

1. Verify Edge Function URL in N8N
2. Check authentication secret matches
3. Review Edge Function logs in Supabase dashboard

### Missing AI Analysis in Journal

1. Verify journal_entry_id is set in SPAR run
2. Check if SPAR run completed successfully
3. Review journal entry ai_analysis field

## Future Enhancements

1. **Real-time Updates**: Use Supabase Realtime to push status updates to Flutter app
2. **Batch Processing**: Support multiple journal entries in single SPAR run
3. **Priority Queue**: Add priority levels for processing order
4. **Cost Tracking**: Track AI API costs per run
5. **Advanced Analytics**: Machine learning on processing patterns

## Conclusion

The SPAR Runs system provides comprehensive tracking and monitoring of AI processing for journal entries. It ensures reliability, provides detailed analytics, and enables debugging of the AI pipeline from submission through completion.