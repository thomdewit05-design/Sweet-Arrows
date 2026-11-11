import SwiftUI
import SweetArrowsCore

/// The candy worlds, 20 levels each.
struct MapView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let progress = model.save.progress
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(1...World.count, id: \.self) { id in
                        WorldCard(world: World(id: id), progress: progress, levelCount: model.levels.count) { level in
                            model.path.append(.level(level))
                        }
                        .id(id)
                    }
                }
                .padding()
            }
            .onAppear { proxy.scrollTo(World.number(forLevel: progress.nextLevel), anchor: .center) }
        }
        .background(Theme.cream.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if model.ads.canShowBanner {
                BannerAdView(adUnitID: model.ads.bannerAdUnitID)
            }
        }
        .navigationTitle(Text("Map"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WorldCard: View {
    let world: World
    let progress: PlayerProgress
    let levelCount: Int
    let open: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(world.displayName)
                    .font(Theme.heading())
                    .foregroundStyle(.white)
                Spacer()
                if !world.newElements.isEmpty {
                    Text(world.newElements.map(\.localizedName).joined(separator: " · "))
                        .font(Theme.body(13))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.3)))
                        .foregroundStyle(.white)
                }
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(world.levels).filter { $0 <= levelCount }, id: \.self) { level in
                    LevelBubble(
                        level: level,
                        unlocked: progress.isUnlocked(level),
                        stars: progress.stars[level] ?? 0,
                        isNext: level == progress.nextLevel
                    ) { open(level) }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 24).fill(world.tint.gradient))
    }
}

private struct LevelBubble: View {
    let level: Int
    let unlocked: Bool
    let stars: Int
    let isNext: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(level)")
                    .font(Theme.heading(18))
                    .foregroundStyle(unlocked ? Theme.ink : Theme.inkSoft.opacity(0.6))
                HStack(spacing: 1) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: index < stars ? "star.fill" : "star")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(index < stars ? Theme.gold : Theme.inkSoft.opacity(0.4))
                    }
                }
                .opacity(unlocked ? 1 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                Circle()
                    .fill(unlocked ? Color.white : Color.white.opacity(0.45))
                    .overlay(Circle().stroke(Theme.gold, lineWidth: isNext ? 4 : 0))
            )
            .overlay {
                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSoft)
                        .offset(y: 16)
                }
            }
        }
        .disabled(!unlocked)
        .accessibilityLabel(Text("Level \(level)"))
    }
}

extension World {
    var displayName: String {
        switch theme {
        case .gummyGarden: String(localized: "Gummy Garden")
        case .lollipopLane: String(localized: "Lollipop Lane")
        case .chocolateFalls: String(localized: "Chocolate Falls")
        case .marshmallowMountains: String(localized: "Marshmallow Mountains")
        case .caramelCanyon: String(localized: "Caramel Canyon")
        case .cottonCandyClouds: String(localized: "Cotton Candy Clouds")
        case .licoriceLab: String(localized: "Licorice Lab")
        case .iceCreamIsland: String(localized: "Ice Cream Island")
        }
    }

    var tint: Color {
        switch theme {
        case .gummyGarden: Color(hex: 0x3DDC97)
        case .lollipopLane: Color(hex: 0xFF5C8A)
        case .chocolateFalls: Color(hex: 0x9C6644)
        case .marshmallowMountains: Color(hex: 0xC9A7FF)
        case .caramelCanyon: Color(hex: 0xFF9F1C)
        case .cottonCandyClouds: Color(hex: 0x7FC8F8)
        case .licoriceLab: Color(hex: 0x5B4B6B)
        case .iceCreamIsland: Color(hex: 0x5B6CFF)
        }
    }
}

extension BoardElement {
    var localizedName: String {
        switch self {
        case .pole: String(localized: "Lollipop poles")
        case .chocolateBar: String(localized: "Chocolate bars")
        case .wrapped: String(localized: "Wrapped sweets")
        case .caramel: String(localized: "Caramel")
        case .iced: String(localized: "Ice cubes")
        case .rotating: String(localized: "Spinners")
        case .mirror: String(localized: "Bumpers")
        case .lock: String(localized: "Locks & keys")
        case .bomb: String(localized: "Bombs")
        case .colorChanger: String(localized: "Color changers")
        }
    }
}

#Preview {
    NavigationStack { MapView() }
        .environment(AppModel.preview())
}
