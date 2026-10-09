# Shared backend slice

Dedicated Tiffe Supabase project, Mumbai, free plan. No trading-journal changes.

Schema uses Postgres + RLS. Staff roles are server-assigned, never a role picker. Customer profile is separate from auth. Status changes run through SQL RPC, not clock simulation. Client totals, payment status and roles cannot be supplied on create. Dispatch requires verified payment and assigned rider. Payment integration remains pending; no checkout claims success.

Deploy schema only after exact editor content verification. Policy testing: anonymous cannot read people/orders; customer sees own only; kitchen gets operational orders; delivery sees assigned only; unassigned delivery cannot change orders; customer cannot set prices/paid/role; invalid transitions and cutoff rejected; duplicate submission returns same order ID. Real credentials and live customer rows never belong in public source or screenshots.

Backend URL/publishable client key are runtime build settings. No service-role key on device/web. Database password saved only securely. Client code currently not wired into old demo entrypoints. Do not ship this slice as live until entrypoints/empty states/server authorization/cross-client stream tested.
