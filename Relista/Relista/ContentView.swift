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

    // Live state — mirrors persisted conversation ID but is the binding source
    // downstream views consume. Hydrated in .task from the scene store.
    @State private var selectedConversationID: UUID = UUID()
    @State private var hasRestoredConversation = false

    // Lifted from PromptField/ChatWindow so they survive layout changes
    // (size class flips, rotation, iPadOS window resize). Deliberately *not*
    // scene-stored per user request — they reset between launches.
    @State private var editingMessage: Message? = nil
    @State private var pendingAttachments: [PendingAttachment] = []

    @State var chatCache = ChatCache.shared
    let reloadSidebar: () async -> Void

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
            Sidebar(chatCache: $chatCache, selectedConversationID: $selectedConversationID, selectedAgent: selectedAgent, selectedModel: $selectedModel, createNewChat: createNewChat, reloadSidebar: reloadSidebar, shownContentType: shownContentType)
        } content: {
            switch shownContentType.wrappedValue {
            case .documentAI:
                DocumentAI()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            case .audioAI:
                AudioAI()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            default:
                ChatWindow(conversationID: $selectedConversationID, inputMessage: $inputMessage, selectedAgent: selectedAgent, selectedModel: $selectedModel, editingMessage: $editingMessage, pendingAttachments: $pendingAttachments)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .toolbar(){
                        ToolbarItemGroup() {
                            Button("New chat", systemImage: "square.and.pencil"){
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
               let uuid = UUID(uuidString: persistedConversationIDString) {
                selectedConversationID = uuid
            } else {
                let result = ConversationManager.createNewConversation(fromID: nil)
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
    }

    private func createNewChat() {
        let prevChat = ChatCache.shared.conversations.first(where: { $0.id == selectedConversationID })
        debugPrint("prevChat != nil: \(prevChat != nil) prevChat.hasMessages: \(prevChat!.hasMessages)")
        let result = ConversationManager.createNewConversation(fromID: selectedConversationID, usingAgent: prevChat != nil && prevChat!.hasMessages, withAgent: selectedAgent.wrappedValue)
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
    case documentAI
    case audioAI
}

#Preview {
    //ContentView(selectedConversation: Conversation(from: <#any Decoder#>))
}
