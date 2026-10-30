import SwiftUI

@MainActor @Observable
/// Feeds the public community feed. Streams every report, anonymizes the
/// reporter's identity, and caps the list to the 20 most recent so the feed
/// stays light.
final class PublicDashboardViewModel {
    private(set) var reports: [Report] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    var errorMessage: String?
    var permissionDenied = false

    private let service: ReportServicing

    init(service: ReportServicing = ReportServiceFactory.make()) {
        self.service = service
    }

    /// Newest first, anonymized, capped to 20.
    var feed: [Report] {
        Array(reports.prefix(20)).map { anonymize($0) }
    }
    var openCount: Int { reports.filter { $0.status == .open }.count }
    var resolvedCount: Int { reports.filter { $0.status == .resolved }.count }

    private func anonymize(_ r: Report) -> Report {
        var copy = r
        copy.userName = "Anonymous citizen"
        copy.userEmail = ""
        return copy
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false; hasLoaded = true }
        do {
            reports = try await service.loadReports()
            errorMessage = nil
            permissionDenied = false
        } catch {
            handleError(error)
        }
    }

    func observe() async {
        do {
            for try await list in service.reportsStream() {
                reports = list
                hasLoaded = true
                errorMessage = nil
                permissionDenied = false
            }
        } catch {
            hasLoaded = true
            handleError(error)
        }
    }

    private func handleError(_ error: Error) {
        if let e = error as? ReportError, case .permissionDenied = e {
            permissionDenied = true
            errorMessage = nil
        } else {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? ReportError.unknown.errorDescription
        }
    }
}
