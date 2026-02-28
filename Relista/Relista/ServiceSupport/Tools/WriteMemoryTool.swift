//
//  WriteMemoryTool.swift
//  Relista
//
//  Created by Nicolas Helbig on 28.02.26.
//

import Foundation

struct WriteMemoryTool: ChatTool {
    /// The agent whose memory to manage, or nil for global memories.
    let agentID: UUID?

    var name: String { "memory" }
    var displayName: String { "Memory" }
    var description: String { "Manage long-term memory" }
    var icon: String { "brain" }
    var defaultEnabled: Bool { true }

    var definition: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "memory",
                "description": """
                Manage long-term memories that persist across conversations.
                Memories are shown to you at the start of every conversation under '## What I remember', numbered 1, 2, 3...

                Actions:
                - 'add': Save a new fact. Provide 'fact' with the text to store. Use this proactively when the user shares something worth remembering.
                - 'delete': Remove an existing memory. Provide 'index' with its number from the list. Only call this for memories that actually exist in the list.
                - 'update': Replace an existing memory with corrected text. Provide 'index' with its number and 'fact' with the new text. Only call this for memories that actually exist in the list.

                IMPORTANT: For 'delete' and 'update', you MUST use the exact number shown next to the memory in '## What I remember'. Do not guess an index for a memory that is not in the list.
                """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "action": [
                            "type": "string",
                            "enum": ["add", "update", "delete"],
                            "description": "The operation to perform"
                        ],
                        "fact": [
                            "type": "string",
                            "description": "Required for 'add' and 'update'. The text of the new or corrected memory."
                        ],
                        "index": [
                            "type": "integer",
                            "description": "Required for 'update' and 'delete'. The 1-based number of the memory as shown in '## What I remember'."
                        ]
                    ],
                    "required": ["action"]
                ]
            ]
        ]
    }

    func inputSummary(from arguments: [String: Any]) -> String {
        let action = arguments["action"] as? String ?? "add"
        switch action {
        case "delete": return "Removed entry"
        case "update": return "Updated entry"
        default: return "Added entry"
        }
    }

    func execute(arguments: [String: Any]) async throws -> String {
        guard let action = arguments["action"] as? String else {
            throw NSError(domain: "MemoryTool", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing action"])
        }

        switch action {

        case "add":
            guard let fact = arguments["fact"] as? String,
                  !fact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw NSError(domain: "MemoryTool", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing or empty fact"])
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
            return "\(fact)"

        case "delete":
            guard let index = arguments["index"] as? Int else {
                throw NSError(domain: "MemoryTool", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing index for delete"])
            }
            let i = index - 1
            var old = ""
            await MainActor.run {
                let globalCount = SyncedSettings.shared.memories.count
                if i >= 0 && i < globalCount {
                    let text = SyncedSettings.shared.memories[i]
                    old = text
                    SyncedSettings.shared.memories.remove(at: i)
                    return text
                } else if let agentID {
                    let agentIndex = i - globalCount
                    var text = ""
                    try? AgentManager.shared.updateAgent(agentID) { agent in
                        if agentIndex >= 0 && agentIndex < agent.memories.count {
                            text = agent.memories[agentIndex]
                            old = text
                            agent.memories.remove(at: agentIndex)
                        }
                    }
                    return text
                }
                return ""
            }
            return "\(old)"

        case "update":
            guard let index = arguments["index"] as? Int,
                  let fact = arguments["fact"] as? String,
                  !fact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw NSError(domain: "MemoryTool", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing index or fact for update"])
            }
            let i = index - 1
            var old = ""
            await MainActor.run {
                let globalCount = SyncedSettings.shared.memories.count
                if i >= 0 && i < globalCount {
                    let text = SyncedSettings.shared.memories[i]
                    old = text
                    SyncedSettings.shared.memories[i] = fact
                    return text
                } else if let agentID {
                    let agentIndex = i - globalCount
                    var text = ""
                    try? AgentManager.shared.updateAgent(agentID) { agent in
                        if agentIndex >= 0 && agentIndex < agent.memories.count {
                            text = agent.memories[agentIndex]
                            old = text
                            agent.memories[agentIndex] = fact
                        }
                    }
                    return text
                }
                return "Failed because the model picked an invalid memory index."
            }
            return "##### Before:\n\(old)\n\n\n##### After:\n\(fact)"

        default:
            throw NSError(domain: "MemoryTool", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unknown action: \(action)"])
        }
    }
}
