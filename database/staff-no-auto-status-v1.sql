-- Staff 1.0.7: order status must change only when staff tap a status in the
-- Staff app. This file must be run once by the database owner (Supabase SQL
-- editor). The app cannot drop a database trigger, so until this runs the
-- trigger below can still move new Confirmed orders to Preparing by itself.
begin;
drop trigger if exists kitchen_auto_accept_insert on public.orders;
update public.settings set kitchen_auto_accept=false where id=true;
commit;
