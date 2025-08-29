// ============================================================================
// ShowTrackAI Journal Entry Delete Function
// Purpose: Delete journal entries with proper authorization
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
    'Access-Control-Allow-Methods': 'DELETE, OPTIONS',
    'Content-Type': 'application/json',
  };

  // Handle preflight requests
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers, body: '' };
  }

  // Only allow DELETE requests
  if (event.httpMethod !== 'DELETE') {
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

    console.log(`Deleting journal entry ${id} for user ${user.id}`);

    // First check if the entry exists and belongs to the user
    const { data: existingEntry, error: fetchError } = await supabase
      .from('journal_entries')
      .select('id, user_id, title')
      .eq('id', id)
      .eq('user_id', user.id)
      .single();

    if (fetchError || !existingEntry) {
      return {
        statusCode: 404,
        headers,
        body: JSON.stringify({ error: 'Journal entry not found' })
      };
    }

    // Delete the entry
    const { error: deleteError } = await supabase
      .from('journal_entries')
      .delete()
      .eq('id', id)
      .eq('user_id', user.id);

    if (deleteError) {
      console.error('Database delete error:', deleteError);
      return {
        statusCode: 500,
        headers,
        body: JSON.stringify({ 
          error: 'Failed to delete journal entry',
          details: deleteError.message
        })
      };
    }

    console.log(`Journal entry ${id} deleted successfully for user ${user.id}`);

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        success: true,
        message: 'Journal entry deleted successfully',
        data: {
          deletedId: id,
          title: existingEntry.title
        }
      })
    };

  } catch (error) {
    console.error('Error in journal-delete function:', error);
    
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