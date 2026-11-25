-- =============================================================================
--  042_vidu_live_streaming_sessions.sql
--  Extends vidu_tryon_tasks to support Vidu S2-Editing real-time live sessions
--  (`POST /live/s_editing/realtime` + WebSocket control proxy) by securely
--  storing server-only `client_secret` and `session_duration_seconds`.
-- =============================================================================
begin;

alter table public.vidu_tryon_tasks
  add column if not exists client_secret text,
  add column if not exists session_duration_seconds integer not null default 30;

create or replace function public.service_record_vidu_task(
  p_task_id text,
  p_user_id uuid,
  p_key_id uuid default null,
  p_state text default 'created',
  p_client_secret text default null,
  p_session_duration_seconds integer default 30
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_task_id is null or btrim(p_task_id) = '' or p_user_id is null then
    return;
  end if;

  insert into public.vidu_tryon_tasks (
    task_id,
    user_id,
    key_id,
    state,
    client_secret,
    session_duration_seconds,
    updated_at
  )
  values (
    btrim(p_task_id),
    p_user_id,
    p_key_id,
    coalesce(p_state, 'created'),
    nullif(btrim(coalesce(p_client_secret, '')), ''),
    greatest(least(coalesce(p_session_duration_seconds, 30), 300), 10),
    now()
  )
  on conflict (task_id) do update
    set state = excluded.state,
        client_secret = coalesce(excluded.client_secret, public.vidu_tryon_tasks.client_secret),
        session_duration_seconds = excluded.session_duration_seconds,
        updated_at = now();
end;
$$;

create or replace function public.service_get_vidu_task(
  p_task_id text,
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  row_data public.vidu_tryon_tasks%rowtype;
begin
  select * into row_data
  from public.vidu_tryon_tasks
  where task_id = btrim(coalesce(p_task_id, ''))
    and user_id = p_user_id;

  if not found then
    return null;
  end if;

  return jsonb_build_object(
    'task_id', row_data.task_id,
    'user_id', row_data.user_id,
    'key_id', row_data.key_id,
    'state', row_data.state,
    'refunded', row_data.refunded,
    'client_secret', row_data.client_secret,
    'session_duration_seconds', row_data.session_duration_seconds
  );
end;
$$;

revoke all on function public.service_record_vidu_task(text, uuid, uuid, text, text, integer)
  from public, anon, authenticated;
grant execute on function public.service_record_vidu_task(text, uuid, uuid, text, text, integer)
  to service_role;

revoke all on function public.service_get_vidu_task(text, uuid)
  from public, anon, authenticated;
grant execute on function public.service_get_vidu_task(text, uuid)
  to service_role;

notify pgrst, 'reload schema';
commit;
