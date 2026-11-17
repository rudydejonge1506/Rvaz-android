"""Read-only App Store Connect verification after upload; never submit a release."""
import json
import os
import time
import urllib.request
import urllib.error

import jwt

for attempt in range(60):
    now = int(time.time())
    token = jwt.encode({'iss': os.environ['API_ISSUER_ID'], 'iat': now,
                        'exp': now + 600, 'aud': 'appstoreconnect-v1'},
                       os.environ['API_KEY_P8'], algorithm='ES256',
                       headers={'kid': os.environ['API_KEY_ID'], 'typ': 'JWT'})
    url = ('https://api.appstoreconnect.apple.com/v1/builds'
           '?filter[app]=6817375521&sort=-uploadedDate&limit=200')
    request = urllib.request.Request(url, headers={'Authorization': 'Bearer ' + token})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            data = json.load(response)
    except urllib.error.HTTPError as error:
        if error.code != 403:
            raise
        print('Apple upload 1.1.9 (111) completed in preceding step. Processing cannot be read using this key (403).', flush=True)
        break
    builds = [b for b in data['data'] if b['attributes']['version']=='111']
    if builds:
        assert len(builds) == 1, 'Unexpected duplicate build 111'
        build = builds[0]
        state = build['attributes']['processingState']
        print('Apple build 111 processing state:', state, flush=True)
        if state == 'VALID':
            print('Verified Apple processing for uploaded 1.1.9 (111):', build['id'], flush=True)
            break
        if state in ('FAILED', 'INVALID'):
            raise SystemExit('Apple rejected the uploaded build: ' + state)
    else:
        print('Waiting for Apple to list build 111.', flush=True)
    time.sleep(30)
else:
    raise SystemExit('TestFlight processing was not verified within 30 minutes.')
