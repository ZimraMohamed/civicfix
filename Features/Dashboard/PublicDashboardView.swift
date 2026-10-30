import SwiftUI

/// Public dashboard: a community feed of recent reports (reporter anonymized)
/// plus a "New report" call-to-action that jumps to the Report tab.
struct PublicDashboardView: View {
    var onReportTapped: () -> Void = {}
    @State private var vm = PublicDashboardViewModel()

    var body: some View {
        @Bindable var vm = vm

        VStack(spacing: 0) {
            header
            cta
            feed
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Community")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.observe() }
        .refreshable { await vm.load() }
        .alert("Something went wrong",
               isPresented: Binding(get: { vm.errorMessage != nil },
                                    set: { if !$0 { vm.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Community")
                .font(AppFonts.screenTitle)
                .foregroundStyle(AppColors.textPrimary)
            Text("See what your neighbours are reporting.")
                .font(AppFonts.subtitle)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, 16)
    }

    private var cta: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatChip(title: "Open", value: vm.openCount,
                         color: AppColors.error, icon: "exclamationmark.circle.fill")
                StatChip(title: "Resolved", value: vm.resolvedCount,
                         color: AppColors.success, icon: "checkmark.circle.fill")
            }
            AppButton(title: "Report an issue", systemImage: "camera.fill") {
                onReportTapped()
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, 16)
    }

    @ViewBuilder private var feed: some View {
        if !vm.hasLoaded {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.permissionDenied {
            ContentUnavailableView(
                "No access yet",
                systemImage: "lock.fill",
                description: Text("The community feed will appear here once public read access is enabled.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.feed.isEmpty {
            ContentUnavailableView(
                "No reports yet",
                systemImage: "tray",
                description: Text("Be the first to report an issue in your area.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    Text("Recent reports")
                        .font(AppFonts.fieldLabel)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(vm.feed) { report in
                        CommunityReportRow(report: report)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
        }
    }
}

// MARK: - Row

private struct CommunityReportRow: View {
    let report: Report

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ReportThumbnail(data: report.imageData)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                StatusBadge(status: report.status)
                Text(report.details.isEmpty ? "No description" : report.details)
                    .font(AppFonts.input)
                    .foregroundStyle(report.details.isEmpty
                                     ? AppColors.textSecondary : AppColors.textPrimary)
                    .lineLimit(2)
                if !report.hashtags.isEmpty {
                    Text(report.hashtags.map { "#\($0)" }.joined(separator: " "))
                        .font(AppFonts.error)
                        .foregroundStyle(AppColors.primary)
                        .lineLimit(1)
                }
                Text(reportDateText(report.createdAt))
                    .font(AppFonts.error)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

#Preview {
    NavigationStack { PublicDashboardView() }
        .environment(SessionStore.preview())
}
