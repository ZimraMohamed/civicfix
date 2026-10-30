import Foundation

nonisolated enum Validator {
    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    /// At least 8 characters, containing a letter and a number.
    static func isValidPassword(_ password: String) -> Bool {
        password.count >= 8
            && password.contains(where: \.isLetter)
            && password.contains(where: \.isNumber)
    }

    static func passwordsMatch(_ a: String, _ b: String) -> Bool {
        !a.isEmpty && a == b
    }

    static func isValidName(_ name: String) -> Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }
}
