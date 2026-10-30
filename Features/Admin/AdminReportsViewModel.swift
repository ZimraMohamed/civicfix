import SwiftUI

@MainActor @Observable
final class AdminReportsViewModel {
    enum Filter: Hashable {
        case all, status(ReportStatus)

        static let options: [Filter] = [.all] + ReportStatus.allCases.map { .status($0) }

        var title: String {
            switch self {
            case .all: "All"
            case .status(let status): status.title
            }
        }
    }

    private(set) var reports: [Report] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    var errorMessage: String?
    var filter: Filter = .all
    var search = ""

    private let service: ReportServicing

    init(service: ReportServicing = ReportServiceFactory.make()) {
        self.service = service
    }

    var visibleReports: [Report] {
        let query = search.trimmingCharacters(in: .whitespaces)
            .lowercased().replacingOccurrences(of: "#", with: "")
        return reports.filter { report in
            if case .status(let wanted) = filter, report.status != wanted { return false }
            guard !query.isEmpty else { return true }
            return report.details.lowercased().contains(query)
                || report.userName.lowercased().contains(query)
                || report.hashtags.contains { $0.contains(query) }
        }
    }

    func count(for filter: Filter) -> Int {
        switch filter {
        case .all: reports.count
        case .status(let status): reports.filter { $0.status == status }.count
        }
    }

    func report(id: String) -> Report? { reports.first { $0.id == id } }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false; hasLoaded = true }
        do {
            reports = try await service.loadReports()
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? ReportError.unknown.errorDescription
        }
    }

    /// Keeps `reports` in sync with Firestore in real time. Runs until the view disappears.
    func observe() async {
        do {
            for try await list in service.reportsStream() {
                reports = list
                hasLoaded = true
                errorMessage = nil
            }
        } catch {
            hasLoaded = true
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? ReportError.unknown.errorDescription
        }
    }

    /// Updates the screen immediately and rolls back if the server refuses.
    func setStatus(_ status: ReportStatus, for id: String) async {
        guard let index = reports.firstIndex(where: { $0.id == id }) else { return }
        let previous = reports[index].status
        guard previous != status else { return }
        reports[index].status = status
        do {
            try await service.updateStatus(ofReport: id, to: status)
        } catch {
            if let back = reports.firstIndex(where: { $0.id == id }) { reports[back].status = previous }
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? ReportError.unknown.errorDescription
        }
    }
}
