//
//  ChatWindow.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct ChatWindow: View {
    @Binding var conversationID: UUID
    @Binding var inputMessage: String
    @Binding var selectedAgent: UUID?
    @Binding var selectedModel: String
    @Binding var editingMessage: Message?
    @Binding var pendingAttachments: [PendingAttachment]
    @State private var chatCache = ChatCache.shared

    @AppStorage("chatFontSize") private var chatFontSize: Double = Font.defaultBodySize

    @State private var scrollWithAnimation = true
    @State private var primaryAccentColor: Color = .clear
    @State private var secondaryAccentColor: Color = .primary
    @State private var topMessageID: UUID?

    var body: some View {
        ZStack{
            ChatBackground(selectedAgent: $selectedAgent, selectedChat: $conversationID, primaryAccentColor: $primaryAccentColor, secondaryAccentColor: $secondaryAccentColor)
                //.ignoresSafeArea(edges: .top)
                //.ignoresSafeArea()
            
            GeometryReader { geo in
                // Access chat directly from cache - it's loaded in .task
                if let chat = chatCache.loadedChats[conversationID] {
                    let sortedMessages = chat.messages.sorted { $0.timeStamp < $1.timeStamp }
                    ScrollViewReader { proxy in
                        ScrollView(.vertical){
                            VStack{
                                ForEach(sortedMessages){ message in
                                    if(message.role == .assistant){
                                        MessageModel(message: message, onRegenerate: {
                                            let model = ModelList.getModelFromSlug(slug: message.modelUsed)
                                            var apiKey = ""
                                            switch model.provider {
                                            case .mistral: apiKey = KeychainHelper.shared.mistralAPIKey
                                            case .anthropic: apiKey = KeychainHelper.shared.claudeAPIKey
                                            default: return
                                            }
                                            chatCache.regenerateMessage(
                                                messageID: message.id,
                                                modelName: message.modelUsed,
                                                agent: chatCache.getConversation(for: conversationID)?.agentUsed,
                                                apiKey: apiKey,
                                                for: conversationID,
                                                tools: ToolRegistry.enabledTools(for: chatCache.getConversation(for: conversationID)?.agentUsed, conversationID: conversationID)
                                            )
                                        })
                                        .frame(minHeight: message.id == sortedMessages.last!.id ? geo.size.height * 0.8 : 0, alignment: .top)
                                        .id(message.id)
                                    }
                                    else if (message.role == .user || message.role == .system){
                                        MessageUser(message: message, availableWidth: geo.size.width, onEdit: {
                                            editingMessage = message
                                        }, primaryAccentColor: $primaryAccentColor)
                                        .frame(minHeight: message.id == sortedMessages.last!.id ? geo.size.height : 0)
                                        .id(message.id)
                                    }
                                }
                            }
                            .scrollTargetLayout()
                            .environment(\.font, .system(size: chatFontSize))
                            // to center-align
                            .frame(maxWidth: .infinity)
                            .frame(maxWidth: 740 + max(0, (chatFontSize - 13) / (24 - 13)) * (geo.size.width - 740))
                            .frame(maxWidth: .infinity)
                        }
                        .scrollPosition(id: $topMessageID, anchor: .top)
                        .scrollDismissesKeyboard(.interactively)
                        .contentShape(Rectangle())
                        .simultaneousGesture(TapGesture().onEnded {
                            #if os(iOS)
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            #endif
                        })
                        .safeAreaBar(edge: .bottom, spacing: 0){
                            InputUI(conversationID: $conversationID, inputMessage: $inputMessage, selectedAgent: $selectedAgent, selectedModel: $selectedModel, primaryAccentColor: $primaryAccentColor, secondaryAccentColor: $secondaryAccentColor, editingMessage: $editingMessage, pendingAttachments: $pendingAttachments)
                        }
                        .onChange(of: conversationID) { _, _ in
                            // scroll to last user/system message when switching conversations
                            if let lastUserMessage = chat.messages.sorted(by: { $0.timeStamp < $1.timeStamp }).last(where: { $0.role == .user || $0.role == .system }) {
                                proxy.scrollTo(lastUserMessage.id, anchor: .top)
                            }
                        }
                        .onChange(of: chat.messages.last?.id) { _, newLastMessageID in
                            guard let lastMessage = chat.messages.last,
                                  lastMessage.role == .user || lastMessage.role == .system else {
                                return
                            }
                            withAnimation(.easeInOut(duration: scrollWithAnimation ? 0.35 : 0)) {
                                proxy.scrollTo(newLastMessageID, anchor: .top)
                            }
                        }
                        .onChange(of: topMessageID) { _, new in
                            // Persist scroll position so it survives ChatWindow rebuilds
                            // (e.g., when UnifiedSplitView swaps view trees on iPad rotation).
                            if let new {
                                chatCache.lastTopMessageID[conversationID] = new
                            }
                        }
                        .onAppear {
                            // Restore scroll position if we have one saved for this conversation.
                            // Setting topMessageID drives scrollPosition's binding, which scrolls
                            // the view to the saved message.
                            if let saved = chatCache.lastTopMessageID[conversationID] {
                                topMessageID = saved
                            }
                        }
                    }
                } else {
                    // Chat loading or not found
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task(id: conversationID) {
            // Load the chat when the view appears or conversation changes
            _ = chatCache.getChat(for: conversationID)
        }
        #if os(iOS)
        .onChange(of: chatCache.getConversation(for: conversationID)?.title, initial: true) { _, title in
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                scene.title = title ?? "New chat"
            }
        }
        #endif
        .navigationTitle(chatCache.getConversation(for: conversationID)?.title ?? "New chat")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    //func chatChanged(){
    //    scrollWithAnimation = false
    //}
    //
    //func textChanged(){
    //    scrollWithAnimation = true
    //}
}

#Preview {
    //ChatWindow(conversation: Conversation(from: <#any Decoder#>))
}
