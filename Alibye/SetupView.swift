import SwiftUI
import CoreLocation
import UIKit

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
                        Text("Location Access Required")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)

                        Text("Alibye needs background location access to build your private timeline and route history.")
                            .font(.system(size: 14))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)

                        Text("To continue, set Location Access to Always.")
                            .font(.system(size: 13, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.blue)
                    }

                    VStack(spacing: 14) {
                        SetupFeatureRow(
                            icon: "1.circle.fill",
                            title: "Open Settings",
                            subtitle: "We’ll take you to the Alibye settings page."
                        )

                        SetupFeatureRow(
                            icon: "2.circle.fill",
                            title: "Tap Location",
                            subtitle: "Open the Location permission section."
                        )

                        SetupFeatureRow(
                            icon: "3.circle.fill",
                            title: "Choose Always",
                            subtitle: "This is required for full tracking to work."
                        )
                    }

                    if locationService.authorizationStatus == .authorizedWhenInUse {
                        statusCard(
                            title: "Current access: While Using",
                            message: "Alibye cannot continue until you change this to Always in Settings.",
                            color: .orange
                        )
                    } else if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
                        statusCard(
                            title: "Location access is off",
                            message: "Open Settings and set Location to Always.",
                            color: .red
                        )
                    } else if locationService.authorizationStatus == .authorizedAlways {
                        statusCard(
                            title: "You're all set",
                            message: "Always access is enabled. Continue to open Alibye.",
                            color: .green
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
                        primaryAction()
                    } label: {
                        HStack {
                            if isRequesting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: buttonIcon)
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
            if locationService.authorizationStatus == .authorizedAlways {
                appState.completeSetup()
            }
        }
        .onChange(of: locationService.authorizationStatus) { _, newValue in
            isRequesting = false
            if newValue == .authorizedAlways {
                appState.completeSetup()
            }
        }
    }

    private var buttonTitle: String {
        switch locationService.authorizationStatus {
        case .authorizedAlways:
            return "Continue"
        case .notDetermined:
            return "Allow Location Access"
        case .authorizedWhenInUse, .denied, .restricted:
            return "Open Settings"
        @unknown default:
            return "Open Settings"
        }
    }

    private var buttonIcon: String {
        switch locationService.authorizationStatus {
        case .authorizedAlways:
            return "checkmark.circle.fill"
        case .notDetermined:
            return "location.fill"
        case .authorizedWhenInUse, .denied, .restricted:
            return "gearshape.fill"
        @unknown default:
            return "gearshape.fill"
        }
    }

    private func primaryAction() {
        switch locationService.authorizationStatus {
        case .authorizedAlways:
            appState.completeSetup()

        case .notDetermined:
            isRequesting = true
            locationService.requestPermissions()

        case .authorizedWhenInUse, .denied, .restricted:
            openSettings()

        @unknown default:
            openSettings()
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    @ViewBuilder
    private func statusCard(title: String, message: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(color)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
