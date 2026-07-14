//
//  ConversationManager.swift
//  Relista
//
//  Created by Nicolas Helbig on 14.07.26.
//

import Foundation
import SwiftData

class DatabaseManager {
    /// The one shared context every read/write goes through — see the note on
    /// `RelistaApp.sharedModelContainer` for why there's only ever one.
    private static var context: ModelContext {
        RelistaApp.sharedModelContainer.mainContext
    }

    // MARK: - File System URLs

    /// Returns the iCloud Documents container URL, falling back to local Documents if unavailable
    private static let relistaURL: URL = {
        let fileManager = FileManager.default

        // Try to get iCloud container
        if let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: "iCloud.Blindside-Studios.Relista") {
            let documentsURL = iCloudURL.appendingPathComponent("Documents").appendingPathComponent("Relista")
            print("☁️ Using iCloud storage: \(documentsURL.path)")
            return documentsURL
        }

        // Fallback to local Documents
        let localURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Relista")
        print("📁 Using local storage (iCloud unavailable): \(localURL.path)")
        return localURL
    }()
    
    static var conversationsURL: URL {
        relistaURL.appendingPathComponent("conversations")
    }
    
    private static var indexURL: URL {
        relistaURL.appendingPathComponent("index.json")
    }
    
    // create folder structure if it doesn't yet exist
    static func initializeStorage() throws {
        let fileManager = FileManager.default
        
        // create Relista folder
        if !fileManager.fileExists(atPath: relistaURL.path) {
            try fileManager.createDirectory(at: relistaURL, withIntermediateDirectories: true)
        }
        
        // create conversations folder
        if !fileManager.fileExists(atPath: conversationsURL.path) {
            try fileManager.createDirectory(at: conversationsURL, withIntermediateDirectories: true)
        }
    }
    
    // Only conversations that have messages get inserted into the store — a freshly
    // created "New Conversation" placeholder stays purely in-memory (ChatCache.conversations)
    // until the first message flips hasMessages to true, so it never syncs to other devices.
    static func saveIndex(conversations: [Conversation]) throws {
        for conversation in conversations where conversation.hasMessages {
            // Safe to call even if already tracked by this context — existing objects
            // are just a no-op here, so this only actually does something for new ones.
            context.insert(conversation)
        }
        try context.save()
    }
    
    // fetch every conversation currently in the local store
    static func loadIndex() throws -> [Conversation] {
        try context.fetch(FetchDescriptor<Conversation>())
    }
    
    // save messages for a specific conversation
    static func saveMessages(for conversationID: UUID, messages: [Message]) throws {
        for message in messages {
            context.insert(message)
        }
        try context.save()
    }

    // load messages for a specific conversation
    static func loadMessages(for conversationID: UUID) throws -> [Message] {
        // A fetch has no inherent order, unlike the old JSON array where append order was
        // reading order for free — sort by timeStamp explicitly to keep the chat readable.
        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate { $0.conversationID == conversationID },
            sortBy: [SortDescriptor(\.timeStamp)]
        )
        return try context.fetch(descriptor)
    }

    // delete a conversation and all its messages
    static func deleteConversation(id: UUID) throws {
        // Remove the attachments folder (images are still plain files, not in the store)
        let conversationFolder = conversationsURL.appendingPathComponent(id.uuidString)
        if FileManager.default.fileExists(atPath: conversationFolder.path) {
            try FileManager.default.removeItem(at: conversationFolder)
        }

        // Unlike the old JSON index, simply not referencing a Conversation anymore doesn't
        // delete it from the store — it has to be removed from the context explicitly, or
        // it (and its messages) would keep existing and syncing forever.
        let messageDescriptor = FetchDescriptor<Message>(predicate: #Predicate { $0.conversationID == id })
        for message in try context.fetch(messageDescriptor) {
            context.delete(message)
        }

        let conversationDescriptor = FetchDescriptor<Conversation>(predicate: #Predicate { $0.id == id })
        for conversation in try context.fetch(conversationDescriptor) {
            context.delete(conversation)
        }

        try context.save()
    }
    
    static func createNewConversation(fromID: UUID?, usingAgent: Bool = false, withAgent: UUID? = nil) -> (newChatUUID: UUID, newAgent: UUID?) {
        // Unmark previous conversation as being viewed
        var agent: UUID? = nil
        if usingAgent { agent = withAgent }
        if let previousID = fromID {
            ChatCache.shared.setViewing(id: previousID, isViewing: false)
        }

        // Create new conversation
        let newConversation = ChatCache.shared.createConversation(agentUsed: agent)
        let newConvID = newConversation.id

        // Mark new conversation as being viewed
        ChatCache.shared.setViewing(id: newConvID, isViewing: true)

        return (newChatUUID: newConvID, newAgent: agent)
    }

    // MARK: - Refresh from Storage

    /// Reload conversations from disk (call after iCloud sync updates files)
    static func refreshConversationsFromStorage() async {
        print("🔄 Refreshing conversations from storage...")

        let conversations = (try? loadIndex()) ?? []

        // Update ChatCache with refreshed data
        await ChatCache.shared.updateLoadedConversations(conversations)

        print("✅ Conversations refreshed: \(conversations.count) total")
    }
}
