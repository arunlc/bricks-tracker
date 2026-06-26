-- ============================================================
-- Bricks Delivery Tracker — UPGRADE v4 -> v5 (login security)
-- Replaces the open "anyone with the anon key" policies with
-- "only a logged-in user" policies. Run this AFTER you have
-- created the owner login (see README step), so you don't lock
-- yourself out.
-- Run in Supabase: SQL Editor -> New query -> paste -> Run.
-- ============================================================

-- Drop the old open policies
drop policy if exists "anon all customers"  on customers;
drop policy if exists "anon all deliveries" on deliveries;
drop policy if exists "anon all payments"   on payments;
drop policy if exists "anon all expenses"   on expenses;

-- New: only authenticated (logged-in) users can read/write.
create policy "auth all customers"  on customers  for all
  to authenticated using (true) with check (true);
create policy "auth all deliveries" on deliveries for all
  to authenticated using (true) with check (true);
create policy "auth all payments"   on payments   for all
  to authenticated using (true) with check (true);
create policy "auth all expenses"   on expenses   for all
  to authenticated using (true) with check (true);

-- Views (customer_balance, pending_summary, monthly_*) read from the
-- tables above, so they inherit this protection automatically.

-- NOTE: the Friday email uses the SERVICE_ROLE key, which bypasses
-- RLS by design — so the scheduled email keeps working after this.
