# Tiffe Staff v2 - Partner Hub

Separate Android staff/admin app, version 1.0.2 (2), package com.ambi.tiffe.staff. Updates Staff v1 in place. Customer app is unchanged.

Live Kitchen: tiffin, chapati and rice totals, selected bhaji portions, elapsed waiting time, customer notes, Accept/Reject, Ready for Pickup and Confirm Handover. Owner controls server Auto-Accept for new orders only. Existing backlog is untouched. Manual controls confirm before changing live orders. Reject does not refund automatically.

Gemini-matching dark charcoal and orange Partner Hub with top tabs: Live Kitchen (KDS), All Orders, Menu & Item Status, Subscriptions and Delivery Fleet. Profile menu: Customers, Overview and Sign out. Header uses the signed-in staff profile, not the mockup identity. Menu status is the global catalogue. Fleet shows enrolled delivery staff and current assigned orders, not GPS.

Owner: full hub, payment verification, rider assignment and payment+rider-gated handover. Kitchen: preparation/packing only, no owner settings, rejects, menu edits, payments or dispatch. Delivery: prior assigned-only delivery screen retained. No role selection/promotion in the app. Supabase server rules remain authoritative.

Analyzer and focused mobile role tests passed. Full tests and signing verified by release CI before publication. Mobile screenshots show actual Flutter app widgets with isolated sample data, not production test orders or an installed-device session. Physical-device/network checks remain for the user. No privileged keys or passwords embedded.

Owner Menu manager includes Add Bhaji: name and description saved to the shared live catalog as available. Kitchen and delivery privileges are unchanged.
