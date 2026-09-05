import SwiftUI

/// Owns the one `GameModel` and shows login until a name is saved, then the menu, then the table.
public struct RootView: View {
    enum Screen { case login, menu, table }

    @StateObject private var model: GameModel
    @State private var screen: Screen
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: GameModel) {
        _model = StateObject(wrappedValue: model)
        _screen = State(initialValue: model.settings.hasSignedIn ? .menu : .login)
    }

    public var body: some View {
        ZStack {
            LinearGradient(colors: [.felt, .black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            switch screen {
            case .login:
                LoginView(model: model) { show(.menu) }.transition(.opacity)
            case .menu:
                MainMenuView(model: model) { show(.table) }.transition(.opacity)
            case .table:
                TableView(model: model) { show(.menu) }.transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func show(_ next: Screen) {
        withAnimation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.overlay) { screen = next }
    }
}
