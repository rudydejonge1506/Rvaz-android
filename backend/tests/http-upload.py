"""Real multipart upload and authenticated REST checks in disposable CI WordPress."""
import base64
import json
import urllib.request

api = 'http://127.0.0.1:8099/?rest_route=/rvaz-wonen/v1'
token = {'Authorization': 'Bearer VALID_APP_TOKEN'}

def request(path, data=None, content_type='application/json'):
    req = urllib.request.Request(api + path, data=data,
                                 headers={**token, 'Content-Type': content_type})
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)

item = request('/makelaar/woningen', json.dumps({'title': 'CI upload property'}).encode())
identifier = item['id']
# Small valid 1x1 RGB PNG; only synthetic content, no production images or account.
photo = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC')
boundary = 'rvaz-ci-multipart'
body = (f'--{boundary}\r\nContent-Disposition: form-data; name="photo"; filename="ci.png"\r\nContent-Type: image/png\r\n\r\n'.encode()
        + photo + f'\r\n--{boundary}--\r\n'.encode())
uploaded = request(f'/makelaar/woningen/{identifier}/fotos', body, f'multipart/form-data; boundary={boundary}')
assert len(uploaded['photos']) == 1, uploaded
assert uploaded['image'], uploaded
uploaded = request(f'/makelaar/woningen/{identifier}/galerij', json.dumps({'photo_ids': []}).encode())
assert uploaded['photos'] == [] and uploaded['image'] == '', uploaded
print('PASS: real authenticated multipart image upload and gallery removal')
token = {'Authorization': 'Bearer VALID_PRIVATE_TOKEN'}
item = request('/particulier/woningen', json.dumps({'title': 'CI private upload property'}).encode())
identifier = item['id']
uploaded = request(f'/particulier/woningen/{identifier}/fotos', body, f'multipart/form-data; boundary={boundary}')
assert len(uploaded['photos']) == 1 and uploaded['image'], uploaded
assert uploaded['publication_status'] == 'draft', uploaded
uploaded = request(f'/particulier/woningen/{identifier}/galerij', json.dumps({'photo_ids': []}).encode())
assert uploaded['photos'] == [] and uploaded['image'] == '', uploaded
print('PASS: ordinary private account authenticated photo upload and gallery removal')
