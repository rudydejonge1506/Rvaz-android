<?php
if (!defined('ABSPATH')) exit;
/** Additive mobile REST endpoints for RVAZ Wonen. Requires authenticated WordPress REST user. */
final class RVAZ_Wonen_Mobile {
 const NS='rvaz-wonen/v1';
 const FIELDS=['adres','postcode','plaats','prijs','prijstype','borg','contractduur','aanvaarding','inkomenseisen','woningtype','transactie','status','bouwjaar','kamers','slaapkamers','badkamers','woonoppervlak','perceel','energielabel','tuin','balkon','garage','makelaar_url'];
 /** Verify existing RVAZ App API bearer tokens without modifying the App API plugin.
  * The App API stores SHA-256 token hashes in user meta _rvaz_app_tokens.
  * No token is accepted merely because a user ID is supplied by the client.
  */
 static function app_user($request){
  $header=(string)$request->get_header('authorization');
  if(!preg_match('/^Bearer\s+([a-f0-9]{64})$/i',trim($header),$matches))return false;
  $hash=hash('sha256',$matches[1]);
  $users=get_users(['meta_key'=>'_rvaz_app_tokens','fields'=>'all']);
  foreach($users as $candidate){
   $tokens=get_user_meta($candidate->ID,'_rvaz_app_tokens',true);
   if(!is_array($tokens))continue;
   foreach($tokens as $stored_hash=>$issued){
    if(is_string($stored_hash)&&hash_equals($stored_hash,$hash))return $candidate;
   }
  }
  return false;
 }
 static function allowed($request){
  $u=wp_get_current_user();
  if(!$u->ID){
   $u=self::app_user($request);
   if(!$u)return new WP_Error('rvaz_wonen_auth','Log in met je RVAZ-app-account.',['status'=>401]);
   wp_set_current_user($u->ID);
  }
  if(RVAZ_Wonen::blocked($u->ID))return new WP_Error('rvaz_wonen_blocked','Makelaarstoegang geblokkeerd.',['status'=>403]);
  if(!in_array(RVAZ_Wonen::ROLE,(array)$u->roles,true)&&!user_can($u,'manage_options'))
   return new WP_Error('rvaz_wonen_forbidden','Geen makelaarstoegang.',['status'=>403]);
  return true;
 }
 static function owned($id){$p=get_post($id);return $p && $p->post_type===RVAZ_Wonen::TYPE && ((int)$p->post_author===get_current_user_id()||current_user_can('manage_options'));}
 static function register(){
  register_rest_route(self::NS,'/makelaar/woningen',['methods'=>'GET','callback'=>[__CLASS__,'list_own'],'permission_callback'=>[__CLASS__,'allowed']]);
  register_rest_route(self::NS,'/makelaar/woningen',['methods'=>'POST','callback'=>[__CLASS__,'save'],'permission_callback'=>[__CLASS__,'allowed']]);
  register_rest_route(self::NS,'/makelaar/woningen/(?P<id>\d+)',['methods'=>'POST,PUT,PATCH','callback'=>[__CLASS__,'save'],'permission_callback'=>[__CLASS__,'allowed']]);
  register_rest_route(self::NS,'/makelaar/woningen/(?P<id>\d+)/fotos',['methods'=>'POST','callback'=>[__CLASS__,'photo'],'permission_callback'=>[__CLASS__,'allowed']]);
  register_rest_route(self::NS,'/makelaar/aanvragen',['methods'=>'GET','callback'=>[__CLASS__,'inbox'],'permission_callback'=>[__CLASS__,'allowed']]);
 }
 static function listing($id){$d=RVAZ_Wonen::fields($id);$d['publication_status']=get_post_status($id);$d['gallery']=array_values(array_filter(array_map(function($aid){return wp_get_attachment_image_url((int)$aid,'large');},(array)get_post_meta($id,'_rvaz_wonen_gallery',true))));return $d;}
 static function list_own(){ $args=['post_type'=>RVAZ_Wonen::TYPE,'post_status'=>['publish','draft','pending'],'numberposts'=>-1];if(!current_user_can('manage_options'))$args['author']=get_current_user_id();return array_map([__CLASS__,'listing'],array_map('intval',wp_list_pluck(get_posts($args),'ID')));}
 static function save($r){$id=absint($r->get_param('id'));if($id&&!self::owned($id))return new WP_Error('forbidden','Geen toegang tot deze woning',['status'=>403]);
  if(!$id){$id=wp_insert_post(['post_type'=>RVAZ_Wonen::TYPE,'post_status'=>'draft','post_author'=>get_current_user_id(),'post_title'=>'Nieuwe woning'],true);if(is_wp_error($id))return $id;}
  $changes=['ID'=>$id];if($r->has_param('title'))$changes['post_title']=sanitize_text_field($r->get_param('title'));if($r->has_param('description'))$changes['post_content']=wp_kses_post($r->get_param('description'));
  if($r->has_param('publication_status')){$status=$r->get_param('publication_status');if(!in_array($status,['draft','publish'],true))return new WP_Error('bad_status','Ongeldige publicatiestatus',['status'=>400]);if($status==='publish'&&get_post_status($id)!=='publish'){
    global $wpdb;$uid=(int)get_post_field('post_author',$id);$sub=$wpdb->get_row($wpdb->prepare("SELECT * FROM {$wpdb->prefix}rvaz_wonen_subscriptions WHERE user_id=%d AND status='active' ORDER BY id DESC LIMIT 1",$uid));$prices=RVAZ_Wonen::prices();if(!$sub||empty($prices[$sub->plan]))return new WP_Error('subscription','Geen actief Wonen-abonnement',['status'=>403]);$limit=(int)$prices[$sub->plan]['limit'];if($limit>0&&count_user_posts($uid,RVAZ_Wonen::TYPE,true)>=$limit)return new WP_Error('limit','Pakketlimiet bereikt',['status'=>403]);}
    $changes['post_status']=$status;}
  if(count($changes)>1){$result=wp_update_post($changes,true);if(is_wp_error($result))return $result;}
  foreach(self::FIELDS as $field)if($r->has_param($field))update_post_meta($id,'_rvaz_wonen_'.$field,sanitize_text_field($r->get_param($field)));
  return self::listing($id);
 }
 static function photo($r){$id=absint($r['id']);if(!self::owned($id))return new WP_Error('forbidden','Geen toegang',['status'=>403]);$files=$r->get_file_params();if(empty($files['photo']))return new WP_Error('missing_photo','Foto ontbreekt',['status'=>400]);require_once ABSPATH.'wp-admin/includes/file.php';require_once ABSPATH.'wp-admin/includes/media.php';require_once ABSPATH.'wp-admin/includes/image.php';$_FILES['rvaz_wonen_mobile_photo']=$files['photo'];$aid=media_handle_upload('rvaz_wonen_mobile_photo',$id);unset($_FILES['rvaz_wonen_mobile_photo']);if(is_wp_error($aid))return $aid;$gallery=array_map('intval',(array)get_post_meta($id,'_rvaz_wonen_gallery',true));$gallery[]=(int)$aid;update_post_meta($id,'_rvaz_wonen_gallery',array_values(array_unique($gallery)));if(!has_post_thumbnail($id))set_post_thumbnail($id,$aid);return self::listing($id);}
 static function inbox(){global $wpdb;$uid=get_current_user_id();return $wpdb->get_results($wpdb->prepare("SELECT id,property_id,name,email,phone,message,status,created FROM {$wpdb->prefix}rvaz_wonen_messages WHERE agent_user_id=%d ORDER BY created DESC LIMIT 200",$uid),ARRAY_A);}
}
add_action('rest_api_init',['RVAZ_Wonen_Mobile','register']);
