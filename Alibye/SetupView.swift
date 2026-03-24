import SwiftUI
import CoreLocation

struct SetupView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var locationService: LocationService

    @State private var isRequesting = false

    private let privacyPolicyURL = URL(string: "https://example.com/privacy")!

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.20),
                    Color.cyan.opacity(0.12),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 20)

                VStack(spacing: 22) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 120, height: 120)

                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 58))
                            .foregroundStyle(.blue)
                    }

                    VStack(spacing: 10) {
                        Text("Welcome to Alibye")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)

                        Text("To build your private timeline and route history, Alibye needs access to your location.")
                            .font(.system(size: 17))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                    }

                    VStack(spacing: 14) {
                        SetupFeatureRow(
                            icon: "clock.arrow.circlepath",
                            title: "Daily timeline",
                            subtitle: "Track your visits and movement throughout the day."
                        )

                        SetupFeatureRow(
                            icon: "map.fill",
                            title: "Live route history",
                            subtitle: "See your paths on the map as you move."
                        )

                        SetupFeatureRow(
                            icon: "lock.shield.fill",
                            title: "Private by design",
                            subtitle: "Your data stays on your device unless you choose otherwise later."
                        )
                    }
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: .black.opacity(0.10), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 20)

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        requestLocationAccess()
                    } label: {
                        HStack {
                            if isRequesting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "location.fill")
                            }

                            Text(buttonTitle)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.large)
                    .padding(.horizontal, 20)

                    Link(destination: privacyPolicyURL) {
                        Text("Privacy Policy")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .underline()
                    }
                    .padding(.bottom, 18)
                }
            }
        }
        .onAppear {
            if locationService.authorizationStatus == .authorizedAlways || locationService.authorizationStatus == .authorizedWhenInUse {
                appState.completeSetup()
            }
        }
        .onChange(of: locationService.authorizationStatus) { _, newValue in
            if newValue == .authorizedAlways || newValue == .authorizedWhenInUse {
                isRequesting = false
                appState.completeSetup()
            }
        }
    }

    private var buttonTitle: String {
        switch locationService.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return "Continue"
        case .denied, .restricted:
            return "Open Settings"
        case .notDetermined:
            return "Allow Location Access"
        @unknown default:
            return "Continue"
        }
    }

    private func requestLocationAccess() {
        switch locationService.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            appState.completeSetup()

        case .denied, .restricted:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }

        case .notDetermined:
            isRequesting = true
            locationService.requestPermissions()

        @unknown default:
            locationService.requestPermissions()
        }
    }
}

private struct SetupFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 36, height: 36)
                .background(Color.blue.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}
