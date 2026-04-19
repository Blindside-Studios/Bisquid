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
            AgentEditorView(agent: agent)
                .presentationSizing(.page)
        }
        .sheet(isPresented: $showCreateSheet) {
            AgentEditorView()
                .presentationSizing(.page)
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
}

struct AgentEditorView: View {
    enum Mode: Equatable {
        case create
        case edit(UUID)
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    @State private var agent: Agent

    init(agent: Agent) {
        self.mode = .edit(agent.id)
        _agent = State(initialValue: agent)
    }

    init() {
        self.mode = .create
        _agent = State(initialValue: Agent(
            name: "",
            description: "",
            icon: "🤖",
            model: ModelList.placeHolderModel,
            systemPrompt: "",
            temperature: 1.0,
            shownInSidebar: true,
            primaryAccentColor: Color.blue.toHex(),
            secondaryAccentColor: Color.purple.toHex(),
            memories: []
        ))
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var primaryColorBinding: Binding<Color> {
        Binding(
            get: {
                if let hex = agent.primaryAccentColor, let color = Color(hex: hex) { return color }
                return .blue
            },
            set: { agent.primaryAccentColor = $0.toHex() }
        )
    }

    private var secondaryColorBinding: Binding<Color> {
        Binding(
            get: {
                if let hex = agent.secondaryAccentColor, let color = Color(hex: hex) { return color }
                return .purple
            },
            set: { agent.secondaryAccentColor = $0.toHex() }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section{
                    VStack{
                        HStack{
                            TextField("Icon (Emoji)", text: $agent.icon)
                                .frame(width: 92, height: 92)
                                .font(.system(size: 72))
                                .gesture(TapGesture().onEnded {
                                    //self.showingImagePicker.toggle()
                                })
                                .padding(.horizontal, 16)
                            
                            VStack{
                                Text("Hello")
                                    .bold()
                                    .font(.largeTitle)
                                Text("My Name is")
                                //.bold()
                                TextField("Bob", text: $agent.name)
                                    .bold()
                                    .foregroundStyle(.black)
                                    .multilineTextAlignment(.center)
                                    .textFieldStyle(.plain)
                                    .font(.title2)
                                    .padding(8)
                                    .background{
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color(.systemGroupedBackground))
                                    }
                                    //.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16, style: .continuous))
                            }
                        }
                        
                        Divider()
                        
                        TextField("Add a description", text: $agent.description)
                            .foregroundStyle(.black)
                            .opacity(0.7)
                            .multilineTextAlignment(.center)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .padding(8)
                            .background{
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.systemGroupedBackground))
                            }
                            //.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16, style: .continuous))
                    }
                    .padding(8)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .background{
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    }
                    .frame(maxWidth: 400)
                }
                
                /*Section("Basics") {
                 TextField("Name", text: $agent.name)
                 TextField("Description", text: $agent.description)
                 TextField("Icon (Emoji)", text: $agent.icon)
                 .font(.largeTitle)
                 }*/
                
                Section("Colors") {
                    ColorPicker("Primary Accent Color", selection: primaryColorBinding)
                    ColorPicker("Secondary Accent Color", selection: secondaryColorBinding)
                }
                
                Section("System Prompt") {
                    TextField("Tell your Squidlet how to respond", text: $agent.systemPrompt, axis: .vertical)
                        .lineLimit(5...)
                }
                
                Section("Temperature") {
                    Slider(value: $agent.temperature, in: 0...2, step: 0.1)
                }
                
                Section("Model") {
                    ModelPicker(selectedModel: $agent.model)
                }
                
                Section("Sidebar") {
                    Toggle("Show in Sidebar", isOn: $agent.shownInSidebar)
                }
                
                Section("Memories") {
                    MemoryListEditor(memories: $agent.memories)
                }
            }
            //.navigationTitle(isEditing ? agent.name : "New Squidlet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { save() }
                        .disabled(agent.name.isEmpty)
                }
            }
        }
    }

    private func save() {
        switch mode {
        case .create:
            try? AgentManager.shared.createAgent(agent)
        case .edit(let id):
            try? AgentManager.shared.updateAgent(id) { existing in
                existing = agent
            }
        }
        dismiss()
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
