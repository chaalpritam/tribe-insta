# tribe-insta

Native SwiftUI iOS client for the [TribeEco](https://github.com/chaalpritam/TribeEco) decentralized social protocol — Instagram-shaped surface (photo grid, stories, reels, profile-first navigation) on the same hub + envelope format as [`tribe-ios`](https://github.com/chaalpritam/tribe-ios).

## Status

**Hub-backed beta.** Connect with the same flows as tribe-app (QR, seed phrase, create/import app key, backup restore), then read and write against a running `tribe-hub` + ER sequencer.

| Area | Status |
|------|--------|
| Onboarding | ConnectFlow — hub URL, QR, seed, create/import, backup restore |
| Feed | Photo posts, stories bar, like/save/comment, pagination, post detail |
| Create | Post / story / reel — library + in-app camera, video compression |
| Reels | Engagement-ranked feed, comments, share, prefetch |
| Search | Explore grid, user search, hashtag/post search |
| Profiles | Self + other users, follow lists, grid/reels tabs, edit profile |
| Activity | Notifications, follow-back via tribe-app explainer |
| DMs | Inbox, decrypt, compose new thread |
| Settings | Hub/ER URLs, export backup, saved posts, block/mute (device-local) |

**Not yet (needs protocol / infra):** tagged-post index, hub-wide block/mute, ER follow writes from mobile (custody key), push notifications, Instagram Live.

See [`PLAN.md`](PLAN.md) for cross-repo stories/reels history and `TribeCore` extraction.

## Requirements

- Xcode 16+ (iOS 26 SDK)
- [xcodegen](https://github.com/yonaskolb/XcodeGen) — run after editing `Project.yml`
- Stack: `brew install tribe && tribe start` (hub `:4000`, ER `:3003`)

## Running

```sh
cd tribe-insta
xcodegen generate   # if you changed Project.yml or added Swift files
open tribe-insta.xcodeproj
# Pick an iPhone simulator and ⌘R
```

On a physical device, set the hub URL to your Mac's LAN IP (`tribe share`) in onboarding or Settings.

## Tester quick path

1. `tribe start` on a Mac
2. Create identity on `tribe-app` (or in-app create/import)
3. Optional: `tribe-app link http://<lan-ip>:4000` on desktop
4. Open tribe-insta → configure hub → sign in → post a photo

## Layout

```
tribe-insta/          SwiftUI views (tabs, onboarding, components)
Sources/              Protocol layer (Crypto, API, TribeService, AppState)
  Crypto/             Blake3, AppKey, BackupFile, NaCl box, BIP39, …
  API/                HubClient, ERClient, Publish, Endpoints
  Services/           TribeService (hub → IG view models)
  State/              AppState, InteractionCache, UserRestrictionsStore
```

`Mock/MockData.swift` remains for SwiftUI previews only; the app does not use it at runtime when signed in.

## Submodule

Part of the [TribeEco](https://github.com/chaalpritam/TribeEco) monorepo. Clone with `--recurse-submodules`.
