# Tiffe Admin Demo v1

Static Flutter web build. No backend, authentication, persistence, real customers, payment processing or notification sends.

Entrypoint: lib/admin_main.dart

Build: flutter build web --release -t lib/admin_main.dart --base-href /tiffe/ --no-wasm-dry-run

The attached static ZIP uses /tiffe/ base href for the existing tiffe GitHub project Pages site. Extract contents directly into the Pages artifact root, including assets, canvaskit and hidden .nojekyll. For a different hosting path rebuild with the correct base href.

No APK signing, Android, customer app entrypoint, publisher CI or repository credentials are changed by this overlay. Copy only the included files.

20 Flutter tests pass, flutter analyze clean. Desktop/tablet widget pixels and role-specific navigation inspected. Publisher must inspect the deployed site's actual browser pixels, asset loading, login/demo-role entry, navigation, packing checks and mobile drawer before declaring the link ready.

Implemented demo workflows: status changes, automatic demand excluding cancelled/refunded/failed orders, prepared counts, per-tiffin packing checklist, role-filtered navigation and assigned delivery view, local delivery assignments, menu availability/publish state, Sunday sweet choice, pause text entry, price/cutoff/area controls, notification preview, session audit.

Still incomplete: catalog CRUD/upload/reorder; real date filtering and complete customer histories; secure auth/backend authorization; saved state; server price/eligibility/cutoff rules; full reports/date exports; real delivery contact/route info; notification sending; staff account CRUD. Follow-up versions, not production claims.

Pricing retained from explicit user correction: subscriptions Rs 1500/3000 monthly, one-time Rs 80, extra bhaji Rs 10, delivery Rs 199/month for subscriptions or Rs 20 one-time. New spec lists Rs 199 generically; confirmation required before changing the one-time split.
