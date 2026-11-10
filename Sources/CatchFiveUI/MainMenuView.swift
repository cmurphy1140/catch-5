import CatchFive
import SwiftUI

/// The main menu (spec R31): who is playing, where the saved match stands, and every destination that is
/// not the table itself. Back to the table leads back to the match untouched; New game starts a new one,
/// after a word of warning if it would replace one (D67); How to play opens the lessons. Settings, Statistics and the build explainer wait in a
/// hamburger menu in the top-right corner, one tap from here in every mode (spec R29), as a bare glyph
/// with no plate (spec R19).
struct MainMenuView: View {
    @ObservedObject var model: GameModel
    @ObservedObject var tutorial: TutorialModel
    /// Back to the table or a fresh deal: the tip card, then the table.
    let onPlay: () -> Void
    /// Opens with the Solo or Pass and play question already up (the screenshot launch stage).
    var choosingMode = false
    /// The player has been reset (D108): on to setting up a new one.
    var onNewPlayer: () -> Void = {}
    @State private var confirmNewMatch = false
    @State private var showSettings = false
    @State private var showTutorial = false
    @State private var showStatistics = false
    @State private var showExplainer = false
    @State private var support: SupportPresentation?

    /// The guest's scene for the opening page, when the build carries one (D127); kept out of the repository.
    private var guestScene: Image? {
        #if canImport(UIKit)
        UIImage(named: "GuestScene") != nil ? Image("GuestScene") : nil
        #else
        nil
        #endif
    }

    /// The one main action, as a compact green capsule (D121); on the wood beside the guest's scene it is bare words and
    /// an arrow, with no capsule round them (D127).
    private func mainCapsule(_ button: HomeButton, bare: Bool = false) -> some View {
        Button { perform(button.action) } label: {
            HStack(spacing: 8) {
                Text(button.title).multilineTextAlignment(.leading)
                Image(systemName: "arrow.right").accessibilityHidden(true)
            }
            .font(.system(.headline, design: .serif).weight(.bold)).foregroundStyle(.ivory)
            .padding(.horizontal, 14).frame(minHeight: 52)
            .background {
                if !bare {
                    Capsule().fill(LinearGradient(colors: [Theme.Paper.green, Theme.Paper.greenDeep], startPoint: .top, endPoint: .bottom))
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                }
            }
            .shadow(color: .black.opacity(bare ? 0.5 : 0), radius: 1.5, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Opens the helper from the opening page (D120). No game goes along: out here it is company, not a coach.
    private func openSupport() {
        guard let context = SupportContext.visible(in: model) ?? (try? SupportContext(match: model.match, seat: 0)) else { return }
        let presentation = SupportPresentation(context: context)
        presentation.front = true
        presentation.sendsContext = false
        presentation.name = model.settings.playerName
        support = presentation
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                VStack(spacing: 6) {
                    Text("Catch 5")
                        .font(.system(size: 48, weight: .bold, design: .serif))
                    Text("A FAMILY CARD GAME")
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .tracking(2)
                        .opacity(0.82)
                    // A thin, slightly wavy bookmark under the title, running off the left edge (D126); a guest may sit on it.
                    WavyRibbon()
                        .stroke(LinearGradient(colors: [Theme.Paper.greenDeep, Theme.Paper.green], startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 6, lineCap: .butt))
                        .frame(height: 10)
                        .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1.5)
                        .padding(.leading, -40).padding(.trailing, 64).padding(.top, 6)
                        .accessibilityHidden(true)
                }
                .padding(.top, 0)

                // The five is the visual signature of the game, not another control. Two hands reach for it (N47).
                HomeFiveCard()
                    .rotationEffect(.degrees(-5))
                    .padding(.vertical, HomeFiveCard.handRoom)
                    .accessibilityHidden(true)

                // The helper, up front (D120), standing alone on the wood as frosted glass (D123).
                Button(action: openSupport) {
                    HStack(spacing: 10) {
                        Text("Ask anything").opacity(0.85)
                        Spacer(minLength: 0)
                        // A bare arrow: no circle round it (Connor: "the less ui containers the better").
                        Image(systemName: "arrow.up").fontWeight(.semibold).accessibilityHidden(true)
                    }
                    .font(.title3)
                    .padding(.horizontal, 20).frame(minHeight: 50)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.28), lineWidth: 1))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ask anything")
                .accessibilityHint("Opens a chat with the game's helper")

                // Who is playing and where the saved match stands, on the ivory paper of the hand's result (D107), with the
                // one main action inside it; the quieter ones sit under it, side by side.
                let buttons = Self.homeButtons(matchInProgress: model.matchInProgress)
                if let scene = guestScene {
                    // A build that carries the guest's scene (D127): she comes out of the bottom-left corner, the scores are
                    // a note pinned at the right, and there is no card round any of it.
                    HStack(alignment: .bottom, spacing: 8) {
                        scene.resizable().scaledToFit().frame(height: 200)
                            .padding(.leading, -24).padding(.bottom, -20)
                            .accessibilityHidden(true)
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 16) {
                            if model.matchInProgress {
                                ScratchPad(hand: model.match.handNumber,
                                           lines: [(model.mode == .solo ? "Us" : model.teamNames(0), model.match.scores[0]),
                                                   (model.mode == .solo ? "Them" : model.teamNames(1), model.match.scores[1])],
                                           note: true)
                            }
                            ForEach(buttons.filter(\.prominent), id: \.title) { mainCapsule($0, bare: true) }
                        }
                        .padding(.bottom, 8)
                    }
                    .zIndex(-1)
                } else {
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        PortraitView(portrait: model.settings.playerPortrait, size: 64, cutOut: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.settings.playerName ?? "friend")
                                .font(.system(.title, design: .serif).weight(.bold)).lineLimit(1).minimumScaleFactor(0.6)
                            Text(model.settings.difficulty == .easy ? "Easy opponents" : "Standard opponents")
                                .font(.subheadline).opacity(0.7)
                        }
                        Spacer(minLength: 0)
                    }
                    let main = buttons.filter(\.prominent)
                    if model.matchInProgress {
                        // The saved game as a scratchpad on the left, and the way back to it, smaller, on the right (D121).
                        HStack(alignment: .center, spacing: 14) {
                            ScratchPad(hand: model.match.handNumber,
                                       lines: [(model.mode == .solo ? "Us" : model.teamNames(0), model.match.scores[0]),
                                               (model.mode == .solo ? "Them" : model.teamNames(1), model.match.scores[1])])
                            Spacer(minLength: 0)
                            ForEach(main, id: \.title) { mainCapsule($0) }
                        }
                    } else {
                        ForEach(main, id: \.title) { button in
                            Button { perform(button.action) } label: {
                                HStack(spacing: 12) {
                                    Text(button.title)
                                    Image(systemName: "arrow.right").accessibilityHidden(true)
                                }
                            }
                            .buttonStyle(PaperButtonStyle())
                        }
                    }
                }
                .padding(16)
                .foregroundStyle(Theme.Paper.ink)
                .paperCard()
                // The card is the open page of a book (D125): cover and page edges under it, a green ribbon out the bottom.
                .background { BookUnderPage() }
                .padding(.bottom, BookUnderPage.ribbonDrop)
                }

                HStack(spacing: 10) {
                    // New game always asks Solo or Pass and play; the same question warns when a match is in progress.
                    ForEach(buttons.filter { !$0.prominent }, id: \.title) { button in
                        Button { perform(button.action) } label: { Label(button.title, systemImage: "plus.square") }
                    }
                    Button { showTutorial = true } label: { Label("How to play", systemImage: "book") }
                }
                .buttonStyle(PaperSecondaryButtonStyle())
            }
            .padding(24).frame(maxWidth: 480).frame(maxWidth: .infinity)
        }
        .overlay(alignment: .topTrailing) {
            Menu {
                Button("Settings", systemImage: "gearshape") { showSettings = true }
                Button("Statistics", systemImage: "chart.bar") { showStatistics = true }
                Button("How Catch 5 is built", systemImage: "doc.text.magnifyingglass") { showExplainer = true }
            } label: {
                Image(systemName: "line.3.horizontal").font(.system(size: 33, weight: .medium))
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                    .frame(width: Theme.Table.statusButtonHitSize, height: Theme.Table.statusButtonHitSize)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .tint(.ivory)
            .accessibilityLabel("Menu")
            .padding(.trailing, 12).padding(.top, 4)
        }
        .foregroundStyle(.ivory)
        .background(WoodGrainView().ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: $model.settings, onNewPlayer: {
                showSettings = false
                model.resetPlayer()
                onNewPlayer()
            })
        }
        .sheet(isPresented: $showTutorial, onDismiss: { model.markRulesSeen() }) { TutorialView(model: tutorial) { showTutorial = false } }
        .sheet(item: $support) { SupportView(presentation: $0).id($0.id) }
        .sheet(isPresented: $showStatistics) { StatisticsView(stats: model.statistics, records: model.records) { showStatistics = false } }
        .fullScreenCoverOrSheet(isPresented: $showExplainer) { ExplainerView { showExplainer = false } }
        // The question on the game's own paper (D114, over the system alert of D57): each choice says what it is, and
        // Cancel is always there.
        .overlay {
            if confirmNewMatch {
                NewMatchCard(replacesSavedGame: model.matchInProgress,
                             onChoose: { mode in confirmNewMatch = false; model.newGame(mode: mode); onPlay() },
                             onCancel: { confirmNewMatch = false })
                    .transition(.opacity)
            }
        }
        .animation(Theme.Motion.overlay, value: confirmNewMatch)
        .onAppear {
            if choosingMode { confirmNewMatch = true }
            switch ScreenshotStage.name {
            case "stats": showStatistics = true
            case "settings": showSettings = true
            case "howto", "rules", "signoff": showTutorial = true
            default: break
            }
        }
    }
}


extension MainMenuView {
    private func perform(_ action: HomeButton.Action) {
        if action == .backToTable { onPlay() } else { confirmNewMatch = true }
    }

    /// One team's score on the player card.
    struct HomeButton: Equatable {
        enum Action { case backToTable, newGame }
        let title: String
        let prominent: Bool
        let action: Action
    }

    /// The home screen's play buttons (D67): with a match in progress, Back to the table in the prominent style
    /// and New game plain; otherwise New game alone, prominent (D93). New game keeps New match's alert and mode picker.
    nonisolated static func homeButtons(matchInProgress: Bool) -> [HomeButton] {
        matchInProgress
            ? [HomeButton(title: "Back to the table", prominent: true, action: .backToTable),
               HomeButton(title: "New game", prominent: false, action: .newGame)]
            : [HomeButton(title: "New game", prominent: true, action: .newGame)]
    }
}

/// The home-screen signature card: a real five-of-hearts pip layout, larger than gameplay cards. It sways
/// slowly and turns over to its back about every nine seconds (D67); under Reduce Motion it holds still.
/// Two hands reach for it, one from above and one from below, drifting in and back with the sway (N47).
private struct HomeFiveCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var swayed = false
    @State private var angle = 0.0
    @State private var showsBack = false

    /// Room above and below the card for the reaching hands.
    static let handRoom = 44.0

    var body: some View {
        Group {
            if showsBack { CardBackView(width: 112).frame(width: 112, height: 168) } else { face }
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .rotationEffect(.degrees(swayed ? 2 : -2))
        .offset(y: swayed ? -4 : 0)
        // From above, reaching down for the top-right corner; from below, reaching up for the bottom-left.
        .overlay {
            ReachingHand(skin: .tan, sleeve: Theme.Portrait.color(.olive))
                .rotationEffect(.degrees(225))
                .offset(x: 66 - reach, y: -98 + reach)
            ReachingHand(skin: .brown, sleeve: Theme.Wood.dark)
                .rotationEffect(.degrees(45))
                .offset(x: -66 + reach, y: 98 - reach)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { swayed = true }
        }
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(9))
                guard !Task.isCancelled else { return }
                await turn()
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                await turn()
            }
        }
    }

    /// Turns the card over about its vertical axis, swapping face and back edge-on.
    private func turn() async {
        withAnimation(.easeIn(duration: 0.3)) { angle = 90 }
        try? await Task.sleep(for: .milliseconds(300))
        showsBack.toggle()
        angle = -90
        withAnimation(.easeOut(duration: 0.3)) { angle = 0 }
    }

    private var face: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ivory)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.black.opacity(0.18)))
                .shadow(color: .black.opacity(0.35), radius: 5, y: 4)
            VStack {
                HStack { heart; Spacer(); heart }
                Spacer()
                heart
                Spacer()
                HStack { heart; Spacer(); heart }
            }
            .padding(.horizontal, 23).padding(.vertical, 24)
            VStack(spacing: -4) {
                Text("5").font(.system(size: 27, weight: .bold, design: .serif))
                Text("♥").font(.system(size: 20))
            }
            .foregroundStyle(Color.suitRed)
            .padding(.top, 8).padding(.leading, 9)
        }
        .frame(width: 112, height: 168)
    }
    private var heart: some View {
        Text("♥").font(.system(size: 27)).foregroundStyle(Color.suitRed)
    }

    /// How far each hand has drifted toward the card, along its diagonal, with the sway.
    private var reach: Double { swayed ? 5 : 0 }
}

/// A flat, drawn hand reaching up, fingers first, from a sleeve with a cuff: the cast's skin palette and shapes
/// (`PortraitView`), decoration only.
private struct ReachingHand: View {
    let skin: Portrait.Skin
    let sleeve: Color
    var width = 46.0

    var body: some View {
        let skinColor = Theme.Portrait.color(skin)
        let finger = width * 0.17
        ZStack(alignment: .bottom) {
            // Four fingers, the middle two longest, standing on the palm.
            HStack(alignment: .bottom, spacing: width * 0.02) {
                ForEach([0.30, 0.36, 0.34, 0.27], id: \.self) { length in
                    Capsule().fill(skinColor).frame(width: finger, height: width * length * 1.8)
                }
            }
            .offset(y: -width * 0.95)
            RoundedRectangle(cornerRadius: width * 0.2, style: .continuous).fill(skinColor)
                .frame(width: width * 0.76, height: width * 0.62)
                .offset(y: -width * 0.5)
            Capsule().fill(skinColor).frame(width: finger, height: width * 0.46)
                .rotationEffect(.degrees(-38))
                .offset(x: -width * 0.4, y: -width * 0.72)
            // The sleeve and its cuff.
            RoundedRectangle(cornerRadius: width * 0.1, style: .continuous).fill(sleeve)
                .frame(width: width * 0.94, height: width * 0.46)
            Rectangle().fill(.ivory).frame(width: width * 0.94, height: width * 0.1)
                .offset(y: -width * 0.4)
        }
        .frame(width: width, height: width * 1.9, alignment: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Solo or Pass and play, asked on ivory paper over the dimmed menu (D114): ink on tan tiles with a gold rule, each
/// choice with a line saying what it is, a warning in oxblood when a saved game would be replaced, and Cancel.
struct NewMatchCard: View {
    let replacesSavedGame: Bool
    let onChoose: (PlayMode) -> Void
    let onCancel: () -> Void

    nonisolated static func title(replacesSavedGame: Bool) -> String { replacesSavedGame ? "Start over?" : "New match" }
    nonisolated static let warning = "This replaces your saved game."

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: onCancel).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 12) {
                Text(Self.title(replacesSavedGame: replacesSavedGame))
                    .font(.system(.largeTitle, design: .serif).weight(.bold)).accessibilityAddTraits(.isHeader)
                if replacesSavedGame {
                    Label(Self.warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.body.weight(.semibold)).foregroundStyle(Theme.Team.theirRim)
                }
                Rectangle().fill(Theme.Paper.rule).frame(height: 1.5).accessibilityHidden(true)
                choice("Solo", "You and three computer players", symbol: "person.fill", mode: .solo)
                choice("Pass and play", "Four players share this phone", symbol: "person.3.fill", mode: .passAndPlay)
                Button(action: onCancel) {
                    Text("Cancel").font(.system(.title3, design: .serif).weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .foregroundStyle(Theme.Paper.ink)
            .paperCard()
            .environment(\.colorScheme, .light)
            .padding(.horizontal, 24)
            .frame(maxWidth: 460)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }

    private func choice(_ title: String, _ detail: String, symbol: String, mode: PlayMode) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Button { onChoose(mode) } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.title2).frame(width: 40).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(.title2, design: .serif).weight(.bold))
                    Text(detail).font(.subheadline).opacity(0.75).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.body.weight(.bold)).opacity(0.5).accessibilityHidden(true)
            }
            .padding(.horizontal, 14).frame(minHeight: 72)
            .background(shape.fill(Theme.Paper.tan))
            .overlay(shape.stroke(Theme.Paper.rule, lineWidth: 1.5))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }
}

/// The saved game on the menu (D121, D124): the hand's number and the two scores, handwritten straight onto the paper
/// card on faint rules, a little crooked, with no pad of its own.
private struct ScratchPad: View {
    let hand: Int
    let lines: [(name: String, score: Int)]
    /// On the wood, with no card under it, the scores are a small paper note pinned a little crooked (D127).
    var note = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row { Text("Hand \(hand)").underline() }
            ForEach(lines, id: \.name) { entry in
                row {
                    Text(entry.name).lineLimit(1).minimumScaleFactor(0.5)
                    Spacer(minLength: 6)
                    Text(entry.score, format: .number).font(.custom("Noteworthy-Bold", size: 24, relativeTo: .title3)).monospacedDigit()
                }
            }
        }
        .font(.custom("Noteworthy-Bold", size: 17, relativeTo: .body))
        .foregroundStyle(Theme.Paper.ink)
        .frame(width: 132)
        .padding(note ? 8 : 0)
        .background { if note { Rectangle().fill(Theme.Paper.tan).shadow(color: .black.opacity(0.35), radius: 3, x: 1, y: 3) } }
        .rotationEffect(.degrees(note ? 3 : -3))
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hand \(hand). " + lines.map { "\($0.name) \($0.score)" }.joined(separator: ", "))
    }

    /// One ruled line.
    private func row(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) { content() }
            .padding(.horizontal, 6).frame(height: 30)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.Paper.rule.opacity(0.6)).frame(height: 1) }
    }
}

/// What lies under the menu's paper card to make it a book (D125): a burgundy cover showing at the left as the spine and
/// along the bottom and right, the edges of the pages between, and a green ribbon bookmark hanging out below.
private struct BookUnderPage: View {
    /// How far the ribbon hangs below the page; the menu leaves this much room under the card.
    static let ribbonDrop = 30.0
    private static let cover = Color(red: 0.36, green: 0.11, blue: 0.13)

    var body: some View {
        let radius = Theme.Paper.cardRadius
        ZStack {
            Ribbon().fill(LinearGradient(colors: [Theme.Paper.green, Theme.Paper.greenDeep], startPoint: .top, endPoint: .bottom))
                .frame(width: 20, height: 60)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 44).offset(y: 8 + Self.ribbonDrop)
            RoundedRectangle(cornerRadius: radius + 3, style: .continuous).fill(Self.cover)
                .overlay(RoundedRectangle(cornerRadius: radius + 3, style: .continuous).strokeBorder(Theme.Paper.rule.opacity(0.7), lineWidth: 1))
                .padding(.leading, -7).padding(.top, -2).padding(.trailing, -6).padding(.bottom, -10)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 5)
            // Page edges: two more sheets a step down and to the right.
            ForEach([2.0, 1.0], id: \.self) { step in
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.Paper.tan)
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.Paper.rule.opacity(0.8), lineWidth: 0.75))
                    .offset(x: step * 1.5, y: step * 3)
            }
        }
        .accessibilityHidden(true)
    }

    /// A ribbon with a swallowtail end.
    private struct Ribbon: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.width * 0.45))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}

/// A gentle wave across its frame: stroked, it is a thin ribbon lying a little loose on the wood (D126).
private struct WavyRibbon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let waves = 2.5
        for step in 0...60 {
            let t = Double(step) / 60
            let point = CGPoint(x: rect.minX + rect.width * t, y: rect.midY + sin(t * waves * 2 * .pi) * rect.height * 0.3)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}
