//
//  ThinkingView.swift
//  Relista
//
//  Created by Nicolas Helbig on 28.02.26.
//

import SwiftUI

struct ThinkingView: View {
    let thinkingBlock: ThinkingBlock

    @Namespace private var ThinkingTransition
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @AppStorage("AlwaysShowChainOfThought") private var alwaysShowCOT: Bool = true
    @State private var expandCOT = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "fossil.shell")
                    .imageScale(.small)
                Text("Thinking")
                    .fontWeight(.medium)
                /*Text("Summary may be displayed here in the future")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)*/
                if thinkingBlock.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }
                Image(systemName: "chevron.down")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                    .rotationEffect(Angle(degrees: expandCOT ? 180 : 0))
            }
            .opacity(0.7)
            .animation(.default, value: thinkingBlock.isLoading)
            .matchedTransitionSource(id: "thinking", in: ThinkingTransition)
            
            .padding(8)
            .contentShape(Rectangle())
            #if os(iOS)
            .hoverEffect(.highlight)
            #endif
            .padding(.vertical, -4)
            .padding(.horizontal, -8)
            .onTapGesture {
                withAnimation{
                    expandCOT.toggle()
                }
            }
            
            if expandCOT{
                Text(thinkingBlock.text)
                    //.font(.body)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(alignment: .leading)
                    .padding(.vertical, 8)
            }
        }
        .onAppear{
            expandCOT = alwaysShowCOT
        }
        .padding(.vertical, 4)
    }
}
