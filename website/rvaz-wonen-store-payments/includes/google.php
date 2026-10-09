<?php
/** Google purchases are read from the Publisher API, never trusted from the app. */
final class RVAZ_Store_Google {
 static function encode($value){return rtrim(strtr(base64_encode($value),'+/','-_'),'=');}
 static function seal($json,$purpose='rvaz-google-service-account'){
  $key=hash('sha256',wp_salt('auth').wp_salt('secure_auth'),true);$iv=random_bytes(12);$tag='';
  $cipher=openssl_encrypt($json,'aes-256-gcm',$key,OPENSSL_RAW_DATA,$iv,$tag,$purpose);
  if($cipher===false)throw new RuntimeException('Credential encryption failed');return base64_encode($iv.$tag.$cipher);
 }
 static function open($encrypted,$purpose='rvaz-google-service-account'){
  $data=base64_decode($encrypted,true);if(!$data||strlen($data)<29)throw new RuntimeException('Encrypted Google connection is not configured');
  $json=openssl_decrypt(substr($data,28),'aes-256-gcm',hash('sha256',wp_salt('auth').wp_salt('secure_auth'),true),OPENSSL_RAW_DATA,substr($data,0,12),substr($data,12,16),$purpose);
  if(!$json)throw new RuntimeException('Google server data cannot be opened');return $json;
 }
 static function credentials(){return self::validate_credentials(self::open(get_option('rvaz_store_google_credentials','')));}
 static function validate_credentials($json){
  $data=json_decode($json,true,16,JSON_THROW_ON_ERROR);
  if(($data['type']??'')!=='service_account'||!preg_match('/^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.iam\.gserviceaccount\.com$/D',$data['client_email']??'')||!openssl_pkey_get_private($data['private_key']??''))throw new RuntimeException('Invalid Google service account');return $data;
 }
 static function response($response){
  if(is_wp_error($response)||wp_remote_retrieve_response_code($response)!==200)throw new RuntimeException('Google Play could not verify this payment; retry later');
  return json_decode(wp_remote_retrieve_body($response),true,32,JSON_THROW_ON_ERROR);
 }
 static function token(){
  $account=self::credentials();$now=time();
  $unsigned=self::encode(json_encode(['alg'=>'RS256','typ'=>'JWT'])).'.'.self::encode(json_encode(['iss'=>$account['client_email'],'scope'=>'https://www.googleapis.com/auth/androidpublisher','aud'=>'https://oauth2.googleapis.com/token','iat'=>$now,'exp'=>$now+600]));
  if(!openssl_sign($unsigned,$signature,$account['private_key'],OPENSSL_ALGO_SHA256))throw new RuntimeException('Google authorization failed');
  $data=self::response(wp_remote_post('https://oauth2.googleapis.com/token',['timeout'=>20,'redirection'=>0,'body'=>['grant_type'=>'urn:ietf:params:oauth:grant-type:jwt-bearer','assertion'=>$unsigned.'.'.self::encode($signature)]]));
  if(!is_string($data['access_token']??null)||$data['access_token']==='')throw new RuntimeException('Google authorization failed');return $data['access_token'];
 }
 static function verify($purchaseToken){
  if(!is_string($purchaseToken)||strlen($purchaseToken)<10||strlen($purchaseToken)>4096)throw new RuntimeException('Invalid Google purchase token');
  $url='https://androidpublisher.googleapis.com/androidpublisher/v3/applications/'.RVAZ_Store_Contract::GOOGLE_PACKAGE.'/purchases/productsv2/tokens/'.rawurlencode($purchaseToken);
  return self::response(wp_remote_get($url,['timeout'=>20,'redirection'=>0,'headers'=>['Authorization'=>'Bearer '.self::token(),'Accept'=>'application/json']]));
 }
}
