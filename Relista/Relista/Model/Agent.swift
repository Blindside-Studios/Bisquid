//
//  Agent.swift
//  Relista
//
//  Created by Nicolas Helbig on 19.11.25.
//

import Foundation
import Combine

struct Agent: Identifiable, Hashable, Codable{
    var id = UUID()
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

    // Custom Codable implementation for backwards compatibility
    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, model, systemPrompt, temperature, shownInSidebar, lastModified, primaryAccentColor, secondaryAccentColor
    }

    init(id: UUID = UUID(), name: String, description: String, icon: String, model: String, systemPrompt: String, temperature: Double, shownInSidebar: Bool, lastModified: Date = Date.now, primaryAccentColor: String? = nil, secondaryAccentColor: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.model = model
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.shownInSidebar = shownInSidebar
        self.lastModified = lastModified
        self.primaryAccentColor = primaryAccentColor
        self.secondaryAccentColor = secondaryAccentColor
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
        // Backwards compatible: default to now if missing
        lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date.now
        // Backwards compatible: default to nil if missing
        primaryAccentColor = try container.decodeIfPresent(String.self, forKey: .primaryAccentColor)
        secondaryAccentColor = try container.decodeIfPresent(String.self, forKey: .secondaryAccentColor)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(icon, forKey: .icon)
        try container.encode(model, forKey: .model)
        try container.encode(systemPrompt, forKey: .systemPrompt)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(shownInSidebar, forKey: .shownInSidebar)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encodeIfPresent(primaryAccentColor, forKey: .primaryAccentColor)
        try container.encodeIfPresent(secondaryAccentColor, forKey: .secondaryAccentColor)
    }
}

public class AgentManager: ObservableObject {
    static let shared = AgentManager()

    @Published var customAgents: [Agent] = []

    init(){
        // Load agents from disk
        try? initializeStorage()
        try? customAgents = loadAgents()

        print("📱 AgentManager initialized with \(customAgents.count) agents")
    }

    /// Returns the iCloud Documents container URL, falling back to local Documents if unavailable
    private var relistaURL: URL {
        let fileManager = FileManager.default

        // Try to get iCloud container
        if let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: "iCloud.Blindside-Studios.Relista") {
            return iCloudURL.appendingPathComponent("Documents").appendingPathComponent("Relista")
        }

        // Fallback to local Documents
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Relista")
    }

    private var fileURL: URL {
        relistaURL.appendingPathComponent("agents.json")
    }

    func initializeStorage() throws {
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: relistaURL.path) {
            try fileManager.createDirectory(at: relistaURL, withIntermediateDirectories: true)
        }
    }

    // MARK: - Agent CRUD

    /// Update a specific agent
    func updateAgent(_ id: UUID, changes: (inout Agent) -> Void) throws {
        guard let index = customAgents.firstIndex(where: { $0.id == id }) else {
            throw AgentError.notFound
        }

        changes(&customAgents[index])
        customAgents[index].lastModified = Date.now

        print("✏️  Updated agent '\(customAgents[index].name)'")
        try saveToDisk()
    }

    /// Create a new agent
    func createAgent(_ agent: Agent) throws {
        var newAgent = agent
        newAgent.lastModified = Date.now
        customAgents.append(newAgent)

        print("➕ Created agent '\(newAgent.name)'")
        try saveToDisk()
    }

    /// Delete an agent
    func deleteAgent(_ id: UUID) throws {
        guard let index = customAgents.firstIndex(where: { $0.id == id }) else {
            throw AgentError.notFound
        }

        let name = customAgents[index].name
        customAgents.remove(at: index)

        print("🗑️  Deleted agent '\(name)'")
        try saveToDisk()
    }

    /// Reload agents from disk (call after iCloud sync updates files)
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

    // MARK: - Private Methods

    /// Save agents to disk
    func saveToDisk() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(customAgents)
        try data.write(to: fileURL)
    }

    func loadAgents() throws -> [Agent] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []  // No index yet, return empty
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode([Agent].self, from: data)
    }
    
    static func createNewAgent() -> Agent {
        return Agent(name: "", description: "", icon: "", model: "mistralai/mistral-medium-3.1", systemPrompt: "", temperature: 0.3, shownInSidebar: true, lastModified: Date.now)
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
    
    static func getUIAgentImage(fromUUID: UUID) -> String{
        let agent = AgentManager.shared.customAgents.filter { $0.id == fromUUID }.first
        if agent != nil {
            return agent!.icon
        }
        else { return "" }
    }
    
    static func getUIAgentColors(fromUUID: UUID) -> [String?]
    {
        let agent = AgentManager.shared.customAgents.filter { $0.id == fromUUID }.first
        if agent != nil {
            return [agent!.primaryAccentColor, agent!.secondaryAccentColor]
        }
        else { return ["", ""] }
    }
}
