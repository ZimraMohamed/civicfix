import SwiftUI
import MapKit


struct ReportsMapView: View {
    @State private var vm = ReportsMapViewModel()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasFitted = false
    @Environment(SessionStore.self) private var session

  
    private var canEdit: Bool {
        session.profile?.isAdmin == true || session.profile?.isOfficer == true
    }

    var body: some View {
        @Bindable var vm = vm

        VStack(spacing: 0) {
            filterBar
            mapContent
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.observe() }
        .refreshable { await vm.load() }
        .sheet(item: $vm.selectedReport) { report in
            ReportMapDetailSheet(report: report, canEdit: canEdit) { status in
                Task { await vm.setStatus(status, for: report.id) }
            }
        }
        .alert("Something went wrong",
               isPresented: Binding(get: { vm.errorMessage != nil },
                                    set: { if !$0 { vm.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private var filterBar: some View {
        @Bindable var vm = vm
        return Picker("Status", selection: $vm.filter) {
            ForEach(ReportsMapViewModel.Filter.options, id: \.self) { option in
                Text("\(option.title) \(vm.count(for: option))").tag(option)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.vertical, 12)
    }

    @ViewBuilder private var mapContent: some View {
        if vm.permissionDenied {
            ContentUnavailableView(
                "No access yet",
                systemImage: "lock.fill",
                description: Text("The map will appear here once you have read access to reports.")
            )
        } else if !vm.hasLoaded {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.mappableReports.isEmpty {
            ContentUnavailableView(
                vm.reports.isEmpty ? "No reports yet" : "No mappable reports",
                systemImage: vm.reports.isEmpty ? "map" : "mappin.slash",
                description: Text(vm.reports.isEmpty
                                  ? "Reports with a location will appear as pins here."
                                  : "None of the current reports include a location.")
            )
        } else {
            map
        }
    }

    private var map: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $cameraPosition) {
                UserAnnotation()
                ForEach(vm.mappableReports) { report in
                    if let loc = report.location {
                        Annotation(report.details.isEmpty ? "Report" : report.details,
                                   coordinate: CLLocationCoordinate2D(latitude: loc.latitude,
                                                                     longitude: loc.longitude)) {
                            StatusMarker(status: report.status,
                                         isSelected: vm.selectedReport?.id == report.id)
                                .onTapGesture { vm.selectedReport = report }
                        }
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onChange(of: vm.mappableReports.count) { _, count in
                // Fit all pins the first time they appear.
                if count > 0, !hasFitted, let region = fittedRegion(for: vm.mappableReports) {
                    cameraPosition = .region(region)
                    hasFitted = true
                }
            }

            Button {
                if let region = fittedRegion(for: vm.mappableReports) {
                    cameraPosition = .region(region)
                }
            } label: {
                Image(systemName: "scope")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(AppColors.surface))
                    .overlay(Circle().stroke(AppColors.border, lineWidth: 1))
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }
            .accessibilityLabel("Fit all reports on screen")
            .padding(16)
        }
    }
}

// MARK: - Pin

private struct StatusMarker: View {
    let status: ReportStatus
    let isSelected: Bool

    private var color: Color {
        switch status {
        case .open: AppColors.error
        case .inProgress: .orange
        case .resolved: AppColors.success
        }
    }

    var body: some View {
        Image(systemName: status.systemImage)
            .font(.callout.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(Circle().fill(color))
            .overlay(Circle().stroke(.white, lineWidth: isSelected ? 3 : 2))
            .scaleEffect(isSelected ? 1.15 : 1)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .animation(.spring(duration: 0.25), value: isSelected)
    }
}

// MARK: - Bottom sheet

private struct ReportMapDetailSheet: View {
    let report: Report
    let canEdit: Bool
    let onStatusChange: (ReportStatus) -> Void

    @Environment(SessionStore.self) private var session
    @Environment(\.openURL) private var openURL

    /// Public users don't see the reporter's name or email.
    private var anonymizeReporter: Bool {
        !(session.profile?.isAdmin == true || session.profile?.isOfficer == true)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ReportThumbnail(data: report.imageData)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.inputRadius))

                HStack {
                    StatusBadge(status: report.status)
                    Spacer(minLength: 0)
                    Text(reportDateText(report.createdAt))
                        .font(AppFonts.error)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Text(report.details.isEmpty ? "No description" : report.details)
                    .font(AppFonts.input)
                    .foregroundStyle(report.details.isEmpty
                                     ? AppColors.textSecondary : AppColors.textPrimary)

                if !report.hashtags.isEmpty {
                    Text(report.hashtags.map { "#\($0)" }.joined(separator: " "))
                        .font(AppFonts.error)
                        .foregroundStyle(AppColors.primary)
                }

                if let loc = report.location {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(format: "%.5f, %.5f  ·  ±%.0f m",
                                    loc.latitude, loc.longitude, loc.accuracy))
                            .font(AppFonts.subtitle)
                            .foregroundStyle(AppColors.textSecondary)
                        AppButton(title: "Open in Maps", style: .secondary, systemImage: "map") {
                            if let url = URL(string: "https://maps.apple.com/?ll=\(loc.latitude),\(loc.longitude)&q=Reported%20issue") {
                                openURL(url)
                            }
                        }
                    }
                }

                if !anonymizeReporter {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(report.userName.isEmpty ? "Unknown" : report.userName)
                            .font(AppFonts.input)
                            .foregroundStyle(AppColors.textPrimary)
                        Text(report.userEmail)
                            .font(AppFonts.subtitle)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.top, 4)
                }

                if canEdit {
                    HStack(spacing: 8) {
                        ForEach(ReportStatus.allCases, id: \.self) { status in
                            let selected = report.status == status
                            Button {
                                onStatusChange(status)
                            } label: {
                                Text(status.title)
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
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(AppColors.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    NavigationStack { ReportsMapView() }
        .environment(SessionStore.preview())
}
