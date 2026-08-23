//
//  ContentView.swift
//  Testing
//
//  Created by Shell on 6/26/21.
//

import SwiftUI
import CoreLocation
import V2binding
internal import Combine

struct ContentView: View {
    @StateObject private var locationAssist = LocationAssist.shared

    var body: some View {
        VStack(spacing: 16) {
            Text("The V2Ray/V2Fly instance should be running in background.\nLocation is required for it to stay in background.")
                .padding()

            Text("Location Status: \(locationAssist.statusText)")
                .font(.footnote)
                .foregroundColor(.secondary)

            Button("Open UI in Browser") {
                if let url = URL(string: "http://127.0.0.1:18888") {
                    UIApplication.shared.open(url)
                }
            }.padding()

            Button("Enable Location Access") {
                locationAssist.requestLocationAccess()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

class LocationAssist: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationAssist()

    private let locationManager = CLLocationManager()
    private var backgroundActivitySession: CLBackgroundActivitySession?
    private var serviceSession: CLServiceSession?

    @Published var statusText = "Not started"

    private static var v2bindingStarted = false

    override init() {
        super.init()
        locationManager.delegate = self
        startV2Binding()
        observeAppLifecycle()
    }

    private func startV2Binding() {
        guard !LocationAssist.v2bindingStarted else { return }
        LocationAssist.v2bindingStarted = true
        let documentPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        V2bindingStartAPIInstance(documentPath)
    }

    private func observeAppLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func appDidEnterBackground() {
        // Reinforce background sessions when entering background
        startBackgroundSessions()
    }

    @objc private func appWillEnterForeground() {
        // Ensure location updates are still active
        ensureLocationUpdatesActive()
    }

    func requestLocationAccess() {
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            // Request "Always" so background location works without the blue bar requirement
            locationManager.requestAlwaysAuthorization()
        case .authorizedWhenInUse:
            // Upgrade to Always if currently only WhenInUse
            locationManager.requestAlwaysAuthorization()
            startLocationUpdates()
        case .authorizedAlways:
            startLocationUpdates()
        case .restricted, .denied:
            statusText = "Location denied - enable in Settings"
        @unknown default:
            locationManager.requestAlwaysAuthorization()
        }
    }

    private func startLocationUpdates() {
        // Use lowest power consumption that still keeps the app alive
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true

        // Critical: prevent iOS from pausing location updates to save power
        locationManager.pausesLocationUpdatesAutomatically = false

        // Hint to iOS that this is not navigation — reduces system priority
        // but avoids auto-pause behavior tied to automotive/fitness activities
        locationManager.activityType = .automotiveNavigation

        // Start continuous location updates (primary keep-alive mechanism)
        locationManager.startUpdatingLocation()

        // Start significant location change monitoring as a fallback.
        // This survives app termination — iOS will relaunch the app on significant moves.
        locationManager.startMonitoringSignificantLocationChanges()

        startBackgroundSessions()

        statusText = "Active (background enabled)"
    }

    private func startBackgroundSessions() {
        // CLBackgroundActivitySession tells the system we need continued background runtime
        if backgroundActivitySession == nil {
            backgroundActivitySession = CLBackgroundActivitySession()
        }
        // CLServiceSession keeps the location subsystem engaged
        if serviceSession == nil {
            serviceSession = CLServiceSession(authorization: .always)
        }
    }

    private func ensureLocationUpdatesActive() {
        let status = locationManager.authorizationStatus
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            if !locationManager.allowsBackgroundLocationUpdates {
                startLocationUpdates()
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        switch status {
        case .authorizedAlways:
            statusText = "Authorized (Always)"
            startLocationUpdates()
        case .authorizedWhenInUse:
            statusText = "Authorized (When In Use) - tap button again for Always"
            startLocationUpdates()
        case .denied:
            statusText = "Location denied - enable in Settings"
        case .restricted:
            statusText = "Location restricted"
        case .notDetermined:
            statusText = "Waiting for authorization"
        @unknown default:
            statusText = "Unknown authorization status"
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Intentionally minimal — we only need location updates running to stay alive.
        // No-op keeps CPU usage negligible.
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Location errors are non-fatal; the system will keep delivering updates.
        // Restarting here could cause a tight loop if the error persists.
    }
}
