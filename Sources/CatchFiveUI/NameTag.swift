import CatchFive
import SwiftUI

/// A seat's name carved into the wood under it (D94, over the N64 sticker): large dark serif letters cut into the
/// table, and beside them, when this seat won the bid and trump is named, the trump suit cut the same way. Every seat
/// has one; the phone holder's sits under the hand.
struct NameTag: View {
    let name: String
    @ScaledMetric(relativeTo: .title2) private var nameSize = Theme.Table.carvedNameSize
    /// Trump, carved beside the name of the seat that bid (D94); nil for everyone else.
    var trump: Suit? = nil
    /// The name lies on the dark field, so it is inlaid in maple instead of cut dark into the oak (D113).
    var inlaid = false

    /// The rename button's height: a full thumb (D93).
    nonisolated static let hitHeight = Theme.Table.statusButtonHitSize
    nonisolated static let renameHint = "Rename this seat"

    /// The names by place round the table, 0 the phone holder at the bottom, then left, across and right.
    static func names(_ model: GameModel) -> [String] {
        (0..<4).map { model.seatNames[model.seat(at: $0)] }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(name).font(.system(size: nameSize, weight: .heavy, design: .serif))
                .modifier(NameInk(inlaid: inlaid))
                // One line, shrinking to fit: a name broken in two ("Dian", "e") makes its seat taller and reads as two words.
                .lineLimit(1).minimumScaleFactor(0.55)
            if let trump {
                if inlaid {
                    Text(trump.glyph).font(.system(size: Theme.Table.carvedNameSize + 4)).foregroundStyle(TrumpInlay.wood(for: trump))
                        .shadow(color: .black.opacity(0.6), radius: 1, y: 1).accessibilityHidden(true)
                } else { CarvedSuit(suit: trump, size: Theme.Table.carvedNameSize + 4) }
            }
        }
        .dynamicTypeSize(...Theme.Card.maximumTypeSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    /// "Diane, hearts are trump" for the bidder once trump is named; the name alone otherwise.
    var spoken: String { trump.map { "\(name), \($0.rawValue) are trump" } ?? name }
}

extension NameTag {
    /// The carved name as a button that renames its seat (D93): its hit area at least a thumb tall.
    func renames(_ onRename: @escaping () -> Void) -> some View {
        Button(action: onRename) {
            frame(minHeight: Self.hitHeight).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spoken)
        .accessibilityHint(Self.renameHint)
    }
}

/// A name's ink: cut dark into the oak, or inlaid light in the walnut field.
private struct NameInk: ViewModifier {
    let inlaid: Bool
    func body(content: Content) -> some View {
        if inlaid {
            content.foregroundStyle(Theme.Field.maple).shadow(color: .black.opacity(0.7), radius: 1, y: 1)
                .shadow(color: .black.opacity(0.55), radius: 3) // side names overhang onto the pale woods (D118)
        } else {
            content.carved()
        }
    }
}
