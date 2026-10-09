<?php
require dirname(__DIR__,2).'/website/rvaz-wonen-store-payments/includes/contract.php';
$i=['id'=>'abcdefgh','provider'=>'apple','product'=>RVAZ_Store_Contract::PRODUCT,'amount'=>'25.00','currency'=>'EUR','period'=>'1_month','created'=>time()-60];
$i['id']='28a0921a-9e4b-4b7b-a12c-1efb75f91c02';
$a=['bundleId'=>RVAZ_Store_Contract::APPLE_BUNDLE,'productId'=>RVAZ_Store_Contract::PRODUCT,'type'=>'Consumable','quantity'=>1,'appAccountToken'=>$i['id'],'price'=>25000,'currency'=>'EUR','environment'=>'Sandbox','transactionId'=>'test-1','purchaseDate'=>time()*1000];
function check($yes,$message){if(!$yes)throw new RuntimeException($message);}
function rejected($provider,$receipt,$intent){try{RVAZ_Store_Contract::validate($provider,$receipt,$intent);}catch(RuntimeException $e){return;}throw new RuntimeException('unsafe receipt accepted');}
$v=RVAZ_Store_Contract::validate('apple',$a,$i);check($v['test']&&!$v['publish'],'Sandbox must not publish');
foreach(['bundleId'=>'attacker.app','productId'=>'other','appAccountToken'=>'ffffffff-ffff-4fff-afff-ffffffffffff','quantity'=>2,'price'=>0,'currency'=>'USD','environment'=>'Xcode','revocationDate'=>time()*1000,'purchaseDate'=>(time()-1000)*1000,'type'=>'Auto-Renewable Subscription'] as $k=>$value){$bad=$a;$bad[$k]=$value;rejected('apple',$bad,$i);}
$a['environment']='Production';check(RVAZ_Store_Contract::validate('apple',$a,$i)['publish'],'Production verified receipt can proceed');
$i['provider']='google';
$g=['purchaseStateContext'=>['purchaseState'=>'PURCHASED'],'obfuscatedExternalAccountId'=>$i['id'],'productLineItem'=>[['productId'=>RVAZ_Store_Contract::PRODUCT,'productOfferDetails'=>['quantity'=>1,'refundableQuantity'=>1]]],'regionCode'=>'NL','orderId'=>'GPA.test','purchaseCompletionTime'=>gmdate('c'),'testPurchaseContext'=>['fopType'=>'TEST']];
check(!RVAZ_Store_Contract::validate('google',$g,$i)['publish'],'Google test must not publish');
foreach(['PENDING','CANCELLED','PURCHASE_STATE_UNSPECIFIED'] as $state){$bad=$g;$bad['purchaseStateContext']['purchaseState']=$state;rejected('google',$bad,$i);}
$bad=$g;$bad['productLineItem'][0]['productOfferDetails']['refundableQuantity']=0;rejected('google',$bad,$i);
$bad=$g;$bad['productLineItem'][]=$bad['productLineItem'][0];rejected('google',$bad,$i);
$bad=$g;$bad['obfuscatedExternalAccountId']='other';rejected('google',$bad,$i);
$bad=$g;unset($bad['purchaseCompletionTime']);rejected('google',$bad,$i);
foreach(['amount'=>'12.50','period'=>'1_year','currency'=>'USD','provider'=>'apple'] as $k=>$value){$bad=$i;$bad[$k]=$value;rejected('google',$g,$bad);}
echo "Purchase policy: 26 rejection/isolation checks passed; no payment, mail or publication performed.\n";
