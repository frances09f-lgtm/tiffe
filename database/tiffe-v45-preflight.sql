-- Owner-run read-only preflight. Save results before migration.
select pg_get_functiondef('public.generate_daily_orders(date)'::regprocedure);
select pg_get_functiondef('public.buy_subscription(text)'::regprocedure);
select pg_get_functiondef('public.verify_subscription(text)'::regprocedure);
select column_name,data_type from information_schema.columns where table_schema='public'
and table_name in ('subscriptions','orders','order_items','menu_items','profiles','settings') order by table_name,ordinal_position;
select jobname,schedule,active from cron.job where jobname='tiffe_daily_orders';
