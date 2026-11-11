# Sweet Arrows — snoep-puzzelgame (iOS, Swift + SpriteKit)

## Doel
Hybrid-casual puzzelgame voor iPhone. Hoofdspel "Glijden & matchen": een getikt snoepje glijdt in de richting
van zijn pijl tot het ergens tegenaan botst; 3 of meer van dezelfde kleur op een rij ploppen. Er komen steeds
snoepjes bij; bord vol = af (SlideGame). De oude pijlpuzzels met levels zijn op verzoek van de eigenaar verwijderd.
Verdienmodel: alleen advertenties (rewarded, interstitials, banner). Geen in-app-aankopen (keuze van de eigenaar).
Zie docs/PLAN.md voor het volledige plan, inclusief "Onderscheid van concurrenten".
Zie docs/STATUS.md voor de stand per fase en gemaakte keuzes.

## Stack
Swift 6, SwiftUI, SpriteKit, iOS 17+, XcodeGen, Google Mobile Ads + UMP (SPM),
Firebase (Analytics, Crashlytics, Remote Config), GameKit, CloudKit, SwiftLint.

## Structuur
```
project.yml                 # XcodeGen; bewerk NOOIT het .xcodeproj zelf
Config/                     # xcconfig's; Secrets.xcconfig (echte ad-ID's) staat NIET in git
SweetArrows/
  App/                      # SweetArrowsApp.swift, AppModel (routing + services), Theme (kleuren, fonts)
  Game/                     # SpriteKit: SlideScene, SlideSession, CandyNode, CandyShapes, BoardPalette
  Features/                 # SwiftUI: Home, Play (spel + boosters), Shop, Settings, DailyReward
  Services/                 # AdService, ConsentService, PurchaseService, AnalyticsService,
                            # ConfigService, SaveService, AudioService, HapticsService,
                            # GameCenterService
  Resources/                # Assets.xcassets, Localizable.xcstrings, Fonts/, Sounds/, Music/
Packages/SweetArrowsCore/   # Swift Package: SlideGame (regels), meta (munten, boosters, voortgang, advertentieregels) (GEEN UIKit/SpriteKit)
Tools/Icon/                 # make_icon.py: tekent het app-icoon
Tools/Sounds/               # make_sounds.py + make_music.py: synthetiseren geluid en muziek
SweetArrowsTests/  SweetArrowsUITests/
docs/                       # PLAN.md, STATUS.md, licenses/, site/
```

## Regels
- Spelregels in SweetArrowsCore als pure Swift, getest met 90%+ dekking.
  Scenes en views bevatten geen spelregels.
- Afstand houden tot block-jam-games: geen sleepbediening, geen gekleurde deuren/uitgangen,
  geen vierkante blokken als hoofdvorm. Tikken, niet slepen; de snelheid van nieuwe snoepjes is de klok.
- Alle advertentie-aanroepen via AdService; frequentiegrenzen komen uit ConfigService
  (Remote Config) met lokale standaardwaarden.
- Geen advertenties voordat de toestemmingsflow (UMP, daarna ATT) is afgerond.
- Nooit een interstitial tijdens een potje of direct na een rewarded ad.
  Een banner mag onder het spelbord (keuze van de eigenaar), onder de boosterbalk, nooit over het bord.
- Alle tekst via Localizable.xcstrings, niets hardgecodeerd.
- Test-ad-unit-ID's in Debug; echte ID's alleen in Release via een xcconfig die niet in git staat.
- Na elke wijziging:
  `swift test --package-path Packages/SweetArrowsCore`,
  dan `xcodegen generate`, daarna
  `xcodebuild test -scheme SweetArrows -destination 'platform=iOS Simulator,name=iPhone 16'`
  moet slagen en SwiftLint mag geen fouten geven.
- Kleine commits met duidelijke berichten; werk per fase uit docs/PLAN.md.
- Doelen: 60 fps op iPhone 11, koude start < 3 s, download < 80 MB.
