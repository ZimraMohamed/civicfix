import LocalAuthentication

nonisolated protocol BiometricAuthenticating: Sendable {
    func authenticate(reason: String) async throws
}

nonisolated enum BiometricError: LocalizedError {
    case unavailable, failed
    var errorDescription: String? {
        switch self {
        case .unavailable: "Face ID isn’t available on this device."
        case .failed: "Face ID didn’t recognise you. Try again or use your password."
        }
    }
}

nonisolated struct BiometricService: BiometricAuthenticating {
    func authenticate(reason: String) async throws {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw BiometricError.unavailable
        }
        do {
            let ok = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                                      localizedReason: reason)
            if !ok { throw BiometricError.failed }
        } catch let laError as LAError where laError.code == .userCancel || laError.code == .systemCancel {
            throw CancellationError()
        }
    }
}
