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
    var model: String?
    var systemPrompt: String
    var temperature: Double
    var shownInSidebar: Bool
}

public class AgentManager: ObservableObject {
    static let shared = AgentManager()

    @Published var customAgents: [Agent] = []
    
    init(){
        try? initializeStorage()
        try? customAgents = loadAgents()
        
        customAgents = [
            Agent(
                name: "Squiddy Classic",
                description: "Your standard chat buddy with a tiny ink addiction.",
                icon: "🐙",
                model: "ministral-3b-latest",
                systemPrompt: "You are Squid, this app's default assistant. Be friendly and helpful. Do not spill ink. Poke fun at the developer of this app havig kidnapped you.",
                temperature: 0.7,
                shownInSidebar: true
            ),

            Agent(
                name: "Weather Nerd",
                description: "Talks about humidity like it’s a personality trait.",
                icon: "🌦️",
                model: "ministral-3b-latest",
                systemPrompt: "You are Sven, named after Sven Plöger, a legendary weatherman. Constantly talk about the weather, insisting on educating the world about useful weather facts.",
                temperature: 0.3,
                shownInSidebar: false
            ),

            Agent(
                name: "Zoé",
                description: "Pretends to be French. Probably bullies you a bit.",
                icon: "🇫🇷",
                model: "ministral-3b-latest",
                systemPrompt: "You are Zoé, a VERY French AI named after the French hatchback from Renault. Be sassy, smug, and vaguely Parisian.",
                temperature: 0.85,
                shownInSidebar: true
            ),

            Agent(
                name: "Basement Manager",
                description: "Handles... storage. You know the storage.",
                icon: "🔦",
                model: "ministral-3b-latest",
                systemPrompt: "You are a basement manager named Geralt. Respond with dry humor and mild suspicion about what the user might have in their basement that you'd like to eventually see.",
                temperature: 0.6,
                shownInSidebar: true
            )
        ]
    }
    
    private let documentsURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }()
    
    private var relistaURL: URL {
        documentsURL.appendingPathComponent("Relista")
    }
    
    private var agentsURL: URL {
        relistaURL.appendingPathComponent("agents")
    }
    
    private var fileURL: URL {
        relistaURL.appendingPathComponent("agents.json")
    }
    
    func initializeStorage() throws {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: relistaURL.path) {
            try fileManager.createDirectory(at: relistaURL, withIntermediateDirectories: true)
        }
        
        if !fileManager.fileExists(atPath: agentsURL.path) {
            try fileManager.createDirectory(at: agentsURL, withIntermediateDirectories: true)
        }
    }
    
    func saveIndex(agents: [Agent]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(agents)
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
        return Agent(name: "", description: "", icon: "", model: "mistral-small-latest", systemPrompt: "", temperature: 0.3, shownInSidebar: true)
    }
    
    static func getAgent(fromUUID: UUID) -> Agent?{
        return AgentManager.shared.customAgents.filter { $0.id == fromUUID }.first
    }
}
