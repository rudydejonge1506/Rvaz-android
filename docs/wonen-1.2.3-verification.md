# RVAZ Wonen 1.2.3

Source: 5dfdae7c1d3bf8c23bb22d977d18559c01839831.

Flutter analysis, tests and original icon verification passed in run 37894974114. Disposable real WordPress, browser, authenticated photo uploads and invoice attachment tests passed in run 37894974063. Email tests use a mocked mail transport; no production invoice was sent.

Website changes: photos during initial private draft creation; private housing inside /account/ Mijn Wonen; broker registration choice without self granting access; explicit unpaid test invoice removal/restoration; admin PDF invoice with manually entered HTTPS Tikkie link.

Public /rvaz-wonen/v1/uitgelicht returns at most six published properties. Private offers require payment, approval and an unexpired month. Brokers require an active subscription with an invoice paid within the current subscription period. Blocked owners, sold/rented housing and historical payments are excluded. Home cards follow PRO businesses and open native housing details.

ZIP: 18 production files, SHA256 d7b295e64f24f16c84234835f56684602bfcccd6384a4fd5d5444f4f6030fe3a.

Android56 (0.6.6): run37894974120; delivery37894974120 source artifact, draft GitHub attachment only. iOS1.1.4(90): run37894974208, TestFlight only. Completion must be verified before delivery. Public releases and existing icon assets were not changed.

Live site still uses 1.2.0. WPVibe plugin update reports no available update; its native installer accepts catalog slugs, not the custom ZIP. ZIP installation needs WordPress admin UI.

No Funda/CRM import is connected. No automatic Tikkie link generation, payment confirmation or store publication was added.
