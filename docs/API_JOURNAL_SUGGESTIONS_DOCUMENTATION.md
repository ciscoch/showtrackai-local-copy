# Journal Suggestions API Documentation

## Overview

The Journal Suggestions System provides AI-powered content auto-populate functionality for ShowTrackAI journal entries, with comprehensive COPPA compliance and age-appropriate content filtering.

## Base URL
```
https://mellifluous-speculoos-46225c.netlify.app/.netlify/functions
```

## Authentication
All endpoints require Bearer token authentication via Supabase Auth:
```
Authorization: Bearer <supabase_jwt_token>
```

---

## API Endpoints

### 1. GET /api/journal/suggestions

Get contextual journal entry suggestions based on user profile and context.

#### Query Parameters
| Parameter | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `category` | string | Yes | Journal entry category | `daily_care` |
| `species` | string | No | Animal species filter | `pig` |
| `animal_id` | UUID | No | Specific animal context | `abc123...` |
| `weather` | string | No | Current weather condition | `sunny` |
| `location` | string | No | Current location context | `barn_a` |
| `competency_level` | string | No | User competency level | `developing` |
| `limit` | integer | No | Max suggestions to return (1-10) | `5` |

#### Example Request
```http
GET /api/journal/suggestions?category=daily_care&species=pig&weather=sunny&limit=3
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### Success Response (200)
```json
{
  "suggestions": [
    {
      "template_id": "daily_care_pig_001",
      "title": "Daily Care for Hamlet",
      "content": "Today I checked on Hamlet. The weather was sunny and 72°F. I observed: [Describe what you noticed about your pig's health, behavior, and environment]. I fed Hamlet 3.5 lbs of starter feed. The water was clean. Next time I will: [What will you do differently?]",
      "category": "daily_care",
      "difficulty_level": 1,
      "estimated_time_minutes": 10,
      "ffa_standards": ["AS.01.01", "AS.02.01"],
      "success_rate": 87.5,
      "placeholders": [
        {"key": "{{animal_name}}", "value": "Hamlet"},
        {"key": "{{weather_condition}}", "value": "sunny and 72°F"},
        {"key": "{{date}}", "value": "August 28, 2025"}
      ]
    }
  ],
  "context": {
    "user_age_group": "13_to_17",
    "coppa_compliant": true,
    "parent_supervised": false,
    "personalization_applied": true
  },
  "cache_info": {
    "cache_hit": false,
    "response_time_ms": 245
  }
}
```

#### Error Responses
```json
// 400 - Invalid Parameters
{
  "error": "Invalid category",
  "message": "Category must be one of: daily_care, health_check, feeding, training...",
  "code": "INVALID_CATEGORY"
}

// 403 - Age Verification Required
{
  "error": "Age verification required", 
  "message": "Parent consent required for users under 13",
  "code": "COPPA_CONSENT_REQUIRED"
}
```

---

### 2. POST /api/journal/generate-content

Generate AI-powered journal content using N8N workflow integration.

#### Request Body
```json
{
  "context": {
    "category": "health_check",
    "animal_id": "abc123-def456-ghi789",
    "weather": {
      "condition": "partly_cloudy",
      "temperature": 68,
      "humidity": 45
    },
    "location": {
      "name": "Main Barn",
      "address": "Farm Location"
    },
    "user_notes": "Pig seems a bit lethargic today"
  },
  "template_id": "health_check_general_001",
  "customization": {
    "tone": "educational", // educational, casual, detailed
    "include_questions": true,
    "include_ffa_standards": true,
    "personalization_level": "high" // low, medium, high
  },
  "user_preferences": {
    "complexity": "age_appropriate",
    "include_reflections": true
  }
}
```

#### Success Response (200)
```json
{
  "generated_content": {
    "title": "Health Check - Hamlet the Market Pig",
    "content": "Today I performed a thorough health check on Hamlet. The weather was partly cloudy at 68°F with 45% humidity - perfect conditions for outdoor observation.\n\nWhat I observed during my health assessment:\n• Eyes: Clear and bright, no discharge\n• Nose: Clean and moist, normal breathing\n• Appetite: Hamlet seemed less interested in feed than usual\n• Energy level: Noticeably more lethargic than yesterday\n• Body condition: Maintaining good weight, no visible issues\n\nBased on my observations, Hamlet's reduced activity could be related to the weather change or minor digestive adjustment. I will monitor closely and consult with my advisor if lethargy continues.\n\nFFA Standards demonstrated: AS.07.01 (Animal Health Assessment), AS.07.02 (Health Problem Identification)\n\nNext steps: Continue monitoring appetite and energy levels, ensure fresh water availability, consider consulting veterinarian if no improvement in 24 hours.",
    "suggested_tags": ["health_assessment", "monitoring", "pig_care"],
    "ffa_standards": ["AS.07.01", "AS.07.02"],
    "educational_objectives": [
      "Demonstrate proper animal health assessment techniques",
      "Identify normal vs abnormal animal behaviors",
      "Apply problem-solving skills to animal care"
    ]
  },
  "processing_info": {
    "n8n_workflow_id": "8aP7U2qh0leVggTL",
    "processing_time_ms": 2340,
    "ai_model_used": "gpt-4",
    "quality_score": 8.5,
    "age_appropriate": true
  },
  "template_info": {
    "template_id": "health_check_general_001",
    "customizations_applied": ["weather_integration", "animal_context", "ffa_standards"]
  }
}
```

#### Error Responses
```json
// 429 - Rate Limited
{
  "error": "Rate limit exceeded",
  "message": "Too many AI generation requests. Try again in 60 seconds.",
  "retry_after": 60
}

// 503 - N8N Service Unavailable  
{
  "error": "AI service temporarily unavailable",
  "message": "Content generation service is down. Using fallback templates.",
  "fallback_suggestion": {
    "title": "Basic Health Check Template",
    "content": "Today I checked my animal's health..."
  }
}
```

---

### 3. PUT /api/journal/suggestion-feedback

Record user acceptance, rejection, or modification of suggestions.

#### Request Body
```json
{
  "template_id": "daily_care_pig_001",
  "session_id": "session_123456",
  "feedback": {
    "action": "accepted", // accepted, modified, dismissed
    "rating": 4, // 1-5 stars
    "comments": "Great template, very helpful for beginners",
    "modifications": "Added more detail about feeding schedule",
    "completion_time_seconds": 180
  },
  "final_journal_entry": {
    "title": "Daily Care for Hamlet",
    "content": "Final content that was actually submitted...",
    "quality_assessment": {
      "score": 8,
      "ffa_standards_met": ["AS.01.01"],
      "educational_value": "high"
    }
  }
}
```

#### Success Response (200)
```json
{
  "feedback_recorded": true,
  "template_updated": true,
  "user_preferences_updated": true,
  "analytics": {
    "new_success_rate": 88.2,
    "new_average_rating": 4.3,
    "total_feedback_count": 156
  }
}
```

---

### 4. GET /api/journal/templates/:category

Get all available templates for a specific category with user personalization.

#### Path Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `category` | string | Yes | Journal entry category |

#### Query Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `species` | string | No | Filter by animal species |
| `difficulty` | integer | No | Filter by difficulty level (1-5) |
| `personalized` | boolean | No | Apply user personalization (default: true) |

#### Example Request
```http
GET /api/journal/templates/daily_care?species=pig&difficulty=1&personalized=true
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### Success Response (200)
```json
{
  "templates": [
    {
      "template_id": "daily_care_pig_001",
      "title_template": "Daily Care for {{animal_name}}",
      "content_template": "Today I checked on {{animal_name}}...",
      "difficulty_level": 1,
      "estimated_time_minutes": 10,
      "ffa_standards": ["AS.01.01", "AS.02.01"],
      "success_rate": 87.5,
      "user_preference_score": 92.3,
      "usage_count": 1247,
      "average_rating": 4.2,
      "is_user_favorite": true
    }
  ],
  "user_context": {
    "age_group": "13_to_17",
    "experience_level": "developing",
    "personalization_applied": true,
    "coppa_compliant": true
  },
  "category_info": {
    "total_available": 8,
    "age_appropriate": 8,
    "difficulty_matched": 3
  }
}
```

---

## N8N Webhook Integration

### Enhanced Journal Processing Webhook

**Webhook URL:** `https://showtrackai.app.n8n.cloud/webhook/journal-suggestions`

#### Request Structure
```json
{
  "action": "generate_suggestion", // generate_suggestion, enhance_template, analyze_usage
  "request_id": "req_123456789",
  "trace_id": "trace_abc123def",
  "timestamp": "2025-08-28T10:30:00Z",
  
  "user_context": {
    "user_id": "user_abc123",
    "age_group": "13_to_17", // COPPA compliance
    "experience_level": "developing",
    "primary_species": "pig",
    "ffa_chapter": "Lincoln FFA",
    "competency_level": "developing"
  },
  
  "generation_context": {
    "category": "daily_care",
    "species": "pig",
    "animal_data": {
      "name": "Hamlet",
      "breed": "Hampshire",
      "age_weeks": 16,
      "current_weight": 145,
      "last_health_check": "2025-08-25"
    },
    "environmental_context": {
      "weather": {
        "condition": "partly_cloudy",
        "temperature": 68,
        "humidity": 45
      },
      "location": {
        "name": "Main Barn",
        "type": "indoor_facility"
      }
    },
    "educational_context": {
      "current_ffa_standards": ["AS.01.01"],
      "recent_learning_topics": ["animal_nutrition", "health_monitoring"],
      "upcoming_goals": ["county_fair_preparation"]
    }
  },
  
  "generation_requirements": {
    "age_appropriate": true,
    "coppa_compliant": true,
    "include_educational_value": true,
    "include_reflection_prompts": true,
    "max_reading_level": 8, // Grade level
    "include_ffa_standards": true,
    "safety_content_only": true
  },
  
  "personalization": {
    "learning_style": "visual",
    "preferred_complexity": "age_appropriate",
    "include_step_by_step": true,
    "include_reflection_questions": true
  }
}
```

#### Expected Response
```json
{
  "success": true,
  "processing_time_ms": 2340,
  "suggestion_generated": {
    "title": "Daily Care Check - Hamlet",
    "content": "AI-generated age-appropriate content with educational value...",
    "educational_elements": {
      "ffa_standards_addressed": ["AS.01.01", "AS.02.01"],
      "learning_objectives": ["Animal observation skills", "Record keeping"],
      "reflection_questions": ["What did you notice that was different today?"]
    },
    "safety_compliance": {
      "coppa_compliant": true,
      "age_appropriate": true,
      "content_reviewed": true,
      "reading_level": 7
    }
  },
  "template_enhancement": {
    "template_id": "daily_care_pig_001", 
    "personalization_applied": true,
    "context_integration": ["weather", "animal_data", "location"]
  },
  "quality_metrics": {
    "educational_value_score": 8.5,
    "age_appropriateness_score": 9.0,
    "engagement_score": 7.8,
    "overall_quality": 8.4
  }
}
```

### Error Handling

#### N8N Webhook Error Responses
```json
// Content Filtering Required
{
  "success": false,
  "error_code": "CONTENT_FILTERED",
  "error_message": "Generated content requires additional review for age appropriateness",
  "fallback_provided": true,
  "fallback_template": {
    "template_id": "safe_fallback_001",
    "content": "Basic age-appropriate template content..."
  }
}

// Rate Limiting
{
  "success": false,
  "error_code": "RATE_LIMITED",
  "error_message": "AI generation quota exceeded for this user",
  "retry_after_seconds": 300,
  "quota_info": {
    "daily_limit": 50,
    "used_today": 50,
    "resets_at": "2025-08-29T00:00:00Z"
  }
}
```

---

## Service Architecture

### 1. Service Boundaries

```mermaid
graph TB
    subgraph "Flutter Client"
        A[Journal Entry Form]
        B[Suggestion UI Component] 
        C[Content Editor]
    end
    
    subgraph "API Layer (.netlify/functions)"
        D[Suggestion Service]
        E[Content Generation Service]
        F[Analytics Service]
        G[Template Management Service]
    end
    
    subgraph "Data Layer"
        H[Supabase Database]
        I[Suggestion Cache]
        J[Analytics Store]
    end
    
    subgraph "AI Processing"
        K[N8N Content Generator]
        L[OpenAI GPT-4]
        M[Content Filter]
    end
    
    subgraph "Compliance Layer"
        N[COPPA Validator]
        O[Age Verification]
        P[Content Safety Check]
    end

    A --> D
    B --> D
    C --> E
    
    D --> H
    D --> I
    E --> K
    F --> J
    
    K --> L
    K --> M
    L --> N
    M --> P
    
    D --> N
    E --> O
```

### 2. Database Schema Overview

#### Core Tables
- **`journal_suggestion_templates`** - Template library with age-appropriate content
- **`user_suggestion_preferences`** - User personalization and COPPA settings
- **`suggestion_analytics`** - Usage tracking and performance metrics
- **`suggestion_performance_metrics`** - Daily aggregated metrics
- **`suggestion_cache`** - Performance optimization cache

#### Key Relationships
```sql
user_suggestion_preferences.user_id → auth.users.id
suggestion_analytics.user_id → auth.users.id  
suggestion_analytics.template_id → journal_suggestion_templates.id
suggestion_cache.template_ids → journal_suggestion_templates.id[]
```

---

## Caching Strategy

### 1. Multi-Level Caching

```mermaid
graph LR
    A[User Request] --> B{Cache L1: User Personalized}
    B -->|Hit| C[Return Cached]
    B -->|Miss| D{Cache L2: Context Group}
    D -->|Hit| E[Personalize & Cache L1]
    D -->|Miss| F[Generate AI Content]
    F --> G[Cache L2]
    G --> H[Personalize & Cache L1]
    E --> C
    H --> C
```

### 2. Cache Keys Structure
```
Level 1 (User): user_{user_id}_{category}_{species}_{competency}
Level 2 (Context): ctx_{category}_{species}_{age_group}_{weather_pattern}
```

### 3. Cache Expiration
- **L1 Cache**: 1 hour (user personalized)
- **L2 Cache**: 6 hours (context group)
- **Template Cache**: 24 hours (base templates)

---

## COPPA Compliance Implementation

### 1. Age Verification Flow

```mermaid
graph TD
    A[User Requests Suggestion] --> B{Birth Date Available?}
    B -->|No| C[Use Safe Default Templates]
    B -->|Yes| D{Calculate Age}
    D --> E{Under 13?}
    E -->|Yes| F{Parent Consent?}
    F -->|No| G[Block Advanced Content]
    F -->|Yes| H[Allow Age-Appropriate Content]
    E -->|No| I[Standard Content Filter]
    
    G --> J[Return Elementary Templates]
    H --> K[Return Supervised Templates]
    I --> L[Return Full Template Library]
```

### 2. Content Filtering Levels

#### Under 13 (COPPA Protected)
- **Content**: Simple language, basic concepts only
- **Templates**: Elementary-level only (`age_group: ['elementary']`)
- **AI Generation**: Extra safety filtering, no complex topics
- **Parent Oversight**: All content logged for potential parent review

#### 13-17 (Teen)
- **Content**: Age-appropriate with educational focus
- **Templates**: Middle and high school levels
- **AI Generation**: Educational enhancement, career exploration
- **Supervision**: Educator oversight available

#### 18+ (Adult)
- **Content**: Full access to all templates and AI features
- **Templates**: Complete library including advanced topics
- **AI Generation**: Full capability with professional language options

### 3. Safety Implementation

#### Content Safety Checks
```sql
-- Age-appropriate content verification
SELECT jst.* 
FROM journal_suggestion_templates jst
WHERE jst.coppa_compliant = TRUE
AND (
    CASE 
        WHEN user_age < 13 THEN 'elementary' = ANY(jst.age_group)
        WHEN user_age <= 17 THEN ('middle_school' = ANY(jst.age_group) OR 'high_school' = ANY(jst.age_group))
        ELSE TRUE
    END
);
```

---

## Performance Optimization

### 1. Database Optimization

#### Key Indexes
```sql
-- High-performance suggestion lookup
CREATE INDEX idx_suggestions_lookup 
ON journal_suggestion_templates(category, is_active) 
WHERE coppa_compliant = TRUE;

-- User preference fast access
CREATE INDEX idx_user_prefs_fast 
ON user_suggestion_preferences(user_id, enable_suggestions) 
WHERE enable_suggestions = TRUE;

-- Analytics time-series queries
CREATE INDEX idx_analytics_timeseries 
ON suggestion_analytics(user_id, created_at DESC) 
WHERE event_type = 'accepted';
```

#### Query Performance Targets
- **Suggestion Lookup**: < 50ms
- **Cache Hit**: < 10ms  
- **AI Generation**: < 3 seconds
- **Analytics Query**: < 100ms

### 2. Scalability Considerations

#### Horizontal Scaling Points
- **Read Replicas**: For suggestion template queries
- **Cache Partitioning**: By geographic region and age group
- **N8N Load Balancing**: Multiple webhook endpoints for AI processing
- **CDN Caching**: For static template content

#### Performance Monitoring
```sql
-- Daily performance check
SELECT 
    metric_date,
    average_response_time_ms,
    cache_hit_rate,
    success_rate,
    n8n_availability_percentage
FROM suggestion_performance_metrics 
WHERE metric_date >= CURRENT_DATE - 7;
```

---

## Security Implementation

### 1. Row Level Security

#### Template Access Control
```sql
-- Age-appropriate template access
CREATE POLICY "age_appropriate_templates" ON journal_suggestion_templates
FOR SELECT USING (
    is_active = TRUE 
    AND coppa_compliant = TRUE
    AND (
        age_group IS NULL 
        OR EXISTS (
            SELECT 1 FROM user_profiles up
            WHERE up.id = auth.uid()
            AND CASE 
                WHEN DATE_PART('year', AGE(up.birth_date)) < 13 
                THEN 'elementary' = ANY(age_group)
                WHEN DATE_PART('year', AGE(up.birth_date)) <= 17 
                THEN ('middle_school' = ANY(age_group) OR 'high_school' = ANY(age_group))
                ELSE TRUE
            END
        )
    )
);
```

#### Data Privacy Protection
```sql
-- Users can only access their own analytics
CREATE POLICY "own_analytics_only" ON suggestion_analytics
FOR ALL USING (auth.uid() = user_id);

-- Educators can view student analytics with consent
CREATE POLICY "educator_student_analytics" ON suggestion_analytics  
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM user_profiles educator
        JOIN user_profiles student ON (
            educator.educational_institution = student.educational_institution
            AND student.educational_consent = TRUE
        )
        WHERE educator.id = auth.uid()
        AND educator.type = 'educator'
        AND student.id = suggestion_analytics.user_id
    )
);
```

### 2. Input Validation & Sanitization

#### API Input Validation
```typescript
// Input validation schema
const suggestionRequestSchema = {
  category: {
    type: 'string',
    enum: ['daily_care', 'health_check', 'feeding', 'training', ...],
    required: true
  },
  species: {
    type: 'string',
    pattern: '^[a-z_]+$',
    maxLength: 20
  },
  user_notes: {
    type: 'string',
    maxLength: 1000,
    sanitize: true // Remove HTML, scripts, etc.
  }
};
```

---

## Integration Patterns

### 1. Service Communication

#### Synchronous Flow (Fast Suggestions)
```
Client Request → Cache Check → Template Match → Response (< 100ms)
```

#### Asynchronous Flow (AI Generation) 
```
Client Request → N8N Webhook → AI Processing → Callback → Cache Update
```

### 2. Error Handling & Fallbacks

#### Fallback Hierarchy
1. **Primary**: AI-generated personalized content
2. **Secondary**: Cached personalized templates  
3. **Tertiary**: Static age-appropriate templates
4. **Emergency**: Basic generic template

#### Circuit Breaker Pattern
```javascript
const circuitBreaker = {
  n8nFailureThreshold: 5, // failures in 60 seconds
  fallbackTimeout: 60, // seconds before retry
  healthCheckInterval: 300 // seconds
};
```

---

## Monitoring & Analytics

### 1. Key Performance Indicators

#### User Engagement
- **Suggestion Acceptance Rate**: Target > 75%
- **Content Completion Rate**: Target > 85%  
- **User Rating**: Target > 4.0/5.0
- **Time to Complete**: Target < 5 minutes

#### System Performance  
- **API Response Time**: Target < 100ms
- **Cache Hit Rate**: Target > 80%
- **N8N Availability**: Target > 99%
- **AI Generation Time**: Target < 3 seconds

#### Compliance Metrics
- **COPPA Violation Rate**: Target 0%
- **Age-Appropriate Content**: 100% compliance
- **Parent Consent Coverage**: Target > 95% for under-13

### 2. Analytics Dashboard Queries

#### Daily Summary
```sql
SELECT 
    metric_date,
    total_suggestions_generated,
    success_rate,
    cache_hit_rate,
    average_response_time_ms,
    under_13_suggestions,
    teen_suggestions,
    adult_suggestions
FROM suggestion_performance_metrics 
WHERE metric_date >= CURRENT_DATE - 30
ORDER BY metric_date DESC;
```

#### Template Performance
```sql
SELECT 
    jst.template_id,
    jst.category,
    jst.usage_count,
    jst.success_rate,
    jst.average_rating,
    COUNT(DISTINCT sa.user_id) as unique_users,
    AVG(sa.quality_score) as avg_quality
FROM journal_suggestion_templates jst
LEFT JOIN suggestion_analytics sa ON sa.template_id = jst.id
WHERE jst.is_active = TRUE
GROUP BY jst.id, jst.template_id, jst.category, jst.usage_count, jst.success_rate, jst.average_rating
ORDER BY jst.success_rate DESC, jst.usage_count DESC;
```

---

## Implementation Checklist

### Database Migration
- [ ] Deploy `20250828_journal_suggestions_system.sql`
- [ ] Verify all tables created successfully
- [ ] Confirm RLS policies are active
- [ ] Test RPC functions with sample data
- [ ] Validate COPPA compliance filters

### API Development  
- [ ] Implement Netlify functions for each endpoint
- [ ] Add input validation and sanitization
- [ ] Implement caching layer with Redis/memory
- [ ] Add rate limiting (10 requests/minute per user)
- [ ] Create comprehensive error handling

### N8N Integration
- [ ] Create new webhook workflow for suggestion generation
- [ ] Implement AI content generation with safety filters
- [ ] Add age-appropriateness validation
- [ ] Create fallback content generation
- [ ] Test webhook reliability and performance

### Security & Compliance
- [ ] Validate COPPA age verification
- [ ] Test content filtering for different age groups
- [ ] Implement audit logging for all suggestion interactions
- [ ] Add parent notification system for under-13 users
- [ ] Create admin tools for content moderation

### Performance Testing
- [ ] Load test with 100 concurrent users
- [ ] Validate cache hit rates > 80%
- [ ] Test API response times < 100ms
- [ ] Verify N8N webhook performance < 3s
- [ ] Monitor database query performance

### Frontend Integration
- [ ] Update Flutter journal entry form with suggestion UI
- [ ] Implement suggestion acceptance/rejection flows
- [ ] Add user preference configuration screen
- [ ] Create suggestion feedback collection
- [ ] Test offline fallback behavior

---

This architecture provides a comprehensive, COPPA-compliant journal suggestion system with performance optimization, security controls, and scalability built-in from day one.