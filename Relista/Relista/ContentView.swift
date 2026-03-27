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

@MainActor
class ContentViewModel: ObservableObject {
    @Published var selectedConversationID: UUID
    
    init() {
        print("🔴 ContentViewModel.init() called - should only happen ONCE")
        let result = ConversationManager.createNewConversation(fromID: nil)
        self.selectedConversationID = result.newChatUUID
    }
}

struct ContentView: View {
    @State var shownContentType: ContentType = .chat
    
    @State var showingSettings: Bool = false
    @State var chatCache = ChatCache.shared
    @StateObject private var viewModel = ContentViewModel()
    //@State var selectedConversationID: UUID = ConversationManager.createNewConversation(fromID: nil).newChatUUID
    @State var inputMessage = "" // put this here so switching between layouts doesn't clear it

    @State var selectedAgent: UUID? = nil
    @State var selectedModel: String = ModelList.placeHolderModel
    let reloadSidebar: () async -> Void
    
    var body: some View {
        UnifiedSplitView {
            Sidebar(showingSettings: $showingSettings, chatCache: $chatCache, selectedConversationID: $viewModel.selectedConversationID, selectedAgent: $selectedAgent, selectedModel: $selectedModel, createNewChat: createNewChat, reloadSidebar: reloadSidebar, shownContentType: $shownContentType)
        } content: {
            switch(shownContentType){
            case .documentAI:
                DocumentAI()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            case .audioAI:
                AudioAI()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            default:
                ChatWindow(conversationID: $viewModel.selectedConversationID, inputMessage: $inputMessage, selectedAgent: $selectedAgent, selectedModel: $selectedModel)
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
        .animation(.default, value: shownContentType)
        .onReceive(NotificationCenter.default.publisher(for: .createNewChat)) { _ in
            createNewChat()
        }
    }
    
    private func createNewChat() {
        let prevChat = ChatCache.shared.conversations.first(where: { $0.id == viewModel.selectedConversationID })
        debugPrint("prevChat != nil: \(prevChat != nil) prevChat.hasMessages: \(prevChat!.hasMessages)")
        let result = ConversationManager.createNewConversation(fromID: viewModel.selectedConversationID, usingAgent: prevChat != nil && prevChat!.hasMessages, withAgent: selectedAgent)
        viewModel.selectedConversationID = result.newChatUUID
        selectedAgent = result.newAgent
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
