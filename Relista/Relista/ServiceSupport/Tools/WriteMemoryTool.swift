//
//  WriteMemoryTool.swift
//  Relista
//
//  Created by Nicolas Helbig on 28.02.26.
//

import Foundation

struct WriteMemoryTool: ChatTool {
    /// The agent whose memory to write to, or nil for global memories.
    let agentID: UUID?

    var name: String { "write_memory" }
    var displayName: String { "Save to Memory" }
    var description: String { "Remember a fact for future conversations" }
    var icon: String { "brain" }
    var defaultEnabled: Bool { true }

    var definition: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "write_memory",
                "description": "Save a fact or piece of information to remember in future conversations. Use this proactively when the user shares something worth remembering.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "fact": [
                            "type": "string",
                            "description": "The fact to remember, written as a concise, self-contained statement (e.g. \"User prefers dark mode\" or \"User's cat is named Luna\")"
                        ]
                    ],
                    "required": ["fact"]
                ]
            ]
        ]
    }

    func inputSummary(from arguments: [String: Any]) -> String {
        arguments["fact"] as? String ?? "Saving to memory"
    }

    func execute(arguments: [String: Any]) async throws -> String {
        guard let fact = arguments["fact"] as? String,
              !fact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "WriteMemoryTool", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Missing or empty fact argument"
            ])
        }

        await MainActor.run {
            if let agentID {
                try? AgentManager.shared.updateAgent(agentID) { agent in
                    agent.memories.append(fact)
                }
            } else {
                SyncedSettings.shared.memories.append(fact)
            }
        }

        return "Remembered: \(fact)"
    }
}
