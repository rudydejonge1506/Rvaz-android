# RVAZ Android en iOS

De gedeelde Flutter-app voor Regio Voorne aan Zee. De newsroom-update staat op `feature/newsroom-design` en bouwt voort op de laatste geslaagde centrale-menuversie.

## Gedrag

- Nieuwste artikel als hoofdartikel, daarna compact nieuws. Per pagina 15 berichten; Meer laden voegt toe, verwijdert duplicaten en behoudt de scrollpositie. Vernieuwen begint een nieuwe selectie.
- PRO-bedrijven direct na de eerste vier berichten, uitsluitend de bestaande betaalde PRO-selectie.
- Vast: Nieuws, 112 & P2000, Agenda, Familie en Account. Het menu bovenaan behoudt Vouchers, Wonen, alle praktische functies en inzendingen.
- Originele logo-configuratie en bestaande launchericonen; `scripts/verify_icons.py` bewaakt de historische bestanden.
- Dosis en Open Sans worden lokaal meegeleverd; geen fontdownload tijdens het openen van de app.
- Nieuwslijst vraagt alleen openbare metadata op. Volledige artikelen gebruiken de bestaande App API en haar accountcontrole.
- Familie gebruikt het bestaande beveiligde websiteformulier binnen de app, met filters, kaartopmaak, eigen foto, beoordeling en eigen beheer. De website-aanmelding binnen Familie gebruikt hetzelfde bestaande RVAZ-account; er is nog geen automatische overdracht van de native aanmeldsessie. De native uitlogactie wist ook de ingebouwde websitecookies.
- Bestaande AdMob-toestemming, advertenties, vouchers, Wonen-betalingen en P2000-pushlogica blijven aanwezig.

## Release

Android-kandidaat: 0.7.0 (67). iOS-kandidaat: 1.2.0 (103). Apple-versies worden voor het bouwen via de bestaande beveiligde CI-sleutels gecontroleerd. Androidversie 67 is een kandidaat totdat Google Play zelf het nummer heeft gecontroleerd.

De CI voert analyse, regressietests, ondertekenings- en icooncontroles uit. De Android-release wordt ook op Android 15 gestart. Apple-upload naar TestFlight is geen publieke App Store-publicatie. Google Play-upload is een afzonderlijke stap.
