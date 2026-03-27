//
//  ChatSplitView.swift
//  Relista
//
//  Created by Nicolas Helbig on 15.11.25.
//

import SwiftUI
import Combine

// MARK: Environment Key for Sidebar Selection

private struct SidebarSelectionActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var onSidebarSelection: (() -> Void)? {
        get { self[SidebarSelectionActionKey.self] }
        set { self[SidebarSelectionActionKey.self] = newValue }
    }
}

// MARK: Sidebar Gesture Coordination

@MainActor
class SidebarGestureCoordinator: ObservableObject {
    @Published var isBlocked: Bool = false
}

private struct SidebarGestureCoordinatorKey: EnvironmentKey {
    static let defaultValue: SidebarGestureCoordinator? = nil
}

extension EnvironmentValues {
    var sidebarGestureCoordinator: SidebarGestureCoordinator? {
        get { self[SidebarGestureCoordinatorKey.self] }
        set { self[SidebarGestureCoordinatorKey.self] = newValue }
    }
}

extension View {
    /// Blocks the sidebar swipe gesture while this view is being scrolled horizontally
    func blocksHorizontalSidebarGesture() -> some View {
        self.modifier(HorizontalScrollBlocker())
    }

    /// Manually block/unblock the sidebar gesture (useful for text selection)
    func blocksSidebarGesture(_ blocked: Bool) -> some View {
        self.modifier(ManualSidebarBlocker(blocked: blocked))
    }
}

private struct HorizontalScrollBlocker: ViewModifier {
    @Environment(\.sidebarGestureCoordinator) private var coordinator
    @GestureState private var isDragging: Bool = false

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 5)
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
            )
            .onChange(of: isDragging) { _, newValue in
                coordinator?.isBlocked = newValue
            }
    }
}

private struct ManualSidebarBlocker: ViewModifier {
    @Environment(\.sidebarGestureCoordinator) private var coordinator
    let blocked: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: blocked, initial: true) { _, newValue in
                coordinator?.isBlocked = newValue
            }
            .onDisappear {
                coordinator?.isBlocked = false
            }
    }
}

// MARK: Unified Control

struct UnifiedSplitView<Sidebar: View, Content: View>: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    
    @State private var isSidebarOpen: Bool = false
    
    let sidebar: Sidebar
    let content: Content
    
    init(@ViewBuilder sidebar: () -> Sidebar,
         @ViewBuilder content: () -> Content) {
        self.sidebar = sidebar()
        self.content = content()
    }
    
    var body: some View {
        NavigationStack{ // so the toolbar displays
            #if os(iOS)
            if hSizeClass == .compact {
                ChatSplitView(isOpen: $isSidebarOpen) {
                    sidebar
                        .environment(\.onSidebarSelection, {
                            withAnimation(.spring) {
                                isSidebarOpen = false
                            }
                        })
                } content: {
                    content
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    withAnimation(.spring) {
                                        isSidebarOpen.toggle()
                                    }
                                } label: {
                                    Image(systemName: "sidebar.left")
                                }
                            }
                        }
                        .navigationTitle("")
                }

            } else {
                
                NavigationSplitView {
                    sidebar
                } detail: {
                    content
                }
            }
            #else
            NavigationSplitView {
                sidebar
            } detail: {
                content
            }
            #endif
        }
        .onAppear(){
            if hSizeClass == .compact {
                   isSidebarOpen = false
            } else {
                isSidebarOpen = true
            }
        }
    }
}

// MARK: Sidebar Pan Gesture

#if os(iOS)
private struct SidebarPanGesture: UIGestureRecognizerRepresentable {
    @Binding var dragOffset: CGFloat
    @Binding var isGestureActive: Bool
    @Binding var isMaskActive: Bool
    let isOpen: Bool
    let drawerWidth: CGFloat
    let gestureCoordinator: SidebarGestureCoordinator
    let onEnded: (_ willOpen: Bool) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(gestureCoordinator: gestureCoordinator)
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.gestureCoordinator = gestureCoordinator
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began:
            isGestureActive = true
        case .changed:
            dragOffset = recognizer.translation(in: recognizer.view).x
            if dragOffset > 0 { isMaskActive = true }
        case .ended, .cancelled, .failed:
            let velocity = recognizer.velocity(in: recognizer.view)
            let predicted = (isOpen ? drawerWidth : 0) + dragOffset + velocity.x * 0.15
            onEnded(predicted > drawerWidth / 2)
            isGestureActive = false
        default:
            break
        }
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var gestureCoordinator: SidebarGestureCoordinator

        init(gestureCoordinator: SidebarGestureCoordinator) {
            self.gestureCoordinator = gestureCoordinator
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let v = view {
                if let tv = v as? UITextView, tv.isFirstResponder { return false }
                view = v.superview
            }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            return true
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard !gestureCoordinator.isBlocked,
                  let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  let view = pan.view else { return false }
            let velocity = pan.velocity(in: view)
            guard abs(velocity.x) > abs(velocity.y) * 2.5 else { return false }
            // Don't steal touches from a horizontal scroll view
            var hitView = view.hitTest(pan.location(in: view), with: nil)
            while let v = hitView {
                if let scroll = v as? UIScrollView, scroll.contentSize.width > scroll.frame.width {
                    return false
                }
                hitView = v.superview
            }
            return true
        }
    }
}
#endif

// MARK: Split View Control

struct ChatSplitView<Sidebar: View, Content: View>: View {
    let sidebar: Sidebar
    let content: Content

    @Binding var isOpen: Bool
    @State private var dragOffset: CGFloat = 0
    @State private var isGestureActive: Bool = false
    @State private var isMaskActive: Bool = false
    @StateObject private var gestureCoordinator = SidebarGestureCoordinator()

    #if os(iOS)
    private func sidebarSnapHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }
    #endif

    init(isOpen: Binding<Bool>,
         @ViewBuilder sidebar: () -> Sidebar,
         @ViewBuilder content: () -> Content) {
        self._isOpen = isOpen
        self.sidebar = sidebar()
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let drawerWidth = width * 0.75
            let baseOffset: CGFloat = isOpen ? drawerWidth : 0
            let currentOffset = min(max(baseOffset + dragOffset, 0), drawerWidth)

            ZStack(alignment: .leading) {
                // SIDEBAR
                sidebar
                    .frame(width: drawerWidth)
                    .scrollDisabled(isGestureActive)
                    .offset(x: currentOffset / 10 - drawerWidth / 10)
                    .scaleEffect(0.95 + ((currentOffset / drawerWidth) * 0.05))
                    .background{
                        AppBackground()
                            .opacity(0.5)
                            .ignoresSafeArea()
                            .padding(.trailing, -56)
                    }
                    .opacity(0.5 + ((currentOffset / drawerWidth) * 0.5))
                
                // MAIN CONTENT
                content
                    .environment(\.sidebarGestureCoordinator, gestureCoordinator)
                    .scrollDisabled(isGestureActive)
                    .contentShape(Rectangle())
                    .background{
                        Color.gray.opacity((currentOffset / drawerWidth) * 0.25)
                    }
                    .mask{
                        UnevenRoundedRectangle(
                            cornerRadii: RectangleCornerRadii(
                                topLeading: isMaskActive ? 56 : 0,
                                bottomLeading: isMaskActive ? 56 : 0,
                                bottomTrailing: 0,
                                topTrailing: 0
                            ),
                            style: .continuous
                        )
                        .ignoresSafeArea()
                    }
                    .overlay{
                        if isMaskActive {
                            Color.clear
                                .ignoresSafeArea()
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring) {
                                        isOpen = false
                                    }
                                }
                        }
                    }
                    .offset(x: currentOffset)
            }
            #if os(iOS)
            .gesture(
                SidebarPanGesture(
                    dragOffset: $dragOffset,
                    isGestureActive: $isGestureActive,
                    isMaskActive: $isMaskActive,
                    isOpen: isOpen,
                    drawerWidth: drawerWidth,
                    gestureCoordinator: gestureCoordinator,
                    onEnded: { willOpen in
                        withAnimation(.spring(response: 0.3)) {
                            if willOpen != isOpen { sidebarSnapHaptic() }
                            isOpen = willOpen
                            dragOffset = 0
                        } completion: {
                            if !isOpen { isMaskActive = false }
                        }
                    }
                )
            )
            #else
            .simultaneousGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .onChanged { value in
                        if gestureCoordinator.isBlocked { dragOffset = 0; isGestureActive = false; return }
                        if !isGestureActive {
                            let t = value.translation
                            guard abs(t.width) > abs(t.height) * 2.5 else { return }
                            isGestureActive = true
                        }
                        guard isGestureActive else { return }
                        dragOffset = value.translation.width
                        if dragOffset > 0 { isMaskActive = true }
                    }
                    .onEnded { value in
                        guard isGestureActive else { dragOffset = 0; isGestureActive = false; return }
                        let predicted = (isOpen ? drawerWidth : 0) + value.predictedEndTranslation.width
                        let willOpen = predicted > drawerWidth / 2
                        withAnimation(.spring(response: 0.3)) {
                            isOpen = willOpen
                            dragOffset = 0
                        } completion: {
                            if !isOpen { isMaskActive = false }
                        }
                        isGestureActive = false
                    }
            )
            #endif
            .onChange(of: isOpen) { oldValue, newValue in
                if newValue {
                    isMaskActive = true
                    // Dismiss keyboard when opening sidebar
                    #if os(iOS)
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    #endif
                } else {
                    // Delay deactivating the mask until the closing animation settles
                    Task {
                        try? await Task.sleep(for: .milliseconds(600))
                        if !isOpen { isMaskActive = false }
                    }
                }
            }
        }
    }
}

#Preview {
    //ChatSplitView()
}
