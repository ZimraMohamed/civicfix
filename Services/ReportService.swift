import Foundation

nonisolated enum ReportError: LocalizedError {
    case notSignedIn, permissionDenied, network, notConfigured, unknown

    var errorDescription: String? {
        switch self {
        case .notSignedIn: "You’re not signed in. Please sign in again."
        case .permissionDenied: "You don’t have permission to submit reports. Please contact support."
        case .network: "Can’t reach the server. Check your connection and try again."
        case .notConfigured: "Firebase isn’t linked in this build, so nothing can be saved. Add FirebaseAuth and FirebaseFirestore to the target."
        case .unknown: "Couldn’t submit your report. Please try again."
        }
    }
}

nonisolated protocol ReportServicing: Sendable {
    
    func submit(_ draft: ReportDraft) async throws

    
    func loadReports() async throws -> [Report]
   
    func updateStatus(ofReport id: String, to status: ReportStatus) async throws
    
    func reportsStream() -> AsyncThrowingStream<[Report], Error>
}

enum ReportServiceFactory {
    
    static func make() -> ReportServicing {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        return FirebaseReportService()
        #else
        return UnavailableReportService()
        #endif
    }
}


nonisolated struct UnavailableReportService: ReportServicing {
    func submit(_ draft: ReportDraft) async throws { throw ReportError.notConfigured }
    func loadReports() async throws -> [Report] { throw ReportError.notConfigured }
    func updateStatus(ofReport id: String, to status: ReportStatus) async throws { throw ReportError.notConfigured }
    func reportsStream() -> AsyncThrowingStream<[Report], Error> {
        AsyncThrowingStream { $0.finish(throwing: ReportError.notConfigured) }
    }
}


nonisolated struct MockReportService: ReportServicing {
    func submit(_ draft: ReportDraft) async throws {
        try await Task.sleep(for: .seconds(1))
    }

    func loadReports() async throws -> [Report] {
        try await Task.sleep(for: .milliseconds(500))
        return [
            Report(id: "1", userName: "Ahsan Ilyas", userEmail: "ahsan@example.com",
                   details: "Large pothole near the bus stop, cars are swerving.",
                   hashtags: ["pothole", "urgent"], imageData: nil,
                   location: ReportLocation(latitude: 5.9667, longitude: 80.6, accuracy: 12),
                   status: .open, createdAt: .now),
            Report(id: "2", userName: "Nimal Perera", userEmail: "nimal@example.com",
                   details: "Streetlight has been out for a week.",
                   hashtags: ["streetlight"], imageData: nil, location: nil,
                   status: .inProgress, createdAt: .now.addingTimeInterval(-86_400)),
            Report(id: "3", userName: "Sara Khan", userEmail: "sara@example.com",
                   details: "", hashtags: ["garbage", "drainage"], imageData: nil, location: nil,
                   status: .resolved, createdAt: .now.addingTimeInterval(-259_200))
        ]
    }

    func updateStatus(ofReport id: String, to status: ReportStatus) async throws {
        try await Task.sleep(for: .milliseconds(300))
    }

    func reportsStream() -> AsyncThrowingStream<[Report], Error> {
        AsyncThrowingStream { continuation in
            Task {
                do { continuation.yield(try await loadReports()); continuation.finish() }
                catch { continuation.finish(throwing: error) }
            }
        }
    }
}
