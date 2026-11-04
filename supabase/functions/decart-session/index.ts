// Deploy with JWT verification enabled. No permanent key is returned to Flutter.
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const respond = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...cors, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
});

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (request.method !== 'POST') return respond({ error: 'Method not allowed' }, 405);
  const authorization = request.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) return respond({ error: 'Unauthorized' }, 401);
  try {
    const url = Deno.env.get('SUPABASE_URL');
    const anon = Deno.env.get('SUPABASE_ANON_KEY');
    const apiKey = Deno.env.get('DECART_API_KEY');
    if (!url || !anon || !apiKey) return respond({ error: 'Service not configured' }, 503);
    // Validate the caller with Auth rather than trusting decoded JWT claims.
    const auth = await fetch(`${url}/auth/v1/user`, {
      headers: { Authorization: authorization, apikey: anon },
      signal: AbortSignal.timeout(10000),
    });
    if (!auth.ok) return respond({ error: 'Unauthorized' }, 401);
    const user = await auth.json();
    if (!user.id || user.is_anonymous) return respond({ error: 'Unauthorized' }, 401);
    const model = 'lucy-vton-3.6';
    const response = await fetch('https://api.decart.ai/v1/client/tokens', {
      method: 'POST',
      headers: { 'x-api-key': apiKey, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        expiresIn: 60,
        allowedModels: [model],
        constraints: { realtime: { maxSessionDuration: 120 } },
      }),
      signal: AbortSignal.timeout(10000),
    });
    if (!response.ok) return respond({ error: 'Unable to create session' }, 502);
    const token = await response.json();
    if (typeof token.apiKey !== 'string' || !token.apiKey) {
      return respond({ error: 'Invalid session response' }, 502);
    }
    const iceServers = [{ urls: 'stun:stun.l.google.com:19302' }];
    // Supply short-lived TURN credentials from your TURN credential service.
    // This environment hook also supports development TURN deployments.
    const turnConfig = Deno.env.get('DECART_ICE_SERVERS_JSON');
    return respond({
      apiKey: token.apiKey, expiresAt: token.expiresAt, model,
      iceServers: turnConfig ? JSON.parse(turnConfig) : iceServers,
      relayOnly: Deno.env.get('DECART_RELAY_ONLY') === 'true',
    });
  } catch {
    // Never echo upstream bodies, URLs, or credentials to clients/logs.
    return respond({ error: 'Session service unavailable' }, 503);
  }
});
