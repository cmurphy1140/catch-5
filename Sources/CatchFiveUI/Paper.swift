import SwiftUI

// The pieces every ivory reading card shares (D107). The colours are `Theme.Paper`.

/// A two-way switch on an ivory card: the chosen half is green, the other waits in green type.
struct PaperSwitch<Value: Hashable>: View {
    let options: [(title: String, value: Value)]
    @Binding var selection: Value
    /// A tick beside the chosen half, for a setting that stays chosen.
    var ticks = false
    /// Smaller words for a switch that shares its row with a name, so both halves stay one size.
    var compact = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                let chosen = selection == option.value
                Button { selection = option.value } label: {
                    HStack(spacing: 5) {
                        if ticks, chosen { Image(systemName: "checkmark").font(.footnote.weight(.bold)) }
                        Text(option.title).font(.system(compact ? .subheadline : .title3, design: .serif).weight(.semibold))
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                    .padding(.horizontal, compact ? 6 : 8)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(chosen ? .ivory : Theme.Paper.green)
                    .background(chosen ? Theme.Paper.green : .clear, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(chosen ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Theme.Paper.tan.opacity(0.6), in: Capsule())
        .overlay(Capsule().stroke(Theme.Paper.rule))
    }
}

/// A line of the card set between two short gold rules.
struct RuledLine<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            rule
            content.layoutPriority(1)
            rule
        }
    }

    private var rule: some View {
        Rectangle().fill(Theme.Paper.rule).frame(height: 1).frame(maxWidth: 56).accessibilityHidden(true)
    }
}

/// The one action of an ivory card: a full-width dark green button, its label in the display serif.
struct PaperButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        configuration.label
            .font(.system(.title2, design: .serif).weight(.bold))
            .lineLimit(1).minimumScaleFactor(0.6)
            .foregroundStyle(.ivory)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: Theme.Paper.buttonHeight)
            .background(shape.fill(LinearGradient(colors: [Theme.Paper.green, Theme.Paper.greenDeep], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 3))
            .overlay(shape.stroke(Theme.Paper.rule.opacity(0.6), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Theme.Motion.press, value: configuration.isPressed)
    }
}

extension View {
    /// The ivory card itself: paper, a gold edge and a second hairline just inside it.
    func paperCard() -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Paper.cardRadius, style: .continuous)
        // The shadow belongs to the paper alone; on the whole card it would fall from every letter too.
        return background(shape.fill(.ivory).shadow(color: .black.opacity(0.4), radius: 10, y: 4))
            .overlay(shape.stroke(Theme.Paper.rule, lineWidth: 1.5))
            .overlay(RoundedRectangle(cornerRadius: Theme.Paper.cardRadius - 4, style: .continuous)
                .stroke(Theme.Paper.rule.opacity(0.45), lineWidth: 1).padding(4))
    }
}

/// The quieter actions beside it: ivory, with green type and a gold edge.
struct PaperSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        configuration.label
            .font(.system(.title3, design: .serif).weight(.bold))
            .lineLimit(1).minimumScaleFactor(0.6)
            .foregroundStyle(Theme.Paper.green)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(shape.fill(.ivory).shadow(color: .black.opacity(0.3), radius: 4, y: 3))
            .overlay(shape.stroke(Theme.Paper.rule, lineWidth: 1.5))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Theme.Motion.press, value: configuration.isPressed)
    }
}
