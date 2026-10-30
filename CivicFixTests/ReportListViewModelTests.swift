import Testing
import Foundation
@testable import CivicFix

// MARK: - Admin reports

@MainActor
struct AdminReportsViewModelTests {
    private func sample() -> [Report] {
        [
            makeReport(id: "1", status: .open, userName: "Ahsan Ilyas",
                       details: "Large pothole near the bus stop", hashtags: ["pothole", "urgent"]),
            makeReport(id: "2", status: .inProgress, userName: "Nimal Perera",
                       details: "Streetlight is out", hashtags: ["streetlight"]),
            makeReport(id: "3", status: .resolved, userName: "Sara Khan",
                       details: "", hashtags: ["garbage"])
        ]
    }

    private func loaded(_ service: StubReportService = StubReportService()) async -> (AdminReportsViewModel, StubReportService) {
        service.reports = sample()
        let vm = AdminReportsViewModel(service: service)
        await vm.load()
        return (vm, service)
    }

    @Test func filterOptionsCoverAllAndEveryStatus() {
        #expect(AdminReportsViewModel.Filter.options.count == 1 + ReportStatus.allCases.count)
        #expect(AdminReportsViewModel.Filter.all.title == "All")
        #expect(AdminReportsViewModel.Filter.status(.inProgress).title == "In progress")
    }

    @Test func loadPopulatesReports() async {
        let (vm, _) = await loaded()
        #expect(vm.reports.count == 3)
        #expect(vm.hasLoaded)
        #expect(!vm.isLoading)
        #expect(vm.errorMessage == nil)
    }

    @Test func loadFailureShowsServiceMessage() async {
        let service = StubReportService()
        service.loadError = ReportError.permissionDenied
        let vm = AdminReportsViewModel(service: service)
        await vm.load()
        #expect(vm.errorMessage == ReportError.permissionDenied.errorDescription)
        #expect(vm.hasLoaded)
        #expect(vm.reports.isEmpty)
    }

    @Test func loadFailureWithUnknownErrorUsesGenericMessage() async {
        let service = StubReportService()
        service.loadError = TestError.boom
        let vm = AdminReportsViewModel(service: service)
        await vm.load()
        #expect(vm.errorMessage == ReportError.unknown.errorDescription)
    }

    @Test func statusFilterNarrowsList() async {
        let (vm, _) = await loaded()
        vm.filter = .status(.open)
        #expect(vm.visibleReports.map(\.id) == ["1"])
        vm.filter = .all
        #expect(vm.visibleReports.count == 3)
    }

    @Test func searchMatchesDetailsUserAndHashtagsCaseInsensitively() async {
        let (vm, _) = await loaded()
        vm.search = "POTHOLE"
        #expect(vm.visibleReports.map(\.id) == ["1"])
        vm.search = "perera"
        #expect(vm.visibleReports.map(\.id) == ["2"])
        vm.search = "garb"
        #expect(vm.visibleReports.map(\.id) == ["3"])
    }

    @Test func searchIgnoresLeadingHashAndWhitespace() async {
        let (vm, _) = await loaded()
        vm.search = "  #urgent "
        #expect(vm.visibleReports.map(\.id) == ["1"])
    }

    @Test func searchAndFilterCombine() async {
        let (vm, _) = await loaded()
        vm.filter = .status(.resolved)
        vm.search = "pothole"
        #expect(vm.visibleReports.isEmpty)
    }

    @Test func countsPerFilter() async {
        let (vm, _) = await loaded()
        #expect(vm.count(for: .all) == 3)
        #expect(vm.count(for: .status(.open)) == 1)
        #expect(vm.count(for: .status(.inProgress)) == 1)
        #expect(vm.count(for: .status(.resolved)) == 1)
    }

    @Test func reportLookupById() async {
        let (vm, _) = await loaded()
        #expect(vm.report(id: "2")?.userName == "Nimal Perera")
        #expect(vm.report(id: "missing") == nil)
    }

    @Test func setStatusUpdatesAndCallsService() async {
        let (vm, service) = await loaded()
        await vm.setStatus(.resolved, for: "1")
        #expect(vm.report(id: "1")?.status == .resolved)
        #expect(service.statusUpdates.count == 1)
        #expect(service.statusUpdates.first?.id == "1")
        #expect(service.statusUpdates.first?.status == .resolved)
    }

    @Test func setStatusToSameValueDoesNothing() async {
        let (vm, service) = await loaded()
        await vm.setStatus(.open, for: "1")
        #expect(service.statusUpdates.isEmpty)
    }

    @Test func setStatusForUnknownIdDoesNothing() async {
        let (vm, service) = await loaded()
        await vm.setStatus(.resolved, for: "nope")
        #expect(service.statusUpdates.isEmpty)
    }

    @Test func setStatusRollsBackWhenServerRefuses() async {
        let service = StubReportService()
        service.updateError = ReportError.permissionDenied
        let (vm, _) = await loaded(service)
        await vm.setStatus(.resolved, for: "1")
        #expect(vm.report(id: "1")?.status == .open)
        #expect(vm.errorMessage == ReportError.permissionDenied.errorDescription)
    }

    @Test func observeReplacesReportsWithLatestSnapshot() async {
        let service = StubReportService()
        service.streamBatches = [[makeReport(id: "a")], [makeReport(id: "b"), makeReport(id: "c")]]
        let vm = AdminReportsViewModel(service: service)
        await vm.observe()
        #expect(vm.reports.map(\.id) == ["b", "c"])
        #expect(vm.hasLoaded)
        #expect(vm.errorMessage == nil)
    }

    @Test func observeErrorShowsMessage() async {
        let service = StubReportService()
        service.streamError = ReportError.network
        let vm = AdminReportsViewModel(service: service)
        await vm.observe()
        #expect(vm.hasLoaded)
        #expect(vm.errorMessage == ReportError.network.errorDescription)
    }
}

// MARK: - Officer dashboard

@MainActor
struct OfficerDashboardViewModelTests {
    private func reports() -> [Report] {
        [makeReport(id: "1", status: .open),
         makeReport(id: "2", status: .open),
         makeReport(id: "3", status: .inProgress),
         makeReport(id: "4", status: .resolved)]
    }

    @Test func queueExcludesResolvedAndCountsAreCorrect() async {
        let service = StubReportService()
        service.reports = reports()
        let vm = OfficerDashboardViewModel(service: service)
        await vm.load()
        #expect(vm.queue.map(\.id) == ["1", "2", "3"])
        #expect(vm.openCount == 2)
        #expect(vm.inProgressCount == 1)
        #expect(vm.resolvedCount == 1)
        #expect(vm.hasLoaded)
    }

    @Test func permissionDeniedSetsFlagInsteadOfMessage() async {
        let service = StubReportService()
        service.loadError = ReportError.permissionDenied
        let vm = OfficerDashboardViewModel(service: service)
        await vm.load()
        #expect(vm.permissionDenied)
        #expect(vm.errorMessage == nil)
    }

    @Test func otherErrorsSetMessage() async {
        let service = StubReportService()
        service.loadError = ReportError.network
        let vm = OfficerDashboardViewModel(service: service)
        await vm.load()
        #expect(!vm.permissionDenied)
        #expect(vm.errorMessage == ReportError.network.errorDescription)
    }

    @Test func successfulLoadClearsEarlierPermissionError() async {
        let service = StubReportService()
        service.loadError = ReportError.permissionDenied
        let vm = OfficerDashboardViewModel(service: service)
        await vm.load()
        service.loadError = nil
        await vm.load()
        #expect(!vm.permissionDenied)
    }

    @Test func observeUpdatesReports() async {
        let service = StubReportService()
        service.streamBatches = [reports()]
        let vm = OfficerDashboardViewModel(service: service)
        await vm.observe()
        #expect(vm.reports.count == 4)
        #expect(vm.hasLoaded)
    }

    @Test func observePermissionDenied() async {
        let service = StubReportService()
        service.streamError = ReportError.permissionDenied
        let vm = OfficerDashboardViewModel(service: service)
        await vm.observe()
        #expect(vm.permissionDenied)
    }

    @Test func resolvingRemovesReportFromQueue() async {
        let service = StubReportService()
        service.reports = reports()
        let vm = OfficerDashboardViewModel(service: service)
        await vm.load()
        await vm.setStatus(.resolved, for: "1")
        #expect(!vm.queue.contains { $0.id == "1" })
        #expect(vm.resolvedCount == 2)
        #expect(service.statusUpdates.count == 1)
    }

    @Test func setStatusRollsBackOnFailure() async {
        let service = StubReportService()
        service.reports = reports()
        service.updateError = ReportError.network
        let vm = OfficerDashboardViewModel(service: service)
        await vm.load()
        await vm.setStatus(.resolved, for: "1")
        #expect(vm.openCount == 2)
        #expect(vm.errorMessage == ReportError.network.errorDescription)
    }

    @Test func setStatusSameValueIsNoOp() async {
        let service = StubReportService()
        service.reports = reports()
        let vm = OfficerDashboardViewModel(service: service)
        await vm.load()
        await vm.setStatus(.open, for: "1")
        #expect(service.statusUpdates.isEmpty)
    }
}

// MARK: - Public dashboard

@MainActor
struct PublicDashboardViewModelTests {
    @Test func feedIsAnonymised() async {
        let service = StubReportService()
        service.reports = [makeReport(id: "1", userName: "Ahsan Ilyas", userEmail: "ahsan@example.com")]
        let vm = PublicDashboardViewModel(service: service)
        await vm.load()
        let item = vm.feed.first
        #expect(item?.userName == "Anonymous citizen")
        #expect(item?.userEmail == "")
        // Content stays intact.
        #expect(item?.id == "1")
        #expect(item?.details == "Some details")
    }

    @Test func feedIsCappedAtTwentyNewestFirst() async {
        let service = StubReportService()
        service.reports = (0..<25).map { makeReport(id: "r\($0)") }
        let vm = PublicDashboardViewModel(service: service)
        await vm.load()
        #expect(vm.feed.count == 20)
        #expect(vm.feed.first?.id == "r0")
        #expect(vm.feed.last?.id == "r19")
    }

    @Test func countsUseAllReportsNotJustTheFeed() async {
        let service = StubReportService()
        service.reports = (0..<30).map { makeReport(id: "r\($0)", status: $0 < 25 ? .open : .resolved) }
        let vm = PublicDashboardViewModel(service: service)
        await vm.load()
        #expect(vm.openCount == 25)
        #expect(vm.resolvedCount == 5)
    }

    @Test func permissionDeniedAndOtherErrors() async {
        let denied = StubReportService()
        denied.loadError = ReportError.permissionDenied
        let vm1 = PublicDashboardViewModel(service: denied)
        await vm1.load()
        #expect(vm1.permissionDenied)
        #expect(vm1.errorMessage == nil)

        let offline = StubReportService()
        offline.loadError = ReportError.network
        let vm2 = PublicDashboardViewModel(service: offline)
        await vm2.load()
        #expect(!vm2.permissionDenied)
        #expect(vm2.errorMessage == ReportError.network.errorDescription)
    }

    @Test func observeStreamsReports() async {
        let service = StubReportService()
        service.streamBatches = [[makeReport(id: "x"), makeReport(id: "y")]]
        let vm = PublicDashboardViewModel(service: service)
        await vm.observe()
        #expect(vm.feed.map(\.id) == ["x", "y"])
        #expect(vm.hasLoaded)
    }
}

// MARK: - Reports map

@MainActor
struct ReportsMapViewModelTests {
    private let here = ReportLocation(latitude: 5.9667, longitude: 80.6, accuracy: 10)

    private func sample() -> [Report] {
        [makeReport(id: "1", status: .open, location: here),
         makeReport(id: "2", status: .inProgress, location: here),
         makeReport(id: "3", status: .open, location: nil),
         makeReport(id: "4", status: .resolved, location: here)]
    }

    private func loaded() async -> (ReportsMapViewModel, StubReportService) {
        let service = StubReportService()
        service.reports = sample()
        let vm = ReportsMapViewModel(service: service)
        await vm.load()
        return (vm, service)
    }

    @Test func onlyReportsWithLocationAreMappable() async {
        let (vm, _) = await loaded()
        #expect(vm.mappableReports.map(\.id) == ["1", "2", "4"])
    }

    @Test func filterAppliesToMappableReports() async {
        let (vm, _) = await loaded()
        vm.filter = .status(.open)
        #expect(vm.mappableReports.map(\.id) == ["1"])     // "3" is open but has no location
    }

    @Test func countsIgnoreReportsWithoutLocation() async {
        let (vm, _) = await loaded()
        #expect(vm.count(for: .all) == 3)
        #expect(vm.count(for: .status(.open)) == 1)
        #expect(vm.count(for: .status(.resolved)) == 1)
    }

    @Test func permissionDeniedSetsFlag() async {
        let service = StubReportService()
        service.loadError = ReportError.permissionDenied
        let vm = ReportsMapViewModel(service: service)
        await vm.load()
        #expect(vm.permissionDenied)
        #expect(vm.errorMessage == nil)
        #expect(vm.hasLoaded)
    }

    @Test func otherErrorShowsMessage() async {
        let service = StubReportService()
        service.loadError = ReportError.network
        let vm = ReportsMapViewModel(service: service)
        await vm.load()
        #expect(!vm.permissionDenied)
        #expect(vm.errorMessage == ReportError.network.errorDescription)
    }

    @Test func observeKeepsSelectedReportInSync() async {
        let service = StubReportService()
        service.streamBatches = [[makeReport(id: "1", status: .resolved, location: here)]]
        let vm = ReportsMapViewModel(service: service)
        vm.selectedReport = makeReport(id: "1", status: .open, location: here)
        await vm.observe()
        #expect(vm.selectedReport?.status == .resolved)
    }

    @Test func observeLeavesSelectionAloneWhenReportIsGone() async {
        let service = StubReportService()
        service.streamBatches = [[makeReport(id: "other", location: here)]]
        let vm = ReportsMapViewModel(service: service)
        let selected = makeReport(id: "1", location: here)
        vm.selectedReport = selected
        await vm.observe()
        #expect(vm.selectedReport == selected)
    }

    @Test func setStatusUpdatesListAndSelection() async {
        let (vm, service) = await loaded()
        vm.selectedReport = vm.mappableReports.first { $0.id == "1" }
        await vm.setStatus(.resolved, for: "1")
        #expect(vm.selectedReport?.status == .resolved)
        #expect(vm.count(for: .status(.resolved)) == 2)
        #expect(service.statusUpdates.first?.status == .resolved)
    }

    @Test func setStatusRollsBackListAndSelectionOnFailure() async {
        let (vm, service) = await loaded()
        service.updateError = ReportError.network
        vm.selectedReport = vm.mappableReports.first { $0.id == "1" }
        await vm.setStatus(.resolved, for: "1")
        #expect(vm.selectedReport?.status == .open)
        #expect(vm.count(for: .status(.open)) == 1)
        #expect(vm.errorMessage == ReportError.network.errorDescription)
    }

    @Test func setStatusPermissionDeniedSetsFlag() async {
        let (vm, service) = await loaded()
        service.updateError = ReportError.permissionDenied
        await vm.setStatus(.resolved, for: "1")
        #expect(vm.permissionDenied)
        #expect(vm.count(for: .status(.open)) == 1)
    }
}
