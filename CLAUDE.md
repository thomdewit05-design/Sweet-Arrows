# Sweet Arrows — snoep-puzzelgame (iOS, Swift + SpriteKit)

## Doel
Hybrid-casual puzzelgame voor iPhone. Snoepjes met pijlen schieten bij een tik in hun richting weg;
vrije snoepjes gaan naar de snoepbak (5 vakjes), 3 dezelfde ploppen. Bord leeg = level klaar.
Verdienmodel: rewarded ads + interstitials + Remove Ads + VIP-abonnement.
Zie docs/PLAN.md voor het volledige plan, inclusief "Onderscheid van concurrenten".
Zie docs/STATUS.md voor de stand per fase en gemaakte keuzes.

## Stack
Swift 6, SwiftUI, SpriteKit, iOS 17+, XcodeGen, Google Mobile Ads + UMP (SPM), StoreKit 2,
Firebase (Analytics, Crashlytics, Remote Config), GameKit, CloudKit, SwiftLint.

## Structuur
```
project.yml                 # XcodeGen; bewerk NOOIT het .xcodeproj zelf
Config/                     # xcconfig's; Secrets.xcconfig (echte ad-ID's) staat NIET in git
SweetArrows/
  App/                      # SweetArrowsApp.swift, AppModel (routing + services), Theme (kleuren, fonts)
  Game/                     # SpriteKit: GameScene, CandyNode, BagNode, CandyShapes, GameSession
  Features/                 # SwiftUI: Home, Map, Level, Shop, Settings, DailyReward
  Services/                 # AdService, ConsentService, PurchaseService, AnalyticsService,
                            # ConfigService, SaveService, AudioService, HapticsService,
                            # GameCenterService, LevelLibrary
  Resources/                # Assets.xcassets, Localizable.xcstrings, Fonts/, levels/
Packages/SweetArrowsCore/   # Swift Package: level-model, regels, snoepbak, solver (GEEN UIKit/SpriteKit)
Tools/LevelGen/             # CLI: swift run levelgen (generator + solver)
Tools/Sounds/               # make_sounds.py + make_music.py: synthetiseren geluid en muziek
SweetArrowsTests/  SweetArrowsUITests/
docs/                       # PLAN.md, STATUS.md, level-report.md, licenses/
```

## Regels
- Spelregels en solver in SweetArrowsCore als pure Swift, getest met 90%+ dekking.
  Scenes en views bevatten geen spelregels.
- Afstand houden tot block-jam-games: geen sleepbediening, geen gekleurde deuren/uitgangen,
  geen tijdslimiet, geen vierkante blokken als hoofdvorm.
- Alle advertentie-aanroepen via AdService; frequentiegrenzen komen uit ConfigService
  (Remote Config) met lokale standaardwaarden.
- Geen advertenties voordat de toestemmingsflow (UMP, daarna ATT) is afgerond.
- Nooit een interstitial tijdens een level of direct na een rewarded ad.
- Alle tekst via Localizable.xcstrings, niets hardgecodeerd.
- Test-ad-unit-ID's in Debug; echte ID's alleen in Release via een xcconfig die niet in git staat.
- Levels: nooit met de hand JSON aanpassen. Wijzig de generator of `HandmadeLevels.swift` en draai
  `swift run --package-path Tools/LevelGen -c release levelgen`; `levelgen verify` moet slagen.
- Na elke wijziging:
  `swift test --package-path Packages/SweetArrowsCore` en `swift test --package-path Tools/LevelGen`,
  dan `xcodegen generate`, daarna
  `xcodebuild test -scheme SweetArrows -destination 'platform=iOS Simulator,name=iPhone 16'`
  moet slagen en SwiftLint mag geen fouten geven.
- Kleine commits met duidelijke berichten; werk per fase uit docs/PLAN.md.
- Doelen: 60 fps op iPhone 11, koude start < 3 s, download < 80 MB.
