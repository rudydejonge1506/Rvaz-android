# RVAZ buildherstel — 8 oktober 2026

Alle 606 beschikbare runs zijn opgehaald. Voor alle 242 als mislukt geregistreerde runs zijn jobs en mislukte stappen onderzocht. Van elke verschillende foutstap zijn representatieve logs gelezen. Details en bewijs staan in `actions-audit.json`.

## Veilige vervangende workflows

- `rvaz-safe-branch-checks.yml`: Flutter-analyse, alle tests, native Wonen en SHA-256-controle van de officiële iconen.
- `rvaz-android-test.yml`: APK-testbuilds met bestaande identiteit en signing; launcher-PNG's zijn byte-exact uit succesvolle run 37751531090. Alleen artifacts, geen release/tag/publicatie.
- `ios-current-features-safe.yml`: behoudt het bewezen native iOS-project, gebruikt het officiële RVAZ-icoon, bouwt 1.1.4 (86), met Xcode 26.3 / iOS 26 SDK, valideert en uploadt uitsluitend naar TestFlight; Apple-processing wordt via een read-only API-call gecontroleerd.

`main`, de live Android-app, iOS-build 80 en de publieke App Store-release worden niet gewijzigd. Oude runs worden niet opnieuw uitgevoerd: oude uploads verwijzen naar gesloten versie-trains of kunnen bestaande releasebestanden overschrijven. Historische rode runs worden door nieuwe geslaagde runs opgevolgd; hun historische conclusie wordt niet aangepast.

## Gevonden oorzaken en herstel

| Foutgroep | Oorzaak | Herstel / status |
|---|---|---|
| Android- en iOS-iconen | Truncated PNG / Invalid IDAT- of PLTE-checksum; standaard Flutter-icoon als historisch referentiepunt | Officiële 512×512-bron hersteld, alle iOS-formaten afgeleid zonder herontwerp, exacte Android-PNG's teruggehaald en gehashd |
| Flutter-analyse / tests | Eerdere syntax- en nullability-fouten, ontbrekende tests, woningparser las de nieuws-wrapper | Actuele code analyseert zonder errors/warnings; 13 tests geslaagd, inclusief echte website-HTML |
| iOS-projectidentiteit | Ongeldige `test -f` met meerdere paden, ontbrekende entitlements / Xcode-project | Bestaan per bestand controleren en bewezen native project behouden |
| Signing | Apple Distribution-instellingen conflicteerden met automatisch gesigneerde Pods/SPM | Bestaande bewezen project- en signingmethode hergebruiken; platformbuild verifieert resultaat |
| IPA-upload | Fout artifact/run-ID, gesloten 1.1.2/1.1.3-train | Upload het IPA uit dezelfde buildjob als nieuwe 1.1.4-build, valideer identiteit en Apple-processing |
| Android-publicatie | Release/tag-bewerking faalde | Testworkflow publiceert alleen build-artifacts en raakt bestaande releases niet aan |
| Android-compilatie/signing | Eerdere Gradle-templatewijzigingen, ontbrekende secrets, package-compatibiliteit | Bewezen actuele signing/configuratie hergebruiken en APK-handtekeningen/pakket verifiëren |
| Screenshot-workflows | Onbeschikbaar simulatortype, extern beheerde Python-omgeving, niet-bewerkbare App Store-versie | Geen screenshot-upload uitvoeren: valt buiten de beschermde TestFlight-opdracht; actuele workflow gebruikt dynamische apparaatkeuze en venv |
| Workflow zonder jobs | Ongeldige eerdere YAML-definities | Actuele YAML-bestanden zijn syntactisch gecontroleerd; vervangende testflows draaien |
| Geannuleerde macOS-jobs | Runner-annulering vóór uitvoering | Vast `macos-15` gebruiken |
| Wonen-beheer | Live namespace heeft alleen aanbod en makelaar/me; beheer/foto/aanvraag-routes ontbreken | WPVibe gekoppeld; bron-ZIP gelezen; aanvullende API gebouwd en in tijdelijke WordPress getest. Live activatie van de ZIP is nog vereist. |

## Actuele verificatie

- Herstelcommit: 9c81f075ae3765cc93547dead26112ee84bafc34.
- Geslaagde Flutter-check: https://github.com/rudydejonge1506/Rvaz-android/actions/runs/37777250867.
- Analyse: 0 errors/warnings, 25 info-lints (waarvan 23 al aanwezig); `--no-fatal-infos` geslaagd.
- Tests: 13/13 geslaagd; native beheer- en foutmeldingswidgets inbegrepen.
- Android-build: https://github.com/rudydejonge1506/Rvaz-android/actions/runs/37777250947 — geslaagd, APK signing en pakketidentiteit gecontroleerd. Nieuwe uitgebreide beheerbuild: [37784300802](https://github.com/rudydejonge1506/Rvaz-android/actions/runs/37784300802) — geslaagd: drie gesigneerde ABI-APK's, package-identiteit gecontroleerd.
- iOS-build 85: [37779023894](https://github.com/rudydejonge1506/Rvaz-android/actions/runs/37779023894) — gesigneerde IPA, validatie, upload en Apple-processing `VALID` geslaagd.
- iOS-build 86 met volledigere native beheerfuncties: [37784300746](https://github.com/rudydejonge1506/Rvaz-android/actions/runs/37784300746) — wacht op macOS-runner.

Een geslaagde compilatie bewijst geen volledige makelaarsbeheerfunctie. De serverroutes en ingelogde beheerhandelingen moeten nog op de live site worden geverifieerd na installatie en activatie van `backend/dist/RVAZ-Wonen-Native-API-1.0.0.zip`. WPVibe kan deze custom plugin-ZIP niet uploaden.


## Aanvullend gecontroleerd tijdens herstel

- Eerste build 85 compileerde en exporteerde, maar Apple weigerde run 37777251309 wegens Xcode 16.4 / iOS 18.5 SDK. Xcode 26.3 / iOS 26 SDK is expliciet geselecteerd; opvolger 37779023894 is succesvol tot en met TestFlight-processing.
- Renderer-test 37778544540 vroeg naar een widget buiten de viewport. Test scrollt nu naar het energielabel; opvolger 37784300832 slaagt en genereert een leesbare native screenshot met Roboto.
- Backendtest [37784300811](https://github.com/rudydejonge1506/Rvaz-android/actions/runs/37784300811) slaagt: 40 REST/businesslogic-controles en echte HTTP bearer/multipartupload met galerijverwijdering. Geen productiedatabase of echte e-mailontvanger wordt gebruikt.
- De oorspronkelijke Android-launcher is in alle drie gesigneerde APK-architecturen op pixels vergeleken met het bestaande juiste icoon. Alle vergelijkingen identiek (renderer-run 37785592065, nieuwste uitgebreide beheerbuild).
- De TestFlight-upload publiceert geen App Store-versie, wijzigt geen publieke metadata en uploadt geen screenshots.
