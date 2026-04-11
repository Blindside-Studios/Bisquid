//
//  NewChatAgentPicker.swift
//  Relista
//
//  Created by Nicolas Helbig on 18.01.26.
//

import SwiftUI

struct NewChatAgentPicker: View {
    @Binding var conversationID: UUID
    @Binding var selectedAgent: UUID?
    @Binding var selectedModel: String
    
    @Environment(\.colorScheme) var colorScheme
    
    @ObservedObject private var agentManager = AgentManager.shared
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                HStack {
                    Text("🐙 Default")
                    Spacer()
                        .frame(width: 2)
                }
                .padding(6)
                //.glassEffect(.clear.tint(selectedAgent == nil ? .accentColor.opacity(0.5) : .black.opacity(0.1)).interactive(), in: .rect(cornerRadius: 10, style: .continuous))
                //.glassEffect(.regular.tint(selectedAgent == nil ? .accentColor.opacity(0.5) : .clear).interactive(), in: .rect(cornerRadius: 10, style: .continuous))
                //.background(.bar)
                //.border(.gray.opacity(0.2), width: 1)
                //.background(selectedAgent == nil ? Color.accentColor.opacity(0.5) : .clear)
                .background(.bar)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .tint(selectedAgent == nil ? Color.accentColor.opacity(0.5) : .clear)
                .glassEffect(.clear.tint(selectedAgent == nil ? .accentColor : .clear).interactive(), in: .rect(cornerRadius: 10, style: .continuous))
                .animation(.default, value: selectedAgent)
                #if os(iOS)
                .hoverEffect(.lift)
                #endif
                .onTapGesture {
                    conversationID = ConversationManager.createNewConversation(
                        fromID: conversationID
                    ).newChatUUID
                    selectedAgent = nil
                }
                
                ForEach(agentManager.customAgents.filter { $0.shownInSidebar }) { agent in
                    let isCurrentAgent = selectedAgent == Optional(agent.id)
                    let colorResponse = AgentManager.getUIAgentColors(fromUUID: agent.id)
                    let primaryAccentColor: Color = {
                        if let primaryHex = colorResponse[0] {
                            let cleanPrimary = primaryHex.replacingOccurrences(of: "#", with: "")
                            return Color(hex: cleanPrimary) ?? .blue
                        }
                        return .blue
                    }()
                    
                    HStack {
                        Text(agent.icon + " " + agent.name)
                        Spacer()
                            .frame(width: 2)
                    }
                    .padding(6)
                    //.glassEffect(.clear.tint(isCurrentAgent ? primaryAccentColor.opacity(0.5) : .black.opacity(0.1)).interactive(), in: .rect(cornerRadius: 10, style: .continuous))
                    //.glassEffect(.regular.tint(isCurrentAgent ? primaryAccentColor.opacity(0.5) : .clear).interactive(), in: .rect(cornerRadius: 10, style: .continuous))
                    //.background(.bar)
                    //.border(.gray.opacity(0.2), width: 1)
                    //.background(isCurrentAgent ? primaryAccentColor.opacity(0.5) : .clear)
                    .background(.bar)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .tint(isCurrentAgent ? primaryAccentColor.opacity(0.5) : .clear)
                    //.glassEffect(.clear.tint(isCurrentAgent ? primaryAccentColor.opacity(0.5) : .clear).interactive(), in: .rect(cornerRadius: 10, style: .continuous))
                    .glassEffect(.clear.tint(isCurrentAgent ? primaryAccentColor : .clear).interactive(), in: .rect(cornerRadius: 10, style: .continuous))
                    .animation(.default, value: isCurrentAgent)
                    #if os(iOS)
                    .hoverEffect(.lift)
                    #endif
                    .onTapGesture {
                        let result = ConversationManager.createNewConversation(
                            fromID: conversationID,
                            withAgent: agent.id
                        )
                        conversationID = result.newChatUUID
                        selectedAgent = agent.id
                        if !agent.model.isEmpty { selectedModel = agent.model }
                    }
                }
            }
            .font(.callout)
            .padding(.vertical, 12) // ensure the shadow is rendered fully
            .padding(.horizontal, 12 + 12)
        }
        .scrollIndicators(.hidden)
        //.blocksHorizontalSidebarGesture()
        .padding(-12) // ensure shadow rendering won't affect layout... this is very buggy but Apple may fix it at some point
    }
}

#Preview {
    //NewChatAgentPicker(selectedAgent: .constant(nil))
}
