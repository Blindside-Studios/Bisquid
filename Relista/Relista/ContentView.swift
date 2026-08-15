//
//  ContentView.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI
import Combine

// notification for menu bar commands
extension Notification.Name {
    static let createNewChat = Notification.Name("createNewChat")
}

struct ContentView: View {
    // Scene-persisted drafts — survive memory eviction and scene restoration.
    @SceneStorage("content.conversationID") private var persistedConversationIDString: String = ""
    @SceneStorage("content.inputMessage") private var inputMessage: String = ""
    @SceneStorage("content.selectedAgentID") private var selectedAgentIDString: String = ""
    @SceneStorage("content.selectedModel") private var selectedModel: String = ModelList.placeHolderModel
    @SceneStorage("content.shownContentType") private var shownContentTypeRaw: String = ContentType.chat.rawValue

    // Sheet-presentation state, shared by key with SidebarToolSelector/AgentSettings
    // (which merely toggle these). The sheets themselves are presented here, on
    // UnifiedSplitView's stable parent, rather than from inside the sidebar/content
    // subtree — that subtree switches between ChatSplitView and NavigationSplitView
    // on size-class changes (e.g. iPhone rotation), which tears down and rebuilds it,
    // forcibly dismissing any sheet presented from within it. A sheet presented from
    // this stable ancestor survives that rebuild untouched.
    @SceneStorage("sidebar.showingSettings") private var showingSettings: Bool = false
    @SceneStorage("agents.showCreateSheet") private var showCreateAgentSheet: Bool = false
    @SceneStorage("agents.editingAgentID") private var editingAgentIDString: String = ""
    @ObservedObject private var agentManager = AgentManager.shared

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var hSizeClass
    #endif

    private var editingAgentBinding: Binding<Agent?> {
        Binding(
            get: {
                guard !editingAgentIDString.isEmpty,
                      let uuid = UUID(uuidString: editingAgentIDString) else { return nil }
                return agentManager.customAgents.first { $0.id == uuid }
            },
            set: { newValue in
                editingAgentIDString = newValue?.id.uuidString ?? ""
            }
        )
    }

    // Live state — mirrors persisted conversation ID but is the binding source
    // downstream views consume. Hydrated in .task from the scene store.
    @State private var selectedConversationID: UUID = UUID()
    @State private var hasRestoredConversation = false

    // Lifted from PromptField/ChatWindow so they survive layout changes
    // (size class flips, rotation, iPadOS window resize). Deliberately *not*
    // scene-stored per user request — they reset between launches.
    @State private var editingMessage: Message? = nil
    @State private var pendingAttachments: [PendingAttachment] = []
    
    @State var showInkingInput = false

    @State var chatCache = ChatCache.shared
    //let reloadSidebar: () async -> Void = RelistaApp.refreshContent

    private var selectedAgent: Binding<UUID?> {
        Binding(
            get: {
                guard !selectedAgentIDString.isEmpty else { return nil }
                return UUID(uuidString: selectedAgentIDString)
            },
            set: { selectedAgentIDString = $0?.uuidString ?? "" }
        )
    }

    private var shownContentType: Binding<ContentType> {
        Binding(
            get: { ContentType(rawValue: shownContentTypeRaw) ?? .chat },
            set: { shownContentTypeRaw = $0.rawValue }
        )
    }

    var body: some View {
        UnifiedSplitView {
            Sidebar(chatCache: $chatCache, selectedConversationID: $selectedConversationID, selectedAgent: selectedAgent, selectedModel: $selectedModel, createNewChat: createNewChat, /*reloadSidebar: reloadSidebar,*/ shownContentType: shownContentType)
        } content: {
            switch shownContentType.wrappedValue {
            /*case .documentAI:
                DocumentAI()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            case .audioAI:
                AudioAI()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())*/
            case .agents:
                AgentSettings()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            case .wikis:
                WikisSettings()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            default:
                ChatWindow(conversationID: $selectedConversationID, inputMessage: $inputMessage, selectedAgent: selectedAgent, selectedModel: $selectedModel, editingMessage: $editingMessage, pendingAttachments: $pendingAttachments, useInkingInput: $showInkingInput)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .toolbar(){
                        ToolbarItemGroup() {
                            #if os(iOS)
                            if UIDevice.current.userInterfaceIdiom == .pad{
                                Button("Use Pencil Input", systemImage: showInkingInput ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle"){
                                    showInkingInput.toggle()
                                }
                            }
                            #endif
                            Button("New Chat", systemImage: "square.and.pencil"){
                                createNewChat()
                            }
                        }
                    }
            }
        }
        .animation(.default, value: shownContentType.wrappedValue)
        .onReceive(NotificationCenter.default.publisher(for: .createNewChat)) { _ in
            createNewChat()
        }
        .task {
            guard !hasRestoredConversation else { return }
            hasRestoredConversation = true

            if !persistedConversationIDString.isEmpty,
               let uuid = UUID(uuidString: persistedConversationIDString),
               chatCache.getConversation(for: uuid) != nil {
                selectedConversationID = uuid
                chatCache.setViewing(id: uuid, isViewing: true)
            } else {
                // Either no persisted UUID, or the persisted UUID points to a
                // conversation that was never saved (new-but-unsent chats are
                // filtered out of index.json by saveIndex). Start fresh.
                let result = DatabaseManager.createNewConversation(fromID: nil)
                selectedConversationID = result.newChatUUID
                persistedConversationIDString = result.newChatUUID.uuidString
            }
        }
        .onChange(of: selectedConversationID) { _, newValue in
            persistedConversationIDString = newValue.uuidString
            // Draft edit/attachments are per-conversation; clear on switch.
            editingMessage = nil
            pendingAttachments = []
        }
        #if os(iOS)
        .sheet(isPresented: $showingSettings) {
            SettingsView(storedSelection: hSizeClass == .compact ? "" : "General", onClose: { showingSettings = false })
                .presentationSizing(.page)
        }
        .sheet(item: editingAgentBinding) { agent in
            AgentEditorView(agent: agent)
                .presentationSizing(.page)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showCreateAgentSheet) {
            AgentEditorView()
                .presentationSizing(.page)
                .interactiveDismissDisabled()
        }
        #endif
    }

    private func createNewChat() {
        let prevChat = ChatCache.shared.conversations.first(where: { $0.id == selectedConversationID })
        debugPrint("prevChat != nil: \(prevChat != nil) prevChat.hasMessages: \(prevChat!.hasMessages)")
        let result = DatabaseManager.createNewConversation(fromID: selectedConversationID, usingAgent: prevChat != nil && prevChat!.hasMessages, withAgent: selectedAgent.wrappedValue)
        selectedConversationID = result.newChatUUID
        selectedAgent.wrappedValue = result.newAgent
        if result.newAgent != nil {
            let agent = AgentManager.getAgent(fromUUID: result.newAgent!)
            if agent != nil {
                selectedModel = agent!.model
            }
            else{
                selectedModel = SyncedSettings.shared.defaultModel
            }
        }
        else{
            selectedModel = SyncedSettings.shared.defaultModel
        }
    }
}

public enum ContentType: String, Codable {
    case chat
    case agents
    case wikis
    //case documentAI
    //case audioAI
    }

#Preview {
    //ContentView(selectedConversation: Conversation(from: <#any Decoder#>))
}
