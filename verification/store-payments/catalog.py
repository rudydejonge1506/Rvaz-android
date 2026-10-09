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

# Focused read-only checkout diagnostics; never log keys or purchase receipts.
def inspect(path,label):
 try:
  with urllib.request.urlopen(urllib.request.Request('https://api.appstoreconnect.apple.com'+path,headers={'Authorization':'Bearer '+token}),timeout=30) as r:data=json.load(r)
  print(label+'='+json.dumps(data.get('data')),flush=True)
  return data.get('data')
 except urllib.error.HTTPError as e:
  print(label+'_HTTP='+str(e.code),flush=True)
for x in catalog['data']:
 if x['attributes']['productId']=='rvaz.wonen.particulier.maand':
  pid=x['id']
  inspect('/v2/inAppPurchases/'+pid+'/inAppPurchaseLocalizations?limit=50','APPLE_CHECKOUT_LOCALIZATIONS')
  availability=inspect('/v2/inAppPurchases/'+pid+'/inAppPurchaseAvailability','APPLE_CHECKOUT_AVAILABILITY')
  if availability:
   inspect('/v1/inAppPurchaseAvailabilities/'+availability['id']+'/availableTerritories?limit=200','APPLE_CHECKOUT_TERRITORIES')
  inspect('/v2/inAppPurchases/'+pid+'/appStoreReviewScreenshot','APPLE_CHECKOUT_REVIEW_SCREENSHOT')
inspect('/v1/apps/6817375521?fields[apps]=bundleId,subscriptionStatusUrl,subscriptionStatusUrlVersion,subscriptionStatusUrlForSandbox,subscriptionStatusUrlVersionForSandbox','APPLE_CHECKOUT_NOTIFICATION_SETTINGS')
