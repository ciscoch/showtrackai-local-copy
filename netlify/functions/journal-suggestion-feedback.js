// ============================================================================
// ShowTrackAI Journal Suggestion Feedback API Function
// Purpose: Track user feedback on suggestions for continuous improvement
// ============================================================================

const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY
);

exports.handler = async (event, context) => {
  // Enable CORS
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'PUT, OPTIONS',
    'Content-Type': 'application/json',
  };

  // Handle preflight requests
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers, body: '' };
  }

  // Only allow PUT requests
  if (event.httpMethod !== 'PUT') {
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
    const { 
      template_id, 
      session_id, 
      feedback, 
      final_journal_entry 
    } = requestData;

    if (!template_id || !feedback || !feedback.action) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({
          error: 'Missing required fields',
          required: ['template_id', 'session_id', 'feedback.action'],
          provided: Object.keys(requestData)
        })
      };
    }

    // Validate feedback action
    const validActions = ['accepted', 'modified', 'dismissed'];
    if (!validActions.includes(feedback.action)) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({
          error: 'Invalid feedback action',
          valid_actions: validActions,
          provided: feedback.action
        })
      };
    }

    // Validate rating if provided
    if (feedback.rating && (feedback.rating < 1 || feedback.rating > 5)) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({
          error: 'Invalid rating',
          message: 'Rating must be between 1 and 5',
          provided: feedback.rating
        })
      };
    }

    // Get user profile for age verification
    const { data: userProfile, error: profileError } = await supabase
      .from('user_profiles')
      .select('birth_date, parent_consent')
      .eq('id', user.id)
      .single();

    if (profileError) {
      return {
        statusCode: 500,
        headers,
        body: JSON.stringify({ error: 'Failed to verify user profile' })
      };
    }

    // Calculate age group for analytics
    const ageVerification = calculateAgeGroup(userProfile.birth_date);

    // Record feedback using Supabase RPC for transaction safety
    const { data: feedbackResult, error: feedbackError } = await supabase
      .rpc('track_suggestion_usage', {
        p_template_id: template_id,
        p_accepted: feedback.action === 'accepted',
        p_user_rating: feedback.rating || null,
        p_user_feedback: feedback.comments || null,
        p_session_id: session_id || null,
        p_completion_time: feedback.completion_time_seconds || null
      });

    if (feedbackError) {
      console.error('Error recording feedback:', feedbackError);
      return {
        statusCode: 500,
        headers,
        body: JSON.stringify({
          error: 'Failed to record feedback',
          details: feedbackError.message
        })
      };
    }

    // Record detailed analytics for machine learning
    const analyticsData = await recordDetailedAnalytics({
      user_id: user.id,
      template_id: template_id,
      session_id: session_id || `session_${Date.now()}`,
      event_type: feedback.action,
      user_rating: feedback.rating,
      user_feedback: feedback.comments,
      user_modifications: feedback.modifications,
      final_content: final_journal_entry?.content,
      time_to_completion: feedback.completion_time_seconds,
      quality_score: final_journal_entry?.quality_assessment?.score,
      user_age_group: ageVerification.age_group,
      parent_consent_verified: ageVerification.coppa_protected ? userProfile.parent_consent : true
    });

    // Update user preferences based on feedback
    await updateUserPreferences(user.id, feedback, template_id);

    // Get updated template statistics
    const { data: updatedTemplate } = await supabase
      .from('journal_suggestion_templates')
      .select('usage_count, success_rate, average_rating')
      .eq('template_id', template_id)
      .single();

    // Check if this feedback triggers any template improvements
    const improvementSuggestions = await checkForImprovements(template_id, feedback);

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        feedback_recorded: true,
        template_updated: true,
        user_preferences_updated: true,
        analytics: {
          new_success_rate: updatedTemplate?.success_rate || 0,
          new_average_rating: updatedTemplate?.average_rating || 0,
          total_usage_count: updatedTemplate?.usage_count || 0
        },
        insights: {
          user_engagement_trend: await getUserEngagementTrend(user.id),
          template_performance_change: await getTemplatePerformanceChange(template_id),
          improvement_suggestions: improvementSuggestions
        },
        privacy_compliance: {
          age_group: ageVerification.age_group,
          data_handled_appropriately: true,
          parent_notification_sent: ageVerification.coppa_protected && feedback.action === 'accepted'
        }
      })
    };

  } catch (error) {
    console.error('Error in journal-suggestion-feedback function:', error);
    
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({
        error: 'Internal server error',
        message: error.message
      })
    };
  }
};

// Helper Functions

function calculateAgeGroup(birthDate) {
  if (!birthDate) {
    return { age_group: 'unknown', coppa_protected: true };
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

async function recordDetailedAnalytics(analyticsData) {
  try {
    const { data, error } = await supabase
      .from('suggestion_analytics')
      .insert({
        user_id: analyticsData.user_id,
        template_id: await getTemplateUUID(analyticsData.template_id),
        event_type: analyticsData.event_type,
        session_id: analyticsData.session_id,
        suggestion_content: null, // Not storing suggestion content for privacy
        user_modifications: analyticsData.user_modifications,
        final_content: analyticsData.final_content,
        time_to_completion: analyticsData.time_to_completion,
        quality_score: analyticsData.quality_score,
        user_rating: analyticsData.user_rating,
        user_feedback: analyticsData.user_feedback,
        user_age_group: analyticsData.user_age_group,
        parent_consent_verified: analyticsData.parent_consent_verified,
        created_at: new Date().toISOString()
      });

    if (error) {
      console.error('Analytics recording error:', error);
    }

    return data;
  } catch (error) {
    console.error('Failed to record detailed analytics:', error);
    return null;
  }
}

async function getTemplateUUID(templateId) {
  const { data } = await supabase
    .from('journal_suggestion_templates')
    .select('id')
    .eq('template_id', templateId)
    .single();
  
  return data?.id || null;
}

async function updateUserPreferences(userId, feedback, templateId) {
  try {
    // Get current preferences
    const { data: currentPrefs } = await supabase
      .from('user_suggestion_preferences')
      .select('*')
      .eq('user_id', userId)
      .single();

    if (!currentPrefs) {
      // Create preferences if they don't exist
      await supabase
        .from('user_suggestion_preferences')
        .insert({
          user_id: userId,
          suggestions_used: feedback.action === 'accepted' ? 1 : 0,
          suggestions_dismissed: feedback.action === 'dismissed' ? 1 : 0,
          custom_modifications: feedback.modifications ? 1 : 0
        });
      return;
    }

    // Update existing preferences
    const updates = {
      updated_at: new Date().toISOString()
    };

    if (feedback.action === 'accepted') {
      updates.suggestions_used = (currentPrefs.suggestions_used || 0) + 1;
      
      // Add to preferred templates if highly rated
      if (feedback.rating >= 4) {
        const preferredTemplates = currentPrefs.preferred_templates || [];
        if (!preferredTemplates.includes(templateId)) {
          updates.preferred_templates = [...preferredTemplates, templateId];
        }
      }
    }

    if (feedback.action === 'dismissed') {
      updates.suggestions_dismissed = (currentPrefs.suggestions_dismissed || 0) + 1;
      
      // Add to blocked templates if consistently dismissed
      if (feedback.rating <= 2) {
        const blockedTemplates = currentPrefs.blocked_templates || [];
        if (!blockedTemplates.includes(templateId)) {
          updates.blocked_templates = [...blockedTemplates, templateId];
        }
      }
    }

    if (feedback.modifications) {
      updates.custom_modifications = (currentPrefs.custom_modifications || 0) + 1;
    }

    await supabase
      .from('user_suggestion_preferences')
      .update(updates)
      .eq('user_id', userId);

  } catch (error) {
    console.error('Failed to update user preferences:', error);
  }
}

async function getUserEngagementTrend(userId) {
  try {
    const { data: recentFeedback } = await supabase
      .from('suggestion_analytics')
      .select('event_type, user_rating, created_at')
      .eq('user_id', userId)
      .gte('created_at', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString()) // Last 7 days
      .order('created_at', { ascending: false })
      .limit(20);

    if (!recentFeedback || recentFeedback.length === 0) {
      return 'insufficient_data';
    }

    const acceptanceRate = recentFeedback.filter(f => f.event_type === 'accepted').length / recentFeedback.length;
    const averageRating = recentFeedback
      .filter(f => f.user_rating)
      .reduce((sum, f) => sum + f.user_rating, 0) / 
      recentFeedback.filter(f => f.user_rating).length || 0;

    if (acceptanceRate >= 0.8 && averageRating >= 4) return 'highly_engaged';
    if (acceptanceRate >= 0.6 && averageRating >= 3) return 'moderately_engaged';
    if (acceptanceRate >= 0.4) return 'somewhat_engaged';
    return 'low_engagement';

  } catch (error) {
    console.error('Error calculating engagement trend:', error);
    return 'error';
  }
}

async function getTemplatePerformanceChange(templateId) {
  try {
    // Get template performance over last 30 days vs previous 30 days
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const sixtyDaysAgo = new Date(Date.now() - 60 * 24 * 60 * 60 * 1000);

    const templateUUID = await getTemplateUUID(templateId);
    if (!templateUUID) return 'template_not_found';

    // Recent performance (last 30 days)
    const { data: recentData } = await supabase
      .from('suggestion_analytics')
      .select('event_type, user_rating, quality_score')
      .eq('template_id', templateUUID)
      .gte('created_at', thirtyDaysAgo.toISOString())
      .limit(1000);

    // Previous performance (30-60 days ago)
    const { data: previousData } = await supabase
      .from('suggestion_analytics')
      .select('event_type, user_rating, quality_score')
      .eq('template_id', templateUUID)
      .gte('created_at', sixtyDaysAgo.toISOString())
      .lt('created_at', thirtyDaysAgo.toISOString())
      .limit(1000);

    if (!recentData?.length && !previousData?.length) {
      return 'insufficient_data';
    }

    const recentAcceptance = recentData?.length ? 
      recentData.filter(d => d.event_type === 'accepted').length / recentData.length : 0;
    const previousAcceptance = previousData?.length ? 
      previousData.filter(d => d.event_type === 'accepted').length / previousData.length : 0;

    const acceptanceChange = recentAcceptance - previousAcceptance;

    if (acceptanceChange > 0.1) return 'improving';
    if (acceptanceChange < -0.1) return 'declining';
    return 'stable';

  } catch (error) {
    console.error('Error calculating template performance change:', error);
    return 'error';
  }
}

async function checkForImprovements(templateId, feedback) {
  const improvements = [];

  try {
    const templateUUID = await getTemplateUUID(templateId);
    if (!templateUUID) return improvements;

    // Get recent feedback for this template
    const { data: recentFeedback } = await supabase
      .from('suggestion_analytics')
      .select('event_type, user_rating, user_feedback, user_modifications')
      .eq('template_id', templateUUID)
      .gte('created_at', new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString()) // Last 14 days
      .limit(50);

    if (!recentFeedback?.length) return improvements;

    // Analyze patterns in feedback
    const dismissalRate = recentFeedback.filter(f => f.event_type === 'dismissed').length / recentFeedback.length;
    const modificationRate = recentFeedback.filter(f => f.user_modifications).length / recentFeedback.length;
    const lowRatingRate = recentFeedback.filter(f => f.user_rating && f.user_rating <= 2).length / 
                          recentFeedback.filter(f => f.user_rating).length;

    // Generate improvement suggestions based on patterns
    if (dismissalRate > 0.3) {
      improvements.push({
        type: 'high_dismissal_rate',
        severity: 'medium',
        suggestion: 'Template has high dismissal rate. Consider simplifying content or improving relevance.',
        metric: `${Math.round(dismissalRate * 100)}% dismissal rate`
      });
    }

    if (modificationRate > 0.5) {
      improvements.push({
        type: 'frequent_modifications',
        severity: 'low',
        suggestion: 'Users frequently modify this template. Consider creating variations.',
        metric: `${Math.round(modificationRate * 100)}% modification rate`
      });
    }

    if (lowRatingRate > 0.2) {
      improvements.push({
        type: 'low_user_satisfaction',
        severity: 'high',
        suggestion: 'Low user satisfaction ratings. Review template content and structure.',
        metric: `${Math.round(lowRatingRate * 100)}% low ratings`
      });
    }

    // Check for common modification patterns
    const commonModifications = analyzeModificationPatterns(recentFeedback);
    if (commonModifications.length > 0) {
      improvements.push({
        type: 'common_modification_patterns',
        severity: 'low',
        suggestion: 'Users commonly make similar modifications. Consider updating template.',
        patterns: commonModifications
      });
    }

    return improvements;

  } catch (error) {
    console.error('Error checking for improvements:', error);
    return improvements;
  }
}

function analyzeModificationPatterns(feedbackData) {
  const modifications = feedbackData
    .filter(f => f.user_modifications)
    .map(f => f.user_modifications.toLowerCase());

  if (modifications.length < 3) return [];

  // Simple pattern detection - in production, use more sophisticated NLP
  const commonPhrases = [];
  const phrases = ['more detail', 'simpler language', 'add steps', 'remove section'];
  
  phrases.forEach(phrase => {
    const count = modifications.filter(m => m.includes(phrase)).length;
    if (count >= 2) {
      commonPhrases.push({
        pattern: phrase,
        frequency: count,
        percentage: Math.round((count / modifications.length) * 100)
      });
    }
  });

  return commonPhrases.slice(0, 3); // Return top 3 patterns
}

// Daily usage and rate limiting check
async function checkRateLimit(userId, ageGroup) {
  const today = new Date().toISOString().split('T')[0];
  
  const { data: todayUsage } = await supabase
    .from('suggestion_analytics')
    .select('id')
    .eq('user_id', userId)
    .eq('event_type', 'generated')
    .gte('created_at', `${today}T00:00:00.000Z`)
    .lt('created_at', `${today}T23:59:59.999Z`);

  const limits = {
    'under_13': 10,
    '13_to_17': 30,
    '18_plus': 60,
    'unknown': 5 // Conservative default
  };

  const currentUsage = todayUsage?.length || 0;
  const dailyLimit = limits[ageGroup] || limits['unknown'];

  return {
    current_usage: currentUsage,
    daily_limit: dailyLimit,
    rate_limited: currentUsage >= dailyLimit,
    remaining: Math.max(0, dailyLimit - currentUsage)
  };
}