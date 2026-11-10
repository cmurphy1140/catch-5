import SwiftUI

/// Make your own face (D109): one row per part of the recipe, each choice drawn as the face it would give, so
/// nothing needs a label to be understood. Shuffle deals a whole new face. It takes its ink from wherever it
/// sits, so it works on ivory paper and on the wood alike; `ring` is the colour that marks the chosen face.
struct FaceBuilder: View {
    @Binding var portrait: Portrait
    var ring: Color = Theme.Paper.green

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                PortraitView(portrait: portrait, size: 84)
                Button { portrait = Self.shuffled() } label: {
                    Label("Shuffle", systemImage: "shuffle").font(.title3.weight(.medium))
                        .frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(ring)
                .accessibilityHint("Deals a new face")
            }
            row("Skin", \.skin)
            row("Hair", \.hair)
            row("Hair colour", \.hairColor)
            row("Details", \.feature)
            row("Hat", \.hat)
            row("Clothes", \.shirt)
        }
    }

    /// Every part chosen at random.
    static func shuffled() -> Portrait {
        Portrait(skin: Portrait.Skin.allCases.randomElement() ?? .tan, hair: Portrait.Hair.allCases.randomElement() ?? .short,
                 hairColor: Portrait.HairColor.allCases.randomElement() ?? .black, feature: Portrait.Feature.allCases.randomElement() ?? .none,
                 hat: Portrait.Hat.allCases.randomElement() ?? .none, shirt: Portrait.Shirt.allCases.randomElement() ?? .oxford)
    }

    /// One part's choices: the current face with only that part changed.
    private func row<Value: Hashable & CaseIterable>(_ title: String, _ part: WritableKeyPath<Portrait, Value>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.semibold)).opacity(0.7)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(Value.allCases), id: \.self) { value in
                        let chosen = portrait[keyPath: part] == value
                        Button { portrait[keyPath: part] = value } label: {
                            PortraitView(portrait: changed(part, to: value), size: 48)
                                .padding(3)
                                .overlay(Circle().stroke(ring, lineWidth: chosen ? 3 : 0))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(title): \(String(describing: value))")
                        .accessibilityAddTraits(chosen ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func changed<Value>(_ part: WritableKeyPath<Portrait, Value>, to value: Value) -> Portrait {
        var copy = portrait
        copy[keyPath: part] = value
        return copy
    }
}
