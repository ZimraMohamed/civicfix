import SwiftUI
import PhotosUI
import MapKit

/// Public users file a report here: photo from the camera, optional location, details and hashtags.
struct ReportView: View {
    @State private var vm = ReportViewModel()
    @State private var showCamera = false
    @State private var showCameraUnavailable = false
    @State private var showPicker = false
    @State private var libraryItem: PhotosPickerItem?
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var vm = vm

        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.fieldToField) {
                section("Photo") { photoContent }
                section("Location") { locationContent }
                section("Details") { detailsContent }
                section("Hashtags") { hashtagContent }

                if let error = vm.errorMessage {
                    Text(error).font(AppFonts.error).foregroundStyle(AppColors.error)
                }

                AppButton(title: "Submit Report", isLoading: vm.isSubmitting,
                          isDisabled: vm.image == nil) {
                    Task { await vm.submit() }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Report an Issue")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if vm.shareLocation && vm.location.location == nil { vm.location.request() } }
        .onChange(of: vm.shareLocation) { _, on in if on { vm.location.request() } }
        .onChange(of: vm.details) { _, text in
            if text.count > ReportViewModel.maxDetailsLength {
                vm.details = String(text.prefix(ReportViewModel.maxDetailsLength))
            }
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let picked = UIImage(data: data) {
                    vm.image = picked
                }
                libraryItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { vm.image = $0 }.ignoresSafeArea()
        }
        .alert("Camera unavailable", isPresented: $showCameraUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device has no camera (the Simulator never does). Choose a photo from your library instead.")
        }
        .alert("Report submitted", isPresented: $vm.didSubmit) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thank you! Your report has been sent.")
        }
        .sensoryFeedback(.success, trigger: vm.didSubmit) { _, new in new }
        .sheet(isPresented: $showPicker) {
            LocationPickerView(initial: vm.location.location) { place in
                vm.location.setManual(place)
            }
            .presentationDetents([.large])
        }
    }

    // MARK: - Photo

    @ViewBuilder private var photoContent: some View {
        if let image = vm.image {
            ZStack(alignment: .bottomTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .accessibilityLabel("Photo of the issue")

                Button { openCamera() } label: {
                    Label("Retake", systemImage: "camera.fill")
                        .font(AppFonts.fieldLabel)
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.inputRadius))
        } else {
            VStack(spacing: 14) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 44))
                    .foregroundStyle(AppColors.primary)
                    .accessibilityHidden(true)
                Text("Take a clear photo of the problem")
                    .font(AppFonts.subtitle)
                    .foregroundStyle(AppColors.textSecondary)
                AppButton(title: "Take Photo", systemImage: "camera.fill") { openCamera() }
                PhotosPicker(selection: $libraryItem, matching: .images) {
                    Text("Choose from library")
                        .font(AppFonts.fieldLabel)
                        .foregroundStyle(AppColors.primary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
        }
    }

    private func openCamera() {
        if CameraPicker.isAvailable { showCamera = true } else { showCameraUnavailable = true }
    }

    // MARK: - Location

    @ViewBuilder private var locationContent: some View {
        @Bindable var vm = vm

        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $vm.shareLocation) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Share my location")
                        .font(AppFonts.input)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Helps the team find the issue")
                        .font(AppFonts.error)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .tint(AppColors.primary)

            if vm.shareLocation { locationStatus }
        }
        .padding(16)
    }

    @ViewBuilder private var locationStatus: some View {
        switch vm.location.status {
        case .idle, .locating:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Getting your location…")
                        .font(AppFonts.subtitle)
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer(minLength: 0)
                }
                // Always offer the manual pick — works even while GPS is still locating,
                // so the simulator (or a slow device) never blocks the user.
                Button {
                    showPicker = true
                } label: {
                    Label("Pick on map instead", systemImage: "mappin.and.ellipse")
                        .font(AppFonts.fieldLabel)
                        .foregroundStyle(AppColors.primary)
                }
            }
        case .ready:
            if let place = vm.location.location {
                let coordinate = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)))
                ) {
                    Marker("Issue location", coordinate: coordinate)
                }
                .id("\(place.latitude),\(place.longitude)")
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .allowsHitTesting(false)
                .accessibilityLabel("Map showing your current location")

                HStack {
                    Text(String(format: "%.5f, %.5f  ·  ±%.0f m", place.latitude, place.longitude, place.accuracy))
                        .font(AppFonts.error)
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer(minLength: 0)
                    Button("Change") { showPicker = true }
                        .font(AppFonts.fieldLabel)
                        .foregroundStyle(AppColors.primary)
                }
            }
        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                Text("Location access is off. Turn it on in Settings, pick a spot on the map, or switch sharing off to submit without it.")
                    .font(AppFonts.error)
                    .foregroundStyle(AppColors.error)
                HStack(spacing: 16) {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .font(AppFonts.fieldLabel)
                    .foregroundStyle(AppColors.primary)

                    Button {
                        showPicker = true
                    } label: {
                        Label("Pick on map", systemImage: "mappin.and.ellipse")
                            .font(AppFonts.fieldLabel)
                            .foregroundStyle(AppColors.primary)
                    }
                }
            }
        case .failed:
            VStack(alignment: .leading, spacing: 8) {
                Text("Couldn’t get your location. Try again, or pick a spot on the map.")
                    .font(AppFonts.error)
                    .foregroundStyle(AppColors.error)
                HStack(spacing: 16) {
                    Button("Try again") { vm.location.request() }
                        .font(AppFonts.fieldLabel)
                        .foregroundStyle(AppColors.primary)

                    Button {
                        showPicker = true
                    } label: {
                        Label("Pick on map", systemImage: "mappin.and.ellipse")
                            .font(AppFonts.fieldLabel)
                            .foregroundStyle(AppColors.primary)
                    }
                }
            }
        }
    }

    // MARK: - Details

    @ViewBuilder private var detailsContent: some View {
        @Bindable var vm = vm

        VStack(alignment: .trailing, spacing: 6) {
            TextField("", text: $vm.details,
                      prompt: Text("Describe the problem (optional)").foregroundStyle(AppColors.placeholder),
                      axis: .vertical)
                .lineLimit(3...6)
                .font(AppFonts.input)
                .foregroundStyle(AppColors.textPrimary)
            Text("\(vm.details.count)/\(ReportViewModel.maxDetailsLength)")
                .font(AppFonts.error)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(16)
    }

    // MARK: - Hashtags

    @ViewBuilder private var hashtagContent: some View {
        @Bindable var vm = vm

        VStack(alignment: .leading, spacing: 14) {
            FlowLayout(spacing: 8) {
                ForEach(vm.visibleTags, id: \.self) { chip($0) }
            }

            HStack(spacing: 8) {
                TextField("", text: $vm.tagInput,
                          prompt: Text("Add your own, e.g. #brokenbench").foregroundStyle(AppColors.placeholder))
                    .font(AppFonts.input)
                    .foregroundStyle(AppColors.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { vm.addTagsFromInput() }

                Button { vm.addTagsFromInput() } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppColors.primary)
                }
                .disabled(vm.tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Add hashtag")
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.background))
        }
        .padding(16)
    }

    private func chip(_ tag: String) -> some View {
        let selected = vm.hashtags.contains(tag)
        return Button { vm.toggle(tag) } label: {
            Text("#\(tag)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(selected ? Color.white : AppColors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(selected ? AppColors.primary : AppColors.background))
                .overlay(Capsule().stroke(selected ? Color.clear : AppColors.border, lineWidth: 1))
        }
        .accessibilityLabel("Hashtag \(tag)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Layout helper

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
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
    NavigationStack { ReportView() }.environment(SessionStore.preview())
}
