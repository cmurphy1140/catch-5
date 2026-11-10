import CatchFive
import SwiftUI

/// Words and suits cut into the table (D94): a dark recess with its shadow along the upper edge and a lit lower
/// edge, the grain showing faintly through, so the information is part of the wood rather than a panel on it.
enum Carving {
    /// The recess: the darkest wood brown, a little open so the grain carries on through it.
    static let ink = Theme.Wood.header.opacity(0.92)
    /// Hearts and diamonds cut in an oxblood dark enough to read on the wood, so they still read red.
    static let redInk = Color(red: 0.22, green: 0.01, blue: 0.03)
    /// The light catching the recess's lower lip.
    static let litEdge = Theme.Wood.streakLight.opacity(0.75)

    static func ink(for suit: Suit) -> Color { suit.isRed ? redInk : ink }

    /// The floor of a big recess (D95): a shade lighter than its top, where the light falls in, still 3:1 on the wood.
    static let floor = Color(red: 0.15, green: 0.09, blue: 0.045)
    static let redFloor = Color(red: 0.25, green: 0.01, blue: 0.03)

    static func floor(for suit: Suit) -> Color { suit.isRed ? redFloor : floor }

    /// How deep a cut of this size reads (D95): 1 for the carved names and smaller, growing with the size above
    /// them, so a big suit's shadowed upper edge and lit lip scale with it instead of vanishing into the fill.
    static func depth(size: Double) -> Double { max(1, size / Theme.Table.carvedNameSize) }

    /// Relative luminance (WCAG) of a colour as drawn over `ground` (its opacity blended in), from sRGB components.
    static func luminance(_ color: Color, over ground: Color = .black) -> Double {
        let top = color.resolve(in: EnvironmentValues()), under = ground.resolve(in: EnvironmentValues())
        let alpha = Double(top.opacity)
        func channel(_ t: Float, _ u: Float) -> Double {
            let v = alpha * Double(t) + (1 - alpha) * Double(u)
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(top.red, under.red) + 0.7152 * channel(top.green, under.green) + 0.0722 * channel(top.blue, under.blue)
    }

    /// The WCAG contrast ratio of `ink`, laid over `ground`, against `ground`.
    static func contrast(_ ink: Color, on ground: Color) -> Double {
        let a = luminance(ink, over: ground), b = luminance(ground)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

/// Cuts text or a glyph into the wood: the ink with an inner shadow on its upper edge, and a lit lower edge.
/// A big cut (`floor` set, D95) is shaded from the ink at its top to the lighter floor at its foot, and `depth` scales the
/// shadow and the lip with it.
struct Carved: ViewModifier {
    var ink: Color = Carving.ink
    var floor: Color? = nil
    var depth = 1.0

    func body(content: Content) -> some View {
        content
            .foregroundStyle(LinearGradient(colors: [ink, floor ?? ink], startPoint: .top, endPoint: .bottom)
                .shadow(.inner(color: .black.opacity(0.85), radius: depth, x: 0, y: 1.5 * depth)))
            .shadow(color: Carving.litEdge, radius: 0, x: 0, y: depth)
    }
}

extension View {
    func carved(_ ink: Color = Carving.ink) -> some View { modifier(Carved(ink: ink)) }
}

/// A suit cut into the wood, in its own dark colour (D94), as concave as the letters: a floor lighter than its top,
/// and the shadow and lit lip cut as deep as its size (D95).
struct CarvedSuit: View {
    let suit: Suit
    let size: Double

    var body: some View {
        Text(suit.glyph).font(.system(size: size))
            .modifier(Carved(ink: Carving.ink(for: suit), floor: Carving.floor(for: suit), depth: Carving.depth(size: size)))
            .accessibilityHidden(true)
    }
}

/// A dealer button (D94): a round ivory puck resting on the table, a "D" engraved in it, its shadow on the wood.
struct DealerButton: View {
    var body: some View {
        let size = Theme.Table.dealerButtonSize
        ZStack {
            Circle().fill(RadialGradient(colors: [.ivory, Color(red: 0.86, green: 0.82, blue: 0.72)],
                                         center: .init(x: 0.35, y: 0.3), startRadius: 1, endRadius: size * 0.7))
            // The rim: a darker groove just inside the edge, like a real puck's.
            Circle().strokeBorder(Theme.Wood.dark.opacity(0.35), lineWidth: 1.5).padding(3)
            Text(DealerMark.engraving)
                .font(.system(size: Theme.Table.dealerButtonLetterSize, weight: .black, design: .serif))
                .foregroundStyle(Theme.Wood.streakDark.shadow(.inner(color: .black.opacity(0.7), radius: 0.8, y: 1)))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.45), radius: 3, x: 1, y: 3)
        .accessibilityHidden(true)
    }
}

/// The Rules control (D94): a small closed book lying on the table, "Rules" on its burgundy cover, its page edges
/// showing along the side and foot, slightly turned, with its shadow on the wood.
struct RulesBook: View {
    static let cover = Color(red: 0.42, green: 0.10, blue: 0.14)
    /// The ribbon marker hanging from the pages: cream, since gold keeps its table meanings (D33).
    static let ribbon = Color(red: 0.93, green: 0.86, blue: 0.70)
    /// How often a soft sheen crosses the cover, so the book reads as something to pick up without calling out (D98).
    nonisolated static let sheenEvery = 9.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sheen = -0.4

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The page block, peeking out right and below the cover, with its ribbon hanging out of the foot.
            RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.93, green: 0.90, blue: 0.82))
                .overlay(alignment: .bottomTrailing) {
                    Capsule().fill(Self.ribbon).frame(width: 7, height: 16).offset(x: -22, y: 10)
                        .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                }
                .offset(x: 3, y: 3)
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [Self.cover, Self.cover.opacity(0.85)], startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .leading) {
                    // The spine: a darker band down the left.
                    Rectangle().fill(.black.opacity(0.25)).frame(width: 9)
                }
                // A blind-tooled border inset from the edge, as on a cloth-bound book.
                .overlay(RoundedRectangle(cornerRadius: 2).inset(by: 5).stroke(.black.opacity(0.28), lineWidth: 1).padding(.leading, 9))
                .overlay {
                    // Light catching the cloth now and then.
                    LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .white.opacity(0.28), location: 0.5),
                                           .init(color: .clear, location: 1)], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 44)
                        .rotationEffect(.degrees(18))
                        .offset(x: sheen * Theme.Table.rulesBookWidth)
                        .blendMode(.plusLighter)
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(TableTopRow.rules.title)
                .font(.system(.title, design: .serif).weight(.bold))
                .foregroundStyle(Color(red: 0.95, green: 0.90, blue: 0.78))
                .lineLimit(1).minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.leading, 11).padding(.trailing, 3)
        }
        // The header reserves the portrait cover, page edges, ribbon and turned shadow.
        .frame(width: Theme.Table.rulesBookWidth, height: Theme.Table.rulesBookHeight)
        .rotationEffect(.degrees(-4))
        .shadow(color: .black.opacity(0.5), radius: 3, x: 2, y: 3)
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.sheenEvery))
                guard !Task.isCancelled else { return }
                sheen = -0.4
                withAnimation(.easeInOut(duration: 1.1)) { sheen = 0.9 }
            }
        }
        .accessibilityHidden(true)
    }
}

/// The book answers a press by lifting a little off the table and settling back (D98).
struct BookPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 1.06 : 1)
            .offset(y: configuration.isPressed && !reduceMotion ? -2 : 0)
            .opacity(configuration.isPressed && reduceMotion ? 0.8 : 1)
            .animation(reduceMotion ? nil : Theme.Motion.press, value: configuration.isPressed)
            .frame(minWidth: Theme.Table.topRowHeight, minHeight: Theme.Table.topRowHeight)
            .contentShape(Rectangle())
    }
}

/// A help screen arriving like a book opening (D94): the page swings onto the screen about its left edge, from
/// edge-on to flat, with a little perspective and the shade of the turn; closing swings it back. Reduce Motion fades.
struct BookFold: ViewModifier {
    var progress: Double

    nonisolated static let seconds = 0.5

    /// The page's turn out of the screen, in degrees: 90 edge-on at the start, 0 flat when open.
    nonisolated static func angle(progress: Double) -> Double { (1 - progress) * 90 }

    /// The `table-rules-fold` screenshot stage holds the page halfway open; any other stage lets it move.
    nonisolated static func heldProgress(stage: String?) -> Double? { stage == "table-rules-fold" ? 0.5 : nil }

    func body(content: Content) -> some View {
        content
            .overlay(Color.black.opacity((1 - progress) * 0.55).allowsHitTesting(false))
            .rotation3DEffect(.degrees(Self.angle(progress: progress)), axis: (x: 0, y: 1, z: 0),
                              anchor: .leading, perspective: 0.6)
    }

    static func transition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .modifier(active: BookFold(progress: 0), identity: BookFold(progress: 1))
    }
}
