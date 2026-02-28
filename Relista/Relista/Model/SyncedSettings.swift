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

    private init() {
        // Load initial values from iCloud KVS, with defaults
        self.defaultModel = store.string(forKey: Keys.defaultModel) ?? "mistralai/mistral-medium-3.1"
        self.defaultInstructions = store.string(forKey: Keys.defaultInstructions) ?? ""
        self.userName = store.string(forKey: Keys.userName) ?? ""
        self.memories = store.array(forKey: Keys.memories) as? [String] ?? []

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
        }
    }

    /// Builds the memory suffix to append to a system message.
    /// Combines global memories with the active agent's memories.
    static func memoryContext(for agentID: UUID?) -> String {
        let global = shared.memories
        let agentMemories = agentID.flatMap { AgentManager.getAgent(fromUUID: $0)?.memories } ?? []
        let all = global + agentMemories
        guard !all.isEmpty else { return "" }
        let numbered = all.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        return "\n\n## What I remember\n\(numbered)"
    }
}
