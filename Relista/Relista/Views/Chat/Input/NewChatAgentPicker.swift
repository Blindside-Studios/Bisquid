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
    
    private var othersButtonColor: Color? {
        guard let selectedAgent,
              let selectedAgentObj = AgentManager.shared.customAgents.first(where: { $0.id == selectedAgent }),
              !selectedAgentObj.shownInSidebar,
              let primaryHex = AgentManager.getUIAgentColors(fromUUID: selectedAgent)[0],
              let color = Color(hex: primaryHex)
        else {
            return nil
        }
        return color.opacity(0.5)
    }
    
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
                .contentShape(Rectangle())
                .compatGlassEffect(tint: selectedAgent == nil ? .accentColor.opacity(0.5) : nil, in: RoundedRectangle(cornerRadius: 12.0, style: .continuous))
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
                    .contentShape(Rectangle())
                    .compatGlassEffect(tint: isCurrentAgent ? primaryAccentColor.opacity(0.5) : nil, in: RoundedRectangle(cornerRadius: 12.0, style: .continuous))
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
                
                if (!agentManager.customAgents.filter{!$0.shownInSidebar}.isEmpty) {
                    Menu {
                        ForEach(agentManager.customAgents.filter{!$0.shownInSidebar}) { agent in
                            Button {
                                let result = DatabaseManager.createNewConversation(
                                    fromID: conversationID,
                                    withAgent: agent.id
                                )
                                conversationID = result.newChatUUID
                                selectedAgent = agent.id
                                if !agent.model.isEmpty { selectedModel = agent.model }
                            } label: {
                                HStack{
                                    if selectedAgent == agent.id {
                                        Image(systemName: "checkmark")
                                    }
                                    #if os(iOS)
                                    AgentManager.getAgentImage(fromUUID: agent.id)
                                    #endif
                                    Text(agent.name)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "ellipsis")
                                .frame(width: size, height: size)
                            Text("Other")
                            Spacer()
                                .frame(width: 2)
                        }
                        .padding(6)
                        .contentShape(Rectangle())
                        .compatGlassEffect(tint: othersButtonColor, in: RoundedRectangle(cornerRadius: 12.0, style: .continuous))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .animation(.default, value: othersButtonColor)
                        #if os(iOS)
                        .hoverEffect(.lift)
                        #endif
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .labelStyle(.titleAndIcon)
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
