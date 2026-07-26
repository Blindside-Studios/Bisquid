//
//  Agent.swift
//  Relista
//
//  Created by Nicolas Helbig on 19.11.25.
//

import Foundation
import Combine
import SwiftUI
import SwiftData

@Model
final class Agent: Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    // Named `agentDescription`, not `description` — @Model rejects a stored property
    // literally named `description`.
    var agentDescription: String = ""
    var icon: String = ""
    var model: String = ""
    var systemPrompt: String = ""
    var temperature: Double = 0.5
    var shownInSidebar: Bool = true
    var lastModified: Date = Date.now
    var primaryAccentColor: String?
    var secondaryAccentColor: String?
    var memories: [String] = []
    // Not persisted anywhere in the old JSON — array position in the file was the order.
    // SwiftData fetches have no inherent order, so manual drag-to-reorder needs a real
    // field to sort by; AgentManager.saveToDisk() keeps this in sync with array order.
    var sortOrder: Int = 0

    init(id: UUID = UUID(), name: String, description: String, icon: String, model: String, systemPrompt: String, temperature: Double, shownInSidebar: Bool, lastModified: Date = Date.now, primaryAccentColor: String? = nil, secondaryAccentColor: String? = nil, memories: [String] = [], sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.agentDescription = description
        self.icon = icon
        self.model = model
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.shownInSidebar = shownInSidebar
        self.lastModified = lastModified
        self.primaryAccentColor = primaryAccentColor
        self.secondaryAccentColor = secondaryAccentColor
        self.memories = memories
        self.sortOrder = sortOrder
    }

    /// Copies every editable field from another Agent onto this one. Used to commit an
    /// AgentEditorView draft (an unmanaged, uninserted Agent) onto the real, context-tracked
    /// instance — see AgentEditorView.save().
    func apply(from other: Agent) {
        name = other.name
        agentDescription = other.agentDescription
        icon = other.icon
        model = other.model
        systemPrompt = other.systemPrompt
        temperature = other.temperature
        shownInSidebar = other.shownInSidebar
        primaryAccentColor = other.primaryAccentColor
        secondaryAccentColor = other.secondaryAccentColor
        memories = other.memories
    }
}

// MARK: - Codable
//
// This exists solely so AgentEditorView can round-trip an in-progress draft through
// SceneStorage as JSON. That's load-bearing, not a nicety: the app's compact layout uses a
// custom side-drawer instead of NavigationSplitView, so a horizontal/vertical size class
// change tears down and rebuilds the view hierarchy the editor sheet lives in — mid-edit,
// during completely normal use, not just on force-quit. Without this, an in-progress
// Squidlet edit gets silently destroyed whenever that happens.
extension Agent: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, icon, model, systemPrompt, temperature, shownInSidebar, lastModified, primaryAccentColor, secondaryAccentColor, memories, sortOrder
        case agentDescription = "description"
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            description: try container.decode(String.self, forKey: .agentDescription),
            icon: try container.decode(String.self, forKey: .icon),
            model: try container.decode(String.self, forKey: .model),
            systemPrompt: try container.decode(String.self, forKey: .systemPrompt),
            temperature: try container.decode(Double.self, forKey: .temperature),
            shownInSidebar: try container.decode(Bool.self, forKey: .shownInSidebar),
            lastModified: try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date.now,
            primaryAccentColor: try container.decodeIfPresent(String.self, forKey: .primaryAccentColor),
            secondaryAccentColor: try container.decodeIfPresent(String.self, forKey: .secondaryAccentColor),
            memories: try container.decodeIfPresent([String].self, forKey: .memories) ?? [],
            sortOrder: try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(agentDescription, forKey: .agentDescription)
        try container.encode(icon, forKey: .icon)
        try container.encode(model, forKey: .model)
        try container.encode(systemPrompt, forKey: .systemPrompt)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(shownInSidebar, forKey: .shownInSidebar)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encodeIfPresent(primaryAccentColor, forKey: .primaryAccentColor)
        try container.encodeIfPresent(secondaryAccentColor, forKey: .secondaryAccentColor)
        try container.encode(memories, forKey: .memories)
        try container.encode(sortOrder, forKey: .sortOrder)
    }
}

// MARK: - Equatable
//
// SwiftUI's onChange(of:) requires it. Content-based rather than reference identity —
// AgentEditorView mutates the same draft instance in place while editing, so reference
// equality would never report a change after the first one.
extension Agent: Equatable {
    static func == (lhs: Agent, rhs: Agent) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.agentDescription == rhs.agentDescription &&
        lhs.icon == rhs.icon &&
        lhs.model == rhs.model &&
        lhs.systemPrompt == rhs.systemPrompt &&
        lhs.temperature == rhs.temperature &&
        lhs.shownInSidebar == rhs.shownInSidebar &&
        lhs.lastModified == rhs.lastModified &&
        lhs.primaryAccentColor == rhs.primaryAccentColor &&
        lhs.secondaryAccentColor == rhs.secondaryAccentColor &&
        lhs.memories == rhs.memories &&
        lhs.sortOrder == rhs.sortOrder
    }
}

public class AgentManager: ObservableObject {
    static let shared = AgentManager()

    @Published var customAgents: [Agent] = []

    private var context: ModelContext {
        RelistaApp.sharedModelContainer.mainContext
    }

    init(){
        customAgents = (try? loadAgents()) ?? []
        print("📱 AgentManager initialized with \(customAgents.count) agents")
    }

    // MARK: - Agent CRUD

    /// Update a specific agent
    func updateAgent(_ id: UUID, changes: (Agent) -> Void) throws {
        guard let existing = customAgents.first(where: { $0.id == id }) else {
            throw AgentError.notFound
        }

        changes(existing)
        existing.lastModified = Date.now

        print("✏️  Updated agent '\(existing.name)'")
        try saveToDisk()
    }

    /// Create a new agent
    func createAgent(_ agent: Agent) throws {
        agent.lastModified = Date.now
        agent.sortOrder = customAgents.count
        customAgents.append(agent)

        print("➕ Created agent '\(agent.name)'")
        try saveToDisk()
    }

    /// Delete an agent
    func deleteAgent(_ id: UUID) throws {
        guard let index = customAgents.firstIndex(where: { $0.id == id }) else {
            throw AgentError.notFound
        }

        let agentToDelete = customAgents[index]
        let name = agentToDelete.name
        customAgents.remove(at: index)
        context.delete(agentToDelete)
        try context.save()

        print("🗑️  Deleted agent '\(name)'")
    }

    /// Reload agents from the store (call after a remote CloudKit change)
    func refreshFromStorage() async {
        print("🔄 Refreshing agents from storage...")

        let agents = (try? loadAgents()) ?? []

        await MainActor.run {
            customAgents = agents
        }

        print("✅ Agents refreshed: \(agents.count) total")
    }

    enum AgentError: Error {
        case notFound
    }

    // MARK: - Persistence

    /// Persists every agent currently in `customAgents`, in its current array order —
    /// sortOrder is re-stamped from position so drag-to-reorder (moveAgents) sticks.
    func saveToDisk() throws {
        for (index, agent) in customAgents.enumerated() {
            agent.sortOrder = index
            context.insert(agent)
        }
        try context.save()
    }

    func loadAgents() throws -> [Agent] {
        try context.fetch(FetchDescriptor<Agent>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    static func createNewAgent() -> Agent {
        return Agent(name: "", description: "", icon: "", model: "mistral-medium-latest", systemPrompt: "", temperature: 0.3, shownInSidebar: true, lastModified: Date.now)
    }

    static func getAgent(fromUUID: UUID) -> Agent?{
        return AgentManager.shared.customAgents.filter { $0.id == fromUUID }.first
    }

    static func getUIAgentName(fromUUID: UUID) -> String{
        let agent = AgentManager.shared.customAgents.filter { $0.id == fromUUID }.first
        if agent != nil {
            return agent!.name
        }
        else { return "Unkown Agent" }
    }

    private static func getAgentImageName(fromUUID: UUID) -> String?{
        let agent = AgentManager.shared.customAgents.filter { $0.id == fromUUID }.first
        if agent != nil {
            return agent!.icon
        }
        else { return nil }
    }

    static func getUIAgentColors(fromUUID: UUID) -> [String?]
    {
        let agent = AgentManager.shared.customAgents.filter { $0.id == fromUUID }.first
        if agent != nil {
            return [agent!.primaryAccentColor, agent!.secondaryAccentColor]
        }
        else { return ["", ""] }
    }

    static func getAgentTemperature(fromUUID: UUID?) -> Double
    {

        if fromUUID == nil{
            return SyncedSettings.shared.temperature
        } else {
            let agent = AgentManager.shared.customAgents.filter { $0.id == fromUUID }.first
            if agent != nil {
                return agent!.temperature
            }
            else { return 0.5 }
        }
    }

    static func getAgentImage(fromUUID: UUID?) -> some View{
        if let fromUUID{
            return Image("AgentIcons/\(AgentManager.getAgentImageName(fromUUID: fromUUID) ?? "Default")").resizable().scaledToFit()
        } else {
            return Image("AgentIcons/Default").resizable().scaledToFit()
        }
    }

    public static let availableImages: [String] = ["Default", "Twongi", "République", "Meet_The_Squid", "Keep_Calm", "Mechanical", "Bricked_Up", "Ghost", "Headband", "Nadiya"]
}

// MARK: - Legacy Import

/// Mirrors the pre-SwiftData JSON shape of `Agent`. Read-only, purely for the one-time
/// migration out of the old agents.json in iCloud Documents — same reasoning as
/// LegacyConversation/LegacyMessage in ConversationManager.swift. Kept as `description`
/// here (not renamed) since it just mirrors the actual on-disk JSON key.
private struct LegacyAgent: Decodable {
    var id: UUID
    var name: String
    var description: String
    var icon: String
    var model: String
    var systemPrompt: String
    var temperature: Double
    var shownInSidebar: Bool
    var lastModified: Date
    var primaryAccentColor: String?
    var secondaryAccentColor: String?
    var memories: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, model, systemPrompt, temperature, shownInSidebar, lastModified, primaryAccentColor, secondaryAccentColor, memories
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        icon = try container.decode(String.self, forKey: .icon)
        model = try container.decode(String.self, forKey: .model)
        systemPrompt = try container.decode(String.self, forKey: .systemPrompt)
        temperature = try container.decode(Double.self, forKey: .temperature)
        shownInSidebar = try container.decode(Bool.self, forKey: .shownInSidebar)
        lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date.now
        primaryAccentColor = try container.decodeIfPresent(String.self, forKey: .primaryAccentColor)
        secondaryAccentColor = try container.decodeIfPresent(String.self, forKey: .secondaryAccentColor)
        memories = try container.decodeIfPresent([String].self, forKey: .memories) ?? []
    }
}

/// Reads the old agents.json directly — kept separate from AgentManager, which no longer
/// touches the filesystem at all now that it's SwiftData-backed.
private enum LegacyAgentFile {
    private static var relistaURL: URL {
        let fileManager = FileManager.default
        if let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: "iCloud.Blindside-Studios.Relista") {
            return iCloudURL.appendingPathComponent("Documents").appendingPathComponent("Relista")
        }
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Relista")
    }

    private static var fileURL: URL {
        relistaURL.appendingPathComponent("agents.json")
    }

    static func load() throws -> [LegacyAgent] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([LegacyAgent].self, from: data)
    }
}

extension LegacyImporter {
    /// Additive, same rule as importIntoDatabase(): anything whose id already exists in the
    /// store is left untouched, so this is safe to run again without duplicating agents.
    static func importAgents() throws -> Int {
        let context = RelistaApp.sharedModelContainer.mainContext
        let existingIDs = Set(try context.fetch(FetchDescriptor<Agent>()).map(\.id))
        let legacyAgents = try LegacyAgentFile.load()

        var imported = 0
        for legacy in legacyAgents where !existingIDs.contains(legacy.id) {
            context.insert(Agent(
                id: legacy.id,
                name: legacy.name,
                description: legacy.description,
                icon: legacy.icon,
                model: legacy.model,
                systemPrompt: legacy.systemPrompt,
                temperature: legacy.temperature,
                shownInSidebar: legacy.shownInSidebar,
                lastModified: legacy.lastModified,
                primaryAccentColor: legacy.primaryAccentColor,
                secondaryAccentColor: legacy.secondaryAccentColor,
                memories: legacy.memories,
                sortOrder: existingIDs.count + imported
            ))
            imported += 1
        }

        try context.save()
        return imported
    }
}
