//
//  ChatCache.swift
//  Relista
//
//  Created by Nicolas Helbig on 07.11.25.
//

import Foundation
import Observation

/// Represents a loaded chat in memory with its messages and metadata
@Observable
class LoadedChat: Identifiable {
    let id: UUID
    var messages: [Message]
    var isGenerating: Bool
    var isBeingViewed: Bool

    init(id: UUID, messages: [Message] = [], isGenerating: Bool = false, isBeingViewed: Bool = false) {
        self.id = id
        self.messages = messages
        self.isGenerating = isGenerating
        self.isBeingViewed = isBeingViewed
    }
}

/// Manages chat state and message generation for all conversations
/// This centralizes chat data so it can be accessed and modified even when not actively displayed
@Observable
class ChatCache {
    static let shared = ChatCache()

    /// All conversations (metadata only)
    var conversations: [Conversation] = []

    /// Dictionary mapping conversation IDs to their loaded chat data
    private(set) var loadedChats: [UUID: LoadedChat] = [:]

    /// Currently active/viewed conversation ID
    var activeConversationID: UUID?

    private init() {
        // Load conversations from disk on init
        do {
            try ConversationManager.initializeStorage()
            conversations = try ConversationManager.loadIndex()
        } catch {
            print("Error loading conversations: \(error)")
        }
    }

    // MARK: - Conversation Management

    /// Gets a conversation by ID
    func getConversation(for id: UUID) -> Conversation? {
        return conversations.first(where: { $0.id == id })
    }

    /// Creates a new conversation (not shown in sidebar until first message is sent)
    func createConversation(modelUsed: String = "ministral-3b-latest") -> Conversation {
        let newConversation = Conversation(
            id: UUID(),
            title: "New Conversation",
            lastInteracted: Date.now,
            modelUsed: modelUsed,
            isArchived: false,
            hasMessages: false
        )

        conversations.append(newConversation)
        return newConversation
    }

    /// Syncs a conversation (saves index and updates metadata)
    func syncConversation(id: UUID) {
        guard let conversation = getConversation(for: id) else { return }
        let chat = getChat(for: id)

        // Update title from first message if conversation is new
        if chat.messages.count > 0 && conversation.title == "New Conversation" {
            conversation.title = chat.messages[0].text
        }

        // Save index
        do {
            try ConversationManager.saveIndex(conversations: conversations)
        } catch {
            print("Error saving conversation index: \(error)")
        }
    }

    /// Renames a conversation
    func renameConversation(id: UUID, to newTitle: String) {
        guard let conversation = getConversation(for: id) else { return }
        conversation.title = newTitle

        do {
            try ConversationManager.saveIndex(conversations: conversations)
        } catch {
            print("Error saving renamed conversation: \(error)")
        }
    }

    /// Deletes a conversation
    func deleteConversation(id: UUID) {
        // Unload from cache
        unloadChat(id: id)

        // Remove from array
        if let index = conversations.firstIndex(where: { $0.id == id }) {
            conversations.remove(at: index)
        }

        // Delete from disk
        do {
            try ConversationManager.deleteConversation(id: id)
            try ConversationManager.saveIndex(conversations: conversations)
        } catch {
            print("Error deleting conversation: \(error)")
        }
    }

    // MARK: - Chat Loading/Unloading

    /// Loads or retrieves a chat from cache
    func getChat(for id: UUID) -> LoadedChat {
        if let existing = loadedChats[id] {
            return existing
        }

        // Load from disk if not in memory
        do {
            let messages = try ConversationManager.loadMessages(for: id)
            let chat = LoadedChat(id: id, messages: messages)
            loadedChats[id] = chat
            return chat
        } catch {
            print("Error loading chat \(id): \(error)")
            // Return empty chat if load fails
            let chat = LoadedChat(id: id)
            loadedChats[id] = chat
            return chat
        }
    }

    /// Marks a chat as being actively viewed
    func setViewing(id: UUID, isViewing: Bool) {
        let chat = getChat(for: id)
        chat.isBeingViewed = isViewing

        if isViewing {
            activeConversationID = id
        } else if activeConversationID == id {
            activeConversationID = nil
        }

        // Unload chats that are no longer needed
        cleanupUnusedChats()
    }

    /// Removes chats from memory that aren't being viewed or generating
    private func cleanupUnusedChats() {
        let idsToRemove = loadedChats.filter { id, chat in
            !chat.isBeingViewed && !chat.isGenerating
        }.map { $0.key }

        for id in idsToRemove {
            loadedChats.removeValue(forKey: id)
        }
    }

    /// Forces a chat to be unloaded from memory
    func unloadChat(id: UUID) {
        guard let chat = loadedChats[id] else { return }

        // Only unload if not being viewed or generating
        if !chat.isBeingViewed && !chat.isGenerating {
            loadedChats.removeValue(forKey: id)
        }
    }

    // MARK: - Message Generation

    /// Sends a message and generates a response in the background
    /// Returns immediately, updates happen asynchronously via Observable updates
    func sendMessage(
        _ text: String,
        to conversationID: UUID,
        apiKey: String,
        onCompletion: (() -> Void)? = nil
    ) {
        let chat = getChat(for: conversationID)
        guard let conversation = getConversation(for: conversationID) else { return }

        // If this is the first message, mark conversation as having messages
        if chat.messages.isEmpty {
            conversation.hasMessages = true
            // Save index immediately so it appears in sidebar
            do {
                try ConversationManager.saveIndex(conversations: conversations)
            } catch {
                print("Error saving conversation index: \(error)")
            }
        }

        // Add user message
        let userMsg = Message(
            id: UUID(),
            text: text,
            role: .user,
            attachmentLinks: [],
            timeStamp: .now
        )
        chat.messages.append(userMsg)

        // Save user message immediately
        saveMessages(for: conversationID)

        // Start generation
        chat.isGenerating = true

        Task {
            do {
                let service = MistralService(apiKey: apiKey)
                let stream = try await service.streamMessage(messages: chat.messages)

                // Create blank assistant message
                let assistantMsg = Message(
                    id: UUID(),
                    text: "",
                    role: .assistant,
                    attachmentLinks: [],
                    timeStamp: .now
                )

                await MainActor.run {
                    chat.messages.append(assistantMsg)
                }

                let assistantIndex = chat.messages.count - 1

                // Stream response chunks
                for try await chunk in stream {
                    await MainActor.run {
                        // Update message text
                        var updatedMessage = chat.messages[assistantIndex]
                        updatedMessage.text += chunk
                        chat.messages[assistantIndex] = updatedMessage
                    }
                }

                // Generation complete - save and cleanup
                await MainActor.run {
                    chat.isGenerating = false

                    // Update conversation metadata
                    if let conversation = getConversation(for: conversationID) {
                        conversation.lastInteracted = Date.now
                    }

                    saveMessages(for: conversationID)
                    syncConversation(id: conversationID)
                    onCompletion?()

                    // Clean up if chat is no longer needed
                    cleanupUnusedChats()
                }

            } catch {
                await MainActor.run {
                    chat.isGenerating = false
                    print("Error generating message: \(error)")
                    cleanupUnusedChats()
                }
            }
        }
    }

    // MARK: - Persistence

    func saveMessages(for id: UUID) {
        guard let chat = loadedChats[id] else { return }

        do {
            try ConversationManager.saveMessages(for: id, messages: chat.messages)
        } catch {
            print("Error saving messages for \(id): \(error)")
        }
    }
}
