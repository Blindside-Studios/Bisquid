//
//  RelistaApp.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI
import Foundation
import SwiftData
import CoreData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

#if os(macOS)
struct TextSizeCommands: Commands {
    @AppStorage("chatFontSize") private var fontSize: Double = Font.defaultBodySize

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Divider()
            Button("Make Text Bigger", systemImage: "textformat.size.larger") { fontSize = min(fontSize + 1, 24) }
                .keyboardShortcut("+", modifiers: .command)
            Button("Make Text Smaller", systemImage: "textformat.size.smaller") { fontSize = max(fontSize - 1, 9) }
                .keyboardShortcut("-", modifiers: .command)
            Button("Make Text Normal Size", systemImage: "textformat.size") { fontSize = Font.defaultBodySize }
                .keyboardShortcut("0", modifiers: .command)
        }
    }
}
#endif

@main
struct RelistaApp: App {
    @State private var hasInitialized = false
    @Environment(\.scenePhase) private var scenePhase

    /// The single SwiftData store for the app, mirrored to CloudKit's private database.
    /// `DatabaseManager` reaches this via `RelistaApp.sharedModelContainer.mainContext` —
    /// there is deliberately only ever one context in play so every read/write sees the
    /// same in-memory state without needing to merge across contexts.
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Conversation.self,
            Message.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        #if os(iOS)
        // BGTaskScheduler.register(...) must be called exactly once per launch,
        // before the app finishes launching.
        ChatCache.shared.registerBackgroundTasks()
        #endif

        // Without this, CloudKit has no push token to reach this device with, so
        // NSPersistentCloudKitContainer (which SwiftData uses under the hood) only ever
        // reconciles remote changes on cold launch instead of while the app is running.
        // No delegate/payload handling needed — the container listens for these itself.
        #if os(iOS)
        UIApplication.shared.registerForRemoteNotifications()
        #elseif os(macOS)
        NSApplication.shared.registerForRemoteNotifications()
        #endif

        RelistaApp.startObservingRemoteChanges()
    }

    /// Fires whenever CloudKit imports a change into the local store — this is the only
    /// way ChatCache finds out about an edit made on another device while this one is
    /// already running, since its `conversations`/`messages` arrays are one-time fetches,
    /// not a live `@Query`. Debounced because CloudKit can post this many times in a burst
    /// (a single sync pass, or later our own bulk import).
    private static var remoteChangeTask: Task<Void, Never>?

    static func startObservingRemoteChanges() {
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { _ in
            remoteChangeTask?.cancel()
            remoteChangeTask = Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }

                let conversations = (try? DatabaseManager.loadIndex()) ?? []
                await ChatCache.shared.updateLoadedConversations(conversations)
                await ChatCache.shared.refreshLoadedMessages()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(reloadSidebar: RelistaApp.refreshContent)
                .onAppear {
                    // Only initialize once
                    guard !hasInitialized else { return }
                    hasInitialized = true

                    Task {
                        print(URL.documentsDirectory.path)
                        await ModelList.loadModels()
                    }
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            Task{
                await RelistaApp.refreshContent()
            }
        }
        .modelContainer(RelistaApp.sharedModelContainer)
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
                        await RelistaApp.refreshContent()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            #endif

            #if os(macOS)
            TextSizeCommands()
            #endif
        }

        #if os(macOS)
        Settings {
            SettingsView(storedSelection: "General")
                //.frame(minWidth: 400, idealWidth: 400, maxWidth: 400, minHeight: 500, idealHeight: 680)
                .frame(width: 600, height: 680)
        }
        .windowResizability(.contentSize)

        WindowGroup("Squidlet Editor", id: "agentEditor", for: AgentEditorLaunch.self) { $launch in
            AgentEditorWindowContent(launch: launch ?? .create(token: UUID()))
                .frame(width: 450)
                .frame(minHeight: 560, idealHeight: 680, maxHeight: 900)
        }
        .windowResizability(.contentSize)
        .windowLevel(.floating)
        #endif
    }
    
    public static func refreshContent() async{
        ChatCache.shared.loadingProgress = 0.0
        ChatCache.shared.isLoading = true
        print("Refreshing agents and chats")
        await ensureICloudUpToDate()
        await AgentManager.shared.refreshFromStorage()
        ChatCache.shared.loadingProgress = 0.9
        // Re-fetch from the local SwiftData store and merge anything new into ChatCache.
        // Covers the case where a CloudKit-driven change arrived while the app wasn't
        // actively observing it (e.g. resumed from suspension while offline).
        let conversations = (try? DatabaseManager.loadIndex()) ?? []
        await ChatCache.shared.updateLoadedConversations(conversations)
        ChatCache.shared.loadingProgress = 1.0
        ChatCache.shared.isLoading = false
    }

    // Agents still live in iCloud Documents (agents.json) — not migrated to SwiftData yet.
    static func ensureICloudUpToDate() async {
        guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.Blindside-Studios.Relista") else {
            print("iCloud not available")
            return
        }

        let relistaURL = iCloudURL.appendingPathComponent("Documents").appendingPathComponent("Relista")

        let agentsURL = relistaURL.appendingPathComponent("agents.json")

        ChatCache.shared.loadingProgress = 0.1

        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: agentsURL)

            ChatCache.shared.loadingProgress = 0.2

            try await waitForDownload(url: agentsURL)
            ChatCache.shared.loadingProgress = 0.8

            print("✅ iCloud files are now current")
        } catch {
            print("❌ iCloud sync error: \(error)")
        }
    }

    private static func waitForDownload(url: URL) async throws {
        while true {
            let resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            
            if let status = resourceValues.ubiquitousItemDownloadingStatus {
                switch status {
                case .current:
                    print("✅ \(url.lastPathComponent) is current")
                    return
                case .downloaded:
                    print("⏳ \(url.lastPathComponent) downloaded, checking if current...")
                    break
                case .notDownloaded:
                    print("⬇️ \(url.lastPathComponent) downloading...")
                    break
                default:
                    break
                }
            }
            
            // man this is a weird solution
            try await Task.sleep(for: .milliseconds(100))
        }
    }}

extension Font {
    static var defaultBodySize: CGFloat {
        #if os(macOS)
        NSFont.preferredFont(forTextStyle: .body).pointSize
        #else
        UIFont.preferredFont(forTextStyle: .body).pointSize
        #endif
    }
}
