"""Anonymous read-only contract check; never creates a public test notice."""
import json, urllib.request, urllib.error
base='https://www.regiovoorneaanzee.nl/wp-json/rvaz-family/v1/'
with urllib.request.urlopen(base+'notices',timeout=30) as r:
    data=json.load(r)
    assert isinstance(data['items'],list) and isinstance(data['has_more'],bool)
    for n in data['items']:
        assert not any(k in n for k in ['image_base64','email','author','status'])
for path in ['mine']:
    try:
        urllib.request.urlopen(base+path,timeout=30)
        raise AssertionError('Private notices must require the app account')
    except urllib.error.HTTPError as e:
        assert e.code==401
print('Live native family API available; private notices require authentication.')
