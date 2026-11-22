-- =============================================================================
--  033_delivery_and_payment_receipts.sql
--  Complete Dual-Delivery (Shop Delivery vs Customer Pickup) + Admin-Managed
--  Gaza Banks & E-Wallets + Mandatory Transfer Receipt Upload + Shop Payment
--  Verification & Customer Issue Feedback Loop (with Push Notifications).
-- =============================================================================
begin;

-- -----------------------------------------------------------------------------
-- 1) Shop Delivery Fee (controlled by each Shop Owner)
-- -----------------------------------------------------------------------------
alter table public.shops
  add column if not exists delivery_fee numeric(10, 2) not null default 0
  check (delivery_fee >= 0);

create or replace function public.shop_update_delivery_fee(
  p_delivery_fee numeric
)
returns public.shops
language plpgsql
security definer
set search_path = public
as $$
declare
  sid uuid;
  result public.shops;
begin
  sid := public.require_shop_owner();

  if p_delivery_fee is null or p_delivery_fee < 0 or p_delivery_fee > 5000 then
    raise exception 'يرجى إدخال قيمة توصيل صحيحة (0 أو أكثر)';
  end if;

  update public.shops
  set delivery_fee = round(p_delivery_fee::numeric, 2),
      updated_at = now()
  where id = sid
  returning * into result;

  if result.id is null then
    raise exception 'المتجر غير موجود';
  end if;

  return result;
end;
$$;

grant execute on function public.shop_update_delivery_fee(numeric) to authenticated;

-- Extend shop_update_profile with optional p_delivery_fee (fully backwards compatible)
drop function if exists public.shop_update_profile(text, text, text, text, text, text, text);
create or replace function public.shop_update_profile(
  p_shop_name text,
  p_description text,
  p_city text,
  p_address text,
  p_commercial_register text,
  p_owner_name text,
  p_phone text,
  p_delivery_fee numeric default null
)
returns public.shops
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.shops;
  sid uuid;
  sstatus public.shop_status;
begin
  sid := public.require_shop_owner();
  select status into sstatus from public.shops where id = sid;

  if sstatus not in ('approved', 'draft', 'rejected') then
    raise exception 'لا يمكن تعديل الملف في الحالة الحالية';
  end if;

  if coalesce(trim(p_shop_name), '') = ''
     or coalesce(trim(p_description), '') = ''
     or coalesce(trim(p_city), '') = ''
     or coalesce(trim(p_address), '') = ''
     or coalesce(trim(p_commercial_register), '') = ''
     or coalesce(trim(p_owner_name), '') = ''
     or coalesce(trim(p_phone), '') = '' then
    raise exception 'جميع الحقول مطلوبة';
  end if;

  if p_delivery_fee is not null and (p_delivery_fee < 0 or p_delivery_fee > 5000) then
    raise exception 'يرجى إدخال قيمة توصيل صحيحة';
  end if;

  update public.profiles
  set
    full_name = trim(p_owner_name),
    phone = trim(p_phone),
    city = trim(p_city),
    address = trim(p_address),
    updated_at = now()
  where id = auth.uid();

  update public.shops
  set
    name = trim(p_shop_name),
    description = trim(p_description),
    city = trim(p_city),
    address = trim(p_address),
    commercial_register = trim(p_commercial_register),
    delivery_fee = case
      when p_delivery_fee is not null then round(p_delivery_fee::numeric, 2)
      else delivery_fee
    end,
    updated_at = now()
  where id = sid
  returning * into result;

  return result;
end;
$$;

grant execute on function public.shop_update_profile(text, text, text, text, text, text, text, numeric) to authenticated;

-- -----------------------------------------------------------------------------
-- 2) Admin-Managed Payment Methods (Gaza Banks & Electronic Wallets)
-- -----------------------------------------------------------------------------
create table if not exists public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  name_en text,
  type text not null default 'bank' check (type in ('bank', 'wallet')),
  account_number text not null,
  iban text,
  account_holder text not null default 'منصة وصلة',
  instructions text,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists payment_methods_active_sort_idx
  on public.payment_methods (is_active, sort_order, name);

alter table public.payment_methods enable row level security;

drop policy if exists "payment_methods_read" on public.payment_methods;
create policy "payment_methods_read" on public.payment_methods
  for select to authenticated
  using (is_active = true or public.current_user_role() = 'admin');

drop policy if exists "payment_methods_admin_manage" on public.payment_methods;
create policy "payment_methods_admin_manage" on public.payment_methods
  for all to authenticated
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

-- Seed Gaza banks & e-wallets only if table is empty (Admin can edit/toggle/delete freely)
insert into public.payment_methods (
  name, name_en, type, account_number, iban, account_holder, instructions, is_active, sort_order
)
select * from (
  values
    ('بنك فلسطين', 'Bank of Palestine', 'bank', '0458-000000-001', 'PS00PALS0458000000000001', 'منصة وصلة للتجارة', 'حوّل المبلغ الإجمالي عبر تطبيق بنكي أو الصراف ثم ارفع لقطة شاشة واضحة للإشعار.', true, 1),
    ('محفظة بال باي (PalPay)', 'PalPay Wallet', 'wallet', '0599000001', null, 'منصة وصلة - PalPay', 'حوّل إلى رقم المحفظة أعلاه عبر تطبيق PalPay ثم ارفع صورة إشعار التحويل.', true, 2),
    ('محفظة جوال باي (Jawwal Pay)', 'Jawwal Pay Wallet', 'wallet', '0599000002', null, 'منصة وصلة - Jawwal Pay', 'حوّل إلى رقم المحفظة أعلاه عبر تطبيق Jawwal Pay ثم ارفع صورة إشعار التحويل.', true, 3),
    ('البنك الإسلامي الفلسطيني', 'Palestine Islamic Bank', 'bank', '1020-000000-001', 'PS00PIBC0000000000000001', 'منصة وصلة للتجارة', 'حوّل المبلغ عبر تطبيق البنك الإسلامي الفلسطيني ثم ارفع صورة الإشعار.', true, 4),
    ('البنك الإسلامي العربي', 'Arab Islamic Bank', 'bank', '2030-000000-001', 'PS00AIBC0000000000000001', 'منصة وصلة للتجارة', 'حوّل المبلغ عبر تطبيق البنك الإسلامي العربي ثم ارفع صورة الإشعار.', true, 5),
    ('بنك القدس', 'Al-Quds Bank', 'bank', '3040-000000-001', 'PS00QUDS0000000000000001', 'منصة وصلة للتجارة', 'حوّل المبلغ عبر تطبيق بنك القدس ثم ارفع صورة الإشعار.', false, 6),
    ('البنك الوطني (TNB)', 'The National Bank', 'bank', '4050-000000-001', 'PS00TNBC0000000000000001', 'منصة وصلة للتجارة', 'حوّل المبلغ عبر تطبيق البنك الوطني ثم ارفع صورة الإشعار.', false, 7)
) as seed(name, name_en, type, account_number, iban, account_holder, instructions, is_active, sort_order)
where not exists (select 1 from public.payment_methods limit 1);

-- Admin RPCs for Payment Methods
create or replace function public.admin_upsert_payment_method(
  p_name text,
  p_account_number text,
  p_type text default 'bank',
  p_name_en text default null,
  p_iban text default null,
  p_account_holder text default null,
  p_instructions text default null,
  p_is_active boolean default true,
  p_sort_order int default 0,
  p_id uuid default null
)
returns public.payment_methods
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.payment_methods;
  v_type text;
begin
  if public.current_user_role() is distinct from 'admin' then
    raise exception 'غير مصرح — صلاحية الإدارة مطلوبة';
  end if;

  if coalesce(trim(p_name), '') = '' then
    raise exception 'يرجى إدخال اسم البنك أو المحفظة';
  end if;

  if coalesce(trim(p_account_number), '') = '' then
    raise exception 'يرجى إدخال رقم الحساب أو رقم المحفظة';
  end if;

  v_type := case when lower(trim(coalesce(p_type, 'bank'))) = 'wallet' then 'wallet' else 'bank' end;

  if p_id is null then
    insert into public.payment_methods (
      name,
      name_en,
      type,
      account_number,
      iban,
      account_holder,
      instructions,
      is_active,
      sort_order
    )
    values (
      trim(p_name),
      nullif(trim(coalesce(p_name_en, '')), ''),
      v_type,
      trim(p_account_number),
      nullif(trim(coalesce(p_iban, '')), ''),
      coalesce(nullif(trim(coalesce(p_account_holder, '')), ''), 'منصة وصلة'),
      nullif(trim(coalesce(p_instructions, '')), ''),
      coalesce(p_is_active, true),
      coalesce(p_sort_order, 0)
    )
    returning * into result;
  else
    update public.payment_methods
    set
      name = trim(p_name),
      name_en = nullif(trim(coalesce(p_name_en, '')), ''),
      type = v_type,
      account_number = trim(p_account_number),
      iban = nullif(trim(coalesce(p_iban, '')), ''),
      account_holder = coalesce(nullif(trim(coalesce(p_account_holder, '')), ''), account_holder),
      instructions = nullif(trim(coalesce(p_instructions, '')), ''),
      is_active = coalesce(p_is_active, is_active),
      sort_order = coalesce(p_sort_order, sort_order),
      updated_at = now()
    where id = p_id
    returning * into result;

    if result.id is null then
      raise exception 'طريقة الدفع غير موجودة';
    end if;
  end if;

  return result;
end;
$$;

create or replace function public.admin_toggle_payment_method(
  p_id uuid,
  p_is_active boolean
)
returns public.payment_methods
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.payment_methods;
begin
  if public.current_user_role() is distinct from 'admin' then
    raise exception 'غير مصرح — صلاحية الإدارة مطلوبة';
  end if;

  update public.payment_methods
  set is_active = coalesce(p_is_active, false),
      updated_at = now()
  where id = p_id
  returning * into result;

  if result.id is null then
    raise exception 'طريقة الدفع غير موجودة';
  end if;

  return result;
end;
$$;

create or replace function public.admin_delete_payment_method(
  p_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_user_role() is distinct from 'admin' then
    raise exception 'غير مصرح — صلاحية الإدارة مطلوبة';
  end if;

  delete from public.payment_methods where id = p_id;
end;
$$;

grant execute on function public.admin_upsert_payment_method(text, text, text, text, text, text, text, boolean, int, uuid) to authenticated;
grant execute on function public.admin_toggle_payment_method(uuid, boolean) to authenticated;
grant execute on function public.admin_delete_payment_method(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 3) Storage Bucket for Payment Receipts
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('payment-receipts', 'payment-receipts', true)
on conflict (id) do update set public = true;

drop policy if exists "payment_receipts_read" on storage.objects;
create policy "payment_receipts_read" on storage.objects
  for select to public
  using (bucket_id = 'payment-receipts');

drop policy if exists "payment_receipts_insert_own" on storage.objects;
create policy "payment_receipts_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'payment-receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "payment_receipts_update_own" on storage.objects;
create policy "payment_receipts_update_own" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'payment-receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "payment_receipts_delete_own" on storage.objects;
create policy "payment_receipts_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'payment-receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- -----------------------------------------------------------------------------
-- 4) Extend public.orders with Delivery Mode + Payment Receipt Verification
-- -----------------------------------------------------------------------------
alter table public.orders
  add column if not exists delivery_mode text not null default 'shop_delivery'
    check (delivery_mode in ('shop_delivery', 'customer_pickup')),
  add column if not exists delivery_fee numeric(10, 2) not null default 0
    check (delivery_fee >= 0),
  add column if not exists subtotal numeric(12, 2) not null default 0
    check (subtotal >= 0),
  add column if not exists payment_method_id uuid references public.payment_methods(id) on delete set null,
  add column if not exists payment_method_name text,
  add column if not exists payment_account_number text,
  add column if not exists payment_receipt_url text,
  add column if not exists payment_status text not null default 'not_required'
    check (payment_status in ('not_required', 'pending_verification', 'verified', 'issue_reported')),
  add column if not exists payment_issue_note text,
  add column if not exists payment_verified_at timestamptz,
  add column if not exists payment_verified_by uuid references public.profiles(id) on delete set null;

-- Backfill subtotal on existing legacy orders so subtotal matches total
update public.orders
set subtotal = coalesce(total, 0)
where subtotal = 0 and coalesce(total, 0) > 0;

create index if not exists orders_payment_status_idx on public.orders (payment_status);

-- -----------------------------------------------------------------------------
-- 5) Updated customer_place_order RPC
--    - Authoritative server-side delivery fee calculation from public.shops
--    - Mandatory active payment method + transfer receipt image URL
-- -----------------------------------------------------------------------------
drop function if exists public.customer_place_order(uuid, jsonb, text, text);
drop function if exists public.customer_place_order(uuid, jsonb, text, text, text);
create or replace function public.customer_place_order(
  p_shop_id uuid,
  p_items jsonb,
  p_delivery_address text,
  p_phone text,
  p_notes text default null,
  p_delivery_mode text default 'shop_delivery',
  p_payment_method_id uuid default null,
  p_payment_receipt_url text default null
)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid;
  v_order public.orders;
  v_subtotal numeric(12, 2) := 0;
  v_delivery_fee numeric(10, 2) := 0;
  v_shop_delivery_fee numeric(10, 2) := 0;
  v_delivery_mode text;
  v_pm public.payment_methods;
  v_receipt_url text;
  v_item jsonb;
  v_price numeric(12, 2);
  v_qty int;
  v_product_id uuid;
  v_variant_id uuid;
  v_product_name text;
  v_variant_info text;
  v_image_path text;
  v_stock int;
begin
  v_customer_id := auth.uid();
  if v_customer_id is null then
    raise exception 'يجب تسجيل الدخول لإتمام الطلب';
  end if;

  if jsonb_array_length(p_items) = 0 then
    raise exception 'السلة فارغة';
  end if;

  v_delivery_mode := lower(trim(coalesce(p_delivery_mode, 'shop_delivery')));
  if v_delivery_mode not in ('shop_delivery', 'customer_pickup') then
    raise exception 'طريقة التوصيل غير صالحة';
  end if;

  -- Verify shop exists, is approved, and fetch its authoritative delivery_fee
  select coalesce(delivery_fee, 0) into v_shop_delivery_fee
  from public.shops
  where id = p_shop_id and status = 'approved';

  if not found then
    raise exception 'المحل غير متوفر أو غير معتمد';
  end if;

  if v_delivery_mode = 'shop_delivery' then
    v_delivery_fee := coalesce(v_shop_delivery_fee, 0);
  else
    v_delivery_fee := 0;
  end if;

  -- Enforce active payment method + uploaded transfer receipt
  if p_payment_method_id is null then
    raise exception 'يرجى اختيار وسيلة الدفع (بنك أو محفظة)';
  end if;

  select * into v_pm
  from public.payment_methods
  where id = p_payment_method_id and is_active = true;

  if v_pm.id is null then
    raise exception 'وسيلة الدفع المختارة غير مفعّلة حالياً، يرجى اختيار وسيلة أخرى';
  end if;

  v_receipt_url := nullif(trim(coalesce(p_payment_receipt_url, '')), '');
  if v_receipt_url is null then
    raise exception 'يرجى رفع صورة إشعار الحوالة لإتمام الطلب';
  end if;

  -- Pre-compute authoritative subtotal before INSERT so triggers (notifications & commission)
  -- immediately receive the true order subtotal & final total.
  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_qty := coalesce((v_item->>'quantity')::int, 1);
    v_price := (v_item->>'unit_price')::numeric;
    v_subtotal := v_subtotal + (coalesce(v_price, 0) * v_qty);
  end loop;

  -- Create order record with final subtotal, delivery_fee, and total
  insert into public.orders (
    customer_id,
    shop_id,
    status,
    subtotal,
    delivery_fee,
    total,
    delivery_mode,
    delivery_address,
    phone,
    notes,
    payment_method_id,
    payment_method_name,
    payment_account_number,
    payment_receipt_url,
    payment_status
  )
  values (
    v_customer_id,
    p_shop_id,
    'pending',
    v_subtotal,
    v_delivery_fee,
    v_subtotal + v_delivery_fee,
    v_delivery_mode,
    nullif(trim(coalesce(p_delivery_address, '')), ''),
    nullif(trim(coalesce(p_phone, '')), ''),
    nullif(trim(coalesce(p_notes, '')), ''),
    v_pm.id,
    v_pm.name,
    v_pm.account_number,
    v_receipt_url,
    'pending_verification'
  )
  returning * into v_order;

  -- Loop through items, decrement stock, insert order_items, and clean cart
  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_product_id := (v_item->>'product_id')::uuid;
    v_variant_id := nullif(v_item->>'variant_id', '')::uuid;
    v_qty := coalesce((v_item->>'quantity')::int, 1);
    v_price := (v_item->>'unit_price')::numeric;
    v_product_name := coalesce(v_item->>'product_name', 'منتج');
    v_variant_info := v_item->>'variant_info';
    v_image_path := nullif(v_item->>'image_path', '');

    if v_variant_id is not null then
      select stock into v_stock
      from public.product_variants
      where id = v_variant_id for update;

      if v_stock is null or v_stock < v_qty then
        raise exception 'الكمية المطلوبة غير متوفرة في المخزون للمنتج %', v_product_name;
      end if;

      update public.product_variants
      set stock = stock - v_qty
      where id = v_variant_id;
    end if;

    insert into public.order_items (
      order_id,
      product_id,
      variant_id,
      product_name,
      variant_info,
      unit_price,
      quantity,
      total_price,
      image_path
    )
    values (
      v_order.id,
      v_product_id,
      v_variant_id,
      v_product_name,
      v_variant_info,
      v_price,
      v_qty,
      (v_price * v_qty),
      v_image_path
    );

    delete from public.cart_items
    where customer_id = v_customer_id
      and product_id = v_product_id;
  end loop;

  -- Update customer profile phone/address if empty
  update public.profiles
  set phone = coalesce(nullif(phone, ''), nullif(trim(p_phone), '')),
      address = case
        when v_delivery_mode = 'shop_delivery'
          then coalesce(nullif(address, ''), nullif(trim(p_delivery_address), ''))
        else address
      end
  where id = v_customer_id;

  return v_order;
end;
$$;

grant execute on function public.customer_place_order(uuid, jsonb, text, text, text, text, uuid, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 6) Shop Payment Verification RPC + Shipping Stage Guard
-- -----------------------------------------------------------------------------
create or replace function public.shop_verify_order_payment(
  p_order_id uuid,
  p_approved boolean,
  p_issue_note text default null
)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  sid uuid;
  v_order public.orders;
  v_note text;
begin
  sid := public.require_approved_shop();

  select * into v_order
  from public.orders
  where id = p_order_id and shop_id = sid;

  if v_order.id is null then
    raise exception 'الطلب غير موجود';
  end if;

  if v_order.status = 'cancelled' then
    raise exception 'لا يمكن مراجعة الحوالة لطلب ملغي';
  end if;

  if coalesce(p_approved, false) then
    update public.orders
    set
      payment_status = 'verified',
      payment_issue_note = null,
      payment_verified_at = now(),
      payment_verified_by = auth.uid(),
      status = case when status = 'pending' then 'confirmed' else status end,
      updated_at = now()
    where id = p_order_id and shop_id = sid
    returning * into v_order;
  else
    v_note := nullif(trim(coalesce(p_issue_note, '')), '');
    if v_note is null then
      raise exception 'يرجى كتابة سبب المشكلة في الحوالة لإعلام العميل';
    end if;

    update public.orders
    set
      payment_status = 'issue_reported',
      payment_issue_note = v_note,
      payment_verified_at = null,
      payment_verified_by = null,
      updated_at = now()
    where id = p_order_id and shop_id = sid
    returning * into v_order;
  end if;

  return v_order;
end;
$$;

grant execute on function public.shop_verify_order_payment(uuid, boolean, text) to authenticated;

-- Guard shop_update_order_status so shipping stages require verified payment
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
  v_current public.orders;
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

  if p_status <> 'cancelled'
     and v_current.payment_status in ('pending_verification', 'issue_reported') then
    raise exception 'يرجى تأكيد إشعار الحوالة المالية أولاً قبل متابعة مراحل التجهيز والشحن';
  end if;

  update public.orders
  set status = p_status, updated_at = now()
  where id = p_order_id
    and shop_id = sid
  returning * into result;

  return result;
end;
$$;

grant execute on function public.shop_update_order_status(uuid, public.order_status) to authenticated;

-- -----------------------------------------------------------------------------
-- 7) Customer Receipt Resubmission RPC (when shop reports a receipt/amount issue)
-- -----------------------------------------------------------------------------
create or replace function public.customer_resubmit_payment_receipt(
  p_order_id uuid,
  p_receipt_url text,
  p_payment_method_id uuid default null
)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_order public.orders;
  v_pm public.payment_methods;
  v_url text;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  v_url := nullif(trim(coalesce(p_receipt_url, '')), '');
  if v_url is null then
    raise exception 'يرجى رفع صورة إشعار الحوالة';
  end if;

  select * into v_order
  from public.orders
  where id = p_order_id and customer_id = v_uid;

  if v_order.id is null then
    raise exception 'الطلب غير موجود';
  end if;

  if v_order.status in ('cancelled', 'delivered') then
    raise exception 'لا يمكن تحديث إشعار الحوالة لهذا الطلب';
  end if;

  if p_payment_method_id is not null then
    select * into v_pm
    from public.payment_methods
    where id = p_payment_method_id and is_active = true;

    if v_pm.id is null then
      raise exception 'وسيلة الدفع المختارة غير مفعّلة حالياً';
    end if;
  end if;

  update public.orders
  set
    payment_receipt_url = v_url,
    payment_method_id = coalesce(v_pm.id, payment_method_id),
    payment_method_name = coalesce(v_pm.name, payment_method_name),
    payment_account_number = coalesce(v_pm.account_number, payment_account_number),
    payment_status = 'pending_verification',
    payment_issue_note = null,
    payment_verified_at = null,
    payment_verified_by = null,
    updated_at = now()
  where id = p_order_id and customer_id = v_uid
  returning * into v_order;

  return v_order;
end;
$$;

grant execute on function public.customer_resubmit_payment_receipt(uuid, text, uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 8) Push + In-App Notifications for Payment Verification & Issues
-- -----------------------------------------------------------------------------
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
  v_delivery_label text;
begin
  select owner_id, name into v_shop_owner_id, v_shop_name
  from public.shops
  where id = new.shop_id;

  select coalesce(nullif(trim(full_name), ''), email, 'عميل')
    into v_customer_name
  from public.profiles
  where id = new.customer_id;

  v_total_text := to_char(coalesce(new.total, 0), 'FM999999990.##');
  v_delivery_label := case
    when new.delivery_mode = 'customer_pickup' then 'توصيل من الزبون'
    else 'توصيل من المحل'
  end;

  -- Notify shop owner about the new order & attached receipt
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
      'طلب جديد مع إشعار حوالة 🧾',
      'وصلك طلب جديد من ' || coalesce(v_customer_name, 'عميل')
        || ' (' || v_delivery_label || ') بقيمة ' || v_total_text
        || ' ₪ — يرجى مراجعة إشعار الحوالة وتأكيده للبدء بالشحن.',
      'shop',
      new.customer_id,
      v_shop_owner_id,
      new.shop_id,
      'system',
      'user',
      jsonb_build_object(
        'event_type', 'order_created',
        'order_id', new.id,
        'shop_id', new.shop_id,
        'route', '/shop/orders'
      )
    );
  end if;

  -- Notify customer confirming order + receipt submission
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
    'تم استلام طلبك وإشعار الحوالة ✅',
    'تم إرسال طلبك إلى ' || coalesce(v_shop_name, 'المتجر')
      || ' بقيمة ' || v_total_text || ' ₪. سيراجع المتجر إشعار الحوالة ويبدأ التجهيز فوراً.',
    'customer',
    new.customer_id,
    new.customer_id,
    new.shop_id,
    'system',
    'user',
    jsonb_build_object(
      'event_type', 'order_created_customer',
      'order_id', new.id,
      'shop_id', new.shop_id,
      'route', '/customer/orders/' || new.id::text
    )
  );

  return new;
end;
$$;

create or replace function public.trg_notify_on_order_payment_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop_owner_id uuid;
  v_shop_name text;
  v_customer_name text;
  v_short_id text;
begin
  if new.payment_status is not distinct from old.payment_status
     and new.payment_receipt_url is not distinct from old.payment_receipt_url then
    return new;
  end if;

  select owner_id, name into v_shop_owner_id, v_shop_name
  from public.shops
  where id = new.shop_id;

  select coalesce(nullif(trim(full_name), ''), email, 'عميل')
    into v_customer_name
  from public.profiles
  where id = new.customer_id;

  v_short_id := upper(left(new.id::text, 8));

  -- 1) Shop confirmed the transfer receipt
  if new.payment_status = 'verified' and old.payment_status is distinct from 'verified' then
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
      'تم تأكيد إشعار الحوالة ✅',
      'أكد متجر ' || coalesce(v_shop_name, 'المتجر')
        || ' استلام حوالة طلبك #' || v_short_id || ' وجاري استكمال مراحل التجهيز والشحن.',
      'customer',
      v_shop_owner_id,
      new.customer_id,
      new.shop_id,
      'shop',
      'user',
      jsonb_build_object(
        'event_type', 'payment_verified',
        'order_id', new.id,
        'shop_id', new.shop_id,
        'route', '/customer/orders/' || new.id::text
      )
    );
  end if;

  -- 2) Shop reported an issue with the receipt or amount
  if new.payment_status = 'issue_reported'
     and (old.payment_status is distinct from 'issue_reported'
          or new.payment_issue_note is distinct from old.payment_issue_note) then
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
      'توجد مشكلة في إشعار الحوالة ⚠️',
      'رسالة من ' || coalesce(v_shop_name, 'المتجر') || ' بخصوص طلبك #' || v_short_id || ': '
        || coalesce(nullif(trim(new.payment_issue_note), ''), 'يرجى مراجعة المبلغ أو رفع إشعار حوالة واضح.'),
      'customer',
      v_shop_owner_id,
      new.customer_id,
      new.shop_id,
      'shop',
      'user',
      jsonb_build_object(
        'event_type', 'payment_issue',
        'order_id', new.id,
        'shop_id', new.shop_id,
        'route', '/customer/orders/' || new.id::text
      )
    );
  end if;

  -- 3) Customer uploaded a new receipt after an issue was reported
  if new.payment_status = 'pending_verification'
     and old.payment_status = 'issue_reported'
     and v_shop_owner_id is not null then
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
      'تم رفع إشعار حوالة محدّث 🧾',
      'قام ' || coalesce(v_customer_name, 'العميل')
        || ' برفع إشعار حوالة جديد للطلب #' || v_short_id || '. يرجى مراجعته وتأكيده.',
      'shop',
      new.customer_id,
      v_shop_owner_id,
      new.shop_id,
      'system',
      'user',
      jsonb_build_object(
        'event_type', 'payment_resubmitted',
        'order_id', new.id,
        'shop_id', new.shop_id,
        'route', '/shop/orders'
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_orders_payment_update_notify on public.orders;
create trigger trg_orders_payment_update_notify
  after update of payment_status, payment_receipt_url, payment_issue_note on public.orders
  for each row execute function public.trg_notify_on_order_payment_update();

notify pgrst, 'reload schema';
commit;
