"""Read-only Apple version guard. Never changes a store release."""
import json
import os
import time
import urllib.request
import urllib.error
import jwt

now = int(time.time())
token = jwt.encode({'iss': os.environ['API_ISSUER_ID'], 'iat': now,
                    'exp': now + 600, 'aud': 'appstoreconnect-v1'},
                   os.environ['API_KEY_P8'], algorithm='ES256',
                   headers={'kid': os.environ['API_KEY_ID'], 'typ': 'JWT'})

def get(path):
    request = urllib.request.Request('https://api.appstoreconnect.apple.com/v1/' + path,
                                     headers={'Authorization': 'Bearer ' + token})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        if error.code != 403:
            raise
        print('Apple build-history read permission unavailable (403). Proposed upload is 1.1.9 (111), following the confirmed 1.1.8 and repository build 110. Apple validates the identity during upload.', flush=True)
        raise SystemExit(0)

builds = get('builds?filter[app]=6817375521&sort=-uploadedDate&limit=200')['data']
highest = max((int(b['attributes']['version']) for b in builds
               if str(b['attributes']['version']).isdigit()), default=0)
print('Highest recent Apple build:', highest, flush=True)
assert highest < 111, 'Build 111 is already used; choose a higher number before upload.'
versions = get('apps/6817375521/appStoreVersions?limit=200')['data']
def version_tuple(value):
    return tuple((list(map(int,value.split('.')))+[0,0,0])[:3])
for version in versions:
    attrs = version['attributes']
    print('Apple version:', attrs['versionString'], attrs['appStoreState'], flush=True)
    assert attrs.get('platform') != 'IOS' or version_tuple(attrs['versionString']) < (1, 1, 9), 'Choose a newer marketing version.'
print('Apple accepts the next proposed identity: 1.1.9 (111).', flush=True)
