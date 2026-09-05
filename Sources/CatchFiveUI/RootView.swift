import SwiftUI

/// Owns the one `GameModel`. A new player sees login, then the tutorial as an intro they may skip, then the
/// table. A returning player lands on the table with a small welcome card over it.
public struct RootView: View {
    enum Screen { case login, intro, table }

    @StateObject private var model: GameModel
    @StateObject private var tutorial: TutorialModel
    @State private var screen: Screen
    /// The returning player's card; also reopened by the table's chevron.
    @State private var showWelcome: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: GameModel) {
        _model = StateObject(wrappedValue: model)
        _tutorial = StateObject(wrappedValue: model.makeTutorial())
        let first = Self.initialScreen(for: model.settings)
        _screen = State(initialValue: first)
        _showWelcome = State(initialValue: first == .table)
    }

    /// Login until a name is saved; after that the table, with the welcome card over it.
    static func initialScreen(for settings: Settings) -> Screen {
        settings.hasSignedIn ? .table : .login
    }

    public var body: some View {
        ZStack {
            LinearGradient(colors: [.felt, .black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            switch screen {
            case .login:
                LoginView(model: model) { startFirstMatch() }.transition(.opacity)
            case .intro:
                IntroView(model: model, tutorial: tutorial) { model.markRulesSeen(); show(.table) }.transition(.opacity)
            case .table:
                TableView(model: model, covered: showWelcome) { withAnimation(motion) { showWelcome = true } }
                    .transition(.opacity)
                    .overlay {
                        if showWelcome {
                            ZStack {
                                Color.black.opacity(0.55).ignoresSafeArea()
                                WelcomeCard(model: model) { withAnimation(motion) { showWelcome = false } }
                            }
                            .transition(.opacity)
                        }
                    }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var motion: Animation { reduceMotion ? Theme.Motion.reduced : Theme.Motion.overlay }

    /// A new player's only option is New match: any game left over from an earlier install is replaced,
    /// then the intro opens.
    private func startFirstMatch() {
        if model.match.actionCount > 0 || model.match.winner != nil { model.newGame() }
        showWelcome = false
        show(.intro)
    }

    private func show(_ next: Screen) {
        withAnimation(motion) { screen = next }
    }
}
