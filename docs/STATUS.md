# Status & keuzes

Stand van de bouw per fase uit [PLAN.md](PLAN.md), plus de keuzes die tijdens het bouwen gemaakt zijn.

## Fasen

| Fase | Stand |
|---|---|
| 1. Fundament | ✅ XcodeGen-project, SwiftUI-navigatie (home, kaart, level, winkel, instellingen), thema + Fredoka, services met protocollen, NL/EN String Catalog, SwiftLint, GitHub Actions (Linux: regels/solver/levels, macOS: iOS-build + tests). Google Mobile Ads, UMP en Firebase zijn als packages gekoppeld. |
| 2. Kernmechaniek | ✅ Regels in `SweetArrowsCore` (pure Swift, getest), SpriteKit-bord met snoepbak, hartjes, tikbediening, ongedaan maken, 10 handgemaakte tutoriallevels. Basale animaties (wegschieten, boog naar de pot, stuiteren, plop) zodat je kunt zien wat er gebeurt. |
| 3. Generator + solver | ✅ `swift run levelgen`: 300 levels, allemaal door de solver goedgekeurd, rapport in [level-report.md](level-report.md). CI controleert elk level opnieuw. |
| 4. Game feel | ⏳ Volgende stap — eerst fase 2 op je telefoon testen (zie hieronder). |
| 5–8 | ⏳ Nog niet begonnen. Services staan klaar als placeholders met de juiste protocollen. |

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
  ongedaan maken verder. Voorlopig gratis; in fase 5 kost het munten of een advertentie.
- **Snoepje weg** (booster) haalt een snoepje van het bord zonder dat het in de pot gaat en wist de
  ongedaan-maken-geschiedenis, zodat je de booster niet per ongeluk terugdraait.
- **Tutorial (1–10) is niet te verliezen**: botsingen kosten geen hartje en de pot is altijd groot genoeg
  (2 kleuren bij 5 vakjes; 3 kleuren bij 7 vakjes in level 9–10). De solver controleert dat er geen enkele
  verliezende zet is.
- **Sterren**: 3 zonder botsing, 2 na één botsing, anders 1.

### Speciale elementen per wereld

Het plan noemt zes elementen voor acht werelden. Ze zijn thematisch verdeeld; elke wereld introduceert er
één en houdt de eerdere:

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

**300 levels vs. 8 werelden × 20 levels.** Het plan wil 300 levels in v1 maar 8 werelden van 20 (=160).
Daarom herhalen de thema's na level 160 als "seizoen 2" (Gummy Garden 2, …) met alle elementen gemengd.
*Open vraag:* liever 8 grotere werelden, of nieuwe namen voor werelden 9–15?

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

## Afwijkingen van het plan

- **CI via GitHub Actions** in plaats van Xcode Cloud (Xcode Cloud kan later nog naast of in plaats van).
- **Level-tool in Swift** (`swift run levelgen`) i.p.v. een Dart-script: dan delen app en tool exact
  dezelfde regels en solver.
- **SwiftLint draait in CI** (en lokaal via een build-fase als het geïnstalleerd is), niet in de CI-build van Xcode zelf.
- **Lettertype**: Fredoka (OFL) staat in `SweetArrows/Resources/Fonts`, licentie in `docs/licenses/`.
- **App-icoon** is een placeholder in code getekend (roze hartgummy met pijl op crème), zoals het plan
  voorschrijft voor fase 1–3.

## Open vragen

1. Eigen naam of studionaam in de stores? (bepaalt bundle-id en `DEVELOPMENT_TEAM`)
2. Werelden 9–15: herhalen als seizoen 2 (nu), of 8 grotere werelden / nieuwe namen?
3. Ongedaan maken tijdens het spelen: gratis houden met een limiet, of altijd munten/advertentie (fase 5)?
4. Hoeveel uur per week en streefdatum soft launch?
