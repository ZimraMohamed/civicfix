import SwiftUI

struct AppBackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: AppSpacing.backButtonSize, height: AppSpacing.backButtonSize)
                .background(RoundedRectangle(cornerRadius: AppSpacing.backButtonRadius).fill(AppColors.surface))
                .overlay(RoundedRectangle(cornerRadius: AppSpacing.backButtonRadius).stroke(AppColors.border, lineWidth: 1))
        }
        .accessibilityLabel("Back")
    }
}

#Preview { AppBackButton().padding().background(AppColors.background) }
