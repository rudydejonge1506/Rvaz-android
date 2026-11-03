"""Public, read-only check of the exact metadata URL used by the app."""
import datetime
import json
import time
import urllib.request

before = datetime.datetime.now(datetime.timezone.utc).isoformat().replace('+00:00', 'Z')
seen = set()
for page in (1, 2):
    url = ('https://www.regiovoorneaanzee.nl/wp-json/wp/v2/posts'
           f'?per_page=15&page={page}&orderby=date&order=desc'
           '&_embed=wp:featuredmedia,wp:term'
           '&_fields=id,title,date,date_gmt,link,_links,_embedded'
           '&before=' + before)
    start = time.monotonic()
    with urllib.request.urlopen(urllib.request.Request(url, headers={'Accept': 'application/json'}), timeout=25) as response:
        items = json.load(response)
    assert isinstance(items, list) and items, 'No public news metadata received'
    assert all(isinstance(p, dict) and p.get('id') and p.get('title') for p in items), 'Invalid metadata response'
    assert all('content' not in p for p in items), 'Full content must use the protected App API'
    ids = {p['id'] for p in items}
    assert not seen.intersection(ids), 'Pagination returned duplicate posts'
    seen.update(ids)
    assert all(p.get('_embedded', {}).get('wp:featuredmedia') for p in items), 'Featured image data missing'
    print('Verified public news page', page, 'items', len(items), 'seconds', round(time.monotonic() - start, 2), flush=True)
print('Verified two distinct live news pages without fetching article bodies.', flush=True)
