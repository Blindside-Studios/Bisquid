//
//  MessageModel.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI
import Textual

struct MessageModel: View {
    let message: Message
    let onRegenerate: () -> Void

    @AppStorage("AlwaysShowFullModelMessageToolbar") private var toolbarExpansionPreference: Bool = false
    @State private var isToolbarExpanded: Bool = false
    @State private var showInfoPopOver: Bool = false
    @State private var showRegenerateConfirmation: Bool = false
    
    @State private var copied = false
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        VStack{
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    if let blocks = message.contentBlocks {
                        ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                            switch block {
                            case .text(let text):
                                StructuredText(markdown: text,
                                               patternOptions: .init(mathExpressions: true))
                                .textual.textSelection(.enabled)
                                .padding(.vertical, 8)
                            case .toolUse(let toolBlock):
                                ToolUseView(toolBlock: toolBlock)
                            case .thinking(let thinkingBlock):
                                ThinkingView(thinkingBlock: thinkingBlock)
                            }
                        }
                    } else {
                        StructuredText(markdown: message.text,
                                       patternOptions: .init(mathExpressions: true))
                        .textual.textSelection(.enabled)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                Spacer()
            }
            HStack(spacing: 0) {
                if !message.text.isEmpty{
                    Button {
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.text, forType: .string)
                        #else
                        UIPasteboard.general.string = message.text
                        #endif
                        withAnimation {
                            copied = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { copied = false }
                        }
                    } label: {
                        Label("Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(minWidth: 18, minHeight: 18)
                            .padding(3)
                            .contentShape(Rectangle())
                            #if os(iOS)
                            .hoverEffect(.highlight)
                            #endif
                            .scaleEffect(0.8)
                    }
                    .disabled(copied)
                    .buttonStyle(.plain)
                    .labelStyle(.iconOnly)
                    
                    Button {
                        showRegenerateConfirmation.toggle()
                    } label: {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                            .frame(minWidth: 28, minHeight: 28)
                            .contentShape(Rectangle())
                            #if os(iOS)
                            .hoverEffect(.highlight)
                            #endif
                            .scaleEffect(0.8)
                    }
                    .buttonStyle(.plain)
                    .labelStyle(.iconOnly)
                    #if os(iOS)
                    .confirmationDialog("Regenerate this response?", isPresented: $showRegenerateConfirmation) {
                        Button("Regenerate", role: .destructive) {
                            onRegenerate()
                        }
                    } message: {
                        Text("Regenerating will delete this message and restart the chat from here")
                    }
                    #else
                    .popover(isPresented: $showRegenerateConfirmation) {
                        VStack{
                            Text("Regenerating will delete this message and restart the chat from here")
                                .lineLimit(nil)
                                .multilineTextAlignment(.center)
                            Button("Regenerate") {
                                onRegenerate()
                            }
                        }
                        .frame(width: 250, height: 70)
                        .padding()
                    }
                    #endif
                    
                    
                    if horizontalSizeClass == .compact{
                        Button {
                            showInfoPopOver.toggle()
                        } label: {
                            Label("Show message info", systemImage: "info.circle")
                                .frame(minWidth: 28, minHeight: 28)
                                .contentShape(Rectangle())
                                #if os(iOS)
                                .hoverEffect(.highlight)
                                #endif
                                .scaleEffect(0.8)
                                .rotationEffect(showInfoPopOver ? Angle(degrees: 0) : Angle(degrees: -360))
                        }
                        .popover(isPresented: $showInfoPopOver) {
                            let modelUsed = ModelList.getModelFromSlug(slug: message.modelUsed)
                            VStack(alignment: .leading) {
                                Text(formatMessageTimestamp(message.timeStamp))
                                Text(message.timeStamp.formatted())
                                    .font(.caption)
                                    .opacity(0.7)
                                Divider()
                                Text(modelUsed.name)
                                if modelUsed.name != modelUsed.modelID{
                                    Text(modelUsed.modelID)
                                        .font(.caption)
                                        .opacity(0.7)
                                }
                            }
                            .padding()
                            .presentationCompactAdaptation(.popover)
                        }
                        .buttonStyle(.plain)
                        .labelStyle(.iconOnly)
                    }
                    else{
                        if (isToolbarExpanded){
                            Divider()
                                .frame(height:12)
                            Text(formatMessageTimestamp(message.timeStamp))
                                .help(message.timeStamp.formatted())
                            Divider()
                                .frame(height:12)
                            Text(ModelList.getModelFromSlug(slug: message.modelUsed).name)
                                .help(message.modelUsed)
                        }
                        
                        Button {
                            withAnimation(.bouncy(duration: 0.3, extraBounce: 0.05)) {
                                isToolbarExpanded.toggle()
                            }
                        } label: {
                            Label("Expand/Collapse toolbar", systemImage: "chevron.forward")
                                .frame(minWidth: 28, minHeight: 28)
                                .contentShape(Rectangle())
                                #if os(iOS)
                                .hoverEffect(.highlight)
                                #endif
                                .scaleEffect(0.8)
                                .rotationEffect(isToolbarExpanded ? Angle(degrees: -180) : Angle(degrees: 0))
                        }
                        .buttonStyle(.plain)
                        .labelStyle(.iconOnly)
                        
                    }
                    Spacer()
                }
            }
            .padding(.leading, 10)
            .opacity(0.4)
            .padding(.top, -5)
            
            Spacer()
                .frame(minHeight: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, horizontalSizeClass == .compact ? 0 : 8)
        .onAppear(){
            if toolbarExpansionPreference {isToolbarExpanded = true}
        }
    }
    
    func formatMessageTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return formatter.string(from: date)
        }

        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    //MessageModel(messageText: "User message")
}
