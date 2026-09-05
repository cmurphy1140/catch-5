/// Why the table may not let a computer act right now. Every input is UI state; none of it is an action,
/// so nothing here reaches the replay log. Stacked covers stay paused until the last one is gone.
struct TablePause: Equatable, Hashable {
    /// The scene is in the foreground and interactive.
    var sceneActive = true
    /// The returning player's welcome card is over the table.
    var welcomeShown = false
    /// Any sheet: settings, tutorial, review, scoreboard, statistics.
    var sheetShown = false
    /// A confirmation dialog or an alert is up.
    var dialogShown = false
    /// The player reopened the last trick to look at it.
    var inspectingTrick = false

    var isPaused: Bool { !sceneActive || welcomeShown || sheetShown || dialogShown || inspectingTrick }
}
