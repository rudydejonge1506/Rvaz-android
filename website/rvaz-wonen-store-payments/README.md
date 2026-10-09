# RVAZ Wonen Winkelbetalingen 0.1.0 — testkandidaat

Deze aanvullende plugin vervangt RVAZ Wonen, Native API, Account Herstel of de kortingsmodule niet. Hij voegt gecontroleerde StoreKit/Google Play-testbetalingen toe voor een particuliere woning of kamer: EUR 25 voor één kalendermaand vanaf publicatie, zonder automatische verlenging.

## Installeren voor testen

1. Houd Wonen 1.0.6, Native API 1.2.4 en Account Herstel 1.0.2 actief. Upload deze plugin als extra plugin en activeer hem.
2. De standaardmodus is testmodus. Sandboxbetalingen maken geen echte factuur aan, publiceren geen advertentie en verzenden geen e-mail. Er is geen knop om productiebetalingen aan te zetten.
3. Voor Google: stel uitsluitend voor deze RVAZ-app een geautoriseerd Google Play Publisher-serviceaccount in via WordPress → Instellingen → Wonen winkelbetalingen. Plak de JSON daar; stuur de privésleutel niet in een chat. De plugin slaat hem versleuteld op met de WordPress-sleutels.
4. Richt in Google Play het eenmalige product `rvaz.wonen.particulier.maand` in. Eén koopoptie, actief, compatibel met de standaard kooproute, geen meerdere aantallen, Nederland beschikbaar, EUR 25,00. De server controleert dit opnieuw vóór het openen van een aankoop.
5. Gebruik voor Android uitsluitend vooraf ingestelde Google-licentietesters. Een interne testrelease alleen maakt betalingen niet automatisch gratis. Apple TestFlight gebruikt sandboxbetalingen.
6. Apple conceptproduct 6820941005 heeft Nederlandse tekst en het Nederlandse EUR25-prijsniveau. Reviewmetadata/beschikbaarheid en een daadwerkelijke sandboxtransactie moeten nog worden voltooid/gecontroleerd voordat de app voor review wordt aangeboden.

## Testen

Maak een particuliere conceptwoning of huurkamer, voeg foto's en kenmerken toe, bevestig bevoegdheid/fotorechten en dien in. Laat een beheerder beoordelen. Open daarna de winkelbetaling in de nieuwe app. Controleer de werkelijke winkelprijs, annuleer eenmaal, probeer een testbetaling, sluit/heropen de app en controleer een openstaande aankoop opnieuw.

Verwacht: één serverbevestiging, geen echte publicatie of factuur in testmodus, geen afschrijving bij correcte sandbox-/licentietestconfiguratie, geen tweede aankoop bij alleen opnieuw controleren. Een andere gebruiker kan deze aankoop of woning niet beheren.

## Productievoorwaarden

Geen productieactivering vóór echte aankooptests, controle van de live API-installatie, configuratie van Apple-servermeldingen voor terugbetalingen, en controle van Google-serverrechten en terugbetalingscontrole. Apple-meldingen gaan naar `/wp-json/rvaz-wonen/v1/winkel/apple-melding` en moeten cryptografisch geldig zijn. Google-terugbetalingen worden dagelijks opnieuw bij Google gecontroleerd. De bestaande websitefacturen, Tikkie-links en makelaarskortingen worden niet vervangen.

De backendtests gebruiken een wegwerp-WordPress-database en synthetische Google-antwoorden; die tests vervangen geen echte winkeltest.
