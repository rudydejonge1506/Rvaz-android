"""Prepare a NEW, unsubmitted consumable product. Never modify approved products or submit review."""
import json,os,time,urllib.request,urllib.error
from decimal import Decimal
import jwt
BASE='https://api.appstoreconnect.apple.com'
now=int(time.time())
token=jwt.encode({'iss':os.environ['API_ISSUER_ID'],'iat':now,'exp':now+600,'aud':'appstoreconnect-v1'},os.environ['API_KEY_P8'],algorithm='ES256',headers={'kid':os.environ['API_KEY_ID'],'typ':'JWT'})
def request(path,method='GET',body=None,allow_missing=False):
 url=path if path.startswith(BASE+'/') else BASE+path
 assert url.startswith(BASE+'/')
 headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'}
 try:
  with urllib.request.urlopen(urllib.request.Request(url,data=json.dumps(body).encode() if body is not None else None,method=method,headers=headers),timeout=30) as r:return json.load(r)
 except urllib.error.HTTPError as e:
  if allow_missing and e.code==404:return None
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

# Complete only metadata and the initial price of our unsubmitted draft.
# No availability change, review submission, or release publication is performed.
localizations=request('/v2/inAppPurchases/'+pid+'/inAppPurchaseLocalizations?limit=50')['data']
if not any(x['attributes']['locale']=='nl-NL' for x in localizations):
 request('/v1/inAppPurchaseLocalizations','POST',{'data':{'type':'inAppPurchaseLocalizations','attributes':{'name':'Woning of kamer: één maand','description':'Eén plaatsing voor één maand. Eenmalig.','locale':'nl-NL'},'relationships':{'inAppPurchaseV2':{'data':{'type':'inAppPurchases','id':pid}}}}})
print('APPLE_DUTCH_LOCALIZATION_PREPARED',flush=True)
schedule=request('/v2/inAppPurchases/'+pid+'/iapPriceSchedule',allow_missing=True)
if schedule is None or not schedule.get('data'):
 schedule=request('/v1/inAppPurchasePriceSchedules','POST',{'data':{'type':'inAppPurchasePriceSchedules','relationships':{'inAppPurchase':{'data':{'type':'inAppPurchases','id':pid}},'baseTerritory':{'data':{'type':'territories','id':'NLD'}},'manualPrices':{'data':[{'type':'inAppPurchasePrices','id':'${rvaz-price}'}]}}},'included':[{'type':'inAppPurchasePrices','id':'${rvaz-price}','attributes':{'startDate':None},'relationships':{'inAppPurchaseV2':{'data':{'type':'inAppPurchases','id':pid}},'inAppPurchasePricePoint':{'data':{'type':'inAppPurchasePricePoints','id':match[0]['id']}}}}]})
prices=request('/v1/inAppPurchasePriceSchedules/'+schedule['data']['id']+'/manualPrices?filter[territory]=NLD&include=inAppPurchasePricePoint')
actual=[x for x in prices.get('included',[]) if x['type']=='inAppPurchasePricePoints']
assert actual and all(Decimal(x['attributes']['customerPrice'])==Decimal('25.00') for x in actual),'Draft price must be exactly EUR25; do not change any established schedule'
print('APPLE_INITIAL_NLD_PRICE_VERIFIED=25.00',flush=True)
print('APPLE_DRAFT_REMAINS_UNSUBMITTED='+request('/v2/inAppPurchases/'+pid)['data']['attributes']['state'],flush=True)

# Configure only this unsubmitted test product and the sandbox callback.
availability=request('/v2/inAppPurchases/'+pid+'/inAppPurchaseAvailability',allow_missing=True)
if availability is None or not availability.get('data'):
 availability=request('/v1/inAppPurchaseAvailabilities','POST',{'data':{'type':'inAppPurchaseAvailabilities','attributes':{'availableInNewTerritories':False},'relationships':{'inAppPurchase':{'data':{'type':'inAppPurchases','id':pid}},'availableTerritories':{'data':[{'type':'territories','id':'NLD'}]}}}})
territories=request('/v1/inAppPurchaseAvailabilities/'+availability['data']['id']+'/availableTerritories?limit=200')['data']
assert any(x['id']=='NLD' for x in territories),'Netherlands purchase availability missing'
print('APPLE_TEST_PRODUCT_NLD_AVAILABILITY_VERIFIED',flush=True)
callback='https://www.regiovoorneaanzee.nl/wp-json/rvaz-wonen/v1/winkel/apple-melding'
app=request('/v1/apps/6817375521?fields[apps]=subscriptionStatusUrlForSandbox,subscriptionStatusUrlVersionForSandbox')['data']
current=app['attributes'].get('subscriptionStatusUrlForSandbox')
assert current in [None,'',callback],'Never overwrite another sandbox callback'
if current!=callback or app['attributes'].get('subscriptionStatusUrlVersionForSandbox')!='V2':
 request('/v1/apps/6817375521','PATCH',{'data':{'type':'apps','id':'6817375521','attributes':{'subscriptionStatusUrlForSandbox':callback,'subscriptionStatusUrlVersionForSandbox':'V2'}}})
after=request('/v1/apps/6817375521?fields[apps]=subscriptionStatusUrlForSandbox,subscriptionStatusUrlVersionForSandbox')['data']['attributes']
assert after['subscriptionStatusUrlForSandbox']==callback and after['subscriptionStatusUrlVersionForSandbox']=='V2'
print('APPLE_SANDBOX_CALLBACK_V2_VERIFIED',flush=True)
print('APPLE_TEST_PRODUCT_STILL_UNSUBMITTED='+request('/v2/inAppPurchases/'+pid)['data']['attributes']['state'],flush=True)
