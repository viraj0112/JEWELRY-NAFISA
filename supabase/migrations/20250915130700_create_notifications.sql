create table if not exists public.notifications(
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    message text not null,
    is_read boolean default false,
    created_at timestamp with time zone default now()
);

alter table public.notifications enable row level security;

create policy "Users can view their own notifications"
on public.notifications for select
using (auth.uid() = user_id);

create policy "Users can update their own notifications" on public.notifications for update
using (auth.uid() = user_id);