<?php
/**
 * Plugin Name: RVAZ Familieberichten Native API
 * Description: Native app-kaarten met bestaande accounts en redactionele controle.
 * Version: 1.0.0
 */
defined('ABSPATH') || exit;
final class RVAZ_Family_Native_API {
 const NS='rvaz-family/v1';
 static function error($message,$status=400){return new WP_Error('rvaz_family',$message,['status'=>$status]);}
 static function auth($r){
  if(!class_exists('RVAZ_Wonen_Native_API'))return self::error('Accountcontrole is tijdelijk niet beschikbaar.',503);
  return RVAZ_Wonen_Native_API::authenticated($r);
 }
 static function register(){
  if(!class_exists('RVAZ_Family'))return;
  register_rest_route(self::NS,'/notices',['methods'=>'GET','callback'=>[__CLASS__,'listing'],'permission_callback'=>'__return_true']);
  register_rest_route(self::NS,'/mine',['methods'=>'GET','callback'=>[__CLASS__,'mine'],'permission_callback'=>[__CLASS__,'auth']]);
  register_rest_route(self::NS,'/notices',['methods'=>'POST','callback'=>[__CLASS__,'submit'],'permission_callback'=>[__CLASS__,'auth']],false);
  register_rest_route(self::NS,'/notices/(?P<id>\d+)',['methods'=>'DELETE','callback'=>[__CLASS__,'trash'],'permission_callback'=>[__CLASS__,'auth']]);
 }
 static function response($data){$r=new WP_REST_Response($data);$r->header('Cache-Control','private, no-store');return $r;}
 static function item($p,$own=false){
  $s=RVAZ_Family::style($p->ID);
  $d=array_merge($s,['id'=>$p->ID,'title'=>$p->post_title,'message'=>$p->post_content,'place'=>(string)get_post_meta($p->ID,'_rf_place',true),'date'=>get_post_time('c',true,$p),'image_url'=>'']);
  if(get_post_meta($p->ID,'_rf_has_image',true)){
   if($p->post_status==='publish')$d['image_url']=RVAZ_Family::image_url($p->ID);
   elseif($own)$d['image_base64']=(string)get_post_meta($p->ID,'_rf_image',true);
  }
  if($own){$d['status']=$p->post_status;$d['rejected']=get_post_meta($p->ID,'_rf_rejected',true)==='1';}
  return $d;
 }
 static function query($r,$own=false){
  $page=max(1,min(10000,absint($r->get_param('page')?:1)));
  $args=['post_type'=>RVAZ_Family::TYPE,'post_status'=>$own?['publish','pending','draft','private']:'publish','has_password'=>false,'posts_per_page'=>$own?5:15,'paged'=>$page,'orderby'=>['date'=>'DESC','ID'=>'DESC']];
  if($own)$args['author']=get_current_user_id();
  $kind=$r->get_param('kind');
  if($kind!==null&&$kind!==''){
   if(!is_string($kind)||!isset(RVAZ_Family::kinds()[$kind]))return self::error('Ongeldig soort familiebericht.');
   $args['meta_query']=[['key'=>'_rf_kind','value'=>$kind]];
  }
  $q=new WP_Query($args);return self::response(['items'=>array_map(fn($p)=>self::item($p,$own),$q->posts),'has_more'=>$page<$q->max_num_pages]);
 }
 static function listing($r){return self::query($r);}
 static function mine($r){return self::query($r,true);}
 static function trash($r){
  $p=get_post(absint($r['id']));
  if(!$p||$p->post_type!==RVAZ_Family::TYPE||(int)$p->post_author!==get_current_user_id()||!in_array($p->post_status,['publish','pending','draft','private'],true))return self::error('Je kunt alleen je eigen familieberichten verwijderen.',403);
  if(!defined('EMPTY_TRASH_DAYS')||EMPTY_TRASH_DAYS<1)return self::error('Verwijderen is tijdelijk niet beschikbaar.',409);
  if(!wp_trash_post($p->ID))return self::error('Verwijderen is niet gelukt.',500);
  return self::response(['deleted'=>true]);
 }
 static function image($files){
  if(empty($files['image']))return '';
  $f=$files['image'];
  if(!isset($f['tmp_name'],$f['size'],$f['error'])||!is_string($f['tmp_name'])||$f['error']!==UPLOAD_ERR_OK||$f['size']>5*1024*1024||!is_uploaded_file($f['tmp_name']))return self::error('Kies een geldige afbeelding van maximaal 5 MB.');
  $dims=wp_getimagesize($f['tmp_name']);$mime=wp_get_image_mime($f['tmp_name']);
  if(!$dims||$dims[0]*$dims[1]>24000000||!in_array($mime,['image/jpeg','image/png','image/webp'],true))return self::error('Gebruik JPG, PNG of WebP van maximaal 24 megapixels.');
  $e=wp_get_image_editor($f['tmp_name']);if(is_wp_error($e))return self::error('Afbeelding kon niet verwerkt worden.');
  $res=$e->resize(1600,1600,false);if(is_wp_error($res))return self::error('Afbeelding kon niet verkleind worden.');
  $e->set_quality(85);$tmp=wp_tempnam('rf-native.jpg');if(!$tmp)return self::error('Afbeelding kon niet opgeslagen worden.',500);
  $saved=$e->save($tmp,'image/jpeg');
  if(is_wp_error($saved)){@unlink($tmp);return self::error('Afbeelding kon niet opgeslagen worden.');}
  $bytes=file_get_contents($saved['path']);@unlink($saved['path']);if($saved['path']!==$tmp)@unlink($tmp);
  if(!$bytes||strlen($bytes)>2*1024*1024)return self::error('Kies een kleinere afbeelding.');
  return base64_encode($bytes);
 }
 static function submit($r){
  $v=[];foreach(['title','message','kind','background','font','align','layout','place','permission','request_id'] as $k){$x=$r->get_param($k);if(!is_string($x))return self::error('Vul alle verplichte velden in.');$v[$k]=$x;}
  $v['title']=sanitize_text_field($v['title']);$v['message']=sanitize_textarea_field($v['message']);
  if(!$v['title']||!$v['message']||mb_strlen($v['title'])>120||mb_strlen($v['message'])>3000||$v['permission']!=='1')return self::error('Controleer titel, tekst en toestemming.');
  foreach(['kind'=>RVAZ_Family::kinds(),'background'=>RVAZ_Family::backgrounds(),'font'=>['serif'=>1,'sans'=>1],'align'=>['center'=>1,'left'=>1],'layout'=>['card'=>1,'image'=>1]] as $k=>$options)if(!isset($options[$v[$k]]))return self::error('Kies een geldige kaartopmaak.');
  if(!in_array($v['place'],['Hellevoetsluis','Brielle','Rockanje','Oostvoorne','Oudenhoorn','Nieuwenhoorn','Tinte','Vierpolders','Zwartewaal','Overig'],true)||!preg_match('/^[a-zA-Z0-9-]{16,80}$/D',$v['request_id']))return self::error('Controleer plaats en inzending.');
  $uid=get_current_user_id();$request_key='rf_native_request_'.hash('sha256',$uid.':'.$v['request_id']);
  $existing=(int)get_transient($request_key);if($existing){$p=get_post($existing);if($p&&(int)$p->post_author===$uid)return self::response(['id'=>$existing,'status'=>$p->post_status]);}
  $lock='rf_native_lock_'.$uid;
  // Atomic per-account lock avoids duplicate parallel app submissions. Expired
  // locks are removed after a bounded period if a worker was interrupted.
  $old=(int)get_option($lock,0);if($old&&$old<time()-300)delete_option($lock);
  if(!add_option($lock,time(),'','no'))return self::error('Je bericht wordt al verwerkt. Probeer straks opnieuw.',409);
  try{
   $existing=(int)get_transient($request_key);if($existing)return self::response(['id'=>$existing,'status'=>get_post_status($existing)]);
   if(get_transient('rf_submit_'.$uid))return self::error('Wacht een minuut voordat je nog een bericht verstuurt.',429);
   $image=self::image($r->get_file_params());if(is_wp_error($image))return $image;
   if($v['layout']==='image'&&!$image)return self::error('Voeg je zelfgemaakte kaart toe.');
   $id=wp_insert_post(wp_slash(['post_type'=>RVAZ_Family::TYPE,'post_status'=>'pending','post_author'=>$uid,'post_title'=>$v['title'],'post_content'=>$v['message']]),true);
   if(is_wp_error($id))return self::error('Opslaan is niet gelukt.',500);
   foreach(['kind','background','font','align','layout','place'] as $k)update_post_meta($id,'_rf_'.$k,$v[$k]);
   update_post_meta($id,'_rf_permission_at',current_time('mysql'));
   if($image){update_post_meta($id,'_rf_image',$image);update_post_meta($id,'_rf_has_image',1);}
   set_transient('rf_submit_'.$uid,1,MINUTE_IN_SECONDS);set_transient($request_key,$id,DAY_IN_SECONDS);
   return self::response(['id'=>$id,'status'=>'pending']);
  }finally{delete_option($lock);}
 }
}
add_action('rest_api_init',['RVAZ_Family_Native_API','register']);
