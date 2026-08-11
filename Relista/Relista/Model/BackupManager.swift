//
//  BackupManager.swift
//  Relista
//
//  Created by Nicolas Helbig on 11.08.26.
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Backup format

/// Everything a fresh install/environment can't get back on its own: conversations,
/// messages, agents, and the iCloud-KVS-backed settings in SyncedSettings.
struct BackupBundle: Codable {
    static let currentVersion = 1

    var version: Int = BackupBundle.currentVersion
    var createdAt: Date = Date.now

    var conversations: [ConversationBackup]
    var messages: [MessageBackup]
    var agents: [Agent]
    var settings: SettingsBackup
}

/// Mirrors Conversation for JSON round-tripping — same reasoning as LegacyConversation in
/// ConversationManager.swift: the live @Model class isn't Codable.
struct ConversationBackup: Codable {
    var id: UUID
    var title: String
    var lastInteracted: Date
    var modelUsed: String
    var agentUsed: UUID?
    var isArchived: Bool
    var hasMessages: Bool
    var lastModified: Date

    init(_ conversation: Conversation) {
        id = conversation.id
        title = conversation.title
        lastInteracted = conversation.lastInteracted
        modelUsed = conversation.modelUsed
        agentUsed = conversation.agentUsed
        isArchived = conversation.isArchived
        hasMessages = conversation.hasMessages
        lastModified = conversation.lastModified
    }

    func makeConversation() -> Conversation {
        Conversation(
            id: id,
            title: title,
            lastInteracted: lastInteracted,
            modelUsed: modelUsed,
            agentUsed: agentUsed,
            isArchived: isArchived,
            hasMessages: hasMessages,
            lastModified: lastModified
        )
    }
}

/// Mirrors Message for JSON round-tripping — same reasoning as MessageBackup above.
struct MessageBackup: Codable {
    var id: UUID
    var text: String
    var role: MessageRole
    var modelUsed: String
    var attachmentLinks: [String]
    var timeStamp: Date
    var lastModified: Date
    var annotations: [MessageAnnotation]?
    var contentBlocks: [MessageContentBlock]?
    var conversationID: UUID

    init(_ message: Message) {
        id = message.id
        text = message.text
        role = message.role
        modelUsed = message.modelUsed
        attachmentLinks = message.attachmentLinks
        timeStamp = message.timeStamp
        lastModified = message.lastModified
        annotations = message.annotations
        contentBlocks = message.contentBlocks
        conversationID = message.conversationID
    }

    func makeMessage() -> Message {
        Message(
            id: id,
            text: text,
            role: role,
            modelUsed: modelUsed,
            attachmentLinks: attachmentLinks,
            timeStamp: timeStamp,
            lastModified: lastModified,
            annotations: annotations,
            contentBlocks: contentBlocks,
            conversationID: conversationID
        )
    }
}

struct SettingsBackup: Codable {
    var defaultModel: String
    var defaultInstructions: String
    var userName: String
    var memories: [String]
    var temperature: Double
    var suppressEmDashes: Bool
    var wikiEntries: [WikiEntry]
    var smartGroundingUseWebSearch: Bool
    var useExplicitPromptCaching: Bool
}

// MARK: - Export / Restore

enum BackupManager {
    @MainActor
    static func exportBackup() throws -> Data {
        let context = RelistaApp.sharedModelContainer.mainContext
        let settings = SyncedSettings.shared

        let bundle = BackupBundle(
            conversations: try context.fetch(FetchDescriptor<Conversation>()).map(ConversationBackup.init),
            messages: try context.fetch(FetchDescriptor<Message>()).map(MessageBackup.init),
            agents: try context.fetch(FetchDescriptor<Agent>(sortBy: [SortDescriptor(\.sortOrder)])),
            settings: SettingsBackup(
                defaultModel: settings.defaultModel,
                defaultInstructions: settings.defaultInstructions,
                userName: settings.userName,
                memories: settings.memories,
                temperature: settings.temperature,
                suppressEmDashes: settings.suppressEmDashes,
                wikiEntries: settings.wikiEntries,
                smartGroundingUseWebSearch: settings.smartGroundingUseWebSearch,
                useExplicitPromptCaching: settings.useExplicitPromptCaching
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(bundle)
    }

    /// Deletes every conversation, message, and agent, then replaces them (and the synced
    /// settings) with the contents of `data`. This is a full restore, not a merge — call
    /// sites are responsible for confirming with the user before calling this.
    @MainActor
    @discardableResult
    static func restoreBackup(from data: Data) async throws -> (conversations: Int, messages: Int, agents: Int) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let bundle = try decoder.decode(BackupBundle.self, from: data)

        let context = RelistaApp.sharedModelContainer.mainContext

        // Drop in-memory references before touching the context — same ordering
        // ChatCache.deleteConversation relies on (see its comment there) to avoid the
        // "detached from context without resolving attribute faults" crash.
        ChatCache.shared.resetAllLoadedState()
        AgentManager.shared.removeAllLocally()

        for message in try context.fetch(FetchDescriptor<Message>()) {
            context.delete(message)
        }
        for conversation in try context.fetch(FetchDescriptor<Conversation>()) {
            context.delete(conversation)
        }
        for agent in try context.fetch(FetchDescriptor<Agent>()) {
            context.delete(agent)
        }
        try context.save()

        for conversationBackup in bundle.conversations {
            context.insert(conversationBackup.makeConversation())
        }
        for messageBackup in bundle.messages {
            context.insert(messageBackup.makeMessage())
        }
        for agent in bundle.agents {
            context.insert(agent)
        }
        try context.save()

        let settings = SyncedSettings.shared
        settings.defaultModel = bundle.settings.defaultModel
        settings.defaultInstructions = bundle.settings.defaultInstructions
        settings.userName = bundle.settings.userName
        settings.memories = bundle.settings.memories
        settings.temperature = bundle.settings.temperature
        settings.suppressEmDashes = bundle.settings.suppressEmDashes
        settings.wikiEntries = bundle.settings.wikiEntries
        settings.smartGroundingUseWebSearch = bundle.settings.smartGroundingUseWebSearch
        settings.useExplicitPromptCaching = bundle.settings.useExplicitPromptCaching

        let conversations = (try? DatabaseManager.loadIndex()) ?? []
        ChatCache.shared.updateLoadedConversations(conversations)
        await AgentManager.shared.refreshFromStorage()

        return (bundle.conversations.count, bundle.messages.count, bundle.agents.count)
    }
}

// MARK: - File picker document

/// Thin `FileDocument` wrapper so `.fileExporter` has something to hand a save panel —
/// the actual content is just the encoded `BackupBundle` JSON.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
