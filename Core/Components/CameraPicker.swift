import SwiftUI
import UIKit

/// Opens the system camera and hands back the captured photo.
/// Requires `NSCameraUsageDescription` in Info.plist.
struct CameraPicker: UIViewControllerRepresentable {
    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onCapture(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

extension UIImage {
    /// Shrinks until the JPEG fits in `maxBytes`, so it can live inside a Firestore document.
    func jpegData(under maxBytes: Int) -> Data? {
        for dimension: CGFloat in [1024, 800, 640, 480] {
            for quality: CGFloat in [0.7, 0.5, 0.35] {
                if let data = resizedJPEG(maxDimension: dimension, quality: quality), data.count <= maxBytes {
                    return data
                }
            }
        }
        return nil
    }

    /// Scales the longest side down to `maxDimension` and encodes as JPEG, so uploads stay small.
    /// Drawing also bakes in the camera's orientation.
    func resizedJPEG(maxDimension: CGFloat = 1600, quality: CGFloat = 0.8) -> Data? {
        let longest = max(size.width, size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxDimension / longest)
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format)
            .jpegData(withCompressionQuality: quality) { _ in
                draw(in: CGRect(origin: .zero, size: target))
            }
    }
}
