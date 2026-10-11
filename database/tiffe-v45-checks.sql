-- READ-ONLY CHECKS AFTER RUN (run separately from migration):
select jobname,schedule,active from cron.job where jobname='tiffe_daily_orders';
select jobid,status,start_time,end_time,return_message from cron.job_run_details
where jobid in (select jobid from cron.job where jobname='tiffe_daily_orders') order by start_time desc limit 5;
