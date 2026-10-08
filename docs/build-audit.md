# RVAZ buildherstel — 8 oktober 2026

Alle 606 beschikbare runs zijn opgehaald. Voor alle 242 als mislukt geregistreerde runs zijn jobs en mislukte stappen onderzocht. Van elke verschillende foutstap zijn representatieve logs gelezen. Details en bewijs staan in `actions-audit.json`.

## Veilige vervangende workflows

- `rvaz-safe-branch-checks.yml`: Flutter-analyse, alle tests, native Wonen en SHA-256-controle van de officiële iconen.
- `rvaz-android-test.yml`: APK-testbuilds met bestaande identiteit en signing; launcher-PNG's zijn byte-exact uit succesvolle run 37751531090. Alleen artifacts, geen release/tag/publicatie.
- `ios-current-features-safe.yml`: behoudt het bewezen native iOS-project, gebruikt het officiële RVAZ-icoon, bouwt 1.1.4 (85), valideert en uploadt uitsluitend naar TestFlight; Apple-processing wordt via een read-only API-call gecontroleerd.

`main`, de live Android-app, iOS-build 80 en de publieke App Store-release worden niet gewijzigd. Oude runs worden niet opnieuw uitgevoerd: oude uploads verwijzen naar gesloten versie-trains of kunnen bestaande releasebestanden overschrijven. Historische rode runs worden door nieuwe geslaagde runs opgevolgd; hun historische conclusie wordt niet aangepast.

## Gevonden oorzaken en herstel

| Foutgroep | Oorzaak | Herstel / status |
|---|---|---|
| Android- en iOS-iconen | Truncated PNG / Invalid IDAT- of PLTE-checksum; standaard Flutter-icoon als historisch referentiepunt | Officiële 512×512-bron hersteld, alle iOS-formaten afgeleid zonder herontwerp, exacte Android-PNG's teruggehaald en gehashd |
| Flutter-analyse / tests | Eerdere syntax- en nullability-fouten, ontbrekende tests, woningparser las de nieuws-wrapper | Actuele code analyseert zonder errors/warnings; 8 tests geslaagd, inclusief echte website-HTML |
| iOS-projectidentiteit | Ongeldige `test -f` met meerdere paden, ontbrekende entitlements / Xcode-project | Bestaan per bestand controleren en bewezen native project behouden |
| Signing | Apple Distribution-instellingen conflicteerden met automatisch gesigneerde Pods/SPM | Bestaande bewezen project- en signingmethode hergebruiken; platformbuild verifieert resultaat |
| IPA-upload | Fout artifact/run-ID, gesloten 1.1.2/1.1.3-train | Upload het IPA uit dezelfde buildjob als nieuwe 1.1.4-build, valideer identiteit en Apple-processing |
| Android-publicatie | Release/tag-bewerking faalde | Testworkflow publiceert alleen build-artifacts en raakt bestaande releases niet aan |
| Android-compilatie/signing | Eerdere Gradle-templatewijzigingen, ontbrekende secrets, package-compatibiliteit | Bewezen actuele signing/configuratie hergebruiken en APK-handtekeningen/pakket verifiëren |
| Screenshot-workflows | Onbeschikbaar simulatortype, extern beheerde Python-omgeving, niet-bewerkbare App Store-versie | Geen screenshot-upload uitvoeren: valt buiten de beschermde TestFlight-opdracht; actuele workflow gebruikt dynamische apparaatkeuze en venv |
| Workflow zonder jobs | Ongeldige eerdere YAML-definities | Actuele YAML-bestanden zijn syntactisch gecontroleerd; vervangende testflows draaien |
| Geannuleerde macOS-jobs | Runner-annulering vóór uitvoering | Vast `macos-15` gebruiken |
| Wonen-beheer | Live namespace heeft alleen aanbod en makelaar/me; beheer/foto/aanvraag-routes ontbreken | WordPress-autorisatie vereist voordat servercode kan worden gelezen en aangepast |

## Actuele verificatie

- Herstelcommit: 9c81f075ae3765cc93547dead26112ee84bafc34.
- Geslaagde Flutter-check: https://github.com/rudydejonge1506/Rvaz-android/actions/runs/37777250867.
- Analyse: 0 errors/warnings, 23 bestaande info-lints; `--no-fatal-infos` geslaagd.
- Tests: 8/8 geslaagd.
- Android-build: https://github.com/rudydejonge1506/Rvaz-android/actions/runs/37777250947 — nog te verifiëren.
- iOS/TestFlight: https://github.com/rudydejonge1506/Rvaz-android/actions/runs/37777251309 — nog te verifiëren.

Een geslaagde compilatie bewijst geen volledige makelaarsbeheerfunctie. De serverroutes en ingelogde beheerhandelingen moeten nog daadwerkelijk worden geverifieerd zodra WordPress gekoppeld is.

