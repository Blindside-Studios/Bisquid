//
//  GeneralSettings.swift
//  Relista
//
//  Created by Nicolas Helbig on 30.11.25.
//

import SwiftUI

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
    @State private var legacyImportResultMessage: String?
    @State private var showingLegacyImportResult = false

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
                .disabled(true)

                Toggle("Show debug options", isOn: $showDebugOptions)
            }
        }
        .formStyle(.grouped)
        .alert(
            "Import Complete",
            isPresented: $showingLegacyImportResult,
            presenting: legacyImportResultMessage
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
                let conversations = (try? DatabaseManager.loadIndex()) ?? []
                await ChatCache.shared.updateLoadedConversations(conversations)
                legacyImportResultMessage = "Imported \(result.conversationsImported) conversation(s) and \(result.messagesImported) message(s)."
            } catch {
                legacyImportResultMessage = "Import failed: \(error.localizedDescription)"
            }
            isImportingLegacyChats = false
            showingLegacyImportResult = true
        }
    }
}

#Preview {
    GeneralSettings()
}
