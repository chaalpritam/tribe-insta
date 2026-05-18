import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Presents the system camera for a photo or video capture.
struct MediaCapturePicker: UIViewControllerRepresentable {
    enum CaptureKind {
        case photo
        case video
    }

    var kind: CaptureKind
    var onPhoto: (UIImage) -> Void
    var onVideo: (URL) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        switch kind {
        case .photo:
            picker.mediaTypes = [UTType.image.identifier]
        case .video:
            picker.mediaTypes = [UTType.movie.identifier]
            picker.videoQuality = .typeHigh
            picker.videoMaximumDuration = 90
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: MediaCapturePicker

        init(_ parent: MediaCapturePicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onPhoto(image)
                return
            }
            if let url = info[.mediaURL] as? URL {
                parent.onVideo(url)
                return
            }
            parent.onCancel()
        }
    }
}
