<?php
/** Verify StoreKit 2 JWS against Apple's pinned certificate authority. */
final class RVAZ_Store_Apple {
 static function decode($value){
  if(!is_string($value)||!preg_match('/^[A-Za-z0-9_-]+$/D',$value))throw new RuntimeException('Invalid JWS encoding');
  $decoded=base64_decode(strtr($value,'-_','+/'),true);if($decoded===false)throw new RuntimeException('Invalid JWS encoding');return $decoded;
 }
 static function json($value){$result=json_decode(self::decode($value),true,32,JSON_THROW_ON_ERROR);if(!is_array($result))throw new RuntimeException('Invalid JWS object');return $result;}
 static function pem($der){return "-----BEGIN CERTIFICATE-----\n".chunk_split(base64_encode($der),64,"\n")."-----END CERTIFICATE-----\n";}
 static function integer($value){$value=ltrim($value,"\0");if($value==='')$value="\0";if(ord($value[0])&128)$value="\0".$value;return "\x02".chr(strlen($value)).$value;}
 static function verify($jws){
  if(!is_string($jws)||strlen($jws)>32768)throw new RuntimeException('Invalid signed transaction');
  $parts=explode('.',$jws);if(count($parts)!==3)throw new RuntimeException('StoreKit 2 signed transaction required');
  $header=self::json($parts[0]);$chain=$header['x5c']??[];
  if(($header['alg']??'')!=='ES256'||isset($header['crit'])||!is_array($chain)||count($chain)<2||count($chain)>3)throw new RuntimeException('Invalid signing chain');
  $rootPath=dirname(__DIR__).'/certs/AppleRootCA-G3.pem';$root=file_get_contents($rootPath);
  $rootDer=base64_decode(preg_replace('/-----[^-]+-----|\s/','',$root),true);
  if(!$rootDer||!hash_equals('63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179',hash('sha256',$rootDer)))throw new RuntimeException('Untrusted root certificate');
  $certs=[];foreach($chain as $item){if(!is_string($item)||strlen($item)>10000)throw new RuntimeException('Invalid certificate');$der=base64_decode($item,true);if(!$der)throw new RuntimeException('Invalid certificate');$certs[]=self::pem($der);}
  if(count($certs)===3&&!hash_equals($rootDer,base64_decode($chain[2],true)))throw new RuntimeException('Untrusted root certificate');
  $leaf=openssl_x509_parse($certs[0]);$intermediate=openssl_x509_parse($certs[1]);
  if(!$leaf||!$intermediate||!isset($leaf['extensions']['1.2.840.113635.100.6.11.1'])||!isset($intermediate['extensions']['1.2.840.113635.100.6.2.1']))throw new RuntimeException('Not an Apple transaction signing certificate');
  $temp=tempnam(sys_get_temp_dir(),'rvaz-chain-');if(!$temp)throw new RuntimeException('Cannot verify certificate');
  try{
   if(file_put_contents($temp,$certs[1])===false)throw new RuntimeException('Cannot verify certificate');
   if(!in_array(openssl_x509_checkpurpose($certs[0],X509_PURPOSE_ANY,[$rootPath],$temp),[true,1],true))throw new RuntimeException('Untrusted signing chain');
  }finally{unlink($temp);}
  $key=openssl_pkey_get_public($certs[0]);$details=$key?openssl_pkey_get_details($key):false;
  if(!$details||($details['type']??null)!==OPENSSL_KEYTYPE_EC||($details['ec']['curve_name']??'')!=='prime256v1')throw new RuntimeException('Invalid signing key');
  $raw=self::decode($parts[2]);if(strlen($raw)!==64)throw new RuntimeException('Invalid signature');
  $sequence=self::integer(substr($raw,0,32)).self::integer(substr($raw,32));$signature="\x30".chr(strlen($sequence)).$sequence;
  if(openssl_verify($parts[0].'.'.$parts[1],$signature,$key,OPENSSL_ALGO_SHA256)!==1)throw new RuntimeException('Invalid transaction signature');
  $payload=self::json($parts[1]);$signed=($payload['signedDate']??0)/1000;
  if(!$signed||$signed>time()+300||$signed<($leaf['validFrom_time_t']??PHP_INT_MAX)||$signed>($leaf['validTo_time_t']??0))throw new RuntimeException('Invalid signed date');
  return $payload;
 }
}
