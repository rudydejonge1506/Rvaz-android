"""Prepare a NEW, unsubmitted consumable product. Never modify approved products or submit review."""
import json,os,time,urllib.request,urllib.error
from decimal import Decimal
import jwt
BASE='https://api.appstoreconnect.apple.com'
now=int(time.time())
token=jwt.encode({'iss':os.environ['API_ISSUER_ID'],'iat':now,'exp':now+600,'aud':'appstoreconnect-v1'},os.environ['API_KEY_P8'],algorithm='ES256',headers={'kid':os.environ['API_KEY_ID'],'typ':'JWT'})
def request(path,method='GET',body=None):
 url=path if path.startswith(BASE+'/') else BASE+path
 assert url.startswith(BASE+'/')
 headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'}
 try:
  with urllib.request.urlopen(urllib.request.Request(url,data=json.dumps(body).encode() if body is not None else None,method=method,headers=headers),timeout=30) as r:return json.load(r)
 except urllib.error.HTTPError as e:
  details=json.loads(e.read());print('APPLE_API_ERROR='+json.dumps(details),flush=True);raise
sku='rvaz.wonen.particulier.maand'
items=request('/v1/apps/6817375521/inAppPurchasesV2?limit=200')['data']
found=[x for x in items if x['attributes']['productId']==sku]
if not found:
 item=request('/v2/inAppPurchases','POST',{'data':{'type':'inAppPurchases','attributes':{'name':'RVAZ Wonen - woning of kamer een maand','productId':sku,'inAppPurchaseType':'CONSUMABLE','familySharable':False,'reviewNote':'One property listing for one calendar month from publication. Non-recurring. The property is moderated before payment. Test purchases do not publish a real paid listing.'},'relationships':{'app':{'data':{'type':'apps','id':'6817375521'}}}}})['data']
else:item=found[0]
assert item['attributes']['state'] not in ['APPROVED','IN_REVIEW','WAITING_FOR_REVIEW'],'Do not change an approved/submitted purchase'
pid=item['id'];print('APPLE_PRIVATE_IAP_DRAFT='+json.dumps({'id':pid,'productId':sku,'state':item['attributes']['state']}),flush=True)
points=request('/v2/inAppPurchases/'+pid+'/pricePoints?filter[territory]=NLD&limit=8000')['data']
match=[x for x in points if Decimal(x['attributes']['customerPrice'])==Decimal('25.00')]
assert len(match)==1,'An exact EUR25 Netherlands price is required; never substitute another amount.'
print('APPLE_EUR25_PRICE_POINT='+json.dumps({'id':match[0]['id'],'price':match[0]['attributes']['customerPrice'],'territory':'NLD'}),flush=True)
# Catalog preparation stops before availability or review submission.
