import Testing
@testable import CivicFix

struct ValidatorTests {
    @Test(arguments: ["a@b.com", "first.last+tag@mail.example.org"])
    func validEmails(_ email: String) {
        #expect(Validator.isValidEmail(email))
    }

    @Test(arguments: ["", "plain", "a@b", "@b.com", "a b@c.com"])
    func invalidEmails(_ email: String) {
        #expect(!Validator.isValidEmail(email))
    }

    @Test func passwordRules() {
        #expect(Validator.isValidPassword("abcd1234"))
        #expect(!Validator.isValidPassword("short1"))
        #expect(!Validator.isValidPassword("onlyletters"))
        #expect(!Validator.isValidPassword("12345678"))
    }

    @Test func passwordsMatch() {
        #expect(Validator.passwordsMatch("abc12345", "abc12345"))
        #expect(!Validator.passwordsMatch("abc12345", "abc12346"))
        #expect(!Validator.passwordsMatch("", ""))
    }

    @Test func nameValidation() {
        #expect(Validator.isValidName("Jo"))
        #expect(!Validator.isValidName(" "))
    }
}
