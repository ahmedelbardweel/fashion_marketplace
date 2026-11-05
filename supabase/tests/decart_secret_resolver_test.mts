import { test } from 'node:test';
import assert from 'node:assert/strict';
import { resolveDecartApiKey } from '../functions/decart-session/secret_resolver.ts';

test('stored key overrides the environment and stays server-to-server', async () => {
  const key = await resolveDecartApiKey('https://project.supabase.co', 'server-key',
    'legacy-key', async (url, init) => {
      assert.equal(url, 'https://project.supabase.co/rest/v1/rpc/service_decart_api_key');
      assert.equal(init?.method, 'POST');
      assert.equal(new Headers(init?.headers).get('Authorization'), 'Bearer server-key');
      assert.equal(init?.body, '{}');
      return Response.json('dct_app_12345678901234567890');
    });
  assert.equal(key, 'dct_app_12345678901234567890');
});

test('new-app keys are returned intact without falling back to the old key', async () => {
  const savedKey = 'dct_new-app_12345678901234567890';
  const key = await resolveDecartApiKey('https://project.supabase.co', 'server-key',
    'legacy-key', async () => Response.json(savedKey));
  assert.equal(key, savedKey);
});

test('only an absent saved key falls back to the existing environment', async () => {
  const key = await resolveDecartApiKey('https://project.supabase.co', 'server-key',
    'legacy-key', async () => Response.json(null));
  assert.equal(key, 'legacy-key');
});

test('database failures never silently use a superseded key or expose raw errors', async () => {
  await assert.rejects(resolveDecartApiKey('https://project.supabase.co', 'server-key',
    'legacy-key', async () => new Response('sensitive-upstream-body', { status: 500 })),
    { message: 'Secret storage unavailable' });
});

test('invalid responses do not get forwarded to Decart', async () => {
  for (const invalid of ['', {}, [], 123, 'other-secret', 'dct_app_short',
    'dct_new-app_short', 'dct_unknown_12345678901234567890',
    'dct_new-app_12345678901234567890\n', `dct_app_${'a'.repeat(513)}`]) {
    await assert.rejects(resolveDecartApiKey('https://project.supabase.co', 'server-key',
      'legacy-key', async () => Response.json(invalid)),
      { message: 'Invalid secret storage response' });
  }
});
