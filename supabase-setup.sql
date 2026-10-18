-- Aviator Arcade V5.2. Run in Supabase SQL Editor as project owner.
-- Never paste service_role keys into the website.
create extension if not exists pgcrypto;
create table if not exists public.pilot_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default 'Pilot', role text not null default 'Pilot',
 xp integer not null default 0 check (xp >= 0), featured text not null default 'c172',
 progress jsonb not null default '{}'::jsonb, updated_at timestamptz not null default now()
);
create table if not exists public.friendships (
 id uuid primary key default gen_random_uuid(),
 requester_id uuid not null references auth.users(id) on delete cascade,
 recipient_id uuid not null references auth.users(id) on delete cascade,
 status text not null default 'pending' check (status in ('pending','accepted')),
 created_at timestamptz not null default now(),
 constraint no_self_friend check (requester_id <> recipient_id),
 constraint unique_direction unique (requester_id,recipient_id)
);
create index if not exists friendships_requester on public.friendships(requester_id);
create index if not exists friendships_recipient on public.friendships(recipient_id);
alter table public.pilot_profiles enable row level security;
alter table public.friendships enable row level security;
-- Profiles visible only to owner or an accepted friend. A separate directory view exposes names/roles only.
create policy "owner reads own profile" on public.pilot_profiles for select to authenticated using (user_id = (select auth.uid()));
create policy "owner inserts profile" on public.pilot_profiles for insert to authenticated with check (user_id = (select auth.uid()));
create policy "owner updates profile" on public.pilot_profiles for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "friends read accepted profiles" on public.pilot_profiles for select to authenticated using (
 exists (select 1 from public.friendships f where f.status='accepted' and ((f.requester_id=(select auth.uid()) and f.recipient_id=pilot_profiles.user_id) or (f.recipient_id=(select auth.uid()) and f.requester_id=pilot_profiles.user_id)))
);
create policy "participants see friendship" on public.friendships for select to authenticated using (requester_id=(select auth.uid()) or recipient_id=(select auth.uid()));
create policy "sender requests friendship" on public.friendships for insert to authenticated with check (requester_id=(select auth.uid()) and status='pending');
create policy "recipient accepts friendship" on public.friendships for update to authenticated using (recipient_id=(select auth.uid()) and status='pending') with check (recipient_id=(select auth.uid()) and status='accepted');
create policy "participants delete friendship" on public.friendships for delete to authenticated using (requester_id=(select auth.uid()) or recipient_id=(select auth.uid()));
-- A limited directory that does not reveal email, progress, or milestones.
create or replace view public.pilot_directory with (security_invoker=false) as
 select user_id,display_name,role from public.pilot_profiles;
revoke all on public.pilot_directory from public, anon;
grant select on public.pilot_directory to authenticated;
grant select,insert,update on public.pilot_profiles to authenticated;
grant select,insert,update,delete on public.friendships to authenticated;
