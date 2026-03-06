-- ============================================================================
-- Digital Products Store — Supabase Migration
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor → New Query)
-- ============================================================================


-- ─── Extensions ──────────────────────────────────────────────────────────────

create extension if not exists "pgcrypto";


-- ─── Profiles ────────────────────────────────────────────────────────────────

create table if not exists profiles (
  id          uuid primary key references auth.users on delete cascade,
  email       text not null,
  full_name   text,
  avatar_url  text,
  role        text not null default 'customer'
                check (role in ('admin', 'customer')),
  created_at  timestamptz not null default now()
);

-- Auto-create profile on signup
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'full_name'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function handle_new_user();


-- ─── Categories ──────────────────────────────────────────────────────────────

create table if not exists categories (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  slug        text unique not null,
  description text,
  created_at  timestamptz not null default now()
);


-- ─── Products ────────────────────────────────────────────────────────────────

create table if not exists products (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,
  slug              text unique not null,
  description       text,
  short_description text,
  price             integer not null check (price >= 0),       -- in cents
  compare_at_price  integer check (compare_at_price >= 0),     -- crossed-out price, in cents
  type              text not null
                      check (type in ('ebook', 'course', 'software', 'template')),
  status            text not null default 'draft'
                      check (status in ('draft', 'published', 'archived')),
  thumbnail_url     text,
  demo_url          text,
  file_path         text,          -- path in 'product-files' Storage bucket
  file_name         text,
  file_size         bigint,
  stripe_product_id text,
  stripe_price_id   text,
  download_limit    integer check (download_limit > 0),        -- null = unlimited
  category_id       uuid references categories on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- Auto-update updated_at
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists products_updated_at on products;
create trigger products_updated_at
  before update on products
  for each row execute function set_updated_at();


-- ─── Product Images ──────────────────────────────────────────────────────────

create table if not exists product_images (
  id          uuid primary key default gen_random_uuid(),
  product_id  uuid not null references products on delete cascade,
  url         text not null,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now()
);


-- ─── Coupons ─────────────────────────────────────────────────────────────────

create table if not exists coupons (
  id               uuid primary key default gen_random_uuid(),
  code             text unique not null,
  type             text not null check (type in ('percentage', 'fixed')),
  value            integer not null check (value > 0),   -- % (1-100) or cents
  min_order_amount integer check (min_order_amount >= 0),
  max_uses         integer check (max_uses > 0),
  used_count       integer not null default 0,
  is_active        boolean not null default true,
  expires_at       timestamptz,
  created_at       timestamptz not null default now()
);

-- Helper function to increment coupon usage atomically
create or replace function increment_coupon_usage(p_coupon_id uuid)
returns void language plpgsql security definer as $$
begin
  update coupons
  set used_count = used_count + 1
  where id = p_coupon_id;
end;
$$;


-- ─── Orders ──────────────────────────────────────────────────────────────────

create table if not exists orders (
  id                     uuid primary key default gen_random_uuid(),
  user_id                uuid not null references auth.users on delete restrict,
  status                 text not null default 'pending'
                           check (status in ('pending', 'completed', 'refunded', 'failed')),
  total_amount           integer not null,       -- in cents, after discount
  subtotal_amount        integer not null,       -- in cents, before discount
  discount_amount        integer not null default 0,
  stripe_session_id      text unique,
  stripe_payment_intent  text,
  coupon_id              uuid references coupons on delete set null,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

drop trigger if exists orders_updated_at on orders;
create trigger orders_updated_at
  before update on orders
  for each row execute function set_updated_at();


-- ─── Order Items ─────────────────────────────────────────────────────────────

create table if not exists order_items (
  id          uuid primary key default gen_random_uuid(),
  order_id    uuid not null references orders on delete cascade,
  product_id  uuid not null references products on delete restrict,
  price       integer not null,  -- price at time of purchase, in cents
  created_at  timestamptz not null default now()
);


-- ─── Downloads ───────────────────────────────────────────────────────────────
-- One row per (user, product). Grants access to the file.

create table if not exists downloads (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references auth.users on delete cascade,
  order_item_id       uuid not null references order_items on delete cascade,
  product_id          uuid not null references products on delete cascade,
  download_count      integer not null default 0,
  last_downloaded_at  timestamptz,
  created_at          timestamptz not null default now(),
  unique (user_id, product_id)
);


-- ─── Reviews ─────────────────────────────────────────────────────────────────

create table if not exists reviews (
  id            uuid primary key default gen_random_uuid(),
  product_id    uuid not null references products on delete cascade,
  user_id       uuid not null references auth.users on delete cascade,
  order_item_id uuid not null references order_items on delete cascade,
  rating        integer not null check (rating between 1 and 5),
  title         text,
  body          text,
  is_approved   boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (user_id, product_id)
);

drop trigger if exists reviews_updated_at on reviews;
create trigger reviews_updated_at
  before update on reviews
  for each row execute function set_updated_at();


-- ─── Indexes ─────────────────────────────────────────────────────────────────

create index if not exists idx_products_slug       on products(slug);
create index if not exists idx_products_status     on products(status);
create index if not exists idx_products_type       on products(type);
create index if not exists idx_orders_user_id      on orders(user_id);
create index if not exists idx_orders_status       on orders(status);
create index if not exists idx_downloads_user_id   on downloads(user_id);
create index if not exists idx_downloads_product   on downloads(product_id);
create index if not exists idx_reviews_product_id  on reviews(product_id);
create index if not exists idx_reviews_is_approved on reviews(is_approved);


-- ============================================================================
-- Row Level Security
-- ============================================================================

alter table profiles      enable row level security;
alter table categories    enable row level security;
alter table products      enable row level security;
alter table product_images enable row level security;
alter table coupons       enable row level security;
alter table orders        enable row level security;
alter table order_items   enable row level security;
alter table downloads     enable row level security;
alter table reviews       enable row level security;


-- ─── Profiles RLS ────────────────────────────────────────────────────────────

create policy "Users read own profile"
  on profiles for select
  using (auth.uid() = id);

create policy "Users update own profile"
  on profiles for update
  using (auth.uid() = id);

create policy "Admin reads all profiles"
  on profiles for select
  using (
    exists (
      select 1 from profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
  );


-- ─── Categories RLS ──────────────────────────────────────────────────────────

create policy "Anyone reads categories"
  on categories for select
  using (true);

create policy "Admin manages categories"
  on categories for all
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );


-- ─── Products RLS ────────────────────────────────────────────────────────────

create policy "Anyone reads published products"
  on products for select
  using (status = 'published');

create policy "Admin full access to products"
  on products for all
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );


-- ─── Product Images RLS ──────────────────────────────────────────────────────

create policy "Anyone reads product images"
  on product_images for select
  using (
    exists (select 1 from products where id = product_id and status = 'published')
  );

create policy "Admin manages product images"
  on product_images for all
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );


-- ─── Coupons RLS ─────────────────────────────────────────────────────────────
-- Users never read coupons directly — validation is server-side via API

create policy "Admin full access to coupons"
  on coupons for all
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );


-- ─── Orders RLS ──────────────────────────────────────────────────────────────

create policy "Users read own orders"
  on orders for select
  using (user_id = auth.uid());

create policy "Admin reads all orders"
  on orders for select
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );

create policy "Admin updates orders"
  on orders for update
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );


-- ─── Order Items RLS ─────────────────────────────────────────────────────────

create policy "Users read own order items"
  on order_items for select
  using (
    exists (
      select 1 from orders
      where orders.id = order_items.order_id
        and orders.user_id = auth.uid()
    )
  );

create policy "Admin reads all order items"
  on order_items for select
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );


-- ─── Downloads RLS ───────────────────────────────────────────────────────────

create policy "Users read own downloads"
  on downloads for select
  using (user_id = auth.uid());

create policy "Users update own download count"
  on downloads for update
  using (user_id = auth.uid());


-- ─── Reviews RLS ─────────────────────────────────────────────────────────────

create policy "Anyone reads approved reviews"
  on reviews for select
  using (is_approved = true);

create policy "Users manage own reviews"
  on reviews for all
  using (user_id = auth.uid());

create policy "Admin manages all reviews"
  on reviews for all
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );


-- ============================================================================
-- Storage Buckets
-- (Run separately or configure manually in the Supabase Dashboard)
-- ============================================================================

-- product-files   → private (no public access — served via signed URLs only)
-- product-thumbnails → public
-- product-gallery    → public

-- insert into storage.buckets (id, name, public) values
--   ('product-files',      'product-files',      false),
--   ('product-thumbnails', 'product-thumbnails', true),
--   ('product-gallery',    'product-gallery',    true)
-- on conflict (id) do nothing;
