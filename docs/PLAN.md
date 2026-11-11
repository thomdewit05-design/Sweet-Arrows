# Bouwplan puzzelgame voor Claude Code

*10 november 2026 · Luc-Thomas de Wit*

> Overgenomen uit het oorspronkelijke bouwplan (PDF). Keuzes die tijdens het bouwen zijn gemaakt
> staan in [STATUS.md](STATUS.md).

## Doel & concept

We bouwen een hybrid-casual puzzelgame voor iPhone (iOS) die draait op advertenties (rewarded voorop),
met een abonnement zonder advertenties ernaast. Het doel voor v1: dag-1-retentie van minstens 40%,
dag-7 minstens 15%, en 8 of meer advertentievertoningen per actieve speler per dag zonder dat spelers afhaken.

**Concept: "Sweet Arrows"** — een bord vol snoepjes, elk met een pijl erop. Tik een snoepje aan en het
schiet in de richting van zijn pijl weg. Is de weg vrij, dan vliegt het van het bord in je **snoepbak**
(5 vakjes). Drie dezelfde snoepjes in de bak ploppen weg. Raakt een snoepje onderweg een ander snoepje,
dan stuitert het terug en kost dat een hartje. Het doel: haal het bord leeg zonder dat je bak volloopt.

- **Waarom dit werkt:** één tik per zet, regels die je in 5 seconden snapt, maar elke zet vraagt twee
  keuzes tegelijk: welk snoepje kan eruit, en past de kleur in mijn bak? Levels duren 30–90 seconden:
  natuurlijke momenten voor een advertentie.
- **Wat het anders maakt:** geen slepen, geen gekleurde deuren, geen tijdslimiet. Je puzzelt op de
  volgorde, in je eigen tempo (zie Onderscheid van concurrenten).
- **Natuurlijk advertentiemoment:** bak bijna vol of vastgelopen? Kijk een rewarded ad voor een extra
  vakje, zet ongedaan maken of een snoepje verwijderen.
- **Doelgroep:** 25–55 jaar, speelt korte sessies (wachtrij, bank, OV). Ongeveer 50/50 man/vrouw.
  Niet gericht op kinderen: dat houdt de advertentieregels eenvoudig en de opbrengst per vertoning hoger.
- **Sessie:** 3–5 levels per sessie, 3–6 sessies per dag.
- **Wat we níet bouwen in v1:** multiplayer, accounts met inloggen, chat, een verhaal met personages.

## Merk & thema

Het spel heet **Sweet Arrows** en speelt zich af in een snoepwinkel: snoepjes met pijlen schieten van de
toonbank in je snoepbak. De naam benadrukt de pijlen, het onderdeel dat het spel anders maakt dan de
block-jam-games in de hitlijsten.

### Naam
- Store-naam: "Sweet Arrows: Candy Puzzle" (26 tekens, binnen Apple's limiet van 30).
- Ondertitel: "Tap, slide, pop the sweets".
- Bundle-ID: bijv. `com.<jouwstudio>.sweetarrows`; domein bijv. sweetarrowsgame.com.
- Controleren vóór je verder bouwt: is de naam vrij in de App Store, is het domein vrij, en staat er geen
  merk op in het EUIPO- of BOIP-register.
- Vermijd woorden van grote concurrenten in naam en ondertitel: geen "Crush", "Saga", "Jam",
  "Block Out" of "Sort".

### Visuele stijl
- Snoepjes = glanzende gummy's en zuurtjes in verschillende vormen per kleur, met een witte pijl erop.
  Ze wiebelen licht als je ze aantikt. Geen vierkante blokken: dat houdt afstand van de block-games.
- Snoepbak = een glazen snoeppot onderaan het scherm met 5 vakjes; bij 3 dezelfde ploppen ze met een
  suikerwolkje.
- Bord = een houten snoepwinkel-toonbank met zachte schaduw; open, ruimtelijk, weinig randen.
- Kleurenpalet: aardbei `#FF5C8A`, citroen `#FFD23F`, munt `#3DDC97`, bosbes `#5B6CFF`,
  sinaasappel `#FF9F1C`, druif `#A259FF`, achtergrond crème `#FFF4E6`. Elke kleur heeft ook een eigen
  snoepvorm (hart, ster, rond, ruit, druppel, vierkant): handig voor kleurenblinde spelers.
- Lettertype: rond en vriendelijk, bijv. Fredoka of Baloo 2 (gratis, open licentie).
- Icoon: één roze hartvormig gummy met een witte pijl die schuin uit beeld schiet, op een crèmekleurige
  achtergrond. Geen tekst in het icoon.

### Mascotte
- "Jelly", een klein gummy-figuurtje met grote ogen. Verschijnt in de tutorial, bij vieringen en op het
  icoon van events. Houdt het spel herkenbaar zonder dat het een verhaal nodig heeft.

### Werelden (20 levels per wereld)

> Besluit tijdens de bouw: de 300 levels van v1 zijn verdeeld over deze 8 werelden (37–38 per wereld).
1. Gummy Garden
2. Lollipop Lane
3. Chocolate Falls
4. Marshmallow Mountains
5. Caramel Canyon
6. Cotton Candy Clouds
7. Licorice Lab
8. Ice Cream Island

Elke wereld krijgt een eigen achtergrond en één nieuw element dat bij de pijlen hoort: karamel (snoepje
heeft 2 tikken nodig), draaisnoepje (pijl draait een kwartslag na elke zet), ijsblokje (bevroren tot een
buurman weg is), verpakt snoepje (kleur pas zichtbaar als de weg vrij is), chocoladereep (2 vakjes lang)
en een lolly-paal waar snoepjes omheen moeten.

### Geluid
- Zachte "squish" en "pop" bij schuiven en wegvallen, oplopende xylofoontonen bij combo's, een kort
  vrolijk deuntje bij level klaar.
- Rustige, speelse achtergrondmuziek (lounge/ukelele), standaard op laag volume.

### Waar komen de assets vandaan
- Fase 1–3: simpele vormen in code (Claude Code tekent ze).
- Vanaf fase 4: echte artwork via een freelancer (Fiverr/ArtStation) of AI-gegenereerd en daarna
  opgeschoond. Controleer bij AI en stockmateriaal dat commercieel gebruik is toegestaan.
- Geluid: royaltyvrije packs (bijv. Kenney, Sonniss) of een freelancer. Bewaar alle licenties in
  `docs/licenses/`.

## Onderscheid van concurrenten

Sweet Arrows zit in hetzelfde populaire puzzelgenre als Block Out! (Grand Games, nr. 1 in Casual), maar
speelt en voelt bewust anders. Het genre is bewezen; een kopie winnen van een grote studio is kansloos.

| | Block Out! en block-jam-games | Sweet Arrows |
|---|---|---|
| Bediening | Blokken vrij slepen | Eén tik; snoepje volgt zijn pijl |
| Doel | Blok naar deur met dezelfde kleur | Bord leeg, snoepjes in de snoepbak, 3 dezelfde ploppen |
| Uitdaging | Ruimte en route | Volgorde én kleurplanning in de bak |
| Tijdslimiet | Vaste tijd per level | Geen tijdslimiet; hartjes bij een botsing |
| Advertenties | Reviewers klagen over een advertentie na elk level | Pas vanaf level 8, hooguit 1 per 2 levels; vermeld op de store-pagina |
| Stijl | Bonte blokken, verhaalgebieden | Snoepwinkel, gummy-vormen, mascotte Jelly |

### Regels om afstand te houden
- Geen gekleurde deuren of uitgangen aan de rand van het bord.
- Geen sleepbediening en geen vierkante blokken als hoofdvorm.
- Geen namen, iconen of screenshots die lijken op de top 10 van Puzzel/Casual; check dat bij elke store-update.
- Voor de soft launch: 5 spelers laten raden "op welke game lijkt dit?". Noemen ze steeds dezelfde titel,
  dan de stijl of twist verder aanpassen.

Bron: App Store-pagina Block Out!, bekeken op 10 november 2026.

## Tech stack

Bouw native in Swift: SpriteKit voor het bord en de animaties, SwiftUI voor menu's, winkel en
instellingen. Dat is dezelfde Apple-omgeving als Skipilot, geeft de beste prestaties op iPhone en heeft
geen extra framework nodig.

| Onderdeel | Keuze | Waarom |
|---|---|---|
| Taal & UI | Swift 6 + SwiftUI | Native, moderne Apple-standaard |
| Game-engine | SpriteKit | Ingebouwd in iOS: animaties, deeltjes en geluid, geen licentiekosten |
| Minimale iOS-versie | iOS 17 | Dekt vrijwel alle actieve iPhones; moderne StoreKit en SwiftData beschikbaar |
| Projectbestand | XcodeGen (`project.yml`) | Het Xcode-project wordt uit een tekstbestand gegenereerd; voorkomt kapotte projectbestanden als Claude Code bestanden toevoegt |
| Advertenties | Google Mobile Ads SDK (Swift Package Manager) met mediation (AppLovin, Unity Ads, Meta, Mintegral als netwerken) | AdMob en AppLovin halen samen ongeveer 65% van de advertentie-inkomsten in games; mediation laat ze tegen elkaar bieden |
| Toestemming | Google UMP SDK + App Tracking Transparency | Verplicht in de EU en op iOS |
| Aankopen & abonnement | StoreKit 2 (met `SubscriptionStoreView`) | Native en gratis; RevenueCat kan later voor uitgebreidere omzetstatistieken |
| Analytics & crashes | Firebase Analytics + Crashlytics | Gratis, standaard in de branche |
| Instellingen op afstand | Firebase Remote Config + A/B Testing | Advertentiefrequentie en moeilijkheid aanpassen zonder update |
| Opslag & cloud-save | Codable JSON of SwiftData, gesynchroniseerd via iCloud (CloudKit) | Voortgang offline bewaren en meenemen naar een nieuwe iPhone |
| Game Center | GameKit | Prestaties en een ranglijst voor de dagpuzzel |
| Geluid & trillingen | SKAudioNode / AVAudioEngine + Core Haptics | Korte effecten, muziek en tastbare feedback |
| Tests | Swift Testing + XCTest (UI-tests) | Ingebouwd in Xcode |
| CI/CD | Xcode Cloud (25 uur per maand inbegrepen bij je developer-account) | Automatisch bouwen, testen en uploaden naar TestFlight |

Claude Code moet op je Mac draaien, zodat het met `xcodebuild` kan bouwen en testen in de Simulator.
De code komt in een nieuwe GitHub-repo; gebruik hetzelfde Apple Developer-account als Skipilot.

## Gameplay & levels

De kern is: level spelen → beloning → voortgang zien → volgend level. Daaromheen zit een lichte meta-laag
die spelers elke dag terug laat komen.

### Core loop
1. Level start direct, zonder laadscherm (binnen 1 seconde).
2. Speler tikt snoepjes aan; elke zet geeft animatie, geluid en een trilling.
3. Klaar: sterren, munten en een korte viering.
4. Vast: aanbod om met een rewarded ad een extra vakje in de snoepbak te krijgen, 1 zet ongedaan te
   maken of een snoepje te verwijderen.
5. Door naar het volgende level.

### Meta-laag (v1)
- Munten verdienen per level; uitgeven aan hints, ongedaan maken en cosmetica (blokstijlen, achtergronden).
- Dagelijkse beloning (7-dagenreeks) en een win-streak die extra munten geeft.
- Een kaart met werelden van 20 levels, elk met een eigen thema en kleurenpalet.
- Dagelijkse puzzel met een eigen ranglijst-gevoel (lokaal, geen server nodig in v1).

### Levels: generator plus solver
- Claude Code bouwt een **level-generator** (draait offline) en een **solver** die bewijst dat elk level
  oplosbaar is en telt hoeveel zetten de kortste oplossing kost.
- Levels worden opgeslagen als JSON in `assets/levels/`. Geen enkel level gaat de app in zonder dat de
  solver het heeft goedgekeurd.
- Moeilijkheid = combinatie van bordgrootte, aantal blokken, aantal kleuren, lengte van de oplossing en
  aantal "valkuilzetten".
- Start met 300 levels in v1; daarna elke 2 weken 50 erbij via een update of Remote Config.

### Moeilijkheidscurve
- Levels 1–10: tutorial, niet te verliezen.
- Daarna een zaagtand: 4 makkelijke, 1 middel, 1 moeilijk ("Hard level"-label), herhalen en langzaam opschuiven.
- Elke 10 levels een nieuw element (bijv. ijsblok, kleurwisselaar).
- Meet per level hoeveel spelers afhaken; levels met meer dan 5% uitval worden aangepast via Remote Config.

## Gevoel & kwaliteit

Of mensen blijven spelen hangt vooral af van hoe het spel aanvoelt. Daarom krijgt elke handeling
feedback, en moet het spel overal soepel lopen.

### Game feel ("juice")
- Elke tik: blok schuift met een ease-out-animatie (150–250 ms), kort geluid, lichte trilling.
- Snoepje vliegt met een boog in de snoepbak; bij 3 dezelfde een plop met suikerwolkje en een oplopende
  toon bij elke volgende combo.
- Level klaar: confetti, sterren die één voor één binnenkomen, munten die naar de teller vliegen.
- Verkeerde zet: blok stuitert terug met een zachte "bonk", nooit een hard foutgeluid.
- Eén consistente stijl: zachte vormen, verzadigde kleuren, veel witruimte.

### Onboarding
- Geen tekstmuren: het eerste level legt zichzelf uit met een wijzende hand.
- Geen advertenties en geen toestemmingsvragen vóór level 3 (behalve de AVG-vraag, die wettelijk eerst
  moet; zie Privacy).
- Na level 5 pas de dagelijkse beloning en de winkel tonen.

### Toegankelijkheid
- Kleurenblind-modus: elk kleurblok krijgt ook een symbool.
- Geluid, muziek en trillingen los aan/uit.
- Grote tikvlakken (minimaal 44×44 pt), werkt met één hand en in staande stand.
- Ondersteuning voor grotere systeemtekst in menu's.

### Taal
- Start met Engels en Nederlands; daarna Duits, Frans, Spaans, Portugees (Brazilië), Turks en
  Indonesisch. Daar zitten veel spelers en lage advertentiekosten.
- Alle teksten in een String Catalog (Localizable.xcstrings), nooit hardgecodeerd.

### Prestaties
- 60 fps op een toestel van 4 jaar oud (bijv. iPhone 11 of iPhone SE 2e generatie).
- App kleiner dan 80 MB bij download.
- Koude start binnen 3 seconden.
- Volledig speelbaar zonder internet (advertenties tonen dan gewoon niet).
- Voortgang wordt na elk level opgeslagen; plus cloud-save via iCloud en Game Center (zie Kosten,
  planning & onderhoud).

## Monetisatie

Rewarded ads zijn de motor: de speler kiest zelf voor een advertentie in ruil voor iets dat hij wil.
Interstitials zijn aanvulling, strak begrensd. Alle grenzen staan in Remote Config, zodat je ze kunt
bijstellen zonder update.

| Formaat | Wanneer | Startregels (Remote Config) |
|---|---|---|
| Rewarded video | Extra vakje in de snoepbak, hint, zet ongedaan maken, snoepje verwijderen, munten verdubbelen na een level, extra leven bij vastlopen, dagbeloning x2 | Altijd optioneel; maximaal 20 per dag |
| Interstitial | Tussen levels, nooit midden in een level | Pas vanaf level 8; maximaal 1 per 2 levels en minimaal 90 seconden ertussen; nooit direct na een rewarded ad; nooit na een verloren level |
| Banner | Onderaan op de kaart en in menu's, nooit tijdens het spelen | Adaptieve banner; uit te zetten via Remote Config als het retentie kost |
| App-open ad | Bij terugkomen in de app na meer dan 4 uur | Pas vanaf dag 2; standaard uit, aanzetten via A/B-test |

### Zonder advertenties betalen
- **Remove Ads** (eenmalig, ongeveer €4,99): geen interstitials, banners en app-open ads. Rewarded
  blijft beschikbaar, want spelers willen die beloningen vaak toch.
- **VIP-abonnement** (ongeveer €3,99 per week of €9,99 per maand, met 3 dagen gratis proberen): geen
  advertenties, dagelijks gratis hints, exclusieve blokstijl, rewarded beloningen zonder kijken.
- **Muntenpakketten** (€1,99 tot €19,99) en een **starterspakket** dat pas na level 15 verschijnt.
- Toon aanbiedingen op natuurlijke momenten (na een verloren level, bij een lege muntenvoorraad), nooit
  als pop-up bij het opstarten.

### Technisch
- Eén `AdService`-klasse die alle advertentielogica, frequentiegrenzen en Remote Config-waarden bundelt.
  De game zelf roept alleen `showRewarded(reden)` of `maybeShowInterstitial()` aan.
- Advertenties vooraf laden, zodat ze direct starten; bij geen beschikbare advertentie de knop grijs
  maken in plaats van een foutmelding.
- Mediation instellen met AdMob als basis en AppLovin, Unity Ads, Meta en Mintegral als biedende
  netwerken. Begin met AdMob alleen tot je ongeveer 1.000 spelers per dag hebt.
- Elke vertoning en de opbrengst ervan loggen naar Firebase (`ad_impression` met waarde), zodat je
  opbrengst per speler per dag (ARPDAU) kunt meten.

## Privacy & wetgeving

In de EU mag je pas gepersonaliseerde advertenties tonen na toestemming. Regel dat goed vanaf dag 1;
anders weigeren Google en Apple de app of daalt je advertentie-opbrengst sterk.

### In de app
- [ ] Google UMP-toestemmingsscherm bij eerste start (Google vereist een gecertificeerd
      toestemmingsplatform in de EER). Volgorde: eerst UMP, daarna pas advertenties laden.
- [ ] iOS: App Tracking Transparency-vraag na de UMP-vraag, met een vriendelijk voorscherm dat uitlegt waarom.
- [ ] Knop "Privacy-instellingen" in het instellingenmenu om toestemming te wijzigen.
- [ ] Werkt volledig zonder toestemming (dan niet-gepersonaliseerde advertenties).
- [ ] SKAdNetwork-ID's van alle advertentienetwerken in `Info.plist`.
- [ ] `app-ads.txt` op je eigen website (verplicht voor AdMob-opbrengst).

### In de stores
- [ ] Privacybeleid en gebruiksvoorwaarden op eigen domein (bijv. een simpele website op GitHub Pages).
- [ ] Privacylabel (App Privacy) in App Store Connect correct invullen (advertentie-ID, crashgegevens,
      aankoopgeschiedenis).
- [ ] Leeftijdsclassificatie: richt je op volwassenen, níet op kinderen. Een app voor kinderen valt onder
      strengere regels (Apple Kids-categorie, COPPA) en levert veel minder op.
- [ ] EU-handelaarsstatus (DSA) instellen in App Store Connect; je adres en contactgegevens worden dan zichtbaar.

### Zakelijk
- [ ] Inschrijven bij de KvK als eenmanszaak zodra je inkomsten verwacht; advertentie-inkomsten van
      Google komen uit Ierland en vallen onder de btw-verleggingsregeling.
- [ ] Belastinggegevens invullen in AdMob en App Store Connect.
- [ ] Even afstemmen met een boekhouder over btw en inkomstenbelasting (ik ben geen belastingadviseur).

Open vraag: lever je het spel uit onder je eigen naam of onder een studionaam? Dat bepaalt welke naam in
de stores staat.

## Data & LiveOps

Zonder metingen gok je. Log vanaf de eerste testversie deze events naar Firebase, en stuur op een handvol KPI's.

### Events
- `level_start`, `level_complete` (zetten, tijd, sterren), `level_fail`, `level_quit`
- `booster_used` (type, bron: munten of advertentie)
- `ad_offer_shown`, `ad_offer_accepted`, `ad_impression` (formaat, netwerk, opbrengst)
- `store_open`, `purchase` (product, prijs), `subscription_start`, `subscription_cancel`
- `tutorial_step`, `daily_reward_claimed`, `session_start`

### KPI's en doelen

| KPI | Doel v1 | Toppers in de markt |
|---|---|---|
| Dag-1-retentie | 40% | 45–55% |
| Dag-7-retentie | 15% | 20–25% |
| Dag-30-retentie | 5% | 8–12% |
| Speeltijd per dag | 20 min | 30+ min |
| Advertenties per speler per dag | 8 | 10–15 |
| ARPDAU (alle inkomsten) | €0,05 | €0,10–0,20 |
| Crashvrije sessies | 99,5% | 99,9% |

### Remote Config-sleutels
`interstitial_min_level`, `interstitial_level_gap`, `interstitial_min_seconds`, `rewarded_daily_cap`,
`banner_enabled`, `app_open_enabled`, `starter_pack_level`, `level_overrides` (moeilijkheid per level aanpassen).

### A/B-tests om als eerste te draaien
1. Interstitial vanaf level 5, 8 of 12.
2. Banner aan of uit (effect op retentie tegenover opbrengst).
3. Prijs van Remove Ads: €2,99 of €4,99.

### LiveOps na lancering
- Elke 2 weken nieuwe levels; elke maand een tijdelijk event (bijv. "Winterweek" met een eigen beloningsbalk).
- Pushmeldingen alleen met toestemming en hooguit 1 per dag (dagpuzzel klaar, reeks bijna voorbij).

## Projectstructuur & CLAUDE.md

Zet een CLAUDE.md in de root van de repo voordat Claude Code begint. Die leest hem bij elke sessie en
houdt zich dan aan dezelfde regels. (De actuele versie staat in [`/CLAUDE.md`](../CLAUDE.md).)

Zet ook dit hele plan als `docs/PLAN.md` in de repo.

## Fasering met prompts voor Claude Code

Bouw in 8 fasen van elk ongeveer een week. Geef Claude Code steeds één fase tegelijk, laat het eerst een
plan maken (plan mode) en test zelf op je telefoon voordat je verdergaat. De belangrijkste regel:
fase 2 moet leuk zijn voordat je aan fase 4 begint.

1. **Fundament.**
   > Lees CLAUDE.md en docs/PLAN.md. Zet een nieuw iOS-project op met XcodeGen (project.yml), SwiftUI en
   > SpriteKit volgens de structuur in CLAUDE.md. Voeg de Swift Packages toe (Google Mobile Ads,
   > Firebase), maak het lokale package SweetArrowsCore, lege services met protocollen, het snoepthema
   > (kleuren, Fredoka-font), navigatie (home, kaart, level, winkel, instellingen) en NL/EN in een String
   > Catalog. Zet SwiftLint en Xcode Cloud of GitHub Actions op voor build en tests. Maak een plan, wacht
   > op mijn akkoord, en bouw dan.
2. **Kernmechaniek (het belangrijkste).**
   > Bouw in Packages/SweetArrowsCore het level-model en de spelregels uit docs/PLAN.md: snoepjes op een
   > raster met elk een pijlrichting; een tik laat het snoepje in die richting bewegen; vrije weg = van het
   > bord naar de snoepbak (5 vakjes, 3 dezelfde ploppen); botsing = terugstuiteren en een hartje kwijt;
   > bak vol of hartjes op = verloren; bord leeg = gewonnen. Pure Swift, uitgebreide tests in Swift
   > Testing. Bouw daarna in SweetArrows/Game een SpriteKit-scene met bord, snoepbak, hartjes, 10
   > handgemaakte levels, tikbediening en zet ongedaan maken. Nog geen menu's of effecten.
3. **Levels: generator en solver.**
   > Maak in Tools/LevelGen een command-line tool (swift run levelgen) met een solver die bewijst dat een
   > level oplosbaar is zonder botsingen en zonder dat de snoepbak volloopt, en die het aantal oplossingen
   > en de valkuilzetten telt. Plus een generator op basis van parameters (bordgrootte, aantal snoepjes,
   > kleuren, bakgrootte, speciale elementen). Genereer 300 levels met de moeilijkheidscurve uit PLAN.md,
   > valideer elk level met de solver en schrijf ze als JSON naar SweetArrows/Resources/levels/. Voeg een
   > rapport toe met moeilijkheid per level.
4. **Game feel.**
   > Voeg alle feedback toe uit de secties Gevoel & kwaliteit en Merk & thema: gummy-wiebel bij tikken,
   > snoepje dat met een boog in de bak vliegt, plop met suikerwolkje bij 3 dezelfde, SKAction-animaties
   > met easing, squish- en pop-geluiden, Core Haptics, level-klaar-viering, stuiter bij een botsing.
   > Voeg een tutorial toe voor levels 1–3 met mascotte Jelly. Zorg voor 60 fps en meet dat met Instruments.
5. **Meta-laag.**
   > Bouw munten, boosters (extra bakvakje, hint, ongedaan maken, snoepje weg), de wereldkaart met de
   > snoepwerelden en hun nieuwe elementen, dagelijkse beloning met 7-dagenreeks, win-streak, dagpuzzel,
   > cosmetica in de winkel en opslag van alle voortgang (SaveService) met iCloud-sync via CloudKit.
   > Voeg Game Center toe voor prestaties en de ranglijst van de dagpuzzel. Alles moet offline werken.
6. **Toestemming en advertenties.**
   > Implementeer ConsentService (eerst UMP, daarna ATT met een eigen voorscherm) en AdService met
   > rewarded, interstitial, banner en app-open volgens de regels in PLAN.md. Alle grenzen uit
   > ConfigService (Remote Config met lokale defaults). Gebruik test-ID's, voeg de SKAdNetwork-ID's toe aan
   > Info.plist en schrijf tests voor de frequentielogica. Koppel rewarded aan de boosters, aan doorgaan
   > na een volle bak en aan munten verdubbelen.
7. **Aankopen, analytics en Remote Config.**
   > Implementeer PurchaseService met StoreKit 2: Remove Ads (non-consumable), VIP-abonnement met 3 dagen
   > gratis proberen (SubscriptionStoreView), muntenpakketten, starterspakket en Aankopen herstellen. Maak
   > een StoreKit-configuratiebestand om lokaal te testen. Voeg alle analytics-events uit PLAN.md toe, plus
   > Crashlytics. Maak een debugmenu (alleen in Debug) om levels over te slaan, munten toe te voegen en
   > advertentieregels te testen.
8. **Afwerking en release.**
   > Voeg kleurenblind-ondersteuning (vorm per kleur), Dynamic Type in menu's, instellingen (geluid,
   > muziek, trillen, privacy), privacylinks en de overige talen toe. Maak het app-icoon en launch screen,
   > zorg dat alles werkt op iPhone SE tot Pro Max en controleer de weergave op iPad. Zet de upload naar
   > TestFlight op en loop de checklist in PLAN.md na. Rapporteer wat nog ontbreekt.

### Tips voor werken met Claude Code
- Laat het na elke fase de app op je eigen telefoon draaien; speel zelf 15 minuten en geef concrete
  feedback ("blok voelt traag", "level 23 te moeilijk").
- Vraag na fase 2 en 4 om een review: "Bekijk de code kritisch op bugs, prestaties en leesbaarheid en
  los de belangrijkste punten op."
- Laat grafische assets (blokstijlen, iconen) eerst als eenvoudige vormen in code maken; vervang ze later
  door echte artwork.

## Testen, release en marketing

Lanceer eerst stil in een paar goedkope landen, verbeter op basis van de cijfers, en ga pas wereldwijd
als de retentie goed is.

### Testen
- Automatisch: unit tests voor regels, solver en advertentielogica; widget tests voor schermen; golden
  tests voor het bord.
- Handmatig op minimaal 1 oude en 1 nieuwe iPhone plus een iPad, met en zonder internet, met en zonder toestemming.
- 10–20 testers via TestFlight (eerst intern, daarna een openbare TestFlight-link).

### Soft launch (4–6 weken)
- Landen: bijvoorbeeld Canada, Australië en Nieuw-Zeeland (Engelstalig, vergelijkbaar met de VS) plus
  Nederland en de Filipijnen (goedkope installs).
- Pas door naar wereldwijd bij dag-1 ≥ 40% en dag-7 ≥ 15%. Zit je daaronder: levels 1–30 en de game feel
  verbeteren, niet de advertenties opvoeren.

### App Store-optimalisatie (ASO)
- Naam plus ondertitel met zoekwoorden (bijv. "Sweet Arrows: Candy Puzzle" en "Tap, slide, pop the sweets").
- Eerste screenshot = het spel midden in een actie, met één korte zin erboven. Een video van 15–30
  seconden met echte gameplay.
- Teksten en screenshots in elke taal die het spel ondersteunt.
- Vraag om een beoordeling na een gewonnen moeilijk level (via de officiële review-API), nooit na verlies.

### Gratis marketing
- Korte video's (TikTok, Reels, Shorts): moeilijke levels, "99% faalt hier", oplossingen in slow motion.
  Postfrequentie: 1 per dag tijdens de lancering.
- Laat het spel een deelbaar resultaat maken bij de dagpuzzel (zoals Wordle).
- Later, als de cijfers goed zijn: kleine betaalde campagnes (Apple Ads, AppLovin, Meta) met de best
  presterende video's, en alleen opschalen als de opbrengst per speler hoger is dan de kosten per install.

## Kosten, planning & onderhoud

De vaste kosten om te starten zijn laag (rond de €115 per jaar als je artwork zelf of met AI maakt). De
grootste investering is je eigen tijd: reken op 8–12 weken tot de soft launch bij 10–15 uur per week.

| Post | Kosten | Opmerking |
|---|---|---|
| Apple Developer Program | €99 per jaar | Heb je al voor Skipilot |
| Xcode Cloud | €0 (25 uur per maand inbegrepen) | |
| Domein + simpele website | ca. €15 per jaar | GitHub Pages is gratis hosting |
| Firebase, AdMob, RevenueCat | €0 | RevenueCat is gratis tot $2.500 omzet per maand |
| Artwork (freelancer) | €0–800 | Optioneel; AI of zelf maken kan ook |
| Geluid | €0–100 | Royaltyvrije packs |
| Testcampagne soft launch | €200–500 | Optioneel, om snel retentiedata te krijgen |

Open vraag: hoeveel uur per week stop je erin, en wat is je streefdatum voor de soft launch?

### Stopcriteria
- Na 3 verbeterrondes in de soft launch nog steeds dag-1 onder 30%: dan het concept omgooien (andere
  twist of mechaniek) in plaats van verder te polijsten.
- Dag-1 boven 40% maar opbrengst per speler te laag: eerst de advertentieregels en het VIP-aanbod testen, niet het spel.

### Website & support
- Eén pagina op het eigen domein met: korte uitleg, store-links, privacybeleid, voorwaarden,
  `app-ads.txt` en een support-mailadres (bijv. support@sweetarrowsgame.com).
- In de app: knop "Contact" die een mail opent met app-versie en toestel al ingevuld.

### Cloud-save (in v1)
- Voortgang koppelen aan iCloud (CloudKit) en Game Center, zodat spelers bij een nieuwe telefoon niets
  kwijtraken. Geen eigen accounts of server nodig.

### Onderhoud na lancering
- Apple eist elk jaar nieuwere SDK-versies (nieuwe Xcode- en iOS SDK-versie, meestal vanaf april). Plan
  minimaal 2–3 onderhoudsupdates per jaar in, ook als je geen nieuwe levels toevoegt.
- Houd advertentie-SDK's actueel; oude versies leveren minder op en kunnen uit de mediation vallen.
- Elke maand de KPI's bekijken en de 5 levels met de meeste uitval bijstellen.

## Checklist: klaar voor lancering

De app gaat pas live als alles hieronder is afgevinkt.

- [ ] 300 levels, allemaal door de solver goedgekeurd
- [ ] Levels 1–10 getest door minstens 5 mensen die het spel niet kenden, zonder uitleg
- [ ] 60 fps op een oud toestel, koude start < 3 s, download < 80 MB
- [ ] Speelbaar zonder internet
- [ ] UMP- en ATT-flow werkt; advertenties laden pas daarna
- [ ] Advertentieregels getest: geen interstitial in een level, na rewarded of vóór level 8
- [ ] Remote Config-waarden werken en hebben lokale standaardwaarden
- [ ] Remove Ads, VIP en "Aankopen herstellen" werken, getest in de sandbox en via TestFlight
- [ ] Alle analytics-events komen binnen in Firebase DebugView
- [ ] Crashlytics actief; 99,5% crashvrij in de testfase
- [ ] Kleurenblind-modus, geluid/muziek/trillen los instelbaar
- [ ] Alle teksten vertaald (minimaal EN en NL)
- [ ] Privacybeleid, voorwaarden en `app-ads.txt` online
- [ ] Privacylabels, leeftijdsclassificatie en handelaarsstatus ingevuld
- [ ] Echte advertentie-ID's alleen in de releasebuild
- [ ] Store-pagina: icoon, screenshots, video en teksten per taal
- [ ] KvK en belastinggegevens geregeld
- [ ] Naam "Sweet Arrows" vrij in de App Store, domein geregistreerd, geen merkconflict
- [ ] Snoepthema doorgevoerd: icoon, bord, snoepjes, snoepbak, werelden 1–3, mascotte Jelly
- [ ] Licenties van artwork, lettertype en geluid in `docs/licenses/`
- [ ] Cloud-save via iCloud werkt (test met twee toestellen)
- [ ] Website met support-mailadres online
- [ ] Concurrentiecheck gedaan: 5 testspelers noemen niet steeds dezelfde bestaande game, en naam, icoon
      en screenshots lijken niet op de top 10 Puzzel/Casual
