# RVAZ Raad het woord — websiteversie

Versie 1.3.0: zes letters en maximaal zes pogingen. Installeer deze versie als nieuwe plugin of deactiveer en activeer na vervangen zodat de antwoordkolom van de tabel naar zes tekens wordt bijgewerkt. Oudere vijfletterwoorden moeten vóór gebruik vervangen worden. Er is nog geen live installatie gedaan in deze sessie.

Versie 1.2.1: de ranglijst gebruikt de gebruikersnaam (user_login) van het account. Intro en uitgelichte afbeelding staan in het openbare artikel. Het spel en de ranglijst worden alleen aan ingelogde gebruikers geleverd; ook de REST-routes weigeren uitgelogde verzoeken. Via de publicatieknop krijgt elk spelartikel automatisch de meegeleverde uitgelichte afbeelding. De ranglijst bevat maximaal 50 winnaars van vandaag, gesorteerd op aantal pogingen met gedeelde plaatsen bij gelijke score. De knop publiceert maximaal één artikel per dag; oudere artikelen tonen expliciet het spel van vandaag.

Nog niet geïnstalleerd op de live website. Installeer de ZIP via Plugins → Nieuwe plugin → Plugin uploaden en activeer. De plugin maakt alleen een eigen spelgegevenstabel en beheeronderdeel aan. Maak zelf een pagina met `[rvaz_woordspel]`. Menu’s, zijbalken en bestaande pagina’s worden niet gewijzigd.

Onder **Woordspel** stel je per datum een woord in. Er wordt geen voorbeeldwoord automatisch gepubliceerd. Vijf letters a–z; zes pogingen; alleen ingelogde WordPress-gebruikers. Daggrens volgens de WordPress-tijdzone. Het woord ligt vast zodra iemand heeft gespeeld. Voortgang is gekoppeld aan account en datum, niet aan browseropslag. Gelijktijdige verzoeken worden geserialiseerd; er kunnen geen zevende pogingen worden opgeslagen. Dubbele letters worden eerst op positie en daarna op resterende aantallen beoordeeld.

Deze versie valideert vijflettercombinaties, niet of elk ingevoerd woord in een Nederlands woordenboek voorkomt. Het antwoord wordt alleen na winst of zes pogingen teruggegeven. Beheer uitsluitend voor manage_options; REST vereist een ingelogde gebruiker en WordPress REST-nonce. Geen app-integratie in deze versie.

Sluit de spelpagina en `/wp-json/rvaz-woord/v1/*` uit van eventuele CDN/full-page caching; de plugin stuurt zelf no-cacheheaders. Herladen na verlopen login of nonce. Gebruikers mogen alleen hun eigen voortgang zien. Er is geen scorebord of openbare persoonsgegevenslijst. Bewaarde spelgegevens vallen onder het privacybeleid van de website; verwijderen van een gebruiker/verwijderen van de plugin wist de tabel momenteel niet automatisch.

Voor livegang te testen op een WordPress-testomgeving: uitgelogde toegang weigeren; zes foute pogingen afsluiten; winst afsluiten; herladen voortgang; twee gelijktijdige laatste pogingen; middernacht/datumwissel; adminwoord na eerste poging niet wijzigbaar; mobiele toetsen en delen; dubbele letters. PHP/WordPress-integratietests zijn nog niet uitgevoerd in deze omgeving omdat PHP hier ontbreekt.
