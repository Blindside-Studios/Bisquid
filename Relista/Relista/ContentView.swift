//
//  ContentView.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct ContentView: View {
    @State var showingSettings: Bool = false
    @State var conversations: [Conversation] = []
    @State var selectedConversation = Conversation(id: 0, title: "New Conversation", uuid: UUID(), messages: [], lastInteracted: Date.now, modelUsed: "mistral-3b-latest", isArchived: false)

    // Helper to sync conversation - can be called from child views
    func syncConversation() {
        syncSelectedConversation()
    }

    var body: some View {
        NavigationSplitView {
            ScrollView{
                ForEach (conversations) { conv in
                    HStack{
                        Text(conv.title)
                        Spacer()
                    }
                    .padding(8)
                    .background(selectedConversation === conv ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.clear))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 4)
                    .padding(.vertical, -4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        loadConversation(conv)
                    }
                }
            }
            .navigationTitle("Chats")
        } detail: {
            ChatWindow(conversation: selectedConversation, onConversationChanged: syncSelectedConversation)
        }
        .onAppear(){
            do {
                try ConversationManager.initializeStorage()
                conversations = try ConversationManager.loadIndex()
            } catch {
                print("Error loading: \(error)")
            }
        }
        .onChange(of: selectedConversation, syncSelectedConversation)
        
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        #endif
    }
    
    func loadConversation(_ conv: Conversation) {
        do {
            // Since Conversation is now a class, we directly modify it
            conv.messages = try ConversationManager.loadMessages(for: conv.uuid)
            selectedConversation = conv
        } catch {
            print("Error loading messages: \(error)")
        }
    }
    
    func syncSelectedConversation(){
        if selectedConversation.messages.count > 0 { // do not attempt to save when the conversation is blank
            if let index = conversations.firstIndex(where: { $0.uuid == selectedConversation.uuid }) {
                // Since it's a class, the conversation in the array is already updated by reference
                // We just need to ensure the reference is correct
                if conversations[index] !== selectedConversation {
                    conversations[index] = selectedConversation
                }
            } else {
                // New conversation - add to list
                selectedConversation.id = conversations.count
                conversations.append(selectedConversation)
            }

            // Save index
            do {
                try ConversationManager.saveIndex(conversations: conversations)
            } catch {
                print("Error saving index: \(error)")
            }
        }
    }
}

#Preview {
    //ContentView(selectedConversation: Conversation(from: <#any Decoder#>))
}
