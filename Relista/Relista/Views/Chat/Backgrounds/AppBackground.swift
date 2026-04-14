//
//  AppBackground.swift
//  Bisquid
//
//  Created by Nicolas Helbig on 27.03.26.
//

import SwiftUI

struct AppBackground: View {
    var style = 0
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("ApplyBackgroundBisquidTheme") private var useBisquidBackground: Bool = true
    
    var body: some View {
        ZStack{
            if useBisquidBackground{
                Color(hex: colorScheme == .dark ? "1a1918" : "eceae9") // squid ink and squid ink after twenty minutes in the ocean (very dissolved)
                    .ignoresSafeArea()
                    .animation(.default, value: colorScheme)
            } else {
                #if os(iOS)
                if style == 0{
                    Color(UIColor.systemBackground)
                } else if style == 1 {
                    Color(UIColor.secondarySystemBackground)
                }
                #endif
            }
        }
        .ignoresSafeArea(edges: .all)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AppBackground()
}
