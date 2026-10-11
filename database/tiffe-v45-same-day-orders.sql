-- TIFFE v45 OWNER-RUN MIGRATION. Not applied by APK installation.
-- Before running, inspect existing definitions and save their output.
-- Uses the established noon lunch / 20:00 dinner IST cutoffs.
-- Does not charge money or change payment verification rules.
begin;
create or replace function public.generate_subscription_orders(p_day date, p_subscription text)
returns int language plpgsql security definer set search_path = public, pg_temp as $body$
declare
  cfg public.settings; sub public.subscriptions; prof public.profiles;
  meals text[]; m text; oid uuid; k uuid; made int = 0;
  picks uuid[]; r record;
begin
  select * into cfg from public.settings where id = true;
  for sub in
    select * from public.subscriptions
    where verified and (p_subscription is null or id::text=p_subscription) and p_day between starts_on and ends_on
      and not (p_day = any(coalesce(paused_on, '{}'::date[])))
  loop
    select * into prof from public.profiles where id = sub.customer_id;
    if prof.id is null or coalesce(prof.name,'') = '' or coalesce(prof.address,'') = ''
       or coalesce(prof.phone,'') = '' or not (prof.area = any(cfg.areas)) then
      continue;
    end if;
    meals := case when sub.plan = 'double' then array['lunch','dinner'] else array['lunch'] end;
    picks := null;
    select array_agg(menu_item_id order by n) into picks from (
      select oi.menu_item_id, row_number() over () as n
      from public.order_items oi
      join public.menu_items mi on mi.id = oi.menu_item_id and mi.available
      where oi.order_id = (
        select o.id from public.orders o
        where o.customer_id = sub.customer_id and o.status <> 'Cancelled'
          and exists (select 1 from public.order_items x where x.order_id = o.id and x.tiffin = 1)
        order by coalesce(o.bhajis_changed_at, o.created_at) desc limit 1)
        and oi.tiffin = 1
      limit 2) s;
    if picks is null or array_length(picks, 1) < 2 then
      select array_agg(id) into picks from (
        select id from public.menu_items where available order by sort_order, name limit 2) d;
    end if;
    if picks is null or array_length(picks, 1) < 2 then continue; end if;
    foreach m in array meals loop
      -- Do not create expired meals when a subscription starts during the day.
      if p_day < (now() at time zone 'Asia/Kolkata')::date then continue; end if;
      if p_day = (now() at time zone 'Asia/Kolkata')::date and
         (now() at time zone 'Asia/Kolkata')::time >=
         case when m='dinner' then time '20:00' else time '12:00' end then continue; end if;
      k := md5(sub.id::text || ':' || p_day::text || ':' || m)::uuid;
      perform pg_advisory_xact_lock(hashtextextended(k::text,0));
      if exists (select 1 from public.orders where customer_id = sub.customer_id and idempotency_key = k) then
        continue;
      end if;
      insert into public.orders(customer_id, delivery_date, subscription_id, quantity, total_paise,
                                address_snapshot, instructions, idempotency_key, meal, payment_status)
      values (sub.customer_id, p_day, sub.id, 1, 0,
              jsonb_build_object('name', prof.name, 'phone', prof.phone, 'address', prof.address, 'area', prof.area),
              '', k, m, 'verified')
      returning id into oid;
      for r in select mi.id, mi.name from public.menu_items mi where mi.id = any(picks) loop
        insert into public.order_items(order_id, tiffin, menu_item_id, item_name, extra_price_paise)
        values (oid, 1, r.id, r.name, 0);
      end loop;
      made := made + 1;
    end loop;
  end loop;
  return made;
end
$body$;
revoke all on function public.generate_subscription_orders(date,text) from public, anon, authenticated;

create or replace function public.generate_daily_orders(p_day date)
returns int language sql security definer set search_path=public,pg_temp as $$
 select public.generate_subscription_orders(p_day,null);
$$;
revoke all on function public.generate_daily_orders(date) from public,anon,authenticated;

create or replace function public.subscription_same_day_orders()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if new.verified and (now() at time zone 'Asia/Kolkata')::date between new.starts_on and new.ends_on then
  perform public.generate_subscription_orders((now() at time zone 'Asia/Kolkata')::date,new.id::text);
 end if;
 return new;
end $$;
revoke all on function public.subscription_same_day_orders() from public,anon,authenticated;
drop trigger if exists tiffe_subscription_same_day_orders on public.subscriptions;
create trigger tiffe_subscription_same_day_orders after insert or update of verified,starts_on,ends_on on public.subscriptions
for each row execute function public.subscription_same_day_orders();
commit;
