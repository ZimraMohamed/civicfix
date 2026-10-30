import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(RoundedRectangle(cornerRadius: 20).fill(AppColors.primary))
                    .shadow(color: AppColors.primary.opacity(0.3), radius: 16, y: 8)
                    .accessibilityHidden(true)

                Text("CivicFix")
                    .font(.system(size: 29, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Report. Track. Improve.")
                    .font(AppFonts.subtitle)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .accessibilityElement(children: .combine)

            VStack {
                Spacer()
                Text("Making our communities better")
                    .font(AppFonts.footer)
                    .foregroundStyle(AppColors.placeholder)
                    .padding(.bottom, 24)
            }
        }
    }
}

#Preview { SplashView() }
