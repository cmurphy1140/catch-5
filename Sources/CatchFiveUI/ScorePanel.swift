import CatchFive
import SwiftUI

/// The full score sheet, opened from the scorecard (N66), on the same ivory paper as the hand's result: the race to
/// 25 as two tracks, each team's marker at its total, then the hands so far, paging sideways, newest first, so
/// nothing scrolls down. Back to game, the cross, a tap outside it or a swipe up or down closes it.
struct ScorePanel: View {
    /// One finished hand, from one team's side.
    struct HandCard: Equatable {
        let number: Int
        /// "Cheryl bid 5, made".
        let line: String
        /// What the hand did to this team's score.
        let change: Int
        /// This team's score after the hand.
        let total: Int
        /// This team held the bid.
        let ourBid: Bool
    }

    struct Content: Equatable {
        let total: Int
        /// How many of the 25 dots are filled.
        let dots: Int
        let hands: [HandCard]
    }

    /// The dots a score fills: none below zero, all 25 from 25 up.
    nonisolated static func dots(_ score: Int) -> Int { min(HouseRules.matchTarget, max(0, score)) }

    /// `team`'s side of the sheet from the match's finished hands.
    nonisolated static func content(team: Int, history: [HandSummary], seatNames: [String]) -> Content {
        var before = 0
        let hands = history.map { hand in
            defer { before = hand.scores[team] }
            let bid = hand.isNineAndOut ? "9 and out" : String(hand.bid)
            return HandCard(number: hand.number, line: "\(seatNames[hand.bidder]) bid \(bid), \(hand.contractMade ? "made" : "set")",
                            change: hand.scores[team] - before, total: hand.scores[team], ourBid: hand.bidder % 2 == team)
        }
        let total = history.last?.scores[team] ?? 0
        return Content(total: total, dots: dots(total), hands: hands)
    }

    /// The phone holder's team and the other team.
    let us: Content
    let them: Content
    /// US and THEM in solo, the pairs' names in pass and play (`Scorecard.label(us:mode:teamNames:)`).
    let usLabel: String
    let themLabel: String
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.45).ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)
                .gesture(DragGesture(minimumDistance: 20).onEnded { _ in onClose() })
                .accessibilityHidden(true)
            panel
                .padding(.horizontal, 12).padding(.bottom, 8)
                // A swipe up or down on the panel closes it; sideways belongs to the hands.
                .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { drag in
                    if abs(drag.translation.height) > abs(drag.translation.width) { onClose() }
                })
        }
        .dynamicTypeSize(...Theme.Card.maximumTypeSize)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onClose)
    }

    private var panel: some View {
        VStack(spacing: 12) {
            RuledLine {
                Text("The race to \(HouseRules.matchTarget)").font(.system(.title, design: .serif).weight(.bold).italic())
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            // The rules stop short of the cross.
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.body.weight(.semibold)).frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(Theme.Paper.green)
                .accessibilityLabel("Close")
            }
            side(label: usLabel, content: us, color: Theme.Paper.green)
            Divider().overlay(Theme.Paper.ink.opacity(0.2))
            side(label: themLabel, content: them, color: Theme.Team.theirRim)
            RuledLine {
                Text(us.hands.count > 1 ? "HANDS SO FAR" : "LATEST HAND")
                    .font(.system(.footnote, design: .serif).weight(.bold)).tracking(3).foregroundStyle(Theme.Paper.green)
            }
            hands
            Button(action: onClose) {
                HStack(spacing: 12) {
                    Text("Back to game")
                    Image(systemName: "arrow.right").accessibilityHidden(true)
                }
            }
            .buttonStyle(PaperButtonStyle())
        }
        .foregroundStyle(Theme.Paper.ink)
        .padding(16)
        .paperCard()
    }

    /// One team: its label and total over its track.
    private func side(label: String, content: Content, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(.system(.title2, design: .serif).weight(.bold)).lineLimit(1).minimumScaleFactor(0.5)
                Spacer(minLength: 4)
                Text(content.total, format: .number).font(.system(size: 44, weight: .bold, design: .serif)).monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            track(content, color: color)
        }
    }

    /// The race itself: a line from 0 to 25, filled in the team's colour as far as its marker, which carries the total.
    private func track(_ content: Content, color: Color) -> some View {
        GeometryReader { geometry in
            let end = geometry.size.width - 50
            let x = 16 + (end - 32) * Double(content.dots) / Double(HouseRules.matchTarget)
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Paper.tan).frame(width: end, height: 5)
                Capsule().fill(color).frame(width: x, height: 5)
                Text(content.total, format: .number).font(.system(.subheadline, design: .serif).weight(.bold)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .foregroundStyle(.ivory)
                    .frame(width: 32, height: 32)
                    .background(color, in: Circle())
                    .overlay(Circle().stroke(Theme.Paper.rule, lineWidth: 1.5))
                    .position(x: x, y: geometry.size.height / 2)
                Text(HouseRules.matchTarget, format: .number).font(.system(.subheadline, design: .serif).weight(.bold))
                    .frame(width: 42, height: 26)
                    .background(Theme.Paper.tan, in: Capsule())
                    .overlay(Capsule().stroke(Theme.Paper.rule, lineWidth: 1.5))
                    .position(x: geometry.size.width - 21, y: geometry.size.height / 2)
            }
            .frame(height: geometry.size.height)
        }
        .frame(height: 34)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(content.dots) of \(HouseRules.matchTarget) points")
    }

    /// The hands so far, one page each with both teams' change and total, newest first, paging sideways.
    @ViewBuilder private var hands: some View {
        if us.hands.isEmpty {
            Text("No hands scored yet").font(.headline).opacity(0.6).frame(height: Self.cardHeight)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(Array(zip(us.hands, them.hands).reversed()), id: \.0.number) { ours, theirs in
                        handCard(ours, theirs).containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .frame(height: Self.cardHeight)
        }
    }

    private static let cardHeight = 132.0

    private func handCard(_ ours: HandCard, _ theirs: HandCard) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Hand \(ours.number)").font(.system(.title3, design: .serif).weight(.bold).italic())
                Spacer(minLength: 6)
                Text(ours.line).font(.subheadline).lineLimit(1).minimumScaleFactor(0.6)
            }
            Rectangle().fill(Theme.Paper.rule).frame(height: 1)
            HStack(spacing: 0) {
                change(label: usLabel, ours)
                Rectangle().fill(Theme.Paper.rule.opacity(0.6)).frame(width: 1)
                change(label: themLabel, theirs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// One team's side of a hand: its label (BID on the team that bid), the change, and "Now" the total.
    private func change(label: String, _ hand: HandCard) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text(label).font(.system(.caption, design: .serif).weight(.bold)).lineLimit(1).minimumScaleFactor(0.6)
                if hand.ourBid { Text("BID").font(.caption2.weight(.semibold)).tracking(1.5).opacity(0.6) }
            }
            Text(hand.change >= 0 ? "+\(hand.change)" : "\(hand.change)")
                .font(.system(size: 34, weight: .bold, design: .serif)).monospacedDigit()
                .foregroundStyle(hand.change >= 0 ? Theme.Paper.green : Color.suitRed)
            Text("Now \(hand.total)").font(.subheadline).monospacedDigit().opacity(0.6)
        }
        .frame(maxWidth: .infinity)
    }
}
