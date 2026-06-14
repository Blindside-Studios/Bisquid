//
//  CommandBar.swift
//  Relista
//
//  Created by Nicolas Helbig on 13.12.25.
//

import SwiftUI

struct CommandBar: View {
    let isVertical: Bool
    @Binding var selectedModel: String
    @State var chatCache = ChatCache.shared
    @Binding var conversationID: UUID
    @Binding var secondaryAccentColor: Color
    @Binding var pendingAttachments: [PendingAttachment]

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    let sendMessage: () -> Void
    let sendMessageAsSystem: () -> Void
    let appendDummyMessages: () -> Void
    var inputFieldNamespace: Namespace.ID

    var body: some View {
        #if os(macOS)
        let spacing: CGFloat = 12
        #else
        let spacing: CGFloat = 16
        #endif

        if !isVertical{
            HStack {
                HStack(alignment: .center, spacing: 0){
                    AttachmentPickerButton(pendingAttachments: $pendingAttachments)
                        .matchedGeometryEffect(id: "attachmentButton", in: inputFieldNamespace)
                    
                    ToolsButton()
                        .matchedGeometryEffect(id: "toolsButton", in: inputFieldNamespace)
                    
                    if horizontalSizeClass == .compact{
                        Spacer()
                    }
                    
                    ModelPicker(selectedModel: $selectedModel)
                        .matchedGeometryEffect(id: "modelPickerButton", in: inputFieldNamespace)
                    
                    if horizontalSizeClass != .compact{
                        Spacer()
                    }
                }
                .opacity(0.75)
                
                SendMessageButton(conversationID: $conversationID, sendMessage: sendMessage, sendMessageAsSystem: sendMessageAsSystem, accentColor: $secondaryAccentColor)
                    .matchedGeometryEffect(id: "sendButton", in: inputFieldNamespace)
            }
            .frame(maxHeight: 16)
            .padding(.leading, -8)
        } else {
            VStack(alignment: .center, spacing: 8) {
                Group{
                    AttachmentPickerButton(pendingAttachments: $pendingAttachments)
                        .matchedGeometryEffect(id: "attachmentButton", in: inputFieldNamespace)
                    ToolsButton()
                        .matchedGeometryEffect(id: "toolsButton", in: inputFieldNamespace)
                    ModelPicker(selectedModel: $selectedModel)
                        .matchedGeometryEffect(id: "modelPickerButton", in: inputFieldNamespace)
                }
                .opacity(0.75)
                .offset(x: 16)
                
                SendMessageButton(conversationID: $conversationID, sendMessage: sendMessage, sendMessageAsSystem: sendMessageAsSystem, accentColor: $secondaryAccentColor)
                    .matchedGeometryEffect(id: "sendButton", in: inputFieldNamespace)
                    .offset(x: 8)
            }
            .padding(.leading, -8)
        }
    }
}

#Preview {
    //CommandBar()
}
