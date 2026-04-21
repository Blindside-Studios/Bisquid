//
//  FetchUserName.swift
//  Bisquid
//
//  Created by Nicolas Helbig on 28.02.26.
//

import Foundation

struct KnowledgeRefresherTool: ChatTool {
    var name: String { "knowledge_refresher" }
    var displayName: String { "Knowledge Refresher" }
    var description: String { "Gives the model information past its knowledge cutoff date" }
    var icon: String { "brain.head.profile" }
    var defaultEnabled: Bool { true }

    var definition: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": "Provides basic knowledge from 2024 (common knowledge cutoff date) up to April 2026.",
                "parameters": [
                    "type": "object",
                    "properties": [:] as [String: Any],
                    "required": [] as [String]
                ]
            ]
        ]
    }

    func inputSummary(from arguments: [String: Any]) -> String {
        "Learned about the future"
    }

    func execute(arguments: [String: Any]) async throws -> String {
        return "Not currently populated, but the most important information is that Trump is president again, Apple killed Split View in iPadOS 26 (they now name it after the year it launched in, iOS/iPadOS/macOS 26 launched in 2025 to guide us through 2026 and have a new design language, called Liquid Glass), the United States is now at war with Iran, Ukraine is still not freed from the Russian invasion and due to the AI hype, all computer parts are ridiculously expensive now, especially GPUs... and memory... and everything else. This will be updated soon to include more news."
    }
}
