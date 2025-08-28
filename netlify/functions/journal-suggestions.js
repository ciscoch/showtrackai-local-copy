// ============================================================================
// ShowTrackAI Journal Suggestions API Function
// Purpose: Get contextual journal entry suggestions with COPPA compliance
// ============================================================================

const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY
);

exports.handler = async (event, context) => {
  // Enable CORS for all origins
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Content-Type': 'application/json',
  };

  // Handle preflight requests
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers, body: '' };
  }

  // Only allow GET requests
  if (event.httpMethod !== 'GET') {
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

    // Parse query parameters
    const params = event.queryStringParameters || {};
    const {
      category,
      species = null,
      animal_id = null,
      weather = null,
      location = null,
      competency_level = 'developing',
      limit = 5
    } = params;

    // Validate required parameters
    if (!category) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({
          error: 'Missing required parameter: category',
          valid_categories: [
            'daily_care', 'health_check', 'feeding', 'training', 'show_prep',
            'veterinary', 'breeding', 'record_keeping', 'financial', 
            'learning_reflection', 'project_planning', 'competition'
          ]
        })
      };
    }

    // Get user profile for age verification (COPPA compliance)
    const { data: userProfile, error: profileError } = await supabase
      .from('user_profiles')
      .select('birth_date, type, parent_consent, educational_institution')
      .eq('id', user.id)
      .single();

    if (profileError) {
      console.error('Error fetching user profile:', profileError);
      return {
        statusCode: 500,
        headers,
        body: JSON.stringify({ error: 'Failed to verify user profile' })
      };
    }

    // Calculate user age for COPPA compliance
    let userAge = null;
    let ageGroup = 'unknown';
    let coppaProtected = false;
    
    if (userProfile.birth_date) {
      const birthDate = new Date(userProfile.birth_date);
      const today = new Date();
      userAge = today.getFullYear() - birthDate.getFullYear();
      const monthDiff = today.getMonth() - birthDate.getMonth();
      if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
        userAge--;
      }

      if (userAge < 13) {
        ageGroup = 'under_13';
        coppaProtected = true;
        
        // Check parent consent for COPPA protected users
        if (!userProfile.parent_consent) {
          return {
            statusCode: 403,
            headers,
            body: JSON.stringify({
              error: 'COPPA_CONSENT_REQUIRED',
              message: 'Parent consent required for users under 13',
              age_verification: {
                age_group: ageGroup,
                coppa_protected: true,
                consent_required: true
              }
            })
          };
        }
      } else if (userAge <= 17) {
        ageGroup = '13_to_17';
      } else {
        ageGroup = '18_plus';
      }
    }

    // Get user preferences
    const { data: userPrefs } = await supabase
      .from('user_suggestion_preferences')
      .select('*')
      .eq('user_id', user.id)
      .single();

    // Create user preferences if they don't exist
    if (!userPrefs) {
      await supabase
        .from('user_suggestion_preferences')
        .insert({
          user_id: user.id,
          parent_supervised: coppaProtected,
          safe_content_only: coppaProtected,
          suggestion_complexity: coppaProtected ? 'simple' : 'age_appropriate'
        });
    }

    // Get animal context if animal_id provided
    let animalContext = null;
    if (animal_id) {
      const { data: animal } = await supabase
        .from('animals')
        .select('name, species, breed, current_weight, birth_date')
        .eq('id', animal_id)
        .eq('user_id', user.id) // Security: only user's animals
        .single();
      
      if (animal) {
        animalContext = {
          name: animal.name,
          species: animal.species,
          breed: animal.breed,
          current_weight: animal.current_weight,
          age_weeks: animal.birth_date 
            ? Math.floor((Date.now() - new Date(animal.birth_date).getTime()) / (7 * 24 * 60 * 60 * 1000))
            : null
        };
      }
    }

    // Build cache key for performance optimization
    const cacheKey = [
      category,
      species || 'any',
      ageGroup,
      competency_level,
      weather || 'any'
    ].join('|');

    // Check cache first
    const { data: cachedSuggestions } = await supabase
      .from('suggestion_cache')
      .select('suggestions_data, cache_hits, generation_time_ms')
      .eq('cache_key', cacheKey)
      .gt('expires_at', new Date().toISOString())
      .single();

    if (cachedSuggestions) {
      // Update cache hit count
      await supabase
        .from('suggestion_cache')
        .update({ 
          cache_hits: cachedSuggestions.cache_hits + 1,
          last_accessed: new Date().toISOString()
        })
        .eq('cache_key', cacheKey);

      // Personalize cached content if animal context available
      const personalizedSuggestions = personalizeTemplates(
        cachedSuggestions.suggestions_data,
        animalContext,
        weather
      );

      return {
        statusCode: 200,
        headers,
        body: JSON.stringify({
          suggestions: personalizedSuggestions,
          context: {
            user_age_group: ageGroup,
            coppa_compliant: coppaProtected,
            parent_supervised: userPrefs?.parent_supervised || false,
            personalization_applied: !!animalContext
          },
          cache_info: {
            cache_hit: true,
            response_time_ms: 15,
            original_generation_time: cachedSuggestions.generation_time_ms
          }
        })
      };
    }

    // Generate fresh suggestions using Supabase RPC
    const startTime = Date.now();
    const { data: suggestions, error: suggestionsError } = await supabase
      .rpc('get_journal_suggestions', {
        p_category: category,
        p_species: species,
        p_user_age: userAge,
        p_competency_level: competency_level,
        p_weather_condition: weather,
        p_limit: parseInt(limit)
      });

    if (suggestionsError) {
      console.error('Error fetching suggestions:', suggestionsError);
      return {
        statusCode: 500,
        headers,
        body: JSON.stringify({ error: 'Failed to fetch suggestions' })
      };
    }

    // Personalize templates with context
    const personalizedSuggestions = personalizeTemplates(
      suggestions || [],
      animalContext,
      weather
    );

    const responseTime = Date.now() - startTime;

    // Cache the results for performance
    if (personalizedSuggestions.length > 0) {
      await supabase
        .from('suggestion_cache')
        .insert({
          cache_key: cacheKey,
          category: category,
          species: species,
          age_group: ageGroup,
          competency_level: competency_level,
          weather_pattern: weather,
          suggestions_data: personalizedSuggestions,
          template_ids: personalizedSuggestions.map(s => s.template_id),
          generation_time_ms: responseTime,
          expires_at: new Date(Date.now() + 6 * 60 * 60 * 1000).toISOString() // 6 hours
        });
    }

    // Record analytics
    await recordSuggestionAnalytics({
      user_id: user.id,
      event_type: 'suggested',
      template_ids: personalizedSuggestions.map(s => s.template_id),
      response_time_ms: responseTime,
      user_age_group: ageGroup,
      trigger_context: {
        category,
        species,
        weather,
        has_animal_context: !!animalContext
      }
    });

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        suggestions: personalizedSuggestions,
        context: {
          user_age_group: ageGroup,
          coppa_compliant: coppaProtected,
          parent_supervised: userPrefs?.parent_supervised || coppaProtected,
          personalization_applied: !!animalContext
        },
        cache_info: {
          cache_hit: false,
          response_time_ms: responseTime
        }
      })
    };

  } catch (error) {
    console.error('Error in journal-suggestions function:', error);
    
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

// Helper function to personalize template content
function personalizeTemplates(templates, animalContext, weather) {
  return templates.map(template => {
    let personalizedTitle = template.title_template;
    let personalizedContent = template.content_template;
    const placeholders = [];

    // Replace animal name placeholder
    if (animalContext && animalContext.name) {
      personalizedTitle = personalizedTitle.replace(/\{\{animal_name\}\}/g, animalContext.name);
      personalizedContent = personalizedContent.replace(/\{\{animal_name\}\}/g, animalContext.name);
      placeholders.push({
        key: '{{animal_name}}',
        value: animalContext.name
      });
    }

    // Replace weather placeholder
    if (weather) {
      const weatherText = `${weather} and ${Math.floor(Math.random() * 20 + 65)}°F`;
      personalizedContent = personalizedContent.replace(/\{\{weather_condition\}\}/g, weatherText);
      placeholders.push({
        key: '{{weather_condition}}',
        value: weatherText
      });
    }

    // Replace date placeholder
    const currentDate = new Date().toLocaleDateString('en-US', { 
      weekday: 'long', 
      year: 'numeric', 
      month: 'long', 
      day: 'numeric' 
    });
    personalizedTitle = personalizedTitle.replace(/\{\{date\}\}/g, currentDate);
    personalizedContent = personalizedContent.replace(/\{\{date\}\}/g, currentDate);
    placeholders.push({
      key: '{{date}}',
      value: currentDate
    });

    return {
      template_id: template.template_id,
      title: personalizedTitle,
      content: personalizedContent,
      category: template.category || 'general',
      difficulty_level: template.difficulty_level,
      estimated_time_minutes: template.estimated_time_minutes,
      ffa_standards: template.ffa_standards || [],
      success_rate: template.success_rate,
      is_popular: template.is_popular,
      placeholders
    };
  });
}

// Helper function to record suggestion analytics
async function recordSuggestionAnalytics(analyticsData) {
  try {
    await supabase
      .from('suggestion_analytics')
      .insert({
        user_id: analyticsData.user_id,
        event_type: analyticsData.event_type,
        session_id: analyticsData.session_id || `session_${Date.now()}`,
        response_time_ms: analyticsData.response_time_ms,
        user_age_group: analyticsData.user_age_group,
        trigger_context: analyticsData.trigger_context
      });
  } catch (error) {
    console.error('Failed to record analytics:', error);
    // Don't throw - analytics failure shouldn't break the main function
  }
}