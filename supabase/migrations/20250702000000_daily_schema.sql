-- Familiar's Call: profiles + UTC daily state (per auth user, per day)

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.daily_state (
  user_id uuid not null references auth.users (id) on delete cascade,
  daily_day date not null,
  ritual_ids jsonb not null,
  ritual_completed jsonb not null default '{}'::jsonb,
  daily_battle_wins integer not null default 0,
  pack_claimed boolean not null default false,
  primary key (user_id, daily_day)
);

create index if not exists daily_state_user_day_idx on public.daily_state (user_id, daily_day desc);

alter table public.profiles enable row level security;
alter table public.daily_state enable row level security;

create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

create policy "daily_state_select_own"
  on public.daily_state for select
  using (auth.uid() = user_id);

-- Inserts/updates go through the daily Edge Function (service role).

create or replace function public.touch_profile_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.touch_profile_updated_at();
