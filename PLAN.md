# tribe-insta — integration plan

Instagram-shaped iOS client for the TribeEco decentralized social protocol.
Sister app to `tribe-twitter` (Twitter-shaped). Same hub, same envelope format,
same identity — different surface.

## Where we are today

- `tribe-insta/` is a SwiftUI scaffold with **mock data only** (Picsum stubs)
- 6 tabs in `Views/`: Feed, Search, Create, Reels, Activity, Profile
- Domain models in `Models/Models.swift`: `User`, `Story`, `Comment`, `Post`,
  `Reel`, `AppNotification` — all `UUID`-keyed, in-memory
- No `Sources/`, no `Project.yml`, no Xcode-aware `.gitignore`
- Not yet a git submodule of the TribeEco monorepo — it's an untracked dir

The protocol already does ~90% of what an Instagram-shaped client needs:

| IG concept | Protocol mapping |
|---|---|
| Post (1+ images) | `TWEET_ADD` with `embeds: ["media:<hash>", …]` |
| Comment | Reply tweet (`parent_hash` set) |
| Like | `REACTION_ADD type:1` |
| Save | `BOOKMARK_ADD` |
| Follow | ER server `/v1/follow` |
| Profile / Activity / Search | `/v1/user/:tid`, `/v1/notifications/:tid`, `/v1/search/*` |
| Story | **does not exist yet** — needs hub/SDK change |
| Reel (video) | **does not exist yet** — needs hub video support |
| Story view (seen-by) | **does not exist yet** — needs hub schema |
| Post location | not in `TWEET_ADD` body today |
| Reel audio title | not in `TWEET_ADD` body today |

---

## Phase 1 — hub-backed reads + minimal onboarding

**Goal:** Replace `MockData` with real hub fetches. App reads everything from
a running `tribe-hub`. No writes yet. Onboarding accepts an existing TID +
backup file from `tribe-twitter-app` or `tribe-twitter` — no new identity creation flow.

**Ports from `tribe-twitter`** (verbatim copies for now — extracted to a shared
package in Phase 4):

- `Sources/Crypto/` — all of it (`Blake3`, `AppKey`, `Keychain`, `BIP39`,
  `SolanaHD`, `NaClBox`, `DMKey`, `BackupFile`, `MessageSigner`)
- `Sources/API/HubClient.swift` + `Endpoints.swift`
- `Sources/API/ERClient.swift`
- `Sources/Models/{Tweet,User,Notification,Channel,Decoding}.swift`
- `Sources/State/AppState.swift` (trimmed — drop DM/tip/karma surfaces)
- `Sources/Config.swift`

**New code in tribe-insta:**

- `Services/TribeService.swift` — actor that wraps `HubClient` and maps
  protocol types to insta types:
  - `Tweet (embeds with image media) → Post` (carousel = N embeds)
  - `Tweet (reply) → Comment`
  - `User → User` (extend with `postsCount/followersCount/followingCount`
    from `/v1/followers/:tid` and `/v1/following/:tid`)
- `Views/Onboarding/OnboardingView.swift` — paste TID + paste backup file
  (BIP39 import). No seed-phrase entry UI in Phase 1 to keep scope down —
  user creates on tribe-twitter-app / tribe-twitter first, exports backup, imports here.
- Wire each tab to the service:
  - `FeedView` → `fetchFeedPage()` filtered to tweets with image embeds
  - `ProfileView` → `fetchUser(tid)` + `fetchTweets(tid)` filtered to images,
    rendered as the 3-col grid
  - `SearchView` → `searchUsers(q)` (search posts later)
  - `ActivityView` → `fetchNotifications(tid)`
  - `ReelsView` → empty state with "Reels coming soon" until Phase 3
  - `CreatePostView` → unchanged (writes land in Phase 2)

**Onboarding shortcut:** Settings sheet (gear icon on Profile) lets the user
paste hub URL + TID + backup file in one screen. Matches `tribe-twitter`'s
settings flow.

**Test path:**

1. `brew install tribe && tribe start` → hub on `:4000`
2. Create identity on `tribe-twitter-app` (`brew install tribe-twitter-app && tribe-twitter-app`)
3. Export backup file from tribe-twitter-app
4. Open tribe-insta, paste TID + import backup, set hub URL → see real feed

**Estimated size:** ~15 files, ~1,500 LOC (mostly verbatim ports from tribe-twitter).

---

## Phase 2 — writes

**Goal:** Like, save, comment, create-post, follow.

**Ports from tribe-twitter:**

- `Sources/API/Publish.swift` (the parts insta uses — drop DM groups, tasks,
  crowdfunds, polls, events for now)
- `Sources/API/InteractionReads.swift` — per-user "have I liked this?" helper
- `Sources/State/InteractionCache.swift`

**Wire-up:**

- `PostCardView.toggleLike()` → `api.likeTweet(hash:as:tid:)` / `unlikeTweet`
- bookmark button → `api.bookmark(hash:as:tid:add:)`
- new `CommentSheet` triggered by "View all N comments" → fetch replies via
  `fetchReplies(hash:)`, post new comment via
  `publishTweet(text:parentHash:)`
- `CreatePostView`:
  - `PhotosPicker` for 1-10 images
  - downscale to ≤5 MB JPEG per image (hub limit)
  - `api.uploadMedia(data:contentType:)` per image → collect hash list
  - `api.publishTweet(text:embeds:)` with `embeds = ["media:<h1>", …]`
  - optional caption, optional location string (carried in body — see
    Phase 3 hub change for indexer support)
- `ProfileView` follow button → `er.follow(tid:)` (read-only Phase 1 already
  shows follow state, Phase 2 makes it writable)

**Estimated size:** ~8 files, ~800 LOC.

---

## Phase 3 — Stories + Reels (touches 4 repos)

This is the chunky one. New protocol concepts, hub schema migrations, SDK
additions, web parity.

### tribe-hub changes

**Video upload support:**

- `/v1/upload`: accept `video/mp4`, `video/quicktime`
- raise size cap from 5 MB → 100 MB (reels are 20-80 MB typical)
- consider offloading large blobs to S3-compatible storage; keep
  `/v1/media/:hash` as the public-facing URL and have the hub stream from
  S3 on read

**Stories (24h ephemeral posts):**

- new envelope type `STORY_ADD = 33` (next free after the DM group
  ops 30-32, which PLAN.md's first draft missed)
  - body: `{ media_hash: string, caption?: string, music?: string }`
  - hub auto-stamps `expires_at = created_at + 24h`
- new envelope type `STORY_VIEW = 34`
  - body: `{ story_hash: string }`
  - hub upserts into `story_views(story_hash, viewer_tid, viewed_at)`
- new `stories` table: `(hash, author_tid, media_hash, caption, music,
  created_at, expires_at)`
- cron job: hourly `DELETE FROM stories WHERE expires_at < now()` (cascades
  story_views)
- new endpoints:
  - `GET /v1/stories` — active stories grouped by author, ordered by author's
    most-recent first; respects follow graph (only authors I follow + my own)
  - `GET /v1/stories/:tid` — that user's active stories
  - `GET /v1/stories/:hash/viewers` — author-only; who has seen this story

**Reels (video posts):**

- option A: new envelope type `REEL_ADD = 35`, separate from `TWEET_ADD`
- option B: reuse `TWEET_ADD` but add `body.post_kind: "reel"` discriminator
- recommendation: **option B** — minimizes envelope sprawl, indexer just
  partitions queries by `post_kind`
- new endpoint: `GET /v1/reels` — paginated, video-only feed; ordered by
  `created_at DESC` for v1 (engagement-ranked later)
- add `audio_title` and `location` to `TWEET_ADD` body (both already in the
  iOS UI mock)

**Schema migration files:**

- `tribe-hub/migrations/00NN_stories.sql`
- `tribe-hub/migrations/00NN_post_kind.sql` (adds `post_kind`, `audio_title`,
  `location` columns to `tweets`)
- `tribe-hub/migrations/00NN_video_upload.sql` (if media metadata table needs
  duration/dimensions for reels)

### tribe-sdk changes

- add `MessageType.STORY_ADD = 33`, `STORY_VIEW = 34`, optionally `REEL_ADD = 35`
- add helpers in `messages.ts`: `publishStory`, `viewStory`, `publishReel`
- add API helpers in `api.ts`: `fetchStories`, `fetchActiveStoriesByUser`,
  `fetchReels`, `fetchStoryViewers`
- the byte-for-byte canonical-form signing impl must stay aligned with the
  Swift `MessageSigner` port

### tribe-protocol changes

**None for v1.** Stories and reels are off-chain envelopes signed by the
app key — same as tweets/likes/bookmarks. The Solana programs stay untouched.

Future (Phase 5+, out of scope here): extend `tip-registry` so creators can
receive on-chain tips against a specific reel/story (would need
`target_kind` in the PDA seed).

### tribe-er-server changes

**Optional for Phase 3, recommended for Phase 5.** Today only `FOLLOW` goes
through ER. Reels engagement spikes hard — a viral reel can melt the hub
with synchronous `REACTION_ADD` writes. Move `REACTION` into ER batching.

### tribe-twitter-app (Next.js) changes

Web reference client needs to render what iOS posts, or content goes one-way:

- Stories tray on the home feed (24h ring around author avatar)
- `/reels` page with vertical-snap scroll
- Story viewer with progress bars + seen-by list (author-only)
- `useStories(tid)` + `useReels()` hooks on top of SDK additions

### tribe-insta consumes the new SDK

Once hub + SDK changes ship:

- `Sources/Models/Story.swift`, `Reel.swift`
- `TribeService.fetchStories()`, `publishStory()`, `viewStory()`,
  `fetchReels()`, `publishReel()`
- `StoriesBar` reads real stories (currently mock); tap fires `viewStory`
- `ReelsView` reads real reels with video playback (`AVPlayer` in
  `ReelCard`); currently shows `RemoteImage` for thumbnail only
- `CreatePostView` gets a Stories tab + a Reels tab next to Post

**Estimated size:** 4 repos, ~2,500 LOC across them. Multi-day.

---

## Phase 4 — extract `TribeCore` Swift package

By the time Phase 1+2 land, `tribe-twitter` and `tribe-insta` are both
maintaining a copy of `Sources/Crypto/`, `HubClient`, `MessageSigner`, etc.
First Blake3 bug fix proves that's untenable.

**Move:**

- Create `tribe-core-swift/` repo (or `tribe-twitter/TribeCore/` as a local SPM
  package consumed by both apps via path reference)
- Public API: `HubClient`, `ERClient`, `AppKey`, `DMKey`, `Blake3`,
  `MessageSigner`, all protocol models, `KeychainStore`
- Both `tribe-twitter` and `tribe-insta` declare it as a `Package.swift`
  dependency and delete their copies

**Why wait until Phase 4 and not do it first:** we'll only know the right
public-API shape after we've actually built two consumers. Doing it earlier
guesses at the surface and ends up wrong.

**Estimated size:** ~3 days of mostly mechanical refactoring + xcodegen
config + careful CI.

---

## Phase 0 (before any of the above) — make tribe-insta a real repo

Currently it's an untracked dir in the monorepo. Two-step gate:

1. **Create a GitHub repo** `chaalpritam/tribe-insta`. Initial commit:
   current `tribe-insta/` contents + a `.gitignore` for Xcode artifacts +
   `Project.yml` mirroring `tribe-twitter/Project.yml` shape + this `PLAN.md` +
   a stub `README.md`.
2. **Register as a submodule** in the TribeEco monorepo:
   - `.gitmodules` entry pointing at the new repo
   - `git submodule add` against HTTPS for unauthenticated clones; push
     remote uses `chaalpritam` SSH (matches the rest of the monorepo
     convention from CLAUDE.md)
   - update root `Readme.md` to list `tribe-insta` alongside `tribe-twitter`
   - update root `CLAUDE.md` architecture section

This is a precondition for any "let's commit" step — without it, work in
`tribe-insta/` is unversioned and any reorganization risks losing files.

---

## Cross-repo change summary

| Repo | Phase | Change |
|---|---|---|
| **tribe-insta** | 0 | Initial repo + submodule registration |
| **tribe-insta** | 1 | Port crypto/API/models, read-only wire-up |
| **tribe-insta** | 2 | Port Publish.swift, wire writes |
| **tribe-insta** | 3 | Stories + Reels surfaces |
| **tribe-hub** | 3 | Video upload, STORY_ADD/STORY_VIEW envelopes, stories + story_views tables, /v1/stories + /v1/reels endpoints, post_kind/location/audio_title columns |
| **tribe-sdk** | 3 | New MessageType entries, helpers for stories/reels |
| **tribe-twitter-app** | 3 | Stories tray, /reels page, viewer with seen-by |
| **tribe-protocol** | — | No changes for v1 (off-chain envelopes only) |
| **tribe-er-server** | 5 (later) | Optional: batch REACTION through ER for reels engagement |
| **tribe-twitter + tribe-insta** | 4 | Extract `TribeCore` Swift package |
| **homebrew-tap** | optional | `tribe-insta` formula (low priority — TestFlight is the real distribution path) |
| **TribeEco** (root) | 0 | `.gitmodules` + Readme + CLAUDE.md updates |

---

## Open questions

1. **Stories envelope vs TTL on TWEET_ADD?** Cleaner to have a distinct
   `STORY_ADD` (matches how the hub already has dedicated kinds for polls,
   events, tasks). Default to that.

2. **Reels: separate envelope or `post_kind` on TWEET_ADD?** Recommend
   `post_kind` — fewer envelope kinds, same indexer code path, reuses
   replies/likes/bookmarks for free.

3. **Video storage strategy?** Keeping 100 MB videos in the hub's filesystem
   is fine for one-laptop demos; production needs S3 + signed URLs. Out of
   scope for the first cut — start with hub-local storage and add the S3
   path when the demo actually breaks.

4. **Onboarding parity with tribe-twitter?** tribe-twitter supports seed-phrase
   import, backup-file import, QR pair-from-desktop, and create-new-identity.
   tribe-insta Phase 1 only ships backup-file import — others come in
   Phase 2 or later. Acceptable tradeoff?

5. **Bottom-nav style?** tribe-twitter uses a black rounded-pill custom nav
   from `tribeapp.wtf`. tribe-insta currently uses stock SwiftUI `TabView`.
   Recommend keeping the stock TabView for tribe-insta — it's the IG-native
   look, and the visual differentiation from tribe-twitter is the whole point.
