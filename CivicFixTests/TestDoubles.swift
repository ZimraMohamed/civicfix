import Foundation
import UIKit
@testable import CivicFix

// MARK: - Shared test helpers
// Hand-written fakes for the service protocols, so view models and SessionStore
// can be tested without Firebase, the network, Face ID or the Keychain.

enum TestError: Error { case boom }

final class StubAuthService: AuthServicing, @unchecked Sendable {
    var loggedIn = false
    var user: UserProfile?
    /// When set, every throwing method throws it.
    var error: Error?
    var roles: Set<UserRole> = [.public]

    private(set) var signInCalls: [(email: String, password: String)] = []
    private(set) var registerCalls: [(name: String, email: String, password: String)] = []
    private(set) var resetEmails: [String] = []
    private(set) var changeEmailCalls: [(email: String, password: String)] = []
    private(set) var changePasswordCalls: [(current: String, new: String)] = []
    private(set) var restoreCount = 0
    private(set) var reloadCount = 0
    private(set) var signOutCount = 0

    var isLoggedIn: Bool { loggedIn }
    var currentUser: UserProfile? { user }

    func signIn(email: String, password: String) async throws {
        signInCalls.append((email, password))
        if let error { throw error }
        loggedIn = true
    }
    func register(name: String, email: String, password: String) async throws {
        registerCalls.append((name, email, password))
        if let error { throw error }
        loggedIn = true
    }
    func sendPasswordReset(email: String) async throws {
        resetEmails.append(email)
        if let error { throw error }
    }
    func restoreSession() async throws {
        restoreCount += 1
        if let error { throw error }
        loggedIn = true
    }
    func reloadUser() async { reloadCount += 1 }
    func changeEmail(to newEmail: String, currentPassword: String) async throws {
        changeEmailCalls.append((newEmail, currentPassword))
        if let error { throw error }
    }
    func changePassword(current: String, new: String) async throws {
        changePasswordCalls.append((current, new))
        if let error { throw error }
    }
    func signOut() { signOutCount += 1; loggedIn = false }
    func loadRoles() async -> Set<UserRole> { roles }
    func setRoles(for uid: String, to roles: Set<UserRole>) async throws {
        if let error { throw error }
    }
}

final class StubBiometric: BiometricAuthenticating, @unchecked Sendable {
    var error: Error?
    private(set) var reasons: [String] = []
    func authenticate(reason: String) async throws {
        reasons.append(reason)
        if let error { throw error }
    }
}

final class StubReportService: ReportServicing, @unchecked Sendable {
    var reports: [Report] = []
    var loadError: Error?
    var updateError: Error?
    var submitError: Error?
    var streamBatches: [[Report]] = []
    var streamError: Error?

    private(set) var submitted: [ReportDraft] = []
    private(set) var statusUpdates: [(id: String, status: ReportStatus)] = []
    private(set) var loadCount = 0

    func submit(_ draft: ReportDraft) async throws {
        submitted.append(draft)
        if let submitError { throw submitError }
    }
    func loadReports() async throws -> [Report] {
        loadCount += 1
        if let loadError { throw loadError }
        return reports
    }
    func updateStatus(ofReport id: String, to status: ReportStatus) async throws {
        statusUpdates.append((id, status))
        if let updateError { throw updateError }
    }
    func reportsStream() -> AsyncThrowingStream<[Report], Error> {
        let batches = streamBatches
        let error = streamError
        return AsyncThrowingStream { continuation in
            for batch in batches { continuation.yield(batch) }
            if let error { continuation.finish(throwing: error) } else { continuation.finish() }
        }
    }
}

final class StubUserService: UserServicing, @unchecked Sendable {
    var users: [UserAccount] = []
    var loadError: Error?
    var createError: Error?
    var rolesError: Error?
    var disabledError: Error?
    var streamBatches: [[UserAccount]] = []
    var streamError: Error?

    private(set) var createCalls: [(name: String, email: String, password: String, roles: Set<UserRole>)] = []
    private(set) var roleCalls: [(uid: String, roles: Set<UserRole>)] = []
    private(set) var disabledCalls: [(uid: String, disabled: Bool)] = []

    func usersStream() -> AsyncThrowingStream<[UserAccount], Error> {
        let batches = streamBatches
        let error = streamError
        return AsyncThrowingStream { continuation in
            for batch in batches { continuation.yield(batch) }
            if let error { continuation.finish(throwing: error) } else { continuation.finish() }
        }
    }
    func loadUsers() async throws -> [UserAccount] {
        if let loadError { throw loadError }
        return users
    }
    func createUser(name: String, email: String, password: String, roles: Set<UserRole>) async throws {
        createCalls.append((name, email, password, roles))
        if let createError { throw createError }
    }
    func setRoles(for uid: String, to roles: Set<UserRole>) async throws {
        roleCalls.append((uid, roles))
        if let rolesError { throw rolesError }
    }
    func setDisabled(_ disabled: Bool, for uid: String) async throws {
        disabledCalls.append((uid, disabled))
        if let disabledError { throw disabledError }
    }
}

// MARK: - Sample data

func makeReport(id: String = UUID().uuidString,
                status: ReportStatus = .open,
                userName: String = "Test User",
                userEmail: String = "test@example.com",
                details: String = "Some details",
                hashtags: [String] = [],
                location: ReportLocation? = nil) -> Report {
    Report(id: id, userName: userName, userEmail: userEmail, details: details,
           hashtags: hashtags, imageData: nil, location: location,
           status: status, createdAt: Date(timeIntervalSince1970: 1_700_000_000))
}

func makeUser(id: String = UUID().uuidString,
              name: String = "Test User",
              email: String = "test@example.com",
              roles: Set<UserRole> = [.public],
              disabled: Bool = false) -> UserAccount {
    UserAccount(id: id, displayName: name, email: email, roles: roles,
                disabled: disabled, createdAt: Date(timeIntervalSince1970: 1_700_000_000))
}

func makeTestImage(width: CGFloat = 200, height: CGFloat = 200) -> UIImage {
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
        UIColor.red.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
}

let validPassword = "abcd1234"
