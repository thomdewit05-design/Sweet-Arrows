# Sweet Arrows: Candy Puzzle

Tap a candy and it shoots off in the direction of its arrow. A clear path sends it into the candy jar,
three alike pop, and a candy in the way makes it bounce back and costs a heart. Clear the board before
the jar fills up.

Native iOS (Swift 6, SwiftUI + SpriteKit, iOS 17+).

- Plan: [docs/PLAN.md](docs/PLAN.md) (Dutch)
- Status, rules as built and open questions: [docs/STATUS.md](docs/STATUS.md)
- Level report: [docs/level-report.md](docs/level-report.md)
- Rules for working on the code: [CLAUDE.md](CLAUDE.md)

## Getting started

```sh
brew install xcodegen swiftlint
xcodegen generate
open SweetArrows.xcodeproj
```

Set your team in `Config/Shared.xcconfig`, then run on a simulator or your iPhone.

## Rules, solver and levels (works on macOS and Linux)

```sh
swift test --package-path Packages/SweetArrowsCore          # game rules + solver
swift test --package-path Tools/LevelGen                    # generator
swift run --package-path Tools/LevelGen -c release levelgen         # regenerate all 300 levels + report
swift run --package-path Tools/LevelGen -c release levelgen verify  # re-check every shipped level
swift run --package-path Tools/LevelGen -c release levelgen show 42 # print a level as ASCII
```
