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
                Text("Thinking")
                    .fontWeight(.medium)
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
            .onTapGesture {
                withAnimation{
                    expandCOT.toggle()
                }
            }
            
            if expandCOT{
                Text(thinkingBlock.text)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(alignment: .leading)
                    .padding(.top, 4)
            }
        }
        .onAppear{
            expandCOT = alwaysShowCOT
        }
        .padding(.vertical, 4)
    }
}
