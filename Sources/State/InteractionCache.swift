import Foundation
import SwiftUI

/// Session-scoped cache of "have I liked / bookmarked this post" state.
/// Hangs off AppState so every PostCardView can ask without refetching,
/// and so write paths (like, unlike, bookmark, unbookmark) can keep the
/// cache consistent without round-tripping the hub for the answer they
/// just produced.
///
/// Loaded lazily the first time a card tries to render with the user's
/// TID known. Re-loadable via `refresh()` after sign-in or pull-to-refresh.
///
/// Trimmed from tribe-twitter: no retweet set (IG-shaped client doesn't
/// retweet).
@MainActor
final class InteractionCache: ObservableObject {
    @Published private(set) var likedHashes: Set<String> = []
    @Published private(set) var bookmarkedHashes: Set<String> = []
    @Published private(set) var loaded = false

    /// Set by AppState immediately after init. Weak so the cache
    /// doesn't outlive the app state in tests.
    private weak var app: AppState?

    init() {}

    func attach(to app: AppState) {
        self.app = app
    }

    func contains(liked hash: String) -> Bool { likedHashes.contains(hash) }
    func contains(bookmarked hash: String) -> Bool { bookmarkedHashes.contains(hash) }

    func setLiked(_ liked: Bool, hash: String) {
        if liked { likedHashes.insert(hash) } else { likedHashes.remove(hash) }
    }

    func setBookmarked(_ bookmarked: Bool, hash: String) {
        if bookmarked { bookmarkedHashes.insert(hash) } else { bookmarkedHashes.remove(hash) }
    }

    /// Pulls the user's like + bookmark sets from the hub. Idempotent
    /// — safe to call repeatedly on view appear; bails fast when the
    /// user has no TID and replaces the in-memory sets atomically on
    /// success.
    func ensureLoaded() async {
        guard !loaded else { return }
        await refresh()
    }

    func refresh() async {
        guard let app, let tid = app.myTID else {
            likedHashes = []
            bookmarkedHashes = []
            loaded = false
            return
        }
        async let likesTask = (try? await app.api.fetchMyReactions(tid: tid, type: "1")) ?? []
        async let bookmarksTask = (try? await app.api.fetchMyBookmarks(tid: tid)) ?? []
        let (likes, bookmarks) = await (likesTask, bookmarksTask)
        self.likedHashes = Set(likes.map(\.targetHash))
        self.bookmarkedHashes = Set(bookmarks.map(\.targetHash))
        self.loaded = true
    }

    /// Drop everything. Called from AppState.signOut.
    func clear() {
        likedHashes = []
        bookmarkedHashes = []
        loaded = false
    }
}
