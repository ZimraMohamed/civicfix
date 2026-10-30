import SwiftUI

struct AppButton: View {
    enum Style { case primary, secondary }

    let title: String
    var style: Style = .primary
    var isLoading = false
    var isDisabled = false
    var systemImage: String? = nil
    let action: () -> Void

    private var foreground: Color { style == .primary ? .white : AppColors.primary }

    var body: some View {
        Button {
            guard !isLoading, !isDisabled else { return }
            action()
        } label: {
            ZStack {
                HStack(spacing: 8) {
                    if let systemImage { Image(systemName: systemImage) }
                    Text(title)
                }
                .font(AppFonts.button)
                .opacity(isLoading ? 0 : 1)

                if isLoading {
                    ProgressView().tint(foreground)
                }
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: AppSpacing.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                    .fill(style == .primary ? AppColors.primary : AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                    .stroke(AppColors.primary, lineWidth: style == .secondary ? 1.5 : 0)
            )
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityLabel(isLoading ? "\(title), loading" : title)
    }
}

#Preview {
    VStack(spacing: 16) {
        AppButton(title: "Sign In") {}
        AppButton(title: "Sign in with Face ID", style: .secondary, systemImage: "faceid") {}
        AppButton(title: "Loading", isLoading: true) {}
        AppButton(title: "Disabled", isDisabled: true) {}
    }
    .padding(24)
    .background(AppColors.background)
}
