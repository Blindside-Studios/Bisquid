//
//  RelistaApp.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

@main
struct RelistaApp: App {
    @State private var hasInitialized = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Only initialize once
                    guard !hasInitialized else { return }
                    hasInitialized = true

                    Task {
                        await ModelList.loadModels()

                        // Perform initial CloudKit sync
                        do {
                            try await CloudKitSyncManager.shared.performFullSync()
                        } catch {
                            print("CloudKit sync error: \(error)")
                        }
                    }
                }
        }
        .commands {
            // Add refresh command to View menu (macOS and iPadOS)
            #if os(macOS) || os(iOS)
            CommandGroup(after: .sidebar) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task {
                        try? await CloudKitSyncManager.shared.performFullSync()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            #endif
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
