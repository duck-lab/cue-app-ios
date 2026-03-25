//
//  cude_appApp.swift
//  cude-app
//
//  Created by Oliver.W on 2026/3/25.
//

import SwiftUI
import SwiftData

@main
struct cude_appApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var runtime = AppRuntime()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(runtime.modelContainer)
                .environmentObject(runtime)
                .onAppear {
                    runtime.pollingScheduler.start()
                }
                .onDisappear {
                    runtime.pollingScheduler.stop()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                runtime.pollingScheduler.resume()
            case .inactive, .background:
                runtime.pollingScheduler.pause()
            @unknown default:
                runtime.pollingScheduler.pause()
            }
        }
    }
}
