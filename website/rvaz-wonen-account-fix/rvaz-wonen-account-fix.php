<?php
/**
 * Plugin Name: RVAZ Wonen Account Herstel
 * Description: Rustige Mijn Wonen-pagina, makelaarsaccount deactiveren en opnieuw een pakket aanvragen. Behoudt Wonen API en kortingscodes.
 * Version: 1.0.2
 */
if(!defined('ABSPATH'))exit;
require_once __DIR__.'/portal-focus.php';
require_once __DIR__.'/private-ui.php';
require_once __DIR__.'/housing-fields.php';
require_once __DIR__.'/subscription-access.php';
final class RVAZ_Wonen_Account_Fix {
 static function subscription($uid){global $wpdb;return $wpdb->get_row($wpdb->prepare("SELECT * FROM {$wpdb->prefix}rvaz_wonen_subscriptions WHERE user_id=%d ORDER BY id DESC LIMIT 1",$uid));}
 static function pending($uid){global $wpdb;return $wpdb->get_row($wpdb->prepare("SELECT * FROM {$wpdb->prefix}rvaz_wonen_applications WHERE user_id=%d AND status IN ('email_pending','pending') ORDER BY id DESC LIMIT 1",$uid));}
 static function history($uid){global $wpdb;return self::subscription($uid)||(bool)$wpdb->get_var($wpdb->prepare("SELECT id FROM {$wpdb->prefix}rvaz_wonen_applications WHERE user_id=%d AND status='approved' LIMIT 1",$uid))||get_user_meta($uid,'rvaz_wonen_agent_archived',true)==='1';}
 static function inactive($uid){$s=self::subscription($uid);return !$s||$s->status!=='active';}
 static function apply($r){
  $uid=get_current_user_id();if(!self::history($uid))return RVAZ_Wonen_Native_API::error('history','Gebruik de gewone makelaarsaanmelding.',403);
  if(RVAZ_Wonen::blocked($uid))return RVAZ_Wonen_Native_API::error('blocked','Je toegang is geblokkeerd. Neem contact op met RVAZ.',403);
  if(!self::inactive($uid))return RVAZ_Wonen_Native_API::error('active','Je hebt al een actief abonnement.',409);
  $pending=self::pending($uid);if($pending)return ['id'=>(int)$pending->id,'status'=>$pending->status];
  foreach(['plan','expected_price','expected_first_month_price','coupon_code'] as $key)if(isset($r[$key])&&!is_scalar($r[$key]))return RVAZ_Wonen_Native_API::error('field','Ongeldige aanvraagwaarde.');
  $plan=sanitize_key($r['plan']??'');$prices=RVAZ_Wonen::prices();
  if(!in_array($plan,['basis','plus','pro'],true)||empty($prices[$plan]['enabled']))return RVAZ_Wonen_Native_API::error('plan','Kies een beschikbaar pakket.');
  if($r['confirm']!==true||(string)$r['expected_price']!==(string)$prices[$plan]['price'])return RVAZ_Wonen_Native_API::error('price','Bevestig het pakket en de actuele prijs.',409);
  $code=RVAZ_Wonen_Coupons::code($r['coupon_code']??'');
  if($code==='MAKELAAR')return RVAZ_Wonen_Native_API::error('intro_used','MAKELAAR is alleen voor een eerste nieuw makelaarsabonnement.',409);
  $amount=(string)$prices[$plan]['price'];$quote=null;
  if($code){$quote=RVAZ_Wonen_Coupons::quote($code,'makelaar',(float)$amount,$uid);if(is_wp_error($quote))return $quote;$amount=$quote['total'];}
  if((string)$r['expected_first_month_price']!==$amount)return RVAZ_Wonen_Native_API::error('price','De eerste-maandprijs is gewijzigd. Vernieuw de tarieven.',409);
  $values=[];foreach(['office','contact_name','phone'] as $key){if(!is_scalar($r[$key]))return RVAZ_Wonen_Native_API::error('field','Ongeldige kantoorwaarde.');$values[$key]=sanitize_text_field($r[$key]);if(!$values[$key])return RVAZ_Wonen_Native_API::error('required','Vul kantoor, contactpersoon en telefoon in.');}
  $lock='rvaz_wonen_reapply_'.absint($uid);if((int)get_option($lock,0)<time()-1800)delete_option($lock);if(!add_option($lock,time(),'','no'))return RVAZ_Wonen_Native_API::error('busy','Je aanvraag wordt al verwerkt.',409);
  try{
   $pending=self::pending($uid);if($pending)return ['id'=>(int)$pending->id,'status'=>$pending->status];
   global $wpdb;if(!$wpdb->insert($wpdb->prefix.'rvaz_wonen_applications',$values+['user_id'=>$uid,'plan'=>$plan,'status'=>'pending','created'=>current_time('mysql')]))return RVAZ_Wonen_Native_API::error('database','Aanvraag opslaan is niet gelukt.',500);
   $id=(int)$wpdb->insert_id;
   if($code){$reserved=RVAZ_Wonen_Coupons::reserve($code,'makelaar',(float)$prices[$plan]['price'],$uid,$id);if(is_wp_error($reserved)){$wpdb->delete($wpdb->prefix.'rvaz_wonen_applications',['id'=>$id]);return $reserved;}}
   update_user_meta($uid,'rvaz_wonen_intro_quote_'.$id,['regular'=>(string)$prices[$plan]['price'],'first'=>$amount,'coupon'=>$code]);
   // The returning account is already authenticated; no email and no automatic role grant.
   return ['id'=>$id,'status'=>'pending'];
  }finally{delete_option($lock);}
 }
 static function archive($uid,$confirm){
  if(!current_user_can('manage_options'))return RVAZ_Wonen_Native_API::error('admin','Alleen RVAZ kan een makelaarsaccount deactiveren.',403);
  $uid=absint($uid);$user=get_userdata($uid);if(!$user||(!in_array(RVAZ_Wonen::ROLE,(array)$user->roles,true)&&!self::history($uid)))return RVAZ_Wonen_Native_API::error('account','Makelaarsaccount niet gevonden.',404);
  if($confirm!==true)return RVAZ_Wonen_Native_API::error('confirm','Bevestig het deactiveren.');
  global $wpdb;$wpdb->update($wpdb->prefix.'rvaz_wonen_subscriptions',['status'=>'cancelled','cancelled_date'=>current_time('Y-m-d'),'next_invoice_date'=>null],['user_id'=>$uid,'status'=>'active']);
  foreach(get_posts(['post_type'=>RVAZ_Wonen::TYPE,'author'=>$uid,'post_status'=>['publish','pending','future'],'numberposts'=>-1]) as $post)if(!RVAZ_Wonen_Private::is_private($post->ID))wp_update_post(['ID'=>$post->ID,'post_status'=>'draft']);
  foreach($wpdb->get_col($wpdb->prepare("SELECT id FROM {$wpdb->prefix}rvaz_wonen_applications WHERE user_id=%d AND status IN ('email_pending','pending')",$uid)) as $id){RVAZ_Wonen_Coupons::mark('makelaar',$id,'released');$wpdb->update($wpdb->prefix.'rvaz_wonen_applications',['status'=>'cancelled'],['id'=>$id]);}
  $user->remove_role(RVAZ_Wonen::ROLE);update_user_meta($uid,'rvaz_wonen_agent_archived','1');update_user_meta($uid,'rvaz_wonen_agent_archived_at',current_time('mysql'));update_user_meta($uid,'rvaz_wonen_agent_archived_by',get_current_user_id());
  return ['status'=>'archived','user_id'=>$uid];
 }
 static function frontend(){
  if(!is_page('mijn-wonen')||!is_user_logged_in()||!class_exists('RVAZ_Wonen_Coupons'))return;$uid=get_current_user_id();
  if(!self::history($uid)||!self::inactive($uid)||RVAZ_Wonen::blocked($uid))return;
  $pending=self::pending($uid);
  wp_enqueue_script('rvaz-wonen-reapply',plugins_url('reapply.js',__FILE__),[], '1.0.0',true);
  wp_add_inline_script('rvaz-wonen-reapply','window.rvazWonenReapply='.wp_json_encode(['api'=>rest_url(RVAZ_Wonen_Native_API::NS),'nonce'=>wp_create_nonce('wp_rest'),'pending'=>$pending?$pending->status:null,'plans'=>RVAZ_Wonen::prices(),'office'=>(string)get_user_meta($uid,'rvaz_wonen_office_name',true),'contact'=>wp_get_current_user()->display_name,'phone'=>(string)get_user_meta($uid,'rvaz_wonen_phone',true)]).';','before');
 }
 static function admin(){
  if(!current_user_can('manage_options'))return;
  $users=get_users(['role'=>RVAZ_Wonen::ROLE,'number'=>200]);$archived=get_users(['meta_key'=>'rvaz_wonen_agent_archived','meta_value'=>'1','number'=>200]);$rows=[];foreach(array_merge($users,$archived) as $user)$rows[$user->ID]=$user;
  echo '<div class="wrap"><h1>Makelaarsaccounts deactiveren</h1><p>Deactiveren stopt het abonnement en zet makelaarswoningen op concept. Het gewone RVAZ-account, facturen en aanvragen blijven behouden. De makelaar kan opnieuw een pakket aanvragen. Een afzonderlijke toegangsblokkering wordt niet opgeheven.</p><table class="widefat striped"><tr><th>Kantoor / account</th><th>Abonnement</th><th>Actie</th></tr>';
  foreach($rows as $user){$s=self::subscription($user->ID);echo '<tr><td>'.esc_html(get_user_meta($user->ID,'rvaz_wonen_office_name',true)?:$user->display_name).'</td><td>'.esc_html($s?$s->status:'Geen abonnement').'</td><td><form method="post" action="'.esc_url(admin_url('admin-post.php')).'"><input type="hidden" name="action" value="rvaz_wonen_archive_account"><input type="hidden" name="user_id" value="'.(int)$user->ID.'">'.wp_nonce_field('rvaz_wonen_archive_account_'.$user->ID,'nonce',true,false).'<label><input type="checkbox" name="confirm" value="1" required> Deactiveren bevestigen</label> <button class="button">Makelaarsaccount deactiveren</button></form></td></tr>';}
  echo '</table></div>';
 }
}
add_action('rest_api_init',function(){if(!class_exists('RVAZ_Wonen_Native_API')||!class_exists('RVAZ_Wonen_Coupons'))return;register_rest_route(RVAZ_Wonen_Native_API::NS,'/makelaar/opnieuw-aanmelden',['methods'=>'POST','permission_callback'=>['RVAZ_Wonen_Native_API','authenticated'],'callback'=>['RVAZ_Wonen_Account_Fix','apply']]);},100);
add_action('wp_enqueue_scripts',['RVAZ_Wonen_Account_Fix','frontend'],100);
add_action('admin_menu',function(){if(class_exists('RVAZ_Wonen')&&class_exists('RVAZ_Wonen_Coupons')&&class_exists('RVAZ_Wonen_Private'))add_submenu_page('rvaz-wonen','Makelaarsaccounts deactiveren','Makelaarsaccounts','manage_options','rvaz-wonen-accounts',['RVAZ_Wonen_Account_Fix','admin']);},100);
add_action('admin_post_rvaz_wonen_archive_account',function(){if(!current_user_can('manage_options'))wp_die('Geen toegang');$uid=absint($_POST['user_id']??0);check_admin_referer('rvaz_wonen_archive_account_'.$uid,'nonce');$result=RVAZ_Wonen_Account_Fix::archive($uid,($_POST['confirm']??'')==='1');if(is_wp_error($result))wp_die(esc_html($result->get_error_message()));wp_safe_redirect(admin_url('admin.php?page=rvaz-wonen-accounts'));exit;});
// Existing Android/iOS registration screens use this route after role deactivation.
add_filter('rest_endpoints',function($routes){$path='/rvaz-wonen/v1/makelaar/aanmelden';if(empty($routes[$path]))return $routes;foreach($routes[$path] as &$endpoint){if(!is_array($endpoint)||($endpoint['callback']??null)!==['RVAZ_Wonen_Native_API','apply'])continue;$original=$endpoint['callback'];$endpoint['callback']=function($request)use($original){return RVAZ_Wonen_Account_Fix::history(get_current_user_id())&&RVAZ_Wonen_Account_Fix::inactive(get_current_user_id())?RVAZ_Wonen_Account_Fix::apply($request):call_user_func($original,$request);};}unset($endpoint);return $routes;},1150);
