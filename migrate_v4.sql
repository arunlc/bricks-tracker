-- ============================================================
-- Bricks Delivery Tracker — UPGRADE v3 -> v4
-- Adds: expense tracking + monthly revenue + monthly P&L.
-- Safe to run on your existing database. It does not touch
-- customers, deliveries, or payments data.
-- Run in Supabase: SQL Editor -> New query -> paste -> Run.
-- ============================================================

-- 1) Expenses: itemised operating costs, by category.
create table if not exists expenses (
  id            uuid primary key default gen_random_uuid(),
  expense_date  date not null default current_date,
  category      text not null,        -- Driver, Fuel, Maintenance, Loading, Rent, Other
  amount        numeric(12,2) not null default 0,
  notes         text,
  voided_at     timestamptz,          -- soft-delete, same pattern as the rest
  created_at    timestamptz not null default now()
);
create index if not exists idx_expenses_date on expenses (expense_date);

-- 2) RLS so the app's anon key can read/write expenses
--    (matches the policy style used for the other tables).
alter table expenses enable row level security;
drop policy if exists "anon all expenses" on expenses;
create policy "anon all expenses" on expenses for all using (true) with check (true);

-- 3) Monthly revenue = money COLLECTED in that month (by payment_date).
--    Voided payments excluded.
create or replace view monthly_revenue as
select
  to_char(payment_date, 'YYYY-MM') as month,
  sum(amount) as collected,
  count(*)    as num_payments
from payments
where voided_at is null
group by 1
order by 1 desc;

-- 4) Monthly costs = expenses in that month (by expense_date).
create or replace view monthly_costs as
select
  to_char(expense_date, 'YYYY-MM') as month,
  sum(amount) as costs,
  count(*)    as num_expenses
from expenses
where voided_at is null
group by 1
order by 1 desc;

-- 5) Monthly P&L: delivered (billed), collected, costs, profit.
--    "delivered" = value of bricks sent that month (by delivery_date).
--    "collected" = cash received that month (by payment_date).
--    "profit"    = collected - costs (cash-basis, matches how revenue is counted).
--    Pending is a running figure (not monthly), shown separately on the dashboard.
create or replace view monthly_pnl as
with months as (
  select to_char(delivery_date,'YYYY-MM') as month from deliveries where voided_at is null
  union
  select to_char(payment_date,'YYYY-MM')  from payments  where voided_at is null
  union
  select to_char(expense_date,'YYYY-MM')  from expenses  where voided_at is null
),
dlv as (
  select to_char(delivery_date,'YYYY-MM') as month, sum(total_value) v
  from deliveries where voided_at is null group by 1
),
pay as (
  select to_char(payment_date,'YYYY-MM') as month, sum(amount) v
  from payments where voided_at is null group by 1
),
exp as (
  select to_char(expense_date,'YYYY-MM') as month, sum(amount) v
  from expenses where voided_at is null group by 1
)
select
  m.month,
  coalesce(dlv.v,0) as delivered,
  coalesce(pay.v,0) as collected,
  coalesce(exp.v,0) as costs,
  coalesce(pay.v,0) - coalesce(exp.v,0) as profit
from (select distinct month from months) m
left join dlv on dlv.month=m.month
left join pay on pay.month=m.month
left join exp on exp.month=m.month
order by m.month desc;
