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
                .glassEffect(.clear.tint(selectedAgent == nil ? .accentColor.opacity(0.5) : .black.opacity(0.1)).interactive(), in: .rect(cornerRadius: 10, style: .continuous))
                //.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)) // removes shadows
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
                    .glassEffect(.clear.tint(isCurrentAgent ? primaryAccentColor.opacity(0.5) : .black.opacity(0.1)).interactive(), in: .rect(cornerRadius: 10, style: .continuous))
                    //.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
