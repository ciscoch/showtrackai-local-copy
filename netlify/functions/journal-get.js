// ============================================================================
// ShowTrackAI Journal Entry Get Function
// Purpose: Get a single journal entry by ID
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

    // Get entry ID from query parameters
    const params = event.queryStringParameters || {};
    const { id } = params;

    if (!id) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ error: 'Missing required parameter: id' })
      };
    }

    console.log(`Fetching journal entry ${id} for user ${user.id}`);

    // Fetch the entry
    const { data: entry, error: fetchError } = await supabase
      .from('journal_entries')
      .select(`
        id,
        user_id,
        title,
        description,
        date,
        duration,
        category,
        aet_skills,
        animal_id,
        feed_data,
        objectives,
        learning_outcomes,
        challenges,
        improvements,
        photos,
        quality_score,
        ffa_standards,
        educational_concepts,
        competency_level,
        ai_insights,
        location_data,
        weather_data,
        attachment_urls,
        tags,
        supervisor_id,
        is_public,
        competency_tracking,
        ffa_degree_type,
        counts_for_degree,
        sa_type,
        hours_logged,
        financial_value,
        evidence_type,
        source,
        notes,
        trace_id,
        created_at,
        updated_at,
        is_synced
      `)
      .eq('id', id)
      .eq('user_id', user.id)
      .single();

    if (fetchError || !entry) {
      if (fetchError?.code === 'PGRST116') {
        // No rows found
        return {
          statusCode: 404,
          headers,
          body: JSON.stringify({ error: 'Journal entry not found' })
        };
      } else {
        console.error('Database fetch error:', fetchError);
        return {
          statusCode: 500,
          headers,
          body: JSON.stringify({ 
            error: 'Failed to fetch journal entry',
            details: fetchError?.message
          })
        };
      }
    }

    // Convert database format to client format
    const formattedEntry = {
      id: entry.id,
      userId: entry.user_id,
      title: entry.title,
      description: entry.description,
      date: entry.date,
      duration: entry.duration,
      category: entry.category,
      aetSkills: entry.aet_skills,
      animalId: entry.animal_id,
      feedData: entry.feed_data,
      objectives: entry.objectives,
      learningOutcomes: entry.learning_outcomes,
      challenges: entry.challenges,
      improvements: entry.improvements,
      photos: entry.photos,
      qualityScore: entry.quality_score,
      ffaStandards: entry.ffa_standards,
      educationalConcepts: entry.educational_concepts,
      competencyLevel: entry.competency_level,
      aiInsights: entry.ai_insights,
      locationData: entry.location_data,
      weatherData: entry.weather_data,
      attachmentUrls: entry.attachment_urls,
      tags: entry.tags,
      supervisorId: entry.supervisor_id,
      isPublic: entry.is_public,
      competencyTracking: entry.competency_tracking,
      ffaDegreeType: entry.ffa_degree_type,
      countsForDegree: entry.counts_for_degree,
      saType: entry.sa_type,
      hoursLogged: entry.hours_logged,
      financialValue: entry.financial_value,
      evidenceType: entry.evidence_type,
      source: entry.source,
      notes: entry.notes,
      traceId: entry.trace_id,
      createdAt: entry.created_at,
      updatedAt: entry.updated_at,
      isSynced: entry.is_synced
    };

    console.log(`Retrieved journal entry ${id} for user ${user.id}`);

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        data: formattedEntry
      })
    };

  } catch (error) {
    console.error('Error in journal-get function:', error);
    
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