import CatchFive
import SwiftUI

struct PracticeSetupView: View {
    let names: [String]
    @State private var configuration: PracticeConfiguration
    let replayDescription: String?
    let onStart: (PracticeConfiguration) -> Void
    let onClose: () -> Void

    init(names: [String], configuration: PracticeConfiguration, replayDescription: String?,
         onStart: @escaping (PracticeConfiguration) -> Void, onClose: @escaping () -> Void) {
        self.names = names
        _configuration = State(initialValue: configuration)
        self.replayDescription = replayDescription
        self.onStart = onStart
        self.onClose = onClose
    }

    @Environment(\.dynamicTypeSize) private var typeSize

    /// The mock's page (D181): the cloth band, the promise beside a card off the deck, the three hands as rows to
    /// tap, and each seat's name and place beside its own switch.
    var body: some View {
        ClothPage(title: "Practice", onDone: onClose) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Try a hand, keep the family score.")
                        .font(.system(.title, design: .serif).weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Practice starts at zero. Your real game, saved hands and statistics stay as they are.")
                }
                .fixedSize(horizontal: false, vertical: true)
                if !typeSize.isAccessibilitySize { PracticeDeckArt().padding(.trailing, 6) }
            }
            if let replayDescription {
                VStack(alignment: .leading, spacing: 6) {
                    heading("Original deal")
                    Text(replayDescription)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    heading("Your starting hand")
                    ForEach(PracticeDeal.allCases) { deal in
                        dealRow(deal)
                        if deal != PracticeDeal.allCases.last { PageRule(weight: 1).opacity(0.6) }
                    }
                }
            }
            PageRule()
            VStack(alignment: .leading, spacing: 8) {
                heading("The other seats")
                seatRow(seat: 1, role: "Left opponent", selection: $configuration.left)
                PageRule(weight: 1).opacity(0.6)
                seatRow(seat: 2, role: "Your partner", selection: $configuration.partner)
                PageRule(weight: 1).opacity(0.6)
                seatRow(seat: 3, role: "Right opponent", selection: $configuration.right)
            }
            Button { onStart(configuration) } label: {
                HStack(spacing: 10) {
                    Text("Start practice")
                    Image(systemName: "arrow.right").accessibilityHidden(true)
                }
            }
            .buttonStyle(PaperButtonStyle())
        }
    }

    private func heading(_ title: String) -> some View {
        Text(title).font(.system(.title2, design: .serif).weight(.bold)).accessibilityAddTraits(.isHeader)
    }

    /// One starting hand: a tick when it is the one, its name, and what it gives you.
    private func dealRow(_ deal: PracticeDeal) -> some View {
        let chosen = configuration.deal == deal
        return Button { configuration.deal = deal } label: {
            HStack(spacing: 12) {
                Image(systemName: "checkmark").font(.body.weight(.bold)).foregroundStyle(Theme.Paper.green)
                    .opacity(chosen ? 1 : 0).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(deal.title).font(.system(.title3, design: .serif).weight(chosen ? .bold : .medium))
                    Text(deal.detail).font(.subheadline).foregroundStyle(Theme.Paper.ink.opacity(0.75))
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 52).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    private func seatRow(seat: Int, role: String, selection: Binding<Difficulty>) -> some View {
        let name = VStack(alignment: .leading, spacing: 0) {
            Text(names.indices.contains(seat) ? names[seat] : "Seat \(seat + 1)")
                .font(.system(.title3, design: .serif).weight(.bold))
            Text(role).font(.subheadline).foregroundStyle(Theme.Paper.ink.opacity(0.75))
        }
        let choice = PaperSwitch(options: [("Easy", Difficulty.easy), ("Standard", Difficulty.standard)],
                                 selection: selection, ticks: true)
            .accessibilityLabel("\(role) difficulty")
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                name
                Spacer(minLength: 0)
                choice.frame(width: 200)
            }
            VStack(alignment: .leading, spacing: 8) { name; choice }
        }
    }
}

/// The five of hearts coming off the deck, from the app's own cards, where the mock has a painted hand.
struct PracticeDeckArt: View {
    var body: some View {
        let width = 58.0
        ZStack(alignment: .bottom) {
            ForEach(0..<4, id: \.self) { layer in CardBackView(width: width + 6).offset(y: Double(-layer) * 2.5) }
            CardFace(card: Card(.hearts, .five), width: width)
                .frame(width: width, height: width * Theme.Card.ratio)
                .background(CardFace.paper, in: RoundedRectangle(cornerRadius: Theme.Card.radius(width: width), style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Card.radius(width: width), style: .continuous)
                    .stroke(.black.opacity(0.18), lineWidth: 0.75))
                .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                .rotationEffect(.degrees(-11), anchor: .bottom)
                .offset(x: 8, y: -30)
        }
        .padding(.top, 34)
        .dynamicTypeSize(.large)
        .accessibilityHidden(true)
    }
}

struct PracticeTableView: View {
    @ObservedObject var model: GameModel
    let onNewDeal: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Text("Practice").font(.system(.headline, design: .serif))
                    Spacer(minLength: 0)
                    controls
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("Practice").font(.system(.headline, design: .serif))
                    HStack { controls }
                }
            }
            .padding(.horizontal, 12)
            .foregroundStyle(.ivory)
            .background(Theme.Wood.header)
            if model.isPractice {
                TableView(model: model, onLeave: onClose, onHome: onClose)
                    .id(ObjectIdentifier(model))
            } else {
                Text("Practice could not be opened. Your real game is safe.")
                    .padding().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(.ivory).background(Theme.Wood.header)
            }
        }
        #if os(iOS)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    private var controls: some View {
        Group {
            Button("New deal", action: onNewDeal).accessibilityLabel("New practice deal")
                .frame(minHeight: 44)
            Button("Leave practice", action: onClose).frame(minHeight: 44)
        }
        .buttonStyle(.plain).font(.subheadline.weight(.semibold))
    }
}
