import Testing
import SwiftUI
import MapKit
@testable import CivicFix

// HashTag

struct HashTagTests {
    @Test func normalizeStripsSymbolsAndLowercases() {
        #expect(HashTag.normalize("#Pothole!") == "pothole")
        #expect(HashTag.normalize("broken_light") == "broken_light")
        #expect(HashTag.normalize("Water Leak") == "waterleak")
    }

    @Test(arguments: ["", "   ", "###", "!!!"])
    func normalizeReturnsNilWhenNothingUsable(_ raw: String) {
        #expect(HashTag.normalize(raw) == nil)
    }

    @Test func normalizeTruncatesToMaxLength() {
        let result = HashTag.normalize(String(repeating: "a", count: 50))
        #expect(result?.count == HashTag.maxLength)
    }

    @Test func parseSplitsOnWhitespaceCommasAndHashes() {
        #expect(HashTag.parse("#pothole #urgent, broken_light") == ["pothole", "urgent", "broken_light"])
        #expect(HashTag.parse("#a#b") == ["a", "b"])
    }

    @Test func parseOfEmptyOrPunctuationOnlyIsEmpty() {
        #expect(HashTag.parse("").isEmpty)
        #expect(HashTag.parse("  ,, ##  ").isEmpty)
    }

    @Test func suggestionsAreAlreadyNormalised() {
        for tag in HashTag.suggestions {
            #expect(HashTag.normalize(tag) == tag)
        }
    }
}

//  ReportStatus / UserRole

struct ReportStatusTests {
    @Test func rawValuesMatchFirestore() {
        #expect(ReportStatus.open.rawValue == "open")
        #expect(ReportStatus.inProgress.rawValue == "in_progress")
        #expect(ReportStatus.resolved.rawValue == "resolved")
        #expect(ReportStatus(rawValue: "in_progress") == .inProgress)
        #expect(ReportStatus(rawValue: "bogus") == nil)
    }

    @Test func titlesAndIconsAreDefinedForEveryCase() {
        #expect(ReportStatus.open.title == "Open")
        #expect(ReportStatus.inProgress.title == "In progress")
        #expect(ReportStatus.resolved.title == "Resolved")
        for status in ReportStatus.allCases {
            #expect(!status.systemImage.isEmpty)
        }
    }
}

struct UserRoleTests {
    @Test func rawValuesAndTitles() {
        #expect(UserRole.public.rawValue == "public")
        #expect(UserRole.officer.title == "Officer")
        #expect(UserRole.admin.title == "Admin")
        #expect(UserRole.allCases == [.public, .officer, .admin])
    }
}

// UserAccount / UserProfile

struct UserAccountTests {
    @Test func initialsUseFirstTwoWords() {
        #expect(makeUser(name: "Ahsan Ilyas").initials == "AI")
        #expect(makeUser(name: "Ahsan Bin Ilyas").initials == "AB")
        #expect(makeUser(name: "madonna").initials == "M")
    }

    @Test func initialsFallBackToEmailThenQuestionMark() {
        #expect(makeUser(name: "", email: "zed@example.com").initials == "Z")
        #expect(makeUser(name: "   ", email: "zed@example.com").initials == "Z")
        #expect(makeUser(name: "", email: "").initials == "?")
    }

    @Test func publicRoleIsAlwaysImplied() {
        let user = makeUser(roles: [])
        #expect(user.effectiveRoles == [.public])
        #expect(!user.isOfficer)
        #expect(!user.isAdmin)
    }

    @Test func roleFlags() {
        #expect(makeUser(roles: [.officer]).isOfficer)
        #expect(makeUser(roles: [.admin]).isAdmin)
    }

    @Test func rolesTextIsOrderedAndJoined() {
        #expect(makeUser(roles: []).rolesText == "Public")
        #expect(makeUser(roles: [.officer]).rolesText == "Public · Officer")
        #expect(makeUser(roles: [.admin, .officer]).rolesText == "Public · Officer · Admin")
    }
}

struct UserProfileTests {
    @Test func defaultsToPublicOnly() {
        let profile = UserProfile(uid: "1", email: "a@b.com", displayName: "A B")
        #expect(profile.roles == [.public])
        #expect(profile.has(.public))
        #expect(!profile.isAdmin)
        #expect(!profile.isOfficer)
    }

    @Test func roleHelpers() {
        let profile = UserProfile(uid: "1", email: "a@b.com", displayName: "A B", roles: [.public, .admin])
        #expect(profile.isAdmin)
        #expect(!profile.isOfficer)
    }

    @Test func initials() {
        #expect(UserProfile(uid: "1", email: "a@b.com", displayName: "Ahsan Ilyas").initials == "AI")
        #expect(UserProfile(uid: "1", email: "q@b.com", displayName: "").initials == "Q")
    }
}

// Error messages

struct ErrorMessageTests {
    @Test func authErrorsHaveSpecificMessages() {
        #expect(AuthError.invalidCredentials.errorDescription == "Incorrect email or password.")
        #expect(AuthError.wrongCurrentPassword.errorDescription == "Your current password is incorrect.")
        #expect(AuthError.emailInUse.errorDescription == "That email is already used by another account.")
        let all: [AuthError] = [.invalidCredentials, .noSavedSession, .emailNotFound, .emailInUse,
                                .weakPassword, .wrongCurrentPassword, .tooManyAttempts,
                                .network, .notSignedIn, .unknown]
        for error in all { #expect(!(error.errorDescription ?? "").isEmpty) }
    }

    @Test func reportErrorsHaveMessages() {
        let all: [ReportError] = [.notSignedIn, .permissionDenied, .network, .notConfigured, .unknown]
        for error in all { #expect(!(error.errorDescription ?? "").isEmpty) }
    }

    @Test func userAdminErrorsHaveMessages() {
        #expect(UserAdminError.permissionDenied.errorDescription == "Only admins can manage users.")
        let all: [UserAdminError] = [.emailInUse, .weakPassword, .invalidEmail, .network,
                                     .permissionDenied, .notSignedIn, .unknown]
        for error in all { #expect(!(error.errorDescription ?? "").isEmpty) }
    }

    @Test func biometricErrorsHaveMessages() {
        #expect(!(BiometricError.unavailable.errorDescription ?? "").isEmpty)
        #expect(!(BiometricError.failed.errorDescription ?? "").isEmpty)
    }
}

//  AppAppearance

@MainActor
struct AppAppearanceTests {
    @Test func colorSchemeMapping() {
        #expect(AppAppearance.system.colorScheme == nil)
        #expect(AppAppearance.light.colorScheme == .light)
        #expect(AppAppearance.dark.colorScheme == .dark)
    }

    @Test func titlesAndRawValues() {
        #expect(AppAppearance.system.title == "Auto")
        #expect(AppAppearance.light.title == "Light")
        #expect(AppAppearance.dark.title == "Dark")
        #expect(AppAppearance(rawValue: "dark") == .dark)
        #expect(AppAppearance.allCases.count == 3)
        #expect(!AppAppearance.storageKey.isEmpty)
    }
}

// fittedRegion

@MainActor
struct FittedRegionTests {
    private func report(_ lat: Double, _ lon: Double) -> Report {
        makeReport(location: ReportLocation(latitude: lat, longitude: lon, accuracy: 5))
    }

    @Test func noLocationsGivesNil() {
        #expect(fittedRegion(for: []) == nil)
        #expect(fittedRegion(for: [makeReport(location: nil)]) == nil)
    }

    @Test func singlePinUsesMinimumSpan() throws {
        let region = try #require(fittedRegion(for: [report(5.9667, 80.6)]))
        #expect(abs(region.center.latitude - 5.9667) < 1e-9)
        #expect(abs(region.center.longitude - 80.6) < 1e-9)
        // max(0, 0.02) * 1.4 + 0.01
        #expect(abs(region.span.latitudeDelta - 0.038) < 1e-9)
        #expect(abs(region.span.longitudeDelta - 0.038) < 1e-9)
    }

    @Test func multiplePinsAreCenteredAndPadded() throws {
        let region = try #require(fittedRegion(for: [report(5, 80), report(6, 81)]))
        #expect(abs(region.center.latitude - 5.5) < 1e-9)
        #expect(abs(region.center.longitude - 80.5) < 1e-9)
        #expect(abs(region.span.latitudeDelta - 1.41) < 1e-9)
        #expect(abs(region.span.longitudeDelta - 1.41) < 1e-9)
    }

    @Test func reportsWithoutLocationAreIgnored() throws {
        let region = try #require(fittedRegion(for: [report(5, 80), makeReport(location: nil)]))
        #expect(abs(region.center.latitude - 5) < 1e-9)
    }
}
