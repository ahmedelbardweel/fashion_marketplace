export async function resolveDecartApiKey(
  url: string,
  serviceKey: string,
  legacyKey: string | undefined,
  fetcher: typeof fetch = fetch,
): Promise<string | undefined> {
  const response = await fetcher(`${url}/rest/v1/rpc/service_decart_api_key`, {
    method: 'POST',
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      'Content-Type': 'application/json',
    },
    body: '{}',
    signal: AbortSignal.timeout(10000),
  });
  // Never silently revert to an old key when the database is unavailable.
  if (!response.ok) throw new Error('Secret storage unavailable');
  const savedKey: unknown = await response.json();
  if (savedKey === null) return legacyKey;
  if (typeof savedKey !== 'string' || savedKey.trim() !== savedKey ||
      !/^dct_(app|new-app)_[A-Za-z0-9]{20,512}$/.test(savedKey)) {
    throw new Error('Invalid secret storage response');
  }
  return savedKey;
}
