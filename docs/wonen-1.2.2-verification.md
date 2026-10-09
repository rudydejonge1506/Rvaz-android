# RVAZ Wonen 1.2.2

Deze websiteupdate bevat de fotobediening vóór eerste opslag en het herstelbare testfactuurbeheer van 1.2.1, plus:

- Op Registreren: Lezer, Bedrijf/adverteerder en Makelaar. Makelaar gebruikt de bestaande bedrijfsregistratie en e-mailbevestiging. De kantoornaam en aanvraagintentie worden onthouden. Publicatierechten worden pas na de bestaande makelaarsaanvraag en RVAZ-goedkeuring toegekend.
- Particulier woningaanbod staat in /account/ onder Mijn Wonen: plaatsen, kenmerken, foto's, beoordeling, facturen en reacties. Het particuliere formulier verdwijnt van de openbare Wonen-pagina; daar staat een verwijzing naar Mijn account. Andere accounttabbladen behouden hun eigen inhoud en navigatie.
- WordPress → Wonen → Factuur + Tikkie: beheerder plakt een zelf aangemaakte HTTPS Tikkie-link, slaat deze op en verstuurt op expliciete bevestiging de PDF-factuur en betaallink naar de eigenaar van de factuur. Zowel makelaarsfacturen als particuliere facturen worden ondersteund. Een mail wijzigt de betaalstatus niet. Verwijderde/geannuleerde of betaalde facturen krijgen via deze functie geen nieuw betaalverzoek. Tijdelijke PDF-bestanden worden na verzending verwijderd.

Tikkie-links worden handmatig aangemaakt; er is geen Tikkie-API of automatische betaalstatuskoppeling ingesteld. De Funda/CRM-import is nog niet aangesloten: CRM-keuze, officiële API-toegang en toestemming van de makelaar ontbreken. Er worden geen importkosten geïnd en er worden geen woningen van Funda gekopieerd.

De screenshots zijn na hernieuwde beschikbaarstelling bekeken: de registratie bood alleen reader/business; de particuliere pagina toonde inderdaad eerst het volledige formulier zonder fotokeuze vóór eerste opslag. Deze routes zijn in de update aangepast.

Deze API-/websiteupdate blijft compatibel met Android 55 en iOS 1.1.4 (89). Er is geen nieuwe appbuild of publieke apprelease nodig. Installeer RVAZ-Wonen-Native-API-1.2.2.zip als vervanging van de bestaande RVAZ Wonen Native API-plugin. Behoud de bestaande RVAZ Wonen-plugin. De live website rapporteerde vóór deze update 1.2.0.
