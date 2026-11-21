-- =============================================================================
--  028_instant_shop_approval.sql
--  Remove the 24-hour decision visibility delay so approved/rejected shops
--  see the admin decision and open immediately.
-- =============================================================================
begin;

-- 1) Set platform setting decision_delay_hours to 0
insert into public.platform_settings (key, value, label)
values ('decision_delay_hours', '0', 'تأخير ظهور قرار المحل (ساعات)')
on conflict (key) do update
  set value = '0',
      updated_at = now();

-- 2) Immediately unlock any existing reviewed shops waiting on a future timestamp
update public.shops
set decision_visible_at = now(),
    updated_at = now()
where status in ('approved', 'rejected')
  and (decision_visible_at is null or decision_visible_at > now());

-- 3) Replace review_shop_application to make approval/rejection instant
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
begin
  perform public.require_admin();

  if not p_approve and coalesce(trim(p_rejection_reason), '') = '' then
    raise exception 'سبب الرفض مطلوب';
  end if;

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
    decision_visible_at = now(),
    updated_at = now()
  where id = p_shop_id
    and status = 'pending'
  returning * into result;

  if result.id is null then
    raise exception 'الطلب غير موجود أو تمت مراجعته مسبقاً';
  end if;

  if p_approve then
    perform public.notify_user(
      result.owner_id,
      'تم قبول واعتماد متجرك',
      'مبروك! تمت الموافقة على متجرك وأصبح مفعّلاً الآن ويمكنك إضافة منتجاتك واستقبال الطلبات مباشرة.',
      'shop'
    );
  else
    perform public.notify_user(
      result.owner_id,
      'تحديث على طلب انضمام المتجر',
      'لم تتم الموافقة على الطلب حالياً. يمكنك مراجعة سبب الرفض وتعديل البيانات وإعادة الإرسال.',
      'shop'
    );
  end if;

  return result;
end;
$$;

grant execute on function public.review_shop_application(uuid, boolean, text) to authenticated;

notify pgrst, 'reload schema';
commit;
