//
//  ConversationManager.swift
//  Relista
//
//  Created by Nicolas Helbig on 03.11.25.
//

import Foundation

/// Mirrors the pre-SwiftData JSON shape of `Conversation`. This exists purely so
/// `ConversationManager` can still read (and, for round-tripping during migration, write)
/// the old iCloud Documents files. The live `Conversation` model no longer conforms to Codable.
private struct LegacyConversation: Codable {
    var id: UUID
    var title: String
    var lastInteracted: Date
    var modelUsed: String
    var agentUsed: UUID?
    var isArchived: Bool
    var hasMessages: Bool
    var lastModified: Date

    enum CodingKeys: String, CodingKey {
        case id, title, lastInteracted, modelUsed, agentUsed, isArchived, hasMessages, lastModified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        lastInteracted = try container.decode(Date.self, forKey: .lastInteracted)
        modelUsed = try container.decode(String.self, forKey: .modelUsed)
        agentUsed = try container.decode(UUID?.self, forKey: .agentUsed)
        isArchived = try container.decode(Bool.self, forKey: .isArchived)
        hasMessages = try container.decodeIfPresent(Bool.self, forKey: .hasMessages) ?? true
        lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date.now
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(lastInteracted, forKey: .lastInteracted)
        try container.encode(modelUsed, forKey: .modelUsed)
        try container.encode(agentUsed, forKey: .agentUsed)
        try container.encode(isArchived, forKey: .isArchived)
        try container.encode(hasMessages, forKey: .hasMessages)
        try container.encode(lastModified, forKey: .lastModified)
    }
}

/// Mirrors the pre-SwiftData JSON shape of `Message`, same reasoning as `LegacyConversation`
/// above. Reuses `MessageRole`/`MessageAnnotation`/`MessageContentBlock` since those stayed
/// Codable — they weren't part of the SwiftData conversion.
private struct LegacyMessage: Codable {
    var id: UUID
    var text: String
    var role: MessageRole
    var modelUsed: String = "Unspecified Model"
    var attachmentLinks: [String]
    var timeStamp: Date
    var lastModified: Date
    var annotations: [MessageAnnotation]?
    var contentBlocks: [MessageContentBlock]?
    var conversationID: UUID

    enum CodingKeys: String, CodingKey {
        case id, text, role, modelUsed, attachmentLinks, timeStamp, lastModified, annotations, contentBlocks, conversationID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        role = try container.decode(MessageRole.self, forKey: .role)
        modelUsed = try container.decodeIfPresent(String.self, forKey: .modelUsed) ?? "Unspecified Model"
        attachmentLinks = try container.decode([String].self, forKey: .attachmentLinks)
        timeStamp = try container.decode(Date.self, forKey: .timeStamp)
        lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date.now
        annotations = try container.decodeIfPresent([MessageAnnotation].self, forKey: .annotations)
        contentBlocks = try container.decodeIfPresent([MessageContentBlock].self, forKey: .contentBlocks)
        conversationID = try container.decodeIfPresent(UUID.self, forKey: .conversationID) ?? UUID()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(role, forKey: .role)
        try container.encode(modelUsed, forKey: .modelUsed)
        try container.encode(attachmentLinks, forKey: .attachmentLinks)
        try container.encode(timeStamp, forKey: .timeStamp)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encodeIfPresent(annotations, forKey: .annotations)
        try container.encodeIfPresent(contentBlocks, forKey: .contentBlocks)
        try container.encode(conversationID, forKey: .conversationID)
    }
}

private class ConversationManager {
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
    
    // save index.json (without messages)
    // Only saves conversations that have messages - filters out empty conversations
    static func saveIndex(conversations: [LegacyConversation]) throws {
        // Filter to only include conversations with messages
        let conversationsToSave = conversations.filter { $0.hasMessages }

        // Clean up folders for conversations that don't have messages
        let conversationsToRemove = conversations.filter { !$0.hasMessages }
        for conversation in conversationsToRemove {
            let conversationFolder = conversationsURL.appendingPathComponent(conversation.id.uuidString)
            if FileManager.default.fileExists(atPath: conversationFolder.path) {
                try? FileManager.default.removeItem(at: conversationFolder)
            }
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(conversationsToSave)
        try data.write(to: indexURL)
    }
    
    // load index.json
    static func loadIndex() throws -> [LegacyConversation] {
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            return []  // No index yet, return empty
        }

        let data = try Data(contentsOf: indexURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode([LegacyConversation].self, from: data)
    }

    // save messages for a specific conversation
    static func saveMessages(for conversationID: UUID, messages: [LegacyMessage]) throws {
        // create conversation folder if needed
        let conversationFolder = conversationsURL.appendingPathComponent(conversationID.uuidString)

        if !FileManager.default.fileExists(atPath: conversationFolder.path) {
            try FileManager.default.createDirectory(at: conversationFolder, withIntermediateDirectories: true)
        }

        // save messages.json
        let messagesURL = conversationFolder.appendingPathComponent("messages.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(messages)
        try data.write(to: messagesURL)
    }

    // load messages for a specific conversation
    static func loadMessages(for conversationID: UUID) throws -> [LegacyMessage] {
        let messagesURL = conversationsURL
            .appendingPathComponent(conversationID.uuidString)
            .appendingPathComponent("messages.json")

        guard FileManager.default.fileExists(atPath: messagesURL.path) else {
            return []  // no messages yet
        }

        let data = try Data(contentsOf: messagesURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var messages = try decoder.decode([LegacyMessage].self, from: data)

        // Backwards compatibility: Set conversationID for old messages that don't have it
        var needsResave = false
        for i in 0..<messages.count {
            if messages[i].conversationID.uuidString == "00000000-0000-0000-0000-000000000000"
                || messages[i].conversationID != conversationID {
                messages[i].conversationID = conversationID
                needsResave = true
            }
        }

        // Resave with conversationID if we updated any messages
        if needsResave {
            try saveMessages(for: conversationID, messages: messages)
        }

        return messages
    }

    // delete a conversation and all its messages
    static func deleteConversation(id: UUID) throws {
        let conversationFolder = conversationsURL.appendingPathComponent(id.uuidString)

        // Remove the entire conversation folder if it exists
        if FileManager.default.fileExists(atPath: conversationFolder.path) {
            try FileManager.default.removeItem(at: conversationFolder)
        }
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
}
