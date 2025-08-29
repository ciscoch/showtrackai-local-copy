// ============================================================================
// ShowTrackAI Journal Entry Update Function
// Purpose: Update existing journal entries
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
    // Extract trace ID for debugging
    const traceId = event.headers['x-trace-id'] || `update_${Date.now()}`;
    
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
    if (!journalEntry.id) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ 
          error: 'Missing required field: id',
          traceId 
        })
      };
    }

    console.log(`[TRACE_ID: ${traceId}] Updating journal entry ${journalEntry.id} for user ${user.id}`);

    // First check if the entry exists and belongs to the user
    const { data: existingEntry, error: fetchError } = await supabase
      .from('journal_entries')
      .select('id, user_id')
      .eq('id', journalEntry.id)
      .eq('user_id', user.id)
      .single();

    if (fetchError || !existingEntry) {
      return {
        statusCode: 404,
        headers,
        body: JSON.stringify({ 
          error: 'Journal entry not found',
          traceId 
        })
      };
    }

    // Prepare update data
    const updateData = {};
    const now = new Date().toISOString();
    updateData.updated_at = now;
    
    // Map client fields to database fields
    if (journalEntry.title !== undefined) updateData.title = journalEntry.title;
    if (journalEntry.description !== undefined) updateData.description = journalEntry.description;
    if (journalEntry.date !== undefined) updateData.date = journalEntry.date;
    if (journalEntry.duration !== undefined) updateData.duration = journalEntry.duration;
    if (journalEntry.category !== undefined) updateData.category = journalEntry.category;
    if (journalEntry.aetSkills !== undefined) updateData.aet_skills = journalEntry.aetSkills;
    if (journalEntry.animalId !== undefined) updateData.animal_id = journalEntry.animalId;
    if (journalEntry.feedData !== undefined) updateData.feed_data = journalEntry.feedData;
    if (journalEntry.objectives !== undefined) updateData.objectives = journalEntry.objectives;
    if (journalEntry.learningOutcomes !== undefined) updateData.learning_outcomes = journalEntry.learningOutcomes;
    if (journalEntry.challenges !== undefined) updateData.challenges = journalEntry.challenges;
    if (journalEntry.improvements !== undefined) updateData.improvements = journalEntry.improvements;
    if (journalEntry.photos !== undefined) updateData.photos = journalEntry.photos;
    if (journalEntry.qualityScore !== undefined) updateData.quality_score = journalEntry.qualityScore;
    if (journalEntry.ffaStandards !== undefined) updateData.ffa_standards = journalEntry.ffaStandards;
    if (journalEntry.educationalConcepts !== undefined) updateData.educational_concepts = journalEntry.educationalConcepts;
    if (journalEntry.competencyLevel !== undefined) updateData.competency_level = journalEntry.competencyLevel;
    if (journalEntry.aiInsights !== undefined) updateData.ai_insights = journalEntry.aiInsights;
    if (journalEntry.locationData !== undefined) updateData.location_data = journalEntry.locationData;
    if (journalEntry.weatherData !== undefined) updateData.weather_data = journalEntry.weatherData;
    if (journalEntry.attachmentUrls !== undefined) updateData.attachment_urls = journalEntry.attachmentUrls;
    if (journalEntry.tags !== undefined) updateData.tags = journalEntry.tags;
    if (journalEntry.supervisorId !== undefined) updateData.supervisor_id = journalEntry.supervisorId;
    if (journalEntry.isPublic !== undefined) updateData.is_public = journalEntry.isPublic;
    if (journalEntry.competencyTracking !== undefined) updateData.competency_tracking = journalEntry.competencyTracking;
    if (journalEntry.ffaDegreeType !== undefined) updateData.ffa_degree_type = journalEntry.ffaDegreeType;
    if (journalEntry.countsForDegree !== undefined) updateData.counts_for_degree = journalEntry.countsForDegree;
    if (journalEntry.saType !== undefined) updateData.sa_type = journalEntry.saType;
    if (journalEntry.hoursLogged !== undefined) updateData.hours_logged = journalEntry.hoursLogged;
    if (journalEntry.financialValue !== undefined) updateData.financial_value = journalEntry.financialValue;
    if (journalEntry.evidenceType !== undefined) updateData.evidence_type = journalEntry.evidenceType;
    if (journalEntry.source !== undefined) updateData.source = journalEntry.source;
    if (journalEntry.notes !== undefined) updateData.notes = journalEntry.notes;
    if (traceId) updateData.trace_id = traceId;
    updateData.is_synced = true;

    // Update in Supabase
    const { data: updatedEntry, error: updateError } = await supabase
      .from('journal_entries')
      .update(updateData)
      .eq('id', journalEntry.id)
      .eq('user_id', user.id)
      .select()
      .single();

    if (updateError) {
      console.error(`[TRACE_ID: ${traceId}] Database update error:`, updateError);
      return {
        statusCode: 500,
        headers,
        body: JSON.stringify({ 
          error: 'Failed to update journal entry',
          details: updateError.message,
          traceId 
        })
      };
    }

    console.log(`[TRACE_ID: ${traceId}] Journal entry updated successfully: ${updatedEntry.id}`);

    // Return the updated entry in the expected format
    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        data: {
          id: updatedEntry.id,
          userId: updatedEntry.user_id,
          title: updatedEntry.title,
          description: updatedEntry.description,
          date: updatedEntry.date,
          duration: updatedEntry.duration,
          category: updatedEntry.category,
          aetSkills: updatedEntry.aet_skills,
          animalId: updatedEntry.animal_id,
          feedData: updatedEntry.feed_data,
          objectives: updatedEntry.objectives,
          learningOutcomes: updatedEntry.learning_outcomes,
          challenges: updatedEntry.challenges,
          improvements: updatedEntry.improvements,
          photos: updatedEntry.photos,
          qualityScore: updatedEntry.quality_score,
          ffaStandards: updatedEntry.ffa_standards,
          educationalConcepts: updatedEntry.educational_concepts,
          competencyLevel: updatedEntry.competency_level,
          aiInsights: updatedEntry.ai_insights,
          locationData: updatedEntry.location_data,
          weatherData: updatedEntry.weather_data,
          attachmentUrls: updatedEntry.attachment_urls,
          tags: updatedEntry.tags,
          supervisorId: updatedEntry.supervisor_id,
          isPublic: updatedEntry.is_public,
          competencyTracking: updatedEntry.competency_tracking,
          ffaDegreeType: updatedEntry.ffa_degree_type,
          countsForDegree: updatedEntry.counts_for_degree,
          saType: updatedEntry.sa_type,
          hoursLogged: updatedEntry.hours_logged,
          financialValue: updatedEntry.financial_value,
          evidenceType: updatedEntry.evidence_type,
          source: updatedEntry.source,
          notes: updatedEntry.notes,
          traceId: updatedEntry.trace_id,
          createdAt: updatedEntry.created_at,
          updatedAt: updatedEntry.updated_at,
          isSynced: updatedEntry.is_synced
        },
        traceId
      })
    };

  } catch (error) {
    console.error('Error in journal-update function:', error);
    
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