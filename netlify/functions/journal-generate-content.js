// ============================================================================
// ShowTrackAI Journal Content Generation API Function
// Purpose: AI-powered journal content generation with N8N integration
// ============================================================================

const { createClient } = require('@supabase/supabase-js');
const fetch = require('node-fetch');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY
);

// N8N Webhook Configuration
const N8N_JOURNAL_SUGGESTIONS_WEBHOOK = 'https://showtrackai.app.n8n.cloud/webhook/journal-suggestions';
const AI_GENERATION_TIMEOUT = 30000; // 30 seconds
const MAX_DAILY_GENERATIONS = {
  'under_13': 10,   // Conservative limit for COPPA users
  '13_to_17': 30,   // Standard limit for teens
  '18_plus': 60     // Higher limit for adults
};

exports.handler = async (event, context) => {
  // Enable CORS
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Content-Type': 'application/json',
  };

  // Handle preflight requests
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers, body: '' };
  }

  // Only allow POST requests
  if (event.httpMethod !== 'POST') {
    return {
      statusCode: 405,
      headers,
      body: JSON.stringify({ error: 'Method not allowed' })
    };
  }

  try {
    // Extract and validate authorization
    const authHeader = event.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return {
        statusCode: 401,
        headers,
        body: JSON.stringify({ error: 'Authorization required' })
      };
    }

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return {
        statusCode: 401,
        headers,
        body: JSON.stringify({ error: 'Invalid token' })
      };
    }

    // Parse request body
    let requestData;
    try {
      requestData = JSON.parse(event.body || '{}');
    } catch (e) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ error: 'Invalid JSON in request body' })
      };
    }

    // Validate required fields
    const { context, template_id, customization = {}, user_preferences = {} } = requestData;
    
    if (!context || !context.category) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ error: 'Missing required field: context.category' })
      };
    }

    // Get user profile for COPPA compliance
    const { data: userProfile, error: profileError } = await supabase
      .from('user_profiles')
      .select('birth_date, type, parent_consent, parent_supervised')
      .eq('id', user.id)
      .single();

    if (profileError) {
      return {
        statusCode: 500,
        headers,
        body: JSON.stringify({ error: 'Failed to verify user profile' })
      };
    }

    // Calculate age and COPPA status
    const ageVerification = calculateAgeGroup(userProfile.birth_date);
    const coppaProtected = ageVerification.age_group === 'under_13';

    // Check parent consent for COPPA users
    if (coppaProtected && !userProfile.parent_consent) {
      return {
        statusCode: 403,
        headers,
        body: JSON.stringify({
          error: 'COPPA_CONSENT_REQUIRED',
          message: 'Parent consent required for AI content generation',
          fallback_available: true
        })
      };
    }

    // Check daily rate limits
    const dailyUsage = await checkDailyUsage(user.id, ageVerification.age_group);
    const dailyLimit = MAX_DAILY_GENERATIONS[ageVerification.age_group];
    
    if (dailyUsage >= dailyLimit) {
      return {
        statusCode: 429,
        headers: {
          ...headers,
          'Retry-After': '3600' // Retry after 1 hour
        },
        body: JSON.stringify({
          error: 'RATE_LIMIT_EXCEEDED',
          message: `Daily AI generation limit exceeded (${dailyLimit} per day)`,
          current_usage: dailyUsage,
          daily_limit: dailyLimit,
          resets_at: getNextMidnight(),
          fallback_available: true
        })
      };
    }

    // Prepare N8N webhook payload
    const webhookPayload = {
      action: 'generate_suggestion',
      request_id: `req_${Date.now()}_${user.id.slice(0, 8)}`,
      trace_id: event.headers['x-trace-id'] || `trace_${Date.now()}`,
      timestamp: new Date().toISOString(),
      
      user_context: {
        user_id: user.id,
        age_group: ageVerification.age_group,
        experience_level: customization.experience_level || 'developing',
        competency_level: context.competency_level || 'developing',
        parent_consent_verified: coppaProtected ? userProfile.parent_consent : true,
        supervision_level: coppaProtected ? 'required' : 'optional'
      },
      
      generation_context: {
        category: context.category,
        species: context.animal_id ? await getAnimalSpecies(context.animal_id, user.id) : context.species,
        animal_data: context.animal_id ? await getAnimalContext(context.animal_id, user.id) : null,
        environmental_context: {
          weather: context.weather,
          location: context.location
        },
        educational_context: await getEducationalContext(user.id)
      },
      
      generation_requirements: {
        age_appropriate: true,
        coppa_compliant: coppaProtected,
        include_educational_value: true,
        include_reflection_prompts: user_preferences.include_reflection_questions !== false,
        max_reading_level: coppaProtected ? 4 : ageVerification.age_group === '13_to_17' ? 8 : 12,
        include_ffa_standards: customization.include_ffa_standards !== false,
        safety_content_only: coppaProtected || user_preferences.safe_content_only,
        supervision_required: coppaProtected || userProfile.parent_supervised
      },
      
      personalization: {
        tone: customization.tone || (coppaProtected ? 'simple' : 'educational'),
        complexity: user_preferences.complexity || (coppaProtected ? 'simple' : 'age_appropriate'),
        include_step_by_step: coppaProtected || customization.include_step_by_step,
        include_reflection_questions: user_preferences.include_reflection_questions !== false,
        personalization_level: customization.personalization_level || 'medium'
      }
    };

    // Call N8N webhook for AI generation
    console.log(`Calling N8N webhook for AI generation (user: ${user.id}, age: ${ageVerification.age_group})`);
    
    const n8nResponse = await callN8NWebhook(webhookPayload);
    
    if (!n8nResponse.success) {
      // Use fallback if N8N fails
      const fallbackContent = await getFallbackContent(context.category, ageVerification.age_group, animalContext?.name);
      
      return {
        statusCode: 200,
        headers,
        body: JSON.stringify({
          generated_content: fallbackContent,
          processing_info: {
            fallback_used: true,
            fallback_reason: n8nResponse.error || 'AI service unavailable',
            processing_time_ms: Date.now() - Date.parse(webhookPayload.timestamp)
          },
          template_info: {
            source: 'fallback_template',
            safety_verified: true
          }
        })
      };
    }

    // Record successful generation in analytics
    await recordGenerationAnalytics({
      user_id: user.id,
      template_id: n8nResponse.template_info?.template_id,
      event_type: 'generated',
      response_time_ms: n8nResponse.processing_time_ms,
      quality_score: n8nResponse.quality_metrics?.overall_score,
      user_age_group: ageVerification.age_group,
      ai_processing_time_ms: n8nResponse.processing_time_ms,
      cache_hit: false
    });

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify(n8nResponse)
    };

  } catch (error) {
    console.error('Error in journal-generate-content function:', error);
    
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({
        error: 'Internal server error',
        message: error.message,
        fallback_available: true
      })
    };
  }
};

// Helper Functions

function calculateAgeGroup(birthDate) {
  if (!birthDate) {
    return { age_group: 'unknown', age: null, coppa_protected: true };
  }

  const birth = new Date(birthDate);
  const today = new Date();
  let age = today.getFullYear() - birth.getFullYear();
  const monthDiff = today.getMonth() - birth.getMonth();
  
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birth.getDate())) {
    age--;
  }

  return {
    age_group: age < 13 ? 'under_13' : age <= 17 ? '13_to_17' : '18_plus',
    age: age,
    coppa_protected: age < 13
  };
}

async function checkDailyUsage(userId, ageGroup) {
  const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
  
  const { data, error } = await supabase
    .from('suggestion_analytics')
    .select('id')
    .eq('user_id', userId)
    .eq('event_type', 'generated')
    .gte('created_at', `${today}T00:00:00.000Z`)
    .lt('created_at', `${today}T23:59:59.999Z`);

  if (error) {
    console.error('Error checking daily usage:', error);
    return 0;
  }

  return data?.length || 0;
}

function getNextMidnight() {
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  tomorrow.setHours(0, 0, 0, 0);
  return tomorrow.toISOString();
}

async function getAnimalSpecies(animalId, userId) {
  const { data } = await supabase
    .from('animals')
    .select('species')
    .eq('id', animalId)
    .eq('user_id', userId)
    .single();
  
  return data?.species || null;
}

async function getAnimalContext(animalId, userId) {
  const { data } = await supabase
    .from('animals')
    .select('name, species, breed, current_weight, birth_date')
    .eq('id', animalId)
    .eq('user_id', userId)
    .single();
  
  if (!data) return null;

  return {
    name: data.name,
    species: data.species,
    breed: data.breed,
    current_weight: data.current_weight,
    age_weeks: data.birth_date 
      ? Math.floor((Date.now() - new Date(data.birth_date).getTime()) / (7 * 24 * 60 * 60 * 1000))
      : null
  };
}

async function getEducationalContext(userId) {
  // Get recent journal entries to understand learning context
  const { data: recentEntries } = await supabase
    .from('journal_entries')
    .select('category, ffa_standards, competency_tracking')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(10);

  if (!recentEntries || recentEntries.length === 0) {
    return {
      current_ffa_standards: [],
      recent_learning_topics: [],
      upcoming_goals: []
    };
  }

  // Extract learning patterns
  const recentCategories = [...new Set(recentEntries.map(e => e.category))];
  const allFFAStandards = recentEntries.flatMap(e => e.ffa_standards || []);
  const uniqueFFAStandards = [...new Set(allFFAStandards)];

  return {
    current_ffa_standards: uniqueFFAStandards.slice(0, 5),
    recent_learning_topics: recentCategories.slice(0, 3),
    upcoming_goals: ['competency_development', 'ffa_degree_progress']
  };
}

async function callN8NWebhook(payload) {
  try {
    console.log('Calling N8N webhook for AI generation...');
    
    const response = await fetch(N8N_JOURNAL_SUGGESTIONS_WEBHOOK, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'ShowTrackAI-Netlify/1.0',
        'X-Request-ID': payload.request_id,
        'X-Trace-ID': payload.trace_id
      },
      body: JSON.stringify(payload),
      timeout: AI_GENERATION_TIMEOUT
    });

    if (!response.ok) {
      throw new Error(`N8N webhook failed: ${response.status} ${response.statusText}`);
    }

    const result = await response.json();
    console.log('N8N webhook successful, processing time:', result.processing_time_ms + 'ms');
    
    return result;
  } catch (error) {
    console.error('N8N webhook error:', error);
    
    return {
      success: false,
      error: error.message,
      error_code: error.name === 'TimeoutError' ? 'AI_TIMEOUT' : 'AI_SERVICE_ERROR'
    };
  }
}

async function getFallbackContent(category, ageGroup, animalName = 'your animal') {
  // Age-appropriate fallback templates
  const fallbackTemplates = {
    under_13: {
      daily_care: {
        title: `Taking Care of ${animalName}`,
        content: `Today I took care of ${animalName}. I made sure ${animalName} had:\n\n□ Fresh food and clean water\n□ A clean, safe place to live\n□ Some exercise and attention\n\nI noticed that ${animalName} seemed: [How did your animal seem today? Happy? Calm? Active?]\n\nI learned: [What did you learn while taking care of your animal?]\n\nTomorrow I will: [What will you do to take care of your animal tomorrow?]\n\n**Remember: Always ask an adult for help if you have questions about your animal!**`,
        educational_elements: {
          ffa_standards: ['AS.01.01'],
          learning_objectives: ['Practice daily animal care', 'Develop observation skills'],
          reflection_questions: ['How did your animal seem today?', 'What did you learn?']
        }
      },
      health_check: {
        title: `Health Check for ${animalName}`,
        content: `Today I checked on ${animalName}'s health with adult help.\n\nI looked at:\n□ Eyes - were they clear and bright?\n□ Nose - was it clean?\n□ How ${animalName} was moving\n□ If ${animalName} wanted to eat\n\nWhat I noticed: [Describe what you saw]\n\nMy adult helper said: [What did your teacher or parent tell you?]\n\nI learned that healthy animals: [What did you learn about healthy animals?]\n\n**Safety reminder: Always have an adult help you check your animal!**`,
        educational_elements: {
          ffa_standards: ['AS.07.01'],
          learning_objectives: ['Learn to observe animal health', 'Practice with supervision'],
          reflection_questions: ['What makes an animal healthy?', 'When should you ask for help?']
        }
      }
    },
    
    teen: {
      daily_care: {
        title: `Daily Care Log - ${animalName}`,
        content: `**Date:** ${new Date().toLocaleDateString()}\n**Animal:** ${animalName}\n**Category:** Daily Care\n\n**Care Activities Completed:**\n- Feed and water check: [Describe feed type and amount]\n- Housing maintenance: [What cleaning or maintenance did you do?]\n- Health observation: [How did your animal look and act?]\n- Exercise/handling: [Any training or exercise activities?]\n\n**Observations:**\n[Describe your animal's behavior, appetite, and general condition]\n\n**Challenges Faced:**\n[Any problems or difficulties you encountered]\n\n**What I Learned:**\n[New insights about animal care or behavior]\n\n**Tomorrow's Plan:**\n[What you plan to focus on next]\n\n**FFA Connection:** This activity demonstrates competency in daily livestock management and record keeping skills.`,
        educational_elements: {
          ffa_standards: ['AS.01.01', 'AS.02.01'],
          learning_objectives: ['Develop consistent care routines', 'Practice detailed observation', 'Maintain accurate records'],
          reflection_questions: ['How has your animal care routine improved?', 'What would you do differently?']
        }
      }
    }
  };

  const ageCategory = ageGroup === 'under_13' ? 'under_13' : 'teen';
  const template = fallbackTemplates[ageCategory][category] || fallbackTemplates[ageCategory]['daily_care'];

  return {
    title: template.title,
    content: template.content,
    suggested_tags: [category, 'animal_care', 'learning'],
    ffa_standards: template.educational_elements.ffa_standards,
    educational_objectives: template.educational_elements.learning_objectives,
    safety_notes: ageGroup === 'under_13' ? ['Adult supervision recommended'] : [],
    source: 'fallback_template',
    personalization_applied: !!animalName && animalName !== 'your animal'
  };
}

async function recordGenerationAnalytics(analyticsData) {
  try {
    await supabase
      .from('suggestion_analytics')
      .insert({
        user_id: analyticsData.user_id,
        template_id: await getTemplateUUID(analyticsData.template_id),
        event_type: analyticsData.event_type,
        session_id: analyticsData.session_id || `session_${Date.now()}`,
        response_time_ms: analyticsData.response_time_ms,
        quality_score: analyticsData.quality_score,
        user_age_group: analyticsData.user_age_group,
        parent_consent_verified: analyticsData.parent_consent_verified || false,
        ai_processing_time_ms: analyticsData.ai_processing_time_ms,
        cache_hit: analyticsData.cache_hit || false
      });
  } catch (error) {
    console.error('Failed to record generation analytics:', error);
    // Don't throw - analytics failure shouldn't break the main function
  }
}

async function getTemplateUUID(templateId) {
  if (!templateId) return null;
  
  const { data } = await supabase
    .from('journal_suggestion_templates')
    .select('id')
    .eq('template_id', templateId)
    .single();
  
  return data?.id || null;
}

// Helper function to check daily usage
async function checkDailyUsage(userId, ageGroup) {
  const today = new Date().toISOString().split('T')[0];
  
  const { data, error } = await supabase
    .from('suggestion_analytics')
    .select('id')
    .eq('user_id', userId)
    .eq('event_type', 'generated')
    .gte('created_at', `${today}T00:00:00.000Z`)
    .lt('created_at', `${today}T23:59:59.999Z`);

  if (error) {
    console.error('Error checking daily usage:', error);
    return 0;
  }

  return data?.length || 0;
}