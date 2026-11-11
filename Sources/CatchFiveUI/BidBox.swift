import CatchFive
import SwiftUI

/// One seat's place in the auction (N55): empty until the seat speaks, then its bid, PASS or 9 OUT, big, chalked on the
/// table with no box round it (D94, D97). Every
/// seat has one, the phone holder included; the call arrives from where it was made (the bid row for you,
/// the seat for everyone else), and the boxes go when the auction ends and the bid corner takes over.
struct BidBox: View {
    let label: String?
    /// Where the call comes in from, relative to the box: the bid row below it, or the seat beside it.
    let from: CGSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// What `seat`'s box says: its latest call, or nil before it has spoken.
    nonisolated static func label(for seat: Int, in auction: Auction) -> String? {
        auction.calls.last { $0.seat == seat }.map { call in
            switch call.bid {
            case nil: "PASS"
            case .nineAndOut: "9 OUT"
            case let .points(amount): String(amount)
            }
        }
    }

    var body: some View {
        ZStack {
            if let label {
                Text(label)
                    .font(.system(size: label.count > 1 ? Theme.Table.bidBoxWordSize : Theme.Table.bidBoxNumberSize,
                                  weight: .heavy, design: .rounded))
                    // Said aloud (D157): ink in an ivory speech bubble whose tail points at the seat that called.
                    .foregroundStyle(Theme.Paper.ink)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .padding(.horizontal, 5)
                    .frame(width: Theme.Table.bidBoxWidth, height: Theme.Table.bidBoxHeight)
                    .background {
                        SpeechBubble(tail: SpeechBubble.tail(toward: from)).fill(Color.ivory)
                            .shadow(color: .black.opacity(0.4), radius: 2, y: 2)
                    }
                    .id(label)
                    .transition(reduceMotion ? .opacity
                        : .asymmetric(insertion: .offset(from).combined(with: .scale(scale: 0.5)).combined(with: .opacity),
                                      removal: .opacity))
            }
        }
        .frame(width: Theme.Table.bidBoxWidth, height: Theme.Table.bidBoxHeight)
        .dynamicTypeSize(...Theme.Card.maximumTypeSize)
        .accessibilityHidden(true)
    }
}

/// A rounded bubble with a small tail on one side, pointing at whoever spoke (D157).
struct SpeechBubble: Shape {
    let tail: Edge

    /// The side the speaker is on, from where the call comes in: sideways if it comes from the side, else up or down.
    nonisolated static func tail(toward from: CGSize) -> Edge {
        if from.width != 0 { return from.width < 0 ? .leading : .trailing }
        return from.height < 0 ? .top : .bottom
    }

    func path(in rect: CGRect) -> Path {
        let reach = 7.0, half = 6.0
        let body = rect.insetBy(dx: tail == .leading || tail == .trailing ? reach / 2 : 0, dy: tail == .top || tail == .bottom ? reach / 2 : 0)
            .offsetBy(dx: tail == .leading ? reach / 2 : tail == .trailing ? -reach / 2 : 0, dy: tail == .top ? reach / 2 : tail == .bottom ? -reach / 2 : 0)
        var path = Path(roundedRect: body, cornerRadius: min(body.height, body.width) * 0.36, style: .continuous)
        let tip: CGPoint, a: CGPoint, b: CGPoint
        switch tail {
        case .leading: tip = CGPoint(x: rect.minX, y: rect.midY + 6); a = CGPoint(x: body.minX + 1, y: rect.midY - half); b = CGPoint(x: body.minX + 1, y: rect.midY + half)
        case .trailing: tip = CGPoint(x: rect.maxX, y: rect.midY + 6); a = CGPoint(x: body.maxX - 1, y: rect.midY - half); b = CGPoint(x: body.maxX - 1, y: rect.midY + half)
        case .top: tip = CGPoint(x: rect.midX + 6, y: rect.minY); a = CGPoint(x: rect.midX - half, y: body.minY + 1); b = CGPoint(x: rect.midX + half, y: body.minY + 1)
        case .bottom: tip = CGPoint(x: rect.midX + 6, y: rect.maxY); a = CGPoint(x: rect.midX - half, y: body.maxY - 1); b = CGPoint(x: rect.midX + half, y: body.maxY - 1)
        }
        path.move(to: a); path.addLine(to: tip); path.addLine(to: b); path.closeSubpath()
        return path
    }
}
