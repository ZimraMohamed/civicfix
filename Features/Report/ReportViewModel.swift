import SwiftUI

@MainActor @Observable
final class ReportViewModel {
    static let maxDetailsLength = 500

    var image: UIImage?
    var details = ""
    var hashtags: [String] = []
    var tagInput = ""
    var shareLocation = true

    private(set) var isSubmitting = false
    var errorMessage: String?
    var didSubmit = false

    let location = LocationProvider()
    private let service: ReportServicing

    init(service: ReportServicing = ReportServiceFactory.make()) {
        self.service = service
    }

    /// Suggestions first, then any custom tags the user added.
    var visibleTags: [String] {
        HashTag.suggestions + hashtags.filter { !HashTag.suggestions.contains($0) }
    }

    func toggle(_ tag: String) {
        if let index = hashtags.firstIndex(of: tag) {
            hashtags.remove(at: index)
        } else if hashtags.count < HashTag.maxCount {
            hashtags.append(tag)
        } else {
            errorMessage = "You can add up to \(HashTag.maxCount) hashtags."
        }
    }

    /// Turns "#brokenbench, #urgent" typed by the user into tags.
    func addTagsFromInput() {
        for tag in HashTag.parse(tagInput) where !hashtags.contains(tag) {
            guard hashtags.count < HashTag.maxCount else {
                errorMessage = "You can add up to \(HashTag.maxCount) hashtags."
                break
            }
            hashtags.append(tag)
        }
        tagInput = ""
    }

    func submit() async {
        errorMessage = nil
        addTagsFromInput()   // include a tag that was typed but not yet added

        guard let image, let data = image.jpegData(under: 600_000) else {
            errorMessage = "Take a photo of the issue first."
            return
        }
        if shareLocation && location.location == nil {
            errorMessage = "Waiting for your location. Turn off sharing to submit without it."
            location.request()
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await service.submit(ReportDraft(
                details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                hashtags: hashtags,
                imageData: data,
                location: shareLocation ? location.location : nil
            ))
            reset()
            didSubmit = true
        } catch {
            var message = (error as? LocalizedError)?.errorDescription
                ?? ReportError.unknown.errorDescription ?? ""
            #if DEBUG
            let ns = error as NSError
            message += "\n[\(ns.domain) \(ns.code)]"
            #endif
            errorMessage = message
        }
    }

    private func reset() {
        image = nil
        details = ""
        hashtags = []
        tagInput = ""
    }
}
