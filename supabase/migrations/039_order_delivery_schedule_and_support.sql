-- =============================================================================
--  039_order_delivery_schedule_and_support.sql
--  Order Delivery Scheduling (set by Shop) & Quick Customer Inquiry / Escalation
--    1) Adds scheduled_delivery_at, delivery_time_window, shop_order_note to orders
--    2) RPC shop_set_order_delivery_schedule(...) -> saves schedule + notifies customer
--    3) RPC customer_send_order_inquiry(...) -> notifies shop (+ optional admin escalation)
--    4) Updates shop order notification routes to open /shop/orders/<order_id> directly
-- =============================================================================
begin;

-- 1) Delivery appointment & shop note columns on public.orders
alter table public.orders
  add column if not exists scheduled_delivery_at timestamptz,
  add column if not exists delivery_time_window text,
  add column if not exists shop_order_note text;

-- 2) Shop RPC: Set or update delivery/pickup appointment & optional customer note
create or replace function public.shop_set_order_delivery_schedule(
  p_order_id uuid,
  p_scheduled_at timestamptz default null,
  p_time_window text default null,
  p_shop_note text default null
)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  sid uuid;
  v_order public.orders;
  v_shop_name text;
  v_window text := nullif(trim(coalesce(p_time_window, '')), '');
  v_note text := nullif(trim(coalesce(p_shop_note, '')), '');
  v_date_label text;
  v_body text;
begin
  sid := public.require_approved_shop();

  update public.orders
  set scheduled_delivery_at = p_scheduled_at,
      delivery_time_window = v_window,
      shop_order_note = v_note,
      updated_at = now()
  where id = p_order_id
    and shop_id = sid
  returning * into v_order;

  if v_order.id is null then
    raise exception 'الطلب غير موجود';
  end if;

  select name into v_shop_name from public.shops where id = sid;

  if p_scheduled_at is not null then
    v_date_label := to_char(p_scheduled_at at time zone 'Asia/Gaza', 'YYYY/MM/DD');
  end if;

  v_body := coalesce(v_shop_name, 'المتجر') || ': ';
  if v_date_label is not null and v_window is not null then
    v_body := v_body || 'موعد التسليم ' || v_date_label || ' (' || v_window || ')';
  elsif v_date_label is not null then
    v_body := v_body || 'موعد التسليم ' || v_date_label;
  elsif v_window is not null then
    v_body := v_body || 'موعد التسليم: ' || v_window;
  else
    v_body := v_body || 'تحديث جديد على طلبك #' || upper(left(v_order.id::text, 8));
  end if;

  if v_note is not null then
    v_body := v_body || ' — ' || left(v_note, 140);
  end if;

  insert into public.notifications (
    title,
    body,
    audience,
    created_by,
    target_user_id,
    shop_id,
    sender_role,
    target_scope,
    metadata
  )
  values (
    case
      when p_scheduled_at is not null or v_window is not null
        then 'تحديد موعد تسليم طلبك'
      else 'ملاحظة من المتجر على طلبك'
    end,
    v_body,
    'customer',
    auth.uid(),
    v_order.customer_id,
    sid,
    'shop',
    'user',
    jsonb_build_object(
      'event_type', 'delivery_scheduled',
      'category', 'orders',
      'order_id', v_order.id,
      'shop_id', sid,
      'route', '/customer/orders/' || v_order.id::text
    )
  );

  return v_order;
end;
$$;

revoke all on function public.shop_set_order_delivery_schedule(uuid, timestamptz, text, text) from public, anon, authenticated;
grant execute on function public.shop_set_order_delivery_schedule(uuid, timestamptz, text, text) to authenticated;

-- 3) Customer RPC: Send quick inquiry / delay follow-up to Shop (+ optional Admin escalation)
create or replace function public.customer_send_order_inquiry(
  p_order_id uuid,
  p_topic text,
  p_message text default null,
  p_escalate_admin boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  v_order public.orders;
  v_shop_owner_id uuid;
  v_shop_name text;
  v_customer_name text;
  v_topic text := coalesce(nullif(trim(p_topic), ''), 'استفسار عن الطلب');
  v_msg text := nullif(trim(coalesce(p_message, '')), '');
  v_short_id text;
  v_body text;
begin
  if uid is null then
    raise exception 'يرجى تسجيل الدخول أولاً' using errcode = '42501';
  end if;

  select * into v_order
  from public.orders
  where id = p_order_id
    and customer_id = uid;

  if v_order.id is null then
    raise exception 'الطلب غير موجود';
  end if;

  select owner_id, name into v_shop_owner_id, v_shop_name
  from public.shops
  where id = v_order.shop_id;

  select coalesce(nullif(trim(full_name), ''), email, 'عميل')
    into v_customer_name
  from public.profiles
  where id = uid;

  v_short_id := upper(left(v_order.id::text, 8));
  v_body := v_customer_name || ' (' || v_topic || ' — طلب #' || v_short_id || ')' ||
    case when v_msg is not null then ': ' || left(v_msg, 180) else '.' end;

  if v_shop_owner_id is not null and v_shop_owner_id <> uid then
    insert into public.notifications (
      title,
      body,
      audience,
      created_by,
      target_user_id,
      shop_id,
      sender_role,
      target_scope,
      metadata
    )
    values (
      'استفسار من عميل على طلب #' || v_short_id,
      v_body,
      'shop',
      uid,
      v_shop_owner_id,
      v_order.shop_id,
      'system',
      'user',
      jsonb_build_object(
        'event_type', 'order_customer_inquiry',
        'category', 'orders',
        'order_id', v_order.id,
        'shop_id', v_order.shop_id,
        'route', '/shop/orders/' || v_order.id::text
      )
    );
  end if;

  if coalesce(p_escalate_admin, false) then
    perform public.notify_all_admins(
      'بلاغ عميل على طلب #' || v_short_id,
      coalesce(v_shop_name, 'متجر') || ' — ' || v_body,
      jsonb_build_object(
        'event_type', 'order_customer_escalation',
        'category', 'orders',
        'order_id', v_order.id,
        'shop_id', v_order.shop_id,
        'route', '/admin/orders'
      )
    );
  end if;
end;
$$;

revoke all on function public.customer_send_order_inquiry(uuid, text, text, boolean) from public, anon, authenticated;
grant execute on function public.customer_send_order_inquiry(uuid, text, text, boolean) to authenticated;

-- 4) Deep-link shop order notifications directly to /shop/orders/<order_id>
create or replace function public.trg_notify_on_order_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop_owner_id uuid;
  v_shop_name text;
  v_customer_name text;
  v_total_text text;
begin
  select owner_id, name into v_shop_owner_id, v_shop_name
  from public.shops
  where id = new.shop_id;

  select coalesce(nullif(trim(full_name), ''), email, 'عميل')
    into v_customer_name
  from public.profiles
  where id = new.customer_id;

  v_total_text := to_char(coalesce(new.total, 0), 'FM999999990.##');

  if v_shop_owner_id is not null and v_shop_owner_id <> new.customer_id then
    insert into public.notifications (
      title,
      body,
      audience,
      created_by,
      target_user_id,
      shop_id,
      sender_role,
      target_scope,
      metadata
    )
    values (
      'طلب جديد في متجرك',
      'وصلك طلب جديد من ' || coalesce(v_customer_name, 'عميل') || ' بقيمة ' || v_total_text || ' ₪.',
      'shop',
      new.customer_id,
      v_shop_owner_id,
      new.shop_id,
      'system',
      'user',
      jsonb_build_object(
        'event_type', 'order_created',
        'category', 'orders',
        'order_id', new.id,
        'shop_id', new.shop_id,
        'route', '/shop/orders/' || new.id::text
      )
    );
  end if;

  insert into public.notifications (
    title,
    body,
    audience,
    created_by,
    target_user_id,
    shop_id,
    sender_role,
    target_scope,
    metadata
  )
  values (
    'تم استلام طلبك بنجاح',
    'تم إرسال طلبك إلى ' || coalesce(v_shop_name, 'المتجر') || ' بقيمة ' || v_total_text || ' ₪ وسنبلغك بكل تحديث.',
    'customer',
    null,
    new.customer_id,
    new.shop_id,
    'system',
    'user',
    jsonb_build_object(
      'event_type', 'order_confirmed_receipt',
      'category', 'orders',
      'order_id', new.id,
      'shop_id', new.shop_id,
      'route', '/customer/orders/' || new.id::text
    )
  );

  return new;
end;
$$;

notify pgrst, 'reload schema';
commit;
