"""Read-only App Store Connect verification after upload; never submit a release."""
import json
import os
import time
import urllib.request
import urllib.error

import jwt

build_number=os.environ.get('RVAZ_IOS_BUILD','99')
version_name=os.environ.get('RVAZ_IOS_VERSION','1.1.4')
for attempt in range(60):
    now = int(time.time())
    token = jwt.encode({'iss': os.environ['API_ISSUER_ID'], 'iat': now,
                        'exp': now + 600, 'aud': 'appstoreconnect-v1'},
                       os.environ['API_KEY_P8'], algorithm='ES256',
                       headers={'kid': os.environ['API_KEY_ID'], 'typ': 'JWT'})
    url = ('https://api.appstoreconnect.apple.com/v1/builds'
           f'?filter[app]=6817375521&filter[version]={build_number}&include=preReleaseVersion')
    request = urllib.request.Request(url, headers={'Authorization': 'Bearer ' + token})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            data = json.load(response)
    except urllib.error.HTTPError as error:
        if error.code != 403:
            raise
        print(f'Build {version_name} ({build_number}) uploaded in the preceding step. Apple processing status cannot be read with this API key (HTTP 403).', flush=True)
        break
    builds = data['data']
    if builds:
        assert len(builds) == 1, f'Unexpected duplicate build {build_number}'
        build = builds[0]
        state = build['attributes']['processingState']
        print(f'Apple build {build_number} processing state:', state, flush=True)
        if state == 'VALID':
            versions = {x['id']: x['attributes']['version']
                        for x in data.get('included', [])
                        if x['type'] == 'preReleaseVersions'}
            version_id = build['relationships']['preReleaseVersion']['data']['id']
            assert versions[version_id] == version_name
            print(f'Verified TestFlight build {version_name} ({build_number}):', build['id'], flush=True)
            break
        if state in ('FAILED', 'INVALID'):
            raise SystemExit('Apple rejected the uploaded build: ' + state)
    else:
        print(f'Waiting for Apple to list build {build_number}.', flush=True)
    time.sleep(30)
else:
    raise SystemExit('TestFlight processing was not verified within 30 minutes.')
