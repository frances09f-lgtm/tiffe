# Tiffe

Flutter Android app for a home-kitchen tiffin service, with customer accounts, meals, subscriptions, orders and staff tools. This guide describes the **connected v44 / 1.0.44+44** release. The old v3 mock-OTP guide is no longer the setup guide for the published app.

## Install and sign in

1. Open this repository's **Releases** section and download `Tiffe.apk` from the latest published release.
2. Install on an ARM64 Android phone. Allow installation from your browser or Files app if Android asks.
3. Open Tiffe. After the split green/cream splash, signed-out customers see **Welcome Back / Sign in**. Signed-in customers go to Home.
4. Use your **email and password**. For a new account, select **Create account**, enter an email and a password of at least 8 characters, and follow any email-confirmation instructions before signing in.
5. Complete your profile with name, phone number, delivery address and area. Check that the kitchen serves that address before placing an order.

The connected app does **not** use the old `123456` mock OTP. It does not silently switch to demo authentication/orders when the server is unavailable. A backend-unavailable screen is not a successful sign-in.

## What keys a normal customer needs

**None.** The published app already contains its public Supabase project address and publishable app key. Customers enter their own account credentials inside the app; they do not enter a database key or provider key. No Firebase app key, Groq/Gemini key or Cloudflare token is required to use Tiffe.

| Public build value | Current deployment | Where it goes for a source build |
| --- | --- | --- |
| `TIFFE_SUPABASE_URL` | `https://obbtxyjglgivcpusjpcx.supabase.co` | Flutter `--dart-define` |
| `TIFFE_SUPABASE_KEY` | `sb_publishable__5qR0bvVmwqKykgbQpAtRw_H0eIgl3_` | Flutter `--dart-define` |
| `TIFFE_OWNER_EMAIL` | Your own deployment's owner sign-in email | Optional build-time alias for staff `admin` sign-in; not a password |

The Supabase publishable key is public application configuration, not a service-role key. Authentication, row-level security and server RPC checks must decide what each account may do. Never use a secret/service-role key in an APK or public website.

## Customer screens

- **Home:** current plan and meals. A server subscription takes priority over phone-local preview choices.
- **Menu:** select the date/tiffin and bhajis. Double-plan tiffins keep their selections independently. Review the checkout's actual pricing and cutoff response.
- **Plans:** choose Daily or Double. v44 calls the backend to create an active 30-day subscription immediately when its checkout action succeeds.
- **Orders:** review submitted orders, items and status. Use tracking only when its state makes it available.
- **Profile:** edit delivery details, view your subscription and change the light/dark setting. Map tiles remain light in dark mode.

Menu, price, availability, cutoff and delivery rules come from the current backend settings. Do not assume a price from an old screenshot or release note is still the checkout total.

## Important: real records, but no online payment gateway

The UPI/Card selection and payment animation are currently a **visual flow**, not a live payment gateway. No card charge or UPI transfer is collected by that screen. Its tick animation is not evidence of money received.

- In **v44**, selecting Pay for a subscription can create a **real active plan immediately without a collected payment**, as chosen for this testing release.
- One-time checkout submits a **real order** during the processing screen. A backend failure returns an error instead of a successful-order screen.
- Owner/staff payment verification is separate from the animation. Coordinate any real payment directly with the kitchen, then have the owner verify it through the supported staff tools.

Do not create test subscriptions/orders on someone else's customer account. A demo-looking checkout can still mutate real backend records.

## Tracking limits

Order status comes from backend records. Some phone-local sample progression can be displayed for newly placed test orders until a real kitchen status change takes priority. The absence of a "Demo" label does not turn a simulated route/status into live rider GPS.

A map pin, predicted progress or enabled map button alone does not establish a rider's current location. Real staff dispatch and location data must be verified separately. Force-stop, internet loss and stale server data can affect updates.

## Staff and owner

The Android staff workspace uses authenticated accounts with owner-enabled roles. A normal signup does not make someone staff. Owner/kitchen staff can manage menu/orders; dispatch requires the relevant payment verification and assigned rider. Delivery accounts have a separate role-limited workflow.

An owner admin website has also been published through this repository's GitHub Pages. Use the owner-provided current website link and an authorized account. Its deployment/source is maintained separately from this Android entry point. Never put an admin password in the README or APK. `admin` is only a configured email alias, not a default password or an authorization bypass.

## Troubleshooting

- **Sign-in fails:** use email/password, not mock OTP. Confirm the email if required and check internet.
- **Backend unavailable:** retry after connectivity is restored. No real-order success should be inferred from this screen.
- **Plan fails/already exists:** read the server error. The backend permits one current plan per customer. Do not repeatedly create orders to test it.
- **No order/plan after checkout:** check the actual Orders/Plans view and error message. The animation alone is not proof.
- **Payment unverified:** no online collection happens in the current method screen. Ask the kitchen to reconcile the actual payment, if any.
- **Map disabled or old status:** check order state and whether a real staff update has occurred. Do not assume live GPS from the drawing.
- **Cannot install an update:** use the published APK with the same signer. Locally signed builds cannot overwrite the official installation.

## Build the connected app

Use Flutter 3.47.6 and Java 17. The connected entry point is **`lib/connected_main.dart`**. Plain `flutter run` / `lib/main.dart` is the old local UI-preview path, not the production-connected app.

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64 \
  -t lib/connected_main.dart \
  --dart-define=TIFFE_SUPABASE_URL=https://obbtxyjglgivcpusjpcx.supabase.co \
  --dart-define=TIFFE_SUPABASE_KEY=sb_publishable__5qR0bvVmwqKykgbQpAtRw_H0eIgl3_
```

For your own deployment, replace the two values with your project's public URL and publishable key. Obtain them from Supabase project settings/API configuration. Deploy and validate your schema, row-level security, staff roles and required RPCs before allowing real orders. Do not point experiments at the existing live deployment.

Package: `com.ambi.tiffe`. Release CI uses a permanent private signing identity and builds APK/AAB from the connected entry point. Configure your own signer for your distribution; never commit a keystore or signing password. A build artifact is not automatically a reviewed release or a completed Firebase distribution.

## Keep private values private

Never publish Supabase secret/service-role keys, database passwords, owner/customer passwords, auth refresh tokens, real customer delivery addresses or signing keys. Do not add them to source, dart-defines, Actions logs, issues or screenshots. Only the public URL and publishable app key above belong in a public client.
