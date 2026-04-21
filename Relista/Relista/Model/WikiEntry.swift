//
//  WikiEntry.swift
//  Relista
//
//  Created by Nicolas Helbig on 21.04.26.
//

import Foundation

struct WikiEntry: Codable, Identifiable, Hashable {
    var id: UUID
    var category: String
    var content: String

    init(id: UUID = UUID(), category: String, content: String) {
        self.id = id
        self.category = category
        self.content = content
    }
}
