-- Link shop operations with admin: targeted notifications, no decision leak before delay

alter table public.notifications
  add column if not exists target_user_id uuid references public.profiles (id) on delete cascade;

create index if not exists notifications_target_user_idx
  on public.notifications (target_user_id);

drop policy if exists "notifications_read" on public.notifications;
create policy "notifications_read"
  on public.notifications for select
  using (
    public.current_user_role() = 'admin'
    or target_user_id = auth.uid()
    or (
      target_user_id is null
      and (
        audience = 'all'
        or (audience = 'customer' and public.current_user_role() = 'customer')
        or (audience = 'shop' and public.current_user_role() = 'shop')
      )
    )
  );

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
  insert into public.notifications (title, body, audience, created_by, target_user_id)
  values (p_title, p_body, p_audience, auth.uid(), p_user_id);
end;
$$;

-- Keep review delay, notify without revealing the decision text
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
  result public.shops;
  delay_hours int;
begin
  perform public.require_admin();

  if not p_approve and coalesce(trim(p_rejection_reason), '') = '' then
    raise exception 'سبب الرفض مطلوب';
  end if;

  begin
    select greatest(0, value::int) into delay_hours
    from public.platform_settings
    where key = 'decision_delay_hours';
  exception when others then
    delay_hours := 24;
  end;
  delay_hours := coalesce(delay_hours, 24);

  update public.shops
  set
    status = case
      when p_approve then 'approved'::public.shop_status
      else 'rejected'::public.shop_status
    end,
    rejection_reason = case
      when p_approve then null
      else trim(p_rejection_reason)
    end,
    decision_at = now(),
    decision_visible_at = now() + make_interval(hours => delay_hours),
    updated_at = now()
  where id = p_shop_id
    and status = 'pending'
  returning * into result;

  if result.id is null then
    raise exception 'الطلب غير موجود أو تمت مراجعته مسبقاً';
  end if;

  perform public.notify_user(
    result.owner_id,
    'تحديث على طلب الانضمام',
    'تم اتخاذ قرار بشأن طلب انضمام محلك. سيظهر القرار في صفحة الحالة حسب سياسة المنصة.',
    'shop'
  );

  return result;
end;
$$;

create or replace function public.admin_set_shop_suspended(
  p_shop_id uuid,
  p_suspend boolean
)
returns public.shops
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.shops;
begin
  perform public.require_admin();

  update public.shops
  set
    status = case
      when p_suspend then 'suspended'::public.shop_status
      else 'approved'::public.shop_status
    end,
    updated_at = now()
  where id = p_shop_id
    and status in ('approved', 'suspended')
  returning * into result;

  if result.id is null then
    raise exception 'يمكن تعليق أو تفعيل المحلات المعتمدة فقط';
  end if;

  perform public.notify_user(
    result.owner_id,
    case when p_suspend then 'تم تعليق المحل' else 'تم إعادة تفعيل المحل' end,
    case
      when p_suspend then 'تم تعليق محلك من الإدارة. لا يمكن إدارة المنتجات حتى إعادة التفعيل.'
      else 'تم إعادة تفعيل محلك. يمكنك متابعة إدارة المنتجات والطلبات.'
    end,
    'shop'
  );

  return result;
end;
$$;

-- When admin hides/deletes a product, notify the shop owner
create or replace function public.admin_set_product_status(
  p_product_id uuid,
  p_status public.product_status
)
returns public.products
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.products;
  owner uuid;
begin
  perform public.require_admin();

  if p_status not in ('hidden', 'deleted', 'published') then
    raise exception 'حالة غير مسموحة';
  end if;

  update public.products
  set status = p_status, updated_at = now()
  where id = p_product_id
    and status is distinct from 'deleted'
  returning * into result;

  if result.id is null then
    raise exception 'المنتج غير موجود';
  end if;

  select owner_id into owner from public.shops where id = result.shop_id;
  perform public.notify_user(
    owner,
    'تحديث على منتج',
    'تم تحديث حالة المنتج "' || result.name || '" من الإدارة.',
    'shop'
  );

  return result;
end;
$$;

grant execute on function public.notify_user(uuid, text, text, public.notification_audience) to authenticated;
grant execute on function public.review_shop_application(uuid, boolean, text) to authenticated;
grant execute on function public.admin_set_shop_suspended(uuid, boolean) to authenticated;
grant execute on function public.admin_set_product_status(uuid, public.product_status) to authenticated;
