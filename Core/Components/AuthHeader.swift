import SwiftUI

struct AuthHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFonts.screenTitle)
                .tracking(-0.6)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(AppFonts.subtitle)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview { AuthHeader(title: "Welcome Back", subtitle: "Sign in to continue").padding() }
