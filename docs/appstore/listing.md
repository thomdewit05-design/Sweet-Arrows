# App Store-teksten — Sweet Arrows

Klaar om in App Store Connect te plakken. Deze teksten passen bij de app zoals hij nu is (build 13, zonder spelmodi, Prijzen of widget) (App Store → je app → versie 1.0 → per taal).
Maak eerst **Nederlands** en **Engels (VS)** aan; de andere talen vallen terug op Engels.
De lengtes zijn gecontroleerd (`python3 Tools/AppStore/check_listing.py`).

## Algemeen (één keer invullen)

| Veld | Waarde |
|---|---|
| Primaire categorie | Games → Puzzel |
| Tweede categorie | Games → Casual |
| Prijs | Gratis |
| In-app-aankopen | Geen |
| Leeftijdsclassificatie | 4+ (vragenlijst: overal "Geen"; "Bevat advertenties": Ja) |
| Privacybeleid-URL | https://thomdewit05-design.github.io/Sweet-Arrows/privacy.html |
| Support-URL | https://thomdewit05-design.github.io/Sweet-Arrows/ |
| Marketing-URL | https://thomdewit05-design.github.io/Sweet-Arrows/ |
| Copyright | 2026 [jouw naam] |
| Screenshots | `docs/appstore/nl/` en `docs/appstore/en/` → bij "iPhone 6,9 inch" (1320 × 2868) |

**App-privacy (vragenlijst "Gegevensverzameling")**, omdat de app Google AdMob en Firebase gebruikt:
- Ja, er worden gegevens verzameld.
- *Identificatiegegevens → Apparaat-ID*: voor advertenties van derden en analyse; gekoppeld aan
  tracking alleen als de speler toestemming geeft (ATT).
- *Gebruiksgegevens → Productinteractie* en *Advertentiegegevens*: analyse en advertenties.
- *Diagnostiek → Crashgegevens*: app-functionaliteit (Crashlytics).
- Niet verzameld: naam, e-mail, locatie, contacten, aankopen.

---

## Nederlands

**Naam** (max. 30)
```
Sweet Arrows
```

**Subtitel** (max. 30)
```
Tik, glijd en plop de snoepjes
```

**Promotietekst** (max. 170, kun je altijd aanpassen zonder nieuwe versie)
```
Tik een snoepje, zie het glijden en laat rijen van 3 of meer ploppen. Elke dag nieuwe opdrachten, levels om te halen en zoete combo's. Hoe lang houd jij het bord leeg?
```

**Beschrijving** (max. 4000)
```
Tik op een snoepje en het glijdt in de richting van zijn pijl tot het ergens tegenaan botst. Zet 3 of meer snoepjes van dezelfde kleur op een rij en ze ploppen met een zoete knal. Klinkt makkelijk? Er komen steeds nieuwe snoepjes bij, en steeds sneller. Is het bord vol, dan is het potje voorbij.

Sweet Arrows is een vrolijke puzzelgame voor even tussendoor of een hele avond. Eén vinger, korte potjes, en elke keer net dat ene record dat je nog wilt verbreken.

ZO SPEEL JE
• Tik om een snoepje te laten glijden: het gaat zo ver als het kan
• Staat het vast? Tik nog eens en de pijl draait
• 3, 4 of 5 op een rij: hoe langer de rij, hoe meer punten
• Snel achter elkaar ploppen geeft combo's en een suikerfeest aan effecten
• Bommen, regenboogsnoepjes en stenen maken elk potje anders

ELKE DAG IETS TE DOEN
• Drie dagopdrachten met een bonuscadeau
• Een dagelijks cadeau dat groter wordt als je meer dagen op rij speelt
• Houd je reeks vast en stijg in level voor munten en nieuwe achtergronden

EN VERDER
• Boosters: hint, hamer en slowmo
• Munten verdienen door te spelen, uitgeven aan nieuwe snoepstijlen, borden en achtergronden
• Ranglijst en prestaties via Game Center
• Muziek die vrolijker wordt naarmate het spel sneller gaat
• Kleurenblindstand, en geluid, muziek en trillingen apart aan of uit
• In 19 talen

Sweet Arrows is gratis en bevat advertenties. Er zijn geen in-app-aankopen: alles verdien je door te spelen.
```

**Trefwoorden** (max. 100, komma's zonder spaties; woorden uit naam en subtitel hoeven er niet in)
```
puzzel,snoep,match 3,drie op een rij,pijlen,glijden,casual,denkspel,combo,brein,offline,record
```

**Nieuw in deze versie**
```
De eerste versie van Sweet Arrows! Veel plezier met ploppen.
```

---

## English (U.S.)

**Name** (max 30)
```
Sweet Arrows
```

**Subtitle** (max 30)
```
Tap, slide & pop the sweets
```

**Promotional text** (max 170)
```
Tap a candy, watch it slide and pop lines of 3 or more. New missions every day, levels to climb and sweet combos. How long can you keep the board clear?
```

**Description** (max 4000)
```
Tap a candy and it slides the way its arrow points until it bumps into something. Line up 3 or more of the same color and they pop with a sweet crunch. Sounds easy? New candies keep arriving, faster and faster. When the board is full, the run is over.

Sweet Arrows is a cheerful puzzle game for a quick break or a whole evening. One finger, short runs, and always that one record you still want to beat.

HOW TO PLAY
• Tap to slide a candy: it goes as far as it can
• Stuck? Tap again and its arrow turns
• 3, 4 or 5 in a row: the longer the line, the more points
• Pop quickly in a row for combos and a sugar rush of effects
• Bombs, rainbow candies and stones make every run different

SOMETHING NEW EVERY DAY
• Three daily missions with a bonus gift
• A daily gift that grows the more days in a row you play
• Keep your streak going and level up for coins and new backdrops

AND MORE
• Boosters: hint, hammer and slow motion
• Earn coins by playing and spend them on new candy styles, boards and backdrops
• Leaderboard and achievements with Game Center
• Music that gets livelier as the game speeds up
• Color-blind mode, and sound, music and vibration each on or off
• In 19 languages

Sweet Arrows is free and contains ads. There are no in-app purchases: you earn everything by playing.
```

**Keywords** (max 100)
```
puzzle,candy,match 3,three in a row,arrows,slide,casual,brain,combo,logic,offline,relaxing,sweet
```

**What's New**
```
The very first version of Sweet Arrows! Have fun popping.
```

---

## Screenshots

In `docs/appstore/`: `nl/` en `en/` (1320 × 2868, iPhone 6,9 inch) en `nl-6.3/` en `en-6.3/`
(1206 × 2622, iPhone 6,1/6,3 inch). Upload ze in deze volgorde:

| # | Scherm | NL-kop | EN-kop |
|---|---|---|---|
| 1 | Spel, Suikerfeest-combo | Tik. Glijd. Plop! | Tap. Slide. Pop! |
| 2 | Hoofdscherm | Elke dag nieuwe opdrachten | New missions every day |
| 3 | Nieuw record | Verbreek je record | Beat your record |
| 4 | Winkel | Nieuwe looks voor je snoep | New looks for your candy |
| 5 | Dagelijks cadeau | Elke dag een cadeau | A gift every day |

Promotieafbeelding (banner, zonder tekst): `docs/appstore/banner/` in 3840 × 1646 en 5244 × 2950.

Opnieuw maken: de workflow "App Store screenshots" draaien (of `SweetArrowsUITests/ScreenshotTests.swift`
aanpassen en pushen), daarna `python3 Tools/AppStore/frame_screenshots.py`; de banner met
`python3 Tools/AppStore/make_banner.py`.
