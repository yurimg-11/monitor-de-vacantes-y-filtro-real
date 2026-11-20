-- Run this complete file in Supabase Dashboard > SQL Editor. It is safe to rerun.
create extension if not exists pgcrypto;

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
drop policy if exists "Users can read own or applicant profiles" on public.profiles;
drop policy if exists "Users can read their own profile" on public.profiles;
create policy "Users can read their own profile" on public.profiles for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "Users can create their own profile" on public.profiles;
create policy "Users can create their own profile" on public.profiles for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile" on public.profiles for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references auth.users(id) on delete cascade,
  name text not null,
  website text not null default '',
  contact_email text not null default '',
  status text not null default 'pending' check(status in ('pending','verified','rejected')),
  created_at timestamptz not null default now()
);
alter table public.companies enable row level security;
drop policy if exists "Companies are visible to owner and public when verified" on public.companies;
drop policy if exists "Company owners can read their company" on public.companies;
create policy "Company owners can read their company" on public.companies for select to authenticated
using (owner_id=(select auth.uid()));
drop policy if exists "Users can register a company" on public.companies;
create policy "Users can register a company" on public.companies for insert to authenticated with check(owner_id=(select auth.uid()) and status='pending');
drop policy if exists "Owners can edit pending company details" on public.companies;
create policy "Owners can edit pending company details" on public.companies for update to authenticated using(owner_id=(select auth.uid()) and status='pending') with check(owner_id=(select auth.uid()) and status='pending');

create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  company text not null,
  logo text not null default '',
  color text not null default 'green',
  place text not null default 'Mexico',
  mode text not null default 'Remoto' check (mode in ('Remoto','Hibrido','Presencial')),
  salary text not null default 'No publicado',
  skills text[] not null default '{}',
  source text not null default 'Importacion',
  verified boolean not null default false,
  posted text not null default 'hoy',
  recent integer not null default 0,
  salary_n integer not null default 0,
  description text not null default '',
  url text not null default '',
  dedupe_key text not null unique,
  owner_id uuid references auth.users(id) on delete set null,
  company_id uuid references public.companies(id) on delete cascade,
  status text not null default 'published' check(status in ('pending','published','closed','rejected')),
  created_at timestamptz not null default now()
);
alter table public.jobs add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table public.jobs add column if not exists company_id uuid references public.companies(id) on delete cascade;
alter table public.jobs add column if not exists status text not null default 'published';
alter table public.jobs drop constraint if exists jobs_mode_check;
alter table public.jobs add constraint jobs_mode_check check (mode in ('Remoto','Hibrido',U&'H\00edbrido','Presencial'));
alter table public.jobs drop constraint if exists jobs_status_check;
alter table public.jobs add constraint jobs_status_check check(status in ('pending','published','closed','rejected'));
create index if not exists jobs_created_at_idx on public.jobs(created_at desc);
create index if not exists jobs_owner_id_idx on public.jobs(owner_id);
alter table public.jobs enable row level security;
drop policy if exists "Anyone can read jobs" on public.jobs;
drop policy if exists "Public sees published jobs and employers see own" on public.jobs;
create policy "Public sees published jobs and employers see own" on public.jobs for select to anon,authenticated
using (status='published' or owner_id=(select auth.uid()));
drop policy if exists "Verified employers can submit jobs for review" on public.jobs;
create policy "Verified employers can submit jobs for review" on public.jobs for insert to authenticated with check (
  owner_id=(select auth.uid()) and status='pending' and exists(
    select 1 from public.companies c where c.id=company_id and c.owner_id=(select auth.uid()) and c.status='verified'
  )
);
drop policy if exists "Employers can edit or close own jobs" on public.jobs;
create policy "Employers can edit or close own jobs" on public.jobs for update to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()) and status in ('pending','closed') and exists(select 1 from public.companies c where c.id=company_id and c.owner_id=(select auth.uid()) and c.status='verified'));

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

create table if not exists public.applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  candidate_id uuid not null references auth.users(id) on delete cascade,
  cover_letter text not null default '',
  status text not null default 'received' check(status in ('received','reviewing','interview','rejected','hired')),
  created_at timestamptz not null default now(),
  unique(job_id,candidate_id)
);
alter table public.applications enable row level security;
drop policy if exists "Candidates and hiring employers can read applications" on public.applications;
create policy "Candidates and hiring employers can read applications" on public.applications for select to authenticated using (
  candidate_id=(select auth.uid()) or exists(select 1 from public.jobs j where j.id=job_id and j.owner_id=(select auth.uid()))
);
drop policy if exists "Candidates can apply to published jobs" on public.applications;
create policy "Candidates can apply to published jobs" on public.applications for insert to authenticated with check (
  candidate_id=(select auth.uid()) and exists(select 1 from public.jobs j where j.id=job_id and j.status='published' and j.owner_id is distinct from (select auth.uid()))
  and exists(select 1 from public.profiles p where p.user_id=(select auth.uid()) and nullif(trim(p.display_name),'') is not null and p.resume_path is not null)
);
drop policy if exists "Hiring employers can update application status" on public.applications;
create policy "Hiring employers can update application status" on public.applications for update to authenticated using (
  exists(select 1 from public.jobs j where j.id=job_id and j.owner_id=(select auth.uid()))
) with check (exists(select 1 from public.jobs j where j.id=job_id and j.owner_id=(select auth.uid())));

drop policy if exists "Users can read their own profile" on public.profiles;
drop policy if exists "Users can read own or applicant profiles" on public.profiles;
create policy "Users can read own or applicant profiles" on public.profiles for select to authenticated using (
  (select auth.uid()) = user_id or exists (
    select 1 from public.applications a join public.jobs j on j.id=a.job_id
    where a.candidate_id=user_id and j.owner_id=(select auth.uid())
  )
);

-- CV files are private. A hiring company can read one only after its owner applies to one of that company's jobs.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('resumes','resumes',false,10485760,array['application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
on conflict (id) do update set public=false,file_size_limit=10485760,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists "Users can read their own CV" on storage.objects;
drop policy if exists "Users and hiring employers can read CVs" on storage.objects;
create policy "Users and hiring employers can read CVs" on storage.objects for select to authenticated using (
  bucket_id='resumes' and (
    (storage.foldername(name))[1]=(select auth.uid())::text or exists(
      select 1 from public.applications a join public.jobs j on j.id=a.job_id
      where a.candidate_id::text=(storage.foldername(name))[1] and j.owner_id=(select auth.uid())
    )
  )
);
drop policy if exists "Users can upload their own CV" on storage.objects;
create policy "Users can upload their own CV" on storage.objects for insert to authenticated with check(bucket_id='resumes' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "Users can update their own CV" on storage.objects;
create policy "Users can update their own CV" on storage.objects for update to authenticated using(bucket_id='resumes' and (storage.foldername(name))[1]=(select auth.uid())::text) with check(bucket_id='resumes' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "Users can delete their own CV" on storage.objects;
create policy "Users can delete their own CV" on storage.objects for delete to authenticated using(bucket_id='resumes' and (storage.foldername(name))[1]=(select auth.uid())::text);

grant usage on schema public to anon, authenticated;
grant select on public.jobs to anon, authenticated;
grant insert,update on public.jobs to authenticated;
grant select,insert,update on public.profiles to authenticated;
grant select,insert,delete on public.saved_jobs to authenticated;
grant select,insert,update on public.companies to authenticated;
grant select,insert on public.applications to authenticated;
grant update(status) on public.applications to authenticated;
