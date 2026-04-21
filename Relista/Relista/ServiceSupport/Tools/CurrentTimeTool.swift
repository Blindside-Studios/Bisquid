//
//  FetchUserName.swift
//  Bisquid
//
//  Created by Nicolas Helbig on 28.02.26.
//

import Foundation

struct CurrentTimeTool: ChatTool {
    var name: String { "current_time" }
    var displayName: String { "Current Time" }
    var description: String { "Lets the model access the current system time" }
    var icon: String { "clock" }
    var defaultEnabled: Bool { true }

    var definition: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": "Returns the current date and time for the user.",
                "parameters": [
                    "type": "object",
                    "properties": [:] as [String: Any],
                    "required": [] as [String]
                ]
            ]
        ]
    }

    func inputSummary(from arguments: [String: Any]) -> String {
        "Checked the time"
    }

    func execute(arguments: [String: Any]) async throws -> String {
        return Date.now.formatted(date: .numeric, time: .shortened)
    }
}
