<?php
/**
 * Plugin Name: RVAZ Wonen Winkelbetalingen
 * Description: Gecontroleerde Apple- en Google-betalingen voor particuliere woningplaatsingen. Standaard alleen testmodus.
 * Version: 0.1.0
 */
if(!defined('ABSPATH'))exit;
require_once __DIR__.'/includes/contract.php';
require_once __DIR__.'/includes/apple.php';
require_once __DIR__.'/includes/google.php';
final class RVAZ_Wonen_Store {
 static function error($message,$status=409){return new WP_Error('rvaz_store',$message,['status'=>$status]);}
 static function register(){
  if(!class_exists('RVAZ_Wonen_Private'))return;
  register_rest_route(RVAZ_Wonen_Native_API::NS,'/winkel/apple-melding',['methods'=>'POST','callback'=>[__CLASS__,'apple_notification'],'permission_callback'=>'__return_true']);
  foreach(['/winkel/catalogus'=>['GET','catalog'],'/winkel/intentie'=>['POST','intent'],'/winkel/bevestigen'=>['POST','confirm']] as $path=>$route)register_rest_route(RVAZ_Wonen_Native_API::NS,$path,['methods'=>$route[0],'callback'=>[__CLASS__,$route[1]],'permission_callback'=>['RVAZ_Wonen_Private','allowed']]);
 }
 static function catalog($r=null){
  $data=['product_id'=>RVAZ_Store_Contract::PRODUCT,'price'=>'25.00','currency'=>'EUR','period'=>'1_month','automatic_renewal'=>false,'review_required'=>true,'test_only'=>!get_option('rvaz_store_production',false),'apple'=>true,'google'=>(bool)get_option('rvaz_store_google_credentials','')];
  if($r instanceof WP_REST_Request&&$r->has_param('property_id')){$ok=self::eligible(absint($r['property_id']));$data['eligible']=!is_wp_error($ok);$data['message']=is_wp_error($ok)?$ok->get_error_message():'Goedgekeurd voor plaatsing.';}
  return $data;
 }
 static function eligible($id,$paidRetry=false){
  if(!RVAZ_Wonen_Private::owns($id))return self::error('Deze woning hoort niet bij jouw account.',403);
  if(get_post_status($id)!=='pending'||!get_post_meta($id,'_rvaz_wonen_private_authority',true))return self::error('Dien eerst je complete woning in voor beoordeling.');
  $reviewer=(int)get_post_meta($id,'_rvaz_wonen_private_reviewed',true);
  if(!$reviewer||!user_can($reviewer,'manage_options'))return self::error('RVAZ moet je woning eerst goedkeuren. Je hoeft daarvoor nog niet te betalen.');
  $ok=RVAZ_Wonen_Private::complete($id);if(is_wp_error($ok))return $ok;
  $invoice=RVAZ_Wonen_Private::invoice($id);$end=(int)get_post_meta($id,'_rvaz_wonen_private_expires',true);
  if(!$paidRetry&&$invoice&&$invoice['status']==='paid'&&(!$end||$end>time()))return self::error('Deze plaatsing is al betaald.');
  if($invoice&&$invoice['status']==='open'&&(float)$invoice['total']!==25.0)return self::error('Voor deze woning bestaat al een factuur met een andere prijs. Betaal niet nogmaals via de winkel.');
  return true;
 }
 static function intent($r){
  $id=absint($r['property_id']);$provider=$r['provider'];
  if(!in_array($provider,['apple','google'],true))return self::error('Onbekende betaalwinkel.');
  if($provider==='google'&&!self::catalog()['google'])return self::error('Google Play-betaling is nog niet gekoppeld.',503);
  $ok=self::eligible($id);if(is_wp_error($ok))return $ok;
  if($provider==='google'){try{RVAZ_Store_Google::product();}catch(Throwable $e){return self::error('Google Play-product of serverrechten zijn nog niet correct ingesteld. Er is niets afgeschreven.',503);}}
  $key='rvaz_store_pending_'.get_current_user_id().'_'.$id.'_'.$provider;$existing=get_option($key);
  if($existing){$data=get_option('rvaz_store_intent_'.$existing);if($data&&!isset($data['completed']))return self::public_intent($data);}
  $data=['id'=>wp_generate_uuid4(),'owner'=>get_current_user_id(),'property_id'=>$id,'provider'=>$provider,'product'=>RVAZ_Store_Contract::PRODUCT,'amount'=>'25.00','currency'=>'EUR','period'=>'1_month','created'=>time(),'reviewer'=>(int)get_post_meta($id,'_rvaz_wonen_private_reviewed',true),'generation'=>(int)get_post_meta($id,'_rvaz_wonen_private_invoice_generation',true)];
  if(!add_option('rvaz_store_intent_'.$data['id'],$data,'',false))return self::error('Aankoop voorbereiden is niet gelukt.',500);
  update_option($key,$data['id'],false);return self::public_intent($data);
 }
 static function public_intent($data){return array_intersect_key($data,array_flip(['id','property_id','provider','product','amount','currency','period']));}
 static function confirm($r){
  $uuid=$r['intent_id'];if(!is_string($uuid)||!preg_match('/^[a-f0-9-]{36}$/D',$uuid))return self::error('Ongeldige aankoop.');
  $intent=get_option('rvaz_store_intent_'.$uuid);
  if(!$intent||(int)$intent['owner']!==get_current_user_id())return self::error('Geen toegang tot deze aankoop.',403);
  try{
   $receipt=$intent['provider']==='apple'?RVAZ_Store_Apple::verify($r['verification_data']):RVAZ_Store_Google::verify($r['verification_data']);
   $verified=RVAZ_Store_Contract::validate($intent['provider'],$receipt,$intent);
   if(!$verified['test']&&!get_option('rvaz_store_production',false))throw new RuntimeException('Live winkelbetalingen zijn nog niet vrijgegeven.');
  }catch(Throwable $error){return self::error('Betaling kon niet worden bevestigd: '.$error->getMessage(),422);}
  global $wpdb;$lock='rvaz-store-'.absint($intent['property_id']);
  if((int)$wpdb->get_var($wpdb->prepare('SELECT GET_LOCK(%s,5)',$lock))!==1)return self::error('Aankoop wordt al verwerkt. Probeer opnieuw.',503);
  try{
   $orderKey='rvaz_store_order_'.hash('sha256',$verified['provider'].':'.$verified['transaction']);$order=get_option($orderKey);
   if($order&&($order['intent_id']!==$uuid||(int)$order['owner']!==get_current_user_id()))return self::error('Deze betaling hoort al bij een andere plaatsing.',403);
   if($order&&($order['status']??'')==='refunded')return self::error('Deze aankoop is terugbetaald en kan niet opnieuw worden gebruikt.');
   if($order&&($order['status']??'')==='completed')return $order['result'];
   if(!$order){$order=['intent_id'=>$uuid,'owner'=>get_current_user_id(),'property_id'=>$intent['property_id'],'status'=>'verified','test'=>$verified['test'],'provider'=>$verified['provider'],'transaction'=>$verified['transaction']];if($intent['provider']==='google')$order['token_sealed']=RVAZ_Store_Google::seal($r['verification_data'],'rvaz-google-purchase');if(!add_option($orderKey,$order,'',false))return self::error('Betaling wordt al verwerkt. Probeer opnieuw.',503);}
   if($verified['test']){$result=['verified'=>true,'test'=>true,'published'=>false,'message'=>'Testbetaling bevestigd. Er is geen echte woning gepubliceerd of factuur aangemaakt.'];}
   else{
    $id=(int)$intent['property_id'];$paidRetry=get_post_meta($id,'_rvaz_wonen_store_order',true)===$orderKey;$ok=self::eligible($id,$paidRetry);if(is_wp_error($ok))return $ok;
    if((int)get_post_meta($id,'_rvaz_wonen_private_reviewed',true)!==(int)$intent['reviewer'])return self::error('Woning is opnieuw beoordeeld. Laat de betaalde aankoop door RVAZ controleren.');
    $request=new WP_REST_Request('POST');$request->set_param('id',$id);$request->set_param('confirm',true);$request->set_param('expected_price','25.00');$request->set_param('expected_period','1_month');
    if((int)get_post_meta($id,'_rvaz_wonen_private_invoice_generation',true)!==(int)$intent['generation']&&!$paidRetry)return self::error('De plaatsing is gewijzigd sinds de aankoop. Laat de betaling door RVAZ controleren.');
    $created=RVAZ_Wonen_Private::order($request);if(is_wp_error($created))return $created;$iid=(int)$created['invoice_id'];
    $invoice=RVAZ_Wonen_Private::invoice($id);if(!$invoice||(int)$invoice['id']!==$iid||(float)$invoice['total']!==25.0)return self::error('Factuur past niet bij de winkelbetaling.',409);
    update_post_meta($id,'_rvaz_wonen_store_order',$orderKey);
    if($wpdb->update($wpdb->prefix.'rvaz_wonen_invoices',['status'=>'paid','tikkie_url'=>''],['id'=>$iid,'user_id'=>get_current_user_id()])===false)return self::error('Betaling opslaan is niet gelukt. Probeer opnieuw.',500);
    // The original administrator review remains authoritative; owners cannot publish.
    $uid=get_current_user_id();wp_set_current_user((int)$intent['reviewer']);
    try{$review=new WP_REST_Request('POST');$review->set_param('id',$id);$review->set_param('decision','approve');$review->set_param('authority_checked',true);$published=RVAZ_Wonen_Private::review($review);}finally{wp_set_current_user($uid);}
    if(is_wp_error($published)||get_post_status($id)!=='publish')return self::error('Betaling is opgeslagen, maar publicatie moet door RVAZ worden gecontroleerd.',409);
    $result=['verified'=>true,'test'=>false,'published'=>true,'invoice_id'=>$iid,'expires'=>(int)get_post_meta($id,'_rvaz_wonen_private_expires',true)];
   }
   $order['status']='completed';$order['result']=$result;update_option($orderKey,$order,false);$intent['completed']=time();update_option('rvaz_store_intent_'.$uuid,$intent,false);delete_option('rvaz_store_pending_'.$intent['owner'].'_'.$intent['property_id'].'_'.$intent['provider']);return $result;
  }finally{$wpdb->get_var($wpdb->prepare('SELECT RELEASE_LOCK(%s)',$lock));}
 }
 static function revoke($orderKey){
  $order=get_option($orderKey);if(!$order)return;
  $order['status']='refunded';$order['refunded']=time();update_option($orderKey,$order,false);
  if(!empty($order['test']))return;
  $id=(int)$order['property_id'];$iid=(int)($order['result']['invoice_id']??0);
  global $wpdb;if($iid)$wpdb->update($wpdb->prefix.'rvaz_wonen_invoices',['status'=>'cancelled'],['id'=>$iid,'user_id'=>(int)$order['owner']]);
  if(get_post_meta($id,'_rvaz_wonen_store_order',true)===$orderKey){delete_post_meta($id,'_rvaz_wonen_private_approved');wp_update_post(['ID'=>$id,'post_status'=>'draft']);}
 }
 static function apple_notification($r){
  try{
   $notice=RVAZ_Store_Apple::verify($r['signedPayload']);
   if(!in_array($notice['notificationType']??'',['REFUND','REVOKE'],true))return ['received'=>true];
   $transaction=RVAZ_Store_Apple::verify($notice['data']['signedTransactionInfo']??'');
   if(($transaction['bundleId']??'')!==RVAZ_Store_Contract::APPLE_BUNDLE||($transaction['productId']??'')!==RVAZ_Store_Contract::PRODUCT||empty($transaction['revocationDate'])||empty($transaction['transactionId']))throw new RuntimeException('Invalid refund');
   self::revoke('rvaz_store_order_'.hash('sha256','apple:'.$transaction['transactionId']));return ['received'=>true];
  }catch(Throwable $e){return self::error('Ongeldige ondertekende winkelmelding.',422);}
 }
 static function google_refunds(){
  if(!get_option('rvaz_store_google_credentials'))return;
  global $wpdb;$names=$wpdb->get_col($wpdb->prepare("SELECT option_name FROM {$wpdb->options} WHERE option_name LIKE %s",$wpdb->esc_like('rvaz_store_order_').'%'));
  foreach($names as $name){$order=get_option($name);if(($order['provider']??'')!=='google'||($order['status']??'')!=='completed'||!empty($order['test'])||empty($order['token_sealed']))continue;
   try{$receipt=RVAZ_Store_Google::verify(RVAZ_Store_Google::open($order['token_sealed'],'rvaz-google-purchase'));$state=$receipt['purchaseStateContext']['purchaseState']??'';$items=$receipt['productLineItem']??[];if($state==='CANCELLED'||(count($items)===1&&($items[0]['productId']??'')===RVAZ_Store_Contract::PRODUCT&&($items[0]['productOfferDetails']['refundableQuantity']??null)===0))self::revoke($name);}catch(Throwable $e){/* Network failure grants nothing and does not withdraw a valid paid listing. Retry at next scan. */}
  }
 }
 static function menu(){add_options_page('Wonen winkelbetalingen','Wonen winkelbetalingen','manage_options','rvaz-wonen-store',[__CLASS__,'settings']);}
 static function settings(){
  if(!current_user_can('manage_options'))return;
  if(isset($_POST['rvaz_store_save'])){
   check_admin_referer('rvaz_store_settings');
   try{$json=trim(wp_unslash($_POST['google_credentials']??''));if($json!==''){RVAZ_Store_Google::validate_credentials($json);update_option('rvaz_store_google_credentials',RVAZ_Store_Google::seal($json),false);}echo '<div class="notice notice-success"><p>Serverkoppeling opgeslagen. Alleen testmodus is beschikbaar.</p></div>';}catch(Throwable $e){echo '<div class="notice notice-error"><p>Ongeldig serviceaccount. Er is niets opgeslagen.</p></div>';}
  }
  echo '<div class="wrap"><h1>RVAZ Wonen winkelbetalingen — testmodus</h1><p>€25 voor één woning of kamer, één kalendermaand vanaf publicatie. Geen automatische verlenging. Testbetalingen publiceren niets. Producten moeten eerst in beide winkels worden ingericht en getest.</p><p>Google Play-serverkoppeling: '.(get_option('rvaz_store_google_credentials')?'ingesteld':'ontbreekt').'</p><form method="post">';wp_nonce_field('rvaz_store_settings');echo '<label for="google_credentials">Google Play Publisher-serviceaccount (JSON, wordt versleuteld opgeslagen; leeg laten om te behouden)</label><p><textarea id="google_credentials" name="google_credentials" rows="8" cols="80" autocomplete="off" spellcheck="false"></textarea></p><button class="button button-primary" name="rvaz_store_save" value="1">Serverkoppeling opslaan</button></form></div>';
 }
}
add_action('rest_api_init',['RVAZ_Wonen_Store','register'],60);
add_action('admin_menu',['RVAZ_Wonen_Store','menu']);

add_action('rvaz_store_google_refunds',['RVAZ_Wonen_Store','google_refunds']);
register_activation_hook(__FILE__,function(){if(!wp_next_scheduled('rvaz_store_google_refunds'))wp_schedule_event(time()+HOUR_IN_SECONDS,'daily','rvaz_store_google_refunds');});
register_deactivation_hook(__FILE__,function(){wp_clear_scheduled_hook('rvaz_store_google_refunds');});
