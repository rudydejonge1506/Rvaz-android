<?php
final class RVAZ_Native_Events_20261022 {
 static function auth($r) {
  if (!class_exists('RVAZ_Wonen_Native_API')) return new WP_Error('unavailable','Aanmelden is tijdelijk niet beschikbaar.',['status'=>503]);
  return RVAZ_Wonen_Native_API::authenticated($r);
 }
 static function error($text){return new WP_Error('event_invalid',$text,['status'=>400]);}
 static function date_ok($v){$d=DateTimeImmutable::createFromFormat('!Y-m-d',$v);return $d&&$d->format('Y-m-d')===$v;}
 static function submit($r){
  if(!post_type_exists('rvaz_event'))return self::error('Evenementen zijn niet beschikbaar.');
  $uid=get_current_user_id();if(!$uid)return new WP_Error('auth','Log eerst in.',['status'=>401]);
  $p=$r->get_params();$v=[];
  foreach(['title','description','start_date','end_date','start_time','end_time','location','address','price','url','repeat','repeat_until'] as $k){
   if(isset($p[$k])&&!is_scalar($p[$k]))return self::error('Ongeldig veld.');
   $v[$k]=sanitize_textarea_field((string)($p[$k]??''));
  }
  $key=sanitize_key((string)($p['request_id']??''));
  if(!$key||strlen($key)>80)return self::error('Ongeldige aanvraag.');
  $done='rvaz_event_done_'.md5($uid.':'.$key);
  if($id=get_transient($done))return ['id'=>(int)$id,'status'=>'pending'];
  if(!$v['title']||!$v['description']||!self::date_ok($v['start_date']))return self::error('Vul titel, beschrijving en een geldige startdatum in.');
  foreach(['end_date','repeat_until'] as $k)if($v[$k]&&(!self::date_ok($v[$k])||$v[$k]<$v['start_date']))return self::error('Een einddatum mag niet voor de startdatum liggen.');
  foreach(['start_time','end_time'] as $k)if($v[$k]&&!preg_match('/^([01]\d|2[0-3]):[0-5]\d$/',$v[$k]))return self::error('Ongeldige tijd.');
  if(($v['end_date']?:$v['start_date'])===$v['start_date']&&$v['start_time']&&$v['end_time']&&$v['end_time']<$v['start_time'])return self::error('De eindtijd ligt voor de starttijd.');
  if(!in_array($v['repeat'],['none','weekly','biweekly','monthly'],true))return self::error('Ongeldige herhaling.');
  if($v['repeat']!=='none'&&!$v['repeat_until'])return self::error('Kies een einddatum voor de herhaling.');
  if($v['url']&&!preg_match('#^https?://#i',$v['url']))return self::error('Gebruik een websiteadres met https:// of http://.');
  $cat=absint($p['category']??0);$term=get_term($cat,'rvaz_event_category');
  if(!$cat||!$term||is_wp_error($term))return self::error('Kies een geldige categorie.');
  $files=$r->get_file_params();$image=$files['event_image']??null;
  if($image){
   if($image['error']!==UPLOAD_ERR_OK||$image['size']>5*1024*1024)return self::error('Kies een afbeelding van maximaal 5 MB.');
   $mime=wp_get_image_mime($image['tmp_name']);
   if(!in_array($mime,['image/jpeg','image/png','image/webp'],true))return self::error('Kies een JPG-, PNG- of WebP-afbeelding.');
  }
  $lock='rvaz_event_lock_'.$uid;
  $previous=(int)get_option($lock,0);
  if($previous&&$previous<time()-120)delete_option($lock);
  if(!add_option($lock,time(),'','no'))return new WP_Error('busy','Een inzending wordt nog verwerkt. Probeer het later opnieuw.',['status'=>429]);
  try {
   if($id=get_transient($done))return ['id'=>(int)$id,'status'=>'pending'];
   if(get_transient('rvaz_event_submit_'.$uid))return new WP_Error('rate','Wacht even voordat je opnieuw indient.',['status'=>429]);
   $id=wp_insert_post(['post_type'=>'rvaz_event','post_status'=>'pending','post_author'=>$uid,'post_title'=>wp_slash($v['title']),'post_content'=>wp_slash($v['description'])],true);
   if(is_wp_error($id))return $id;
   if($image){
    require_once ABSPATH.'wp-admin/includes/file.php';require_once ABSPATH.'wp-admin/includes/media.php';require_once ABSPATH.'wp-admin/includes/image.php';
    $aid=media_handle_upload('event_image',$id,[],['test_form'=>false,'mimes'=>['jpg|jpeg'=>'image/jpeg','png'=>'image/png','webp'=>'image/webp']]);
    if(is_wp_error($aid)){wp_trash_post($id);return self::error('Afbeelding uploaden mislukt. Je evenement is niet ingediend.');}
    set_post_thumbnail($id,$aid);
   }
   foreach(['start_date','end_date','start_time','end_time','location','address','price','repeat','repeat_until'] as $k)update_post_meta($id,'_rvaz_event_'.$k,wp_slash($v[$k]));
   update_post_meta($id,'_rvaz_event_url',esc_url_raw($v['url']));
   wp_set_object_terms($id,[$cat],'rvaz_event_category',false);
   update_post_meta($id,'_rvaz_event_category',$term->slug);update_post_meta($id,'rvaz_event_category',$term->slug);
   update_post_meta($id,'_rvaz_submitted_frontend',1);
   set_transient($done,$id,DAY_IN_SECONDS);set_transient('rvaz_event_submit_'.$uid,1,20);
   return new WP_REST_Response(['id'=>$id,'status'=>'pending'],201);
  } finally {delete_option($lock);}
 }
}
add_action('rest_api_init',function(){
 register_rest_route('rvaz-native-events/v1','/submit',['methods'=>'POST','permission_callback'=>['RVAZ_Native_Events_20261022','auth'],'callback'=>['RVAZ_Native_Events_20261022','submit']]);
});
