//
//  PanelItemBackground.swift
//  Bisquid
//
//  Created by Nicolas Helbig on 12.08.26.
//

import SwiftUI

struct PanelItemBackground: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.gray.opacity(0.4))
            .compatGlassEffect(in: RoundedRectangle(cornerRadius: 16.0, style: .continuous))
            .transition(
                hSizeClass == .compact
                ? .opacity
                : .opacity.combined(with: .scale(scale: 0.3)).combined(with: .offset(x: -100))
            )
    }
}

#Preview {
    PanelItemBackground()
}
