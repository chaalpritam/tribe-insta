# tribe-insta

Native SwiftUI iOS client for the [TribeEco](https://github.com/chaalpritam/TribeEco) decentralized social protocol — Instagram-shaped surface (photo grid, stories, reels, profile-first navigation) on the same hub + envelope format as [`tribe-twitter`](https://github.com/chaalpritam/tribe-twitter).

## Status

**Hub-backed beta.** Connect with the same flows as tribe-twitter-app (QR, seed phrase, create/import app key, backup restore), then read and write against a running `tribe-hub` + ER sequencer.

| Area | Status |
|------|--------|
| Onboarding | ConnectFlow — hub URL, QR, seed, create/import, backup restore |
| Feed | Photo posts, stories bar, like/save/comment, pagination, post detail |
| Create | Post / story / reel — library + in-app camera, video compression |
| Reels | Engagement-ranked feed, comments, share, prefetch |
| Search | Explore grid, user search, hashtag/post search |
| Profiles | Self + other users, follow lists, grid/reels tabs, edit profile |
| Activity | Notifications, follow-back via tribe-twitter-app explainer |
| DMs | Inbox, decrypt, compose new thread |
| Settings | Hub/ER URLs, export backup, saved posts, block/mute (device-local) |

**Tier 3 (app):** deep links (`tribeinsta://`), image cache, content report sheet, legal links, backup reminder, TestFlight pipeline — see [`TESTFLIGHT.md`](TESTFLIGHT.md).

**Not yet (needs protocol / infra):** tagged-post index, hub-wide block/mute, push notifications, S3 video CDN, Instagram Live, TribeCore API/Models extraction.

See [`PLAN.md`](PLAN.md) for cross-repo history.

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
2. Create identity on `tribe-twitter-app` (or in-app create/import)
3. Optional: `tribe-twitter-app link http://<lan-ip>:4000` on desktop
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

## Related Repos

| Repo | Description |
|------|-------------|
| [tribe-protocol](../tribe-protocol) | Solana programs (Anchor) — 12 programs: tid-registry, app-key-registry, username-registry, social-graph w/ ER delegation, hub-registry, tip-registry, crowdfund-registry, task-registry, channel-registry, karma-registry, poll-registry, event-registry |
| [tribe-sdk](../tribe-sdk) | TypeScript SDK — DirectSolana and EphemeralRollup providers; clients for identity, tweets, DMs, profiles, channels, bookmarks, polls, events, tasks, crowdfunds, tips, search |
| [tribe-hub](../tribe-hub) | Decentralized hub — signed-message storage + Solana indexer + gossip peer sync; REST + WebSocket APIs |
| [tribe-er-server](../tribe-er-server) | Ephemeral Rollup sequencer — instant follows, batched L1 settlement every 10s |
| [tribe-twitter-app](../tribe-twitter-app) | Next.js frontend — protocol-first reference client with multi-node failover |
| [tribeapp.wtf](../tribeapp.wtf) | Consumer-facing web app + landing page at tribeapp.wtf — hyperlocal social built entirely on the protocol |
| [tribe-twitter](../tribe-twitter) | Native SwiftUI iOS client (Twitter-shaped) — full read/write against hub + ER, NaCl-box DMs, BLAKE3 + ed25519 signing via Apple CryptoKit |
| [tribe-insta](../tribe-insta) | Native SwiftUI iOS client (Instagram-shaped) — photo grid, stories, reels; same hub + envelope format as tribe-twitter. Scaffolding stage — see `tribe-insta/PLAN.md` |
| [tribe-core-swift](../tribe-core-swift) | Shared Swift package consumed by tribe-twitter + tribe-insta — crypto (BLAKE3, NaCl box, ed25519 signing, BIP39, SolanaHD), backup file format, envelope signer. See `tribe-core-swift/MIGRATION.md` |
| [homebrew-tap](../homebrew-tap) | Homebrew formulas: `brew install tribe` (hub + ER) and `brew install tribe-twitter-app` (demo UI) |
