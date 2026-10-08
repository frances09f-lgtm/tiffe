Tiffe customer v5 scheduled tracking overlay. Build lib/main.dart. Preserve permanent signing identity and publisher CI. Android package remains com.ambi.tiffe; source folder path follows original project but Kotlin package is com.ambi.tiffe.

Daily subscribers: fixed 20:00 Asia/Kolkata schedule. Before departure shows countdown. At 20:00 Tiffe left, 20:06 On the way, 20:24 arrived. 24-minute clock-based simulated ETA, not real dispatch events or GPS. Reopening derives stage from clock, no reset. Foreground Shell auto-opens the journey once daily. Daily tracking button opens at any time. Notification taps request daily tracker opening. No forced background UI launch.

Native additions: scheduleDaily/cancelDaily/consumeDailyTap channel calls, daily RTC alarms at 20:00/20:06/20:24 IST, setInexactRepeating. Permission-denied and Android idle can delay/suppress alerts. Reboot/force-stop clears alarms; app reopening reschedules. No boot receiver. No server/subscription lifecycle validation or pause/expiry support. Daily sync cancels on local Plan.none. Legacy v3 24-second quick preview remains separate; old start alarm IDs 3100 and daily IDs3200 do not collide.

Admin website cannot control customer schedule yet: no backend. 20:00 fixed demo only. Native compile/device tests still needed in publisher CI and on actual phone. Test tray permission, background, tap opening, restart, overnight repeat and declined permissions. New Kotlin files replace MainActivity/DeliveryNotificationReceiver only; manifest receiver/permissions unchanged from v3.

24 Flutter tests pass, analysis clean. Scheduled/left/on-way/arrived pixels inspected. Existing Android notifications icon and manifest must remain. No money/real order/backend created.
