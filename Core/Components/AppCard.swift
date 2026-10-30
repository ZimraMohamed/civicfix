import SwiftUI

extension View {
    /// White (or dark-mode surface) rounded card with a hairline border.
    func appCard() -> some View {
        self
            .background(RoundedRectangle(cornerRadius: AppSpacing.inputRadius).fill(AppColors.surface))
            .overlay(RoundedRectangle(cornerRadius: AppSpacing.inputRadius)
                .stroke(AppColors.border, lineWidth: AppSpacing.borderWidth))
    }
}
