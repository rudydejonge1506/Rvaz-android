# RVAZ Wonen Native API

Deze aanvullende plugin werkt naast de bestaande **RVAZ Wonen** en **RVAZ App API**. Vervang of deactiveer die plugins niet. Het installatiepakket bevat alleen `rvaz-wonen-native-api/rvaz-wonen-native-api.php`; testfixtures en tijdelijke CI-authenticatie zijn uitgesloten.

## Installeren

WordPress → Plugins → Nieuwe plugin toevoegen → Plugin uploaden → `dist/RVAZ-Wonen-Native-API-1.0.0.zip` → Installeren → Activeren.

WPVibe ondersteunt aangepaste plugin-ZIP-upload niet: bronbestanden buiten een draft-thema zijn read-only en `plugin install` ondersteunt alleen een WordPress-plugin-slug. Deze installatie moet daarom via het normale WordPress-beheer plaatsvinden, tenzij een toegestane uploadverbinding beschikbaar komt.

## Gedrag

- Bestaande RVAZ App API controleert haar eigen bearer-token via `/rvaz-app/v1/me`; deze plugin maakt geen alternatieve tokens of wachtwoorden aan.
- Administrators en goedgekeurde makelaars kunnen Mijn Wonen openen; blokkering wordt gerespecteerd. Gewone gebruikers kunnen een aanvraag indienen, maar zichzelf nooit makelaar maken.
- Woningen, foto’s, galerij, profiel, instellingen, statistieken, privéberichten, abonnementen, promotie-aanvragen en facturen/PDF's gebruiken de bestaande Wonen-data.
- Aanbodserializer geeft integer-woningnummers en ingevulde websitekenmerken; gallery en makelaarsgegevens worden toegevoegd.
- Publiceren vraagt een actief abonnement en controleert de bestaande limiet of beheerderoverride. Verwijderen gebruikt de WordPress-prullenbak; galerijverwijdering wist geen mediabestanden.
- Pakketwijzigingen vragen bevestiging van de actuele prijs. Een gewone gebruiker krijgt geen actief abonnement zonder RVAZ-beoordeling.
- Schema-installatie voegt ontbrekende kolommen toe via `dbDelta`. Bestaande factuurbedragen, BTW, abonnementsdatums, gebruikersrollen en pagina’s worden niet herschreven. Bestaande lege volgende-factuurdatums worden niet automatisch gevuld.
- Deactivatie herstelt de routecallbacks van de bestaande Wonen-plugin; geen uninstall/data deletion.

## Bewijs

WordPress REST- en echte HTTP/multiparttests zijn geslaagd in run [37784300811](https://github.com/rudydejonge1506/Rvaz-android/actions/runs/37784300811). Ze controleren echte WordPress-opslag, eigenaarschap, ingetrokken tokens via de App API, blokkering, limieten, galerij, facturen/PDF, abonnementwijzigingen, opzegging en behoud van historische factuurbedragen. Mail wordt uitsluitend in de tijdelijke CI-installatie onderdrukt.

Plugin 1.0.0 is op 8 oktober 2026 live geactiveerd. De publieke woningkenmerken, ingelogde beheer-GET-routes, factuur-PDF en aanmaken/wijzigen/opruimen van een tijdelijk concept zijn via WPVibe gecontroleerd. Een controle met de ingelogde WordPress-beheerverbinding vervangt geen controle met een app-token op een toestel.
