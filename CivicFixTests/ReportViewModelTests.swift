import Testing
import UIKit
@testable import CivicFix

@MainActor
struct ReportViewModelTests {
    private func make(_ service: StubReportService = StubReportService()) -> (ReportViewModel, StubReportService) {
        (ReportViewModel(service: service), service)
    }

    // Tags

    @Test func toggleAddsThenRemoves() {
        let (vm, _) = make()
        vm.toggle("pothole")
        #expect(vm.hashtags == ["pothole"])
        vm.toggle("pothole")
        #expect(vm.hashtags.isEmpty)
    }

    @Test func toggleStopsAtMaxCount() {
        let (vm, _) = make()
        vm.hashtags = (0..<HashTag.maxCount).map { "tag\($0)" }
        vm.toggle("extra")
        #expect(vm.hashtags.count == HashTag.maxCount)
        #expect(!vm.hashtags.contains("extra"))
        #expect(vm.errorMessage == "You can add up to \(HashTag.maxCount) hashtags.")
    }

    @Test func addTagsFromInputParsesAndClearsInput() {
        let (vm, _) = make()
        vm.tagInput = "#brokenbench, #Urgent"
        vm.addTagsFromInput()
        #expect(vm.hashtags == ["brokenbench", "urgent"])
        #expect(vm.tagInput.isEmpty)
    }

    @Test func addTagsFromInputSkipsDuplicates() {
        let (vm, _) = make()
        vm.hashtags = ["urgent"]
        vm.tagInput = "#urgent #pothole"
        vm.addTagsFromInput()
        #expect(vm.hashtags == ["urgent", "pothole"])
    }

    @Test func addTagsFromInputRespectsMaxCount() {
        let (vm, _) = make()
        vm.hashtags = (0..<(HashTag.maxCount - 1)).map { "tag\($0)" }
        vm.tagInput = "x y"
        vm.addTagsFromInput()
        #expect(vm.hashtags.count == HashTag.maxCount)
        #expect(vm.hashtags.contains("x"))
        #expect(!vm.hashtags.contains("y"))
        #expect(vm.errorMessage != nil)
    }

    @Test func visibleTagsListSuggestionsThenCustomTags() {
        let (vm, _) = make()
        vm.hashtags = ["pothole", "custom"]
        #expect(vm.visibleTags == HashTag.suggestions + ["custom"])
    }

    //Submit

    @Test func submitWithoutPhotoShowsError() async {
        let (vm, service) = make()
        await vm.submit()
        #expect(vm.errorMessage == "Take a photo of the issue first.")
        #expect(!vm.didSubmit)
        #expect(service.submitted.isEmpty)
    }

    @Test func successfulSubmitSendsDraftAndResetsForm() async throws {
        let (vm, service) = make()
        vm.image = makeTestImage()
        vm.details = "  Big pothole  \n"
        vm.hashtags = ["pothole"]
        vm.shareLocation = false

        await vm.submit()

        #expect(vm.didSubmit)
        #expect(vm.errorMessage == nil)
        #expect(!vm.isSubmitting)
        let draft = try #require(service.submitted.first)
        #expect(draft.details == "Big pothole")
        #expect(draft.hashtags == ["pothole"])
        #expect(draft.location == nil)
        #expect(!draft.imageData.isEmpty)
        // Form is cleared for the next report.
        #expect(vm.image == nil)
        #expect(vm.details.isEmpty)
        #expect(vm.hashtags.isEmpty)
        #expect(vm.tagInput.isEmpty)
    }

    @Test func submitIncludesTagThatWasTypedButNotAdded() async throws {
        let (vm, service) = make()
        vm.image = makeTestImage()
        vm.shareLocation = false
        vm.tagInput = "#streetlight"
        await vm.submit()
        #expect(service.submitted.first?.hashtags == ["streetlight"])
    }

    @Test func submitAttachesLocationWhenSharing() async throws {
        let (vm, service) = make()
        let place = ReportLocation(latitude: 5.9667, longitude: 80.6, accuracy: 12)
        vm.location.setManual(place)
        vm.image = makeTestImage()
        vm.shareLocation = true
        await vm.submit()
        #expect(service.submitted.first?.location == place)
    }

    @Test func submitOmitsLocationWhenSharingIsOff() async throws {
        let (vm, service) = make()
        vm.location.setManual(ReportLocation(latitude: 1, longitude: 2, accuracy: 3))
        vm.image = makeTestImage()
        vm.shareLocation = false
        await vm.submit()
        #expect(service.submitted.first?.location == nil)
    }

    @Test func failedSubmitKeepsFormAndShowsError() async {
        let service = StubReportService()
        service.submitError = ReportError.permissionDenied
        let (vm, _) = make(service)
        vm.image = makeTestImage()
        vm.details = "Keep me"
        vm.shareLocation = false

        await vm.submit()

        #expect(!vm.didSubmit)
        #expect(!vm.isSubmitting)
        // In Debug builds the message also carries "[domain code]", so compare the prefix.
        let expected = ReportError.permissionDenied.errorDescription ?? ""
        #expect(vm.errorMessage?.hasPrefix(expected) == true)
        #expect(vm.image != nil)
        #expect(vm.details == "Keep me")
    }

    @Test func unknownErrorFallsBackToGenericMessage() async {
        let service = StubReportService()
        service.submitError = TestError.boom
        let (vm, _) = make(service)
        vm.image = makeTestImage()
        vm.shareLocation = false
        await vm.submit()
        let expected = ReportError.unknown.errorDescription ?? ""
        #expect(vm.errorMessage?.hasPrefix(expected) == true)
    }

    @Test func errorIsClearedOnNewSubmit() async {
        let (vm, _) = make()
        await vm.submit()                       // no photo -> error
        #expect(vm.errorMessage != nil)
        vm.image = makeTestImage()
        vm.shareLocation = false
        await vm.submit()
        #expect(vm.errorMessage == nil)
        #expect(vm.didSubmit)
    }
}

// UIImage JPEG helpers

@MainActor
struct ImageJPEGTests {
    @Test func smallImageFitsUnderLimit() throws {
        let data = try #require(makeTestImage().jpegData(under: 600_000))
        #expect(!data.isEmpty)
        #expect(data.count <= 600_000)
    }

    @Test func impossibleLimitReturnsNil() {
        #expect(makeTestImage().jpegData(under: 1) == nil)
    }

    @Test func resizeScalesLongestSideDown() throws {
        let data = try #require(makeTestImage(width: 2000, height: 1000).resizedJPEG(maxDimension: 500))
        let decoded = try #require(UIImage(data: data))
        #expect(abs(decoded.size.width - 500) <= 1)
        #expect(abs(decoded.size.height - 250) <= 1)
    }

    @Test func resizeNeverUpscales() throws {
        let data = try #require(makeTestImage(width: 100, height: 50).resizedJPEG(maxDimension: 1600))
        let decoded = try #require(UIImage(data: data))
        #expect(abs(decoded.size.width - 100) <= 1)
    }

    @Test func emptyImageReturnsNil() {
        #expect(UIImage().resizedJPEG() == nil)
    }
}
