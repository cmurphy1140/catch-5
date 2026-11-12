import CatchFive
import SwiftUI

/// The burgundy cloth band over a page of paper (D181): the page's name in the display serif and a dark Done pill.
struct ClothHeader<Below: View>: View {
    let title: String
    let onDone: () -> Void
    /// Burgundy for the pages about playing, green for the pages about the app itself (D184).
    var colours = ClothColours.burgundy
    /// Small symbols before Done: the chat's notebook and its settings.
    var tools: [ClothTool] = []
    /// What rides on the cloth under the title, edge to edge: the rulebook's chapter chips.
    @ViewBuilder var below: Below

    var body: some View {
        VStack(spacing: 0) {
            bar
            below
        }
        .foregroundStyle(.ivory)
        .background {
            let shape = UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
            shape.fill(LinearGradient(colors: [colours.cloth, colours.deep], startPoint: .top, endPoint: .bottom))
                .overlay(BandNap().clipShape(shape))
                .shadow(color: .black.opacity(0.35), radius: 5, y: 3)
        }
        .padding(.top, 8)
    }

    private var bar: some View {
        HStack(spacing: 12) {
            Text(title).font(.system(.largeTitle, design: .serif).weight(.bold))
                .lineLimit(1).minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            ForEach(tools) { tool in
                Button(action: tool.action) {
                    Image(systemName: tool.symbol).font(.title3.weight(.semibold)).frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel(tool.label)
            }
            Button(action: onDone) {
                Text("Done").font(.system(.title3, design: .serif).weight(.bold))
                    .padding(.horizontal, 18).frame(minHeight: 44)
                    .background(Theme.Wood.header, in: Capsule())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }
}

extension ClothHeader where Below == EmptyView {
    init(title: String, colours: ClothColours = .burgundy, tools: [ClothTool] = [], onDone: @escaping () -> Void) {
        self.init(title: title, onDone: onDone, colours: colours, tools: tools) { EmptyView() }
    }
}

/// A symbol on the band that opens something.
struct ClothTool: Identifiable {
    let label: String
    let symbol: String
    let action: () -> Void
    var id: String { label }
}

/// The band's cloth, lit from above.
struct ClothColours {
    let cloth: Color
    let deep: Color
    static let burgundy = ClothColours(cloth: Color(red: 0.47, green: 0.07, blue: 0.12), deep: Color(red: 0.34, green: 0.04, blue: 0.08))
    static let green = ClothColours(cloth: Color(red: 0.09, green: 0.29, blue: 0.19), deep: Color(red: 0.04, green: 0.17, blue: 0.11))
}

/// The nap of the cloth: faint seeded flecks, drawn once and still.
private struct BandNap: View {
    var body: some View {
        Canvas { context, size in
            var state: UInt64 = 23
            func next() -> Double {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                return Double(state >> 33) / Double(1 << 31)
            }
            for _ in 0..<Int(size.width * size.height / 26) {
                let spot = CGRect(x: next() * size.width, y: next() * size.height, width: 1.2, height: 1.2)
                context.fill(Path(ellipseIn: spot), with: .color(next() < 0.5 ? .white.opacity(0.07) : .black.opacity(0.12)))
            }
        }
        .accessibilityHidden(true)
    }
}

/// A page under the cloth band: one sheet of ivory paper on the wood, scrolling under the band, which stays put.
struct ClothPage<Content: View>: View {
    let title: String
    let onDone: () -> Void
    var spacing = 18.0
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            ClothHeader(title: title, onDone: onDone).zIndex(1)
            ScrollView {
                VStack(alignment: .leading, spacing: spacing) { content }
                    .foregroundStyle(Theme.Paper.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .paperCard()
                    // Paper is light whatever is around it, so fields and switches draw for light.
                    .environment(\.colorScheme, .light)
                    .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 12)
            }
        }
        .background(WoodGrainView().ignoresSafeArea())
        #if os(iOS)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }
}

/// A gold hairline between the parts of a page.
struct PageRule: View {
    var weight = 1.5
    var body: some View {
        Rectangle().fill(Theme.Paper.rule).frame(height: weight).accessibilityHidden(true)
    }
}

/// A square of cloth cut with pinking shears: a zigzag on all four sides.
struct PinkedSquare: Shape {
    var teeth = 9

    /// The corners of the zigzag, clockwise from the top left: a valley and a peak for every tooth on every side.
    static func points(in rect: CGRect, teeth: Int) -> [CGPoint] {
        let count = max(1, teeth)
        let stepX = rect.width / Double(count), stepY = rect.height / Double(count)
        let depth = min(stepX, stepY) / 2
        var points: [CGPoint] = []
        for i in 0..<count {
            points.append(CGPoint(x: rect.minX + Double(i) * stepX, y: rect.minY + depth))
            points.append(CGPoint(x: rect.minX + (Double(i) + 0.5) * stepX, y: rect.minY))
        }
        for i in 0..<count {
            points.append(CGPoint(x: rect.maxX - depth, y: rect.minY + Double(i) * stepY))
            points.append(CGPoint(x: rect.maxX, y: rect.minY + (Double(i) + 0.5) * stepY))
        }
        for i in 0..<count {
            points.append(CGPoint(x: rect.maxX - Double(i) * stepX, y: rect.maxY - depth))
            points.append(CGPoint(x: rect.maxX - (Double(i) + 0.5) * stepX, y: rect.maxY))
        }
        for i in 0..<count {
            points.append(CGPoint(x: rect.minX + depth, y: rect.maxY - Double(i) * stepY))
            points.append(CGPoint(x: rect.minX, y: rect.maxY - (Double(i) + 0.5) * stepY))
        }
        return points
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addLines(Self.points(in: rect, teeth: teeth))
        path.closeSubpath()
        return path
    }
}

/// One cloth the table can wear, as a pinked swatch to tap; the chosen one carries a tick.
struct FeltSwatch: View {
    let title: String
    let cloth: Settings.TableColours
    let chosen: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                PinkedSquare()
                    .fill(RadialGradient(colors: Theme.Field.cloth(cloth), center: .center, startRadius: 4, endRadius: 80))
                    .frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
                    .overlay {
                        if chosen { Image(systemName: "checkmark").font(.title.weight(.bold)).foregroundStyle(.ivory) }
                    }
                Text(title).font(.title3.weight(chosen ? .semibold : .regular))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}
