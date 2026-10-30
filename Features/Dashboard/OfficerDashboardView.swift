import SwiftUI


struct OfficerDashboardView: View {
    @State private var vm = OfficerDashboardViewModel()

    var body: some View {
        @Bindable var vm = vm

        VStack(spacing: 0) {
            header
            stats
            queue
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Officer")
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
            Text("Officer")
                .font(AppFonts.screenTitle)
                .foregroundStyle(AppColors.textPrimary)
            Text("Triage reports and move them forward.")
                .font(AppFonts.subtitle)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, 16)
    }

    private var stats: some View {
        HStack(spacing: 12) {
            StatChip(title: "Open", value: vm.openCount,
                     color: AppColors.error, icon: "exclamationmark.circle.fill")
            StatChip(title: "In progress", value: vm.inProgressCount,
                     color: .orange, icon: "clock.fill")
            StatChip(title: "Resolved", value: vm.resolvedCount,
                     color: AppColors.success, icon: "checkmark.circle.fill")
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, 16)
    }

    @ViewBuilder private var queue: some View {
        if !vm.hasLoaded {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.permissionDenied {
            ContentUnavailableView(
                "No access yet",
                systemImage: "lock.fill",
                description: Text("Officers can view reports once an admin grants the role permission.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.queue.isEmpty {
            ContentUnavailableView(
                "Queue is clear",
                systemImage: "checkmark.seal.fill",
                description: Text("There are no open or in-progress reports right now.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.queue) { report in
                        OfficerReportRow(report: report) { status in
                            Task { await vm.setStatus(status, for: report.id) }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, 16)
            }
        }
    }
}



private struct OfficerReportRow: View {
    let report: Report
    let onStatus: (ReportStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ReportThumbnail(data: report.imageData)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
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

            // Quick status shortcuts. The current status is shown as selected.
            HStack(spacing: 8) {
                quickButton(.inProgress, icon: "clock.fill")
                quickButton(.resolved, icon: "checkmark.fill")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func quickButton(_ status: ReportStatus, icon: String) -> some View {
        let selected = report.status == status
        return Button {
            onStatus(status)
        } label: {
            Label(status.title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color.white : AppColors.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? AppColors.primary : AppColors.background))
        }
        .disabled(selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview {
    NavigationStack { OfficerDashboardView() }
        .environment(SessionStore.preview())
}
