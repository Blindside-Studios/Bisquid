//
//  PencilKitInputField.swift
//  Bisquid
//
//  Created by Nicolas Helbig on 13.06.26.
//

#if os(iOS)
import SwiftUI
import PencilKit

struct PencilKitInputField: View {
    @Binding var canvasView: PKCanvasView
    @Binding var userPenSelection: String
    
    var body: some View {
        HStack{
            GeometryReader { geo in
                PKCanvasRepresentable(canvasView: $canvasView)
                    .onChange(of: geo.size.width) { oldWidth, newWidth in
                        handleWidthChange(oldWidth: oldWidth, newWidth: newWidth)
                    }
            }
            .onChange(of: userPenSelection) { _, newValue in
                switch newValue {
                case "eraser":
                    canvasView.tool = PKEraserTool(.vector)
                case "selection":
                    canvasView.tool = PKLassoTool()
                default:
                    canvasView.tool = PKInkingTool(.pen)
                }
            }
        }
            
        
        /*Button("Send") {
            let image = canvasView.drawing.image(
                from: canvasView.bounds,
                scale: UIScreen.main.scale
            )
            
        }*/
    }
    
    func handleWidthChange(oldWidth: CGFloat, newWidth: CGFloat) {
        guard oldWidth > 0, newWidth > 0, oldWidth != newWidth else { return }
        let scale = newWidth / oldWidth
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        canvasView.drawing = canvasView.drawing.transformed(using: transform)
    }
}
#endif
