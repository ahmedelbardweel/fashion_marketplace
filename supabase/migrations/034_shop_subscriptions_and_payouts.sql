-- ============================================================================
-- Migration 034: Shop Subscriptions (replacing commissions) & 100% Shop Payouts
-- - Admin-managed flexible subscription plans (Monthly 30 NIS, 3 Months, Yearly)
-- - Shop onboarding & renewal transfer receipt upload using Admin payment accounts
-- - Admin verification of subscription receipts (approve -> open/renew shop, reject -> notify)
-- - Automatic pause on publishing products when subscription expires
-- - 0% commission on sales; full 100% per-shop financial statement & Admin->Shop payouts
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 1) Subscription Plans (Admin-managed)
-- ----------------------------------------------------------------------------
create table if not exists public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  name_en text,
  description text,
  price numeric(10, 2) not null default 30 check (price >= 0),
  duration_days integer not null default 30 check (duration_days >= 1),
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now().
  
);

create index if not exists subscription_plans_active_idx
  on public.subscription_plans (is_active, sort_order, created_at);

drop trigger if exists subscription_plans_set_updated_at on public.subscription_plans;
create trigger subscription_plans_set_updated_at
  before update on public.subscription_plans
  for each row execute function public.set_updated_at();

alter table public.subscription_plans enable row level security;

drop policy if exists "subscription_plans_read_active" on public.subscription_plans;
create policy "subscription_plans_read_active"
  on public.subscription_plans for select
  to authenticated
  using (is_active = true or public.current_user_role() = 'admin');

drop policy if exists "subscription_plans_admin_all" on public.subscription_plans;
create policy "subscription_plans_admin_all"
  on public.subscription_plans for all
  to authenticated
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

-- Seed default plans once if table is empty
insert into public.subscription_plans (name, name_en, description, price, duration_days, is_active, sort_order)
select * from (values
  ('الباقة الشهرية', 'Monthly Plan', 'اشتراك شهري كامل لنشر المنتجات واستقبال الطلبات بدون أي عمولة على المبيعات (0%).', 30.00, 30, true, 1),
  ('باقة 3 شهور', '3-Month Plan', 'اشتراك ربع سنوي موفر للمتاجر النشطة مع 100% من أرباح مبيعاتك.', 80.00, 90, true, 2),
  ('الباقة السنوية', 'Yearly Plan', 'أفضل قيمة — اشتراك سنة كاملة لمتجرك بدون عمولات على الطلبات.', 300.00, 365, true, 3)
) as seed(name, name_en, description, price, duration_days, is_active, sort_order)
where not exists (select 1 from public.subscription_plans);

-- ----------------------------------------------------------------------------
-- 2) Shop Subscriptions (Applications & Renewals with Transfer Receipt)
-- ----------------------------------------------------------------------------
create table if not exists public.shop_subscriptions (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  plan_id uuid references public.subscription_plans (id) on delete set null,
  plan_name text not null,
  amount numeric(10, 2) not null check (amount >= 0),
  duration_days integer not null default 30 check (duration_days >= 1),
  payment_method_id uuid references public.payment_methods (id) on delete set null,
  payment_method_name text,
  payment_account_number text,
  receipt_url text not null,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'expired')),
  starts_at timestamptz,
  ends_at timestamptz,
  is_renewal boolean not null default false,
  notes text,
  rejection_reason text,
  reviewed_by uuid references public.profiles (id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists shop_subscriptions_shop_idx
  on public.shop_subscriptions (shop_id, created_at desc);
create index if not exists shop_subscriptions_status_idx
  on public.shop_subscriptions (status, created_at desc);

drop trigger if exists shop_subscriptions_set_updated_at on public.shop_subscriptions;
create trigger shop_subscriptions_set_updated_at
  before update on public.shop_subscriptions
  for each row execute function public.set_updated_at();

alter table public.shop_subscriptions enable row level security;

drop policy if exists "shop_subscriptions_owner_select" on public.shop_subscriptions;
create policy "shop_subscriptions_owner_select"
  on public.shop_subscriptions for select
  to authenticated
  using (
    shop_id in (select id from public.shops where owner_id = auth.uid())
    or public.current_user_role() = 'admin'
  );

drop policy if exists "shop_subscriptions_admin_all" on public.shop_subscriptions;
create policy "shop_subscriptions_admin_all"
  on public.shop_subscriptions for all
  to authenticated
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

-- ----------------------------------------------------------------------------
-- 3) Shop Payouts (Admin transfers 100% of verified order funds to each shop)
-- ----------------------------------------------------------------------------
create table if not exists public.shop_payouts (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  amount numeric(10, 2) not null check (amount > 0),
  payment_method text not null default 'bank_transfer',
  reference_no text,
  receipt_url text,
  notes text,
  paid_by uuid references public.profiles (id) on delete set null,
  paid_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists shop_payouts_shop_idx
  on public.shop_payouts (shop_id, paid_at desc);

alter table public.shop_payouts enable row level security;

drop policy if exists "shop_payouts_owner_select" on public.shop_payouts;
create policy "shop_payouts_owner_select"
  on public.shop_payouts for select
  to authenticated
  using (
    shop_id in (select id from public.shops where owner_id = auth.uid())
    or public.current_user_role() = 'admin'
  );

drop policy if exists "shop_payouts_admin_all" on public.shop_payouts;
create policy "shop_payouts_admin_all"
  on public.shop_payouts for all
  to authenticated
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

-- ----------------------------------------------------------------------------
-- 4) Extend public.shops with subscription state & zero out legacy commissions
-- ----------------------------------------------------------------------------
alter table public.shops
  add column if not exists subscription_status text not null default 'none'
    check (subscription_status in ('none', 'pending', 'active', 'expired', 'rejected')),
  add column if not exists subscription_plan_id uuid references public.subscription_plans (id) on delete set null,
  add column if not exists subscription_plan_name text,
  add column if not exists subscription_price numeric(10, 2) not null default 0,
  add column if not exists subscription_starts_at timestamptz,
  add column if not exists subscription_ends_at timestamptz,
  add column if not exists subscription_receipt_url text,
  add column if not exists subscription_payment_method_name text,
  add column if not exists subscription_payment_account_number text;

-- Grandfather already-approved shops with an active 30-day subscription so they keep operating smoothly
update public.shops
set
  subscription_status = 'active',
  subscription_plan_name = coalesce(subscription_plan_name, 'الباقة الشهرية'),
  subscription_price = case when coalesce(subscription_price, 0) > 0 then subscription_price else 30.00 end,
  subscription_starts_at = coalesce(subscription_starts_at, now()),
  subscription_ends_at = coalesce(subscription_ends_at, now() + interval '30 days')
where status = 'approved'
  and subscription_status = 'none';

-- Zero out legacy commission columns if present and disable legacy commission trigger
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'shops' and column_name = 'commission_rate'
  ) then
    execute 'update public.shops set commission_rate = 0, commission_fixed_fee = 0, financial_hold = false';
  end if;

  if exists (
    select 1 from pg_trigger
    where tgname = 'trg_orders_record_commission'
      and tgrelid = 'public.orders'::regclass
  ) then
    execute 'drop trigger if exists trg_orders_record_commission on public.orders';
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- 5) Admin Plan CRUD RPCs
-- ----------------------------------------------------------------------------
create or replace function public.admin_upsert_subscription_plan(
  p_id uuid default null,
  p_name text default '',
  p_name_en text default null,
  p_description text default null,
  p_price numeric default 30,
  p_duration_days integer default 30,
  p_is_active boolean default true,
  p_sort_order integer default 0
)
returns public.subscription_plans
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.subscription_plans;
  v_name text := trim(coalesce(p_name, ''));
begin
  perform public.require_admin();

  if v_name = '' then
    raise exception 'يرجى إدخال اسم الباقة';
  end if;
  if coalesce(p_price, -1) < 0 then
    raise exception 'يرجى إدخال سعر اشتراك صحيح';
  end if;
  if coalesce(p_duration_days, 0) < 1 then
    raise exception 'مدة الاشتراك يجب أن تكون يوماً واحداً على الأقل';
  end if;

  if p_id is null then
    insert into public.subscription_plans (
      name, name_en, description, price, duration_days, is_active, sort_order
    ) values (
      v_name,
      nullif(trim(coalesce(p_name_en, '')), ''),
      nullif(trim(coalesce(p_description, '')), ''),
      round(p_price, 2),
      p_duration_days,
      coalesce(p_is_active, true),
      coalesce(p_sort_order, 0)
    )
    returning * into v_row;
  else
    update public.subscription_plans
    set
      name = v_name,
      name_en = nullif(trim(coalesce(p_name_en, '')), ''),
      description = nullif(trim(coalesce(p_description, '')), ''),
      price = round(p_price, 2),
      duration_days = p_duration_days,
      is_active = coalesce(p_is_active, true),
      sort_order = coalesce(p_sort_order, 0),
      updated_at = now()
    where id = p_id
    returning * into v_row;

    if v_row.id is null then
      raise exception 'باقة الاشتراك غير موجودة';
    end if;
  end if;

  return v_row;
end;
$$;

create or replace function public.admin_toggle_subscription_plan(
  p_id uuid,
  p_is_active boolean
)
returns public.subscription_plans
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.subscription_plans;
begin
  perform public.require_admin();

  update public.subscription_plans
  set is_active = coalesce(p_is_active, true), updated_at = now()
  where id = p_id
  returning * into v_row;

  if v_row.id is null then
    raise exception 'باقة الاشتراك غير موجودة';
  end if;
  return v_row;
end;
$$;

create or replace function public.admin_delete_subscription_plan(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_admin();
  delete from public.subscription_plans where id = p_id;
end;
$$;

grant execute on function public.admin_upsert_subscription_plan(uuid, text, text, text, numeric, integer, boolean, integer) to authenticated;
grant execute on function public.admin_toggle_subscription_plan(uuid, boolean) to authenticated;
grant execute on function public.admin_delete_subscription_plan(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- 6) Shop Application With Subscription + Renewal RPCs
-- ----------------------------------------------------------------------------
create or replace function public.submit_shop_application_with_subscription(
  p_plan_id uuid,
  p_payment_method_id uuid,
  p_receipt_url text,
  p_notes text default null
)
returns public.shops
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_shop public.shops;
  v_plan public.subscription_plans;
  v_pm public.payment_methods;
  v_receipt text := trim(coalesce(p_receipt_url, ''));
  v_admin_id uuid;
begin
  if v_uid is null then
    raise exception 'يرجى تسجيل الدخول أولاً';
  end if;

  if v_receipt = '' then
    raise exception 'يرجى إرفاق صورة إشعار تحويل الاشتراك أولاً';
  end if;

  select * into v_plan
  from public.subscription_plans
  where id = p_plan_id and is_active = true;
  if v_plan.id is null then
    raise exception 'باقة الاشتراك المختارة غير متاحة حالياً';
  end if;

  select * into v_pm
  from public.payment_methods
  where id = p_payment_method_id and is_active = true;
  if v_pm.id is null then
    raise exception 'حساب التحويل المختار غير متاح حالياً';
  end if;

  select * into v_shop
  from public.shops
  where owner_id = v_uid;

  if v_shop.id is null then
    raise exception 'أكمل بيانات المحل أولاً قبل إرسال الطلب';
  end if;

  if v_shop.status not in ('draft', 'rejected') then
    raise exception 'طلب المتجر مرسل مسبقاً أو معتمد بالفعل';
  end if;

  if coalesce(trim(v_shop.name), '') = ''
     or coalesce(trim(v_shop.description), '') = ''
     or coalesce(trim(v_shop.city), '') = ''
     or coalesce(trim(v_shop.address), '') = ''
     or coalesce(trim(v_shop.commercial_register), '') = '' then
    raise exception 'أكمل جميع بيانات المحل المطلوبة أولاً قبل إرسال الطلب';
  end if;

  -- Mark any old pending subscription requests for this shop as rejected/superseded
  update public.shop_subscriptions
  set status = 'rejected',
      rejection_reason = 'تم استبدال الطلب بإشعار جديد',
      updated_at = now()
  where shop_id = v_shop.id and status = 'pending';

  insert into public.shop_subscriptions (
    shop_id,
    plan_id,
    plan_name,
    amount,
    duration_days,
    payment_method_id,
    payment_method_name,
    payment_account_number,
    receipt_url,
    status,
    is_renewal,
    notes
  ) values (
    v_shop.id,
    v_plan.id,
    v_plan.name,
    v_plan.price,
    v_plan.duration_days,
    v_pm.id,
    v_pm.name,
    v_pm.account_number,
    v_receipt,
    'pending',
    false,
    nullif(trim(coalesce(p_notes, '')), '')
  );

  update public.shops
  set
    status = 'pending',
    rejection_reason = null,
    decision_at = null,
    decision_visible_at = null,
    submitted_at = now(),
    subscription_status = 'pending',
    subscription_plan_id = v_plan.id,
    subscription_plan_name = v_plan.name,
    subscription_price = v_plan.price,
    subscription_receipt_url = v_receipt,
    subscription_payment_method_name = v_pm.name,
    subscription_payment_account_number = v_pm.account_number,
    updated_at = now()
  where id = v_shop.id
  returning * into v_shop;

  update public.profiles
  set profile_completed = true, updated_at = now()
  where id = v_uid;

  -- Notify admins
  for v_admin_id in select id from public.profiles where role = 'admin' and is_active = true loop
    insert into public.notifications (user_id, title, body, data)
    values (
      v_admin_id,
      'طلب اعتماد متجر واشتراك جديد',
      format('أرسل متجر "%s" طلب اعتماد مع إشعار اشتراك %s بقيمة %s ₪.', v_shop.name, v_plan.name, v_plan.price),
      jsonb_build_object(
        'type', 'shop_subscription_submitted',
        'shop_id', v_shop.id,
        'route', '/admin/shop-applications/' || v_shop.id::text
      )
    );
  end loop;

  return v_shop;
end;
$$;

create or replace function public.shop_submit_subscription_renewal(
  p_plan_id uuid,
  p_payment_method_id uuid,
  p_receipt_url text,
  p_notes text default null
)
returns public.shop_subscriptions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_shop public.shops;
  v_plan public.subscription_plans;
  v_pm public.payment_methods;
  v_receipt text := trim(coalesce(p_receipt_url, ''));
  v_sub public.shop_subscriptions;
  v_admin_id uuid;
begin
  if v_uid is null then
    raise exception 'يرجى تسجيل الدخول أولاً';
  end if;

  if v_receipt = '' then
    raise exception 'يرجى إرفاق صورة إشعار تحويل الاشتراك أولاً';
  end if;

  select * into v_shop from public.shops where owner_id = v_uid;
  if v_shop.id is null then
    raise exception 'لم يتم العثور على المتجر';
  end if;

  select * into v_plan
  from public.subscription_plans
  where id = p_plan_id and is_active = true;
  if v_plan.id is null then
    raise exception 'باقة الاشتراك المختارة غير متاحة حالياً';
  end if;

  select * into v_pm
  from public.payment_methods
  where id = p_payment_method_id and is_active = true;
  if v_pm.id is null then
    raise exception 'حساب التحويل المختار غير متاح حالياً';
  end if;

  -- Replace any previous pending renewal
  update public.shop_subscriptions
  set status = 'rejected',
      rejection_reason = 'تم استبدال الطلب بإشعار تجديد أحدث',
      updated_at = now()
  where shop_id = v_shop.id and status = 'pending';

  insert into public.shop_subscriptions (
    shop_id,
    plan_id,
    plan_name,
    amount,
    duration_days,
    payment_method_id,
    payment_method_name,
    payment_account_number,
    receipt_url,
    status,
    is_renewal,
    notes
  ) values (
    v_shop.id,
    v_plan.id,
    v_plan.name,
    v_plan.price,
    v_plan.duration_days,
    v_pm.id,
    v_pm.name,
    v_pm.account_number,
    v_receipt,
    'pending',
    true,
    nullif(trim(coalesce(p_notes, '')), '')
  )
  returning * into v_sub;

  update public.shops
  set
    subscription_receipt_url = v_receipt,
    subscription_payment_method_name = v_pm.name,
    subscription_payment_account_number = v_pm.account_number,
    subscription_status = case
      when subscription_status = 'active' and (subscription_ends_at is null or subscription_ends_at > now())
        then 'active'
      else 'pending'
    end,
    updated_at = now()
  where id = v_shop.id;

  for v_admin_id in select id from public.profiles where role = 'admin' and is_active = true loop
    insert into public.notifications (user_id, title, body, data)
    values (
      v_admin_id,
      'طلب تجديد اشتراك متجر',
      format('أرسل متجر "%s" إشعار تجديد %s بقيمة %s ₪.', v_shop.name, v_plan.name, v_plan.price),
      jsonb_build_object(
        'type', 'shop_subscription_renewal',
        'shop_id', v_shop.id,
        'subscription_id', v_sub.id,
        'route', '/admin/revenue'
      )
    );
  end loop;

  return v_sub;
end;
$$;

grant execute on function public.submit_shop_application_with_subscription(uuid, uuid, text, text) to authenticated;
grant execute on function public.shop_submit_subscription_renewal(uuid, uuid, text, text) to authenticated;

-- ----------------------------------------------------------------------------
-- 7) Admin Review Application & Subscription RPCs
-- ----------------------------------------------------------------------------
create or replace function public.review_shop_application(
  p_shop_id uuid,
  p_approve boolean,
  p_rejection_reason text default null
)
returns public.shops
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop public.shops;
  v_sub public.shop_subscriptions;
  v_start timestamptz;
  v_end timestamptz;
  v_duration integer := 30;
  v_plan_name text := 'الباقة الشهرية';
  v_price numeric(10, 2) := 30.00;
  v_plan_id uuid;
begin
  perform public.require_admin();

  if not p_approve and coalesce(trim(p_rejection_reason), '') = '' then
    raise exception 'سبب الرفض مطلوب';
  end if;

  select * into v_sub
  from public.shop_subscriptions
  where shop_id = p_shop_id and status = 'pending'
  order by created_at desc
  limit 1;

  if v_sub.id is not null then
    v_duration := greatest(1, coalesce(v_sub.duration_days, 30));
    v_plan_name := v_sub.plan_name;
    v_price := v_sub.amount;
    v_plan_id := v_sub.plan_id;
  end if;

  v_start := now();
  v_end := v_start + make_interval(days => v_duration);

  if p_approve then
    if v_sub.id is not null then
      update public.shop_subscriptions
      set status = 'approved',
          starts_at = v_start,
          ends_at = v_end,
          rejection_reason = null,
          reviewed_by = auth.uid(),
          reviewed_at = now(),
          updated_at = now()
      where id = v_sub.id;
    end if;

    update public.shops
    set
      status = 'approved'::public.shop_status,
      rejection_reason = null,
      decision_at = now(),
      decision_visible_at = now(),
      subscription_status = 'active',
      subscription_plan_id = coalesce(v_plan_id, subscription_plan_id),
      subscription_plan_name = coalesce(v_plan_name, subscription_plan_name),
      subscription_price = coalesce(v_price, subscription_price),
      subscription_starts_at = v_start,
      subscription_ends_at = v_end,
      updated_at = now()
    where id = p_shop_id
      and status in ('pending', 'rejected', 'suspended')
    returning * into v_shop;
  else
    if v_sub.id is not null then
      update public.shop_subscriptions
      set status = 'rejected',
          rejection_reason = trim(p_rejection_reason),
          reviewed_by = auth.uid(),
          reviewed_at = now(),
          updated_at = now()
      where id = v_sub.id;
    end if;

    update public.shops
    set
      status = 'rejected'::public.shop_status,
      rejection_reason = trim(p_rejection_reason),
      decision_at = now(),
      decision_visible_at = now(),
      subscription_status = 'rejected',
      updated_at = now()
    where id = p_shop_id
      and status = 'pending'
    returning * into v_shop;
  end if;

  if v_shop.id is null then
    raise exception 'تعذر تحديث حالة الطلب أو أنه تمت مراجعته مسبقاً';
  end if;

  insert into public.notifications (user_id, title, body, data)
  values (
    v_shop.owner_id,
    case when p_approve then 'تم اعتماد متجرك وتفعيل اشتراكك' else 'تم رفض طلب اعتماد المتجر' end,
    case
      when p_approve then format('مبارك! تم اعتماد متجر "%s" وتفعيل اشتراك %s. يمكنك الآن نشر منتجاتك.', v_shop.name, v_plan_name)
      else format('تم رفض طلب متجر "%s": %s. يمكنك تصحيح البيانات أو إشعار الحوالة وإعادة الإرسال.', v_shop.name, trim(p_rejection_reason))
    end,
    jsonb_build_object(
      'type', case when p_approve then 'shop_approved' else 'shop_rejected' end,
      'shop_id', v_shop.id,
      'route', case when p_approve then '/shop' else '/shop/complete-profile' end
    )
  );

  return v_shop;
end;
$$;

create or replace function public.admin_review_subscription(
  p_subscription_id uuid,
  p_approve boolean,
  p_rejection_reason text default null
)
returns public.shop_subscriptions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub public.shop_subscriptions;
  v_shop public.shops;
  v_start timestamptz;
  v_end timestamptz;
begin
  perform public.require_admin();

  if not p_approve and coalesce(trim(p_rejection_reason), '') = '' then
    raise exception 'يرجى إدخال سبب الرفض';
  end if;

  select * into v_sub
  from public.shop_subscriptions
  where id = p_subscription_id;

  if v_sub.id is null then
    raise exception 'طلب الاشتراك غير موجود';
  end if;
  if v_sub.status <> 'pending' then
    raise exception 'تمت مراجعة طلب الاشتراك هذا مسبقاً';
  end if;

  select * into v_shop from public.shops where id = v_sub.shop_id;
  if v_shop.id is null then
    raise exception 'المتجر غير موجود';
  end if;

  if p_approve then
    -- If renewing while still active, extend smoothly from current end date
    if v_shop.subscription_status = 'active'
       and v_shop.subscription_ends_at is not null
       and v_shop.subscription_ends_at > now() then
      v_start := v_shop.subscription_ends_at;
    else
      v_start := now();
    end if;
    v_end := v_start + make_interval(days => greatest(1, v_sub.duration_days));

    update public.shop_subscriptions
    set status = 'approved',
        starts_at = v_start,
        ends_at = v_end,
        rejection_reason = null,
        reviewed_by = auth.uid(),
        reviewed_at = now(),
        updated_at = now()
    where id = v_sub.id
    returning * into v_sub;

    update public.shops
    set
      status = case when status = 'pending' then 'approved'::public.shop_status else status end,
      rejection_reason = case when status = 'pending' then null else rejection_reason end,
      decision_at = case when status = 'pending' then now() else decision_at end,
      decision_visible_at = case when status = 'pending' then now() else decision_visible_at end,
      subscription_status = 'active',
      subscription_plan_id = v_sub.plan_id,
      subscription_plan_name = v_sub.plan_name,
      subscription_price = v_sub.amount,
      subscription_starts_at = coalesce(subscription_starts_at, v_start),
      subscription_ends_at = v_end,
      subscription_receipt_url = v_sub.receipt_url,
      subscription_payment_method_name = v_sub.payment_method_name,
      subscription_payment_account_number = v_sub.payment_account_number,
      updated_at = now()
    where id = v_shop.id;

    insert into public.notifications (user_id, title, body, data)
    values (
      v_shop.owner_id,
      'تم تفعيل اشتراك متجرك بنجاح',
      format('تم اعتماد اشتراك "%s" لمتجر "%s" بنجاح.', v_sub.plan_name, v_shop.name),
      jsonb_build_object(
        'type', 'subscription_approved',
        'shop_id', v_shop.id,
        'subscription_id', v_sub.id,
        'route', '/shop/sales'
      )
    );
  else
    update public.shop_subscriptions
    set status = 'rejected',
        rejection_reason = trim(p_rejection_reason),
        reviewed_by = auth.uid(),
        reviewed_at = now(),
        updated_at = now()
    where id = v_sub.id
    returning * into v_sub;

    if not v_sub.is_renewal and v_shop.status = 'pending' then
      update public.shops
      set status = 'rejected'::public.shop_status,
          rejection_reason = trim(p_rejection_reason),
          decision_at = now(),
          decision_visible_at = now(),
          subscription_status = 'rejected',
          updated_at = now()
      where id = v_shop.id;
    elsif v_shop.subscription_ends_at is null or v_shop.subscription_ends_at <= now() then
      update public.shops
      set subscription_status = case when subscription_ends_at is not null then 'expired' else 'rejected' end,
          updated_at = now()
      where id = v_shop.id;
    end if;

    insert into public.notifications (user_id, title, body, data)
    values (
      v_shop.owner_id,
      'تم رفض إشعار الاشتراك',
      format('تم رفض إشعار اشتراك متجر "%s": %s. يمكنك إعادة رفع إشعار صحيح.', v_shop.name, trim(p_rejection_reason)),
      jsonb_build_object(
        'type', 'subscription_rejected',
        'shop_id', v_shop.id,
        'subscription_id', v_sub.id,
        'route', case when v_sub.is_renewal then '/shop/sales' else '/shop/complete-profile' end
      )
    );
  end if;

  return v_sub;
end;
$$;

grant execute on function public.review_shop_application(uuid, boolean, text) to authenticated;
grant execute on function public.admin_review_subscription(uuid, boolean, text) to authenticated;

-- ----------------------------------------------------------------------------
-- 8) Subscription Expiration Guard on Product Publishing
-- ----------------------------------------------------------------------------
create or replace function public.assert_shop_subscription_active(p_shop_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop public.shops;
begin
  select * into v_shop from public.shops where id = p_shop_id;
  if v_shop.id is null then
    raise exception 'المتجر غير موجود';
  end if;
  if v_shop.status <> 'approved' then
    raise exception 'متجرك غير معتمد بعد للنشر';
  end if;
  if v_shop.subscription_status <> 'active'
     or (v_shop.subscription_ends_at is not null and v_shop.subscription_ends_at <= now()) then
    update public.shops
    set subscription_status = 'expired', updated_at = now()
    where id = v_shop.id and subscription_status = 'active';
    raise exception 'انتهت مدة اشتراك متجرك. يرجى تجديد الاشتراك لمتابعة نشر المنتجات.';
  end if;
end;
$$;

-- Trigger on public.products to enforce active subscription whenever a shop publishes a product
create or replace function public.trg_enforce_shop_subscription_on_publish()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Admins and SQL Editor migrations bypass
  if auth.uid() is null or public.current_user_role() = 'admin' then
    return new;
  end if;

  if new.status = 'published' and (tg_op = 'INSERT' or old.status is distinct from 'published') then
    perform public.assert_shop_subscription_active(new.shop_id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_products_enforce_subscription on public.products;
create trigger trg_products_enforce_subscription
  before insert or update of status on public.products
  for each row
  execute function public.trg_enforce_shop_subscription_on_publish();

-- ----------------------------------------------------------------------------
-- 9) 100% Shop Financial Statement & Admin Payouts RPCs
-- ----------------------------------------------------------------------------
create or replace function public.get_admin_subscription_and_payout_overview()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total_sub_revenue numeric(12, 2) := 0;
  v_active_subs int := 0;
  v_expired_subs int := 0;
  v_pending_subs int := 0;
  v_total_shops_sales numeric(12, 2) := 0;
  v_total_paid_to_shops numeric(12, 2) := 0;
  v_total_owed_to_shops numeric(12, 2) := 0;
  v_shops jsonb := '[]'::jsonb;
  v_pending_list jsonb := '[]'::jsonb;
begin
  perform public.require_admin();

  select coalesce(sum(amount), 0)
  into v_total_sub_revenue
  from public.shop_subscriptions
  where status = 'approved';

  select count(*)
  into v_pending_subs
  from public.shop_subscriptions
  where status = 'pending';

  with order_agg as (
    select
      o.shop_id,
      count(*)::int as total_orders,
      count(*) filter (where o.status = 'delivered')::int as delivered_orders,
      count(*) filter (where o.status not in ('delivered', 'cancelled'))::int as in_progress_orders,
      count(*) filter (where o.status = 'cancelled')::int as cancelled_orders,
      coalesce(sum(o.total) filter (
        where o.status <> 'cancelled'
          and (o.payment_status = 'verified' or o.status = 'delivered')
      ), 0)::numeric(12, 2) as verified_sales,
      coalesce(sum(o.total) filter (
        where o.status not in ('delivered', 'cancelled')
      ), 0)::numeric(12, 2) as in_progress_sales
    from public.orders o
    group by o.shop_id
  ),
  payout_agg as (
    select
      p.shop_id,
      coalesce(sum(p.amount), 0)::numeric(12, 2) as total_paid_out,
      count(*)::int as payouts_count,
      max(p.paid_at) as last_payout_at
    from public.shop_payouts p
    group by p.shop_id
  ),
  pending_sub_agg as (
    select
      s.shop_id,
      count(*)::int as pending_sub_count
    from public.shop_subscriptions s
    where s.status = 'pending'
    group by s.shop_id
  ),
  shop_rows as (
    select
      sh.id as shop_id,
      sh.name as shop_name,
      sh.city as shop_city,
      sh.status::text as shop_status,
      pr.full_name as owner_name,
      pr.phone as owner_phone,
      case
        when sh.subscription_status = 'active'
          and sh.subscription_ends_at is not null
          and sh.subscription_ends_at <= now() then 'expired'
        else sh.subscription_status
      end as effective_subscription_status,
      sh.subscription_plan_name,
      coalesce(sh.subscription_price, 0)::numeric(10, 2) as subscription_price,
      sh.subscription_starts_at,
      sh.subscription_ends_at,
      coalesce(ps.pending_sub_count, 0) > 0 as has_pending_subscription,
      coalesce(oa.total_orders, 0) as total_orders,
      coalesce(oa.delivered_orders, 0) as delivered_orders,
      coalesce(oa.in_progress_orders, 0) as in_progress_orders,
      coalesce(oa.cancelled_orders, 0) as cancelled_orders,
      coalesce(oa.verified_sales, 0)::numeric(12, 2) as verified_sales,
      coalesce(oa.in_progress_sales, 0)::numeric(12, 2) as in_progress_sales,
      coalesce(pa.total_paid_out, 0)::numeric(12, 2) as total_paid_out,
      greatest(0, coalesce(oa.verified_sales, 0) - coalesce(pa.total_paid_out, 0))::numeric(12, 2) as remaining_owed,
      coalesce(pa.payouts_count, 0) as payouts_count,
      pa.last_payout_at
    from public.shops sh
    left join public.profiles pr on pr.id = sh.owner_id
    left join order_agg oa on oa.shop_id = sh.id
    left join payout_agg pa on pa.shop_id = sh.id
    left join pending_sub_agg ps on ps.shop_id = sh.id
    where sh.status <> 'draft'
  )
  select
    count(*) filter (where effective_subscription_status = 'active'),
    count(*) filter (where effective_subscription_status = 'expired'),
    coalesce(sum(verified_sales), 0),
    coalesce(sum(total_paid_out), 0),
    coalesce(sum(remaining_owed), 0),
    coalesce(jsonb_agg(
      jsonb_build_object(
        'shop_id', shop_id,
        'shop_name', shop_name,
        'shop_city', shop_city,
        'shop_status', shop_status,
        'owner_name', owner_name,
        'owner_phone', owner_phone,
        'subscription_status', effective_subscription_status,
        'subscription_plan_name', subscription_plan_name,
        'subscription_price', subscription_price,
        'subscription_starts_at', subscription_starts_at,
        'subscription_ends_at', subscription_ends_at,
        'has_pending_subscription', has_pending_subscription,
        'total_orders', total_orders,
        'delivered_orders', delivered_orders,
        'in_progress_orders', in_progress_orders,
        'cancelled_orders', cancelled_orders,
        'verified_sales', verified_sales,
        'in_progress_sales', in_progress_sales,
        'total_paid_out', total_paid_out,
        'remaining_owed', remaining_owed,
        'payouts_count', payouts_count,
        'last_payout_at', last_payout_at
      )
      order by remaining_owed desc, verified_sales desc, shop_name asc
    ), '[]'::jsonb)
  into
    v_active_subs,
    v_expired_subs,
    v_total_shops_sales,
    v_total_paid_to_shops,
    v_total_owed_to_shops,
    v_shops
  from shop_rows;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', ss.id,
      'shop_id', ss.shop_id,
      'shop_name', sh.name,
      'shop_city', sh.city,
      'owner_name', pr.full_name,
      'owner_phone', pr.phone,
      'plan_id', ss.plan_id,
      'plan_name', ss.plan_name,
      'amount', ss.amount,
      'duration_days', ss.duration_days,
      'payment_method_name', ss.payment_method_name,
      'payment_account_number', ss.payment_account_number,
      'receipt_url', ss.receipt_url,
      'status', ss.status,
      'is_renewal', ss.is_renewal,
      'notes', ss.notes,
      'rejection_reason', ss.rejection_reason,
      'starts_at', ss.starts_at,
      'ends_at', ss.ends_at,
      'created_at', ss.created_at,
      'reviewed_at', ss.reviewed_at
    )
    order by
      case when ss.status = 'pending' then 0 else 1 end,
      ss.created_at desc
  ), '[]'::jsonb)
  into v_pending_list
  from public.shop_subscriptions ss
  join public.shops sh on sh.id = ss.shop_id
  left join public.profiles pr on pr.id = sh.owner_id;

  return jsonb_build_object(
    'total_subscription_revenue', v_total_sub_revenue,
    'active_subscriptions_count', v_active_subs,
    'expired_subscriptions_count', v_expired_subs,
    'pending_subscriptions_count', v_pending_subs,
    'total_shops_sales', v_total_shops_sales,
    'total_paid_to_shops', v_total_paid_to_shops,
    'total_owed_to_shops', v_total_owed_to_shops,
    'shops', v_shops,
    'subscriptions', v_pending_list
  );
end;
$$;

create or replace function public.get_shop_financial_statement(
  p_shop_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_is_admin boolean := (public.current_user_role() = 'admin');
  v_shop public.shops;
  v_owner_name text;
  v_owner_phone text;
  v_effective_sub_status text;
  v_days_remaining int := 0;
  v_total_orders int := 0;
  v_delivered_orders int := 0;
  v_in_progress_orders int := 0;
  v_cancelled_orders int := 0;
  v_verified_sales numeric(12, 2) := 0;
  v_in_progress_sales numeric(12, 2) := 0;
  v_total_paid_out numeric(12, 2) := 0;
  v_remaining_owed numeric(12, 2) := 0;
  v_orders jsonb := '[]'::jsonb;
  v_payouts jsonb := '[]'::jsonb;
  v_subscriptions jsonb := '[]'::jsonb;
begin
  if v_uid is null then
    raise exception 'يرجى تسجيل الدخول أولاً';
  end if;

  if v_is_admin and p_shop_id is not null then
    select * into v_shop from public.shops where id = p_shop_id;
  else
    select * into v_shop from public.shops where owner_id = v_uid;
  end if;

  if v_shop.id is null then
    raise exception 'لم يتم العثور على المتجر';
  end if;

  select full_name, phone into v_owner_name, v_owner_phone
  from public.profiles where id = v_shop.owner_id;

  if v_shop.subscription_status = 'active'
     and v_shop.subscription_ends_at is not null
     and v_shop.subscription_ends_at <= now() then
    v_effective_sub_status := 'expired';
  else
    v_effective_sub_status := v_shop.subscription_status;
  end if;

  if v_shop.subscription_ends_at is not null and v_shop.subscription_ends_at > now() then
    v_days_remaining := greatest(0, ceil(extract(epoch from (v_shop.subscription_ends_at - now())) / 86400.0)::int);
  end if;

  select
    count(*)::int,
    count(*) filter (where status = 'delivered')::int,
    count(*) filter (where status not in ('delivered', 'cancelled'))::int,
    count(*) filter (where status = 'cancelled')::int,
    coalesce(sum(total) filter (
      where status <> 'cancelled'
        and (payment_status = 'verified' or status = 'delivered')
    ), 0)::numeric(12, 2),
    coalesce(sum(total) filter (
      where status not in ('delivered', 'cancelled')
    ), 0)::numeric(12, 2)
  into
    v_total_orders,
    v_delivered_orders,
    v_in_progress_orders,
    v_cancelled_orders,
    v_verified_sales,
    v_in_progress_sales
  from public.orders
  where shop_id = v_shop.id;

  select coalesce(sum(amount), 0)::numeric(12, 2)
  into v_total_paid_out
  from public.shop_payouts
  where shop_id = v_shop.id;

  v_remaining_owed := greatest(0, v_verified_sales - v_total_paid_out);

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', o.id,
      'status', o.status::text,
      'payment_status', o.payment_status,
      'delivery_mode', o.delivery_mode,
      'subtotal', o.subtotal,
      'delivery_fee', o.delivery_fee,
      'total', o.total,
      'payment_method_name', o.payment_method_name,
      'customer_name', coalesce(cp.full_name, 'عميل'),
      'created_at', o.created_at
    )
    order by o.created_at desc
  ), '[]'::jsonb)
  into v_orders
  from (
    select * from public.orders
    where shop_id = v_shop.id
    order by created_at desc
    limit 100
  ) o
  left join public.profiles cp on cp.id = o.customer_id;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', p.id,
      'shop_id', p.shop_id,
      'amount', p.amount,
      'payment_method', p.payment_method,
      'reference_no', p.reference_no,
      'receipt_url', p.receipt_url,
      'notes', p.notes,
      'paid_at', p.paid_at,
      'created_at', p.created_at
    )
    order by p.paid_at desc
  ), '[]'::jsonb)
  into v_payouts
  from public.shop_payouts p
  where p.shop_id = v_shop.id;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', ss.id,
      'shop_id', ss.shop_id,
      'shop_name', v_shop.name,
      'plan_id', ss.plan_id,
      'plan_name', ss.plan_name,
      'amount', ss.amount,
      'duration_days', ss.duration_days,
      'payment_method_name', ss.payment_method_name,
      'payment_account_number', ss.payment_account_number,
      'receipt_url', ss.receipt_url,
      'status', ss.status,
      'is_renewal', ss.is_renewal,
      'notes', ss.notes,
      'rejection_reason', ss.rejection_reason,
      'starts_at', ss.starts_at,
      'ends_at', ss.ends_at,
      'created_at', ss.created_at,
      'reviewed_at', ss.reviewed_at
    )
    order by ss.created_at desc
  ), '[]'::jsonb)
  into v_subscriptions
  from public.shop_subscriptions ss
  where ss.shop_id = v_shop.id;

  return jsonb_build_object(
    'shop_id', v_shop.id,
    'shop_name', v_shop.name,
    'shop_city', v_shop.city,
    'owner_name', v_owner_name,
    'owner_phone', v_owner_phone,
    'subscription_status', v_effective_sub_status,
    'subscription_plan_name', v_shop.subscription_plan_name,
    'subscription_price', coalesce(v_shop.subscription_price, 0),
    'subscription_starts_at', v_shop.subscription_starts_at,
    'subscription_ends_at', v_shop.subscription_ends_at,
    'days_remaining', v_days_remaining,
    'total_orders', v_total_orders,
    'delivered_orders', v_delivered_orders,
    'in_progress_orders', v_in_progress_orders,
    'cancelled_orders', v_cancelled_orders,
    'verified_sales', v_verified_sales,
    'in_progress_sales', v_in_progress_sales,
    'total_paid_out', v_total_paid_out,
    'remaining_owed', v_remaining_owed,
    'orders', v_orders,
    'payouts', v_payouts,
    'subscriptions', v_subscriptions
  );
end;
$$;

create or replace function public.admin_record_shop_payout(
  p_shop_id uuid,
  p_amount numeric,
  p_payment_method text default 'bank_transfer',
  p_reference_no text default null,
  p_receipt_url text default null,
  p_notes text default null
)
returns public.shop_payouts
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop public.shops;
  v_payout public.shop_payouts;
begin
  perform public.require_admin();

  if coalesce(p_amount, 0) <= 0 then
    raise exception 'يرجى إدخال مبلغ تحويل صحيح أكبر من صفر';
  end if;

  select * into v_shop from public.shops where id = p_shop_id;
  if v_shop.id is null then
    raise exception 'المتجر غير موجود';
  end if;

  insert into public.shop_payouts (
    shop_id,
    amount,
    payment_method,
    reference_no,
    receipt_url,
    notes,
    paid_by
  ) values (
    p_shop_id,
    round(p_amount, 2),
    coalesce(nullif(trim(p_payment_method), ''), 'bank_transfer'),
    nullif(trim(coalesce(p_reference_no, '')), ''),
    nullif(trim(coalesce(p_receipt_url, '')), ''),
    nullif(trim(coalesce(p_notes, '')), ''),
    auth.uid()
  )
  returning * into v_payout;

  insert into public.notifications (user_id, title, body, data)
  values (
    v_shop.owner_id,
    'تم تحويل مستحقات لمتجرك',
    format('تم تحويل مبلغ %s ₪ من مستحقات مبيعات متجر "%s" بنجاح.', round(p_amount, 2), v_shop.name),
    jsonb_build_object(
      'type', 'shop_payout_recorded',
      'shop_id', v_shop.id,
      'payout_id', v_payout.id,
      'route', '/shop/sales'
    )
  );

  return v_payout;
end;
$$;

grant execute on function public.get_admin_subscription_and_payout_overview() to authenticated;
grant execute on function public.get_shop_financial_statement(uuid) to authenticated;
grant execute on function public.admin_record_shop_payout(uuid, numeric, text, text, text, text) to authenticated;

notify pgrst, 'reload schema';

commit;
