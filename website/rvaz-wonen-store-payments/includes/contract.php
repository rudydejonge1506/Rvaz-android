<?php
/** Pure purchase policy: verified provider payloads only; no entitlement side effects. */
final class RVAZ_Store_Contract {
 const PRODUCT='rvaz.wonen.particulier.maand';
 const APPLE_BUNDLE='nl.regiovoorneaanzee.app';
 const GOOGLE_PACKAGE='nl.regiovoorneaanzee.rvaz_android';
 static function validate($provider,array $receipt,array $intent,$now=null){
  $now=$now??time();
  if(!in_array($provider,['apple','google'],true)||($intent['provider']??'')!==$provider)throw new RuntimeException('provider');
  if(!preg_match('/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/D',$intent['id']??''))throw new RuntimeException('intent');
  if(($intent['product']??'')!==self::PRODUCT||($intent['amount']??'')!=='25.00'||($intent['currency']??'')!=='EUR'||($intent['period']??'')!=='1_month')throw new RuntimeException('quote');
  if($provider==='apple'){
   if(($receipt['bundleId']??'')!==self::APPLE_BUNDLE||($receipt['productId']??'')!==self::PRODUCT||($receipt['type']??'')!=='Consumable'||($receipt['quantity']??null)!==1)throw new RuntimeException('product');
   if(!hash_equals($intent['id'],strtolower($receipt['appAccountToken']??'')))throw new RuntimeException('account');
   if(isset($receipt['revocationDate'])||isset($receipt['revocationReason']))throw new RuntimeException('revoked');
   if(($receipt['price']??null)!==25000||($receipt['currency']??'')!=='EUR')throw new RuntimeException('price');
   if(!in_array($receipt['environment']??'', ['Sandbox','Production'],true))throw new RuntimeException('environment');
   $transaction=$receipt['transactionId']??'';$date=($receipt['purchaseDate']??0)/1000;$test=$receipt['environment']==='Sandbox';
  }else{
   if(($receipt['purchaseStateContext']['purchaseState']??'')!=='PURCHASED')throw new RuntimeException('pending_or_cancelled');
   if(!hash_equals($intent['id'],$receipt['obfuscatedExternalAccountId']??''))throw new RuntimeException('account');
   $items=$receipt['productLineItem']??[];
   if(count($items)!==1||($items[0]['productId']??'')!==self::PRODUCT||($items[0]['productOfferDetails']['quantity']??null)!==1)throw new RuntimeException('product');
   if(($items[0]['productOfferDetails']['refundableQuantity']??null)!==1)throw new RuntimeException('refunded');
   if(($receipt['regionCode']??'')!=='NL')throw new RuntimeException('territory');
   $transaction=$receipt['orderId']??'';$date=strtotime($receipt['purchaseCompletionTime']??'');$test=isset($receipt['testPurchaseContext']);
  }
  if(!is_string($transaction)||$transaction===''||strlen($transaction)>200)throw new RuntimeException('transaction');
  if(!$date||$date<($intent['created']??PHP_INT_MAX)-300||$date>$now+300)throw new RuntimeException('date');
  return ['provider'=>$provider,'transaction'=>$transaction,'test'=>$test,'amount'=>'25.00','currency'=>'EUR','publish'=>!$test];
 }
}
