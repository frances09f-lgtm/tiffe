-- READ-ONLY CHECKS AFTER RUN (run separately from migration):
select jobname,schedule,active from cron.job where jobname='tiffe_daily_orders';
select jobid,status,start_time,end_time,return_message from cron.job_run_details
where jobid in (select jobid from cron.job where jobname='tiffe_daily_orders') order by start_time desc limit 5;

-- Read-only order/prerequisite check for the reported customer. This does not
-- assert identity from name alone: inspect the ID and subscription details.
select p.id,p.name,(nullif(trim(p.name),'') is not null and nullif(trim(p.phone),'') is not null and nullif(trim(p.address),'') is not null) as profile_complete,
 p.area, p.area=any(c.areas) as area_allowed,
 (select count(*) from public.menu_items where available) as available_menu_count,
 s.id as subscription_id,s.plan,s.verified,s.starts_on,s.ends_on,
 (select count(*) from public.orders o where o.subscription_id=s.id and o.delivery_date=(now() at time zone 'Asia/Kolkata')::date) as orders_today
from public.profiles p left join public.subscriptions s on s.customer_id=p.id
cross join public.settings c where c.id=true and p.name ilike '%Aditya%';
