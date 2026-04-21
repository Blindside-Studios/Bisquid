//
//  SyncedSettings.swift
//  Relista
//
//  Created by Nicolas Helbig on 01.02.26.
//

import Foundation
import Combine

@MainActor
final class SyncedSettings: ObservableObject {
    static let shared = SyncedSettings()

    private let store = NSUbiquitousKeyValueStore.default

    private enum Keys {
        static let defaultModel = "AppDefaultModel"
        static let defaultInstructions = "DefaultAssistantInstructions"
        static let userName = "UIUserName"
        static let memories = "GlobalMemories"
        static let temperature = "DefaultAssistantTemperature"
        static let suppressEmDashes = "SuppressEmDashes"
        static let wikiEntries = "WikiEntries"
    }

    @Published var defaultModel: String {
        didSet {
            store.set(defaultModel, forKey: Keys.defaultModel)
            store.synchronize()
        }
    }

    @Published var defaultInstructions: String {
        didSet {
            store.set(defaultInstructions, forKey: Keys.defaultInstructions)
            store.synchronize()
        }
    }

    @Published var userName: String {
        didSet {
            store.set(userName, forKey: Keys.userName)
            store.synchronize()
        }
    }

    @Published var memories: [String] {
        didSet {
            store.set(memories, forKey: Keys.memories)
            store.synchronize()
        }
    }
    
    @Published var temperature: Double {
        didSet {
            store.set(temperature, forKey: Keys.temperature)
            store.synchronize()
        }
    }

    @Published var suppressEmDashes: Bool {
        didSet {
            store.set(suppressEmDashes, forKey: Keys.suppressEmDashes)
            store.synchronize()
        }
    }

    @Published var wikiEntries: [WikiEntry] {
        didSet {
            if let data = try? JSONEncoder().encode(wikiEntries) {
                store.set(data, forKey: Keys.wikiEntries)
                store.synchronize()
            }
        }
    }

    private init() {
        // Load initial values from iCloud KVS, with defaults
        self.defaultModel = store.string(forKey: Keys.defaultModel) ?? "mistral-medium-latest"
        self.defaultInstructions = store.string(forKey: Keys.defaultInstructions) ?? ""
        self.userName = store.string(forKey: Keys.userName) ?? ""
        self.memories = store.array(forKey: Keys.memories) as? [String] ?? []
        self.temperature = store.object(forKey: Keys.temperature) != nil ? store.double(forKey: Keys.temperature) : 0.35
        self.suppressEmDashes = store.object(forKey: Keys.suppressEmDashes) != nil ? store.bool(forKey: Keys.suppressEmDashes) : false
        if let data = store.data(forKey: Keys.wikiEntries),
           let decoded = try? JSONDecoder().decode([WikiEntry].self, from: data) {
            self.wikiEntries = decoded
        } else {
            self.wikiEntries = []
        }

        // Listen for external changes (from other devices)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )

        // Trigger initial sync
        store.synchronize()
    }

    @objc private func storeDidChange(_ notification: Notification) {
        Task { @MainActor in
            // Update published properties from store
            if let newModel = store.string(forKey: Keys.defaultModel), newModel != defaultModel {
                defaultModel = newModel
            }
            if let newInstructions = store.string(forKey: Keys.defaultInstructions), newInstructions != defaultInstructions {
                defaultInstructions = newInstructions
            }
            if let newUserName = store.string(forKey: Keys.userName), newUserName != userName {
                userName = newUserName
            }
            if let newMemories = store.array(forKey: Keys.memories) as? [String], newMemories != memories {
                memories = newMemories
            }
            if let newTemperature = store.double(forKey: Keys.temperature) as Double?, newTemperature != temperature {
                temperature = newTemperature
            }
            let newSuppressEmDashes = store.bool(forKey: Keys.suppressEmDashes)
            if newSuppressEmDashes != suppressEmDashes {
                suppressEmDashes = newSuppressEmDashes
            }
            if let data = store.data(forKey: Keys.wikiEntries),
               let decoded = try? JSONDecoder().decode([WikiEntry].self, from: data),
               decoded != wikiEntries {
                wikiEntries = decoded
            }
        }
    }

    /// Builds the memory suffix to append to a system message.
    /// Combines global memories with the active agent's memories.
    static func memoryContext(for agentID: UUID?) -> String {
        let global = shared.memories
        let agentMemories = agentID.flatMap { AgentManager.getAgent(fromUUID: $0)?.memories } ?? []
        let all = agentID == nil ? global : agentMemories
        guard !all.isEmpty else { return "" }
        let numbered = all.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        return """

        ## Background context
        The following is background information about the user, derived from past conversations or user input. \
        Use it only when directly relevant to the current message - do not reference, repeat, or \
        acknowledge it otherwise. Most messages will not require most or any of this context at all.

        \(numbered)
        """
    }
}
