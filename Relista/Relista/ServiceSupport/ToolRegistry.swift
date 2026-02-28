//
//  ToolRegistry.swift
//  Relista
//
//  Created by Nicolas Helbig on 28.02.26.
//

import Foundation

/// Central registry of all tools available in the app.
/// To add a new tool: create a struct conforming to ChatTool in ServiceSupport/Tools/,
/// then add an instance to `allTools` below.
enum ToolRegistry {
    static let allTools: [any ChatTool] = [
        WebSearchTool(),
        WriteMemoryTool(agentID: nil),
        RandomFruitTool(),
        UserNameTool()
    ]

    private static func key(for tool: any ChatTool) -> String {
        "tool.enabled.\(tool.name)"
    }

    static func isEnabled(_ tool: any ChatTool) -> Bool {
        let k = key(for: tool)
        guard UserDefaults.standard.object(forKey: k) != nil else {
            return tool.defaultEnabled
        }
        return UserDefaults.standard.bool(forKey: k)
    }

    static func setEnabled(_ enabled: Bool, for tool: any ChatTool) {
        UserDefaults.standard.set(enabled, forKey: key(for: tool))
    }

    /// Returns only the tools that are currently enabled, with context-sensitive tools
    /// (like WriteMemoryTool) configured for the active agent.
    static func enabledTools(for agentID: UUID? = nil) -> [any ChatTool] {
        allTools
            .filter { isEnabled($0) }
            .map { tool in
                if tool.name == "memory" {
                    return WriteMemoryTool(agentID: agentID)
                }
                return tool
            }
    }
}
