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
    @SceneStorage("sidebar.showingSettings") private var showingSettings: Bool = false
    #endif

    var body: some View {
        VStack(spacing: 0){
            SidebarToolButton(assignedTool: .documentAI, shownContentType: $shownContentType, toolName: "Documents", systemImage: "document.on.document")
            SidebarToolButton(assignedTool: .audioAI, shownContentType: $shownContentType, toolName: "Audio", systemImage: "waveform")

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
        #if os(iOS)
        .sheet(isPresented: $showingSettings) {
            SettingsView(onClose: { showingSettings = false })
                .presentationSizing(.page)
        }
        #endif
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
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .glassEffect(in: .rect(cornerRadius: 16.0))
                    .transition(
                        hSizeClass == .compact
                        ? .opacity
                        : .opacity.combined(with: .scale(scale: 0.3)).combined(with: .offset(x: -100))
                    )
            }
        }
        .animation(.default, value: shownContentType)
    }
}

#Preview {
    SidebarToolSelector(shownContentType: .init(projectedValue: .constant(.chat)))
}
