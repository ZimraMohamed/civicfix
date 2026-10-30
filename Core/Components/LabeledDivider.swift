import SwiftUI

struct LabeledDivider: View {
    var label = "OR"

    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(AppColors.border).frame(height: 1)
            Text(label)
                .font(AppFonts.footer)
                .foregroundStyle(AppColors.textSecondary)
            Rectangle().fill(AppColors.border).frame(height: 1)
        }
        .accessibilityHidden(true)
    }
}

#Preview { LabeledDivider().padding() }
