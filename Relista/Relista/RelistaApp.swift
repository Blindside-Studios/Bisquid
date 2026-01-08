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

                        // Perform initial CloudKit sync (app launch)
                        print("🚀 App launched - performing initial sync")
                        do {
                            try await AgentManager.shared.refreshFromCloud()
                            try await ConversationManager.refreshConversationsFromCloud()
                        } catch {
                            print("❌ CloudKit sync error on launch: \(error)")
                        }
                    }
                }
        }
        .commands {
            // Replace default "New Window" with "New Chat" in File menu
            #if os(macOS) || os(iOS)
            CommandGroup(replacing: .newItem) {
                Button("New Chat", systemImage: "square.and.pencil") {
                    NotificationCenter.default.post(name: .createNewChat, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            #endif

            // Add refresh command to View menu (macOS and iPadOS)
            #if os(macOS) || os(iOS)
            CommandGroup(after: .sidebar) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task {
                        // Refresh from CloudKit using new sync system
                        print("🔄 Manual refresh triggered (Menu bar)")
                        try? await AgentManager.shared.refreshFromCloud()
                        try? await ConversationManager.refreshConversationsFromCloud()
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
