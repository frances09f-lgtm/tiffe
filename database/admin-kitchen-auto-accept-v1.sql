begin;
alter table public.settings add column if not exists kitchen_auto_accept boolean not null default false;
create or replace function public.set_kitchen_auto_accept(p_enabled boolean) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if public.tiffe_role() is distinct from 'owner' then raise exception 'Not allowed'; end if;
 update public.settings set kitchen_auto_accept=p_enabled where id=true;
 if not found then raise exception 'Settings not configured'; end if;
end;
$$;
revoke all on function public.set_kitchen_auto_accept(boolean) from public,anon;
grant execute on function public.set_kitchen_auto_accept(boolean) to authenticated;
create or replace function public.kitchen_auto_accept_insert() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if new.status='Confirmed' and coalesce((select kitchen_auto_accept from public.settings where id=true),false) then
  new.status:='Preparing';
  new.updated_at:=now();
 end if;
 return new;
end;
$$;
revoke all on function public.kitchen_auto_accept_insert() from public,anon,authenticated;
drop trigger if exists kitchen_auto_accept_insert on public.orders;
create trigger kitchen_auto_accept_insert before insert on public.orders for each row execute function public.kitchen_auto_accept_insert();
update public.settings set kitchen_auto_accept=true where id=true;
commit;
