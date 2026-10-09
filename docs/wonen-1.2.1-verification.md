# RVAZ Wonen Native API 1.2.1

Particuliere woningformulieren tonen de fotokeuze vóór de eerste opslag. Meerdere foto's kunnen tegelijk worden geselecteerd en worden bij het opslaan toegevoegd. De galerij toont de hoofdfoto en ondersteunt opnieuw ordenen en verwijderen. De bestaande native foto-API blijft compatibel met Android 55 en iOS 1.1.4 (89); deze update vereist geen nieuwe appbuild.

Beheer: WordPress → Wonen → Testfacturen beheren. Markeer een onbetaalde factuur expliciet als test en verwijder deze vervolgens uit de actieve lijsten. Een open testfactuur wordt geannuleerd; het factuurnummer, gegevens en oorspronkelijke status blijven bewaard voor herstel via Verwijderde testfacturen → Terugzetten. De testmarkering kan daarna ook worden opgeheven. Er is geen automatische classificatie van bestaande facturen en er worden geen productiefacturen automatisch opgeruimd. Betaalde facturen en facturen met een eerdere betaaldatum worden geblokkeerd voor deze acties.

Toegang vereist een beheeraccount, een geldige WordPress-nonce en expliciete bevestiging. Verwijderde testfacturen zijn verborgen in de bestaande websiteoverzichten, administratie en native facturenlijsten. De bestaande bedragen, factuurnummerteller en abonnementen blijven behouden.

Installeer RVAZ-Wonen-Native-API-1.2.1.zip als vervanging van de bestaande RVAZ Wonen Native API-plugin. De bestaande RVAZ Wonen-plugin blijft actief. De productie-installatie rapporteerde vóór deze update versie 1.2.0. Het screenshot uit de chat was niet beschikbaar op het opgegeven pad; de diagnose kwam uit de bestaande broncode.

Validatie: 125 website/API-controles geslaagd (Actions 37892446474), inclusief een Chromium-test voor de volledige nieuwe fotobediening en tests voor verwijderen, verbergen, herstellen en bescherming van betaalde facturen. Flutter-analyse en alle 20 tests geslaagd (Actions 37892446445). ZIP-inhoud exact vergeleken met de 13 geteste GitHub-bronbestanden; integriteit geslaagd. ZIP SHA256: 9756a5d91b8dc8b2d781a1458426376bf9cc2cdac7d621ce63f8d9ebdf543884.
