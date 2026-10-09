# Wonen dashboard, favorites and search alerts

Implemented on ios-current-features-safe; Android candidate 54 (0.6.4), iOS TestFlight 1.1.4 (88), additive WordPress plugin 1.1.0.

The app and website use the same authenticated rvaz-wonen/v1 routes and WordPress account user metadata. Reader routes do not require realtor privileges. Existing mobile bearer tokens are validated through the existing RVAZ App API; cookie requests require WordPress REST nonces. Favorites and search profiles are private to the current account. No user ID supplied by a client changes the account scope.

A search supports an exact town, purchase/rental, property type, minimum and maximum price. At least one filter is required. Prices use the same purchase/rental currency amounts as the listing; no currency conversions. Max 10 saved searches and 1000 favorites per account. Existing matches become the initial baseline. Matching newly available published stock creates one account notification per search/property pair, with a maximum retained history of 200 notices. Sold/rented stock creates no new notifications. Scans run hourly through WordPress cron and on opening the notification center. There is currently no email or push delivery. Supply a real server cron for predictable background timing on low traffic sites. Scans use the existing public API's most recent 100 listings.

The realtor dashboard shows actual publication totals, new inquiries, views, the current subscription and remaining publication space. It flags missing address/town/price/transaction/photo data without changing existing listings. It does not invent statistics or billing prices.

## Installation

Replace only **RVAZ Wonen Native API** with RVAZ-Wonen-Native-API-1.1.0.zip via WordPress Plugins > Add Plugin > Upload Plugin > Replace current. Keep the existing RVAZ Wonen base plugin, theme and other API plugins active. The update preserves historical invoices and account metadata. No database reset is required. Website additions appear in the existing Wonen and Mijn Wonen shortcodes; no PHP snippet needs activation.

After installation verify an ordinary reader account can save a public listing on the website and see the same favorite in app build 88/54. Verify another account cannot see it. Save a search, publish an actual new matching property through a realtor account, refresh notices, verify exactly one alert and read marking. Do not publish synthetic listings on the live site merely for testing.

## Official CRM import: pending provider/access

The user chose a connection through realtor CRM software. The actual provider, developer registration, authorized account credentials and data-owner permission are not yet supplied. No scraper, Funda HTML importer, speculative API requests or paid unavailable import option has been added.

Primary sources checked 2026-10-09:
- https://www.realworks.nl/api: Realworks Wonen API exports object information; a realtor orders access via its Marketplace and connects a registered developer ID.
- https://developers.realworks.nl/: owner permission is required for bulk storage; credentials are issued through the developer platform.
- https://start.kolibri.software/: SiteLink supports object information on external websites.
- https://www.funda.nl/voorwaarden-en-beleid/aansluitvoorwaarden/funda/: commercial access and third-party rights must be arranged.

Proposed paid import acceptance criteria once access is provided:
1. Account-scoped provider authorization for the subscribing realtor; never share credentials with the mobile app or expose them in REST results.
2. Import is unavailable without an active paid RVAZ subscription; enforce the existing publication quota.
3. Retrieve only authorized, publicly releasable fields/photos. Exclude seller/buyer personal data even if a CRM response includes it.
4. Stable provider/object IDs, idempotent updates and collision protection across offices.
5. Preview imported data and missing fields before publication. Do not overwrite realtor edits without a clear field ownership policy.
6. Synchronize withdrawn/sold/rented states and disclose last successful synchronization and errors.
7. Agree the import tariff before billing. No new prices or subscription charges have been created.

## Verification

GitHub Actions runs real PHP/WordPress REST integration tests, real HTTP bearer/multipart image tests, Flutter analysis/widget tests, exact original icon checks, signed Android release creation and Android 15 emulator startup, and signed iOS export/upload/Apple processing validation. Physical device testing and live deployment checks remain separate from CI.
