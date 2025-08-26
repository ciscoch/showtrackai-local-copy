# N8N AI Assessment Integration Format

## Overview

This document defines the expected data format for AI assessment results from the N8N Financial Agent workflow to be properly stored in the normalized `journal_entry_ai_assessments` table.

## N8N Webhook Response Format

### Expected Response Structure

The N8N workflow should send assessment results to the SPAR callback endpoint with the following structure:

```json
{
  "runId": "run_abc123xyz",
  "status": "completed",
  "results": {
    // Core Assessment Scores (0-10 scale)
    "quality_score": 8.5,
    "engagement_score": 7.8,
    "learning_depth_score": 8.2,
    
    // FFA Competency and Standards (Arrays)
    "competencies": [
      "AS.07.01",
      "AS.07.02",
      "AS.01.03"
    ],
    "ffa_standards": [
      "Animal Science - Health Management",
      "Animal Science - Nutrition Planning",
      "General Agriculture - Record Keeping"
    ],
    "objectives_achieved": [
      "Demonstrated proper health assessment techniques",
      "Recorded detailed observations with measurements",
      "Applied preventive care protocols"
    ],
    
    // Assessment Insights (Arrays)
    "strengths": [
      "Excellent attention to detail in observations",
      "Proper use of technical terminology",
      "Clear documentation of procedures followed"
    ],
    "growth_areas": [
      "Could provide more specific measurements",
      "Consider adding cost analysis",
      "Include follow-up planning"
    ],
    "recommendations": [
      "Continue daily health monitoring",
      "Document feed conversion ratios",
      "Schedule veterinary consultation for vaccination update"
    ],
    
    // Additional Analysis (Optional Arrays)
    "key_concepts": [
      "Preventive healthcare",
      "Animal behavior observation",
      "Record keeping accuracy"
    ],
    "vocabulary_used": [
      "Auscultation",
      "Body condition scoring",
      "Vital signs assessment"
    ],
    
    // Technical Analysis (Optional)
    "technical_notes": "Entry demonstrates advanced understanding of animal health protocols with appropriate use of veterinary terminology.",
    "accuracy_notes": "All measurements and observations align with standard veterinary practices.",
    
    // Assessment Metadata
    "confidence_score": 0.89,
    "model_used": "gpt-4",
    "processing_duration_ms": 4250
  },
  "model": "gpt-4",
  "timestamp": "2025-02-02T10:30:45Z"
}
```

## Data Transformation in SPAR Callback

The SPAR callback Edge Function transforms the N8N response into normalized database format:

### Transformation Mapping

| N8N Field | Database Column | Type | Notes |
|-----------|-----------------|------|--------|
| `results.quality_score` | `quality_score` | DECIMAL(3,1) | 0-10 scale |
| `results.engagement_score` | `engagement_score` | DECIMAL(3,1) | 0-10 scale |
| `results.learning_depth_score` | `learning_depth_score` | DECIMAL(3,1) | 0-10 scale |
| `results.competencies` | `competencies_identified` | JSONB | Array of strings |
| `results.ffa_standards` | `ffa_standards_matched` | JSONB | Array of strings |
| `results.objectives_achieved` | `learning_objectives_achieved` | JSONB | Array of strings |
| `results.strengths` | `strengths_identified` | JSONB | Array of strings |
| `results.growth_areas` OR `results.improvements` | `growth_areas` | JSONB | Array of strings |
| `results.recommendations` | `recommendations` | JSONB | Array of strings |
| `results.key_concepts` | `key_concepts` | JSONB | Array of strings |
| `results.vocabulary_used` | `vocabulary_used` | JSONB | Array of strings |
| `results.technical_notes` OR `results.accuracy_notes` | `technical_accuracy_notes` | TEXT | Single string |
| `results.confidence_score` | `confidence_score` | DECIMAL(3,2) | 0-1 scale |
| `results.model_used` OR `model` | `model_used` | TEXT | AI model identifier |

### Data Validation Rules

1. **Score Validation**:
   - All scores must be between 0 and 10
   - Confidence score must be between 0 and 1
   - Invalid scores are converted to NULL

2. **Array Validation**:
   - All array fields must be valid JSON arrays
   - Non-array values are converted to empty arrays
   - Null values are converted to empty arrays

3. **String Validation**:
   - Text fields accept NULL values
   - Empty strings are converted to NULL

## N8N Workflow Configuration

### Required Output Nodes

Your N8N workflow should have these output nodes configured:

#### 1. Quality Assessment Node
```javascript
// Calculate quality scores based on content analysis
return {
  quality_score: calculateQualityScore(content),
  engagement_score: calculateEngagementScore(content),
  learning_depth_score: calculateLearningDepth(content)
};
```

#### 2. Competency Detection Node  
```javascript
// Extract FFA competencies and standards
return {
  competencies: extractCompetencies(content),
  ffa_standards: mapToFfaStandards(competencies),
  objectives_achieved: identifyObjectives(content)
};
```

#### 3. Insight Generation Node
```javascript
// Generate assessment insights
return {
  strengths: identifyStrengths(content),
  growth_areas: identifyGrowthAreas(content),
  recommendations: generateRecommendations(content, context)
};
```

#### 4. Technical Analysis Node
```javascript
// Perform technical content analysis
return {
  key_concepts: extractKeyConcepts(content),
  vocabulary_used: extractTechnicalVocabulary(content),
  technical_notes: generateTechnicalNotes(content)
};
```

#### 5. Assessment Metadata Node
```javascript
// Calculate assessment metadata
return {
  confidence_score: calculateConfidence(analysis),
  model_used: "gpt-4",
  processing_duration_ms: Date.now() - startTime
};
```

### Final Aggregation Node

Combine all analysis results before sending to webhook:

```javascript
const assessmentResults = {
  runId: $node["Start"].json.runId,
  status: "completed",
  results: {
    // Combine all analysis results
    ...$node["Quality Assessment"].json,
    ...$node["Competency Detection"].json,
    ...$node["Insight Generation"].json,
    ...$node["Technical Analysis"].json,
    ...$node["Assessment Metadata"].json
  },
  timestamp: new Date().toISOString()
};

return [assessmentResults];
```

## Error Handling

### N8N Error Response Format

If analysis fails, N8N should send:

```json
{
  "runId": "run_abc123xyz",
  "status": "failed",
  "error": "Unable to process journal content",
  "errorDetails": {
    "error_type": "content_analysis_error",
    "message": "Insufficient content for meaningful analysis",
    "timestamp": "2025-02-02T10:30:45Z"
  }
}
```

### Partial Analysis Response

If some analysis succeeds but others fail:

```json
{
  "runId": "run_abc123xyz",
  "status": "completed",
  "results": {
    "quality_score": 7.5,
    "competencies": ["AS.07.01"],
    "strengths": ["Good observation skills"],
    // Other fields as available
    "analysis_warnings": [
      "Unable to identify specific FFA standards",
      "Limited technical vocabulary detected"
    ]
  }
}
```

## Testing the Integration

### Test Payload Example

Use this payload to test the SPAR callback endpoint:

```bash
curl -X POST https://your-supabase-url/functions/v1/spar-callback \
  -H "Content-Type: application/json" \
  -H "x-spar-auth: your-callback-secret" \
  -d '{
    "runId": "test_run_123",
    "status": "completed",
    "results": {
      "quality_score": 8.5,
      "engagement_score": 7.8,
      "learning_depth_score": 8.2,
      "competencies": ["AS.07.01", "AS.07.02"],
      "ffa_standards": ["Animal Health Management"],
      "objectives_achieved": ["Demonstrated health assessment"],
      "strengths": ["Excellent documentation"],
      "growth_areas": ["Include cost analysis"],
      "recommendations": ["Continue monitoring"],
      "confidence_score": 0.89,
      "model_used": "gpt-4"
    }
  }'
```

### Verification Queries

After testing, verify data was stored correctly:

```sql
-- Check assessment was created
SELECT * FROM journal_entry_ai_assessments 
WHERE n8n_run_id = 'test_run_123';

-- Check data structure
SELECT 
  quality_score,
  jsonb_array_length(competencies_identified) as competency_count,
  jsonb_array_length(strengths_identified) as strengths_count
FROM journal_entry_ai_assessments 
WHERE n8n_run_id = 'test_run_123';
```

## Data Analytics Capabilities

With this normalized structure, you can now perform advanced analytics:

### Competency Progress Tracking
```sql
SELECT * FROM get_student_ai_competency_progress('user_id', 30);
```

### Quality Score Analysis
```sql
SELECT 
  AVG(quality_score) as avg_quality,
  COUNT(*) as assessment_count
FROM journal_entry_ai_assessments
WHERE created_at > NOW() - INTERVAL '30 days';
```

### FFA Standards Coverage
```sql
SELECT 
  jsonb_array_elements_text(ffa_standards_matched) as standard,
  COUNT(*) as coverage_count
FROM journal_entry_ai_assessments
GROUP BY jsonb_array_elements_text(ffa_standards_matched)
ORDER BY coverage_count DESC;
```

## Performance Considerations

1. **Batch Processing**: For multiple assessments, use batch processing in N8N
2. **Async Processing**: Large assessments should be processed asynchronously  
3. **Caching**: Consider caching frequent competency lookups
4. **Indexing**: The database includes optimized indexes for common queries
5. **Monitoring**: Monitor assessment processing times and success rates

## Security & Compliance

1. **Authentication**: All webhook calls must include `x-spar-auth` header
2. **Data Privacy**: Assessment data is protected by RLS policies
3. **Audit Trail**: All assessments include trace_id for correlation
4. **Error Logging**: All processing errors are logged for debugging

## Migration from Legacy Format

Existing `ai_analysis` JSONB fields in `journal_entries` will be:
1. Preserved for backward compatibility
2. Updated with basic summary pointing to detailed assessment
3. Enhanced with `assessment_id` reference to new table

This ensures zero downtime during the transition while enabling rich analytics capabilities.