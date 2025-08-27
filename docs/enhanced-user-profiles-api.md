# Enhanced User Profiles API Documentation

## Overview

The Enhanced User Profile System for ShowTrackAI provides comprehensive user profile management with FFA degree tracking, skills certification, and educational progress monitoring. This system is fully COPPA compliant and includes robust security features.

## Database Schema Changes

### New Fields in `user_profiles` Table

```sql
-- Basic profile information
bio TEXT                      -- User biography (max 1000 characters)
phone VARCHAR(20)             -- Phone number (validated format)
profile_image_url TEXT        -- URL to profile image

-- FFA specific information
ffa_chapter VARCHAR(255)      -- FFA Chapter name
ffa_degree VARCHAR(50)        -- Current FFA degree
ffa_state VARCHAR(2)          -- State code (validated)
member_since DATE             -- Date started in FFA

-- Extended information (JSONB fields)
address JSONB DEFAULT '{}'              -- Address information
emergency_contact JSONB DEFAULT '{}'    -- Emergency contact details
educational_info JSONB DEFAULT '{}'     -- School and education details
preferences JSONB DEFAULT '{}'          -- User preferences
social_links JSONB DEFAULT '{}'         -- Social media links
achievements JSONB DEFAULT '[]'         -- List of achievements
skills_certifications JSONB DEFAULT '[]' -- Skills and certifications
```

### New Tables

#### `ffa_chapters`
- Stores FFA chapter information
- Links users to their chapters
- Includes advisor and school details

#### `ffa_degrees` 
- Reference table for FFA degree types
- Includes requirements and prerequisites
- Five standard degrees: Discovery, Greenhand, Chapter, State, American

#### `user_ffa_progress`
- Tracks individual user progress on FFA degrees
- Verification workflow for degree completion
- Evidence file storage

#### `skills_catalog`
- Master list of agricultural skills
- Categorized by agricultural area
- Certification tracking capability

#### `user_skills`
- Individual user skill tracking
- Proficiency levels and certifications
- Verification by educators

## API Endpoints

### User Profile Management

#### Get Enhanced Profile
```javascript
GET /api/user/profile

Response:
{
  "id": "uuid",
  "email": "user@example.com",
  "bio": "Student passionate about livestock management",
  "phone": "555-0123",
  "ffa_chapter": "Lincoln FFA",
  "ffa_degree": "Chapter FFA Degree",
  "ffa_state": "NE",
  "member_since": "2023-08-15",
  "profile_image_url": "https://...",
  "address": {
    "street": "123 Farm Road",
    "city": "Lincoln",
    "state": "NE",
    "zip": "68501"
  },
  "emergency_contact": {
    "name": "John Doe",
    "relationship": "parent",
    "phone": "555-0124"
  },
  "educational_info": {
    "school": "Lincoln High School",
    "grade": 11,
    "graduation_year": 2025
  },
  "achievements": [
    {
      "title": "State FFA Speaking Contest",
      "level": "state",
      "date": "2024-03-15",
      "description": "First place in prepared speaking"
    }
  ],
  "profile_completion_percentage": 85,
  "is_minor": false,
  "parent_consent": true
}
```

#### Update Profile
```javascript
PUT /api/user/profile

Body:
{
  "bio": "Updated biography",
  "phone": "555-0125",
  "ffa_chapter": "Valley View FFA",
  "ffa_state": "CA",
  "address": {
    "street": "456 Ranch Drive",
    "city": "Fresno", 
    "state": "CA",
    "zip": "93701"
  }
}

Response:
{
  "success": true,
  "profile_completion_percentage": 90,
  "updated_fields": ["bio", "phone", "ffa_chapter", "ffa_state", "address"]
}
```

### FFA Degree Management

#### Get Available Degrees
```javascript
GET /api/ffa/degrees

Response:
{
  "degrees": [
    {
      "id": "uuid",
      "degree_name": "Discovery FFA Degree",
      "degree_level": 1,
      "description": "For students in grades 7-8...",
      "requirements": [
        "Be enrolled in agricultural education course",
        "Demonstrate knowledge of FFA history"
      ],
      "prerequisites": []
    }
  ]
}
```

#### Get User's FFA Progress
```javascript
GET /api/user/ffa/progress

Response:
{
  "current_degree": "Chapter FFA Degree",
  "progress": [
    {
      "degree_name": "Greenhand FFA Degree",
      "degree_level": 2,
      "progress_percentage": 100.00,
      "status": "awarded",
      "requirements_met": [
        "completed_agricultural_course",
        "learned_ffa_creed",
        "submitted_sae_plan"
      ],
      "date_completed": "2023-12-15"
    },
    {
      "degree_name": "Chapter FFA Degree", 
      "degree_level": 3,
      "progress_percentage": 75.00,
      "status": "in_progress",
      "requirements_met": [
        "has_greenhand_degree",
        "completed_180_hours"
      ],
      "requirements_pending": [
        "community_service_hours",
        "leadership_activity"
      ]
    }
  ]
}
```

#### Start Degree Progress
```javascript
POST /api/user/ffa/degree/start

Body:
{
  "degree_id": "uuid"
}

Response:
{
  "success": true,
  "degree_name": "State FFA Degree",
  "progress_id": "uuid",
  "requirements": [...],
  "estimated_completion": "2025-06-01"
}
```

#### Update Degree Progress
```javascript
PUT /api/user/ffa/progress/{progress_id}

Body:
{
  "requirements_met": ["requirement_key"],
  "evidence_files": ["file_url"],
  "notes": "Completed community service project"
}

Response:
{
  "success": true,
  "progress_percentage": 85.5,
  "requirements_remaining": 2,
  "next_requirement": "leadership_activity"
}
```

### Skills Management

#### Get Skills Catalog
```javascript
GET /api/skills/catalog?category=animal_science&subcategory=livestock_management

Response:
{
  "skills": [
    {
      "id": "uuid",
      "skill_name": "Animal Handling",
      "category": "animal_science",
      "subcategory": "livestock_management",
      "description": "Safe and effective handling...",
      "certification_available": true,
      "certification_body": "National FFA Organization",
      "skill_level": "beginner",
      "learning_resources": [
        {
          "type": "video",
          "title": "Basic Animal Handling Techniques",
          "url": "https://..."
        }
      ]
    }
  ]
}
```

#### Add User Skill
```javascript
POST /api/user/skills

Body:
{
  "skill_id": "uuid",
  "proficiency_level": "developing",
  "notes": "Practiced with cattle and sheep",
  "evidence_files": ["photo_url"]
}

Response:
{
  "success": true,
  "skill_name": "Animal Handling",
  "proficiency_level": "developing",
  "certification_eligible": false,
  "next_level_requirements": "Demonstrate with 3 different species"
}
```

#### Get User Skills Summary
```javascript
GET /api/user/skills/summary

Response:
{
  "total_skills": 15,
  "certified_skills": 3,
  "skills_by_category": {
    "animal_science": {
      "total": 8,
      "certified": 2,
      "avg_proficiency": 2.5
    },
    "agricultural_mechanics": {
      "total": 4,
      "certified": 1,
      "avg_proficiency": 2.0
    }
  },
  "recent_achievements": [
    {
      "skill_name": "Welding - MIG",
      "certification_earned": true,
      "date": "2024-01-15"
    }
  ]
}
```

### FFA Chapters

#### Search Chapters
```javascript
GET /api/ffa/chapters?state=NE&search=lincoln

Response:
{
  "chapters": [
    {
      "id": "uuid",
      "chapter_name": "Lincoln FFA",
      "chapter_number": "1234",
      "state_code": "NE",
      "school_name": "Lincoln High School",
      "advisor_name": "Ms. Johnson",
      "advisor_email": "advisor@lincolnffa.org",
      "is_active": true
    }
  ]
}
```

## Frontend Integration Examples

### React Components

#### Profile Completion Widget
```jsx
import { useState, useEffect } from 'react';

const ProfileCompletionWidget = ({ userId }) => {
  const [completion, setCompletion] = useState(0);
  const [suggestions, setSuggestions] = useState([]);

  useEffect(() => {
    fetchProfileCompletion();
  }, [userId]);

  const fetchProfileCompletion = async () => {
    const response = await fetch(`/api/user/profile`);
    const data = await response.json();
    setCompletion(data.profile_completion_percentage);
    
    // Generate suggestions based on missing fields
    const missingSuggestions = [];
    if (!data.bio) missingSuggestions.push('Add a bio');
    if (!data.ffa_chapter) missingSuggestions.push('Select your FFA chapter');
    if (!data.phone) missingSuggestions.push('Add phone number');
    
    setSuggestions(missingSuggestions);
  };

  return (
    <div className="profile-completion-widget">
      <div className="completion-bar">
        <div 
          className="completion-fill" 
          style={{ width: `${completion}%` }}
        />
      </div>
      <p>Profile {completion}% complete</p>
      
      {suggestions.length > 0 && (
        <div className="suggestions">
          <h4>Complete your profile:</h4>
          <ul>
            {suggestions.map((suggestion, index) => (
              <li key={index}>{suggestion}</li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
};
```

#### FFA Degree Progress Tracker
```jsx
const FFADegreeProgress = ({ userId }) => {
  const [progress, setProgress] = useState([]);
  const [nextDegree, setNextDegree] = useState(null);

  useEffect(() => {
    fetchFFAProgress();
    fetchNextDegree();
  }, [userId]);

  const fetchFFAProgress = async () => {
    const response = await fetch('/api/user/ffa/progress');
    const data = await response.json();
    setProgress(data.progress);
  };

  const fetchNextDegree = async () => {
    const response = await fetch('/api/user/ffa/next-degree');
    const data = await response.json();
    setNextDegree(data);
  };

  return (
    <div className="ffa-progress-tracker">
      <h3>FFA Degree Progress</h3>
      
      {progress.map((degree, index) => (
        <div key={index} className="degree-progress">
          <div className="degree-header">
            <h4>{degree.degree_name}</h4>
            <span className={`status ${degree.status}`}>
              {degree.status}
            </span>
          </div>
          
          <div className="progress-bar">
            <div 
              className="progress-fill"
              style={{ width: `${degree.progress_percentage}%` }}
            />
          </div>
          
          <div className="requirements">
            <p>
              {degree.requirements_met?.length || 0} of{' '}
              {(degree.requirements_met?.length || 0) + (degree.requirements_pending?.length || 0)}{' '}
              requirements completed
            </p>
          </div>
        </div>
      ))}
      
      {nextDegree && (
        <div className="next-degree">
          <h4>Next Degree: {nextDegree.degree_name}</h4>
          <button onClick={() => startDegree(nextDegree.id)}>
            Start Progress
          </button>
        </div>
      )}
    </div>
  );
};
```

### Form Validation

#### Profile Update Form
```jsx
const ProfileUpdateForm = ({ profile, onUpdate }) => {
  const [formData, setFormData] = useState({
    bio: profile.bio || '',
    phone: profile.phone || '',
    ffa_chapter: profile.ffa_chapter || '',
    ffa_state: profile.ffa_state || '',
    member_since: profile.member_since || ''
  });
  
  const [errors, setErrors] = useState({});

  const validateForm = () => {
    const newErrors = {};
    
    // Bio validation
    if (formData.bio.length > 1000) {
      newErrors.bio = 'Bio must be less than 1000 characters';
    }
    
    // Phone validation
    if (formData.phone && !/^\d{3}-?\d{3}-?\d{4}$/.test(formData.phone)) {
      newErrors.phone = 'Please enter a valid phone number';
    }
    
    // State validation
    if (formData.ffa_state && !/^[A-Z]{2}$/.test(formData.ffa_state)) {
      newErrors.ffa_state = 'Please enter a valid 2-letter state code';
    }
    
    // Member since validation
    if (formData.member_since && new Date(formData.member_since) > new Date()) {
      newErrors.member_since = 'Member since date cannot be in the future';
    }
    
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!validateForm()) return;
    
    try {
      const response = await fetch('/api/user/profile', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData)
      });
      
      const result = await response.json();
      
      if (result.success) {
        onUpdate(result);
      }
    } catch (error) {
      console.error('Profile update failed:', error);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="profile-update-form">
      <div className="field-group">
        <label htmlFor="bio">Bio</label>
        <textarea
          id="bio"
          value={formData.bio}
          onChange={(e) => setFormData(prev => ({ ...prev, bio: e.target.value }))}
          maxLength={1000}
          rows={4}
        />
        {errors.bio && <span className="error">{errors.bio}</span>}
      </div>

      <div className="field-group">
        <label htmlFor="phone">Phone</label>
        <input
          type="tel"
          id="phone"
          value={formData.phone}
          onChange={(e) => setFormData(prev => ({ ...prev, phone: e.target.value }))}
          placeholder="555-123-4567"
        />
        {errors.phone && <span className="error">{errors.phone}</span>}
      </div>

      <div className="field-group">
        <label htmlFor="ffa_chapter">FFA Chapter</label>
        <input
          type="text"
          id="ffa_chapter"
          value={formData.ffa_chapter}
          onChange={(e) => setFormData(prev => ({ ...prev, ffa_chapter: e.target.value }))}
          placeholder="Lincoln FFA"
        />
      </div>

      <button type="submit" className="submit-button">
        Update Profile
      </button>
    </form>
  );
};
```

## Database Functions Usage

### Profile Completion Calculation
```sql
-- Get profile completion percentage
SELECT calculate_profile_completion('user-uuid-here') as completion_percentage;

-- Get users with incomplete profiles
SELECT email, calculate_profile_completion(id) as completion
FROM user_profiles
WHERE calculate_profile_completion(id) < 80
ORDER BY completion DESC;
```

### FFA Degree Suggestions
```sql
-- Get next recommended degree for user
SELECT suggest_next_ffa_degree('user-uuid-here') as next_degree;

-- Get all users ready for next degree level
SELECT up.email, up.ffa_degree, suggest_next_ffa_degree(up.id) as suggested
FROM user_profiles up
WHERE suggest_next_ffa_degree(up.id) IS NOT NULL;
```

### Skills Analysis
```sql
-- Get user skills summary by category
SELECT * FROM user_skills_summary 
WHERE user_id = 'user-uuid-here';

-- Find users with specific certifications
SELECT DISTINCT us.user_id, up.email, sc.skill_name
FROM user_skills us
JOIN skills_catalog sc ON sc.id = us.skill_id
JOIN user_profiles up ON up.id = us.user_id
WHERE us.certification_earned = TRUE
AND sc.skill_name ILIKE '%welding%';
```

## Security Considerations

### Row Level Security (RLS)
All tables have RLS policies that ensure:
- Users can only access their own data
- Educators can view student data from same institution
- Parents can access supervised child data (COPPA compliance)
- Admins have appropriate administrative access

### Data Validation
- Phone numbers are validated using regex patterns
- State codes are validated against US state list
- Email addresses are validated for format
- Text fields have length limits to prevent abuse

### Privacy Compliance
- COPPA compliance for users under 13
- Parental consent tracking and verification
- Data retention and deletion capabilities
- Audit logging for all data access

## Error Handling

### Common Error Codes
```javascript
// Validation errors
{
  "error": "VALIDATION_ERROR",
  "code": "INVALID_PHONE",
  "message": "Phone number format is invalid",
  "field": "phone"
}

// Permission errors
{
  "error": "PERMISSION_DENIED", 
  "code": "INSUFFICIENT_PRIVILEGES",
  "message": "You don't have permission to perform this action"
}

// Not found errors
{
  "error": "NOT_FOUND",
  "code": "DEGREE_NOT_FOUND", 
  "message": "FFA degree not found or inactive"
}

// Constraint violations
{
  "error": "CONSTRAINT_VIOLATION",
  "code": "DUPLICATE_SKILL",
  "message": "This skill has already been added to your profile"
}
```

### Frontend Error Handling
```jsx
const handleAPIError = (error, setError) => {
  if (error.code === 'VALIDATION_ERROR') {
    setError(prev => ({ ...prev, [error.field]: error.message }));
  } else if (error.code === 'PERMISSION_DENIED') {
    // Redirect to login or show permission error
    window.location.href = '/login';
  } else {
    // Generic error handling
    setError(prev => ({ ...prev, general: error.message }));
  }
};
```

## Testing

### Database Test Queries
```sql
-- Test profile completion calculation
SELECT 
  email,
  calculate_profile_completion(id) as completion,
  CASE 
    WHEN bio IS NOT NULL THEN 1 ELSE 0 END +
    CASE 
      WHEN phone IS NOT NULL THEN 1 ELSE 0 END +
    CASE 
      WHEN ffa_chapter IS NOT NULL THEN 1 ELSE 0 END as manual_count
FROM user_profiles
LIMIT 5;

-- Test RLS policies
SET ROLE authenticated;
SET request.jwt.claim.sub = 'test-user-uuid';
SELECT * FROM user_profiles; -- Should only return current user's profile
SELECT * FROM ffa_chapters; -- Should return all chapters (public data)
```

### API Test Examples
```bash
# Test profile update
curl -X PUT http://localhost:3000/api/user/profile \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{
    "bio": "Test bio update",
    "phone": "555-123-4567",
    "ffa_state": "NE"
  }'

# Test FFA progress retrieval
curl -X GET http://localhost:3000/api/user/ffa/progress \
  -H "Authorization: Bearer $JWT_TOKEN"

# Test skills search
curl -X GET "http://localhost:3000/api/skills/catalog?category=animal_science" \
  -H "Authorization: Bearer $JWT_TOKEN"
```

This enhanced user profile system provides a comprehensive foundation for ShowTrackAI's educational features while maintaining security and compliance with educational data privacy requirements.