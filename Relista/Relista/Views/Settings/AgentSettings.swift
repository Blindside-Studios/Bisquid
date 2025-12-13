//
//  AgentSettings.swift
//  Relista
//
//  Created by Nicolas Helbig on 20.11.25.
//

import SwiftUI

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
                                    if let index = manager.customAgents.firstIndex(where: { $0.id == agent.id }) {
                                        let agentID = agent.id
                                        manager.customAgents.remove(at: index)
                                        CloudKitSyncManager.shared.markAgentDeleted(agentID)
                                        try? AgentManager.shared.saveAgents()
                                    }
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
        // Mark agents as deleted before removing
        for index in offsets {
            CloudKitSyncManager.shared.markAgentDeleted(manager.customAgents[index].id)
        }
        manager.customAgents.remove(atOffsets: offsets)
        try? AgentManager.shared.saveAgents()
    }
    
    private func moveAgents(from source: IndexSet, to destination: Int) {
        manager.customAgents.move(fromOffsets: source, toOffset: destination)
        try? AgentManager.shared.saveAgents()
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
            shownInSidebar: true
        )
        
        AgentManager.shared.customAgents.append(newAgent)
        try? AgentManager.shared.saveAgents()
        isPresented = false
    }
}

struct AgentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var agent: Agent

    @State private var showModelPickerPopOver = false

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Name", text: $agent.name)
                TextField("Description", text: $agent.description)
                TextField("Icon (Emoji)", text: $agent.icon)
                    .font(.largeTitle)
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
        }
        .onDisappear {
            try? AgentManager.shared.saveAgents()
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
