# Tiffe v3

## Admin website
[Open the Tiffe admin website](https://frances09f-lgtm.github.io/tiffe/review/admin/) - owner sign-in required.

Flutter UI-first preview for a Pune home-kitchen tiffin service.

## Try it
Enter an Indian-format mobile number, then use **123456** as the mock OTP. No SMS is sent. Enter name and sample Pune address. All customer inputs stay on this device. No analytics, external APIs, payment, or live order submission.

## Included
- Animated splash, mobile/OTP/name/address onboarding with validation.
- Cream/green home, offline bundled food imagery, five-tab navigation.
- Today/tomorrow date-based sample menu of 8 bhajis.
- Two-column selection with checkmarks and animated highlight. First 2 included; each additional bhaji ₹10. No cap at 2.
- Double plan keeps each tiffin's selection independent.
- Plans: ₹1,500 daily and ₹3,000 double; one-time ₹80.
- Local persistence of onboarding, selected preview plan, date/tiffin choices and My Usual.
- Basic checkout preview displays ₹199/month subscription delivery or ₹20 one-time delivery before final confirmation; no payment is collected.
- Subscriber-only Sunday sweet predicate. Orders is an honest empty state.

## Not production-connected
Backend, actual OTP/auth, payments, backend pricing validation, live subscription/order creation, payment history, pause extension, cutoff automation, live menu/sold-out updates, kitchen/admin dashboard, delivery dashboard and push notifications are later releases. Sample coverage is not real operational delivery availability. Food photos are generated illustrative assets, not actual kitchen photographs.

Delivery clarified by the owner on October 9: ₹199/month for subscriptions; ₹20 for a one-time tiffin. Base plan prices remain ₹1,500/₹3,000 and one-time ₹80.

## Build
Pinned Flutter 3.47.6 / Dart 3.13.5, Java 17. `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --release --target-platform android-arm64`.

Package: `com.ambi.tiffe`. Version: 1.0.3+3.

Publisher must replace template debug release signing with a **new permanent Tiffe signing identity**, held in repository secrets. No keystore or secrets are in this source archive. Do not publish a debug-signed production APK.

15 tests cover pricing, per-tiffin extras, Sunday eligibility, dates, unique menu, onboarding validations, independent Double choices and persistence. Widget tests generate screenshot captures for 430x932 and 360x800 logical layouts, using bundled fonts and images.

Payment-success screen is a clearly labelled visual demo after preview confirmation. No payment, transaction ID, order or live subscription is created.
