// Run with PGLITE_MODULE pointing to an installed @electric-sql/pglite module.
const { PGlite } = require(process.env.PGLITE_MODULE || '@electric-sql/pglite');
const fs = require('fs');
const assert = require('node:assert/strict');
(async () => {
 const db = new PGlite();
 await db.exec(`create role anon; create role authenticated;
 create type public.product_status as enum ('draft','published','hidden','deleted');
 create table categories(id uuid primary key default gen_random_uuid(), name text unique, is_active boolean default true);
 create table products(id uuid primary key default gen_random_uuid(),shop_id uuid,category_id uuid references categories(id),name text,description text,price numeric,status product_status,updated_at timestamptz default now());
 create table product_variants(id uuid primary key default gen_random_uuid(),product_id uuid references products(id),color text,size text,stock int check(stock>=0),is_active bool default true,updated_at timestamptz,unique(product_id,color,size));
 create table product_images(id uuid primary key default gen_random_uuid(),product_id uuid references products(id),file_path text,kind text,sort_order int);
 create function public.require_approved_shop() returns uuid language plpgsql as $$ begin
 if current_setting('test.shop',true) = '' then raise exception 'not approved'; end if;
 return current_setting('test.shop')::uuid; end $$;
 set test.shop = '11111111-1111-1111-1111-111111111111';`);
 const original = fs.readFileSync('supabase/migrations/004_shop_platform.sql','utf8');
 for (const name of ['shop_upsert_product','shop_upsert_variant']) {
  const start=original.indexOf('create or replace function public.'+name+'(');
  await db.exec(original.slice(start, original.indexOf('$$;',start)+3));
 }
 await db.exec(fs.readFileSync('supabase/migrations/012_shop_product_editor.sql','utf8'));
 const payload = {name:'فستان',description:'قطن',price:150,status:'published',new_category_name:'فساتين',details:{material:'قطن'},variants:[{color:'أسود',size:'M',stock:3},{color:'أسود',size:'L',stock:2}],images:[{path:'https://example.com/1.png',kind:'gallery'},{path:'https://example.com/2.png',kind:'gallery'}]};
 const save=async data => (await db.query('select * from public.shop_save_product_form($1::jsonb)',[JSON.stringify(data)])).rows[0];
 const created=await save(payload); assert.equal(created.details.material,'قطن');
 const variantId=(await db.query('select id from product_variants where size=\'M\'')).rows[0].id;
 const edited=await save({...payload,id:created.id,new_category_name:'فساتين',variants:[payload.variants[0]],images:[payload.images[1]]});
 assert.equal(created.id,edited.id);
 assert.equal((await db.query('select count(*)::int n from products')).rows[0].n,1);
 assert.equal((await db.query('select count(*)::int n from categories')).rows[0].n,1);
 assert.equal((await db.query("select id from product_variants where size='M'")).rows[0].id,variantId);
 assert.equal((await db.query("select is_active from product_variants where size='L'")).rows[0].is_active,false);
 assert.equal((await db.query('select file_path from product_images order by sort_order')).rows[0].file_path,payload.images[1].path);
 await assert.rejects(save({...payload,id:created.id,name:'should rollback',new_category_name:'rollback category',images:[{path:'invalid',kind:'gallery'}]}));
 assert.equal((await db.query('select name from products')).rows[0].name,'فستان');
 assert.equal((await db.query('select count(*)::int n from categories')).rows[0].n,1);
 await assert.rejects(save({...payload,variants:[payload.variants[0],payload.variants[0]]}));
 await assert.rejects(save({...payload,images:[]}));
 await db.exec("set test.shop = '22222222-2222-2222-2222-222222222222'");
 await assert.rejects(save({...payload,id:created.id}));
 await db.exec("set test.shop = ''"); await assert.rejects(save(payload));
 await db.close(); console.log('PASS: atomic create/edit, category reuse, option retirement, image order/delete, rollback, publish validation, shop ownership');
})().catch(e=>{console.error(e);process.exitCode=1;});

