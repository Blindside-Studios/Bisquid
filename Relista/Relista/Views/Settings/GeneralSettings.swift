//
//  GeneralSettings.swift
//  Relista
//
//  Created by Nicolas Helbig on 30.11.25.
//

import SwiftUI
import UniformTypeIdentifiers

struct GeneralSettings: View {
    #if os(macOS)
    @AppStorage("AddPaddingToTypingBar") private var typingBarPaddingMacOS: Bool = true
    #endif
    @AppStorage("ShowUserMessageToolbars") private var showUserMessageToolbars: Bool = false
    @AppStorage("AlwaysShowFullModelMessageToolbar") private var alwaysShowFullModelMessageToolbar: Bool = false
    @AppStorage("AlwaysShowChainOfThought") private var alwaysShowCOT: Bool = true
    #if os(iOS)
    @AppStorage("HapticFeedbackForMessageGeneration") private var vibrateOnTokensReceived: Bool = true
    #endif
    @AppStorage("ApplyBackgroundBisquidTheme") private var useBisquidBackground: Bool = true
    @AppStorage("AnimateAgentJellyfishBackgtround") private var jellyfishAnimations: Bool = true
    @AppStorage("AnimateUserMessageBackdropOnGeneration") private var userMessageAnimation: Bool = true
    @AppStorage("SmartGroundingEnabled") private var smartGroundingEnabled: Bool = true
    @StateObject private var syncedSettings = SyncedSettings.shared
    
    @AppStorage("EnableUIDebugControls") private var showDebugOptions: Bool = false

    @State private var isImportingLegacyChats = false
    @State private var operationResultMessage: String?
    @State private var showingOperationResult = false

    @State private var showingBackupExporter = false
    @State private var backupExportDocument: BackupDocument?
    @State private var showingBackupImporter = false
    @State private var pendingRestoreData: Data?
    @State private var showingRestoreConfirmation = false
    @State private var isRestoringBackup = false

    var body: some View {
        Form{
            Section(header: Text("Interface"), footer: Text("This adds Bisquid's own color to the app background to avoid pure black and white on iOS. This will disable window background tinting on macOS and iPadOS.")){
                #if os(macOS)
                Toggle("Add extra padding to the input bar", isOn: $typingBarPaddingMacOS)
                #endif
                Toggle("Animate \"Jellyfish\" background when choosing an agent", isOn: $jellyfishAnimations)
                Toggle("Play animation during response generation", isOn: $userMessageAnimation)
                Toggle("Tint background with Bisquid theme colors", isOn: $useBisquidBackground)
            }

            Section(header: Text("Response Display"), footer: Text("Only applies to bigger screens where information is displayed in-line")){
                Toggle("Show user message toolbars", isOn: $showUserMessageToolbars)
                Toggle("Always show Chain of Thought", isOn: $alwaysShowCOT)
                Toggle("Always show time and model", isOn: $alwaysShowFullModelMessageToolbar)
            }

            Section(
                header: Text("Smart Grounding"),
                footer: Text("Smart Grounding runs a small background model before each reply to quietly inject relevant background facts into the conversation. Web search increases latency but helps with time-sensitive questions.")
            ){
                Toggle("Enable Smart Grounding", isOn: $smartGroundingEnabled)
                Toggle("Let Smart Grounding use web search", isOn: $syncedSettings.smartGroundingUseWebSearch)
                    .disabled(!smartGroundingEnabled)
            }

            Section(
                header: Text("Backup"),
                footer: Text("Export saves every conversation, agent, and synced setting to a single file. Restoring replaces everything currently in Relista with the contents of that file — it does not merge.")
            ) {
                Button {
                    exportBackup()
                } label: {
                    Text("Export Backup…")
                }

                Button {
                    showingBackupImporter = true
                } label: {
                    HStack {
                        Text("Restore from Backup…")
                        if isRestoringBackup {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isRestoringBackup)
            }

            // haptic feedback only applies to iPhone
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                Section(header: Text("Haptic Feedback")){
                    Toggle("Haptic feedback during response generation", isOn: $vibrateOnTokensReceived)
                }
            }
            #endif
            
            Section(header: Text("Debug"), footer: Text("Shows debug options meant to test features and animations without streaming responses. Currently limited to a button in the user message context menu to force the stream message animation")){
                Button {
                    importLegacyChats()
                } label: {
                    HStack {
                        Text("Import Legacy iCloud Chats")
                        if isImportingLegacyChats {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                //.disabled(isImportingLegacyChats)
                .disabled(false)

                Toggle("Show debug options", isOn: $showDebugOptions)
            }
        }
        .formStyle(.grouped)
        .fileExporter(
            isPresented: $showingBackupExporter,
            document: backupExportDocument,
            contentType: .json,
            defaultFilename: "Relista Backup"
        ) { result in
            if case .failure(let error) = result {
                operationResultMessage = "Export failed: \(error.localizedDescription)"
                showingOperationResult = true
            }
            backupExportDocument = nil
        }
        .fileImporter(
            isPresented: $showingBackupImporter,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url) else {
                    operationResultMessage = "Couldn't read that file."
                    showingOperationResult = true
                    return
                }
                pendingRestoreData = data
                showingRestoreConfirmation = true
            case .failure(let error):
                operationResultMessage = "Restore failed: \(error.localizedDescription)"
                showingOperationResult = true
            }
        }
        .alert(
            "Replace Everything?",
            isPresented: $showingRestoreConfirmation,
            presenting: pendingRestoreData
        ) { data in
            Button("Cancel", role: .cancel) {
                pendingRestoreData = nil
            }
            Button("Restore", role: .destructive) {
                performRestore(from: data)
            }
        } message: { _ in
            Text("This deletes every conversation, Squidlet, and synced setting currently in Relista and replaces them with the contents of this backup. This can't be undone.")
        }
        .alert(
            "Import Complete",
            isPresented: $showingOperationResult,
            presenting: operationResultMessage
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private func importLegacyChats() {
        isImportingLegacyChats = true
        Task {
            do {
                let result = try LegacyImporter.importIntoDatabase()
                let agentsImported = try LegacyImporter.importAgents()

                let conversations = (try? DatabaseManager.loadIndex()) ?? []
                await ChatCache.shared.updateLoadedConversations(conversations)
                await AgentManager.shared.refreshFromStorage()

                operationResultMessage = "Imported \(result.conversationsImported) conversation(s), \(result.messagesImported) message(s), and \(agentsImported) agent(s)."
            } catch {
                operationResultMessage = "Import failed: \(error.localizedDescription)"
            }
            isImportingLegacyChats = false
            showingOperationResult = true
        }
    }

    private func exportBackup() {
        do {
            backupExportDocument = BackupDocument(data: try BackupManager.exportBackup())
            showingBackupExporter = true
        } catch {
            operationResultMessage = "Export failed: \(error.localizedDescription)"
            showingOperationResult = true
        }
    }

    private func performRestore(from data: Data) {
        pendingRestoreData = nil
        isRestoringBackup = true
        Task {
            do {
                let result = try await BackupManager.restoreBackup(from: data)
                operationResultMessage = "Restored \(result.conversations) conversation(s), \(result.messages) message(s), and \(result.agents) agent(s)."
            } catch {
                operationResultMessage = "Restore failed: \(error.localizedDescription)"
            }
            isRestoringBackup = false
            showingOperationResult = true
        }
    }
}

#Preview {
    GeneralSettings()
}
