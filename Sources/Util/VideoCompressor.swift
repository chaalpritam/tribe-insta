import AVFoundation
import Foundation

/// Downscale exported video for hub upload (target ≤ ~720p, smaller file).
enum VideoCompressor {
    enum CompressError: LocalizedError {
        case exportFailed
        case noOutput

        var errorDescription: String? {
            switch self {
            case .exportFailed: return "Could not compress video."
            case .noOutput: return "Compressed video file missing."
            }
        }
    }

    static func compressForUpload(sourceURL: URL) async throws -> Data {
        let asset = AVURLAsset(url: sourceURL)
        guard let session = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPreset1280x720
        ) else {
            throw CompressError.exportFailed
        }
        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("reel-compressed-\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: out)
        session.outputURL = out
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true

        await session.export()
        guard session.status == .completed else {
            throw CompressError.exportFailed
        }
        defer { try? FileManager.default.removeItem(at: out) }
        let data = try Data(contentsOf: out)
        guard !data.isEmpty else { throw CompressError.noOutput }
        return data
    }
}
