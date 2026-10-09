"""Read-only Apple product readiness and public certificate capture. Never submit or publish."""
import base64,json,os,time,urllib.request,urllib.error
import jwt
now=int(time.time())
token=jwt.encode({'iss':os.environ['API_ISSUER_ID'],'iat':now,'exp':now+600,'aud':'appstoreconnect-v1'},os.environ['API_KEY_P8'],algorithm='ES256',headers={'kid':os.environ['API_KEY_ID'],'typ':'JWT'})
url='https://api.appstoreconnect.apple.com/v1/apps/6817375521/inAppPurchasesV2?limit=200'
try:
 with urllib.request.urlopen(urllib.request.Request(url,headers={'Authorization':'Bearer '+token}),timeout=30) as r:catalog=json.load(r)
 items=[{'id':x['id'],'productId':x['attributes']['productId'],'type':x['attributes']['inAppPurchaseType'],'state':x['attributes']['state']} for x in catalog['data']]
 print('APPLE_IAP_CATALOG='+json.dumps(items),flush=True)
except urllib.error.HTTPError as error:
 print('APPLE_IAP_CATALOG_ACCESS='+str(error.code),flush=True)
 raise
# Public CA only; contains no account credentials.
with urllib.request.urlopen('https://www.apple.com/certificateauthority/AppleRootCA-G3.cer',timeout=30) as r:cert=r.read()
print('APPLE_PUBLIC_ROOT_DER_BASE64='+base64.b64encode(cert).decode(),flush=True)
