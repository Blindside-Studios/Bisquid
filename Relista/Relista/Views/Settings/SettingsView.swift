//
//  SettingsView.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    let totalAvailableItems: [SettingsItem] = [.general, .personalization, .agents, .apiProvider]
    @State private var settingsView: SettingsItem? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var onClose: (() -> Void)? = nil

    var body: some View {
        NavigationSplitView {
            List(totalAvailableItems, selection: $settingsView) { view in
                NavigationLink(value: view) {
                    Label(view.title, systemImage: view.systemImage)
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .toolbar {
                if let onClose {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .close, action: onClose)
                    }
                }
            }
            #endif
        } detail: {
            if let settingsView {
                settingsDetail(for: settingsView)
            } else {
                Text("Select a setting")
            }
        }
        .onAppear {
            if sizeClass != .compact {
                settingsView = .general
            }
        }
    }
    
    @ViewBuilder
    func settingsDetail(for item: SettingsItem) -> some View {
        switch item {
        case .general:
            GeneralSettings()
        case .apiProvider:
            APIProvider()
        case .personalization:
            PersonalizationSettings()
        case .agents:
            AgentSettings()
        }
    }
}

enum SettingsItem: String, CaseIterable, Identifiable {
    case general
    case apiProvider
    case personalization
    case agents

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .apiProvider: "API Provider"
        case .personalization: "Personalization"
        case .agents: "Squidlets"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .apiProvider: "link"
        case .personalization: "paintpalette"
        case .agents: "person.crop.square"
        }
    }
}

#Preview {
    //SettingsView(selection: .general)
}
