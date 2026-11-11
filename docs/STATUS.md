# Status & keuzes

Stand van de bouw per fase uit [PLAN.md](PLAN.md), plus de keuzes die tijdens het bouwen gemaakt zijn.

> **November 2026:** het spel is omgebouwd. Het hoofdspel is nu **Glijden & matchen** (zie hieronder).
> De pijlpuzzels met levels, de kaart, de dagpuzzel, de levelgenerator en de solver zijn op verzoek van de
> eigenaar verwijderd. Ook **alle in-app-aankopen** zijn eruit (Remove Ads, VIP, muntenpakketten, starterspakket):
> de app verdient alleen aan advertenties. Waar de fasentabel nog over levels of aankopen spreekt, beschrijft
> hij hoe het eerst gebouwd was.

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

## Fase 5: wat je zelf nog moet instellen

- **iCloud**: de app gebruikt iCloud key-value-opslag (`NSUbiquitousKeyValueStore`), een onderdeel van iCloud
  dat genoeg is voor de voortgang (enkele kB) en geen CloudKit-schema nodig heeft. Bij automatisch
  ondertekenen zet Xcode de iCloud-capability aan zodra je `DEVELOPMENT_TEAM` hebt ingevuld.
  Samenvoegen: beste score, aantal potjes en cosmetica worden samengevoegd; munten, boosters en
  instellingen komen van het toestel dat het laatst iets veranderde.
- **Game Center**: maak in App Store Connect aan:
  - Prestaties: `sweetarrows.first_pop`, `sweetarrows.score_1000`, `sweetarrows.score_5000`,
    `sweetarrows.combo_5`, `sweetarrows.speed_10`, `sweetarrows.runs_50`.
  - Ranglijst `sweetarrows.endless_score`: altijd, "hoog naar laag", score = punten.
  - De oude prestaties (werelden, sterren, dagpuzzel) en de ranglijst `sweetarrows.daily_time` zijn niet meer nodig.

## Fase 6–7: wat je zelf nog moet instellen

- **AdMob**: maak de app aan in AdMob en vier ad units (rewarded, interstitial, banner, app-open). Kopieer
  `Config/Secrets.example.xcconfig` naar `Config/Secrets.xcconfig` en vul de ID's in (alleen Release leest ze).
  Zet bij meer netwerken (mediation) hun SKAdNetwork-ID's in `project.yml` onder `SKAdNetworkItems`.
- **Firebase**: maak een project, voeg de iOS-app toe met je bundle-ID en zet `GoogleService-Info.plist` in
  `SweetArrows/App/` (staat in `.gitignore`). Daarmee gaan Analytics, Crashlytics en Remote Config aan.
  Maak in Remote Config de sleutels uit PLAN.md aan (behalve `level_overrides`, die bestaat niet meer).
  "Level" in de sleutelnamen betekent nu een gespeeld potje: `interstitial_min_level` (standaard 4),
  `interstitial_level_gap` (2). `starter_pack_level` is niet meer nodig.
- **App Store Connect – aankopen**: niet nodig, de app heeft geen in-app-aankopen. Heb je daar al producten
  aangemaakt (Remove Ads, VIP, munten, starterspakket), dan kun je die verwijderen of laten staan; dien ze niet
  mee in ter beoordeling.

## Afwijkingen van het plan

- **iCloud key-value-opslag** in plaats van een CloudKit-database: eenvoudiger, zelfde resultaat voor deze hoeveelheid data.
- **CI via GitHub Actions** in plaats van Xcode Cloud (Xcode Cloud kan later nog naast of in plaats van).
- **SwiftLint draait in CI** (en lokaal via een build-fase als het geïnstalleerd is), niet in de CI-build van Xcode zelf.
- **Lettertype**: Fredoka (OFL) staat in `SweetArrows/Resources/Fonts`, licentie in `docs/licenses/`.
- **App-icoon** (keuze van de eigenaar, ontwerp D): een lachend geel sterretje-snoepje op een grote witte pijl,
  voor een groen-paarse snoephemel met stralen, glitters en een paar snoepjes in de vormen uit het spel;
  gemaakt door `Tools/Icon/make_icon.py`. De mascotte in de app (`JellyView`) is hetzelfde sterretje.
  Vrolijk en speels, maar bewust niet kinderachtig: de app blijft voor algemeen publiek (geen Kids-categorie).

## Hoofdspel: Glijden & matchen

De eigenaar vond het wegschieten met pijlen niet leuk genoeg en koos een nieuw spel dat erop lijkt
(`SlideGame` in SweetArrowsCore, `SlideSession`/`SlideScene` in de app, scherm `EndlessView`).
De pijlpuzzels zijn daarna helemaal verwijderd.

- **Tik** op een snoepje: het glijdt in de richting van zijn pijl tot de rand of een ander snoepje.
  Kan het niet bewegen, dan draait de pijl een kwartslag (met de klok mee). Elke tik doet dus iets; geen hartjes.
- **3 of meer** van dezelfde kleur op een rij (horizontaal of verticaal) ploppen. Er valt niets; het bord is een tafel.
- Bord van 7×8, start met 12 snoepjes. Elke 2,4 s komt er een snoepje bij (eerst 1 s een schaduw);
  elke "snelheid" (15 snoepjes geplopt) 8% sneller, tot één per 0,7 s. Een nieuw snoepje maakt nooit zelf een rij.
- Eerst 3 kleuren, elke twee snelheden een kleur erbij (max. 6). Speciaal: **bom** (vanaf snelheid 2, popt 3×3),
  **steen** (vanaf 3, kan niet bewegen, breekt als ernaast iets popt), **regenboog** (vanaf 4, telt als elke kleur).
- **Af:** geen vrij vakje voor een nieuw snoepje. Eén keer per potje doorgaan met een beloningsvideo:
  een derde van de snoepjes verdwijnt.
- **Punten:** 10 per gepopt snoepje, +20 per snoepje boven de 3 in een rij, 5 per gebroken steen, alles × combo
  (ploppen binnen 3 s na elkaar, max. ×5), +100 voor een leeg bord. Munten: score ÷ 25. Record en Game Center-ranglijst
  `sweetarrows.endless_score` zoals voorheen.
- Simulatie (20 potjes, speler die één zet vooruit kijkt, één tik per seconde): potjes duren 4–6 minuten, snelheid 4–6.
- Eerste twee potjes: uitleg bovenin en een handje dat een snoepje aanwijst dat meteen een rij maakt.
- **Boosters** (onder het bord; uit voorraad, voor munten of met een beloningsvideo):
  *Tip* (60) laat een snoepje knipperen dat meteen een rij maakt (je betaalt alleen als er zo'n zet is),
  *Hamer* (90) tik daarna een snoepje of steen weg, *Slowmo* (120) 15 s lang komen nieuwe snoepjes half zo snel.
  In oude saves heten ze nog `removeCandy` en `extraSlot`; die voorraad blijft dus bewaard.
- **Game feel** (op verzoek van de eigenaar, naar voorbeeld van een opname; eigen stijl): bij elke plop flitst
  het vakje wit op, schiet er een gloeiende streep langs de rij en spatten snoepstukjes met zwaartekracht weg;
  lof-woorden groeien mee met de zet (*Lekker!*, *Heerlijk!*, *Suikerfeest!*, *Bord leeg!*, plus "Combo ×N");
  het bord schudt harder bij grotere zetten en bommen (schokgolf); vanaf combo 3 gloeit er een rand in
  wisselende snoepkleuren om het bord en kleurt de achtergrond roze; de score pompt op en kleurt mee.
  Trillingen groeien mee (1–5 tikken, met een doorlopende tril bij grote zetten, een rommel bij bommen).
  Met "Beweging verminderen" aan: geen schudden en minder stukjes.
- **Banner onder het spelbord** (keuze van de eigenaar, wijkt af van het plan "nooit tijdens het spelen"):
  onder de boosterbalk, met ruimte ertussen. Op verzoek van de eigenaar vaak zichtbaar: vanaf het eerste potje
  (zodra de toestemmingsvraag is afgerond), ook onderin het startscherm en de winkel. Remote Config-sleutel
  `banner_from_level` (standaard 0) en `banner_enabled` om hem op afstand te regelen.
- **Meta:** winkel (alleen munten: boosters, toonbanken en snoepstijlen, ook "Goud" voor 1500) en dagbeloning
  na 3 potjes, ATT-vraag na 2, advertenties na 2 potjes,
  interstitial pas vanaf potje 4, hooguit om de 2 potjes, alleen bij "Opnieuw spelen".

## Doorspelen en uitstraling (november 2026)

Op verzoek van de eigenaar ("alles mag") zodat spelers blijven terugkomen:

- **Spelersniveau met XP** (`PlayerLevel`): elk potje geeft 20 XP + score/25 + 15 per leeg bord. Een niveau kost
  100 XP, daarna 40 meer per niveau. Elk niveau geeft 40 + 10×niveau munten; elk 5e niveau 1 van elke booster;
  niveau 3, 6, 10 en 15 geven een nieuwe **achtergrond** (Snoepweide, IJsjesbaai, Chocoladerivier,
  Suikerspinlucht, Sterrennacht). Achtergronden kies je in de winkel.
- **3 dagopdrachten** (`DailyMissions`): elke dag andere, voor iedereen met hetzelfde niveau gelijk, doelen
  groeien met je niveau (bijv. "Haal 1500 punten in één potje", "Laat 50 snoepjes ploppen", "Haal combo ×4").
  Munten per opdracht en een bonuscadeau (munten + tip) als alle drie klaar zijn.
- **Speelreeks** (`PlayStreak`): dagen op rij met minstens één potje, met vlammetje op het startscherm.
- **Na een potje:** eerst het doorspeel-aanbod (filmpje), pas daarna wordt het potje geteld (dus nooit dubbel).
  De uitslagkaart toont de XP-balk die vol loopt, level-ups met beloning, gehaalde opdrachten, alle munten
  en "nog X punten tot je record".
- **Startscherm:** snoephemel met zwevende snoepjes, niveau + XP-balk, munten, record en speelreeks,
  een grote kloppende Speel-knop, de dagopdrachten en knoppen voor winkel en cadeau (met stip als het klaarstaat).
- **Eén stijl:** glanzende 3D-knoppen, witte kaarten op de snoephemel (startscherm en winkel), score en
  boosters op een lichte ondergrond zodat ze op elke achtergrond leesbaar zijn.
- **Snoepjes:** donkerdere onderkant en extra glimlichtje voor meer diepte, en een zachte "ademhaling" als ze
  stilliggen (uit met Beweging verminderen). Combo-koorts kleurt nu de achtergrond roze in plaats van de kleur te wisselen.

### Echte illustraties later toevoegen

Alles is nu met code getekend. Komen er later echte tekeningen (bijv. van een illustrator), zet ze dan als
afbeelding in `SweetArrows/Resources/Assets.xcassets` met precies deze namen; de app gebruikt ze dan vanzelf:

| Wat | Naam in de asset catalog | Formaat |
|---|---|---|
| Snoepje per kleur | `candy-strawberry`, `candy-lemon`, `candy-mint`, `candy-blueberry`, `candy-orange`, `candy-grape` | vierkant, transparant, 256×256 |
| Snoepje per kleur en stijl (optioneel) | bijv. `candy-lemon-pastelCandy`, `candy-mint-goldenCandy` | idem |
| Mascotte (sterretje) | `mascot` | vierkant, transparant, 512×512 |
| Achtergrond | `backdrop-candyMeadow`, `backdrop-iceCreamBay`, `backdrop-chocolateRiver`, `backdrop-cottonSky`, `backdrop-starryNight` | staand, 1290×2796 |

De witte pijl wordt altijd door de app over het snoepje heen getekend; teken die dus niet in de afbeelding.

## Besluiten van de eigenaar

- Uitgeven onder **eigen naam**: bundle-ID `com.lucthomasdewit.sweetarrows.com` (zo staat de app in App Store Connect;
  een bundle-ID kan daar niet meer veranderen). Team-ID `7BDZ6994AD`. Beide in `Config/Shared.xcconfig`.
- Hoofdspel **Glijden & matchen**; de pijlpuzzels met levels zijn verwijderd.
- **Geen in-app-aankopen**; alleen advertenties.

## Checklist: klaar voor lancering (uit PLAN.md)

| Punt | Stand |
|---|---|
| Eerste potjes getest door 5 mensen zonder uitleg | ❌ jij — nog niemand heeft het gespeeld |
| 60 fps oud toestel, koude start < 3 s, download < 80 MB | 🟡 voorbereid (texturen, FPS-teller in Debug); meten op een iPhone 11 met Instruments |
| Speelbaar zonder internet | ✅ in code; testen op toestel |
| UMP- en ATT-flow; advertenties pas daarna | ✅ in code; testen op toestel in de EU |
| Advertentieregels getest | ✅ unit tests (`AdPolicyTests`) |
| Remote Config met lokale standaardwaarden | ✅ |
| Analytics-events in Firebase DebugView | 🟡 `GoogleService-Info.plist` nodig |
| Crashlytics actief | 🟡 `GoogleService-Info.plist` nodig |
| Kleurenblind-modus, geluid/muziek/trillen los | ✅ |
| Alle teksten vertaald (min. EN en NL) | ✅ 8 talen |
| Privacybeleid, voorwaarden, `app-ads.txt` online | 🟡 klaar in `docs/site`; domein + GitHub Pages aanzetten, publisher-id invullen |
| Privacylabels, leeftijdsclassificatie, handelaarsstatus | ❌ jij, in App Store Connect |
| Echte advertentie-ID's alleen in Release | ✅ via `Config/Secrets.xcconfig` |
| Store-pagina: icoon, screenshots, video, teksten per taal | 🟡 icoon klaar; screenshots uit de UI-test als basis |
| KvK en belastinggegevens | ❌ jij |
| Naam vrij, domein, geen merkconflict | ❌ jij (App Store, sweetarrowsgame.com, EUIPO/BOIP) |
| Snoepthema doorgevoerd | 🟡 in code-tekeningen; echte artwork nog niet |
| Licenties in `docs/licenses/` | ✅ Fredoka (OFL); geluid en muziek zelf gemaakt |
| Cloud-save via iCloud (twee toestellen) | 🟡 gebouwd; testen met twee toestellen |
| Website met support-mailadres | 🟡 klaar; publiceren |
| Concurrentiecheck met 5 testspelers | ❌ jij |

## Open vragen

1. Hoeveel uur per week en streefdatum soft launch?
