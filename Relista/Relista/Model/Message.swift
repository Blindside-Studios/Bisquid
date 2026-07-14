//
//  Message.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import Foundation
import SwiftData

@Model
final class Message: Identifiable {
    var id: UUID = UUID()
    var text: String = ""
    var role: MessageRole = MessageRole.user
    var modelUsed: String = "Unspecified Model"
    var attachmentLinks: [String] = []
    var timeStamp: Date = Date.now
    var lastModified: Date = Date.now
    var annotations: [MessageAnnotation]?
    var contentBlocks: [MessageContentBlock]?
    var conversationID: UUID = UUID()

    init(id: UUID, text: String, role: MessageRole, modelUsed: String = "Unspecified Model", attachmentLinks: [String], timeStamp: Date, lastModified: Date = Date.now, annotations: [MessageAnnotation]? = nil, contentBlocks: [MessageContentBlock]? = nil, conversationID: UUID) {
        self.id = id
        self.text = text
        self.role = role
        self.modelUsed = modelUsed
        self.attachmentLinks = attachmentLinks
        self.timeStamp = timeStamp
        self.lastModified = lastModified
        self.annotations = annotations
        self.contentBlocks = contentBlocks
        self.conversationID = conversationID
    }
}

enum MessageRole: String, Codable{
    case system, assistant, user
    
    func toAPIString() -> String {
            switch self {
            case .user: return "user"
            case .assistant: return "assistant"
            case .system: return "system"
            }
        }
}
