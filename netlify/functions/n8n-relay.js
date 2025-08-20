// netlify/functions/n8n-relay.js
export async function handler(event) {
  // CORS preflight
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-API-Key'
      }
    };
  }

  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  try {
    const body = event.body || '{}';

    // 🔁 Post body straight through to your n8n PRODUCTION webhook (not /webhook-test)
    const resp = await fetch(
      'https://showtrackai.app.n8n.cloud/webhook/4b52c2de-4d37-4752-aa5c-5741bd9e493d',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body
      }
    );

    const text = await resp.text(); // n8n may return text or JSON
    return {
      statusCode: resp.status,
      headers: { 'Access-Control-Allow-Origin': '*' },
      body: text
    };
  } catch (e) {
    return {
      statusCode: 502,
      headers: { 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({ error: 'Relay failed', detail: e.message })
    };
  }
}
