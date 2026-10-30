#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import Foundation
import FirebaseAuth
import FirebaseFirestore
import OSLog

/// Saves a report as one Firestore document: `reports/{autoId}`. No Firebase Storage needed.
///
///   uid, userName, userEmail, details, hashtags [String],
///   imageData (bytes, JPEG under ~600 KB so the document stays below Firestore's 1 MiB limit),
///   location (GeoPoint, optional), locationAccuracy (Double, optional),
///   status ("open"), createdAt (server timestamp)
nonisolated struct FirebaseReportService: ReportServicing {
    private let log = Logger(subsystem: "com.lozaa.CivicFix", category: "reports")

    func submit(_ draft: ReportDraft) async throws {
        guard let user = Auth.auth().currentUser else { throw ReportError.notSignedIn }

        var data: [String: Any] = [
            "uid": user.uid,
            "userName": user.displayName ?? "",
            "userEmail": user.email ?? "",
            "details": draft.details,
            "hashtags": draft.hashtags,
            "imageData": draft.imageData,
            "status": "open",
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let location = draft.location {
            data["location"] = GeoPoint(latitude: location.latitude, longitude: location.longitude)
            data["locationAccuracy"] = location.accuracy
        }

        do {
            let ref = try await Firestore.firestore().collection("reports").addDocument(data: data)
            log.info("Saved report \(ref.documentID)")
        } catch {
            log.error("Save failed: \((error as NSError).domain) \((error as NSError).code) \(error.localizedDescription)")
            throw map(error)
        }
    }

    // MARK: - Admin

    func loadReports() async throws -> [Report] {
        do {
            let snapshot = try await Firestore.firestore().collection("reports")
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .getDocuments()
            return snapshot.documents.map(Self.makeReport)
        } catch { throw map(error) }
    }

    /// Live version of `loadReports()`: emits the full list again every time a report is added or changes.
    func reportsStream() -> AsyncThrowingStream<[Report], Error> {
        AsyncThrowingStream { continuation in
            nonisolated(unsafe) let registration = Firestore.firestore().collection("reports")
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: self.map(error))
                        return
                    }
                    guard let snapshot else { return }
                    continuation.yield(snapshot.documents.map(Self.makeReport))
                }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    private static func makeReport(_ doc: QueryDocumentSnapshot) -> Report {
        let data = doc.data()
        let point = data["location"] as? GeoPoint
        return Report(
            id: doc.documentID,
            userName: data["userName"] as? String ?? "",
            userEmail: data["userEmail"] as? String ?? "",
            details: data["details"] as? String ?? "",
            hashtags: data["hashtags"] as? [String] ?? [],
            imageData: data["imageData"] as? Data,
            location: point.map {
                ReportLocation(latitude: $0.latitude, longitude: $0.longitude,
                               accuracy: data["locationAccuracy"] as? Double ?? 0)
            },
            status: ReportStatus(rawValue: data["status"] as? String ?? "") ?? .open,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
        )
    }

    func updateStatus(ofReport id: String, to status: ReportStatus) async throws {
        do {
            try await Firestore.firestore().collection("reports").document(id)
                .updateData(["status": status.rawValue])
        } catch { throw map(error) }
    }

    private func map(_ error: Error) -> ReportError {
        let ns = error as NSError
        if ns.domain == FirestoreErrorDomain, let code = FirestoreErrorCode.Code(rawValue: ns.code) {
            switch code {
            case .permissionDenied, .unauthenticated: return .permissionDenied
            case .unavailable, .deadlineExceeded: return .network
            default: return .unknown
            }
        }
        if ns.domain == NSURLErrorDomain { return .network }
        return .unknown
    }
}
#endif
