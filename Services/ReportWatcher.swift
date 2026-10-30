import Foundation
import OSLog
#if canImport(FirebaseFirestore)
import FirebaseFirestore

/// Listens to Firestore in real time while the app is running and raises a local notification:
///   • every user: one of *their* reports changed status
///   • admins:     someone else submitted a new report
///
/// Needs no server. Limitation: it only works while the app process is alive
/// (foreground, or shortly after it goes to the background).
@MainActor
final class ReportWatcher {
    static let shared = ReportWatcher()

    private let log = Logger(subsystem: "com.lozaa.CivicFix", category: "watcher")
    private var listeners: [ListenerRegistration] = []
    private var runningFor: (uid: String, isAdmin: Bool)?

    /// Last status we saw for each of the user's own reports.
    private var knownStatuses: [String: String] = [:]
    private var ownBaselineDone = false
    private var notifiedNewReports: Set<String> = []

    /// Safe to call repeatedly; does nothing if already watching for the same user and role.
    func start(uid: String, isAdmin: Bool) {
        if let current = runningFor, current.uid == uid, current.isAdmin == isAdmin { return }
        stop()
        runningFor = (uid, isAdmin)
        log.info("Watcher started. admin=\(isAdmin)")

        Task { await NotificationService.shared.requestPermission() }

        watchOwnReports(uid: uid)
        if isAdmin { watchNewReports(excluding: uid) }
    }

    func stop() {
        listeners.forEach { $0.remove() }
        listeners = []
        runningFor = nil
        knownStatuses = [:]
        ownBaselineDone = false
        notifiedNewReports = []
    }

    // MARK: - Reporter: status changed on my report

    private func watchOwnReports(uid: String) {
        let query = Firestore.firestore().collection("reports").whereField("uid", isEqualTo: uid)
        let listener = query.addSnapshotListener { [weak self] snapshot, error in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let error { self.log.error("Own-reports listener: \(error.localizedDescription)"); return }
                guard let snapshot else { return }
                self.handleOwn(snapshot)
            }
        }
        listeners.append(listener)
    }

    private func handleOwn(_ snapshot: QuerySnapshot) {
        // First snapshot is the starting point, not news.
        log.info("Own reports snapshot: \(snapshot.documents.count) docs, \(snapshot.documentChanges.count) changes, fromCache=\(snapshot.metadata.isFromCache)")
        if !ownBaselineDone {
            for doc in snapshot.documents { knownStatuses[doc.documentID] = doc.data()["status"] as? String }
            ownBaselineDone = true
            return
        }

        for change in snapshot.documentChanges {
            let doc = change.document
            let id = doc.documentID
            let status = doc.data()["status"] as? String ?? "open"

            switch change.type {
            case .added:
                knownStatuses[id] = status
            case .removed:
                knownStatuses[id] = nil
            case .modified:
                let previous = knownStatuses[id]
                knownStatuses[id] = status
                // Ignore echoes of our own writes; only react to what the server (an admin) changed.
                log.info("Report \(id) modified: \(previous ?? "nil") -> \(status), pendingWrites=\(doc.metadata.hasPendingWrites)")
                guard !doc.metadata.hasPendingWrites, previous != status else { continue }
                let label = ReportStatus(rawValue: status)?.title ?? status
                Task {
                    await NotificationService.shared.post(
                        title: "Your report was updated",
                        body: "Status changed to “\(label)”.",
                        type: "status_changed", reportID: id, key: status)
                }
            }
        }
    }

    // MARK: - Admin: a new report arrived

    private func watchNewReports(excluding myUID: String) {
        // Only reports created after we started listening, so we never download the whole backlog.
        let query = Firestore.firestore().collection("reports")
            .whereField("createdAt", isGreaterThan: Timestamp(date: Date()))
        let listener = query.addSnapshotListener { [weak self] snapshot, error in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let error { self.log.error("New-reports listener: \(error.localizedDescription)"); return }
                guard let snapshot else { return }
                self.handleNew(snapshot, myUID: myUID)
            }
        }
        listeners.append(listener)
    }

    private func handleNew(_ snapshot: QuerySnapshot, myUID: String) {
        for change in snapshot.documentChanges where change.type == .added {
            let doc = change.document
            let data = doc.data()
            log.info("New report seen: \(doc.documentID), pendingWrites=\(doc.metadata.hasPendingWrites)")
            guard !doc.metadata.hasPendingWrites,            // our own submission
                  (data["uid"] as? String) != myUID,
                  notifiedNewReports.insert(doc.documentID).inserted else { continue }

            let name = (data["userName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "a citizen"
            let details = (data["details"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let tags = (data["hashtags"] as? [String] ?? []).map { "#\($0)" }.joined(separator: " ")
            var body = details.isEmpty ? (tags.isEmpty ? "A new issue was reported." : tags) : details
            if body.count > 120 { body = String(body.prefix(117)) + "…" }

            let id = doc.documentID
            Task {
                await NotificationService.shared.post(
                    title: "New report from \(name)", body: body,
                    type: "new_report", reportID: id, key: "new")
            }
        }
    }
}
#else
/// Firebase not linked: nothing to watch.
@MainActor
final class ReportWatcher {
    static let shared = ReportWatcher()
    func start(uid: String, isAdmin: Bool) {}
    func stop() {}
}
#endif
