-- =============================================================================
--  035_multi_shop_checkout_groups.sql
--  Option 1: Multi-Shop Shipments Checkout with Grouped Single Transfer Receipt
--  - Links sibling shop orders from one customer checkout via checkout_group_id
--  - Stores combined receipt amount (group_total) & shop count (group_shops_count)
--    so every shop clearly sees its exact 100% share of a grouped receipt
--  - Admin can verify or flag a grouped transfer receipt once for all sibling orders
--  - Customer receipt resubmission automatically updates all sibling group orders
-- =============================================================================
begin;

-- -----------------------------------------------------------------------------
-- 1) Extend public.orders with multi-shop checkout group metadata
-- -----------------------------------------------------------------------------
alter table public.orders
  add column if not exists checkout_group_id uuid,
  add column if not exists group_total numeric(12, 2),
  add column if not exists group_shops_count integer not null default 1
    check (group_shops_count >= 1);

create index if not exists orders_checkout_group_idx
  on public.orders (checkout_group_id)
  where checkout_group_id is not null;

-- -----------------------------------------------------------------------------
-- 2) Update customer_place_order with optional group metadata
-- -----------------------------------------------------------------------------
drop function if exists public.customer_place_order(uuid, jsonb, text, text, text, text, uuid, text);
drop function if exists public.customer_place_order(uuid, jsonb, text, text, text, text, uuid, text, uuid, numeric, integer);

create or replace function public.customer_place_order(
  p_shop_id uuid,
  p_items jsonb,
  p_delivery_address text default null,
  p_phone text default null,
  p_notes text default null,
  p_delivery_mode text default 'shop_delivery',
  p_payment_method_id uuid default null,
  p_payment_receipt_url text default null,
  p_checkout_group_id uuid default null,
  p_group_total numeric default null,
  p_group_shops_count integer default 1
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
  v_shops_count int := greatest(1, coalesce(p_group_shops_count, 1));
  v_final_group_total numeric(12, 2);
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

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_qty := coalesce((v_item->>'quantity')::int, 1);
    v_price := (v_item->>'unit_price')::numeric;
    v_subtotal := v_subtotal + (coalesce(v_price, 0) * v_qty);
  end loop;

  v_final_group_total := case
    when p_group_total is not null and p_group_total > 0 then round(p_group_total, 2)
    else (v_subtotal + v_delivery_fee)
  end;

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
    payment_status,
    checkout_group_id,
    group_total,
    group_shops_count
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
    'pending_verification',
    p_checkout_group_id,
    v_final_group_total,
    v_shops_count
  )
  returning * into v_order;

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

grant execute on function public.customer_place_order(
  uuid, jsonb, text, text, text, text, uuid, text, uuid, numeric, integer
) to authenticated;

-- -----------------------------------------------------------------------------
-- 3) Admin Grouped Payment Verification RPC
--    Verifies or flags a single order OR all sibling orders in the same group
-- -----------------------------------------------------------------------------
create or replace function public.admin_verify_order_payment(
  p_order_id uuid,
  p_approved boolean,
  p_issue_note text default null,
  p_apply_to_group boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders;
  v_note text;
  v_updated_count int := 0;
begin
  perform public.require_admin();

  select * into v_order
  from public.orders
  where id = p_order_id;

  if v_order.id is null then
    raise exception 'الطلب غير موجود';
  end if;

  if v_order.status = 'cancelled' then
    raise exception 'لا يمكن مراجعة الحوالة لطلب ملغي';
  end if;

  if coalesce(p_approved, false) then
    if coalesce(p_apply_to_group, true) and v_order.checkout_group_id is not null then
      update public.orders
      set
        payment_status = 'verified',
        payment_issue_note = null,
        payment_verified_at = now(),
        payment_verified_by = auth.uid(),
        status = case when status = 'pending' then 'confirmed' else status end,
        updated_at = now()
      where checkout_group_id = v_order.checkout_group_id
        and status <> 'cancelled';
      get diagnostics v_updated_count = row_count;
    else
      update public.orders
      set
        payment_status = 'verified',
        payment_issue_note = null,
        payment_verified_at = now(),
        payment_verified_by = auth.uid(),
        status = case when status = 'pending' then 'confirmed' else status end,
        updated_at = now()
      where id = p_order_id;
      get diagnostics v_updated_count = row_count;
    end if;
  else
    v_note := nullif(trim(coalesce(p_issue_note, '')), '');
    if v_note is null then
      raise exception 'يرجى كتابة سبب المشكلة في الحوالة لإعلام العميل';
    end if;

    if coalesce(p_apply_to_group, true) and v_order.checkout_group_id is not null then
      update public.orders
      set
        payment_status = 'issue_reported',
        payment_issue_note = v_note,
        payment_verified_at = null,
        payment_verified_by = null,
        updated_at = now()
      where checkout_group_id = v_order.checkout_group_id
        and status not in ('cancelled', 'delivered');
      get diagnostics v_updated_count = row_count;
    else
      update public.orders
      set
        payment_status = 'issue_reported',
        payment_issue_note = v_note,
        payment_verified_at = null,
        payment_verified_by = null,
        updated_at = now()
      where id = p_order_id;
      get diagnostics v_updated_count = row_count;
    end if;
  end if;

  return jsonb_build_object(
    'order_id', p_order_id,
    'checkout_group_id', v_order.checkout_group_id,
    'updated_count', v_updated_count,
    'approved', coalesce(p_approved, false)
  );
end;
$$;

grant execute on function public.admin_verify_order_payment(uuid, boolean, text, boolean) to authenticated;

-- -----------------------------------------------------------------------------
-- 4) Update customer_resubmit_payment_receipt to sync sibling group orders
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

  if v_order.checkout_group_id is not null then
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
    where checkout_group_id = v_order.checkout_group_id
      and customer_id = v_uid
      and status not in ('cancelled', 'delivered');

    select * into v_order from public.orders where id = p_order_id;
  else
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
  end if;

  return v_order;
end;
$$;

grant execute on function public.customer_resubmit_payment_receipt(uuid, text, uuid) to authenticated;

notify pgrst, 'reload schema';

commit;
