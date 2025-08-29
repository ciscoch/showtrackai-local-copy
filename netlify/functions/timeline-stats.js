// ============================================================================
// ShowTrackAI Timeline Statistics Function
// Purpose: Get timeline statistics and analytics
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
      start_date,
      end_date
    } = params;

    console.log(`Fetching timeline statistics for user ${user.id}`);

    // Initialize statistics object
    const stats = {
      totalItems: 0,
      journalCount: 0,
      expenseCount: 0,
      totalExpenses: 0,
      averageQuality: null,
      categories: [],
      startDate: null,
      endDate: null,
      weeklyActivity: {}
    };

    // Get journal statistics
    let journalQuery = supabase
      .from('journal_entries')
      .select(`
        category,
        quality_score,
        date,
        created_at
      `)
      .eq('user_id', user.id);

    if (start_date) journalQuery = journalQuery.gte('date', start_date);
    if (end_date) journalQuery = journalQuery.lte('date', end_date);

    const { data: journalEntries, error: journalError } = await journalQuery;

    if (journalError) {
      console.error('Error fetching journal statistics:', journalError);
    } else {
      stats.journalCount = journalEntries.length;
      stats.totalItems += journalEntries.length;

      // Calculate quality average
      const qualityScores = journalEntries
        .map(entry => entry.quality_score)
        .filter(score => score != null);
      
      if (qualityScores.length > 0) {
        stats.averageQuality = qualityScores.reduce((sum, score) => sum + score, 0) / qualityScores.length;
      }

      // Collect categories
      journalEntries.forEach(entry => {
        if (entry.category && !stats.categories.includes(entry.category)) {
          stats.categories.push(entry.category);
        }

        // Weekly activity tracking
        const date = new Date(entry.date || entry.created_at);
        const week = getWeekKey(date);
        stats.weeklyActivity[week] = (stats.weeklyActivity[week] || 0) + 1;
      });

      // Set date range
      if (journalEntries.length > 0) {
        const dates = journalEntries.map(entry => new Date(entry.date || entry.created_at));
        stats.startDate = new Date(Math.min(...dates)).toISOString();
        stats.endDate = new Date(Math.max(...dates)).toISOString();
      }
    }

    // Get expense statistics (if table exists)
    try {
      let expenseQuery = supabase
        .from('expenses')
        .select(`
          category,
          amount,
          date,
          created_at
        `)
        .eq('user_id', user.id);

      if (start_date) expenseQuery = expenseQuery.gte('date', start_date);
      if (end_date) expenseQuery = expenseQuery.lte('date', end_date);

      const { data: expenseEntries, error: expenseError } = await expenseQuery;

      if (expenseError) {
        console.error('Error fetching expense statistics (table may not exist):', expenseError);
      } else {
        stats.expenseCount = expenseEntries.length;
        stats.totalItems += expenseEntries.length;

        // Calculate total expenses
        stats.totalExpenses = expenseEntries.reduce((sum, expense) => sum + (expense.amount || 0), 0);

        // Collect categories from expenses
        expenseEntries.forEach(expense => {
          if (expense.category && !stats.categories.includes(expense.category)) {
            stats.categories.push(expense.category);
          }

          // Weekly activity tracking
          const date = new Date(expense.date || expense.created_at);
          const week = getWeekKey(date);
          stats.weeklyActivity[week] = (stats.weeklyActivity[week] || 0) + 1;
        });

        // Update date range if expenses extend it
        if (expenseEntries.length > 0) {
          const dates = expenseEntries.map(expense => new Date(expense.date || expense.created_at));
          const minDate = new Date(Math.min(...dates));
          const maxDate = new Date(Math.max(...dates));

          if (!stats.startDate || minDate < new Date(stats.startDate)) {
            stats.startDate = minDate.toISOString();
          }
          if (!stats.endDate || maxDate > new Date(stats.endDate)) {
            stats.endDate = maxDate.toISOString();
          }
        }
      }
    } catch (error) {
      console.log('Expenses table not available, skipping expense statistics');
    }

    console.log(`Retrieved timeline statistics for user ${user.id}: ${stats.totalItems} total items`);

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        total_items: stats.totalItems,
        journal_count: stats.journalCount,
        expense_count: stats.expenseCount,
        total_expenses: stats.totalExpenses,
        average_quality: stats.averageQuality,
        categories: stats.categories,
        date_range: {
          start: stats.startDate,
          end: stats.endDate
        },
        weekly_activity: stats.weeklyActivity
      })
    };

  } catch (error) {
    console.error('Error in timeline-stats function:', error);
    
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

// Helper function to generate week key for activity tracking
function getWeekKey(date) {
  const year = date.getFullYear();
  const month = date.getMonth();
  const day = date.getDate();
  
  // Get the start of the week (Sunday)
  const startOfWeek = new Date(year, month, day - date.getDay());
  
  return `${startOfWeek.getFullYear()}-W${Math.ceil((startOfWeek - new Date(startOfWeek.getFullYear(), 0, 1)) / (7 * 24 * 60 * 60 * 1000))}`;
}