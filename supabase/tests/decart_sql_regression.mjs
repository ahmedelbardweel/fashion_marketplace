// Run after installing @electric-sql/pglite in build/decart-sql-check.
// Real PostgreSQL validation; Vault is a test double, not an encryption test.
import { PGlite } from '../../build/decart-sql-check/node_modules/@electric-sql/pglite/dist/index.js';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const db = new PGlite();
try {
  await assert.rejects(db.query("select 'x' ~ '[a-z]{20,512}'"), { code: '2201B' });
  await db.exec(`
    create role anon; create role authenticated;
    create schema auth; create schema vault;
    create function auth.uid() returns uuid language sql as
      $$ select '00000000-0000-0000-0000-000000000001'::uuid $$;
    create table public.profiles(id uuid, role text, is_active boolean);
    insert into public.profiles values(auth.uid(), 'admin', true);
    create table vault.secrets(id uuid default gen_random_uuid(), name text, secret text);
    create function vault.create_secret(k text, n text, d text) returns uuid
      language sql as $$ insert into vault.secrets(name,secret) values(n,k) returning id $$;
    create function vault.update_secret(i uuid, k text) returns void
      language sql as $$ update vault.secrets set secret=k where id=i $$;
  `);
  await db.exec(await readFile(new URL('../migrations/011_decart_postgres_validation.sql', import.meta.url), 'utf8'));
  let checks = 1;
  for (const prefix of ['dct_app_', 'dct_new-app_']) {
    for (const length of [20, 64, 255, 256, 512]) {
      const key = prefix + 'a'.repeat(length);
      await db.query('select public.admin_set_decart_api_key($1)', [key]);
      const result = await db.query('select secret from vault.secrets');
      assert.deepEqual(result.rows, [{secret: key}]);
      checks++;
    }
    for (const length of [0, 19, 513]) {
      await assert.rejects(db.query('select public.admin_set_decart_api_key($1)', [prefix + 'a'.repeat(length)]), {code:'22023'});
      checks++;
    }
  }
  for (const key of [null, '', 'dct_unknown_' + 'a'.repeat(20), 'dct_app_' + 'a'.repeat(20) + '\n', 'dct_app_' + 'a'.repeat(20) + '!']) {
    await assert.rejects(db.query('select public.admin_set_decart_api_key($1)', [key]), {code:'22023'});
    checks++;
  }
  await db.exec("update public.profiles set is_active=false");
  await assert.rejects(db.query('select public.admin_set_decart_api_key($1)', ['dct_app_' + 'a'.repeat(20)]), {code:'42501'});
  checks++;
  console.log(`${checks} PostgreSQL checks passed; old 2201B reproduced, migration 011 validated.`);
} finally {
  await db.close();
}
