import SwiftUI

@MainActor @Observable

final class OfficerDashboardViewModel {
    private(set) var reports: [Report] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    var errorMessage: String?
    var permissionDenied = false

    private let service: ReportServicing

    init(service: ReportServicing = ReportServiceFactory.make()) {
        self.service = service
    }

   
    var queue: [Report] {
        reports.filter { $0.status != .resolved }
    }
    var openCount: Int { reports.filter { $0.status == .open }.count }
    var inProgressCount: Int { reports.filter { $0.status == .inProgress }.count }
    var resolvedCount: Int { reports.filter { $0.status == .resolved }.count }

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

    
    func setStatus(_ status: ReportStatus, for id: String) async {
        guard let index = reports.firstIndex(where: { $0.id == id }) else { return }
        let previous = reports[index].status
        guard previous != status else { return }
        reports[index].status = status
        do {
            try await service.updateStatus(ofReport: id, to: status)
        } catch {
            if let back = reports.firstIndex(where: { $0.id == id }) {
                reports[back].status = previous
            }
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
