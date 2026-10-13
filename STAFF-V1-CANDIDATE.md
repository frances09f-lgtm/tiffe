# Tiffe Staff v1 device-test build

Separate package com.ambi.tiffe.staff, using same live backend as customer Tiffe and admin site. Customer app remains unchanged. Existing Tiffe permanent signing identity reused.

Owner: all orders, customer list, assign/reassign enrolled delivery staff, kitchen preparation/packing, dispatch after verified payment+assignment, explicit receipt-confirmation before payment verification. Kitchen: preparation/packing only. Delivery: own assigned orders/address/phone, mark Delivered after Out for Delivery. No self-selected role or staff promotion.

Live backend read-only verification: orders RLS uses can_read_order, delivery limited to assigned_to=auth.uid(); profiles self/owner; staff roles self/owner. assign_rider owner-only and requires delivery role. advance_order enforces owner dispatch/payment/assignment and delivery only assigned Delivered transition; updates departed_at/eta_at/delivered_at and audit_log. No production orders/status/payments or schema changed for testing.

Delivery picked-up/departure action not enabled in v1 because existing backend restricts dispatch to owner. Rider accounts need staff enrollment; signup alone does not grant access. No real delivery account was created or messaged. Existing Supabase publishable client key is public client configuration, not service role/provider secret. No privileged secrets embedded. README unchanged.

Same backend realtime stream with refresh; no mock source in production. Mobile owner pixels inspected with test fixture, no live customer screenshot. On-device network/subscription behavior remains unverified. Firebase separate app setup/distribution follows audited build.
