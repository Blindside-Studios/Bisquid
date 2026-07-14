//
//  Conversation.swift
//  Relista
//
//  Created by Nicolas Helbig on 03.11.25.
//

import Foundation
import SwiftData

@Model
final class Conversation: Identifiable {
    var id: UUID = UUID()
    var title: String = "New Conversation"
    var lastInteracted: Date = Date.now
    var modelUsed: String = "mistralai/mistral-medium-3.1"
    var agentUsed: UUID?
    var isArchived: Bool = false
    var hasMessages: Bool = false
    var lastModified: Date = Date.now

    // Note: messages are looked up by conversationID via DatabaseManager, not a SwiftData relationship

    init(id: UUID = UUID(), title: String, lastInteracted: Date = Date(), modelUsed: String, agentUsed: UUID?, isArchived: Bool = false, hasMessages: Bool = false, lastModified: Date = Date.now) {
        self.id = id
        self.title = title
        self.lastInteracted = lastInteracted
        self.modelUsed = modelUsed
        self.agentUsed = agentUsed
        self.isArchived = isArchived
        self.hasMessages = hasMessages
        self.lastModified = lastModified
    }
}
