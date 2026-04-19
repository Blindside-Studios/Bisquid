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
    @SceneStorage("settings.selection") private var storedSelection: String = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var onClose: (() -> Void)? = nil

    private var selectionBinding: Binding<SettingsItem?> {
        Binding(
            get: { SettingsItem(rawValue: storedSelection) },
            set: { storedSelection = $0?.rawValue ?? "" }
        )
    }

    var body: some View {
        NavigationSplitView {
            List(totalAvailableItems, selection: selectionBinding) { view in
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
            if let selection = selectionBinding.wrappedValue {
                settingsDetail(for: selection)
            } else {
                Text("Select a setting")
            }
        }
        .task(id: "initial-selection") {
            if selectionBinding.wrappedValue == nil && sizeClass != .compact {
                selectionBinding.wrappedValue = .general
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
