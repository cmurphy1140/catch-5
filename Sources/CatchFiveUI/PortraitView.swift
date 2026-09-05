import SwiftUI

/// A face drawn from a `Portrait` recipe: shoulders, head, hair, one feature, one hat, inside an ivory-ringed disc.
/// Every measurement is a fraction of `size`, so the same view serves 28 pt seat tiles and 72 pt pickers.
struct PortraitView: View {
    let portrait: Portrait
    let size: Double

    var body: some View {
        ZStack {
            Circle().fill(Theme.Portrait.disc)
            shoulders
            hairBack
            head
            feature
            hairFront
            hat
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.ivory.opacity(0.7), lineWidth: max(1, size * 0.03)))
        .accessibilityHidden(true)
    }

    // MARK: Parts

    private var shoulders: some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(Theme.Portrait.color(portrait.shirt))
            .frame(width: size * 0.78, height: size * 0.5)
            .offset(y: size * 0.5)
    }

    private var head: some View {
        Ellipse()
            .fill(Theme.Portrait.color(portrait.skin))
            .frame(width: size * 0.46, height: size * 0.54)
            .offset(y: -size * 0.02)
    }

    /// Hair drawn behind the head: the bob's sides and the curly mass.
    @ViewBuilder private var hairBack: some View {
        let color = Theme.Portrait.color(portrait.hairColor)
        switch portrait.hair {
        case .bob:
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .fill(color).frame(width: size * 0.56, height: size * 0.6).offset(y: -size * 0.02)
        case .curly:
            Circle().fill(color).frame(width: size * 0.6, height: size * 0.6).offset(y: -size * 0.06)
        case .short, .bald:
            EmptyView()
        }
    }

    /// Hair drawn over the head: the short cut's cap.
    @ViewBuilder private var hairFront: some View {
        if portrait.hair == .short {
            Ellipse()
                .fill(Theme.Portrait.color(portrait.hairColor))
                .frame(width: size * 0.48, height: size * 0.24)
                .offset(y: -size * 0.24)
        }
    }

    @ViewBuilder private var feature: some View {
        switch portrait.feature {
        case .none:
            EmptyView()
        case .glasses:
            HStack(spacing: size * 0.02) {
                Circle().stroke(Theme.Portrait.accessory, lineWidth: max(1, size * 0.025)).frame(width: size * 0.15, height: size * 0.15)
                Circle().stroke(Theme.Portrait.accessory, lineWidth: max(1, size * 0.025)).frame(width: size * 0.15, height: size * 0.15)
            }.offset(y: -size * 0.03)
        case .moustache:
            Capsule().fill(Theme.Portrait.color(portrait.hairColor))
                .frame(width: size * 0.2, height: size * 0.06).offset(y: size * 0.1)
        case .freckles:
            HStack(spacing: size * 0.04) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(Theme.Portrait.accessory.opacity(0.5)).frame(width: size * 0.03, height: size * 0.03)
                }
            }.offset(y: size * 0.05)
        }
    }

    @ViewBuilder private var hat: some View {
        switch portrait.hat {
        case .none:
            EmptyView()
        case .beanie:
            RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
                .fill(Theme.Portrait.accessory)
                .frame(width: size * 0.5, height: size * 0.26).offset(y: -size * 0.26)
        case .cap:
            ZStack {
                Ellipse().fill(Theme.Portrait.accessory).frame(width: size * 0.5, height: size * 0.22).offset(y: -size * 0.26)
                Capsule().fill(Theme.Portrait.accessory).frame(width: size * 0.62, height: size * 0.07).offset(y: -size * 0.18)
            }
        case .flower:
            Image(systemName: "leaf.fill")
                .resizable().scaledToFit()
                .foregroundStyle(Theme.Portrait.color(.rust))
                .frame(width: size * 0.16, height: size * 0.16)
                .rotationEffect(.degrees(-30))
                .offset(x: size * 0.18, y: -size * 0.24)
        }
    }
}
