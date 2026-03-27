//
//  AppBackground.swift
//  Bisquid
//
//  Created by Nicolas Helbig on 27.03.26.
//

import SwiftUI

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("ApplyBackgroundBisquidTheme") private var useBisquidBackground: Bool = true
    
    var body: some View {
        ZStack{
            if useBisquidBackground{
                Color(hex: colorScheme == .dark ? "12171F" : "EEEFF7")
                    .ignoresSafeArea()
                    .animation(.default, value: colorScheme)
            }
        }
        .ignoresSafeArea(edges: .all)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AppBackground()
}
