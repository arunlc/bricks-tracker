-- ============================================================
-- Bricks Delivery Tracker — database schema (v3: soft-delete / void)
-- Run this once in Supabase: SQL Editor -> New query -> paste -> Run.
--
-- Already on v2? Jump to the "UPGRADE v2 -> v3" block near the bottom —
-- you only need to add the voided_at columns and refresh the views.
-- ============================================================

create table if not exists customers (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  phone       text not null,          -- store with country code, e.g. 919876543210
  notes       text,
  created_at  timestamptz not null default now()
);

-- DELIVERIES: each load of bricks sent. This is what the customer OWES.
create table if not exists deliveries (
  id              uuid primary key default gen_random_uuid(),
  customer_id     uuid not null references customers(id) on delete cascade,
  delivery_date   date not null default current_date,
  bricks          integer not null default 0,
  price_per_brick numeric(10,2) not null default 0,
  total_value     numeric(12,2) not null default 0,   -- bricks * price
  notes           text,
  voided_at       timestamptz,        -- null = active; a timestamp = voided (hidden)
  created_at      timestamptz not null default now()
);

-- PAYMENTS: each amount the customer pays. Many payments per customer.
create table if not exists payments (
  id             uuid primary key default gen_random_uuid(),
  customer_id    uuid not null references customers(id) on delete cascade,
  payment_date   date not null default current_date,
  amount         numeric(12,2) not null default 0,
  method         text,             -- UPI / Cash / Net Banking / Cheque ...
  notes          text,
  voided_at      timestamptz,       -- null = active; a timestamp = voided (hidden)
  created_at     timestamptz not null default now()
);

create index if not exists idx_customers_name on customers (lower(name));
create index if not exists idx_deliveries_customer on deliveries (customer_id);
create index if not exists idx_payments_customer on payments (customer_id);

-- Per-customer balance. VOIDED rows are excluded from every sum.
create or replace view customer_balance as
select
  c.id   as customer_id,
  c.name,
  c.phone,
  coalesce((select sum(d.total_value) from deliveries d
            where d.customer_id = c.id and d.voided_at is null), 0) as total_billed,
  coalesce((select sum(p.amount) from payments p
            where p.customer_id = c.id and p.voided_at is null), 0) as total_paid,
  coalesce((select sum(d.total_value) from deliveries d
            where d.customer_id = c.id and d.voided_at is null), 0)
    - coalesce((select sum(p.amount) from payments p
            where p.customer_id = c.id and p.voided_at is null), 0) as pending,
  (select max(d.delivery_date) from deliveries d
   where d.customer_id = c.id and d.voided_at is null) as last_delivery
from customers c;

-- The Friday email reads this: only customers who still owe money.
create or replace view pending_summary as
select customer_id, name, phone, total_billed, total_paid, pending, last_delivery
from customer_balance
where pending > 0
order by pending desc;

-- ============================================================
-- UPGRADE v2 -> v3 (only if you already created v2 tables).
-- Run these three lines once; existing rows default to active.
-- ============================================================
-- alter table deliveries add column if not exists voided_at timestamptz;
-- alter table payments   add column if not exists voided_at timestamptz;
-- (then re-run the two "create or replace view" statements above)

-- ============================================================
-- v4 additions: expenses + monthly revenue + monthly P&L
-- (Included here for fresh installs. If upgrading an existing
--  database, run migrate_v4.sql instead.)
-- ============================================================
create table if not exists expenses (
  id            uuid primary key default gen_random_uuid(),
  expense_date  date not null default current_date,
  category      text not null,
  amount        numeric(12,2) not null default 0,
  notes         text,
  voided_at     timestamptz,
  created_at    timestamptz not null default now()
);
create index if not exists idx_expenses_date on expenses (expense_date);

create or replace view monthly_revenue as
select to_char(payment_date,'YYYY-MM') as month, sum(amount) as collected, count(*) as num_payments
from payments where voided_at is null group by 1 order by 1 desc;

create or replace view monthly_costs as
select to_char(expense_date,'YYYY-MM') as month, sum(amount) as costs, count(*) as num_expenses
from expenses where voided_at is null group by 1 order by 1 desc;

create or replace view monthly_pnl as
with months as (
  select to_char(delivery_date,'YYYY-MM') as month from deliveries where voided_at is null
  union select to_char(payment_date,'YYYY-MM') from payments where voided_at is null
  union select to_char(expense_date,'YYYY-MM') from expenses where voided_at is null
),
dlv as (select to_char(delivery_date,'YYYY-MM') as month, sum(total_value) v from deliveries where voided_at is null group by 1),
pay as (select to_char(payment_date,'YYYY-MM') as month, sum(amount) v from payments where voided_at is null group by 1),
exp as (select to_char(expense_date,'YYYY-MM') as month, sum(amount) v from expenses where voided_at is null group by 1)
select m.month,
  coalesce(dlv.v,0) as delivered, coalesce(pay.v,0) as collected,
  coalesce(exp.v,0) as costs, coalesce(pay.v,0)-coalesce(exp.v,0) as profit
from (select distinct month from months) m
left join dlv on dlv.month=m.month
left join pay on pay.month=m.month
left join exp on exp.month=m.month
order by m.month desc;
