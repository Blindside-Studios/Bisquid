//
//  SidebarSectionHeader.swift
//  Bisquid
//
//  Created by Nicolas Helbig on 15.04.26.
//

import SwiftUI

struct SidebarSectionHeader: View {
    var label: String
    @Binding var state: Bool
    @State private var isHovering: Bool = false
    
    var body: some View {
        Button{
            state.toggle()
        } label: {
            HStack(spacing: 4){
                Text(label)
                    .font(.callout)
                if (isHovering){
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .rotationEffect(state ? Angle(degrees: -180) : Angle(degrees: 0))
                }
            }
            .opacity(0.7)
            .padding(8)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
            #if os(iOS)
            .hoverEffect(.highlight)
            #endif
            .padding(-8)
            .padding(.vertical, 4)
            .padding(.leading, 8)
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .animation(.bouncy, value: state)
        .animation(.bouncy, value: isHovering)
    }
}

#Preview {
    SidebarSectionHeader(label: "Label", state: .constant(false))
}
