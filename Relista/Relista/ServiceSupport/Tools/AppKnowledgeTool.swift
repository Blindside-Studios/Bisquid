//
//  FetchUserName.swift
//  Bisquid
//
//  Created by Nicolas Helbig on 28.02.26.
//

import Foundation

struct AppKnowledgeTool: ChatTool {
    var name: String { "app_knowledge" }
    var displayName: String { "App Knowledge" }
    var description: String { "Provides the model with a Bisquid user guide" }
    var icon: String { "questionmark.app" }
    var defaultEnabled: Bool { true }

    var definition: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": "Returns information and user guides about the Bisquid application this chat is handled by (currently not implemented).",
                "parameters": [
                    "type": "object",
                    "properties": [:] as [String: Any],
                    "required": [] as [String]
                ]
            ]
        ]
    }

    func inputSummary(from arguments: [String: Any]) -> String {
        "Consulted the manual"
    }

    func execute(arguments: [String: Any]) async throws -> String {
        return "No app documentation has been submitted by the developer yet. Documentation is being compiled as the app is being developed."
    }
}
