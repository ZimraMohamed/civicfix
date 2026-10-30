import Testing
@testable import CivicFix

/// Extra cases on top of Tests/ValidatorTests.swift.
struct ValidatorEdgeCaseTests {
    @Test func emailIsTrimmedBeforeChecking() {
        #expect(Validator.isValidEmail("  a@b.com \n"))
    }

    @Test(arguments: ["a@b.c", "a@@b.com", "a@b.c0m", "a@.com", "user@domain.", "a@b.com extra"])
    func moreInvalidEmails(_ email: String) {
        #expect(!Validator.isValidEmail(email))
    }

    @Test(arguments: ["UPPER@CASE.ORG", "a.b-c_d%e+f@sub.domain.co"])
    func moreValidEmails(_ email: String) {
        #expect(Validator.isValidEmail(email))
    }

    @Test func passwordLengthBoundary() {
        #expect(Validator.isValidPassword("abcdefg1"))     // 8 chars
        #expect(!Validator.isValidPassword("abcdef1"))     // 7 chars
    }

    @Test func passwordNeedsBothLetterAndNumber() {
        #expect(!Validator.isValidPassword("abcdefgh"))
        #expect(!Validator.isValidPassword("12345678"))
        #expect(!Validator.isValidPassword(""))
    }

    @Test func passwordMatchIsCaseSensitive() {
        #expect(!Validator.passwordsMatch("Abc12345", "abc12345"))
    }

    @Test func nameIsTrimmedAndNeedsTwoCharacters() {
        #expect(Validator.isValidName("  Jo  "))
        #expect(!Validator.isValidName("J"))
        #expect(!Validator.isValidName(""))
        #expect(!Validator.isValidName("  J  "))
    }
}
