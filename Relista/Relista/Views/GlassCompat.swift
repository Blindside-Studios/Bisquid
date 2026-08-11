import SwiftUI

/// iOS/macOS 26 (Tahoe) API shims that fall back to pre-26 equivalents on older OS versions.
extension View {
    /// Liquid Glass, falling back to the bar material on older OS versions.
    @ViewBuilder
    func compatGlassEffect<S: Shape>(
        tint: Color? = nil,
        interactive: Bool = false,
        in shape: S
    ) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            let baseGlass = Glass.regular.tint(tint)
            let glass = interactive ? baseGlass.interactive() : baseGlass
            self.glassEffect(glass, in: shape)
        } else {
            self.background(.bar, in: shape)
        }
    }

    /// `safeAreaBar` (auto-glass safe area inset), falling back to plain `safeAreaInset` pre-26.
    @ViewBuilder
    func compatSafeAreaBar<V: View>(
        edge: VerticalEdge,
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: () -> V
    ) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.safeAreaBar(edge: edge, alignment: alignment, spacing: spacing, content: content)
        } else {
            self.safeAreaInset(edge: edge, alignment: alignment, spacing: spacing, content: content)
        }
    }
}

/// `Button(role: .cancel)` / `Button(role: .confirm)` (implicit system label, iOS/macOS 26) shims that
/// fall back to explicitly-titled buttons pre-26, since `ButtonRole.confirm` and the label-less
/// `Button(role:action:)` initializer don't exist before then.
@ViewBuilder
func compatCancelButton(action: @escaping () -> Void) -> some View {
    if #available(iOS 26.0, macOS 26.0, *) {
        Button(role: .cancel, action: action)
    } else {
        Button("Cancel", role: .cancel, action: action)
    }
}

@ViewBuilder
func compatConfirmButton(_ title: String = "Save", action: @escaping () -> Void) -> some View {
    if #available(iOS 26.0, macOS 26.0, *) {
        Button(role: .confirm, action: action)
    } else {
        Button(title, action: action)
    }
}
