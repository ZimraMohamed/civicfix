import SwiftUI
import MapKit


struct LocationPickerView: View {
  
    var onPicked: (ReportLocation) -> Void

    @State private var cameraPosition: MapCameraPosition
    @State private var picked: CLLocationCoordinate2D?
   
    private let manualAccuracy: Double = 30
    @Environment(\.dismiss) private var dismiss

    
    init(initial: ReportLocation? = nil, onPicked: @escaping (ReportLocation) -> Void) {
        self.onPicked = onPicked
        let coord = initial.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            ?? CLLocationCoordinate2D(latitude: 37.3327, longitude: -122.0053)
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
    }

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                ZStack(alignment: .bottom) {
                    Map(position: $cameraPosition) {
                        if let picked {
                            Marker("Selected location", coordinate: picked)
                        }
                    }
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                        MapScaleView()
                    }
                    .onTapGesture { location in
                        if let coord = proxy.convert(location, from: .local) {
                            picked = coord
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)

                    VStack(spacing: 12) {
                        if let picked {
                            Text(String(format: "%.5f, %.5f", picked.latitude, picked.longitude))
                                .font(AppFonts.subtitle)
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(AppColors.surface))
                        } else {
                            Text("Tap the map to pick a location.")
                                .font(AppFonts.subtitle)
                                .foregroundStyle(AppColors.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(AppColors.surface))
                        }

                        AppButton(title: "Use this location", isDisabled: picked == nil) {
                            guard let picked else { return }
                            onPicked(ReportLocation(
                                latitude: picked.latitude,
                                longitude: picked.longitude,
                                accuracy: manualAccuracy
                            ))
                            dismiss()
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Pick location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    LocationPickerView(onPicked: { _ in })
}
