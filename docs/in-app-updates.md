# Tiffe in-app updates: where the APK is downloaded from

## Why
On some networks (seen on an Indian ISP, Oct 2026) GitHub's release file host
(`github.com/.../releases/download/...` -> `release-assets.githubusercontent.com`)
answers with headers and then sends no data. The update dialog showed
"Downloading Tiffe 1.0.57... 0.0 / 39.7 MB" forever. The update feed itself
loads fine, because it comes from `raw.githubusercontent.com`.

## How it works now
- Every release APK is also copied to the `apk-mirror` branch of this repo by
  `.github/workflows/apk-mirror.yml`, served at
  `https://raw.githubusercontent.com/frances09f-lgtm/tiffe/apk-mirror/<customer|staff>/<version>/<file>.apk`
  and via GitHub Pages at `https://frances09f-lgtm.github.io/tiffe/<customer|staff>/<version>/<file>.apk`.
  The branch is one force-pushed commit holding the two newest versions per app.
- The same workflow writes `apk-mirror/version.json` (the "mirror feed") with
  `version`, `notes`, `apk` (raw mirror), `mirrors` (Pages, GitHub release),
  `size`, `sha256`.
- Customer 1.0.58+ and Staff 1.0.11+ read BOTH feeds (child-safety-updates and
  the mirror feed), take the newest version, and try each download address in
  turn: raw mirror, Pages, then GitHub release. A download that moves less than
  16 KB in 15 s counts as stalled and the next address is tried. When all fail,
  the dialog shows each address's problem and a Retry button.
- The customer release workflow (`customer-vNN.yml`) and the Staff workflow
  (`build-staff-apk.yml`) call `apk-mirror.yml` after publishing, using only
  this repo's own token. No extra secret is needed for the mirror.

## The one manual step (until a feed token exists)
Older installed apps (customer <= 1.0.57, Staff <= 1.0.10) only read
`frances09f-lgtm/child-safety-updates/main/version.json` and only its `apk`
field. CI cannot write that repo (no `UPDATES_FEED_TOKEN` secret here). After
each release, edit that file by hand (or add the secret):

```json
"tiffe": {
  "version": "1.0.NN",
  "notes": "...",
  "apk": "https://raw.githubusercontent.com/frances09f-lgtm/tiffe/apk-mirror/customer/1.0.NN/Tiffe.apk",
  "mirrors": ["https://frances09f-lgtm.github.io/tiffe/customer/1.0.NN/Tiffe.apk",
              "https://github.com/frances09f-lgtm/tiffe/releases/download/vNN/Tiffe.apk"],
  "size": <bytes>
}
```
(`tiffe_staff` the same with `staff/1.0.NN/Tiffe-Staff.apk` and tag `staff-vNN`.)
Always point `apk` at the raw mirror, never at the GitHub release, and check
the mirror URL downloads the same bytes first (the mirror workflow's last step
checks the sha256 anonymously). If `UPDATES_FEED_TOKEN` (a fine-grained token
with contents: write on child-safety-updates) is added to this repo, the Staff
workflow's feed job does this automatically.

## Manual mirror of an existing release
Actions -> "APK mirror" -> Run workflow on main with e.g.
`tag=v57, feed_key=tiffe, version=1.0.57, asset=Tiffe.apk`.
