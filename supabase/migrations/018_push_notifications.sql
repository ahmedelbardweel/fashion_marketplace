-- Push notifications infrastructure: device tokens, shop-to-customer notifications, and order alerts

create table if not exists public.device_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('android', 'ios', 'web')),
  device_label text,
  notifications_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists device_push_tokens_user_idx
  on public.device_push_tokens (user_id);

create index if not exists device_push_tokens_user_enabled_idx
  on public.device_push_tokens (user_id, notifications_enabled);

alter table public.device_push_tokens enable row level security;

drop policy if exists "device_push_tokens_own" on public.device_push_tokens;
create policy "device_push_tokens_own"
  on public.device_push_tokens for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "device_push_tokens_admin_read" on public.device_push_tokens;
create policy "device_push_tokens_admin_read"
  on public.device_push_tokens for select
  using (public.current_user_role() = 'admin');

-- Register or reassign an FCM token for the authenticated user
create or replace function public.register_push_token(
  p_token text,
  p_platform text,
  p_device_label text default null,
  p_enabled boolean default true
)
returns public.device_push_tokens
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_token text;
  v_platform text;
  v_result public.device_push_tokens;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول لتفعيل الإشعارات';
  end if;

  v_token := trim(coalesce(p_token, ''));
  if v_token = '' then
    raise exception 'رمز الإشعارات غير صالح';
  end if;

  v_platform := lower(trim(coalesce(p_platform, 'android')));
  if v_platform not in ('android', 'ios', 'web') then
    raise exception 'نوع المنصة غير مدعوم';
  end if;

  insert into public.device_push_tokens (
    user_id,
    token,
    platform,
    device_label,
    notifications_enabled,
    updated_at
  )
  values (
    v_uid,
    v_token,
    v_platform,
    nullif(trim(coalesce(p_device_label, '')), ''),
    coalesce(p_enabled, true),
    now()
  )
  on conflict (token) do update
    set user_id = v_uid,
        platform = excluded.platform,
        device_label = coalesce(excluded.device_label, public.device_push_tokens.device_label),
        notifications_enabled = excluded.notifications_enabled,
        updated_at = now()
  returning * into v_result;

  return v_result;
end;
$$;

-- Unregister a device push token (e.g. on sign-out)
create or replace function public.unregister_push_token(
  p_token text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_token text;
begin
  v_uid := auth.uid();
  if v_uid is null then
    return;
  end if;

  v_token := nullif(trim(coalesce(p_token, '')), '');
  if v_token is not null then
    delete from public.device_push_tokens
    where user_id = v_uid and token = v_token;
  end if;
end;
$$;

-- Enable or pause push delivery for the current user's registered devices
create or replace function public.set_push_notifications_enabled(
  p_enabled boolean,
  p_token text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_token text;
begin
  v_uid := auth.uid();
  if v_uid is null then
    return;
  end if;

  v_token := nullif(trim(coalesce(p_token, '')), '');
  update public.device_push_tokens
  set notifications_enabled = coalesce(p_enabled, true),
      updated_at = now()
  where user_id = v_uid
    and (v_token is null or token = v_token);
end;
$$;

grant execute on function public.register_push_token(text, text, text, boolean) to authenticated;
grant execute on function public.unregister_push_token(text) to authenticated;
grant execute on function public.set_push_notifications_enabled(boolean, text) to authenticated;

-- Extend notifications table to support shop-sent notifications and target scopes
alter table public.notifications
  add column if not exists shop_id uuid references public.shops (id) on delete cascade,
  add column if not exists sender_role text not null default 'system',
  add column if not exists target_scope text not null default 'audience';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'notifications_sender_role_check'
  ) then
    alter table public.notifications
      add constraint notifications_sender_role_check
      check (sender_role in ('admin', 'shop', 'system'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'notifications_target_scope_check'
  ) then
    alter table public.notifications
      add constraint notifications_target_scope_check
      check (target_scope in ('audience', 'user', 'shop_customers', 'all_customers'));
  end if;
end $$;

create index if not exists notifications_shop_idx
  on public.notifications (shop_id);

create index if not exists notifications_created_by_idx
  on public.notifications (created_by);

-- Update notifications read policy so:
-- 1) Admin reads everything
-- 2) Targeted user reads their own notifications
-- 3) Shop owner reads notifications they sent + shop/all broadcasts
-- 4) Customer reads all/customer broadcasts + shop_customers notifications from shops they ordered from
drop policy if exists "notifications_read" on public.notifications;
create policy "notifications_read"
  on public.notifications for select
  using (
    public.current_user_role() = 'admin'
    or target_user_id = auth.uid()
    or (
      shop_id is not null
      and shop_id in (select id from public.shops where owner_id = auth.uid())
    )
    or (
      target_user_id is null
      and target_scope in ('audience', 'all_customers')
      and (
        audience = 'all'
        or (audience = 'customer' and public.current_user_role() = 'customer')
        or (audience = 'shop' and public.current_user_role() = 'shop')
      )
    )
    or (
      target_user_id is null
      and target_scope = 'shop_customers'
      and shop_id is not null
      and public.current_user_role() = 'customer'
      and exists (
        select 1 from public.orders o
        where o.shop_id = notifications.shop_id
          and o.customer_id = auth.uid()
      )
    )
  );

-- Refresh admin_send_notification to tag sender_role and target_scope
create or replace function public.admin_send_notification(
  p_title text,
  p_body text,
  p_audience public.notification_audience
)
returns public.notifications
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.notifications;
begin
  perform public.require_admin();

  if coalesce(trim(p_title), '') = '' or coalesce(trim(p_body), '') = '' then
    raise exception 'عنوان ومحتوى الإشعار مطلوبان';
  end if;

  insert into public.notifications (
    title,
    body,
    audience,
    created_by,
    sender_role,
    target_scope
  )
  values (
    trim(p_title),
    trim(p_body),
    p_audience,
    auth.uid(),
    'admin',
    'audience'
  )
  returning * into result;

  return result;
end;
$$;

-- Refresh notify_user to tag target_scope = 'user'
create or replace function public.notify_user(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_audience public.notification_audience default 'shop'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null then
    return;
  end if;
  insert into public.notifications (
    title,
    body,
    audience,
    created_by,
    target_user_id,
    sender_role,
    target_scope
  )
  values (
    p_title,
    p_body,
    p_audience,
    auth.uid(),
    p_user_id,
    case when public.current_user_role() = 'admin' then 'admin' else 'system' end,
    'user'
  );
end;
$$;

-- Allow approved shop owners to send notifications to their shop customers or all customers
create or replace function public.shop_send_notification(
  p_title text,
  p_body text,
  p_scope text default 'shop_customers'
)
returns public.notifications
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sid uuid;
  v_scope text;
  v_title text;
  v_body text;
  v_result public.notifications;
begin
  v_sid := public.require_approved_shop();

  v_title := trim(coalesce(p_title, ''));
  v_body := trim(coalesce(p_body, ''));
  if v_title = '' or v_body = '' then
    raise exception 'عنوان ومحتوى الإشعار مطلوبان';
  end if;

  if char_length(v_title) > 120 then
    raise exception 'عنوان الإشعار طويل جداً (الحد الأقصى 120 حرفاً)';
  end if;

  if char_length(v_body) > 500 then
    raise exception 'محتوى الإشعار طويل جداً (الحد الأقصى 500 حرف)';
  end if;

  v_scope := lower(trim(coalesce(p_scope, 'shop_customers')));
  if v_scope not in ('shop_customers', 'all_customers') then
    raise exception 'نطاق الإرسال غير مسموح';
  end if;

  insert into public.notifications (
    title,
    body,
    audience,
    created_by,
    shop_id,
    sender_role,
    target_scope
  )
  values (
    v_title,
    v_body,
    'customer',
    auth.uid(),
    v_sid,
    'shop',
    v_scope
  )
  returning * into v_result;

  return v_result;
end;
$$;

grant execute on function public.shop_send_notification(text, text, text) to authenticated;

-- Also emit a targeted notification when a shop updates an order status
create or replace function public.shop_update_order_status(
  p_order_id uuid,
  p_status public.order_status
)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.orders;
  sid uuid;
  v_shop_name text;
  v_status_label text;
begin
  sid := public.require_approved_shop();

  if p_status not in ('confirmed', 'processing', 'shipped', 'delivered', 'cancelled') then
    raise exception 'حالة الطلب غير مسموحة';
  end if;

  update public.orders
  set status = p_status, updated_at = now()
  where id = p_order_id
    and shop_id = sid
  returning * into result;

  if result.id is null then
    raise exception 'الطلب غير موجود';
  end if;

  select name into v_shop_name from public.shops where id = sid;
  v_status_label := case p_status
    when 'confirmed' then 'تم تأكيد طلبك'
    when 'processing' then 'جاري تجهيز طلبك'
    when 'shipped' then 'تم شحن طلبك'
    when 'delivered' then 'تم تسليم طلبك'
    when 'cancelled' then 'تم إلغاء طلبك'
    else 'تحديث على طلبك'
  end;

  insert into public.notifications (
    title,
    body,
    audience,
    created_by,
    target_user_id,
    shop_id,
    sender_role,
    target_scope
  )
  values (
    v_status_label,
    coalesce(v_shop_name, 'المتجر') || ': تم تحديث حالة الطلب إلى "' || v_status_label || '".',
    'customer',
    auth.uid(),
    result.customer_id,
    sid,
    'shop',
    'user'
  );

  return result;
end;
$$;

grant execute on function public.shop_update_order_status(uuid, public.order_status) to authenticated;

-- Enable Supabase Realtime on public.notifications for foreground instant alerts
do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;
