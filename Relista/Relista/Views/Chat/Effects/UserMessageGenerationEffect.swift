//
//  UserMessageGenerationEffect.swift
//  Bisquid
//
//  Created by Nicolas Helbig on 07.06.26.
//

import SwiftUI

struct UserMessageGenerationEffect: View {
    let message: String
    let primaryColor: Color
    let secondaryColor: Color
    
    @State private var glowPulse: Bool = false
    @State private var t: Double = 0
    
    var body: some View {
        if secondaryColor != .clear{
            GeometryReader{ geo in
                TimelineView(.periodic(from: .now, by: 1.0 / 12.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let progress = (t * 0.05).truncatingRemainder(dividingBy: 1.0)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 40, style: .circular)
                            .fill(secondaryColor)
                            .padding(10)
                        
                        /*Path(roundedRect: CGRect(
                         origin: .init(x: geo.size.width / 10, y: geo.size.height / 10),
                         size: CGSize(width: geo.size.width * 0.8, height: geo.size.height * 0.8)),
                         cornerRadius: 40, style: .circular)
                         .stroke(.blue, lineWidth: 10)*/
                        
                        Ellipse()
                            .fill(secondaryColor)
                            .frame(width: geo.size.width / 2.5, height: geo.size.height / 2)
                            .position(pointOnRect(
                                t: progress,
                                rect: CGRect(
                                    origin: .init(x: geo.size.width / 10, y: geo.size.height / 10),
                                    size: CGSize(width: geo.size.width * 0.8, height: geo.size.height * 0.8)),
                                cornerRadius: 40))
                    }
                    .scaleEffect(glowPulse ? 1.1 : 0.9)
                    .opacity(glowPulse ? 0.8 : 0.5)
                    .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true),
                               value: glowPulse)
                    .onAppear { glowPulse = true }
                }
            }
            .padding(20)
            .drawingGroup()
            .blur(radius: 40)
            .opacity(0.7)
            .transition(.opacity.combined(with: .scale(scale: 0.5)))
        }
    }
    
    func pointOnRect(t: Double, rect: CGRect, cornerRadius: CGFloat) -> CGPoint {
        let w = rect.width - cornerRadius * 2
        let h = rect.height - cornerRadius * 2
        let arcLen = cornerRadius * .pi / 2
        let perimeter = 2 * (w + h) + 4 * arcLen
        let dist = t * perimeter
        
        // four straight edges + four corner arcs, walk them in order
        var remaining = dist
        
        // top edge (left to right)
        if remaining < w {
            return CGPoint(x: rect.minX + cornerRadius + remaining, y: rect.minY)
        }
        remaining -= w
        
        // top-right arc
        if remaining < arcLen {
            let angle = -(.pi / 2) + (remaining / arcLen) * (.pi / 2)
            return CGPoint(x: rect.maxX - cornerRadius + cos(angle) * cornerRadius,
                           y: rect.minY + cornerRadius + sin(angle) * cornerRadius)
        }
        remaining -= arcLen
        
        // right edge (top to bottom)
        if remaining < h {
            return CGPoint(x: rect.maxX, y: rect.minY + cornerRadius + remaining)
        }
        remaining -= h
        
        // bottom-right arc
        if remaining < arcLen {
            let angle = (remaining / arcLen) * (.pi / 2)
            return CGPoint(x: rect.maxX - cornerRadius + cos(angle) * cornerRadius,
                           y: rect.maxY - cornerRadius + sin(angle) * cornerRadius)
        }
        remaining -= arcLen
        
        // bottom edge (right to left)
        if remaining < w {
            return CGPoint(x: rect.maxX - cornerRadius - remaining, y: rect.maxY)
        }
        remaining -= w
        
        // bottom-left arc
        if remaining < arcLen {
            let angle = (.pi / 2) + (remaining / arcLen) * (.pi / 2)
            return CGPoint(x: rect.minX + cornerRadius + cos(angle) * cornerRadius,
                           y: rect.maxY - cornerRadius + sin(angle) * cornerRadius)
        }
        remaining -= arcLen
        
        // left edge (bottom to top)
        if remaining < h {
            return CGPoint(x: rect.minX, y: rect.maxY - cornerRadius - remaining)
        }
        remaining -= h
        
        // top-left arc
        let angle = .pi + (remaining / arcLen) * (.pi / 2)
        return CGPoint(x: rect.minX + cornerRadius + cos(angle) * cornerRadius,
                       y: rect.minY + cornerRadius + sin(angle) * cornerRadius)
    }
}

#Preview {
    @Previewable @State var isShowing = true
    VStack{
        Toggle("Show effect", isOn: $isShowing)
        Rectangle()
            .fill(.clear)
            .glassEffect(in: .rect(cornerRadius: 30, style: .continuous))
            .padding(50)
            .background{
                if isShowing{
                    UserMessageGenerationEffect(message: "I recently went to the construction site, it was actually quite cool, I saw a barefoot man eating a hot dog and it looked so good!", primaryColor: Color.red, secondaryColor: Color.blue)
                }
            }
            .animation(.default.speed(0.3), value: isShowing)
    }
    .padding(50)
}
