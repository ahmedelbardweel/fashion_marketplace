-- =============================================================================
--  038_professional_notifications.sql
--  Professional Notification Platform Upgrades:
--    1) Per-user notification category preferences (orders, offers, catalog, system)
--    2) Server-side read state sync across devices (notification_reads)
--    3) Smart throttling & rich product/banner image URLs in notification metadata
--    4) Automatic Admin alert when Decart Virtual Try-On credits are low/depleted
-- =============================================================================
begin;

-- -----------------------------------------------------------------------------
--  1) Per-user Notification Preferences
-- -----------------------------------------------------------------------------
create table if not exists public.user_notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  orders_enabled boolean not null default true,
  offers_enabled boolean not null default true,
  catalog_enabled boolean not null default true,
  system_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.user_notification_preferences enable row level security;

drop policy if exists "user_notif_prefs_own_select" on public.user_notification_preferences;
create policy "user_notif_prefs_own_select"
  on public.user_notification_preferences for select
  using (auth.uid() = user_id);

drop policy if exists "user_notif_prefs_own_upsert" on public.user_notification_preferences;
create policy "user_notif_prefs_own_upsert"
  on public.user_notification_preferences for insert
  with check (auth.uid() = user_id);

drop policy if exists "user_notif_prefs_own_update" on public.user_notification_preferences;
create policy "user_notif_prefs_own_update"
  on public.user_notification_preferences for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function public.get_my_notification_preferences()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  pref public.user_notification_preferences%rowtype;
begin
  if uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into pref
  from public.user_notification_preferences
  where user_id = uid;

  if not found then
    return jsonb_build_object(
      'orders_enabled', true,
      'offers_enabled', true,
      'catalog_enabled', true,
      'system_enabled', true
    );
  end if;

  return jsonb_build_object(
    'orders_enabled', pref.orders_enabled,
    'offers_enabled', pref.offers_enabled,
    'catalog_enabled', pref.catalog_enabled,
    'system_enabled', pref.system_enabled,
    'updated_at', pref.updated_at
  );
end;
$$;

create or replace function public.update_my_notification_preferences(
  p_orders_enabled boolean default true,
  p_offers_enabled boolean default true,
  p_catalog_enabled boolean default true,
  p_system_enabled boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  pref public.user_notification_preferences%rowtype;
begin
  if uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  insert into public.user_notification_preferences (
    user_id,
    orders_enabled,
    offers_enabled,
    catalog_enabled,
    system_enabled,
    updated_at
  )
  values (
    uid,
    coalesce(p_orders_enabled, true),
    coalesce(p_offers_enabled, true),
    coalesce(p_catalog_enabled, true),
    coalesce(p_system_enabled, true),
    now()
  )
  on conflict (user_id) do update
    set orders_enabled = excluded.orders_enabled,
        offers_enabled = excluded.offers_enabled,
        catalog_enabled = excluded.catalog_enabled,
        system_enabled = excluded.system_enabled,
        updated_at = now()
  returning * into pref;

  return jsonb_build_object(
    'orders_enabled', pref.orders_enabled,
    'offers_enabled', pref.offers_enabled,
    'catalog_enabled', pref.catalog_enabled,
    'system_enabled', pref.system_enabled,
    'updated_at', pref.updated_at
  );
end;
$$;

revoke all on function public.get_my_notification_preferences() from public, anon, authenticated;
grant execute on function public.get_my_notification_preferences() to authenticated;

revoke all on function public.update_my_notification_preferences(boolean, boolean, boolean, boolean) from public, anon, authenticated;
grant execute on function public.update_my_notification_preferences(boolean, boolean, boolean, boolean) to authenticated;

-- -----------------------------------------------------------------------------
--  2) Server-side Read Sync (Multi-device consistent unread badges)
-- -----------------------------------------------------------------------------
create table if not exists public.notification_reads (
  user_id uuid not null references auth.users(id) on delete cascade,
  notification_id uuid not null references public.notifications(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (user_id, notification_id)
);

create index if not exists idx_notification_reads_user_read_at
  on public.notification_reads (user_id, read_at desc);

alter table public.notification_reads enable row level security;

drop policy if exists "notification_reads_own_select" on public.notification_reads;
create policy "notification_reads_own_select"
  on public.notification_reads for select
  using (auth.uid() = user_id);

drop policy if exists "notification_reads_own_insert" on public.notification_reads;
create policy "notification_reads_own_insert"
  on public.notification_reads for insert
  with check (auth.uid() = user_id);

create or replace function public.get_my_read_notification_ids()
returns uuid[]
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  return coalesce(
    (
      select array_agg(nr.notification_id)
      from (
        select notification_id
        from public.notification_reads
        where user_id = uid
        order by read_at desc
        limit 500
      ) nr
    ),
    array[]::uuid[]
  );
end;
$$;

create or replace function public.mark_notifications_read(p_ids uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if p_ids is null or array_length(p_ids, 1) is null then
    return;
  end if;

  insert into public.notification_reads (user_id, notification_id, read_at)
  select uid, n.id, now()
  from public.notifications n
  where n.id = any(p_ids)
  on conflict (user_id, notification_id) do nothing;
end;
$$;

revoke all on function public.get_my_read_notification_ids() from public, anon, authenticated;
grant execute on function public.get_my_read_notification_ids() to authenticated;

revoke all on function public.mark_notifications_read(uuid[]) from public, anon, authenticated;
grant execute on function public.mark_notifications_read(uuid[]) to authenticated;

-- -----------------------------------------------------------------------------
--  3) Rich Image URLs + Smart Throttling on Product Publish / Offer Triggers
-- -----------------------------------------------------------------------------
create index if not exists idx_notifications_event_created
  on public.notifications ((metadata->>'event_type'), created_at desc);

create or replace function public.trg_notify_on_product_published_or_offer()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop_name text;
  v_shop_owner_id uuid;
  v_price_text text;
  v_image_url text;
  v_became_published boolean := false;
  v_new_offer boolean := false;
  v_recent_publish_exists boolean := false;
begin
  if new.status <> 'published' then
    return new;
  end if;

  if tg_op = 'INSERT' then
    v_became_published := true;
  elsif tg_op = 'UPDATE' then
    if old.status is distinct from 'published' then
      v_became_published := true;
    elsif (new.price < old.price)
       or (coalesce(new.details->>'offer_active', 'false') = 'true'
           and coalesce(old.details->>'offer_active', 'false') <> 'true') then
      v_new_offer := true;
    end if;
  end if;

  if not v_became_published and not v_new_offer then
    return new;
  end if;

  select name, owner_id into v_shop_name, v_shop_owner_id
  from public.shops
  where id = new.shop_id;

  select pi.image_url into v_image_url
  from public.product_images pi
  where pi.product_id = new.id
  order by pi.sort_order asc, pi.created_at asc
  limit 1;

  v_price_text := to_char(coalesce(new.price, 0), 'FM999999990.##');

  if v_new_offer then
    insert into public.notifications (
      title,
      body,
      audience,
      created_by,
      shop_id,
      sender_role,
      target_scope,
      metadata
    )
    values (
      'عرض وخصم جديد 🔥',
      coalesce(v_shop_name, 'متجر') || ' أطلق خصماً على "' || new.name || '" الآن بسعر ' || v_price_text || ' ₪!',
      'customer',
      v_shop_owner_id,
      new.shop_id,
      'shop',
      'all_customers',
      jsonb_strip_nulls(
        jsonb_build_object(
          'event_type', 'product_offer',
          'category', 'offers',
          'product_id', new.id,
          'shop_id', new.shop_id,
          'image_url', nullif(trim(coalesce(v_image_url, '')), ''),
          'route', '/customer/products/' || new.id::text
        )
      )
    );
  elsif v_became_published then
    -- Smart throttle: at most 1 new-arrival broadcast per shop every 15 minutes
    -- so bulk catalog uploads never spam customer devices.
    select exists (
      select 1
      from public.notifications n
      where n.shop_id = new.shop_id
        and n.metadata->>'event_type' = 'product_published'
        and n.created_at > now() - interval '15 minutes'
    ) into v_recent_publish_exists;

    if not v_recent_publish_exists then
      insert into public.notifications (
        title,
        body,
        audience,
        created_by,
        shop_id,
        sender_role,
        target_scope,
        metadata
      )
      values (
        'وصول قطعة جديدة ✨',
        coalesce(v_shop_name, 'متجر') || ' أضاف "' || new.name || '" بسعر ' || v_price_text || ' ₪ — جرّبها افتراضياً الآن!',
        'customer',
        v_shop_owner_id,
        new.shop_id,
        'shop',
        'all_customers',
        jsonb_strip_nulls(
          jsonb_build_object(
            'event_type', 'product_published',
            'category', 'catalog',
            'product_id', new.id,
            'shop_id', new.shop_id,
            'image_url', nullif(trim(coalesce(v_image_url, '')), ''),
            'route', '/customer/products/' || new.id::text
          )
        )
      );
    end if;
  end if;

  return new;
end;
$$;

-- Rich banner image & category in banner insert trigger
create or replace function public.trg_notify_on_banner_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.is_active, false) = false then
    return new;
  end if;

  insert into public.notifications (
    title,
    body,
    audience,
    created_by,
    shop_id,
    sender_role,
    target_scope,
    metadata
  )
  values (
    coalesce(nullif(trim(new.title), ''), 'عرض جديد في وصلة 🎉'),
    coalesce(nullif(trim(new.subtitle), ''), 'تصفح أحدث العروض والبنرات الحصرية داخل التطبيق الآن.'),
    'customer',
    auth.uid(),
    new.shop_id,
    case when new.shop_id is not null then 'shop' else 'admin' end,
    'all_customers',
    jsonb_strip_nulls(
      jsonb_build_object(
        'event_type', 'new_banner',
        'category', 'offers',
        'banner_id', new.id,
        'shop_id', new.shop_id,
        'image_url', nullif(trim(coalesce(new.image_url, '')), ''),
        'route', case
          when new.shop_id is not null then '/customer/shops/' || new.shop_id::text
          else '/customer/home'
        end
      )
    )
  );

  return new;
end;
$$;

-- -----------------------------------------------------------------------------
--  4) Automatic Admin Alert when Decart Virtual Try-On Credits are Low/Depleted
-- -----------------------------------------------------------------------------
create or replace function public.service_update_decart_key_telemetry(
  p_id uuid,
  p_credits numeric default null,
  p_status text default null,
  p_mark_used boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usable_keys integer := 0;
  v_low_keys integer := 0;
  v_recent_alert boolean := false;
begin
  if p_id is null then
    return;
  end if;

  update public.decart_api_keys
  set
    last_credits = coalesce(p_credits, last_credits),
    last_status = case
      when p_status in ('active', 'low', 'depleted', 'invalid', 'unknown') then p_status
      else last_status
    end,
    last_checked_at = case
      when p_credits is not null or p_status is not null then now()
      else last_checked_at
    end,
    last_used_at = case when p_mark_used then now() else last_used_at end,
    updated_at = now()
  where id = p_id;

  -- Trigger throttled Admin alert when pool becomes depleted or critically low.
  if p_status in ('depleted', 'low', 'invalid') then
    select
      count(*) filter (
        where is_active
          and last_status not in ('depleted', 'invalid')
          and (last_credits is null or last_credits > 0)
      ),
      count(*) filter (
        where is_active and last_status = 'low'
      )
    into v_usable_keys, v_low_keys
    from public.decart_api_keys;

    if v_usable_keys = 0 then
      select exists (
        select 1
        from public.notifications n
        where n.metadata->>'event_type' = 'decart_credits_depleted'
          and n.created_at > now() - interval '6 hours'
      ) into v_recent_alert;

      if not v_recent_alert then
        perform public.notify_all_admins(
          'نفاد رصيد التجربة الافتراضية ⚠️',
          'نفد الرصيد في جميع مفاتيح Decart النشطة وتوقفت ميزة تجربة الملابس مؤقتاً للعملاء. يرجى إضافة مفتاح جديد أو شحن الرصيد من الإعدادات.',
          jsonb_build_object(
            'event_type', 'decart_credits_depleted',
            'category', 'system',
            'route', '/admin/settings'
          )
        );
      end if;
    elsif p_status = 'low' and v_low_keys > 0 then
      select exists (
        select 1
        from public.notifications n
        where n.metadata->>'event_type' = 'decart_credits_low'
          and n.created_at > now() - interval '6 hours'
      ) into v_recent_alert;

      if not v_recent_alert then
        perform public.notify_all_admins(
          'انخفاض رصيد التجربة الافتراضية 🔔',
          'رصيد مفتاح Decart النشط منخفض حالياً. يُنصح بإضافة مفتاح احتياطي أو شحن الرصيد لضمان عدم توقف الخدمة.',
          jsonb_build_object(
            'event_type', 'decart_credits_low',
            'category', 'system',
            'route', '/admin/settings'
          )
        );
      end if;
    end if;
  end if;
end;
$$;

revoke all on function public.service_update_decart_key_telemetry(uuid, numeric, text, boolean) from public, anon, authenticated;
grant execute on function public.service_update_decart_key_telemetry(uuid, numeric, text, boolean) to service_role;

notify pgrst, 'reload schema';
commit;
