//
//  ToolsButton.swift
//  Relista
//
//  Created by Nicolas Helbig on 28.02.26.
//

import SwiftUI

struct ToolsButton: View {
    @Namespace private var ToolsTransition
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State private var showPopover = false
    @State private var showSheet = false
    
    @State private var anyEnabled = !ToolRegistry.enabledTools().isEmpty
    @State private var allEnabled = ToolRegistry.enabledTools().count < ToolRegistry.allTools.count

    var body: some View {
        Button {
            if horizontalSizeClass == .compact { showSheet = true }
            else { showPopover.toggle() }
        } label: {
            ZStack{
                // top switch is disabled, bottom switch is enabled
                Label("Tools", systemImage: "switch.2")
                // flip to enable top switch
                    .scaleEffect(y: anyEnabled ? -1 : 1)
                    .mask{
                        VStack(spacing: 0){
                            Color.black
                            Color.clear
                        }
                    }
                Label("Tools", systemImage: "switch.2")
                // flip to disable bottom switch
                    .scaleEffect(y: allEnabled ? -1 : 1)
                    .mask{
                        VStack(spacing: 0){
                            Color.clear
                            Color.black
                        }
                    }
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color.clear)
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        //.animation(.default, value: anyEnabled)
        .matchedTransitionSource(id: "tools", in: ToolsTransition)
        .popover(isPresented: $showPopover) {
            ToolsPopoverContents(onToggle: reevaluateIcon)
                .presentationCompactAdaptation(.popover)
        }
        #if os(iOS)
        .sheet(isPresented: $showSheet) {
            ScrollView(.vertical){
                ToolsPopoverContents()
                    .presentationDetents([.fraction(0.3), .medium])
                    .navigationTransition(.zoom(sourceID: "tools", in: ToolsTransition))
                    .padding(4)
                Spacer()
            }
        }
        #endif
        .onChange(of: showPopover, reevaluateIcon)
        .onChange(of: showSheet, reevaluateIcon)
    }
    
    private func reevaluateIcon(){
        anyEnabled = !ToolRegistry.enabledTools().isEmpty
        allEnabled = ToolRegistry.enabledTools().count < ToolRegistry.allTools.count
    }
}

private struct ToolsPopoverContents: View {
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Tools")
                .font(.title)
                .padding(.bottom, 8)

            ForEach(ToolRegistry.allTools.indices, id: \.self) { i in
                ToolToggleRow(tool: ToolRegistry.allTools[i], onToggle: onToggle)
                if i < ToolRegistry.allTools.count - 1 {
                    Divider()
                }
            }
        }
        .padding()
    }
}

private struct ToolToggleRow: View {
    let tool: any ChatTool
    let onToggle: () -> Void
    @State private var isEnabled: Bool

    init(tool: any ChatTool, onToggle: @escaping () -> Void) {
        self.tool = tool
        self.onToggle = onToggle
        self._isEnabled = State(initialValue: ToolRegistry.isEnabled(tool))
    }

    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack(spacing: 10) {
                Image(systemName: tool.icon)
                    .frame(width: 20)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.displayName)
                        .fontWeight(.medium)
                    Text(tool.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 6)
        .onChange(of: isEnabled) { _, newValue in
            ToolRegistry.setEnabled(newValue, for: tool)
            onToggle()
        }
    }
}

#Preview {
    ToolsButton()
}
