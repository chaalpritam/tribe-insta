import SwiftUI

/// Reels are a Phase 3 surface. The protocol doesn't have a video
/// envelope yet (see PLAN.md → tribe-hub additions: video upload
/// MIME types + size cap + optional REEL_ADD discriminator). Until
/// those land, this tab shows a placeholder so users aren't taken
/// to a broken pager.
struct ReelsView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "play.square.stack")
                    .font(.system(size: 56))
                    .foregroundStyle(.white.opacity(0.8))
                Text("Reels coming soon")
                    .font(.title3).fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text("Video posts need a hub schema change to land. Track progress in PLAN.md → Phase 3.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .overlay(alignment: .top) {
            HStack {
                Text("Reels")
                    .font(.title3).fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
}

#Preview {
    ReelsView()
}
