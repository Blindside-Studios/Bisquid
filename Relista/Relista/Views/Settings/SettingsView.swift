//
//  SettingsView.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    let totalAvailableItems: [SettingsItem] = [.general, .personalization, .agents, .wikis, .apiProvider]
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
        #if os(macOS)
        TabView(selection: macTabSelectionBinding) {
            ForEach(totalAvailableItems) { item in
                NavigationStack {
                    settingsDetail(for: item)
                }
                .tabItem { Label(item.title, systemImage: item.systemImage) }
                .tag(item)
            }
        }
        #else
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(totalAvailableItems, selection: selectionBinding) { view in
                NavigationLink(value: view) {
                    Label(view.title, systemImage: view.systemImage)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                if let onClose {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close, action: onClose)
                    }
                }
            }
        } detail: {
            Group {
                if let selection = selectionBinding.wrappedValue {
                    settingsDetail(for: selection)
                } else {
                    Text("Select a setting")
                }
            }
            .toolbar {
                // When the sidebar is collapsed in regular width, or we're
                // in compact width without a sidebar visible, expose the
                // close button on the detail's nav bar so the sheet can
                // still be dismissed.
                if let onClose, shouldShowDetailClose {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close, action: onClose)
                    }
                }
            }
        }
        .task(id: "initial-selection") {
            if selectionBinding.wrappedValue == nil && sizeClass != .compact {
                selectionBinding.wrappedValue = .general
            }
        }
        #endif
    }

    #if os(macOS)
    private var macTabSelectionBinding: Binding<SettingsItem> {
        Binding(
            get: { SettingsItem(rawValue: storedSelection) ?? .general },
            set: { storedSelection = $0.rawValue }
        )
    }
    #endif

    private var shouldShowDetailClose: Bool {
        // Compact mode stacks into a NavigationStack — the sidebar is the
        // root and the detail is pushed, so the system-provided back button
        // gets the user back to the sidebar's close button.
        guard sizeClass == .regular else { return false }
        return columnVisibility == .detailOnly
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
        case .wikis:
            WikisSettings()
        }
    }
}

enum SettingsItem: String, CaseIterable, Identifiable {
    case general
    case apiProvider
    case personalization
    case agents
    case wikis

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .apiProvider: "API Provider"
        case .personalization: "Personalization"
        case .agents: "Squidlets"
        case .wikis: "Wikis"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .apiProvider: "link"
        case .personalization: "paintpalette"
        case .agents: "person.crop.square"
        case .wikis: "books.vertical"
        }
    }
}

#Preview {
    //SettingsView(selection: .general)
}
