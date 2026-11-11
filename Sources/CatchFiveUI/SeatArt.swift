import SwiftUI

/// A seat's figure as a cut-out picture (D148), when the build carries one: the data-free image assets `GuestSeat0`
/// to `GuestSeat3`, one per seat, kept out of the repository like the other `Guest` assets. A build without them
/// draws the usual portraits.
enum SeatArt {
    static func image(seat: Int) -> Image? { named("GuestSeat\(seat)") }

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
