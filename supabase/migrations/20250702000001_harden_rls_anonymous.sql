-- Harden table access for anonymous sign-in (anonymous users use the authenticated role).
-- Game clients must not write daily_state or profiles directly; the daily Edge Function
-- uses the service role. Authenticated users may only SELECT their own rows (RLS).

revoke all on table public.profiles from anon, authenticated;
revoke all on table public.daily_state from anon, authenticated;

grant select on table public.profiles to authenticated;
grant select on table public.daily_state to authenticated;

-- No insert/update/delete policies on these tables for authenticated.
-- RLS is enabled; without matching policies, writes are denied.

comment on policy "profiles_select_own" on public.profiles is
  'Each user (including anonymous) can read only their own profile row.';

comment on policy "daily_state_select_own" on public.daily_state is
  'Each user can read only their own daily_state rows. All writes go through the daily edge function (service role).';
