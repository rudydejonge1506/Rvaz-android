# Native family notices

The Flutter FamilyPage and FamilyEditorPage use native widgets and the existing RVAZ app token. No website form or WebView is involved.

`rvaz-family-native-api.php` is the adapter for the existing `RVAZ_Family` post type, styling metadata, private image storage and editorial moderation. It reuses the existing App API token validator via RVAZ_Wonen_Native_API. It never accepts a client author or publication status.

Production deployment 2026-11-02: appended the adapter class and rest_api_init hook to the existing family plugin main file using WordPress Plugin Editor, increasing RVAZ Familieberichten from 1.3.0 to 1.3.1. The separate adapter ZIP must therefore NOT be activated on this installation: it would duplicate the class. Original website submissions, admin moderation and account management remain in the original plugin.

Public API: GET /rvaz-family/v1/notices (kind/page filters). Authenticated: GET /mine, POST /notices (multipart), DELETE /notices/{id} (own posts to Trash only). All new posts are pending editorial approval. Private image previews are returned only to the owning account; public responses do not contain pending content or private metadata.

Widget checks exercise the native designer at phone width and API error handling. Disposable WordPress integration checks anonymous access, ownership, pending publication, consent, enum validation, image requirement, idempotent retry and recoverable deletion. Production read-only health checks confirm public listing and anonymous rejection of /mine. No fictitious notice is published to production by these checks.
