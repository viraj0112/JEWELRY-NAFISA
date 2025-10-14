create or replace function get_user_counts_by_role()
returns table(role text, count int) as $$
begin
  return query
  select
    u.role::text,
    count(u.id)::int
  from
    public.users u
  group by
    u.role;
end;
$$ language plpgsql security definer;

create or replace function get_post_counts_by_type()
returns table(type text, count int) as $$
begin
  return query
  select 'Scraped' as type, count(*)::int from public.pins
  union all
  select 'B2B Uploaded' as type, count(*)::int from public.assets;
end;
$$ language plpgsql security definer;

create or replace function get_daily_credits_used()
returns int as $$

  select floor(random() * 1000 + 500)::int;
$$ language sql;

create or replace function get_top_performing_content()
returns table(title text, thumbnail_url text, stats text) as $$
begin
  return query
  select
    p.title,
    p.image_url as thumbnail_url,
    p.like_count || ' likes' as stats
  from
    public.pins p
  order by
    p.like_count desc
  limit 3;
end;
$$ language plpgsql security definer;

create or replace function get_engagement_data()
returns table(day text, views int, saves int, shares int) as $$
begin
  return query
  select
    to_char(a.date, 'Mon DD') as day,
    a.views,
    a.saves,
    a.shares
  from
    public.analytics_daily a
  order by
    a.date desc
  limit 7;
end;
$$ language plpgsql security definer;