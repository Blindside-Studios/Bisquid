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

    private init() {
        // Load initial values from iCloud KVS, with defaults
        self.defaultModel = store.string(forKey: Keys.defaultModel) ?? "mistralai/mistral-medium-3.1"
        self.defaultInstructions = store.string(forKey: Keys.defaultInstructions) ?? ""
        self.userName = store.string(forKey: Keys.userName) ?? ""

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
        }
    }
}
