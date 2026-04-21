//
//  WikisTool.swift
//  Relista
//
//  Created by Nicolas Helbig on 21.04.26.
//

import Foundation

struct WikisTool: ChatTool {
    /// Snapshot of the current wiki entries, captured on the main thread when
    /// the tool is constructed in `ToolRegistry.enabledTools`. Used to build the
    /// dynamic category list in `definition` from any thread.
    let entrySnapshot: [WikiEntry]

    var name: String { "wikis" }
    var displayName: String { "Wikis" }
    var description: String { "Categorized long-term knowledge base" }
    var icon: String { "books.vertical" }
    var defaultEnabled: Bool { true }

    var definition: [String: Any] {
        let grouped = Dictionary(grouping: entrySnapshot, by: \.category)
        let sortedCategories = grouped.keys.sorted()
        let categoriesList: String
        if sortedCategories.isEmpty {
            categoriesList = "(the knowledge base is currently empty)"
        } else {
            categoriesList = sortedCategories.map { cat in
                let count = grouped[cat]?.count ?? 0
                return "- \(cat) (\(count) \(count == 1 ? "entry" : "entries"))"
            }.joined(separator: "\n")
        }

        return [
            "type": "function",
            "function": [
                "name": name,
                "description": """
                Manage a persistent, categorized knowledge base that survives across conversations. \
                Use this to look up or record factual information the user may reference later — \
                events past your training cutoff, project details, recurring preferences, etc. \
                This is not the main memory tool. If you want to note down something you always want \
                access to, use the Memory tool if the user enabled it. This tool only works by actively \
                reading from it and read requests from past messages do not go through. If you need \
                additional knowledge, always call the tool again.

                Existing categories (with entry counts):
                \(categoriesList)

                When reading or writing, use the EXACT category name shown above. Do NOT include \
                the entry count in the category name.

                Actions:
                - 'read': Retrieve entries. Provide 'category' with an exact category name to read \
                  just that category, or omit 'category' to read the entire knowledge base. Each \
                  entry comes back with its UUID. You MUST call 'read' before 'update' or 'delete' \
                  so you have a real UUID — never guess or invent a UUID.
                - 'add': Create a new entry. Provide 'category' (creating a new one if it does not \
                  yet exist) and 'content' with the text to store.
                - 'update': Modify an existing entry. Provide 'id' (a UUID from a prior 'read') \
                  and at least one of 'category' (to re-tag the entry) or 'content' (to rewrite it).
                - 'delete': Remove an entry. Provide 'id' (a UUID from a prior 'read'). A category \
                  disappears automatically once its last entry is deleted.
                """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "action": [
                            "type": "string",
                            "enum": ["read", "add", "update", "delete"],
                            "description": "The operation to perform."
                        ],
                        "category": [
                            "type": "string",
                            "description": "For 'read': exact category name (omit to read everything). For 'add': the category to file the entry under. For 'update': optional new category name."
                        ],
                        "content": [
                            "type": "string",
                            "description": "For 'add': the text of the new entry. For 'update': the replacement text."
                        ],
                        "id": [
                            "type": "string",
                            "description": "Required for 'update' and 'delete'. The UUID of the entry, obtained from a prior 'read' call."
                        ]
                    ],
                    "required": ["action"]
                ]
            ]
        ]
    }

    func inputSummary(from arguments: [String: Any]) -> String {
        let action = arguments["action"] as? String ?? "read"
        switch action {
        case "read":
            if let cat = arguments["category"] as? String,
               !cat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Read from \"\(cat)\""
            }
            return "Read knowledge base"
        case "add":
            if let cat = arguments["category"] as? String,
               !cat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Added to \"\(cat)\""
            }
            return "Added entry"
        case "update": return "Updated entry"
        case "delete": return "Removed entry"
        default: return action
        }
    }

    func execute(arguments: [String: Any]) async throws -> String {
        guard let action = arguments["action"] as? String else {
            throw NSError(domain: "WikisTool", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing action"])
        }

        switch action {
        case "read":
            let requested = (arguments["category"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let entries = await MainActor.run { SyncedSettings.shared.wikiEntries }

            if let cat = requested, !cat.isEmpty {
                let filtered = entries.filter { $0.category == cat }
                if filtered.isEmpty {
                    return "No entries found for category '\(cat)'. Existing categories: \(existingCategories(entries).joined(separator: ", "))."
                }
                return Self.formatCategory(cat, entries: filtered)
            }

            if entries.isEmpty { return "The knowledge base is empty." }
            let grouped = Dictionary(grouping: entries, by: \.category)
            return grouped.keys.sorted()
                .map { Self.formatCategory($0, entries: grouped[$0] ?? []) }
                .joined(separator: "\n\n")

        case "add":
            guard let category = (arguments["category"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !category.isEmpty else {
                throw NSError(domain: "WikisTool", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing or empty category"])
            }
            guard let content = (arguments["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !content.isEmpty else {
                throw NSError(domain: "WikisTool", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing or empty content"])
            }
            let newEntry = WikiEntry(category: category, content: content)
            await MainActor.run {
                SyncedSettings.shared.wikiEntries.append(newEntry)
            }
            return "Added to '\(category)':\n\(content)\nID: \(newEntry.id.uuidString)"

        case "update":
            guard let idString = arguments["id"] as? String,
                  let uuid = UUID(uuidString: idString) else {
                throw NSError(domain: "WikisTool", code: 4, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid 'id'. Call 'read' first to obtain a valid UUID."])
            }
            let newCategory = (arguments["category"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let newContent = (arguments["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if (newCategory?.isEmpty ?? true) && (newContent?.isEmpty ?? true) {
                throw NSError(domain: "WikisTool", code: 5, userInfo: [NSLocalizedDescriptionKey: "Provide at least one of 'category' or 'content' to update."])
            }

            let result: String? = await MainActor.run {
                guard let idx = SyncedSettings.shared.wikiEntries.firstIndex(where: { $0.id == uuid }) else {
                    return nil
                }
                var entry = SyncedSettings.shared.wikiEntries[idx]
                let oldCategory = entry.category
                let oldContent = entry.content
                if let c = newCategory, !c.isEmpty { entry.category = c }
                if let t = newContent, !t.isEmpty { entry.content = t }
                SyncedSettings.shared.wikiEntries[idx] = entry
                return """
                ##### Before
                **Category:** \(oldCategory)
                **Content:** \(oldContent)

                ##### After
                **Category:** \(entry.category)
                **Content:** \(entry.content)
                """
            }
            guard let result else {
                throw NSError(domain: "WikisTool", code: 6, userInfo: [NSLocalizedDescriptionKey: "No entry found for ID \(idString). Call 'read' first to obtain valid UUIDs."])
            }
            return result

        case "delete":
            guard let idString = arguments["id"] as? String,
                  let uuid = UUID(uuidString: idString) else {
                throw NSError(domain: "WikisTool", code: 4, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid 'id'. Call 'read' first to obtain a valid UUID."])
            }
            let removed: WikiEntry? = await MainActor.run {
                guard let idx = SyncedSettings.shared.wikiEntries.firstIndex(where: { $0.id == uuid }) else {
                    return nil
                }
                return SyncedSettings.shared.wikiEntries.remove(at: idx)
            }
            guard let removed else {
                throw NSError(domain: "WikisTool", code: 6, userInfo: [NSLocalizedDescriptionKey: "No entry found for ID \(idString). Call 'read' first to obtain valid UUIDs."])
            }
            return "**Deleted from \"\(removed.category)\":**\n\n\(removed.content)"

        default:
            throw NSError(domain: "WikisTool", code: 7, userInfo: [NSLocalizedDescriptionKey: "Unknown action: \(action)"])
        }
    }

    private func existingCategories(_ entries: [WikiEntry]) -> [String] {
        Array(Set(entries.map(\.category))).sorted()
    }

    private static func formatCategory(_ category: String, entries: [WikiEntry]) -> String {
        let body = entries.enumerated().map { (i, e) in
            "\(i + 1). \(e.content)\n   ID: \(e.id.uuidString)"
        }.joined(separator: "\n\n")
        return "## \(category)\n\n\(body)"
    }
}
