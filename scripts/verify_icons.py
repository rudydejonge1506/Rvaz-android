"""Fail closed unless official source, iOS and original Android icons match."""
import hashlib
import json
from pathlib import Path

provenance = json.loads(Path('assets/icon-provenance.json').read_text())
source = Path('assets/rvaz-android-original.png')
assert hashlib.sha256(source.read_bytes()).hexdigest() == provenance['source_sha256']
assert provenance['android_run'] == 37751531090
for path, record in provenance['android_icons'].items():
    icon = Path('android-icon-original') / path
    assert hashlib.sha256(icon.read_bytes()).hexdigest() == record['sha256'], path
config = json.loads(Path('ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json').read_text())
paths = {'ios/Runner/Assets.xcassets/AppIcon.appiconset/' + i['filename']
         for i in config['images'] if i.get('filename')}
assert paths == set(provenance['ios_icons']), 'Incomplete iOS icon provenance'
for path, digest in provenance['ios_icons'].items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == digest, path
print('Verified official RVAZ source, exact original Android PNGs and all iOS icons.')
