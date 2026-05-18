# tribe-insta — TestFlight

## Prerequisites

- Apple Developer account with App Store Connect access
- Xcode 16+ on macOS
- `DEVELOPMENT_TEAM` — your 10-character Team ID (set in `Project.yml` or pass on the command line)
- App Store Connect app record for bundle id `xyz.tribeprotocol.apps.tribe-insta`

## One-time setup

1. Open `Project.yml` and set `DEVELOPMENT_TEAM: "XXXXXXXXXX"` (or export when building).
2. In [App Store Connect](https://appstoreconnect.apple.com), create the iOS app if it does not exist.
3. Fill in Privacy Nutrition Labels (UGC: photos, messages, user-generated content).
4. Add a public **Privacy Policy URL** (can point at the TribeEco README until a dedicated page exists).

## Build and upload

```sh
cd tribe-insta
make bump-build          # optional: increment CFBundleVersion
DEVELOPMENT_TEAM=XXXXXXXXXX make archive
```

Upload with an App Store Connect API key:

```sh
export APP_STORE_CONNECT_API_KEY=...
export APP_STORE_CONNECT_ISSUER_ID=...
make testflight-upload
```

Or upload the IPA from `build/export/` with Transporter.

## Tester instructions

Share with external testers:

1. Install **TestFlight** on iPhone.
2. On a Mac on the same Wi‑Fi: `brew install tribe && tribe start`.
3. Run `tribe share` and note the **hub URL** (use LAN IP, not `127.0.0.1`).
4. In tribe-insta: onboarding → hub URL → sign in (QR from tribe-app or backup import).
5. Optional: point at a **seed hub** — `tribe seed set ws://<seed-host>/gossip` on the Mac, then use that hub’s HTTPS URL if exposed.

### Deep links

- `tribeinsta://post/<hash>` — open a post
- `tribeinsta://profile/<tid>` — open a profile
- Shared hub links `https://<hub>/v1/tweet/<hash>` also open in-app when tapped

## Public seed node (optional)

For testers off your LAN, deploy a seed hub:

```sh
# On a VPS with DNS pointing at the box
DOMAIN=seed.example.com bash deploy/seed/setup-seed.sh
```

Then on each tester’s home Mac (or your seed): hubs peer via `PEERS` / `tribe peer add`.

## Not in this build

- Push notifications (badges poll every 60s while the app is open)
- Follow/unfollow writes (use tribe-app + custody key)
- Instagram Live
