-- Tiffe v56 (customer 1.0.56 / Staff 1.0.10): "Order placed" until staff
-- accept, and Remove (archive) for bhajis.
--
-- Run ONCE as the database owner in the Supabase SQL editor. Additive only:
--   * adds two nullable columns and one function;
--   * changes no existing row: older orders keep awaiting_acceptance = NULL,
--     which both apps read as "already confirmed", so every existing order
--     (including the owner's current order) shows exactly as before;
--   * does not touch place_order, advance_order, the status values, any
--     check constraint, trigger or RLS policy.
-- Safe to run twice (IF NOT EXISTS / CREATE OR REPLACE).
-- Both apps also work BEFORE this runs: no order is ever shown as
-- "Order placed", and Remove says the database update is needed.

begin;

-- 5. Order placed -> Confirmed after staff accept ----------------------------
-- NULL  = order created before this migration (treated as confirmed)
-- true  = new order, not yet accepted by the kitchen ("Order placed")
-- false = accepted by staff ("Confirmed")
-- Only meaningful while status = 'Confirmed'; later statuses ignore it.
alter table public.orders
  add column if not exists awaiting_acceptance boolean;
-- Only rows inserted from now on get true. ADD COLUMN above has no default,
-- so existing rows stay NULL (no table rewrite, no data change).
alter table public.orders
  alter column awaiting_acceptance set default true;
comment on column public.orders.awaiting_acceptance is
  'Tiffe v56: true = placed, waiting for staff to accept; false = accepted; null = created before v56 (treated as accepted).';

create or replace function public.accept_order(p_order text) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  r text := public.tiffe_role();
begin
  if r is null or r not in ('owner', 'kitchen') then
    raise exception 'Not allowed';
  end if;
  update public.orders
     set awaiting_acceptance = false,
         updated_at = now()
   where id::text = p_order
     and status = 'Confirmed'
     and awaiting_acceptance is true;
  if not found then
    raise exception 'Order is not waiting for acceptance';
  end if;
end;
$$;
revoke all on function public.accept_order(text) from public, anon;
grant execute on function public.accept_order(text) to authenticated;

-- 6. Remove (archive) a bhaji ---------------------------------------------------
-- The row stays, so order_items and old orders keep their history. The apps
-- hide rows with archived_at set from every menu; Remove also switches
-- available off, so ordering and the nightly plan orders skip it.
alter table public.menu_items
  add column if not exists archived_at timestamptz;
comment on column public.menu_items.archived_at is
  'Tiffe v56: set when staff Remove the bhaji. Hidden from menus; kept for order history.';

commit;

-- Checks (read-only) ------------------------------------------------------------
-- Existing orders unchanged (expect 0 rows with a non-null flag right after
-- running this, until a new order arrives):
--   select count(*) from public.orders where awaiting_acceptance is not null;
-- Column defaults:
--   select column_name, column_default from information_schema.columns
--    where table_schema = 'public' and table_name = 'orders'
--      and column_name = 'awaiting_acceptance';
