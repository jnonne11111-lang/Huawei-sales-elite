-- Execute in a new Supabase project's SQL editor.
-- Enable anonymous sign-in in Supabase Authentication settings.
create extension if not exists pgcrypto;
create table if not exists public.employees (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null check(length(trim(full_name)) between 2 and 100),
 store_name text not null check(length(trim(store_name)) between 2 and 100),
 start_day integer not null,
 created_at timestamptz not null default now()
);
create table if not exists public.task_completions (
 employee_id uuid not null references public.employees(id) on delete cascade,
 day_number integer not null check(day_number between 1 and 30),
 task_number integer not null check(task_number between 0 and 2),
 completed_at timestamptz not null default now(),
 primary key(employee_id,day_number,task_number)
);
create table if not exists public.lesson_completions (
 employee_id uuid not null references public.employees(id) on delete cascade,
 lesson_number integer not null check(lesson_number between 0 and 11),
 completed_at timestamptz not null default now(),
 primary key(employee_id,lesson_number)
);
-- Administrator credentials are kept as a password hash, never in Flutter source.
create table if not exists public.admin_config (
 id integer primary key check(id=1), password_hash text not null
);
create table if not exists public.admin_sessions (
 token_hash text primary key, expires_at timestamptz not null
);
revoke all on public.admin_config,public.admin_sessions from anon,authenticated;
alter table public.employees enable row level security;
alter table public.task_completions enable row level security;
alter table public.lesson_completions enable row level security;
create policy "employee select self" on public.employees for select to authenticated using(id=auth.uid());
create policy "employee insert self" on public.employees for insert to authenticated with check(id=auth.uid());
create policy "employee update self" on public.employees for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy "task select self" on public.task_completions for select to authenticated using(employee_id=auth.uid());
create policy "task insert self" on public.task_completions for insert to authenticated with check(employee_id=auth.uid());
create policy "task update self" on public.task_completions for update to authenticated using(employee_id=auth.uid()) with check(employee_id=auth.uid());
create policy "task delete self" on public.task_completions for delete to authenticated using(employee_id=auth.uid());
create policy "lesson select self" on public.lesson_completions for select to authenticated using(employee_id=auth.uid());
create policy "lesson insert self" on public.lesson_completions for insert to authenticated with check(employee_id=auth.uid());
create policy "lesson update self" on public.lesson_completions for update to authenticated using(employee_id=auth.uid()) with check(employee_id=auth.uid());
create policy "lesson delete self" on public.lesson_completions for delete to authenticated using(employee_id=auth.uid());
-- The initial password is provisioned once server-side, not embedded in the client.
insert into public.admin_config(id,password_hash)
values(1,crypt('1w2q3r4e',gen_salt('bf',12)))
on conflict(id) do nothing;
create or replace function public.admin_login(p_password text) returns text
language plpgsql security definer set search_path=public,extensions as $$
declare v_hash text; v_token text;
begin
 select password_hash into v_hash from public.admin_config where id=1;
 if v_hash is null or crypt(p_password,v_hash)<>v_hash then return null; end if;
 v_token=encode(gen_random_bytes(32),'hex');
 insert into public.admin_sessions(token_hash,expires_at) values(encode(digest(v_token,'sha256'),'hex'),now()+interval '8 hours');
 return v_token;
end $$;
create or replace function public.admin_dashboard(p_token text)
returns table(full_name text,store_name text,task_count bigint,lesson_count bigint,points bigint)
language plpgsql security definer set search_path=public,extensions as $$
begin
 if not exists(select 1 from public.admin_sessions where token_hash=encode(digest(p_token,'sha256'),'hex') and expires_at>now()) then
  raise exception 'Unauthorized';
 end if;
 return query select e.full_name,e.store_name,
 (select count(*) from public.task_completions t where t.employee_id=e.id),
 (select count(*) from public.lesson_completions l where l.employee_id=e.id),
 30*(select count(*) from public.task_completions t where t.employee_id=e.id)+50*(select count(*) from public.lesson_completions l where l.employee_id=e.id)
 from public.employees e order by 5 desc,e.full_name;
end $$;
revoke all on function public.admin_login(text),public.admin_dashboard(text) from public;
grant execute on function public.admin_login(text),public.admin_dashboard(text) to authenticated;
-- Before production: rate-limit admin_login at an API gateway/Edge Function;
-- rotate the initial password, enforce identity and device recovery, and audit access.
