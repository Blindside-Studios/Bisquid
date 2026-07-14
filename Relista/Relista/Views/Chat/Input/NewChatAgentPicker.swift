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
    @ScaledMetric(relativeTo: .body) var size = 18
    
    @ObservedObject private var agentManager = AgentManager.shared
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                HStack {
                    AgentManager.getAgentImage(fromUUID: nil)
                        .frame(width: size, height: size)
                    Text("Default")
                    Spacer()
                        .frame(width: 2)
                }
                .padding(6)
                .glassEffect(.regular.tint(selectedAgent == nil ? .accentColor.opacity(0.5) : nil), in: .rect(cornerRadius: 12, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .animation(.default, value: selectedAgent)
                #if os(iOS)
                .hoverEffect(.lift)
                #endif
                .onTapGesture {
                    conversationID = DatabaseManager.createNewConversation(
                        fromID: conversationID
                    ).newChatUUID
                    selectedAgent = nil
                }
                
                ForEach(agentManager.customAgents.filter { $0.shownInSidebar }) { agent in
                    let isCurrentAgent = selectedAgent == Optional(agent.id)
                    let colorResponse = AgentManager.getUIAgentColors(fromUUID: agent.id)
                    let primaryAccentColor: Color = {
                        if let primaryHex = colorResponse[0], let color = Color(hex: primaryHex) {
                            return color
                        }
                        return .accentColor
                    }()
                    
                    HStack {
                        AgentManager.getAgentImage(fromUUID: agent.id)
                            .frame(width: size, height: size)
                        Text(agent.name)
                        Spacer()
                            .frame(width: 2)
                    }
                    .padding(6)
                    .glassEffect(.regular.tint(isCurrentAgent ? primaryAccentColor.opacity(0.5) : nil), in: .rect(cornerRadius: 12, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .animation(.default, value: isCurrentAgent)
                    #if os(iOS)
                    .hoverEffect(.lift)
                    #endif
                    .onTapGesture {
                        let result = DatabaseManager.createNewConversation(
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
