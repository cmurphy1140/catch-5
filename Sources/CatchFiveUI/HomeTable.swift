import SwiftUI
import CatchFive

/// The opening page as one oak table (D159, D166): the title, Play below the rail and a labelled chat tab, the five held up over
/// the wood, her notebook, and the family picture at the bottom. Her links and her note have a page of their own, `GuestThings`. Drawn only when the build carries the pictures;
/// they stay out of the repository.
struct HomeTable: View {
    /// One thing on the table that can be picked up: its picture, the line under it, and what a tap does.
    struct Item: Identifiable {
        let art: String
        let title: String
        let hint: String
        let action: () -> Void
        var id: String { art }
    }

    let colours: Settings.TableColours
    /// The guest's name, when the build carries her things: she and the words beside her open their page (D159).
    var guest: String?
    var onGuest: () -> Void = {}
    let onPlay: () -> Void
    let onAsk: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Counts the deals, so each tap on Play starts the cards again; `dealing` holds the tap until they have landed.
    @State private var deal = 0
    @State private var dealing = false

    /// Play: the cards go round the blanket first (D179), then the play page opens.
    private func play() {
        guard !dealing else { return }
        guard !reduceMotion else { onPlay(); return }
        dealing = true; deal += 1
        Task {
            try? await Task.sleep(for: .seconds(HomeMotion.dealSeconds))
            dealing = false
            onPlay()
        }
    }

    /// The hero; without it, the older page is drawn.
    static var carried: Bool { SeatArt.named("GuestMenuHero") != nil }

    /// "Emma's things" and its arrow, as written on the wood.
    private func guestWords(_ guest: String) -> some View {
        HStack(spacing: 6) {
            Text("\(guest)'s things").font(.system(.headline, design: .serif))
            Image(systemName: "arrow.right").font(.subheadline.weight(.semibold)).accessibilityHidden(true)
        }
        .shadow(color: .black.opacity(0.45), radius: 1, y: 1).frame(minHeight: 24).contentShape(Rectangle())
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize { accessibleTable }
            else { illustratedTable }
        }
    }

    /// The same table in reading order when text is enlarged: every action stays reachable by scrolling.
    private var accessibleTable: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    HomeTitle(width: geometry.size.width - 40, guest: guest)
                        .padding(.top, 64).padding(.bottom, 12)
                    Button(action: play) {
                        Text(dealing ? "Dealing…" : "Play")
                            .font(.system(.title, design: .serif).weight(.bold))
                            .foregroundStyle(Theme.Paper.greenDeep)
                            .padding(.horizontal, 32).padding(.vertical, 12)
                            .frame(minHeight: 54)
                            .background(Color.ivory, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    HomeAskTab(action: onAsk)
                    if let guest {
                        Button(action: onGuest) { guestWords(guest).padding(.vertical, 10) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(guest)'s things").accessibilityHint("Her links and her note")
                    }
                    if let hero = SeatArt.named("GuestMenuHero") {
                        HomeHero(picture: hero, width: geometry.size.width - 32).accessibilityHidden(true)
                    }
                    if let picnic = SeatArt.named("GuestMenuPicnic") {
                        picnic.resizable().scaledToFit().accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 30)
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(.ivory)
            .background { HomeFelt(colours: .green) }
        }
    }

    private var illustratedTable: some View {
        GeometryReader { geometry in
            let width = geometry.size.width, height = geometry.size.height
            // A strip of green cloth behind the title, then the oak table from its edge down to the grass (D168).
            let edge = height * 0.185
            let table = TableEdge(top: edge)
            ZStack(alignment: .topLeading) {
                Group {
                    WoodGrainView().mask { table }
                    table.fill(.black.opacity(0.22))
                    // The rail's shadow on the wood just under it.
                    TableEdge(top: edge + 9, closed: false).stroke(.black.opacity(0.45), lineWidth: 12).blur(radius: 7).mask { table }
                    HomeGlow(width: width, height: height)
                }
                .accessibilityHidden(true)

                HomeTitle(width: width, guest: guest)
                    .frame(width: width).position(x: width / 2, y: height * 0.085)

                // Play keeps the ivory silhouette. General chat has its own labelled place on the rail.
                Button(action: play) {
                    Text(dealing ? "Dealing…" : "Play").font(.system(size: dealing ? 24 : 30, weight: .bold, design: .serif)).italic(dealing)
                        .foregroundStyle(Theme.Paper.greenDeep)
                        .frame(width: min(218, width * 0.56), height: 54)
                        .background(Color.ivory, in: Capsule())
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 3)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .position(x: width / 2, y: edge + 58)
                // Without the notebook's picture, the way to her things stays as words under Play.
                if let guest, SeatArt.named("GuestMenuBook") == nil {
                    Button(action: onGuest) { guestWords(guest) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(guest)'s things").accessibilityHint("Her links and her note")
                        .position(x: width / 2, y: edge + 102)
                }

                if let hero = SeatArt.named("GuestMenuHero") {
                    // A little wider than the screen, and centred between the words and the family picture's heads, so the
                    // oak between them is filled (D166).
                    let picnicTop = height + geometry.safeAreaInsets.bottom - width * 856 / 1837 * 0.88
                    Button(action: play) { HomeHero(picture: hero, width: width * 1.3) }
                        .buttonStyle(.plain).shadow(color: .black.opacity(0.4), radius: 5, y: 4)
                        .position(x: width / 2, y: (edge + 118 + picnicTop) / 2)
                        .accessibilityHidden(true) // a second way to Play (D133)
                }

                // The family picture (D162), when the build carries it: everyone on the blanket at the bottom, the water
                // behind them cut away so the oak runs down round them to the grass (D166).
                if let picnic = SeatArt.named("GuestMenuPicnic") {
                    let picnicHeight = width * 856 / 1837
                    picnic.resizable().scaledToFit().frame(width: width)
                        // A deck and a few dealt cards on the blanket, so they are plainly playing (D165).
                        .overlay(alignment: .topLeading) {
                            PicnicDeck(card: width * 0.05).position(x: width * 0.43, y: picnicHeight * 0.845)
                        }
                        .position(x: width / 2, y: height + geometry.safeAreaInsets.bottom - picnicHeight / 2)
                        .accessibilityHidden(true)
                    GrassBreeze(width: width, height: height + geometry.safeAreaInsets.bottom)
                    if deal > 0, dealing {
                        DealLayer(origin: CGPoint(x: 0, y: height + geometry.safeAreaInsets.bottom - picnicHeight),
                                  size: CGSize(width: width, height: picnicHeight))
                            .id(deal)
                    }
                }

                // On the oak just above the family, at the left: her open notebook with the way to her things written
                // under it (D176), or, in a build without her, the deck's box (D167).
                let picnicTop = height + geometry.safeAreaInsets.bottom - width * 856 / 1837 * 0.88
                if let guest, let book = SeatArt.named("GuestMenuBook") {
                    Button(action: onGuest) {
                        VStack(alignment: .leading, spacing: 2) {
                            book.resizable().scaledToFit().frame(width: width * 0.24)
                                .rotationEffect(.degrees(-9))
                                .shadow(color: .black.opacity(0.45), radius: 5, y: 4)
                            guestWords(guest)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(guest)'s things").accessibilityHint("Her links and her note")
                    .frame(width: width * 0.5, alignment: .leading)
                    .position(x: width * 0.29, y: picnicTop - width * 0.125)
                } else if let box = SeatArt.named("GuestMenuBox") {
                    box.resizable().scaledToFit().frame(width: width * 0.14)
                        .rotationEffect(.degrees(-14))
                        .shadow(color: .black.opacity(0.45), radius: 5, y: 4)
                        .position(x: width * 0.15, y: picnicTop - width * 0.21)
                        .accessibilityHidden(true)
                }

                RoomRail(top: edge)
                HomeAskTab(action: onAsk)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: min(210, width - 40), alignment: .trailing)
                    .position(x: width - 20 - min(210, width - 40) / 2, y: edge + 2)
            }
        }
        .foregroundStyle(.ivory)
        .background {
            ZStack {
                // The strip of cloth at the top (D168): always the green, quiet as on the other opening pages.
                HomeFelt(colours: .green)
            }
            .ignoresSafeArea().accessibilityHidden(true)
        }
    }
}

/// A smoked-amber label on the rail, with a solid walnut treatment when transparency is reduced.
private struct HomeAskTab: View {
    let action: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "bubble.left").font(.callout.weight(.semibold)).accessibilityHidden(true)
                Text("Ask anything").font(.system(.callout, design: .serif).weight(.semibold))
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.ivory)
            .padding(.horizontal, 14).padding(.vertical, 9).frame(minHeight: 44)
            .background {
                let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
                if reduceTransparency {
                    shape.fill(Color(red: 0.25, green: 0.15, blue: 0.09))
                } else {
                    shape.fill(.ultraThinMaterial)
                        .overlay { shape.fill(Color(red: 0.25, green: 0.15, blue: 0.09).opacity(0.88)) }
                }
            }
            .overlay(alignment: .top) {
                Capsule().fill(Color(red: 0.82, green: 0.69, blue: 0.43).opacity(0.6))
                    .frame(height: 1).padding(.horizontal, 12).padding(.top, 1)
            }
            .shadow(color: .black.opacity(0.28), radius: 3, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ask anything").accessibilityHint("Opens a conversation with the game's helper")
    }
}

/// The guest's own page (D159): her links as things left on the felt, and her note as a place card. It slides over
/// the opening page; the arrow puts it away.
struct GuestThings: View {
    let name: String
    let colours: Settings.TableColours
    let items: [HomeTable.Item]
    /// Opens her note, when the build carries one.
    var onNote: (() -> Void)?
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                Text("\(name)'s things").font(.system(size: 36, weight: .bold, design: .serif))
                    .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1.5).accessibilityAddTraits(.isHeader)
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button(action: item.action) {
                        HStack(spacing: 18) {
                            if index % 2 == 1 { Spacer(minLength: 0) }
                            if let art = SeatArt.named(item.art) {
                                art.resizable().scaledToFit().frame(width: 132, height: 96).shadow(color: .black.opacity(0.4), radius: 4, y: 3)
                            }
                            Text(item.title).font(.system(.title3, design: .serif).weight(.semibold)).multilineTextAlignment(.leading)
                                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                            if index % 2 == 0 { Spacer(minLength: 0) }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityLabel(item.title).accessibilityHint(item.hint)
                }
                if let onNote {
                    VStack(spacing: 6) {
                        GuestPlaceCard(name: name, action: onNote)
                        Text("A note for you").font(.system(.subheadline, design: .serif)).italic().opacity(0.85)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(.horizontal, 28).padding(.top, 64).padding(.bottom, 30).frame(maxWidth: 480).frame(maxWidth: .infinity)
        }
        .overlay(alignment: .topLeading) {
            Button(action: onClose) {
                Image(systemName: "arrow.left").font(.system(size: 28, weight: .semibold))
                    .frame(width: Theme.Table.statusButtonHitSize, height: Theme.Table.statusButtonHitSize).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel("Back").keyboardShortcut(.cancelAction)
            .padding(.leading, 12).padding(.top, 4)
        }
        .foregroundStyle(.ivory)
        .background {
            HomeFelt(colours: colours)
        }
    }
}

/// The opening pages' cloth: the table's, under a lower lamp, so it is quieter (D159).
struct HomeFelt: View {
    let colours: Settings.TableColours

    var body: some View {
        ZStack {
            Rectangle().fill(RadialGradient(colors: Theme.Field.cloth(colours), center: .init(x: 0.5, y: 0.45), startRadius: 20, endRadius: 620)).saturation(0.7)
            ClothNap().equatable().opacity(0.24)
                .mask {
                    GeometryReader { geometry in
                        RadialGradient(stops: [.init(color: .clear, location: 0),
                                               .init(color: .black.opacity(0.12), location: 0.55),
                                               .init(color: .black, location: 1)],
                                       center: .init(x: 0.5, y: 0.35), startRadius: 0,
                                       endRadius: max(geometry.size.width, geometry.size.height) * 0.6)
                    }
                }
            Color.black.opacity(0.24)
        }
        .ignoresSafeArea().accessibilityHidden(true)
    }
}

/// The scorekeeper, the man crouched beside her with his pencil on her right-hand page, and the dog on his other side
/// (D161), as one picture `width` wide standing on its bottom edge. It left the opening page for the play page (D162).
struct HomeScene: View {
    let width: Double

    /// A build carries the scene when it has both people; the dog is optional.
    static var carried: Bool { SeatArt.named("GuestMenuScribe") != nil && SeatArt.named("GuestMenuHelper") != nil }
    static func height(width: Double) -> Double { width * 0.54 }

    var body: some View {
        let base = Self.height(width: width)
        let scribeWidth = width * 0.371, scribeHeight = scribeWidth * 203 / 212
        let helperWidth = width * 0.43, helperHeight = helperWidth * 1.05
        // His pencil's tip is at his picture's left edge, 42% of the way down.
        let tip = CGPoint(x: scribeWidth * 0.83, y: base - scribeHeight * 0.76)
        let centre = CGPoint(x: tip.x - helperWidth * 0.03 + helperWidth / 2, y: tip.y + helperHeight * 0.42 - helperHeight / 2)
        ZStack(alignment: .topLeading) {
            if let scribe = SeatArt.named("GuestMenuScribe") {
                scribe.resizable().scaledToFit().frame(width: scribeWidth).shadow(color: .black.opacity(0.4), radius: 5, y: 3)
                    .position(x: scribeWidth / 2, y: base - scribeHeight / 2)
            }
            if let dog = SeatArt.named("GuestMenuDog") {
                let dogWidth = width * 0.27
                dog.resizable().scaledToFit().frame(width: dogWidth).shadow(color: .black.opacity(0.4), radius: 5, y: 3)
                    .position(x: width - dogWidth * 0.52, y: base - dogWidth * 163 / 165 / 2)
            }
            if let helper = SeatArt.named("GuestMenuHelper") {
                Ellipse().fill(.black.opacity(0.32)).frame(width: helperWidth * 0.72, height: 14).blur(radius: 6)
                    .position(x: centre.x + helperWidth * 0.10, y: centre.y + helperHeight / 2 - 2)
                helper.resizable().scaledToFit().frame(width: helperWidth, height: helperHeight, alignment: .bottom)
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                    .position(centre)
            }
        }
        .frame(width: width, height: base).accessibilityHidden(true)
    }
}

/// A small deck lying on the picnic blanket with three cards dealt beside it (D165), drawn flat and then laid down.
/// `card` is a card's width before it is laid down.
struct PicnicDeck: View {
    let card: Double

    private func back(_ tilt: Double) -> some View {
        RoundedRectangle(cornerRadius: card * 0.14, style: .continuous).fill(Color(red: 0.95, green: 0.90, blue: 0.78))
            .overlay(RoundedRectangle(cornerRadius: card * 0.08, style: .continuous).fill(Color(red: 0.55, green: 0.13, blue: 0.13)).padding(card * 0.1))
            .frame(width: card, height: card * 1.4).rotationEffect(.degrees(tilt))
    }

    var body: some View {
        ZStack {
            // The dealt cards, fanned to the right of the deck; the last one face up.
            back(34).offset(x: card * 1.5, y: card * 0.1)
            back(58).offset(x: card * 2.2, y: card * 0.5)
            RoundedRectangle(cornerRadius: card * 0.14, style: .continuous).fill(Color(red: 0.97, green: 0.94, blue: 0.86))
                .overlay(Image(systemName: "suit.heart.fill").font(.system(size: card * 0.5)).foregroundStyle(Color(red: 0.70, green: 0.15, blue: 0.15)))
                .frame(width: card, height: card * 1.4).rotationEffect(.degrees(-20)).offset(x: card * 3.1, y: card * 0.2)
            // The deck: the same back five times, each a little higher, with the edge showing as its thickness.
            ForEach(0..<5, id: \.self) { layer in
                back(-14).offset(y: -Double(layer) * card * 0.07)
                    .shadow(color: .black.opacity(layer == 0 ? 0.35 : 0), radius: 2, y: 2)
            }
        }
        .scaleEffect(x: 1, y: 0.56)
        .accessibilityHidden(true)
    }
}
