// ============================================================================
// ShowTrackAI Journal Entry Creation Function
// Purpose: Create new journal entries with AI processing integration
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
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-trace-id',
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
    // Extract trace ID for debugging
    const traceId = event.headers['x-trace-id'] || `create_${Date.now()}`;
    
    // Extract and validate authorization
    const authHeader = event.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return {
        statusCode: 401,
        headers,
        body: JSON.stringify({ 
          error: 'Authorization required',
          traceId 
        })
      };
    }

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return {
        statusCode: 401,
        headers,
        body: JSON.stringify({ 
          error: 'Invalid token',
          traceId 
        })
      };
    }

    // Parse and validate request body
    let journalEntry;
    try {
      journalEntry = JSON.parse(event.body);
    } catch (parseError) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ 
          error: 'Invalid JSON in request body',
          traceId 
        })
      };
    }

    // Validate required fields
    if (!journalEntry.title || !journalEntry.description) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ 
          error: 'Missing required fields: title and description',
          traceId 
        })
      };
    }

    // Ensure user ID matches authenticated user
    journalEntry.userId = user.id;
    journalEntry.user_id = user.id; // Database column name
    
    // Set timestamps
    const now = new Date().toISOString();
    journalEntry.created_at = now;
    journalEntry.updated_at = now;
    
    // Ensure ID is set
    if (!journalEntry.id) {
      journalEntry.id = `journal_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    }

    console.log(`[TRACE_ID: ${traceId}] Creating journal entry for user ${user.id}`);

    // Insert into Supabase
    const { data: createdEntry, error: insertError } = await supabase
      .from('journal_entries')
      .insert({
        id: journalEntry.id,
        user_id: user.id,
        title: journalEntry.title,
        description: journalEntry.description,
        date: journalEntry.date || now,
        duration: journalEntry.duration || 60,
        category: journalEntry.category || 'general',
        aet_skills: journalEntry.aetSkills || journalEntry.aet_skills || [],
        animal_id: journalEntry.animalId || journalEntry.animal_id,
        feed_data: journalEntry.feedData || journalEntry.feed_data,
        objectives: journalEntry.objectives || [],
        learning_outcomes: journalEntry.learningOutcomes || journalEntry.learning_outcomes || [],
        challenges: journalEntry.challenges || [],
        improvements: journalEntry.improvements || [],
        photos: journalEntry.photos || [],
        quality_score: journalEntry.qualityScore || journalEntry.quality_score,
        ffa_standards: journalEntry.ffaStandards || journalEntry.ffa_standards || [],
        educational_concepts: journalEntry.educationalConcepts || journalEntry.educational_concepts || [],
        competency_level: journalEntry.competencyLevel || journalEntry.competency_level || 'developing',
        ai_insights: journalEntry.aiInsights || journalEntry.ai_insights,
        location_data: journalEntry.locationData || journalEntry.location_data,
        weather_data: journalEntry.weatherData || journalEntry.weather_data,
        attachment_urls: journalEntry.attachmentUrls || journalEntry.attachment_urls || [],
        tags: journalEntry.tags || [],
        supervisor_id: journalEntry.supervisorId || journalEntry.supervisor_id,
        is_public: journalEntry.isPublic || journalEntry.is_public || false,
        competency_tracking: journalEntry.competencyTracking || journalEntry.competency_tracking,
        ffa_degree_type: journalEntry.ffaDegreeType || journalEntry.ffa_degree_type,
        counts_for_degree: journalEntry.countsForDegree || journalEntry.counts_for_degree || false,
        sa_type: journalEntry.saType || journalEntry.sa_type,
        hours_logged: journalEntry.hoursLogged || journalEntry.hours_logged || 0,
        financial_value: journalEntry.financialValue || journalEntry.financial_value || 0,
        evidence_type: journalEntry.evidenceType || journalEntry.evidence_type,
        source: journalEntry.source,
        notes: journalEntry.notes,
        trace_id: traceId,
        created_at: now,
        updated_at: now,
        is_synced: true
      })
      .select()
      .single();

    if (insertError) {
      console.error(`[TRACE_ID: ${traceId}] Database insert error:`, insertError);
      return {
        statusCode: 500,
        headers,
        body: JSON.stringify({ 
          error: 'Failed to create journal entry',
          details: insertError.message,
          traceId 
        })
      };
    }

    console.log(`[TRACE_ID: ${traceId}] Journal entry created successfully: ${createdEntry.id}`);

    // Return the created entry in the expected format
    return {
      statusCode: 201,
      headers,
      body: JSON.stringify({
        data: {
          id: createdEntry.id,
          userId: createdEntry.user_id,
          title: createdEntry.title,
          description: createdEntry.description,
          date: createdEntry.date,
          duration: createdEntry.duration,
          category: createdEntry.category,
          aetSkills: createdEntry.aet_skills,
          animalId: createdEntry.animal_id,
          feedData: createdEntry.feed_data,
          objectives: createdEntry.objectives,
          learningOutcomes: createdEntry.learning_outcomes,
          challenges: createdEntry.challenges,
          improvements: createdEntry.improvements,
          photos: createdEntry.photos,
          qualityScore: createdEntry.quality_score,
          ffaStandards: createdEntry.ffa_standards,
          educationalConcepts: createdEntry.educational_concepts,
          competencyLevel: createdEntry.competency_level,
          aiInsights: createdEntry.ai_insights,
          locationData: createdEntry.location_data,
          weatherData: createdEntry.weather_data,
          attachmentUrls: createdEntry.attachment_urls,
          tags: createdEntry.tags,
          supervisorId: createdEntry.supervisor_id,
          isPublic: createdEntry.is_public,
          competencyTracking: createdEntry.competency_tracking,
          ffaDegreeType: createdEntry.ffa_degree_type,
          countsForDegree: createdEntry.counts_for_degree,
          saType: createdEntry.sa_type,
          hoursLogged: createdEntry.hours_logged,
          financialValue: createdEntry.financial_value,
          evidenceType: createdEntry.evidence_type,
          source: createdEntry.source,
          notes: createdEntry.notes,
          traceId: createdEntry.trace_id,
          createdAt: createdEntry.created_at,
          updatedAt: createdEntry.updated_at,
          isSynced: createdEntry.is_synced
        },
        traceId
      })
    };

  } catch (error) {
    console.error('Error in journal-create function:', error);
    
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({
        error: 'Internal server error',
        message: error.message,
        traceId: event.headers['x-trace-id'] || 'unknown'
      })
    };
  }
};