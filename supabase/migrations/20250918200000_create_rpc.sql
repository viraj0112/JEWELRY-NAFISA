create or replace function get_total_users() 
returns int as $$ 
    select count(*) from public.users;
$$ language sql;

create or replace function get_daily_active_users()
returns int as $$
  select count(distinct u.id)
  from public.users as u
  join auth.users as au on u.id = au.id
  where au.last_sign_in_at > now() - interval '24 hours';
$$ language sql security definer;

create or replace function get_total_posts()
returns int as $$
  select (select count(*) from public.pins) + (select count(*) from public.assets);
$$ language sql;

create or replace function get_total_referrals()
returns int as $$
  select count(*) from public.referrals;
$$ language sql;