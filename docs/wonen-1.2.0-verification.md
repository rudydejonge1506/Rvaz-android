# Verificatie RVAZ Wonen 1.2.0

- Website/API: 110 geslaagde controles, waaronder accountnavigatie in Chromium, mobiele breedte, toetsenbordbediening, behoud van links/listeners/formulieren, accountisolatie, foto's, €25-factuur, moderatie, kalendermaand, afloop en expliciet betaalde nieuwe plaatsing. Actions 37890801192.
- Flutter: analyse zonder fouten of waarschuwingen; 25 informatieve lintmeldingen. Alle 20 tests geslaagd. Actions 37890032835.
- Android: 0.6.5 (55), ondertekende AAB met R8-mapping, originele icoonpixels, succesvolle start op Android 15 zonder crash. Actions 37890032896.
- AAB: RVAZ-0.6.5-55.aab, SHA256 d6ad122af13b38f6319617943888e4d84aa939dcae6b26d2ae736a4fce119ac9. Alleen als ongepubliceerde GitHub-conceptbijlage geleverd; niet naar Google Play gepubliceerd. Levering Actions 37891136497.
- iOS: 1.1.4 (89), originele icoonassets en ondertekende identiteit gecontroleerd. TestFlight-upload geslaagd, Apple processingState VALID, build-id 16d88574-fc7c-4899-a880-b38ca40d4b7a. Actions 37890032852. Geen App Store-release ingediend.
- ZIP: RVAZ-Wonen-Native-API-1.2.0.zip, SHA256 5de90f6c81f6ac86e072b501bba2bb2c1b284a9b27579ec8d9e6d92e2cbabfd1. Inhoud exact gecontroleerd tegen de geteste GitHub-bronbestanden, ZIP-integriteit geslaagd.

De website rapporteert nog API-plugin 1.0.0. Installeer het ZIP-bestand als vervanging van de bestaande RVAZ Wonen Native API-plugin om dashboard, particulier aanbod, lezersfuncties en kortingsactie live te activeren. WPVibe kon de eigen ZIP niet installeren (Plugin not found). Het ingelogde productiedashboard is nog niet na installatie gecontroleerd. Bestaande RVAZ Wonen, accounts en historische facturen blijven behouden. Live Android, stabiele iOS-build 80 en de publieke App Store-release zijn niet gewijzigd.
