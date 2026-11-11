import CatchFive
import SwiftUI

/// What a player's card says about them (D151), counted from the match so far: the bids they won and whether they
/// made them, the tricks they have taken this hand, and their side's score.
struct PlayerSheet: Equatable {
    let hands: Int
    let bidsWon: Int
    let made: Int
    let set: Int
    let averageBid: Double?
    let tricksThisHand: Int
    let sideScore: Int

    init(hands: Int, bidsWon: Int, made: Int, set: Int, averageBid: Double?, tricksThisHand: Int, sideScore: Int) {
        self.hands = hands; self.bidsWon = bidsWon; self.made = made; self.set = set
        self.averageBid = averageBid; self.tricksThisHand = tricksThisHand; self.sideScore = sideScore
    }

    init(seat: Int, match: Match) {
        let theirs = match.history.filter { $0.bidder == seat }
        let made = theirs.filter(\.contractMade).count
        self.init(hands: match.history.count, bidsWon: theirs.count, made: made, set: theirs.count - made,
                  averageBid: theirs.isEmpty ? nil : Double(theirs.reduce(0) { $0 + ($1.isNineAndOut ? 9 : $1.bid) }) / Double(theirs.count),
                  tricksThisHand: match.hand.completedTricks.filter { $0.winner == seat }.count,
                  sideScore: match.scores[seat % 2])
    }

    /// How they have played this match, in a few words. It is read off the counts above and nothing else.
    var style: String {
        guard hands > 0 else { return "Too early to tell" }
        guard bidsWon > 0 else { return "Lets others do the bidding" }
        if set > made { return "Bites off more than they can chew" }
        if let averageBid, averageBid >= 4 { return "Bold bidder" }
        if bidsWon * 2 >= hands { return "Likes to run the table" }
        return "Steady hand"
    }

    /// The scoreboard's lines, label then figure.
    var lines: [(label: String, value: String)] {
        [("Bids won", "\(bidsWon) of \(hands)"), ("Made, set", "\(made), \(set)"),
         ("Tricks now", "\(tricksThisHand)"), ("Side's score", "\(sideScore)")]
    }
}

/// A player as a card (D150, D151): their figure on an oxblood wash, their name on a ribbon, and under it their thing
/// on the table, how they play and their scoreboard. A pencil in the corner renames them.
struct PlayerCard: View {
    let name: String
    let figure: Image?
    var item: Image? = nil
    var sheet: PlayerSheet? = nil
    var width = 280.0
    var onRename: (() -> Void)? = nil

    private static let paper = Color(red: 0.95, green: 0.90, blue: 0.78)

    var body: some View {
        let height = width * 1.45
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.07, style: .continuous).fill(Self.paper)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 5)
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    Color.suitRed.opacity(0.16)
                    if let figure { figure.resizable().scaledToFit().padding(.top, width * 0.09).padding(.horizontal, width * 0.06) }
                }
                .frame(height: height * 0.42).clipped()
                Color.clear.frame(height: width * 0.17) // the ribbon lies over this seam
                VStack(spacing: width * 0.02) {
                    if let sheet {
                        Text(sheet.style).font(.system(size: width * 0.058, weight: .bold, design: .serif)).italic()
                            .foregroundStyle(Theme.Paper.green).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    HStack(alignment: .center, spacing: width * 0.05) {
                        if let item { item.resizable().scaledToFit().frame(width: width * 0.27).shadow(color: .black.opacity(0.25), radius: 2, y: 2) }
                        if let sheet {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(sheet.lines, id: \.label) { line in
                                    HStack(spacing: 4) {
                                        Text(line.label)
                                        Spacer(minLength: 4)
                                        Text(line.value).fontWeight(.bold)
                                    }
                                    .font(.custom("Noteworthy-Light", fixedSize: width * 0.052))
                                }
                            }
                        }
                    }
                }
                .foregroundStyle(Theme.Paper.ink)
                .padding(.horizontal, width * 0.07)
                .frame(maxHeight: .infinity)
            }
            .padding(width * 0.075)
            RoundedRectangle(cornerRadius: width * 0.045, style: .continuous).inset(by: width * 0.06)
                .stroke(Theme.Paper.ink.opacity(0.75), lineWidth: 1.2)
            Text(name.uppercased()).font(.system(size: width * 0.1, weight: .heavy, design: .serif)).tracking(2)
                .foregroundStyle(Theme.Paper.ink).lineLimit(1).minimumScaleFactor(0.5)
                .padding(.horizontal, width * 0.1).frame(width: width * 0.96, height: width * 0.17)
                .background { Ribbon().fill(Self.paper).overlay(Ribbon().stroke(Theme.Paper.ink.opacity(0.8), lineWidth: 1.2)) }
                .rotationEffect(.degrees(-4))
                .offset(y: -height * 0.5 + width * 0.075 + height * 0.42 + width * 0.07)
            VStack(spacing: -2) {
                Text(String(name.prefix(1)).uppercased()).font(.system(size: width * 0.1, weight: .bold, design: .serif))
                Text("♦").font(.system(size: width * 0.085))
            }
            .foregroundStyle(Color.suitRed)
            .padding(width * 0.1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if let onRename {
                Button(action: onRename) {
                    Image(systemName: "pencil").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.Paper.ink)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Rename \(name)")
                .padding(width * 0.07)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .frame(width: width, height: height)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(name)'s card" + (sheet.map { ". \($0.style). " + $0.lines.map { "\($0.label) \($0.value)" }.joined(separator: ", ") } ?? ""))
    }
}

/// A band whose two ends are cut to swallow tails.
struct Ribbon: Shape {
    func path(in rect: CGRect) -> Path {
        let notch = rect.height * 0.4
        var path = Path()
        path.addLines([CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX - notch, y: rect.midY),
                       CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.minX + notch, y: rect.midY)])
        path.closeSubpath()
        return path
    }
}
