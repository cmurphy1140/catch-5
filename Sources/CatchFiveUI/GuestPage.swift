import SwiftUI

/// The looks the guest can wear at her own seat (D177): the git-ignored image assets `GuestLook1`, `GuestLook2` and on,
/// counted until the first one that is missing, so a new look is one more picture in the build. Her choice is kept by
/// name, so adding a look never moves it.
enum GuestLook {
    static let key = "guestLook"

    /// The run of look names a build carries, given a way to ask whether a picture exists.
    nonisolated static func names(limit: Int = 60, carried: (String) -> Bool) -> [String] {
        var found: [String] = []
        for number in 1...max(1, limit) {
            let name = "GuestLook\(number)"
            guard carried(name) else { break }
            found.append(name)
        }
        return found
    }

    /// The look to wear: the saved one while the build still carries it, else none, which is the figure she came in.
    nonisolated static func worn(saved: String?, among names: [String]) -> String? {
        saved.flatMap { names.contains($0) ? $0 : nil }
    }

    static var all: [String] { names { SeatArt.named($0) != nil } }

    /// The chosen look's picture, for her seat at the table.
    static var chosen: Image? {
        UserDefaults.standard.string(forKey: key).flatMap { $0.hasPrefix("GuestLook") ? SeatArt.named($0) : nil }
    }
}

/// The guest's own page (D177), in place of `GuestThings`: her dog runs up through the snow (D182), two swans glide in and meet, she rises under them, her name
/// writes itself, and then her things and her looks are laid out below. Her letter can be opened throughout.
/// With Reduce Motion the snowy-nose still waits for Back, and the swans and portrait are already in place.
struct GuestPage: View {
    let name: String
    let colours: Settings.TableColours
    let items: [HomeTable.Item]
    /// Opens her note, when the build carries one.
    var onNote: (() -> Void)?
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(GuestLook.key) private var savedLook = ""
    /// How far the opening has got: the swans, her, her name, then everything else.
    @State private var beat = UserDefaults.standard.bool(forKey: GuestDogRun.seenKey) ? GuestPage.last : 0
    @State private var breathing = false
    /// Her dog's run through the snow, played once before the swans (D182), when the build carries its pictures.
    @State private var dogRun = GuestDogRun.carried
    /// It plays by itself the first time only; after that the paw print beside her calls the dog.
    @State private var running = !UserDefaults.standard.bool(forKey: GuestDogRun.seenKey)
    private let looks = GuestLook.all

    private static let last = 4
    private var worn: String? { GuestLook.worn(saved: savedLook.isEmpty ? nil : savedLook, among: looks) }

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                stage
                // Her letter stays available without waiting for the entrance to finish.
                if let onNote {
                    GuestMailboxButton(name: name, showsPortrait: false, ink: .ivory, action: onNote)
                }
                Group {
                    things
                    if !looks.isEmpty { wardrobe }
                }
                .opacity(beat >= Self.last ? 1 : 0).offset(y: beat >= Self.last ? 0 : 14)
                .allowsHitTesting(beat >= Self.last).accessibilityHidden(beat < Self.last)
            }
            .padding(.horizontal, 28).padding(.top, 54).padding(.bottom, 30).frame(maxWidth: 480).frame(maxWidth: .infinity)
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
        .background { HomeFelt(colours: colours) }
        .overlay {
            if running, let dogRun { dogScene(dogRun).transition(.opacity) }
        }
        // Changing presentation or leaving the page cancels its wait. A replay never owns a stray timer.
        .task(id: running ? (reduceMotion ? 2 : 1) : 0) { await present() }
        .onChange(of: beat) { _, now in
            if now == Self.last, !reduceMotion { withAnimation(Theme.Motion.pulse) { breathing = true } }
        }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced { breathing = false; beat = Self.last }
        }
    }

    /// The still has an explicit way back; the letter can be opened even during the first run.
    private func dogScene(_ frames: GuestDogRun.Frames) -> some View {
        VStack(spacing: 12) {
            HStack {
                Button("Back", systemImage: "arrow.left", action: dismissDog)
                    .font(.body.weight(.semibold)).frame(minWidth: 44, minHeight: 44)
                    .keyboardShortcut(.cancelAction)
                Spacer()
            }
            .padding(.horizontal, 16)
            GuestDogRun(frames: frames).frame(maxWidth: .infinity, maxHeight: .infinity)
            if let onNote {
                Button {
                    dismissDog()
                    beat = Self.last
                    onNote()
                } label: {
                    Text("For \(name)").font(.system(.title3, design: .serif).weight(.semibold))
                        .padding(.horizontal, 24).frame(minHeight: 48).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityHint("Opens your letter")
                .padding(.bottom, 12)
            }
        }
        .foregroundStyle(Color.ivory).buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { HomeFelt(colours: colours) }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, dismissDog)
        .onAppear { UserDefaults.standard.set(true, forKey: GuestDogRun.seenKey) }
    }

    private func present() async {
        guard running else { await open(); return }
        guard let dogRun else { running = false; return }
        // A still is kept until Back or the letter is chosen, rather than timing out while it is being explored.
        guard !reduceMotion else { beat = Self.last; return }
        do { try await Task.sleep(for: .seconds(dogRun.duration)) } catch { return }
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.6)) { running = false }
    }

    /// The swans' opening stops when the page leaves or a tap has already skipped ahead.
    private func open() async {
        guard !reduceMotion else { beat = Self.last; return }
        guard beat < Self.last else { return }
        let beats: [(wait: Duration, motion: Animation)] = [
            (.milliseconds(150), .spring(duration: 0.9, bounce: 0.15)),
            (.milliseconds(550), .spring(duration: 0.7, bounce: 0.3)),
            (.milliseconds(500), .easeOut(duration: 0.9)),
            (.milliseconds(700), Theme.Motion.overlay),
        ]
        for (index, step) in beats.enumerated() {
            do { try await Task.sleep(for: step.wait) } catch { return }
            guard !Task.isCancelled, beat == index else { return }
            withAnimation(step.motion) { beat = index + 1 }
        }
    }

    private func dismissDog() {
        withAnimation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.overlay) { running = false }
    }

    private func callDog() {
        guard dogRun != nil else { return }
        withAnimation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.overlay) { running = true }
    }

    private var callDogButton: some View {
        Button(action: callDog) {
            Image(systemName: "pawprint.fill").font(.system(size: 24)).rotationEffect(.degrees(18))
                .opacity(0.8).shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                .frame(width: 48, height: 48).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel("Call the dog")
        .accessibilityHint("Shows the dog in the snow")
    }

    /// The swans, her, and her name: the part that moves.
    private var stage: some View {
        VStack(spacing: -4) {
            HStack(spacing: 0) {
                ForEach([false, true], id: \.self) { mirrored in
                    SwanView().frame(width: 112, height: 86).scaleEffect(x: mirrored ? -1 : 1)
                        .offset(x: beat >= 1 ? 0 : (mirrored ? 170 : -170)).opacity(beat >= 1 ? 1 : 0)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
            if let figure = worn.flatMap(SeatArt.named) ?? SeatArt.named("Guest") ?? SeatArt.named("GuestSeat0") {
                figure.resizable().scaledToFit().frame(height: 220)
                    .shadow(color: .black.opacity(0.4), radius: 5, y: 4)
                    .scaleEffect(breathing ? 1.012 : 1, anchor: .bottom)
                    .id(worn ?? "came").transition(.scale(scale: 0.9, anchor: .bottom).combined(with: .opacity))
                    .offset(y: beat >= 2 ? 0 : 70).opacity(beat >= 2 ? 1 : 0)
                    // Her dog comes in last and lies down beside her (D178), when the build carries its pieces.
                    .overlay(alignment: .bottomTrailing) {
                        if beat >= Self.last, let dog = GuestDogFigure.Parts.carried {
                            if dogRun != nil {
                                Button(action: callDog) {
                                    GuestDogFigure(parts: dog, pose: GuestDogMotion.rest, width: 150).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).accessibilityLabel("Call the dog")
                                .accessibilityHint("Shows the dog in the snow")
                                .offset(x: 46, y: 8)
                            } else {
                                GuestDog(parts: dog, width: 150, distance: 260).offset(x: 46, y: 8)
                            }
                        } else if beat >= Self.last, dogRun != nil {
                            callDogButton.offset(x: 56, y: 6).transition(.opacity)
                        }
                    }
            } else if beat >= Self.last, dogRun != nil {
                callDogButton
            }
            Text(name).font(.custom("SnellRoundhand-Black", fixedSize: 56)).lineLimit(1).minimumScaleFactor(0.5)
                .shadow(color: .black.opacity(0.45), radius: 1.5, y: 1.5)
                .padding(.horizontal, 10)
                // Written from left to right, as a pen would.
                .mask { Rectangle().scaleEffect(x: beat >= 3 ? 1 : 0, anchor: .leading) }
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { if beat < Self.last { withAnimation(Theme.Motion.overlay) { beat = Self.last } } }
    }

    /// Her links, as things left on the felt.
    private var things: some View {
        VStack(spacing: 26) {
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
        }
    }

    /// Her looks in a row: the one she came in, then each the build carries. The one she wears stands a little taller
    /// with a stroke under it; nothing is boxed.
    private var wardrobe: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your look").font(.system(.title3, design: .serif).weight(.semibold))
                .shadow(color: .black.opacity(0.4), radius: 1, y: 1).accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 16) {
                    look(nil, label: "As you came")
                    ForEach(Array(looks.enumerated()), id: \.element) { index, name in look(name, label: "Look \(index + 1)") }
                }
                .padding(.vertical, 6)
            }
            .padding(.horizontal, -28) // the row runs to both edges of the screen
            .contentMargins(.horizontal, 28, for: .scrollContent)
        }
    }

    private func look(_ look: String?, label: String) -> some View {
        let isWorn = look == worn
        return Button {
            withAnimation(reduceMotion ? Theme.Motion.reduced : .spring(duration: 0.4, bounce: 0.35)) { savedLook = look ?? "" }
        } label: {
            VStack(spacing: 6) {
                if let picture = SeatArt.named(look ?? "GuestSeat0") ?? SeatArt.named("Guest") {
                    picture.resizable().scaledToFit().frame(width: 96, height: 104, alignment: .bottom)
                        .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
                }
                Capsule().fill(.ivory.opacity(isWorn ? 0.9 : 0)).frame(width: 36, height: 2)
            }
            .scaleEffect(isWorn ? 1 : 0.86, anchor: .bottom).opacity(isWorn ? 1 : 0.7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label).accessibilityAddTraits(isWorn ? .isSelected : [])
    }
}

extension GuestDogFigure.Parts {
    /// The dog's pieces, when the build carries every one: the git-ignored pictures `GuestDogBody`, `GuestDogHead`,
    /// `GuestDogTail`, the four `GuestDogLeg…`, `GuestDogLying` and `GuestDogLyingTail`.
    static var carried: GuestDogFigure.Parts? {
        let legs = ["FrontNear", "FrontFar", "BackNear", "BackFar"].compactMap { SeatArt.named("GuestDogLeg\($0)") }
        guard legs.count == 4, let body = SeatArt.named("GuestDogBody"), let head = SeatArt.named("GuestDogHead"),
              let tail = SeatArt.named("GuestDogTail"), let lying = SeatArt.named("GuestDogLying"),
              let lyingTail = SeatArt.named("GuestDogLyingTail") else { return nil }
        return GuestDogFigure.Parts(body: body, head: head, tail: tail, legs: legs, lying: lying, lyingTail: lyingTail)
    }
}
