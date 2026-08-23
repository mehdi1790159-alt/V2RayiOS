//
//  V2RayiOSApp.swift
//  V2RayiOS
//
//  Created by shelikhoo on 21/02/2026.
//

import SwiftUI

@main
struct V2RayiOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // If the app was relaunched by the system due to a significant location change,
        // immediately re-engage location tracking and V2binding.
        if launchOptions?[.location] != nil {
            _ = LocationAssist.shared
            LocationAssist.shared.requestLocationAccess()
        } else {
            // Eagerly initialize so V2binding starts and location is ready
            _ = LocationAssist.shared
        }
        return true
    }
}
