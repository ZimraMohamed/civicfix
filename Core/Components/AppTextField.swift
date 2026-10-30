import SwiftUI

struct AppTextField: View {
    enum FieldType { case email, phone, password, plain }

    let label: String
    let placeholder: String
    @Binding var text: String
    var type: FieldType = .plain
    var errorMessage: String? = nil
    /// Use `.newPassword` on register screens for iOS password suggestions.
    var contentTypeOverride: UITextContentType? = nil

    @FocusState private var isFocused: Bool
    @State private var isRevealed = false

    private var isSecure: Bool { type == .password && !isRevealed }

    private var borderColor: Color {
        if errorMessage != nil { return AppColors.error }
        return isFocused ? AppColors.primary : AppColors.border
    }

    private var keyboard: UIKeyboardType {
        switch type {
        case .email: .emailAddress
        case .phone: .phonePad
        default: .default
        }
    }

    private var contentType: UITextContentType? {
        if let contentTypeOverride { return contentTypeOverride }
        return switch type {
        case .email: .emailAddress
        case .phone: .telephoneNumber
        case .password: .password
        case .plain: nil
        }
    }

    private var capitalization: TextInputAutocapitalization {
        switch type {
        case .email, .password, .phone: .never
        case .plain: .words
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.labelToInput) {
            Text(label)
                .font(AppFonts.fieldLabel)
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: 8) {
                Group {
                    if isSecure {
                        SecureField("", text: $text, prompt: promptText)
                    } else {
                        TextField("", text: $text, prompt: promptText)
                    }
                }
                .focused($isFocused)
                .font(AppFonts.input)
                .foregroundStyle(AppColors.textPrimary)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled(type != .plain)

                if type == .password {
                    Button {
                        isRevealed.toggle()
                    } label: {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
                }
            }
            .padding(.horizontal, AppSpacing.inputPadding)
            .frame(minHeight: AppSpacing.inputHeight)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.inputRadius).fill(AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.inputRadius)
                    .stroke(borderColor, lineWidth: AppSpacing.borderWidth)
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel(label)
            .accessibilityHint(errorMessage ?? "Enter your \(label.lowercased())")

            if let errorMessage {
                Text(errorMessage)
                    .font(AppFonts.error)
                    .foregroundStyle(AppColors.error)
                    .accessibilityLabel("Error: \(errorMessage)")
            }
        }
    }

    private var promptText: Text {
        Text(placeholder).foregroundStyle(AppColors.placeholder)
    }
}

#Preview {
    @Previewable @State var email = ""
    @Previewable @State var pw = "secret"
    return VStack(spacing: 24) {
        AppTextField(label: "Email", placeholder: "you@example.com", text: $email, type: .email, errorMessage: "Enter a valid email address")
        AppTextField(label: "Password", placeholder: "Password", text: $pw, type: .password)
    }
    .padding(24)
    .background(AppColors.background)
}
