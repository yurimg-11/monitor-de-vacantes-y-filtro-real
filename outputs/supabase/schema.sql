-- Ejecuta este archivo completo en Supabase Dashboard > SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  company text not null,
  logo text not null default '',
  color text not null default 'green',
  place text not null default 'México',
  mode text not null default 'Remoto' check (mode in ('Remoto','Híbrido','Presencial')),
  salary text not null default 'No publicado',
  skills text[] not null default '{}',
  source text not null default 'Importación',
  verified boolean not null default false,
  posted text not null default 'hoy',
  recent integer not null default 0,
  salary_n integer not null default 0,
  description text not null default '',
  url text not null default '',
  dedupe_key text not null unique,
  created_at timestamptz not null default now()
);
create index if not exists jobs_created_at_idx on public.jobs(created_at desc);
alter table public.jobs enable row level security;
drop policy if exists "Anyone can read jobs" on public.jobs;
create policy "Anyone can read jobs" on public.jobs for select using (true);
-- No se conceden políticas de escritura a usuarios normales. La API usa la clave service role solo en el servidor.

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  skills text[] not null default '{}',
  resume_path text,
  resume_name text,
  updated_at timestamptz not null default now()
);
alter table public.profiles add column if not exists resume_path text;
alter table public.profiles add column if not exists resume_name text;
alter table public.profiles enable row level security;
drop policy if exists "Users can read their own profile" on public.profiles;
create policy "Users can read their own profile" on public.profiles for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "Users can create their own profile" on public.profiles;
create policy "Users can create their own profile" on public.profiles for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile" on public.profiles for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create table if not exists public.saved_jobs (
  user_id uuid not null references auth.users(id) on delete cascade,
  job_id uuid not null references public.jobs(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, job_id)
);
alter table public.saved_jobs enable row level security;
drop policy if exists "Users can read their saved jobs" on public.saved_jobs;
create policy "Users can read their saved jobs" on public.saved_jobs for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "Users can save jobs for themselves" on public.saved_jobs;
create policy "Users can save jobs for themselves" on public.saved_jobs for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "Users can remove their saved jobs" on public.saved_jobs;
create policy "Users can remove their saved jobs" on public.saved_jobs for delete to authenticated using ((select auth.uid()) = user_id);

-- CVs live in a private bucket. Each account can access only its own folder.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('resumes','resumes',false,10485760,array['application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
on conflict (id) do update set public=false,file_size_limit=10485760,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists "Users can read their own CV" on storage.objects;
create policy "Users can read their own CV" on storage.objects for select to authenticated using (bucket_id='resumes' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "Users can upload their own CV" on storage.objects;
create policy "Users can upload their own CV" on storage.objects for insert to authenticated with check (bucket_id='resumes' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "Users can update their own CV" on storage.objects;
create policy "Users can update their own CV" on storage.objects for update to authenticated using (bucket_id='resumes' and (storage.foldername(name))[1]=(select auth.uid())::text) with check (bucket_id='resumes' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "Users can delete their own CV" on storage.objects;
create policy "Users can delete their own CV" on storage.objects for delete to authenticated using (bucket_id='resumes' and (storage.foldername(name))[1]=(select auth.uid())::text);

grant usage on schema public to anon, authenticated;
grant select on public.jobs to anon, authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select, insert, delete on public.saved_jobs to authenticated;
