# RVAZ particuliere winkelbetaling

## Vastgestelde voorwaarden

Een particulier kan een koopwoning, huurwoning of kamer beheren in Mijn RVAZ / Mijn Wonen en Mijn account op de website. Een plaatsing kost EUR 25 voor één kalendermaand vanaf daadwerkelijke publicatie. Het is een eenmalige aankoop zonder automatische verlenging. De bestaande limiet van één actieve particuliere woning blijft behouden. Geen nieuwe particuliere introductiekorting is afgesproken.

De bestaande makelaarsintroductie van 50%, en MAKELAAR voor de eerste twee verschillende nieuwe kantoren met 100% korting op de eerste maand, blijven afzonderlijk behouden. Geen stapeling. Websitekortingscodes mogen niet als onbewezen Apple- of Google-winkelkorting worden aangeboden.

## Betaal- en publicatievolgorde

1. Opslaan als concept, met foto's en dezelfde toepasselijke woningkenmerken als voor makelaars. Huurvelden alleen bij Huur.
2. Bevoegdheid en fotorechten bevestigen; indienen voor beoordeling.
3. Beheerder beoordeelt. Een afgewezen of nog niet beoordeelde advertentie krijgt geen winkelbetaalknop.
4. Server maakt een unieke aankoopintentie voor ingelogde eigenaar, advertentie, winkel, product, EUR 25 en één maand.
5. App toont de werkelijke winkelprijs en opent StoreKit of Google Play Billing. Geen Tikkie om winkelbetaling heen.
6. Server controleert de cryptografisch ondertekende Apple-transactie, of vraagt Google Play met geautoriseerde servercredentials. Clientstatus is nooit betalingsbewijs.
7. Unieke winkeltransactie wordt eenmaal verwerkt en gekoppeld aan eigenaar en advertentie. Herhalen na netwerkuitval geeft hetzelfde resultaat. Andere eigenaar/advertentie krijgt geen toegang.
8. Alleen een echte productiebetaling kan een eerder beoordeelde advertentie activeren. Sandbox- en licentietestbetalingen publiceren niets op de live website en veroorzaken geen echte factuur of e-mail.
9. Start en einde worden vastgelegd op het moment van publicatie. Bewerkingen vereisen opnieuw moderatie; de betaalde einddatum wordt niet verlengd door een bewerking. Na afloop verdwijnt het publieke aanbod. Terugbetaling moet de betreffende lopende plaatsing intrekken.

## Winkelstatus op 9 oktober 2026

Apple app 6817375521, bundle nl.regiovoorneaanzee.app. Conceptproduct 6820941005, SKU rvaz.wonen.particulier.maand, consumable. Nederlands prijsniveau exact EUR 25 beschikbaar. Product is MISSING_METADATA en niet ingediend of gepubliceerd. Build 1.1.4 (96) is door Apple verwerkt voor TestFlight, maar bevat nog de factuurroute; niet de definitieve winkelbetaling.

Google package nl.regiovoorneaanzee.rvaz_android. Google Play Publisher-serviceaccount en werkelijk ingericht eenmalig EUR25-product zijn nog niet geverifieerd. Geen Google-credentials beschikbaar via de bestaande bouwconfiguratie. Dit verhindert een gecontroleerde echte Google-betaling; een groene Android-build bewijst die koppeling niet.

## Oplevercriteria

Geslaagde servervalidatie, replay/andere eigenaar/quota/prijs/refund-tests, gecontroleerde sandboxaankoop op beide winkels, live geïnstalleerde backendkoppeling, en daarna nieuwe Android- en iOS-testbuilds. Geen e-mails verzenden, echte advertenties publiceren of App Store/Google Play productie-release uitrollen als onderdeel van deze tests.
