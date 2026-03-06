-- ============================================================
-- Migration 002: License Management System Schema + Indexes
-- Run this after 001_initial_schema.sql
-- ============================================================

-- ─── License Plans ───────────────────────────────────────────────────────────

create table if not exists license_plans (
  id                uuid primary key default gen_random_uuid(),
  product_id        uuid not null references products on delete cascade,
  name              text not null,
  type              text not null check (type in ('perpetual','subscription','trial')),
  price             integer not null,
  currency          text default 'usd',
  billing_interval  text check (billing_interval in ('month','year')),
  trial_days        integer,
  max_activations   integer default 1,
  features          jsonb default '[]',
  is_active         boolean default true,
  stripe_price_id   text,
  stripe_product_id text,
  created_at        timestamptz default now()
);

-- ─── Licenses ────────────────────────────────────────────────────────────────

create table if not exists licenses (
  id                     uuid primary key default gen_random_uuid(),
  license_key            text unique not null,
  user_id                uuid not null references auth.users on delete restrict,
  product_id             uuid not null references products on delete restrict,
  license_plan_id        uuid not null references license_plans on delete restrict,
  order_item_id          uuid references order_items,
  status                 text default 'active'
                           check (status in ('active','expired','revoked','suspended','trial')),
  type                   text not null check (type in ('perpetual','subscription','trial')),
  max_activations        integer not null default 1,
  activation_count       integer not null default 0,
  issued_at              timestamptz default now(),
  expires_at             timestamptz,
  revoked_at             timestamptz,
  revocation_reason      text,
  stripe_subscription_id text,
  metadata               jsonb default '{}',
  created_at             timestamptz default now(),
  updated_at             timestamptz default now()
);

-- ─── License Activations ─────────────────────────────────────────────────────

create table if not exists license_activations (
  id                 uuid primary key default gen_random_uuid(),
  license_id         uuid not null references licenses on delete cascade,
  machine_id         text not null,
  machine_name       text,
  ip_address         text,
  is_active          boolean default true,
  first_activated_at timestamptz default now(),
  last_seen_at       timestamptz default now(),
  unique(license_id, machine_id)
);

-- ─── License Events (audit log) ──────────────────────────────────────────────

create table if not exists license_events (
  id          uuid primary key default gen_random_uuid(),
  license_id  uuid not null references licenses on delete cascade,
  event_type  text not null check (event_type in (
                'issued','activated','deactivated','verified',
                'expired','revoked','suspended','renewed','reactivated')),
  machine_id  text,
  ip_address  text,
  metadata    jsonb default '{}',
  created_at  timestamptz default now()
);

-- ─── Performance Indexes (CRITICAL for license validation) ───────────────────
-- These indexes are essential for sub-100ms verification under load.
-- idx_licenses_license_key is used in every verification/activation request.

create index if not exists idx_licenses_license_key    on licenses(license_key);
create index if not exists idx_licenses_user_id        on licenses(user_id);
create index if not exists idx_licenses_product_id     on licenses(product_id);
create index if not exists idx_licenses_status         on licenses(status);
create index if not exists idx_licenses_expires_at     on licenses(expires_at) where expires_at is not null;
create index if not exists idx_activations_license_id  on license_activations(license_id);
create index if not exists idx_activations_machine_id  on license_activations(machine_id);
create index if not exists idx_activations_is_active   on license_activations(is_active) where is_active = true;
create index if not exists idx_events_license_id       on license_events(license_id);
create index if not exists idx_events_created_at       on license_events(created_at desc);
create index if not exists idx_plans_product_id        on license_plans(product_id);
create index if not exists idx_plans_is_active         on license_plans(is_active) where is_active = true;

-- ─── RLS Policies ────────────────────────────────────────────────────────────

alter table license_plans enable row level security;
alter table licenses enable row level security;
alter table license_activations enable row level security;
alter table license_events enable row level security;

-- License plans: anyone can read active plans; admin can manage all
create policy "Public read active license_plans"
  on license_plans for select
  using (is_active = true);

create policy "Admin manages license_plans"
  on license_plans for all
  using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.role = 'admin'
    )
  );

-- Licenses: users see their own; service_role writes
create policy "Users read own licenses"
  on licenses for select
  using (user_id = auth.uid());

create policy "Admin reads all licenses"
  on licenses for select
  using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.role = 'admin'
    )
  );

create policy "Admin updates licenses"
  on licenses for update
  using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.role = 'admin'
    )
  );

-- License activations: users see their own license activations
create policy "Users read own activations"
  on license_activations for select
  using (
    exists (
      select 1 from licenses
      where licenses.id = license_activations.license_id
        and licenses.user_id = auth.uid()
    )
  );

-- License events: admin only
create policy "Admin reads license_events"
  on license_events for select
  using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.role = 'admin'
    )
  );

-- ─── Updated_at trigger for licenses ────────────────────────────────────────

create or replace function update_licenses_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger licenses_updated_at
  before update on licenses
  for each row execute function update_licenses_updated_at();

-- ─── Orders table (if not created in 001) ────────────────────────────────────

create table if not exists orders (
  id                     uuid primary key default gen_random_uuid(),
  user_id                uuid not null references auth.users on delete restrict,
  status                 text default 'pending'
                           check (status in ('pending','completed','refunded','failed')),
  total_amount           integer not null,
  discount_amount        integer default 0,
  stripe_session_id      text unique,
  stripe_payment_intent  text,
  stripe_subscription_id text,
  coupon_id              uuid references coupons,
  created_at             timestamptz default now()
);

create table if not exists order_items (
  id              uuid primary key default gen_random_uuid(),
  order_id        uuid not null references orders on delete cascade,
  product_id      uuid not null references products on delete restrict,
  license_plan_id uuid not null references license_plans on delete restrict,
  price           integer not null,
  created_at      timestamptz default now()
);

create index if not exists idx_orders_user_id        on orders(user_id);
create index if not exists idx_orders_status         on orders(status);
create index if not exists idx_orders_stripe_session on orders(stripe_session_id) where stripe_session_id is not null;
create index if not exists idx_order_items_order_id  on order_items(order_id);

-- Enable RLS on orders
alter table orders enable row level security;
alter table order_items enable row level security;

create policy "Users read own orders"
  on orders for select
  using (user_id = auth.uid());

create policy "Admin reads all orders"
  on orders for select
  using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.role = 'admin'
    )
  );

create policy "Users read own order_items"
  on order_items for select
  using (
    exists (
      select 1 from orders
      where orders.id = order_items.order_id
        and orders.user_id = auth.uid()
    )
  );
