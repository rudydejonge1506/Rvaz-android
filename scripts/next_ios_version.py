"""Read App Store Connect build numbers before building; never change releases."""
import json
import os
import time
import urllib.request
import urllib.error
import jwt

def read(path):
    now=int(time.time())
    token=jwt.encode({'iss':os.environ['API_ISSUER_ID'],'iat':now,'exp':now+600,'aud':'appstoreconnect-v1'},os.environ['API_KEY_P8'],algorithm='ES256',headers={'kid':os.environ['API_KEY_ID'],'typ':'JWT'})
    request=urllib.request.Request('https://api.appstoreconnect.apple.com/v1/'+path,headers={'Authorization':'Bearer '+token})
    with urllib.request.urlopen(request,timeout=30) as response:
        return json.load(response)

# All pages, including older builds, so an already-used number is never reused.
path='builds?filter[app]=6817375521&limit=200&include=preReleaseVersion'
numbers=[]
versions=[(1,1,4)]
while path:
    try:
        result=read(path)
    except urllib.error.HTTPError as error:
        if error.code != 403:
            raise
        print('Apple API key does not allow reading build history (HTTP 403).')
        print('Use the next number after the last verified repository build 99; Apple validates it again during upload.')
        break
    numbers.extend(int(x['attributes']['version']) for x in result['data'] if x['attributes']['version'].isdigit())
    for item in result.get('included',[]):
        if item['type']=='preReleaseVersions':
            parts=item['attributes']['version'].split('.')
            if all(p.isdigit() for p in parts):
                versions.append(tuple((list(map(int,parts))+[0,0,0])[:3]))
    next_url=result.get('links',{}).get('next')
    if next_url and not next_url.startswith('https://api.appstoreconnect.apple.com/v1/'):
        raise SystemExit('Unexpected Apple pagination URL')
    path=next_url.split('/v1/',1)[1] if next_url else None
build=max(numbers+[99])+1
major,minor,patch=max(versions)
version=f'{major}.{minor}.{patch+1}'
print(f'Next Apple upload: {version} ({build}); highest existing build: {max(numbers,default=99)}')
with open(os.environ['GITHUB_OUTPUT'],'a') as out:
    out.write(f'build={build}\nversion={version}\n')
