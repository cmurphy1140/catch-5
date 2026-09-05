import SwiftUI
import CatchFiveUI

@main
struct CatchFiveApp: App {
    var body: some Scene {
        WindowGroup { RootView(model: GameModel.loadDefault()) }
    }
}
