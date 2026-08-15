//
//  SidebarToolSelector.swift
//  Bisquid
//
//  Created by Nicolas Helbig on 27.03.26.
//

import SwiftUI

struct SidebarToolSelector: View {
    @Binding var shownContentType: ContentType
    #if os(iOS)
    // Shared by key with ContentView, which presents the actual sheet — see the
    // comment there for why the presentation itself doesn't happen in this view.
    @SceneStorage("sidebar.showingSettings") private var showingSettings: Bool = false
    #endif

    var body: some View {
        VStack(spacing: 0){
            //SidebarToolButton(assignedTool: .documentAI, shownContentType: $shownContentType, toolName: "Documents", systemImage: "document.on.document")
            //SidebarToolButton(assignedTool: .audioAI, shownContentType: $shownContentType, toolName: "Audio", systemImage: "waveform")

            SidebarToolButton(assignedTool: .agents, shownContentType: $shownContentType, toolName: "Squidlets", systemImage: "person.crop.square")
            SidebarToolButton(assignedTool: .wikis, shownContentType: $shownContentType, toolName: "Wikis", systemImage: "books.vertical")
            
            #if os(macOS)
            SettingsLink{
                HStack {
                    Label("Settings", systemImage: "gearshape")
                    Text("Settings")
                    Spacer()
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .labelStyle(.iconOnly)
            .backgroundStyle(.clear)
            #else
            Button {
                showingSettings.toggle()
            } label: {
                HStack {
                    Label("Settings", systemImage: "gearshape")
                    Text("Settings")
                    Spacer()
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .labelStyle(.iconOnly)
            .backgroundStyle(.clear)
            #endif
        }
    }
}
 
struct SidebarToolButton: View {
    var assignedTool: ContentType
    @Binding var shownContentType: ContentType
    var toolName: String
    var systemImage: String
    
    @Environment(\.onSidebarSelection) private var onSidebarSelection
    @Environment(\.horizontalSizeClass) private var hSizeClass
    
    var body: some View {
        Button {
            shownContentType = assignedTool
            onSidebarSelection?()
        } label: {
            HStack {
                Label(toolName, systemImage: systemImage)
                Text(toolName)
                Spacer()
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .labelStyle(.iconOnly)
        .backgroundStyle(.clear)
        .background {
            if shownContentType == assignedTool {
                PanelItemBackground()
            }
        }
        .animation(.default, value: shownContentType)
    }
}

#Preview {
    SidebarToolSelector(shownContentType: .init(projectedValue: .constant(.chat)))
}
