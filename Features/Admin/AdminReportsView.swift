import SwiftUI

/// Admin tab: every submitted report, newest first, with filter and search.
struct AdminReportsView: View {
    @State private var vm = AdminReportsViewModel()

    var body: some View {
        @Bindable var vm = vm

        VStack(spacing: 0) {
            Picker("Status", selection: $vm.filter) {
                ForEach(AdminReportsViewModel.Filter.options, id: \.self) { option in
                    Text("\(option.title) \(vm.count(for: option))").tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, 12)

            content
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $vm.search, prompt: "Search text, name or #hashtag")
        .task { await vm.observe() }   // live updates; pull-to-refresh below still works
        .refreshable { await vm.load() }
        .alert("Something went wrong",
               isPresented: Binding(get: { vm.errorMessage != nil },
                                    set: { if !$0 { vm.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    @ViewBuilder private var content: some View {
        if !vm.hasLoaded {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.visibleReports.isEmpty {
            ContentUnavailableView(
                vm.reports.isEmpty ? "No reports yet" : "No matches",
                systemImage: vm.reports.isEmpty ? "tray" : "magnifyingglass",
                description: Text(vm.reports.isEmpty
                                  ? "Reports submitted by users will show up here."
                                  : "Try a different filter or search.")
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.visibleReports) { report in
                        NavigationLink {
                            AdminReportDetailView(reportID: report.id, vm: vm)
                        } label: {
                            ReportRow(report: report)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, 16)
            }
        }
    }
}

// MARK: - Row

private struct ReportRow: View {
    let report: Report

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ReportThumbnail(data: report.imageData)
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    StatusBadge(status: report.status)
                    Spacer(minLength: 0)
                    if report.location != nil {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .accessibilityLabel("Has location")
                    }
                }
                Text(report.details.isEmpty ? "No description" : report.details)
                    .font(AppFonts.input)
                    .foregroundStyle(report.details.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)
                    .lineLimit(2)
                if !report.hashtags.isEmpty {
                    Text(report.hashtags.map { "#\($0)" }.joined(separator: " "))
                        .font(AppFonts.error)
                        .foregroundStyle(AppColors.primary)
                        .lineLimit(1)
                }
                Text("\(report.userName.isEmpty ? "Unknown" : report.userName) · \(reportDateText(report.createdAt))")
                    .font(AppFonts.error)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
        .contentShape(Rectangle())
    }
}

// MARK: - Detail

struct AdminReportDetailView: View {
    let reportID: String
    let vm: AdminReportsViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            if let report = vm.report(id: reportID) {
                VStack(alignment: .leading, spacing: AppSpacing.fieldToField) {
                    ReportThumbnail(data: report.imageData)
                        .frame(height: 280)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.inputRadius))
                        .accessibilityLabel("Photo of the issue")

                    statusSection(report)
                    detailsSection(report)

                    if !report.hashtags.isEmpty { hashtagsSection(report) }
                    if let place = report.location { locationSection(place) }

                    reporterSection(report)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, 16)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statusSection(_ report: Report) -> some View {
        block("Status") {
            HStack(spacing: 8) {
                ForEach(ReportStatus.allCases, id: \.self) { status in
                    let selected = report.status == status
                    Button {
                        Task { await vm.setStatus(status, for: report.id) }
                    } label: {
                        Text(status.title)
                            .font(AppFonts.fieldLabel)
                            .foregroundStyle(selected ? Color.white : AppColors.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(RoundedRectangle(cornerRadius: AppSpacing.inputRadius)
                                .fill(selected ? AppColors.primary : AppColors.background))
                    }
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(8)
        }
    }

    private func detailsSection(_ report: Report) -> some View {
        block("Details") {
            Text(report.details.isEmpty ? "No description provided." : report.details)
                .font(AppFonts.input)
                .foregroundStyle(report.details.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
    }

    private func hashtagsSection(_ report: Report) -> some View {
        block("Hashtags") {
            FlowLayout(spacing: 8) {
                ForEach(report.hashtags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(AppColors.primary.opacity(0.12)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }

    private func locationSection(_ place: ReportLocation) -> some View {
        block("Location") {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(format: "%.5f, %.5f  ·  ±%.0f m", place.latitude, place.longitude, place.accuracy))
                    .font(AppFonts.subtitle)
                    .foregroundStyle(AppColors.textSecondary)
                AppButton(title: "Open in Maps", style: .secondary, systemImage: "map") {
                    if let url = URL(string: "https://maps.apple.com/?ll=\(place.latitude),\(place.longitude)&q=Reported%20issue") {
                        openURL(url)
                    }
                }
            }
            .padding(16)
        }
    }

    private func reporterSection(_ report: Report) -> some View {
        block("Reported by") {
            VStack(alignment: .leading, spacing: 4) {
                Text(report.userName.isEmpty ? "Unknown" : report.userName)
                    .font(AppFonts.input)
                    .foregroundStyle(AppColors.textPrimary)
                Text(report.userEmail)
                    .font(AppFonts.subtitle)
                    .foregroundStyle(AppColors.textSecondary)
                Text(reportDateText(report.createdAt))
                    .font(AppFonts.error)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }

    private func block(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.labelToInput) {
            Text(title)
                .font(AppFonts.fieldLabel)
                .foregroundStyle(AppColors.textSecondary)
                .accessibilityAddTraits(.isHeader)
            content().appCard()
        }
    }
}

#Preview {
    NavigationStack { AdminReportsView() }.environment(SessionStore.preview())
}
