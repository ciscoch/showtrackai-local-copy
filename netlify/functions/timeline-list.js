// ============================================================================
// ShowTrackAI Timeline List Function
// Purpose: Get timeline items with unified query support
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
      start_date,
      end_date,
      category,
      animal_id,
      item_types = 'journal,expense'
    } = params;

    console.log(`Fetching timeline items for user ${user.id} with params:`, params);

    const limitInt = parseInt(limit, 10);
    const offsetInt = parseInt(offset, 10);
    const itemTypesArray = item_types.split(',').map(t => t.trim());

    // Since we might not have the unified timeline view, we'll combine journal entries and expenses
    const timelineItems = [];

    // Fetch journal entries
    if (itemTypesArray.includes('journal')) {
      let journalQuery = supabase
        .from('journal_entries')
        .select(`
          id,
          title,
          description,
          date,
          category,
          duration,
          animal_id,
          tags,
          photos,
          quality_score,
          created_at
        `)
        .eq('user_id', user.id);

      // Apply filters
      if (category) journalQuery = journalQuery.eq('category', category);
      if (animal_id) journalQuery = journalQuery.eq('animal_id', animal_id);
      if (start_date) journalQuery = journalQuery.gte('date', start_date);
      if (end_date) journalQuery = journalQuery.lte('date', end_date);

      const { data: journalEntries, error: journalError } = await journalQuery;

      if (journalError) {
        console.error('Error fetching journal entries:', journalError);
      } else {
        // Add journal entries to timeline
        journalEntries.forEach(entry => {
          timelineItems.push({
            id: entry.id,
            date: entry.date,
            type: 'journal',
            title: entry.title,
            description: entry.description,
            animalId: entry.animal_id,
            animalName: null, // Would need to join with animals table
            amount: null,
            category: entry.category,
            tags: entry.tags,
            imageUrl: entry.photos && entry.photos.length > 0 ? entry.photos[0] : null,
            metadata: {
              duration: entry.duration,
              qualityScore: entry.quality_score,
              createdAt: entry.created_at
            }
          });
        });
      }
    }

    // Fetch expenses if table exists
    if (itemTypesArray.includes('expense')) {
      try {
        let expenseQuery = supabase
          .from('expenses')
          .select(`
            id,
            description,
            amount,
            date,
            category,
            animal_id,
            receipt_url,
            created_at
          `)
          .eq('user_id', user.id);

        // Apply filters
        if (category) expenseQuery = expenseQuery.eq('category', category);
        if (animal_id) expenseQuery = expenseQuery.eq('animal_id', animal_id);
        if (start_date) expenseQuery = expenseQuery.gte('date', start_date);
        if (end_date) expenseQuery = expenseQuery.lte('date', end_date);

        const { data: expenseEntries, error: expenseError } = await expenseQuery;

        if (expenseError) {
          console.error('Error fetching expenses (table may not exist):', expenseError);
        } else {
          // Add expenses to timeline
          expenseEntries.forEach(expense => {
            timelineItems.push({
              id: expense.id,
              date: expense.date,
              type: 'expense',
              title: `$${expense.amount} - ${expense.description}`,
              description: expense.description,
              animalId: expense.animal_id,
              animalName: null, // Would need to join with animals table
              amount: expense.amount,
              category: expense.category,
              tags: null,
              imageUrl: expense.receipt_url,
              metadata: {
                receiptUrl: expense.receipt_url,
                createdAt: expense.created_at
              }
            });
          });
        }
      } catch (error) {
        console.log('Expenses table not available, skipping expense items');
      }
    }

    // Sort by date descending
    timelineItems.sort((a, b) => new Date(b.date) - new Date(a.date));

    // Apply pagination
    const paginatedItems = timelineItems.slice(offsetInt, offsetInt + limitInt);
    const hasMore = timelineItems.length > offsetInt + limitInt;

    console.log(`Retrieved ${paginatedItems.length} timeline items for user ${user.id}`);

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        items: paginatedItems,
        totalCount: timelineItems.length,
        hasMore: hasMore,
        nextOffset: hasMore ? offsetInt + limitInt : null,
        pagination: {
          limit: limitInt,
          offset: offsetInt,
          total: timelineItems.length,
          hasMore: hasMore
        }
      })
    };

  } catch (error) {
    console.error('Error in timeline-list function:', error);
    
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