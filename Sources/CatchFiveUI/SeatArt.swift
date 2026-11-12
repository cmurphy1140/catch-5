import SwiftUI

/// A seat's figure as a cut-out picture (D148), when the build carries one: the data-free image assets `GuestSeat0`
/// to `GuestSeat3`, one per seat, kept out of the repository like the other `Guest` assets. A build without them
/// draws the usual portraits.
enum SeatArt {
    /// The new cast's pictures are `GuestCast1` to `GuestCast3` (D160); a seat without one draws its portrait rather
    /// than wear the family's picture under another name.
    static func image(seat: Int, opponents: Settings.Opponents) -> Image? {
        // Her own seat wears the look she chose on her page, when she has chosen one (D177).
        if seat == 0, let look = GuestLook.chosen { return look }
        return named(seat == 0 || opponents == .family ? "GuestSeat\(seat)" : "GuestCast\(seat)")
    }

    /// Any of the build's private pictures by name, or nil when the build has none.
    static func named(_ name: String) -> Image? {
        #if canImport(UIKit)
        UIImage(named: name).map(Image.init(uiImage:))
        #else
        nil
        #endif
    }

    /// How much wider and taller than the old portrait disc a figure is drawn; it stands on the disc's bottom edge.
    static let width = 1.7, height = 1.5
}

/// A seat's face away from the table (D170): its cut-out figure when the build carries one, the drawn portrait when
/// not. The drawn faces stay for the lessons and demos.
struct SeatFace: View {
    let portrait: Portrait
    var figure: Image?
    let size: Double

    var body: some View {
        if let figure {
            figure.resizable().scaledToFit().frame(width: size * 1.25, height: size * 1.15, alignment: .bottom)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                .accessibilityHidden(true)
        } else {
            PortraitView(portrait: portrait, size: size)
        }
    }
}
