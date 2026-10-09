# RVAZ Wonen Account Herstel 1.0.2

Aanvullende plugin voor RVAZ Wonen 1.0.6 en RVAZ Wonen Native API 1.2.4 met kortingscodes. Vervangt geen bestaande plugin.

## Installeren
Upload de ZIP via WordPress → Plugins → Nieuwe plugin → Plugin uploaden en activeer RVAZ Wonen Account Herstel.

## Gebruik
- Na opzegging: Mijn Wonen toont **Opnieuw een pakket kiezen**. Een nieuwe aanvraag gaat ter beoordeling naar RVAZ; oude facturen en aanvragen blijven behouden.
- Beheer: **Wonen → Makelaarsaccounts** → bevestigen → **Makelaarsaccount deactiveren**. Dit stopt het abonnement, verwijdert de makelaarsrol en zet makelaarswoningen op concept. Het gewone account en particuliere advertenties blijven behouden.
- De introductiekorting wordt niet herhaald. MAKELAAR is voor nieuwe makelaars. Een afzonderlijke toegangsblokkering blijft actief; deactiveren is geen deblokkeren.
- Mijn Wonen verbergt losse promotieblokken en de nieuws-sidebar. Favorieten blijven op het dashboard in een inklapbaar onderdeel.

## Terugdraaien
Deactiveer uitsluitend deze aanvullende plugin. Bestaande data en de oorspronkelijke Wonen-plugins blijven behouden. Een eerder bewust gedeactiveerd makelaarsaccount wordt hierdoor niet opnieuw geactiveerd.

Niet op de live website geïnstalleerd tijdens deze controle. Geen mails verzonden.

## 1.0.1
Particuliere formulieren krijgen een responsive indeling, huur/koopkeuze en huurkenmerken; bestaande kortingscode-invoer blijft behouden. Het opslaan gebruikt de oorspronkelijke eigenaar-, concept- en limietcontroles. Na makelaarsopzegging wordt de nieuwe-woningwizard vervangen door een pakketkeuze en worden API-schrijfacties geblokkeerd. Wonen → Makelaarsmailing bevat een verbeterd HTML-template en voorbeeld; niets wordt verzonden.

## 1.0.2
Borg, contractduur en inkomenseisen verschijnen uitsluitend bij Huur; prijsconditie uitsluitend bij Koop. Het particuliere formulier heeft dezelfde woningkenmerken als het makelaarsformulier, inclusief balkon, status en prijsconditie. Het nieuwsbriefmenu wordt nu door RVAZ Nieuwsbrief 1.10.0 geleverd; het losse kopieertemplate uit 1.0.1 wordt niet meer geladen. De bestaande kortingscodemodule wordt niet vervangen.
