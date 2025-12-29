-- Create Shopping Items table
create table if not exists public.shopping_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  name text not null,
  is_completed boolean default false,
  created_at timestamptz default now()
);

-- Enable RLS
alter table public.shopping_items enable row level security;

-- Policies
create policy "Users can view own shopping items"
  on public.shopping_items for select
  using (auth.uid() = user_id);

create policy "Users can insert own shopping items"
  on public.shopping_items for insert
  with check (auth.uid() = user_id);

create policy "Users can update own shopping items"
  on public.shopping_items for update
  using (auth.uid() = user_id);

create policy "Users can delete own shopping items"
  on public.shopping_items for delete
  using (auth.uid() = user_id);
