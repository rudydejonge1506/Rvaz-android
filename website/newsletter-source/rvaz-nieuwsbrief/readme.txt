RVAZ Nieuwsbrief 1.4.4
- Afbeeldingen via publieke HTTPS-URL's; geen CID/inline bijlagen.
- Eigen RVAZ Advertentiebeheer-shortcodes voor nieuwsbriefposities.
- Geen Advanced Ads-shortcodes meer in nieuwsbriefinstellingen.
- Adminmenu en statistieken behouden.

1.4.6
- Nieuwsbrief-evenementen komen rechtstreeks uit RVAZ Evenementen / het WordPress post type event.
- Geen afhankelijkheid meer van de Events Manager classes.
- Alleen goedgekeurde toekomstige evenementen worden opgenomen.

1.4.7
- RVAZ Evenementen 1.1-integratie: tijd, locatie, entree en herhaling kunnen in het evenementenoverzicht van de nieuwsbrief worden getoond.

1.4.8: evenementen komen uitsluitend uit RVAZ Evenementen (rvaz_event), niet meer uit Events Manager.

1.4.9
- Nieuwsbrief-admin blijft bereikbaar als een externe integratie een fout veroorzaakt.
- RVAZ Evenementen-koppeling geïsoleerd en defensief gemaakt.
- Alleen het eigen posttype rvaz_event wordt gelezen.
- Bij een probleem met evenementen wordt het evenementenblok overgeslagen in plaats van de hele adminpagina fataal te maken.

1.5.0
- Herstelt ontbrekende afbeeldingsfuncties in 1.4.9.
- Logo's, uitgelichte afbeeldingen en bedrijfslogo's worden weer opgebouwd met publieke afbeeldings-URL's.
- Behoudt de foutafhandeling van het nieuwsbriefvoorbeeld.

1.5.1
- Herstelt ontbrekende tracked_html() waardoor echte verzending in 1.5.0 fataal kon stoppen.
- Herstelt region_from_ip() voor klikregistratie; privacy-first standaard zonder opslag van IP-adres.
- Kliklinks en openpixel worden weer veilig aan echte nieuwsbrieven toegevoegd.

1.6.0
- Nieuwsbrieven worden in een wachtrij geplaatst en in batches van maximaal 800 e-mails per uur verzonden.
- Handmatig verzenden blokkeert het beheerscherm niet meer terwijl alle abonnees worden verwerkt.
- Per nieuwsbrief: status, totaal, verzonden, mislukt, unieke opens, klikken, unieke klikkers en CTR.
- De inhoud/postselectie wordt bij het aanmaken van de mailing vastgezet voor alle batches.
- Bescherming tegen dubbele batches via lock en minimaal 55 minuten tussen batches.
- Kliktracking-URL gecorrigeerd naar base64-codering die aansluit op de bestaande click-handler.
- WP-Cron is verkeersafhankelijk; een echte server-cron kan worden gebruikt voor strakkere timing.

1.6.1
- Verzending opgesplitst in kleine batches van 20 adressen om time-outs/providerlimieten rond 25 mails per proces te voorkomen.
- Harde bovengrens van 800 verzendpogingen per uur per nieuwsbrief; batches worden ongeveer elke 90 seconden gepland via WP-Cron.
- Actieve verzending kan vanuit het dashboard worden gepauzeerd en hervat.
- Onderwerp en inhoud van een lopende/gepauzeerde nieuwsbrief kunnen worden gewijzigd; wijzigingen gelden alleen voor resterende ontvangers.
- Inhoud wordt per mailing als snapshot opgeslagen; statistieken blijven per afzonderlijke nieuwsbrief bijgehouden.

1.6.2
- Zelfherstel van ontbrekende wachtrij-kolommen na upgrades.
- Geeft de echte database- of cronfout weer wanneer inplannen mislukt.
- Controleert expliciet of de eerste verzendtaak is aangemaakt.
- Bij een cronfout blijft de nieuwsbrief veilig gepauzeerd staan.

1.6.3
- Actieve verzendwachtrij kan nu worden gepauzeerd, hervat, inhoudelijk gewijzigd, hersteld of geannuleerd.
- Herstelt oude wachtrijen die na een upgrade als 0 van 0 bleven staan door het actuele aantal bevestigde abonnees opnieuw vast te leggen.
- Geannuleerde verzendingen bewaren reeds verzonden aantallen/statistieken en versturen niets meer naar resterende ontvangers.

1.6.4
- Nieuwe verzendingen maken eerst een volledige, vaste ontvangerssnapshot van alle bevestigde abonnees.
- De worker verwerkt uitsluitend die snapshot, zodat een querylimiet van 25 nooit het totale verzendbereik bepaalt.
- Wachtrij herstellen repareert ook oude 25/25-wachtrijen.
- Per ontvanger wordt pending/sent/failed bijgehouden.
- Bij oude wachtrijen worden alleen ontvangers met aantoonbare tracking als reeds verwerkt gemarkeerd; een oude teller alleen is niet voldoende bewijs om adressen over te slaan.

1.6.5
- Herstelt de statuslogica van de verzendwachtrij.
- queued/sending met alle ontvangers verwerkt wordt automatisch completed.
- lege 0/0 queued/sending records worden automatisch cancelled en blokkeren niets meer.
- de nieuwste echte actieve mailing krijgt voorrang boven oude foutieve records.
- snapshot-status per ontvanger wordt bij upgrade opnieuw met de mailingstatistieken gesynchroniseerd.
- een achtergebleven batch-lock wordt bij upgrade verwijderd zodat een geldige 0/1807-mailing weer kan doorlopen.

1.6.6
- Oorzaak van vastlopende batches opgelost: verzending is niet langer afhankelijk van een keten van losse WP-Cron single events.
- Vaste worker draait iedere minuut en pakt een actieve wachtrij automatisch weer op.
- Bij upgrade worden oude losse worker-events en een achtergebleven lock opgeruimd.
- Pauzeren stopt verwerking; hervatten activeert de vaste worker en start direct een batch.
- De limiet van maximaal 800 verzendpogingen per uur blijft gehandhaafd.

1.6.7
- Diagnose uit live statistiek verwerkt: 5 verzonden + 35 mislukt betekent dat de worker wel draait, maar wp_mail bij veel adressen faalt.
- Batchgrootte verlaagd naar 5 per worker-run om hosting/mailtransport niet langdurig in één PHP-proces te belasten.
- Mislukte adressen worden niet direct definitief afgeschreven: maximaal 3 pogingen, met 5 minuten tussen retries.
- wp_mail_failed wordt opgeslagen per ontvanger zodat de werkelijke mailfout zichtbaar/traceerbaar blijft.
- Een wachtrij wordt niet meer voltooid wanneer ontvangers alleen tijdelijk op een retry wachten.
- Maximaal 800 verzendpogingen per uur blijft als harde bovengrens gelden.

1.6.8
- Verzendtempo: maximaal 800 verzendpogingen per uur.
- Maximaal 20 per batch met minimaal 90 seconden tussen batches.
- Harde uurgrens van 800 blijft actief.

1.6.9
- Herstelt onterecht voltooide mailings waarbij sent + failed lager is dan het ontvangerstotaal.
- Vult ontbrekende snapshot-ontvangers aan zonder reeds verzonden ontvangers opnieuw te mailen.
- Voortgang wordt opnieuw uit de recipient-snapshot berekend.
- Een mailing wordt alleen voltooid als geen pending ontvangers meer bestaan en snapshot sent + failed exact gelijk is aan het snapshot-totaal.
- Verzendlimiet blijft maximaal 800 pogingen per uur.


1.7.5
- Op de statistiek/detailpagina van een gepauzeerde handmatige mailing staat nu een duidelijke knop ‘Verzending starten’.
- Toont het aantal resterende ontvangers en vraagt om bevestiging voor starten.
- Bij actieve verzending verschijnt op dezelfde plek ‘Verzending pauzeren’.
- Na starten blijft de beheerder op de statistiekpagina van dezelfde mailing.


1.9.7
- Nieuw eenmalig sjabloon onder RVAZ Nieuwsbrief > Nieuwsbrief maken: RVAZ Wonen – uitnodiging makelaars.
- Sjabloon kiest verzendlijst Makelaars, stelt onderwerp in en biedt correcte aanmeld- en tarievenlinks.
- Eenmalig zakelijk bericht vermeldt uitdrukkelijk dat ontvangers geen nieuwsbriefabonnees zijn.
- Opslaan maakt uitsluitend een gepauzeerd concept, geen verzending.
- Eerste twee makelaarskantoren: eerste maand gratis, uitsluitend na handmatige bevestiging.
- Makelaars-only contacten worden uitgesloten van reguliere automatische nieuwsbrieven; een specifiek op Makelaars gericht concept blijft mogelijk.

1.9.8
- Makelaarsuitnodiging: toegevoegd dat opzeggen op ieder moment eenvoudig kan via Mijn Wonen.

1.10.0: Alleen template Wonen makelaars bijgewerkt met kortingscode MAKELAAR, maximaal twee gratis eerste maanden en eenvoudige gebruiksinstructie. Geen verzending of lijstwijziging.

== 1.10.0 ==
Vernieuwde makelaarsuitnodiging met kortingscode en eenvoudige stappen. Wonen op Voorne in reguliere nieuwsbrieven en als editorblok. Geen wijzigingen aan kortingscodes of verzending.
