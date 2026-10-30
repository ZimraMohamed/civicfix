import Foundation
import SwiftUI
import MapKit

@MainActor @Observable
/// Feeds the map screen. Streams every report, keeps only the ones that have
/// a location, exposes a status filter, and offers optimistic status changes
/// (same pattern as the officer dashboard).
final class ReportsMapViewModel {
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
    var permissionDenied = false
    var filter: Filter = .all
    /// The report whose details are showing in the bottom sheet, if any.
    var selectedReport: Report?

    private let service: ReportServicing

    init(service: ReportServicing = ReportServiceFactory.make()) {
        self.service = service
    }

    /// Reports that have a location AND match the current filter. Newest first.
    var mappableReports: [Report] {
        reports
            .filter { $0.location != nil }
            .filter { report in
                if case .status(let wanted) = filter, report.status != wanted { return false }
                return true
            }
    }

    /// Count of mappable reports for a given filter (used by the picker labels).
    func count(for filter: Filter) -> Int {
        let withLocation = reports.filter { $0.location != nil }
        switch filter {
        case .all: return withLocation.count
        case .status(let status): return withLocation.filter { $0.status == status }.count
        }
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

    /// Live list; emits again whenever any report changes. Runs until the view leaves.
    func observe() async {
        do {
            for try await list in service.reportsStream() {
                reports = list
                hasLoaded = true
                errorMessage = nil
                permissionDenied = false
                // Keep the open sheet in sync if the selected report changed.
                if let id = selectedReport?.id,
                   let updated = list.first(where: { $0.id == id }) {
                    selectedReport = updated
                }
            }
        } catch {
            hasLoaded = true
            handleError(error)
        }
    }

    /// Optimistic status change; rolls back if the server refuses.
    func setStatus(_ status: ReportStatus, for id: String) async {
        guard let index = reports.firstIndex(where: { $0.id == id }) else { return }
        let previous = reports[index].status
        guard previous != status else { return }
        reports[index].status = status
        if selectedReport?.id == id { selectedReport = reports[index] }
        do {
            try await service.updateStatus(ofReport: id, to: status)
        } catch {
            if let back = reports.firstIndex(where: { $0.id == id }) {
                reports[back].status = previous
                if selectedReport?.id == id { selectedReport = reports[back] }
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

/// Builds a `MKCoordinateRegion` that fits every report location, with padding
/// so pins don't sit on the edges. Returns nil when there are no locations.
func fittedRegion(for reports: [Report]) -> MKCoordinateRegion? {
    let coords = reports.compactMap { $0.location }
    guard !coords.isEmpty else { return nil }
    let lats = coords.map(\.latitude)
    let lons = coords.map(\.longitude)
    guard let minLat = lats.min(), let maxLat = lats.max(),
          let minLon = lons.min(), let maxLon = lons.max() else { return nil }

    let center = CLLocationCoordinate2D(
        latitude: (minLat + maxLat) / 2,
        longitude: (minLon + maxLon) / 2
    )
    // Pad by 40% and clamp to a sensible minimum so a single pin isn't zoomed all the way in.
    let latDelta = max(maxLat - minLat, 0.02) * 1.4 + 0.01
    let lonDelta = max(maxLon - minLon, 0.02) * 1.4 + 0.01
    return MKCoordinateRegion(
        center: center,
        span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
    )
}
