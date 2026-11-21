-- Revenue Sharing, Commission Agreements, Immutable Financial Ledger,
-- Settlement Receipts & COD Anti-Fraud Protection System

-- 1) Shop Commission Agreement & Financial Hold columns
alter table public.shops
  add column if not exists commission_type text not null default 'percentage',
  add column if not exists commission_rate numeric(6, 2) not null default 5,
  add column if not exists commission_fixed_fee numeric(10, 2) not null default 0,
  add column if not exists credit_limit numeric(10, 2) not null default 300,
  add column if not exists settlement_cycle text not null default 'weekly',
  add column if not exists auto_suspend_on_limit boolean not null default true,
  add column if not exists financial_hold boolean not null default false,
  add column if not exists agreement_version int not null default 1,
  add column if not exists agreement_accepted_version int not null default 0,
  add column if not exists agreement_accepted_at timestamptz,
  add column if not exists agreement_notes text;

-- 2) Immutable Commission Snapshot on Orders
alter table public.orders
  add column if not exists commission_type text not null default 'percentage',
  add column if not exists commission_rate numeric(6, 2) not null default 5,
  add column if not exists commission_fixed_fee numeric(10, 2) not null default 0,
  add column if not exists platform_commission numeric(10, 2) not null default 0,
  add column if not exists shop_net_amount numeric(10, 2) not null default 0,
  add column if not exists commission_status text not null default 'pending';

-- 3) Immutable Financial Ledger
create table if not exists public.shop_commission_ledger (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  order_id uuid references public.orders(id) on delete set null,
  settlement_id uuid,
  entry_type text not null check (entry_type in ('order_commission', 'settlement_payment', 'admin_adjustment')),
  direction text not null check (direction in ('debit', 'credit')),
  amount numeric(10, 2) not null check (amount >= 0),
  note text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists shop_commission_ledger_shop_idx
  on public.shop_commission_ledger (shop_id, created_at desc);

create unique index if not exists shop_commission_ledger_order_uidx
  on public.shop_commission_ledger (order_id)
  where entry_type = 'order_commission' and order_id is not null;

-- 4) Settlement Requests & Payment Proofs
create table if not exists public.shop_settlements (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  amount numeric(10, 2) not null check (amount > 0),
  payment_method text not null default 'cash' check (payment_method in ('cash', 'bank_transfer', 'jawwal_pay', 'palpay')),
  reference_number text,
  receipt_url text,
  notes text,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  admin_note text,
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists shop_settlements_shop_idx
  on public.shop_settlements (shop_id, created_at desc);

create index if not exists shop_settlements_status_idx
  on public.shop_settlements (status, created_at desc);

drop trigger if exists shop_settlements_set_updated_at on public.shop_settlements;
create trigger shop_settlements_set_updated_at
  before update on public.shop_settlements
  for each row execute function public.set_updated_at();

alter table public.shop_commission_ledger enable row level security;
alter table public.shop_settlements enable row level security;

drop policy if exists "ledger_admin_read" on public.shop_commission_ledger;
create policy "ledger_admin_read"
  on public.shop_commission_ledger for select
  using (public.current_user_role() = 'admin');

drop policy if exists "ledger_shop_own_read" on public.shop_commission_ledger;
create policy "ledger_shop_own_read"
  on public.shop_commission_ledger for select
  using (shop_id = public.current_shop_id());

drop policy if exists "settlements_admin_read" on public.shop_settlements;
create policy "settlements_admin_read"
  on public.shop_settlements for select
  using (public.current_user_role() = 'admin');

drop policy if exists "settlements_shop_own_read" on public.shop_settlements;
create policy "settlements_shop_own_read"
  on public.shop_settlements for select
  using (shop_id = public.current_shop_id());

-- Helper: Pure commission calculator
create or replace function public.compute_order_commission(
  p_total numeric,
  p_type text,
  p_rate numeric,
  p_fixed numeric
)
returns numeric
language plpgsql
immutable
as $$
declare
  v_total numeric := greatest(0, coalesce(p_total, 0));
  v_rate numeric := greatest(0, least(100, coalesce(p_rate, 0)));
  v_fixed numeric := greatest(0, coalesce(p_fixed, 0));
  v_comm numeric := 0;
begin
  if p_type = 'fixed' then
    v_comm := v_fixed;
  elsif p_type = 'hybrid' then
    v_comm := round((v_total * v_rate / 100.0) + v_fixed, 2);
  else
    v_comm := round(v_total * v_rate / 100.0, 2);
  end if;
  return least(v_total, greatest(0, v_comm));
end;
$$;

-- Helper: Computes outstanding balance for a shop
create or replace function public.shop_outstanding_balance(p_shop_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select greatest(
    0,
    coalesce(sum(case when direction = 'debit' then amount else -amount end), 0)
  )::numeric(10, 2)
  from public.shop_commission_ledger
  where shop_id = p_shop_id;
$$;

-- Helper: Syncs automatic financial hold when credit limit is reached/cleared
create or replace function public.sync_shop_financial_hold(p_shop_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop public.shops;
  v_bal numeric(10, 2);
begin
  select * into v_shop from public.shops where id = p_shop_id;
  if v_shop.id is null then return; end if;
  if not coalesce(v_shop.auto_suspend_on_limit, true) then return; end if;

  v_bal := public.shop_outstanding_balance(p_shop_id);
  if v_shop.credit_limit > 0 and v_bal >= v_shop.credit_limit then
    if not v_shop.financial_hold then
      update public.shops
      set financial_hold = true, updated_at = now()
      where id = p_shop_id;
    end if;
  else
    if v_shop.financial_hold then
      update public.shops
      set financial_hold = false, updated_at = now()
      where id = p_shop_id;
    end if;
  end if;
end;
$$;

-- Trigger 1 (BEFORE): Snapshot commission on order insert & update commission_status
create or replace function public.orders_commission_before_fn()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop public.shops;
  v_comm numeric(10, 2);
begin
  if tg_op = 'INSERT' then
    select * into v_shop from public.shops where id = new.shop_id;
    new.commission_type := coalesce(v_shop.commission_type, 'percentage');
    new.commission_rate := coalesce(v_shop.commission_rate, 5);
    new.commission_fixed_fee := coalesce(v_shop.commission_fixed_fee, 0);
    v_comm := public.compute_order_commission(
      new.total,
      new.commission_type,
      new.commission_rate,
      new.commission_fixed_fee
    );
    new.platform_commission := v_comm;
    new.shop_net_amount := greatest(0, round(coalesce(new.total, 0) - v_comm, 2));
    new.commission_status := case
      when new.status = 'delivered' then 'due'
      when new.status = 'cancelled' then 'void'
      else 'pending'
    end;
  elsif tg_op = 'UPDATE' then
    if new.status = 'delivered' then
      new.commission_status := 'due';
    elsif new.status = 'cancelled' then
      new.commission_status := 'void';
    elsif new.status is distinct from old.status then
      new.commission_status := 'pending';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists orders_commission_before_trg on public.orders;
create trigger orders_commission_before_trg
  before insert or update of status, total on public.orders
  for each row execute function public.orders_commission_before_fn();

-- Trigger 2 (AFTER): Post immutable ledger entry on delivery (or reverse if admin cancels after delivery)
create or replace function public.orders_commission_after_fn()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing numeric(10, 2);
begin
  if new.status = 'delivered' and (tg_op = 'INSERT' or old.status is distinct from 'delivered') then
    if coalesce(new.platform_commission, 0) > 0 then
      insert into public.shop_commission_ledger (
        shop_id,
        order_id,
        entry_type,
        direction,
        amount,
        note,
        created_by
      )
      values (
        new.shop_id,
        new.id,
        'order_commission',
        'debit',
        new.platform_commission,
        'عمولة طلب #' || upper(left(new.id::text, 8)),
        auth.uid()
      )
      on conflict (order_id) where (entry_type = 'order_commission' and order_id is not null)
      do nothing;

      perform public.sync_shop_financial_hold(new.shop_id);
    end if;
  elsif tg_op = 'UPDATE' and old.status = 'delivered' and new.status = 'cancelled' then
    select amount into v_existing
    from public.shop_commission_ledger
    where order_id = new.id and entry_type = 'order_commission'
    limit 1;

    if coalesce(v_existing, 0) > 0 then
      insert into public.shop_commission_ledger (
        shop_id,
        order_id,
        entry_type,
        direction,
        amount,
        note,
        created_by
      )
      values (
        new.shop_id,
        new.id,
        'admin_adjustment',
        'credit',
        v_existing,
        'استرداد عمولة طلب ملغي #' || upper(left(new.id::text, 8)),
        auth.uid()
      );
      perform public.sync_shop_financial_hold(new.shop_id);
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists orders_commission_after_trg on public.orders;
create trigger orders_commission_after_trg
  after insert or update of status on public.orders
  for each row execute function public.orders_commission_after_fn();

-- Anti-Fraud Guardrail 1: Shop cannot cancel shipped/delivered orders or revert delivered orders
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
  v_current public.orders;
  v_result public.orders;
  sid uuid;
begin
  sid := public.require_approved_shop();

  if p_status not in ('confirmed', 'processing', 'shipped', 'delivered', 'cancelled') then
    raise exception 'حالة الطلب غير مسموحة';
  end if;

  select * into v_current
  from public.orders
  where id = p_order_id and shop_id = sid;

  if v_current.id is null then
    raise exception 'الطلب غير موجود';
  end if;

  if v_current.status = 'delivered' and p_status <> 'delivered' then
    raise exception 'لا يمكن تغيير حالة الطلب بعد التسليم. تواصل مع الإدارة.';
  end if;

  if p_status = 'cancelled' and v_current.status in ('shipped', 'delivered') then
    raise exception 'لا يمكن إلغاء الطلب بعد الشحن أو التسليم. تواصل مع الإدارة.';
  end if;

  update public.orders
  set status = p_status, updated_at = now()
  where id = p_order_id and shop_id = sid
  returning * into v_result;

  return v_result;
end;
$$;

-- Anti-Fraud Guardrail 2: Shop cannot delete account with unpaid platform dues
create or replace function public.delete_my_shop_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  sid uuid;
  v_bal numeric(10, 2);
begin
  if uid is null then
    raise exception 'Authentication required';
  end if;

  select id into sid
  from public.shops
  where owner_id = uid
  limit 1;

  if sid is not null then
    v_bal := public.shop_outstanding_balance(sid);
    if v_bal > 0 then
      raise exception 'لا يمكن حذف المحل قبل تسوية المستحقات المالية للمنصة (% ₪)', v_bal;
    end if;

    update public.products
    set status = 'deleted', updated_at = now()
    where shop_id = sid;

    update public.shops
    set status = 'suspended', updated_at = now()
    where id = sid;
  end if;

  perform set_config('app.allow_self_deactivate', 'true', true);

  update public.profiles
  set is_active = false, updated_at = now()
  where id = uid;
end;
$$;

-- Admin RPC 1: Full Platform Revenue & Per-Shop Financial Overview
create or replace function public.admin_revenue_overview()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shops jsonb;
  v_pending_settlements jsonb;
begin
  perform public.require_admin();

  select coalesce(jsonb_agg(row_to_json(t) order by t.outstanding_balance desc, t.delivered_sales desc), '[]'::jsonb)
  into v_shops
  from (
    select
      s.id as shop_id,
      s.name as shop_name,
      s.city as shop_city,
      s.status::text as status,
      s.commission_type,
      s.commission_rate,
      s.commission_fixed_fee,
      s.credit_limit,
      s.settlement_cycle,
      s.auto_suspend_on_limit,
      s.financial_hold,
      s.agreement_version,
      s.agreement_accepted_version,
      s.agreement_accepted_at,
      s.agreement_notes,
      coalesce(ord.total_orders, 0) as total_orders,
      coalesce(ord.delivered_orders, 0) as delivered_orders,
      coalesce(ord.cancelled_orders, 0) as cancelled_orders,
      coalesce(ord.delivered_sales, 0) as delivered_sales,
      coalesce(ldg.commission_earned, 0) as commission_earned,
      coalesce(ldg.total_paid, 0) as total_paid,
      greatest(0, coalesce(ldg.debits, 0) - coalesce(ldg.credits, 0)) as outstanding_balance,
      coalesce(stl.pending_count, 0) as pending_settlements_count,
      coalesce(stl.pending_amount, 0) as pending_settlements_amount
    from public.shops s
    left join (
      select
        shop_id,
        count(*)::int as total_orders,
        count(*) filter (where status = 'delivered')::int as delivered_orders,
        count(*) filter (where status = 'cancelled')::int as cancelled_orders,
        coalesce(sum(total) filter (where status = 'delivered'), 0)::numeric(10, 2) as delivered_sales
      from public.orders
      group by shop_id
    ) ord on ord.shop_id = s.id
    left join (
      select
        shop_id,
        coalesce(sum(amount) filter (where entry_type = 'order_commission' and direction = 'debit'), 0)::numeric(10, 2) as commission_earned,
        coalesce(sum(amount) filter (where entry_type = 'settlement_payment' and direction = 'credit'), 0)::numeric(10, 2) as total_paid,
        coalesce(sum(amount) filter (where direction = 'debit'), 0)::numeric(10, 2) as debits,
        coalesce(sum(amount) filter (where direction = 'credit'), 0)::numeric(10, 2) as credits
      from public.shop_commission_ledger
      group by shop_id
    ) ldg on ldg.shop_id = s.id
    left join (
      select
        shop_id,
        count(*) filter (where status = 'pending')::int as pending_count,
        coalesce(sum(amount) filter (where status = 'pending'), 0)::numeric(10, 2) as pending_amount
      from public.shop_settlements
      group by shop_id
    ) stl on stl.shop_id = s.id
    where s.status is distinct from 'draft'
  ) t;

  select coalesce(jsonb_agg(
    to_jsonb(st.*) || jsonb_build_object('shop_name', sh.name)
    order by st.created_at desc
  ), '[]'::jsonb)
  into v_pending_settlements
  from public.shop_settlements st
  join public.shops sh on sh.id = st.shop_id
  where st.status = 'pending';

  return jsonb_build_object(
    'total_delivered_sales', coalesce((select sum(total) from public.orders where status = 'delivered'), 0),
    'total_commission_earned', coalesce((select sum(amount) from public.shop_commission_ledger where entry_type = 'order_commission' and direction = 'debit'), 0),
    'total_collected', coalesce((select sum(amount) from public.shop_commission_ledger where entry_type = 'settlement_payment' and direction = 'credit'), 0),
    'total_outstanding', coalesce((
      select sum(greatest(0, deb - cred))
      from (
        select
          shop_id,
          coalesce(sum(amount) filter (where direction = 'debit'), 0) as deb,
          coalesce(sum(amount) filter (where direction = 'credit'), 0) as cred
        from public.shop_commission_ledger
        group by shop_id
      ) x
    ), 0),
    'pending_settlements_count', (select count(*) from public.shop_settlements where status = 'pending'),
    'pending_settlements_amount', coalesce((select sum(amount) from public.shop_settlements where status = 'pending'), 0),
    'shops_on_hold', (select count(*) from public.shops where financial_hold = true),
    'shops', v_shops,
    'pending_settlements', v_pending_settlements
  );
end;
$$;

grant execute on function public.admin_revenue_overview() to authenticated;

-- Admin RPC 2: Update Shop Commission Agreement
create or replace function public.admin_update_shop_agreement(
  p_shop_id uuid,
  p_commission_type text,
  p_commission_rate numeric,
  p_commission_fixed_fee numeric default 0,
  p_credit_limit numeric default 300,
  p_settlement_cycle text default 'weekly',
  p_auto_suspend_on_limit boolean default true,
  p_agreement_notes text default null
)
returns public.shops
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop public.shops;
begin
  perform public.require_admin();

  if p_commission_type not in ('percentage', 'fixed', 'hybrid') then
    raise exception 'نوع الاتفاق غير صالح';
  end if;
  if coalesce(p_commission_rate, 0) < 0 or coalesce(p_commission_rate, 0) > 100 then
    raise exception 'نسبة العمولة يجب أن تكون بين 0 و 100';
  end if;
  if coalesce(p_commission_fixed_fee, 0) < 0 then
    raise exception 'المبلغ الثابت غير صالح';
  end if;
  if coalesce(p_credit_limit, 0) < 0 then
    raise exception 'سقف الذمة غير صالح';
  end if;

  update public.shops
  set
    commission_type = p_commission_type,
    commission_rate = round(coalesce(p_commission_rate, 0), 2),
    commission_fixed_fee = round(coalesce(p_commission_fixed_fee, 0), 2),
    credit_limit = round(coalesce(p_credit_limit, 300), 2),
    settlement_cycle = coalesce(nullif(trim(p_settlement_cycle), ''), 'weekly'),
    auto_suspend_on_limit = coalesce(p_auto_suspend_on_limit, true),
    agreement_notes = nullif(trim(coalesce(p_agreement_notes, '')), ''),
    agreement_version = agreement_version + 1,
    updated_at = now()
  where id = p_shop_id
  returning * into v_shop;

  if v_shop.id is null then
    raise exception 'المحل غير موجود';
  end if;

  perform public.sync_shop_financial_hold(p_shop_id);
  return v_shop;
end;
$$;

grant execute on function public.admin_update_shop_agreement(uuid, text, numeric, numeric, numeric, text, boolean, text) to authenticated;

-- Admin RPC 3: Manual Financial Hold / Release
create or replace function public.admin_set_shop_financial_hold(
  p_shop_id uuid,
  p_hold boolean
)
returns public.shops
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop public.shops;
begin
  perform public.require_admin();
  update public.shops
  set financial_hold = coalesce(p_hold, false), updated_at = now()
  where id = p_shop_id
  returning * into v_shop;
  return v_shop;
end;
$$;

grant execute on function public.admin_set_shop_financial_hold(uuid, boolean) to authenticated;

-- Admin RPC 4: Approve or Reject a Shop Settlement Request
create or replace function public.admin_review_settlement(
  p_settlement_id uuid,
  p_approve boolean,
  p_admin_note text default null
)
returns public.shop_settlements
language plpgsql
security definer
set search_path = public
as $$
declare
  v_stl public.shop_settlements;
begin
  perform public.require_admin();

  select * into v_stl from public.shop_settlements where id = p_settlement_id;
  if v_stl.id is null then
    raise exception 'طلب التسوية غير موجود';
  end if;
  if v_stl.status <> 'pending' then
    raise exception 'تمت مراجعة هذا الطلب مسبقاً';
  end if;

  update public.shop_settlements
  set
    status = case when p_approve then 'approved' else 'rejected' end,
    admin_note = nullif(trim(coalesce(p_admin_note, '')), ''),
    reviewed_by = auth.uid(),
    reviewed_at = now(),
    updated_at = now()
  where id = p_settlement_id
  returning * into v_stl;

  if p_approve then
    insert into public.shop_commission_ledger (
      shop_id,
      settlement_id,
      entry_type,
      direction,
      amount,
      note,
      created_by
    )
    values (
      v_stl.shop_id,
      v_stl.id,
      'settlement_payment',
      'credit',
      v_stl.amount,
      coalesce(nullif(trim(coalesce(v_stl.reference_number, '')), ''), 'سداد تسوية معتمد'),
      auth.uid()
    );
    perform public.sync_shop_financial_hold(v_stl.shop_id);
  end if;

  return v_stl;
end;
$$;

grant execute on function public.admin_review_settlement(uuid, boolean, text) to authenticated;

-- Admin RPC 5: Directly record cash / transfer received from a shop
create or replace function public.admin_record_shop_payment(
  p_shop_id uuid,
  p_amount numeric,
  p_payment_method text default 'cash',
  p_reference_number text default null,
  p_note text default null
)
returns public.shop_settlements
language plpgsql
security definer
set search_path = public
as $$
declare
  v_stl public.shop_settlements;
begin
  perform public.require_admin();

  if coalesce(p_amount, 0) <= 0 then
    raise exception 'مبلغ السداد يجب أن يكون أكبر من صفر';
  end if;

  insert into public.shop_settlements (
    shop_id,
    amount,
    payment_method,
    reference_number,
    notes,
    status,
    admin_note,
    reviewed_by,
    reviewed_at
  )
  values (
    p_shop_id,
    round(p_amount, 2),
    coalesce(nullif(trim(p_payment_method), ''), 'cash'),
    nullif(trim(coalesce(p_reference_number, '')), ''),
    nullif(trim(coalesce(p_note, '')), ''),
    'approved',
    'تحصيل مباشر بواسطة الإدارة',
    auth.uid(),
    now()
  )
  returning * into v_stl;

  insert into public.shop_commission_ledger (
    shop_id,
    settlement_id,
    entry_type,
    direction,
    amount,
    note,
    created_by
  )
  values (
    p_shop_id,
    v_stl.id,
    'settlement_payment',
    'credit',
    v_stl.amount,
    coalesce(nullif(trim(coalesce(p_note, '')), ''), 'تحصيل مباشر بواسطة الإدارة'),
    auth.uid()
  );

  perform public.sync_shop_financial_hold(p_shop_id);
  return v_stl;
end;
$$;

grant execute on function public.admin_record_shop_payment(uuid, numeric, text, text, text) to authenticated;

-- Admin RPC 6: Shop Ledger & Settlements History
create or replace function public.admin_shop_ledger(p_shop_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_admin();
  return jsonb_build_object(
    'ledger', coalesce((
      select jsonb_agg(to_jsonb(l.*) order by l.created_at desc)
      from public.shop_commission_ledger l
      where l.shop_id = p_shop_id
    ), '[]'::jsonb),
    'settlements', coalesce((
      select jsonb_agg(to_jsonb(st.*) order by st.created_at desc)
      from public.shop_settlements st
      where st.shop_id = p_shop_id
    ), '[]'::jsonb)
  );
end;
$$;

grant execute on function public.admin_shop_ledger(uuid) to authenticated;

-- Shop RPC 1: Own Financial Summary, Agreement, Ledger & Settlements
create or replace function public.shop_my_finance_summary()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  sid uuid := public.current_shop_id();
  v_shop public.shops;
  v_total_orders int := 0;
  v_delivered_orders int := 0;
  v_cancelled_orders int := 0;
  v_delivered_sales numeric(10, 2) := 0;
  v_commission_earned numeric(10, 2) := 0;
  v_total_paid numeric(10, 2) := 0;
  v_outstanding numeric(10, 2) := 0;
  v_pending_cnt int := 0;
  v_pending_amt numeric(10, 2) := 0;
begin
  if sid is null then
    raise exception 'Shop account required';
  end if;

  select * into v_shop from public.shops where id = sid;

  select
    count(*)::int,
    count(*) filter (where status = 'delivered')::int,
    count(*) filter (where status = 'cancelled')::int,
    coalesce(sum(total) filter (where status = 'delivered'), 0)::numeric(10, 2)
  into v_total_orders, v_delivered_orders, v_cancelled_orders, v_delivered_sales
  from public.orders
  where shop_id = sid;

  select
    coalesce(sum(amount) filter (where entry_type = 'order_commission' and direction = 'debit'), 0)::numeric(10, 2),
    coalesce(sum(amount) filter (where entry_type = 'settlement_payment' and direction = 'credit'), 0)::numeric(10, 2),
    greatest(0, coalesce(sum(case when direction = 'debit' then amount else -amount end), 0))::numeric(10, 2)
  into v_commission_earned, v_total_paid, v_outstanding
  from public.shop_commission_ledger
  where shop_id = sid;

  select
    count(*) filter (where status = 'pending')::int,
    coalesce(sum(amount) filter (where status = 'pending'), 0)::numeric(10, 2)
  into v_pending_cnt, v_pending_amt
  from public.shop_settlements
  where shop_id = sid;

  return jsonb_build_object(
    'account', jsonb_build_object(
      'shop_id', v_shop.id,
      'shop_name', v_shop.name,
      'shop_city', v_shop.city,
      'status', v_shop.status::text,
      'commission_type', v_shop.commission_type,
      'commission_rate', v_shop.commission_rate,
      'commission_fixed_fee', v_shop.commission_fixed_fee,
      'credit_limit', v_shop.credit_limit,
      'settlement_cycle', v_shop.settlement_cycle,
      'auto_suspend_on_limit', v_shop.auto_suspend_on_limit,
      'financial_hold', v_shop.financial_hold,
      'agreement_version', v_shop.agreement_version,
      'agreement_accepted_version', v_shop.agreement_accepted_version,
      'agreement_accepted_at', v_shop.agreement_accepted_at,
      'agreement_notes', v_shop.agreement_notes,
      'total_orders', v_total_orders,
      'delivered_orders', v_delivered_orders,
      'cancelled_orders', v_cancelled_orders,
      'delivered_sales', v_delivered_sales,
      'commission_earned', v_commission_earned,
      'total_paid', v_total_paid,
      'outstanding_balance', v_outstanding,
      'pending_settlements_count', v_pending_cnt,
      'pending_settlements_amount', v_pending_amt
    ),
    'ledger', coalesce((
      select jsonb_agg(to_jsonb(l.*) order by l.created_at desc)
      from (
        select * from public.shop_commission_ledger
        where shop_id = sid
        order by created_at desc
        limit 50
      ) l
    ), '[]'::jsonb),
    'settlements', coalesce((
      select jsonb_agg(to_jsonb(st.*) order by st.created_at desc)
      from (
        select * from public.shop_settlements
        where shop_id = sid
        order by created_at desc
        limit 30
      ) st
    ), '[]'::jsonb)
  );
end;
$$;

grant execute on function public.shop_my_finance_summary() to authenticated;

-- Shop RPC 2: Digital Acceptance of Commission Agreement
create or replace function public.shop_accept_commission_agreement()
returns public.shops
language plpgsql
security definer
set search_path = public
as $$
declare
  sid uuid := public.current_shop_id();
  v_shop public.shops;
begin
  if sid is null then
    raise exception 'Shop account required';
  end if;

  update public.shops
  set
    agreement_accepted_version = agreement_version,
    agreement_accepted_at = now(),
    updated_at = now()
  where id = sid
  returning * into v_shop;

  return v_shop;
end;
$$;

grant execute on function public.shop_accept_commission_agreement() to authenticated;

-- Shop RPC 3: Submit a Settlement Request with Payment Proof
create or replace function public.shop_submit_settlement(
  p_amount numeric,
  p_payment_method text default 'cash',
  p_reference_number text default null,
  p_receipt_url text default null,
  p_notes text default null
)
returns public.shop_settlements
language plpgsql
security definer
set search_path = public
as $$
declare
  sid uuid := public.current_shop_id();
  v_stl public.shop_settlements;
begin
  if sid is null then
    raise exception 'Shop account required';
  end if;

  if coalesce(p_amount, 0) <= 0 then
    raise exception 'مبلغ التسوية يجب أن يكون أكبر من صفر';
  end if;

  insert into public.shop_settlements (
    shop_id,
    amount,
    payment_method,
    reference_number,
    receipt_url,
    notes,
    status
  )
  values (
    sid,
    round(p_amount, 2),
    coalesce(nullif(trim(p_payment_method), ''), 'cash'),
    nullif(trim(coalesce(p_reference_number, '')), ''),
    nullif(trim(coalesce(p_receipt_url, '')), ''),
    nullif(trim(coalesce(p_notes, '')), ''),
    'pending'
  )
  returning * into v_stl;

  return v_stl;
end;
$$;

grant execute on function public.shop_submit_settlement(numeric, text, text, text, text) to authenticated;

-- Backfill commission snapshots & ledger entries for existing delivered orders
do $$
declare
  r record;
  v_comm numeric(10, 2);
begin
  for r in
    select o.id, o.shop_id, o.total, o.status,
           coalesce(s.commission_type, 'percentage') as ctype,
           coalesce(s.commission_rate, 5) as crate,
           coalesce(s.commission_fixed_fee, 0) as cfixed
    from public.orders o
    join public.shops s on s.id = o.shop_id
    where o.platform_commission = 0 and o.total > 0
  loop
    v_comm := public.compute_order_commission(r.total, r.ctype, r.crate, r.cfixed);
    update public.orders
    set
      commission_type = r.ctype,
      commission_rate = r.crate,
      commission_fixed_fee = r.cfixed,
      platform_commission = v_comm,
      shop_net_amount = greatest(0, round(r.total - v_comm, 2)),
      commission_status = case
        when r.status = 'delivered' then 'due'
        when r.status = 'cancelled' then 'void'
        else 'pending'
      end
    where id = r.id;

    if r.status = 'delivered' and v_comm > 0 then
      insert into public.shop_commission_ledger (
        shop_id, order_id, entry_type, direction, amount, note
      )
      values (
        r.shop_id,
        r.id,
        'order_commission',
        'debit',
        v_comm,
        'عمولة طلب #' || upper(left(r.id::text, 8))
      )
      on conflict (order_id) where (entry_type = 'order_commission' and order_id is not null)
      do nothing;
    end if;
  end loop;
end $$;
