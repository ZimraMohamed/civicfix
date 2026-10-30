import SwiftUI

extension View {
   
    func appCard() -> some View {
        self
            .background(RoundedRectangle(cornerRadius: AppSpacing.inputRadius).fill(AppColors.surface))
            .overlay(RoundedRectangle(cornerRadius: AppSpacing.inputRadius)
                .stroke(AppColors.border, lineWidth: AppSpacing.borderWidth))
    }
}
