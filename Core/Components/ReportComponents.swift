import SwiftUI

/// Shared report UI bits used by the admin, officer, and public dashboards.
/// Extracted so the same look is reused everywhere (previously duplicated in AdminReportsView).

/// Square thumbnail for a report photo. Shows a placeholder when there's no image.
struct ReportThumbnail: View {
    let data: Data?

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "photo").foregroundStyle(AppColors.placeholder)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
        .clipped()
    }
}

/// Coloured pill that shows a report's status with its icon.
struct StatusBadge: View {
    let status: ReportStatus

    private var color: Color {
        switch status {
        case .open: AppColors.error
        case .inProgress: .orange
        case .resolved: AppColors.success
        }
    }

    var body: some View {
        Label(status.title, systemImage: status.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.14)))
    }
}

/// Compact stat tile used on the officer and public dashboards.
struct StatChip: View {
    let title: String
    let value: Int
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(color)
            Text("\(value)")
                .font(AppFonts.screenTitle)
                .foregroundStyle(AppColors.textPrimary)
            Text(title)
                .font(AppFonts.error)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .appCard()
    }
}

/// "12 Oct 2026, 09:41" — or "Just now" when there's no timestamp yet.
func reportDateText(_ date: Date?) -> String {
    date?.formatted(date: .abbreviated, time: .shortened) ?? "Just now"
}
