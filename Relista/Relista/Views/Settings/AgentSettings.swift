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

    @SceneStorage("agents.showCreateSheet") private var showCreateSheet = false
    @SceneStorage("agents.editingAgentID") private var editingAgentID: String = ""

    private var selectedAgentBinding: Binding<Agent?> {
        Binding(
            get: {
                guard !editingAgentID.isEmpty,
                      let uuid = UUID(uuidString: editingAgentID) else { return nil }
                return manager.customAgents.first { $0.id == uuid }
            },
            set: { newValue in
                editingAgentID = newValue?.id.uuidString ?? ""
            }
        )
    }

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
                            editingAgentID = agent.id.uuidString
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
        .sheet(item: selectedAgentBinding) { agent in
            AgentEditorView(agent: agent)
                .presentationSizing(.page)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showCreateSheet) {
            AgentEditorView()
                .presentationSizing(.page)
                .interactiveDismissDisabled()
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
    @Environment(\.horizontalSizeClass) var sizeClass

    let mode: Mode
    @State private var agent: Agent
    @SceneStorage private var draftJSON: String

    init(agent: Agent) {
        self.mode = .edit(agent.id)
        _agent = State(initialValue: agent)
        _draftJSON = SceneStorage(wrappedValue: "", "agentEditor.edit.\(agent.id.uuidString)")
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
            primaryAccentColor: nil,
            secondaryAccentColor: nil,
            memories: []
        ))
        _draftJSON = SceneStorage(wrappedValue: "", "agentEditor.create")
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section{
                    if sizeClass == .regular {
                        HStack(spacing: 16) {
                            AgentHeader(name: $agent.name, description: $agent.description, icon: $agent.icon)
                            AgentColorPicker(primaryHex: $agent.primaryAccentColor, secondaryHex: $agent.secondaryAccentColor)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    } else {
                        VStack(spacing: 16) {
                            AgentHeader(name: $agent.name, description: $agent.description, icon: $agent.icon)
                            AgentColorPicker(primaryHex: $agent.primaryAccentColor, secondaryHex: $agent.secondaryAccentColor)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }
                
                /*Section("Colors") {
                    ColorPicker("Primary Accent Color", selection: primaryColorBinding)
                    ColorPicker("Secondary Accent Color", selection: secondaryColorBinding)
                }*/
                
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
                    MemoryListEditor(memories: $agent.memories, storageID: "agent")
                }
            }
            .formStyle(.grouped)
            //.navigationTitle(isEditing ? agent.name : "New Squidlet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { cancel() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { save() }
                        .disabled(agent.name.isEmpty)
                }
            }
        }
        .task {
            if !draftJSON.isEmpty,
               let data = draftJSON.data(using: .utf8),
               let restored = try? JSONDecoder().decode(Agent.self, from: data) {
                agent = restored
            }
        }
        .onChange(of: agent) { _, newValue in
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                draftJSON = json
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
        draftJSON = ""
        dismiss()
    }

    private func cancel() {
        draftJSON = ""
        dismiss()
    }
}

struct AgentHeader: View{
    @Binding var name: String
    @Binding var description: String
    @Binding var icon: String
    @Environment(\.horizontalSizeClass) var sizeClass
    var body: some View{
        VStack{
            HStack{
                TextField("Icon (Emoji)", text: $icon)
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
                    TextField("Squiddy", text: $name)
                        .bold()
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.plain)
                        .font(.title2)
                        .padding(8)
                        .background{
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                #if os(iOS)
                                .fill(Color(.systemGroupedBackground))
                                #else
                                .fill(.gray)
                                #endif
                        }
                        //.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16, style: .continuous))
                }
            }
            
            Divider()
            
            TextField("Your friendly AI who doesn't ink", text: $description)
                .opacity(0.7)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(8)
                .background{
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        #if os(iOS)
                        .fill(Color(.systemGroupedBackground))
                        #else
                        .fill(.gray)
                        #endif
                }
                //.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16, style: .continuous))
        }
        .padding(8)
        .background{
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                #if os(iOS)
                .fill(Color(.secondarySystemGroupedBackground))
                #else
                .fill(.background)
                #endif
        }
        .frame(maxWidth: sizeClass == .compact ? 500 : 350)
    }
}

struct AgentColorPreset: Identifiable, Hashable {
    let name: String
    let primaryHex: String?
    let secondaryHex: String?
    var id: String { name }

    var primaryColor: Color? {
        guard let primaryHex else { return nil }
        return Color(hex: primaryHex)
    }

    var secondaryColor: Color? {
        guard let secondaryHex else { return nil }
        return Color(hex: secondaryHex)
    }

    static let presets: [AgentColorPreset] = [
        .init(name: "Simply Bisquid",   primaryHex: nil,       secondaryHex: nil),
        .init(name: "Deepsea Violets",  primaryHex: "#0056D6", secondaryHex: "#61187C"),
        .init(name: "Split Fantasy",    primaryHex: "#669D34", secondaryHex: "#016E8F"),
        .init(name: "Timeless Love",    primaryHex: "#D30011", secondaryHex: "#C31B78"),
        .init(name: "Mechanical Poet",  primaryHex: "#91783F", secondaryHex: "#CC7C5E"),
        .init(name: "Cool Profession",  primaryHex: "#74A7FF", secondaryHex: "#858585")
    ]
}

struct AgentColorPicker: View {
    @Binding var primaryHex: String?
    @Binding var secondaryHex: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(AgentColorPreset.presets) { preset in
                    
                    let isSelected = normalized(preset.primaryHex) == normalized(primaryHex)
                                  && normalized(preset.secondaryHex) == normalized(secondaryHex)
                    
                    Button {
                        primaryHex = preset.primaryHex
                        secondaryHex = preset.secondaryHex
                    } label: {
                        VStack(spacing: 0){
                            ZStack{
                                Rectangle()
                                    .fill(.gray.opacity(0.0001))
                                VStack{
                                    HStack{
                                        Spacer()
                                            .frame(width: 15)
                                        Text("Example request")
                                            .font(.caption)
                                            .redacted(reason: .placeholder)
                                            .multilineTextAlignment(.leading)
                                            .lineLimit(2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                            .glassEffect(.regular.tint((preset.primaryColor ?? Color.clear).opacity(0.3)), in: .rect(cornerRadius: 8, style: .continuous))
                                    }
                                    ZStack{
                                        HStack{
                                            Text("This is text from the model lmao")
                                                .font(.caption)
                                                .redacted(reason: .placeholder)
                                                .multilineTextAlignment(.leading)
                                            Spacer()
                                                .frame(width: 7)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.bottom, 12)
                                        .offset(y: -4)
                                        VStack{
                                            Spacer()
                                                .frame(height: 34)
                                            ZStack{
                                                Rectangle()
                                                    .fill(.clear)
                                                    .frame(height: 24)
                                                    .glassEffect(in: .rect(cornerRadius: 12, style: .continuous))
                                                
                                                HStack{
                                                    Spacer()
                                                    Button {} label: {
                                                        Label("Mock send button", systemImage: "arrow.up")
                                                    }
                                                    .scaleEffect(0.5)
                                                    .offset(x: 12)
                                                    .buttonBorderShape(.circle)
                                                    .buttonStyle(.borderedProminent)
                                                    .tint(preset.secondaryColor ?? Color.white)
                                                    .foregroundStyle(preset.secondaryHex != nil ? Color.white : Color.black)
                                                }
                                                .padding(4)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                            .background{
                                GeometryReader { proxy in
                                    Jellyfish(primaryColor: preset.primaryColor ?? Color.clear, secondaryColor: preset.secondaryColor ?? Color.clear, showJellyfish: isSelected)
                                        .frame(width: proxy.size.width * 5, height: proxy.size.height * 5)
                                        .scaleEffect(1/5, anchor: .center)
                                        .frame(width: proxy.size.width, height: proxy.size.height)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(.gray.opacity(0.3), lineWidth: isSelected ? 2 : 0)
                                                .animation(.default, value: isSelected)
                                        }
                                }
                                .padding(.bottom, 8)
                            }
                            
                            Spacer()
                                .frame(height: 4)
                            Text(preset.name)
                                .font(.caption)
                                .lineLimit(2)
                                .opacity(isSelected ? 1 : 0.7)
                                .animation(.default, value: isSelected)
                        }
                    }
                    .frame(minHeight: 150)
                    .frame(maxWidth: 120)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                }
            }
            .frame(maxHeight: .infinity)
            .padding(16)
        }
        .background{
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                #if os(iOS)
                .fill(Color(.secondarySystemGroupedBackground))
                #else
                .fill(.background)
                #endif
        }
    }

    @ViewBuilder
    private func swatch(for preset: AgentColorPreset) -> some View {
        let isSelected = normalized(preset.primaryHex) == normalized(primaryHex)
                      && normalized(preset.secondaryHex) == normalized(secondaryHex)
        ZStack {
            if let primary = preset.primaryColor, let secondary = preset.secondaryColor {
                LinearGradient(
                    colors: [primary, secondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.15))
                    .overlay(
                        Image(systemName: "nosign")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    )
            }
            Circle()
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
                .padding(-3)
        }
        .frame(width: 36, height: 36)
        .contentShape(Circle())
    }

    func normalized(_ hex: String?) -> String? {
        hex?.replacingOccurrences(of: "#", with: "").uppercased()
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
