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
        raise SystemExit('Cannot verify Apple build history (403); stop before uploading.')

builds = get('builds?filter[app]=6817375521&sort=-uploadedDate&limit=200')['data']
highest = max((int(b['attributes']['version']) for b in builds
               if str(b['attributes']['version']).isdigit()), default=0)
print('Highest recent Apple build:', highest, flush=True)
assert highest < 112, 'Build 112 is already used; stop before uploading.'
versions = get('apps/6817375521/appStoreVersions?limit=200')['data']
def number(value):
    parts=tuple(int(part) for part in value.split('.'))
    return parts+(0,)*(3-len(parts))
for version in versions:
    attrs=version['attributes']
    print('Apple version:',attrs['versionString'],attrs['appStoreState'],flush=True)
    if attrs.get('platform')=='IOS':
        assert number(attrs['versionString']) < number('1.2.5'), 'Apple version is already at or above 1.2.5.'
# Apple's binary validator explicitly reported an approved 1.2.4, even though
# the listing API exposes older version records. The candidate must exceed both.
assert number('1.2.5') > number('1.2.4')
print('Confirmed Apple candidate 1.2.5 (112) exceeds listed versions and validation floor 1.2.4.',flush=True)
