"""Read-only App Store Connect verification after upload; never submit a release."""
import json
import os
import time
import urllib.request

import jwt

for attempt in range(60):
    now = int(time.time())
    token = jwt.encode({'iss': os.environ['API_ISSUER_ID'], 'iat': now,
                        'exp': now + 600, 'aud': 'appstoreconnect-v1'},
                       os.environ['API_KEY_P8'], algorithm='ES256',
                       headers={'kid': os.environ['API_KEY_ID'], 'typ': 'JWT'})
    url = ('https://api.appstoreconnect.apple.com/v1/builds'
           '?filter[app]=6817375521&filter[version]=90&include=preReleaseVersion')
    request = urllib.request.Request(url, headers={'Authorization': 'Bearer ' + token})
    with urllib.request.urlopen(request, timeout=30) as response:
        data = json.load(response)
    builds = data['data']
    if builds:
        assert len(builds) == 1, 'Unexpected duplicate build 90'
        build = builds[0]
        state = build['attributes']['processingState']
        print('Apple build 90 processing state:', state, flush=True)
        if state == 'VALID':
            versions = {x['id']: x['attributes']['version']
                        for x in data.get('included', [])
                        if x['type'] == 'preReleaseVersions'}
            version_id = build['relationships']['preReleaseVersion']['data']['id']
            assert versions[version_id] == '1.1.4'
            print('Verified TestFlight build 1.1.4 (90):', build['id'], flush=True)
            break
        if state in ('FAILED', 'INVALID'):
            raise SystemExit('Apple rejected the uploaded build: ' + state)
    else:
        print('Waiting for Apple to list build 90.', flush=True)
    time.sleep(30)
else:
    raise SystemExit('TestFlight processing was not verified within 30 minutes.')
