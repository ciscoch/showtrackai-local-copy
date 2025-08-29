// ============================================================================
// ShowTrackAI Journal Entry List Function
// Purpose: Get journal entries with filtering and pagination
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
      limit = '20',
      offset = '0',
      category,
      animal_id,
      start_date,
      end_date,
      tags
    } = params;

    console.log(`Fetching journal entries for user ${user.id} with params:`, params);

    // Build query
    let query = supabase
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
      .eq('user_id', user.id)
      .order('created_at', { ascending: false });

    // Apply filters
    if (category) {
      query = query.eq('category', category);
    }
    
    if (animal_id) {
      query = query.eq('animal_id', animal_id);
    }
    
    if (start_date) {
      query = query.gte('date', start_date);
    }
    
    if (end_date) {
      query = query.lte('date', end_date);
    }

    // Apply pagination
    const limitInt = parseInt(limit, 10);
    const offsetInt = parseInt(offset, 10);
    
    if (limitInt > 0) {
      query = query.limit(limitInt);
    }
    
    if (offsetInt > 0) {
      query = query.range(offsetInt, offsetInt + limitInt - 1);
    }

    const { data: entries, error: fetchError } = await query;

    if (fetchError) {
      console.error('Database fetch error:', fetchError);
      return {
        statusCode: 500,
        headers,
        body: JSON.stringify({ 
          error: 'Failed to fetch journal entries',
          details: fetchError.message
        })
      };
    }

    // Filter by tags if provided (client-side filtering since Supabase doesn't have easy array contains)
    let filteredEntries = entries;
    if (tags) {
      const tagArray = tags.split(',').map(t => t.trim());
      filteredEntries = entries.filter(entry => {
        if (!entry.tags || !Array.isArray(entry.tags)) return false;
        return tagArray.some(tag => entry.tags.includes(tag));
      });
    }

    // Convert database format to client format
    const formattedEntries = filteredEntries.map(entry => ({
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
    }));

    console.log(`Retrieved ${formattedEntries.length} journal entries for user ${user.id}`);

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        data: formattedEntries,
        pagination: {
          limit: limitInt,
          offset: offsetInt,
          total: formattedEntries.length,
          hasMore: formattedEntries.length === limitInt
        }
      })
    };

  } catch (error) {
    console.error('Error in journal-list function:', error);
    
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