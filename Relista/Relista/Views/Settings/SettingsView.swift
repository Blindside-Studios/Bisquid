//
//  SettingsView.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct SettingsView: View {
    @State private var selection: SettingsItem? = .apiProvider
        
        var body: some View {
            #if os(macOS)
            NavigationSplitView {
                List(selection: $selection) {
                    ForEach(SettingsItem.allCases, id: \.self) { item in
                        NavigationLink(value: item) {
                            Label {
                                Text(item.title)
                            } icon: {
                                Image(systemName: item.systemImage)
                            }
                        }
                    }
                }
                .navigationTitle("Settings")
            } detail: {
                switch selection {
                case .general:
                    GeneralSettings()
                case .apiProvider:
                    APIProviderSettings()
                case .personalization:
                    PersonalizationSettings()
                case .agents:
                    AgentsSettings()
                case .none:
                    Text("Select a category")
                }
            }
            .frame(width: 800, height: 500)
            
            #else
            NavigationStack {
                List {
                    ForEach(SettingsItem.allCases, id: \.self) { item in
                        NavigationLink(item.title) {
                            switch item {
                            case .general:
                                GeneralSettings()
                            case .apiProvider:
                                APIProviderSettings()
                            case .personalization:
                                PersonalizationSettings()
                            case .agents:
                                AgentsSettings()
                            }
                        }
                    }
                }
                .navigationTitle("Settings")
            }
            #endif
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

struct APIProviderSettings: View {
    var body: some View {
        APIProvider()
            .padding()
    }
}

struct AgentsSettings: View {
    var body: some View {
        AgentSettings()
            .padding()
    }
}

#Preview {
    SettingsView()
}
