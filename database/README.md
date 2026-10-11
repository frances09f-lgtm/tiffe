# v45 same-day order setup

APK installation does not apply database migrations. This draft is based on the SQL the owner ran on 11 October 2026 and needs the current live definitions checked first.

1. Run tiffe-v45-preflight.sql in the owner's Supabase SQL Editor and save the output. Stop if the current definitions/schema differ.
2. Review tiffe-v45-same-day-orders.sql. It preserves current verification rules, creates only unexpired meals for the affected subscription, and uses the existing meal-specific idempotency key with a transaction lock. It creates no retrospective meals and charges nothing.
3. After review, run the migration as the database owner, then tiffe-v45-checks.sql. The nightly cron is not created by this migration.
4. Missing cron, incomplete profile, unknown delivery area or fewer than two available menu items still prevent automatic orders. The trigger deliberately preserves those checks.

Lunch cutoff is noon IST; dinner cutoff is 20:00 IST. A Double subscription created at 14:26 creates dinner only that day. Its next midnight run creates the next day's two meals if the cron and other prerequisites are set.

Not applied to the live database. No existing orders or payment records have been edited by preparing these files.
