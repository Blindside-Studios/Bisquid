//
//  Agent.swift
//  Relista
//
//  Created by Nicolas Helbig on 19.11.25.
//

import Foundation
import Combine
import CloudKit

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

    /// CloudKit sync engine for agents
    private let syncEngine: SyncEngine<Agent>

    init(){
        // Initialize CloudKit sync engine
        let container = CKContainer(identifier: "iCloud.Blindside-Studios.Relista")
        self.syncEngine = SyncEngine(database: container.privateCloudDatabase)

        // Load agents from disk
        try? initializeStorage()
        try? customAgents = loadAgents()

        print("📱 AgentManager initialized with \(customAgents.count) agents")
    }

    private let documentsURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }()

    private var relistaURL: URL {
        documentsURL.appendingPathComponent("Relista")
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

    // MARK: - New Sync-Aware API

    /// Update a specific agent and sync to CloudKit
    /// This is the preferred way to modify agents - ensures timestamp and sync tracking
    /// - Parameters:
    ///   - id: The ID of the agent to update
    ///   - changes: A closure that modifies the agent
    /// - Throws: Error if agent not found or save fails
    func updateAgent(_ id: UUID, changes: (inout Agent) -> Void) throws {
        guard let index = customAgents.firstIndex(where: { $0.id == id }) else {
            throw SyncError.notFound
        }

        // Apply changes
        changes(&customAgents[index])

        // Update timestamp BEFORE saving (critical for sync!)
        customAgents[index].lastModified = Date.now

        print("✏️  Updated agent '\(customAgents[index].name)'")

        // Save to disk
        try saveToDisk()

        // Sync to CloudKit (debounced)
        Task {
            await syncEngine.markForPush(id)
            await syncEngine.startDebouncedPush { [weak self] in
                self?.customAgents ?? []
            }
        }
    }

    /// Create a new agent and sync to CloudKit
    /// - Parameter agent: The agent to create
    /// - Throws: Error if save fails
    func createAgent(_ agent: Agent) throws {
        var newAgent = agent
        newAgent.lastModified = Date.now
        customAgents.append(newAgent)

        print("➕ Created agent '\(newAgent.name)'")

        try saveToDisk()

        Task {
            await syncEngine.markForPush(newAgent.id)
            await syncEngine.startDebouncedPush { [weak self] in
                self?.customAgents ?? []
            }
        }
    }

    /// Delete an agent and sync deletion to CloudKit
    /// - Parameter id: The ID of the agent to delete
    /// - Throws: Error if agent not found or save fails
    func deleteAgent(_ id: UUID) throws {
        guard let index = customAgents.firstIndex(where: { $0.id == id }) else {
            throw SyncError.notFound
        }

        let name = customAgents[index].name
        customAgents.remove(at: index)

        print("🗑️  Deleted agent '\(name)'")

        try saveToDisk()

        Task {
            await syncEngine.markForDelete(id)
            await syncEngine.startDebouncedPush { [weak self] in
                self?.customAgents ?? []
            }
        }
    }

    /// Manually refresh agents from CloudKit
    /// Call this when user taps refresh button
    /// - Throws: Error if sync fails
    func refreshFromCloud() async throws {
        print("🔄 Refreshing agents from CloudKit...")

        // Step 1: Pull deletion tombstones (do this first!)
        let deletedIDs = try await syncEngine.pullDeletions()

        // Step 2: Remove deleted agents from local collection
        if !deletedIDs.isEmpty {
            await MainActor.run {
                customAgents.removeAll { deletedIDs.contains($0.id) }
                print("  🗑️  Removed \(deletedIDs.count) deleted agent(s) from local storage")
            }
        }

        // Step 3: Pull updated agents from CloudKit
        let cloudAgents = try await syncEngine.pull()

        // Step 4: Merge with local agents (newest wins)
        let merged = SyncMerge.merge(
            cloudItems: cloudAgents,
            into: customAgents,
            itemName: "agent"
        )

        // Step 5: Update local state on main thread
        await MainActor.run {
            customAgents = merged
        }

        // Step 6: Save merged result to disk
        try saveToDisk()

        print("✅ Agents refreshed: now have \(customAgents.count) total")
    }

    // MARK: - Legacy API (Deprecated)

    /// Save agents to disk and optionally sync to CloudKit
    /// ⚠️ Deprecated: Use updateAgent(), createAgent(), or deleteAgent() instead
    /// Those methods properly update timestamps and track specific changes
    @available(*, deprecated, message: "Use updateAgent(), createAgent(), or deleteAgent() instead")
    func saveAgents(syncToCloudKit: Bool = true) throws {
        try saveToDisk()

        if syncToCloudKit {
            // Old behavior: mark ALL agents as changed (inefficient)
            Task {
                for agent in customAgents {
                    await syncEngine.markForPush(agent.id)
                }
                await syncEngine.startDebouncedPush { [weak self] in
                    self?.customAgents ?? []
                }
            }
        }
    }

    // MARK: - Private Methods

    /// Save agents to disk (local only, no CloudKit)
    private func saveToDisk() throws {
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

    /// Updates an agent's lastModified timestamp - call before saving
    func touchAgent(id: UUID) {
        if let index = customAgents.firstIndex(where: { $0.id == id }) {
            customAgents[index].lastModified = Date.now
        }
    }

    /// Updates multiple agents' lastModified timestamps - call before saving
    func touchAllAgents() {
        for index in customAgents.indices {
            customAgents[index].lastModified = Date.now
        }
    }
}
