# tribe-insta

Native SwiftUI iOS client for the [TribeEco](https://github.com/chaalpritam/TribeEco) decentralized social protocol — Instagram-shaped surface (photo grid, stories, reels, profile-first navigation) sitting on the same hub + envelope format as the Twitter-shaped [`tribe-ios`](https://github.com/chaalpritam/tribe-ios) client.

## Status

**Scaffolding stage.** UI shell is complete and runs against mock Picsum data. Protocol integration is being landed in phases — see [`PLAN.md`](PLAN.md) for the roadmap and cross-repo dependency table.

| Phase | Scope | State |
|---|---|---|
| 0 | Repo + submodule + tooling | in progress |
| 1 | Hub-backed reads (feed, profile, activity, search) + paste-backup onboarding | pending |
| 2 | Writes: like, save, comment, create-post, follow | pending |
| 3 | Stories + Reels (requires tribe-hub + tribe-sdk + tribe-app changes) | pending |
| 4 | Extract `TribeCore` Swift package shared with tribe-ios | pending |

## What works today

iPhone-only, portrait-only, mock data only:

- **Feed** — stories bar + photo cards with carousel, double-tap to like, save toggle
- **Search** — Instagram-style explore grid with tall video cells, user search filter
- **Create** — post composer scaffold (no real upload yet)
- **Reels** — vertical-snap pager with action rail
- **Activity** — grouped notifications (Today / This week / Earlier)
- **Profile** — grid + reels + tagged tabs with highlights row

All data comes from `tribe-insta/Mock/MockData.swift`. The protocol wire-up replaces this in Phase 1.

## Requirements

- Xcode 16+ (iOS 26 SDK)
- Optional: [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — only needed if you edit `Project.yml`

Phase 1 adds:

- A running `tribe-hub` (defaults to `http://127.0.0.1:4000` — see [`tribe-hub`](https://github.com/chaalpritam/tribe-hub))
- An identity created via `tribe-app` and exported to a backup file

## Running

```sh
cd tribe-insta
open tribe-insta.xcodeproj
# In Xcode: pick an iPhone simulator and ⌘R
```

The `.xcodeproj` is committed so a fresh clone opens directly in Xcode without needing xcodegen installed. When you add Swift files, Xcode picks them up via the source group's directory reference. When you change build settings, edit `Project.yml` and run `xcodegen generate`.

## Layout

```
tribe-insta/                          Xcode app target sources
  tribe_instaApp.swift                @main entry
  ContentView.swift                   wraps RootView
  Assets.xcassets/                    AccentColor + AppIcon stubs
  Mock/
    MockData.swift                    Picsum-backed sample feed (Phase 1 deletes this)
  Models/
    Models.swift                      User, Story, Comment, Post, Reel, AppNotification
  Views/
    Root/        RootView (TabView shell)
    Feed/        FeedView + PostCardView + StoriesBar
    Search/      SearchView (explore grid + user results)
    Create/      CreatePostView
    Reels/       ReelsView (vertical pager)
    Activity/    ActivityView + NotificationRow
    Profile/     ProfileView (header + highlights + grid)
    Components/  RemoteImage, AvatarView, StoryAvatarView, Formatters
```

Phase 1 adds `Sources/Crypto/`, `Sources/API/`, `Sources/State/`, `Sources/Services/`, ported from tribe-ios.

## Where this fits

`tribe-insta` is a submodule of the [TribeEco](https://github.com/chaalpritam/TribeEco) monorepo. Clone the monorepo with `--recurse-submodules` to get everything.

| Repo | Role |
|---|---|
| [tribe-protocol](https://github.com/chaalpritam/tribe-protocol) | Solana programs — identity, app keys, social graph, registries |
| [tribe-sdk](https://github.com/chaalpritam/tribe-sdk) | TypeScript SDK shared by web clients |
| [tribe-hub](https://github.com/chaalpritam/tribe-hub) | Decentralized hub — message storage, indexing, gossip |
| [tribe-er-server](https://github.com/chaalpritam/tribe-er-server) | Ephemeral Rollup sequencer — instant follows |
| [tribe-app](https://github.com/chaalpritam/tribe-demo-app) | Next.js reference client (Twitter-shaped) |
| [tribe-ios](https://github.com/chaalpritam/tribe-ios) | Native iOS client (Twitter-shaped) |
| **tribe-insta** | Native iOS client (Instagram-shaped) — this repo |

## What's next

See [`PLAN.md`](PLAN.md). The next concrete step is Phase 1: port the crypto + HubClient layer from tribe-ios, replace `MockData` with a `TribeService` that fetches `/v1/feed` filtered to tweets with image embeds, and wire each tab to the real hub.
