# Status & keuzes

Stand van de bouw per fase uit [PLAN.md](PLAN.md), plus de keuzes die tijdens het bouwen gemaakt zijn.

## Fasen

| Fase | Stand |
|---|---|
| 1. Fundament | ✅ CI groen (Linux + iOS-simulator op Xcode 26). XcodeGen-project, SwiftUI-navigatie (home, kaart, level, winkel, instellingen), thema + Fredoka, services met protocollen, NL/EN String Catalog, SwiftLint, GitHub Actions (Linux: regels/solver/levels, macOS: iOS-build + tests). Google Mobile Ads, UMP en Firebase zijn als packages gekoppeld. |
| 2. Kernmechaniek | ✅ Regels in `SweetArrowsCore` (pure Swift, getest), SpriteKit-bord met snoepbak, hartjes, tikbediening, ongedaan maken, 10 handgemaakte tutoriallevels. Basale animaties (wegschieten, boog naar de pot, stuiteren, plop) zodat je kunt zien wat er gebeurt. |
| 3. Generator + solver | ✅ `swift run levelgen`: 300 levels, allemaal door de solver goedgekeurd, rapport in [level-report.md](level-report.md). CI controleert elk level opnieuw. |
| 4. Game feel | 🚧 Gebouwd, nog te testen op een iPhone: gummy-wiebel bij elke tik, ease-out-slide (150–250 ms) en boog naar de pot, pot toont de drie dezelfde en plopt ze met een suikerwolkje in hun kleur, oplopende xylofoontonen per plop op rij, zachte bonk bij een botsing, Core Haptics (met UIKit-terugval), confetti + sterren één voor één + munten die naar de teller vliegen, waarschuwing bij nog één vrij vakje, tutorial levels 1–3 met Jelly en een wijzende hand (de hand wijst altijd een veilige zet aan, via de solver). Snoepjes en pijlen worden als gecachete texturen getekend voor 60 fps; in Debug staan FPS en aantal nodes in beeld. Geluiden en de achtergrondmuziek (ukulele-lounge-loop van 42 s, laag volume, los uit te zetten) zijn zelf gesynthetiseerd (`Tools/Sounds`). Nog niet: echte artwork, meting met Instruments op een iPhone 11. |
| 5. Meta-laag | 🚧 Gebouwd, nog te testen op een iPhone: munten (10 per level + sterrenbonus + win-streak-bonus vanaf 3 op rij), boosters (hint 60, snoepje weg 90, extra vakje 120 munten — of met een advertentie), dagbeloning met 7-dagenreeks (verdubbelen met een advertentie), dagpuzzel (365 door de solver goedgekeurde puzzels, dezelfde voor iedereen, met reeks en deelbare uitslag), winkel met boosters en cosmetica (4 toonbanken, 3 snoepstijlen), introkaart per nieuw wereldelement, voortgang met iCloud-sync, Game Center (prestaties + ranglijst dagpuzzel). Winkel, dagbeloning en dagpuzzel verschijnen pas na level 5. Alles werkt offline. |
| 6. Toestemming & advertenties | 🚧 Gebouwd: Google UMP bij eerste start (pas daarna laden advertenties), ATT na level 3 met eigen voorscherm, AdMob met rewarded, interstitial, banner (kaart + winkel, nooit tijdens het spelen) en app-open. Alle regels in `AdPolicy` (kern, getest): interstitial vanaf level 8, max 1 per 2 levels, ≥ 90 s ertussen, nooit na verlies of vlak na een rewarded; rewarded max 20/dag; geen advertenties vóór level 3; app-open pas na 4 uur weg vanaf dag 2 en standaard uit. Test-ID's in Debug. |
| 7. Aankopen, analytics, Remote Config | 🚧 Gebouwd: StoreKit 2 met Remove Ads, VIP (week/maand, 3 dagen gratis, via `SubscriptionStoreView`), 4 muntenpakketten, starterspakket (vanaf level 15, eenmalig), Aankopen herstellen; StoreKit-configuratiebestand voor lokaal testen; alle analytics-events; Crashlytics (dSYM-upload in Release); Remote Config met de sleutels uit het plan (incl. `level_overrides`); debugmenu in Instellingen (alleen Debug). |
| 8. Afwerking & release | 🚧 Gebouwd: 6 extra talen (de, fr, es, pt-BR, tr, id) voor alle teksten, Dynamic Type in menu's (Fredoka schaalt mee), instellingen (geluid, muziek, trillen, kleurenblind, privacy), privacybeleid/voorwaarden/contact in de app, website + `app-ads.txt` (`docs/site`, GitHub Pages), launch screen met icoon, reviewvraag na een gewonnen moeilijk level, TestFlight-upload via GitHub Actions (`.github/workflows/testflight.yml`), screenshots van de hoofdschermen in de UI-tests. iPhone-only; op iPad draait de app in iPhone-modus. |

## Zo test je het op je iPhone

1. Op je Mac: `brew install xcodegen swiftlint`
2. In de repo: `xcodegen generate && open SweetArrows.xcodeproj`
3. Zet in `Config/Shared.xcconfig` je eigen `DEVELOPMENT_TEAM` (zelfde account als Skipilot) en eventueel
   je eigen bundle-id, kies je iPhone als doel en druk op Run.
4. In Debug geven de "advertentie"-knoppen (extra vakje, 3 hartjes, hint) direct de beloning, zodat je
   die flows kunt testen. In Release staan ze uit tot fase 6.

## Spelregels zoals gebouwd

Waar het plan ruimte liet, is dit gekozen (alles staat in `Packages/SweetArrowsCore`):

- **Botsen of vliegen is alles-of-niets.** Een snoepje vliegt alleen als de hele lijn tot de rand vrij is;
  anders stuitert het terug naar zijn plek en kost het een hartje. Elk level heeft 3 hartjes.
- **Een botsing is geen zet**: draaisnoepjes draaien niet en ongedaan maken slaat hem over.
- **Snoepbak**: snoepjes landen naast dezelfde kleur; bij 3 dezelfde ploppen ze. Zijn alle vakjes bezet
  zonder plop, dan is het level verloren (tenzij het bord op dat moment leeg is: dan win je).
- **Ongedaan maken** zet bord en pot terug, maar geeft geen hartjes terug. Na een volle pot kun je met
  ongedaan maken verder. **Altijd gratis** (keuze van de eigenaar): geen munten, geen advertentie.
- **Snoepje weg** (booster) haalt een snoepje van het bord zonder dat het in de pot gaat en wist de
  ongedaan-maken-geschiedenis, zodat je de booster niet per ongeluk terugdraait.
- **Tutorial (1–10) is niet te verliezen**: botsingen kosten geen hartje en de pot is altijd groot genoeg
  (2 kleuren bij 5 vakjes; 3 kleuren bij 7 vakjes in level 9–10). De solver controleert dat er geen enkele
  verliezende zet is.
- **Sterren**: 3 zonder botsing, 2 na één botsing, anders 1.

### Speciale elementen per wereld

De 300 levels zijn verdeeld over **8 werelden** (38, 38, 38, 38, 37, 37, 37, 37 levels). Het plan noemt
zes elementen; ze zijn thematisch verdeeld, elke wereld introduceert er één en houdt de eerdere:

| Wereld | Nieuw element | Regel |
|---|---|---|
| 1. Gummy Garden | – | basis |
| 2. Lollipop Lane | lolly-paal | vast obstakel, snoepjes moeten eromheen |
| 3. Chocolate Falls | chocoladereep | 2 vakjes lang, gaat als één snoepje in de pot |
| 4. Marshmallow Mountains | verpakt snoepje | kleur verborgen tot de weg vrij is |
| 5. Caramel Canyon | karamel | eerste tik (met vrije weg) kraakt de karamel, tweede tik vliegt |
| 6. Cotton Candy Clouds | ijsblokje | bevroren tot een buurman het bord verlaat; tikken doet niets en kost niets |
| 7. Licorice Lab | draaisnoepje | pijl draait een kwartslag met de klok mee na elke geslaagde zet |
| 8. Ice Cream Island | – | alles door elkaar |

Nieuwe levels na v1 (elke 2 weken 50) komen voorlopig achter in wereld 8, tot er nieuwe werelden zijn.

## Levels: hoe de generator werkt

- De generator bouwt levels **achterstevoren**: hij plaatst snoepjes in omgekeerde volgorde, telkens zo
  dat het nieuwe snoepje een vrije weg heeft langs de snoepjes die er al liggen. Omgedraaid is dat een
  winnende volgorde. Daarna worden kleuren zo verdeeld dat de pot langs die volgorde nooit vol raakt.
- De **solver** (in `SweetArrowsCore`, ook gebruikt voor de hint-knop) zoekt met geheugen over alle
  standen (twee 64-bit maskers) en bewijst dat het level te winnen is zonder botsing en zonder volle pot.
  Hij telt de **valkuilzetten** langs de oplossing (toegestane zetten die het level onwinbaar maken) en
  het aantal oplossingen (afgekapt op 10.000).
- **Moeilijkheid (0–100)** = bordgrootte + aantal kleuren + valkuilen per zet + hoe vol de pot wordt +
  speciale elementen. De curve: 4 makkelijk, 1 middel, 1 moeilijk ("Hard level"), langzaam oplopend.
- Elk level is reproduceerbaar uit de seed. Levels nooit met de hand aanpassen: wijzig de generator of
  `HandmadeLevels.swift` en draai `levelgen` opnieuw. `levelgen show 42` toont een level als ASCII.

## Fase 5: wat je zelf nog moet instellen

- **iCloud**: de app gebruikt iCloud key-value-opslag (`NSUbiquitousKeyValueStore`), een onderdeel van iCloud
  dat genoeg is voor de voortgang (enkele kB) en geen CloudKit-schema nodig heeft. Bij automatisch
  ondertekenen zet Xcode de iCloud-capability aan zodra je `DEVELOPMENT_TEAM` hebt ingevuld.
  Samenvoegen: levels, sterren, cosmetica en dagpuzzel-uitslagen worden samengevoegd; munten, boosters en
  instellingen komen van het toestel dat het laatst iets veranderde.
- **Game Center**: maak in App Store Connect aan:
  - Prestaties: `sweetarrows.first_win`, `sweetarrows.tutorial_done`, `sweetarrows.world_1` t/m
    `sweetarrows.world_8`, `sweetarrows.stars_100`, `sweetarrows.daily_streak_7`.
  - Ranglijst `sweetarrows.daily_time`: terugkerend (dagelijks), "laag naar hoog", score = seconden.

## Fase 6–7: wat je zelf nog moet instellen

- **AdMob**: maak de app aan in AdMob en vier ad units (rewarded, interstitial, banner, app-open). Kopieer
  `Config/Secrets.example.xcconfig` naar `Config/Secrets.xcconfig` en vul de ID's in (alleen Release leest ze).
  Zet bij meer netwerken (mediation) hun SKAdNetwork-ID's in `project.yml` onder `SKAdNetworkItems`.
- **Firebase**: maak een project, voeg de iOS-app toe met je bundle-ID en zet `GoogleService-Info.plist` in
  `SweetArrows/App/` (staat in `.gitignore`). Daarmee gaan Analytics, Crashlytics en Remote Config aan.
  Maak in Remote Config de sleutels uit PLAN.md aan; `level_overrides` is JSON, bijv.
  `{"23": {"bagCapacity": 6}, "41": {"hearts": 4}}`.
- **App Store Connect – aankopen** (ID's exact zo):
  - `com.lucthomasdewit.sweetarrows.removeads` — non-consumable, € 4,99
  - abonnementsgroep "VIP": `…vip.weekly` (€ 3,99/week) en `…vip.monthly` (€ 9,99/maand), beide met
    introductieaanbod 3 dagen gratis
  - consumables `…coins.500` (€ 1,99), `…coins.1500` (€ 4,99), `…coins.4000` (€ 9,99), `…coins.10000` (€ 19,99),
    `…starterpack` (€ 2,99)
  - Lokaal testen kan meteen: het schema gebruikt `SweetArrows/Resources/SweetArrows.storekit`.

## Afwijkingen van het plan

- **iCloud key-value-opslag** in plaats van een CloudKit-database: eenvoudiger, zelfde resultaat voor deze hoeveelheid data.
- **CI via GitHub Actions** in plaats van Xcode Cloud (Xcode Cloud kan later nog naast of in plaats van).
- **Level-tool in Swift** (`swift run levelgen`) i.p.v. een Dart-script: dan delen app en tool exact
  dezelfde regels en solver.
- **SwiftLint draait in CI** (en lokaal via een build-fase als het geïnstalleerd is), niet in de CI-build van Xcode zelf.
- **Lettertype**: Fredoka (OFL) staat in `SweetArrows/Resources/Fonts`, licentie in `docs/licenses/`.
- **App-icoon** is een placeholder in code getekend (roze hartgummy met pijl op crème), zoals het plan
  voorschrijft voor fase 1–3.

## Besluiten van de eigenaar

- Uitgeven onder **eigen naam**: bundle-ID `com.lucthomasdewit.sweetarrows.com` (zo staat de app in App Store Connect;
  een bundle-ID kan daar niet meer veranderen). Team-ID `7BDZ6994AD`. Beide in `Config/Shared.xcconfig`.
  De aankoop-ID's houden het voorvoegsel `com.lucthomasdewit.sweetarrows.` – die hoeven niet gelijk te zijn aan de bundle-ID.
- **8 werelden** voor de 300 levels.
- **Ongedaan maken blijft gratis.**

## Checklist: klaar voor lancering (uit PLAN.md)

| Punt | Stand |
|---|---|
| 300 levels, allemaal door de solver goedgekeurd | ✅ (+ 365 dagpuzzels; CI controleert ze) |
| Levels 1–10 getest door 5 mensen zonder uitleg | ❌ jij — nog niemand heeft het gespeeld |
| 60 fps oud toestel, koude start < 3 s, download < 80 MB | 🟡 voorbereid (texturen, FPS-teller in Debug); meten op een iPhone 11 met Instruments |
| Speelbaar zonder internet | ✅ in code; testen op toestel |
| UMP- en ATT-flow; advertenties pas daarna | ✅ in code; testen op toestel in de EU |
| Advertentieregels getest | ✅ unit tests (`AdPolicyTests`) |
| Remote Config met lokale standaardwaarden | ✅ |
| Remove Ads, VIP, Aankopen herstellen (sandbox + TestFlight) | 🟡 lokaal testbaar met het StoreKit-bestand; producten aanmaken in App Store Connect |
| Analytics-events in Firebase DebugView | 🟡 `GoogleService-Info.plist` nodig |
| Crashlytics actief | 🟡 `GoogleService-Info.plist` nodig |
| Kleurenblind-modus, geluid/muziek/trillen los | ✅ |
| Alle teksten vertaald (min. EN en NL) | ✅ 8 talen |
| Privacybeleid, voorwaarden, `app-ads.txt` online | 🟡 klaar in `docs/site`; domein + GitHub Pages aanzetten, publisher-id invullen |
| Privacylabels, leeftijdsclassificatie, handelaarsstatus | ❌ jij, in App Store Connect |
| Echte advertentie-ID's alleen in Release | ✅ via `Config/Secrets.xcconfig` |
| Store-pagina: icoon, screenshots, video, teksten per taal | ❌ icoon is een placeholder; screenshots uit de UI-test als basis |
| KvK en belastinggegevens | ❌ jij |
| Naam vrij, domein, geen merkconflict | ❌ jij (App Store, sweetarrowsgame.com, EUIPO/BOIP) |
| Snoepthema doorgevoerd | 🟡 in code-tekeningen; echte artwork nog niet |
| Licenties in `docs/licenses/` | ✅ Fredoka (OFL); geluid en muziek zelf gemaakt |
| Cloud-save via iCloud (twee toestellen) | 🟡 gebouwd; testen met twee toestellen |
| Website met support-mailadres | 🟡 klaar; publiceren |
| Concurrentiecheck met 5 testspelers | ❌ jij |

## Open vragen

1. Hoeveel uur per week en streefdatum soft launch?
