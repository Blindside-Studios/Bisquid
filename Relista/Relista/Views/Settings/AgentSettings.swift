//
//  AgentSettings.swift
//  Relista
//
//  Created by Nicolas Helbig on 20.11.25.
//

import SwiftUI

// MARK: - Color Extension for Hex Conversion
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        let r, g, b, a: Double

        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    func toHex() -> String? {
        guard let components = self.cgColor?.components, components.count >= 3 else {
            return nil
        }

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        let a = components.count >= 4 ? Float(components[3]) : 1.0

        if a < 1.0 {
            return String(format: "#%02lX%02lX%02lX%02lX",
                         lroundf(r * 255),
                         lroundf(g * 255),
                         lroundf(b * 255),
                         lroundf(a * 255))
        } else {
            return String(format: "#%02lX%02lX%02lX",
                         lroundf(r * 255),
                         lroundf(g * 255),
                         lroundf(b * 255))
        }
    }
}

struct AgentSettings: View {
    @StateObject private var manager = AgentManager.shared

    @State private var showCreateSheet = false
    @State private var selectedAgent: Agent?

    var body: some View {
        Group {
            if manager.customAgents.isEmpty {
                ContentUnavailableView(
                    "No Agents Yet",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("Create your first custom agent to get started.")
                )
            } else {
                List {
                    ForEach(manager.customAgents) { agent in
                        HStack {
                            Text(agent.icon)
                                .font(.largeTitle)
                                .padding(.trailing, 4)

                            VStack(alignment: .leading) {
                                Text(agent.name)
                                Text(agent.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedAgent = agent
                        }
                        .contextMenu {
                                Button(role: .destructive) {
                                    // Use new deleteAgent() API for proper sync
                                    try? AgentManager.shared.deleteAgent(agent.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete(perform: deleteAgents)
                    .onMove(perform: moveAgents)
                }
            }
        }
        .navigationTitle("Agents")
        .toolbar(){
            ToolbarItemGroup(placement: .automatic) {
                Button("New Squidlet", systemImage: "square.and.pencil"){
                    showCreateSheet = true
                }
            }
        }
        .sheet(item: $selectedAgent) { agent in
            NavigationStack {
                AgentDetailView(agent: binding(for: agent))
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            AgentCreateView(isPresented: $showCreateSheet)
        }
    }
    
    private func deleteAgents(at offsets: IndexSet) {
        // Use new deleteAgent() API for each agent
        for index in offsets {
            let agentID = manager.customAgents[index].id
            try? AgentManager.shared.deleteAgent(agentID)
        }
    }
    
    private func moveAgents(from source: IndexSet, to destination: Int) {
        manager.customAgents.move(fromOffsets: source, toOffset: destination)
        try? AgentManager.shared.saveToDisk()
    }
    
    private func binding(for agent: Agent) -> Binding<Agent> {
        guard let index = manager.customAgents.firstIndex(where: { $0.id == agent.id }) else {
            fatalError("Agent not found")
        }
        return $manager.customAgents[index]
    }
}

struct AgentCreateView: View {
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var description = ""
    @State private var icon = "🤖"
    @State private var systemPrompt = ""
    @State private var temperature = 1.0
    @State private var model: String = ModelList.placeHolderModel
    @State private var primaryAccentColor: Color = .blue
    @State private var secondaryAccentColor: Color = .purple
    @State private var memories: [String] = []

    @State private var showModelPickerPopOver: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                    TextField("Icon (Emoji)", text: $icon)
                        .font(.largeTitle)
                }

                Section("Colors") {
                    ColorPicker("Primary Accent Color", selection: $primaryAccentColor)
                    ColorPicker("Secondary Accent Color", selection: $secondaryAccentColor)
                }

                Section("System Prompt") {
                    TextEditor(text: $systemPrompt)
                        .frame(minHeight: 120)
                }

                Section("Temperature") {
                    Slider(value: $temperature, in: 0...2, step: 0.1)
                }

                Section("Model") {
                    ModelPicker(selectedModel: $model)
                }

                Section("Memories") {
                    MemoryListEditor(memories: $memories)
                }
            }
            .navigationTitle("New Agent")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func create() {
        let newAgent = Agent(
            name: name,
            description: description,
            icon: icon,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            shownInSidebar: true,
            primaryAccentColor: primaryAccentColor.toHex(),
            secondaryAccentColor: secondaryAccentColor.toHex(),
            memories: memories
        )

        // Use new createAgent() API for proper timestamp and sync
        try? AgentManager.shared.createAgent(newAgent)
        isPresented = false
    }
}

struct AgentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var agent: Agent

    @State private var showModelPickerPopOver = false

    // Computed bindings for color pickers
    private var primaryColorBinding: Binding<Color> {
        Binding(
            get: {
                if let hexString = agent.primaryAccentColor,
                   let color = Color(hex: hexString) {
                    return color
                }
                return .blue // Default color
            },
            set: { newColor in
                agent.primaryAccentColor = newColor.toHex()
            }
        )
    }

    private var secondaryColorBinding: Binding<Color> {
        Binding(
            get: {
                if let hexString = agent.secondaryAccentColor,
                   let color = Color(hex: hexString) {
                    return color
                }
                return .purple // Default color
            },
            set: { newColor in
                agent.secondaryAccentColor = newColor.toHex()
            }
        )
    }

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Name", text: $agent.name)
                TextField("Description", text: $agent.description)
                TextField("Icon (Emoji)", text: $agent.icon)
                    .font(.largeTitle)
            }

            Section("Colors") {
                ColorPicker("Primary Accent Color", selection: primaryColorBinding)
                ColorPicker("Secondary Accent Color", selection: secondaryColorBinding)
            }

            Section("Model") {
                ModelPicker(selectedModel: $agent.model)
            }

            Section("System Prompt") {
                TextEditor(text: $agent.systemPrompt)
                    .frame(minHeight: 150)
            }

            Section("Temperature") {
                Slider(value: $agent.temperature, in: 0...2, step: 0.1)
                Text("Current: \(agent.temperature, specifier: "%.1f")")
            }

            Section("Sidebar") {
                Toggle("Show in Sidebar", isOn: $agent.shownInSidebar)
            }

            Section("Memories") {
                MemoryListEditor(memories: $agent.memories)
            }
        }
        .onDisappear {
            // Use updateAgent() to properly save with timestamp update
            try? AgentManager.shared.updateAgent(agent.id) { _ in
                // Agent is already updated via binding
            }
        }
        .navigationTitle(agent.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

extension Binding where Value == String {
    init(_ source: Binding<String?>, replacingNilWith defaultValue: String) {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { source.wrappedValue = $0 }
        )
    }
}

#Preview {
    AgentSettings()
}
