<?php
/**
 * Plugin Name: RVAZ Wonen Native API
 * Description: Native Flutter API naast RVAZ Wonen; behoudt website, accounts en bestaande facturen.
 * Version: 1.2.4
 */
if (!defined('ABSPATH')) exit;
final class RVAZ_Wonen_Native_API {
 const NS = 'rvaz-wonen/v1';
 const FIELDS = ['adres','postcode','plaats','prijs','prijstype','borg','contractduur','aanvaarding','inkomenseisen','woningtype','transactie','status','bouwjaar','kamers','slaapkamers','badkamers','woonoppervlak','perceel','energielabel','tuin','balkon','garage','makelaar_url'];
 static $routes=[];
 const OFFICE = ['office_name','kvk','address','postcode','place','phone','website'];
 static function error($code, $message, $status=400) { return new WP_Error($code,$message,['status'=>$status]); }
 // Laat de bestaande App API haar eigen tokens, verloop en intrekking controleren.
 // Een lokaal aangeleverd user_id of tokenhash levert nooit toegang op.
 static function authenticated($r) {
  if (get_current_user_id()) return true;
  $token=trim((string)$r->get_header('authorization'));
  $x=trim((string)$r->get_header('x-rvaz-token'));
  if (!$token && $x) $token='Bearer '.$x;
  if (!preg_match('/^Bearer\s+\S+$/i',$token)) return self::error('rvaz_auth','Log opnieuw in via Mijn RVAZ.',401);
  $check=new WP_REST_Request('GET','/rvaz-app/v1/me');
  $check->set_header('authorization',$token);
  if ($x) $check->set_header('x-rvaz-token',$x);
  $response=rest_do_request($check);
  if ($response->get_status()!==200) return self::error('rvaz_auth','Log opnieuw in via Mijn RVAZ.',401);
  $data=$response->get_data();$uid=absint($data['user']['id']??$data['user']['ID']??0);
  if (!$uid || !get_userdata($uid)) return self::error('rvaz_auth','App-account kon niet worden bevestigd.',401);
  wp_set_current_user($uid);return true;
 }
 static function allowed($r) {
  $ok=self::authenticated($r);if(is_wp_error($ok))return $ok;
  $u=wp_get_current_user();
  if(strpos($r->get_route(),'/makelaar/woningen/')!==false&&get_post_meta(absint($r['id']),'_rvaz_wonen_private',true)==='1')return self::error('private','Gebruik particulier woningbeheer.',403);
  if(RVAZ_Wonen::blocked($u->ID))return self::error('rvaz_blocked','Je makelaarstoegang is geblokkeerd. Neem contact op met RVAZ.',403);
  if(!in_array(RVAZ_Wonen::ROLE,(array)$u->roles,true)&&!current_user_can('manage_options'))return self::error('rvaz_forbidden','Dit account heeft geen makelaarstoegang.',403);
  return true;
 }
 static function owned($id) {
  $p=get_post($id);return $p && $p->post_type===RVAZ_Wonen::TYPE && $p->post_status!=='trash' && ((int)$p->post_author===get_current_user_id()||current_user_can('manage_options'));
 }
 static function listing($id,$private=false) {
  $id=absint(is_object($id)?$id->ID:$id);$d=RVAZ_Wonen::fields($id);$d['id']=$id;
  $private_offer=get_post_meta($id,'_rvaz_wonen_private',true)==='1';$d['aanbieder_type']=$private_offer?'Particulier':'Makelaar';
  $uid=(int)get_post_field('post_author',$id);
  $d['title']=$d['adres']?:$d['title'];
  $d['makelaar_naam']=(string)get_user_meta($uid,'rvaz_wonen_office_name',true);
  $d['makelaar_telefoon']=(string)get_user_meta($uid,'rvaz_wonen_phone',true);
  if(empty($d['makelaar_url']))$d['makelaar_url']=(string)get_user_meta($uid,'rvaz_wonen_website',true);
  if($d['makelaar_url']&&!preg_match('#^https?://#i',$d['makelaar_url']))$d['makelaar_url']='https://'.$d['makelaar_url'];
  $d['gallery']=[];$photos=[];
  foreach(array_unique(array_map('absint',(array)get_post_meta($id,'_rvaz_wonen_gallery',true))) as $aid){
   $url=wp_get_attachment_image_url($aid,'large');if(!$url)continue;
   $d['gallery'][]=$url;$photos[]=['id'=>$aid,'url'=>$url];
  }
  if($private){$d['publication_status']=get_post_status($id);$d['photos']=$photos;$d['news_promo']=(string)get_post_meta($id,'_rvaz_wonen_news_promo',true);}
  else foreach(['views','contact_clicks','agent_clicks'] as $key)unset($d[$key]);
  if($private_offer){$d['makelaar_naam']='Particulier aanbod';$d['makelaar_telefoon']='';$d['makelaar_url']='';if($private){$d['placement_expires']=(int)get_post_meta($id,'_rvaz_wonen_private_expires',true);$invoice=RVAZ_Wonen_Private::invoice($id);$d['payment_status']=$invoice['status']??'not_ordered';$d['review_reason']=(string)get_post_meta($id,'_rvaz_wonen_private_reason',true);}}
  return $d;
 }
 static function route($path,$methods,$callback,$permission='allowed') {
  self::$routes[$path][]=['methods'=>$methods,'callback'=>[__CLASS__,$callback],'permission_callback'=>$permission==='public'?'__return_true':[__CLASS__,$permission]];
 }
 static function register() {
  if(!class_exists('RVAZ_Wonen'))return;self::$routes=[];
  self::route('/woningen','GET','public_list','public');
  self::route('/makelaar/me','GET','me','authenticated');
  self::route('/makelaar/aanmelden','POST','apply','authenticated');
  self::route('/makelaar/woningen','GET','list_own');
  self::route('/makelaar/woningen','POST','save');
  self::route('/makelaar/woningen/(?P<id>\d+)','POST,PUT,PATCH','save');
  self::route('/makelaar/woningen/(?P<id>\d+)/verwijderen','POST','trash');
  self::route('/makelaar/woningen/(?P<id>\d+)/fotos','POST','photo');
  self::route('/makelaar/woningen/(?P<id>\d+)/galerij','POST','gallery');
  self::route('/makelaar/woningen/(?P<id>\d+)/promotie','POST','promo');
  self::route('/makelaar/aanvragen','GET','inbox');
  self::route('/makelaar/aanvragen/(?P<id>\d+)','POST','message');
  self::route('/makelaar/kantoor','GET','office');
  self::route('/makelaar/kantoor','POST','save_office');
  self::route('/makelaar/kantoor/logo','POST','logo');
  self::route('/makelaar/instellingen','GET','settings');
  self::route('/makelaar/instellingen','POST','save_settings');
  self::route('/makelaar/dashboard','GET','dashboard');
  self::route('/makelaar/abonnement','GET','subscription');
  self::route('/makelaar/abonnement','POST','change_plan');
  self::route('/makelaar/abonnement/opzeggen','POST','cancel');
  self::route('/makelaar/facturen','GET','invoices');
  self::route('/makelaar/facturen/(?P<id>\d+)/pdf','GET','invoice_pdf');
  foreach(self::$routes as $path=>$endpoints)register_rest_route(self::NS,$path,$endpoints,true);
 }
 static function public_list() {
  if(class_exists('RVAZ_Wonen_Private'))RVAZ_Wonen_Private::expires();
  $args=['post_type'=>RVAZ_Wonen::TYPE,'post_status'=>'publish','numberposts'=>100,'author__not_in'=>array_map('intval',get_users(['meta_key'=>'rvaz_wonen_blocked','meta_value'=>'1','fields'=>'ID']))];
  return array_map([__CLASS__,'listing'],get_posts($args));
 }
 static function me() {
  global $wpdb;$u=wp_get_current_user();$blocked=RVAZ_Wonen::blocked($u->ID);
  return ['user_id'=>$u->ID,'name'=>$u->display_name,'makelaar'=>!$blocked&&(in_array(RVAZ_Wonen::ROLE,(array)$u->roles,true)||current_user_can('manage_options')),'blocked'=>$blocked,'plans'=>RVAZ_Wonen_Intro::plans($u->ID),'application'=>$wpdb->get_row($wpdb->prepare("SELECT id,office,plan,status FROM {$wpdb->prefix}rvaz_wonen_applications WHERE user_id=%d ORDER BY id DESC LIMIT 1",$u->ID),ARRAY_A)];
 }
 static function own_posts() {return get_posts(['post_type'=>RVAZ_Wonen::TYPE,'post_status'=>['publish','draft','pending'],'numberposts'=>-1,'author'=>get_current_user_id()]);}
 static function list_own() {return array_map(function($p){return self::listing($p->ID,true);},self::own_posts());}
 static function publishing($uid) {
  global $wpdb;$sub=$wpdb->get_row($wpdb->prepare("SELECT * FROM {$wpdb->prefix}rvaz_wonen_subscriptions WHERE user_id=%d AND status='active' ORDER BY id DESC LIMIT 1",$uid));$prices=RVAZ_Wonen::prices();
  if(!$sub||empty($prices[$sub->plan]))return self::error('subscription','Geen actief Wonen-abonnement.',403);
  $override=get_user_meta($uid,'rvaz_wonen_limit_override',true);$limit=$override!==''?(int)$override:(int)$prices[$sub->plan]['limit'];
  if($limit>0&&count_user_posts($uid,RVAZ_Wonen::TYPE,true)>=$limit)return self::error('limit','Je pakketlimiet is bereikt.',403);
  return true;
 }
 static function save($r) {
  $id=absint($r->get_param('id'));
  if($id&&!self::owned($id))return self::error('forbidden','Geen toegang tot deze woning.',403);
  $status=$r->has_param('publication_status')?$r['publication_status']:($id?get_post_status($id):'draft');
  if(!in_array($status,['draft','publish','pending'],true))return self::error('status','Ongeldige publicatiestatus.');
  foreach(array_merge(self::FIELDS,['title','description']) as $key)if($r->has_param($key)&&!is_scalar($r[$key]))return self::error('field','Ongeldige waarde voor '.$key.'.');
  if($status==='publish'&&(!$id||get_post_status($id)!=='publish')){
   $ok=self::publishing($id?(int)get_post_field('post_author',$id):get_current_user_id());if(is_wp_error($ok))return $ok;
  }
  $post=['post_status'=>$status];
  if($r->has_param('title'))$post['post_title']=sanitize_text_field($r['title']);
  if($r->has_param('description'))$post['post_content']=wp_kses_post($r['description']);
  if($id){$post['ID']=$id;$result=wp_update_post($post,true);}else{$post+=['post_type'=>RVAZ_Wonen::TYPE,'post_author'=>get_current_user_id(),'post_title'=>'Nieuwe woning'];$result=wp_insert_post($post,true);}
  if(is_wp_error($result))return $result;$id=(int)$result;
  foreach(self::FIELDS as $key)if($r->has_param($key))update_post_meta($id,'_rvaz_wonen_'.$key,$key==='makelaar_url'?esc_url_raw($r[$key]):sanitize_text_field($r[$key]));
  return self::listing($id,true);
 }
 static function trash($r) {
  $id=absint($r['id']);if(!self::owned($id))return self::error('forbidden','Geen toegang tot deze woning.',403);
  if($r['confirm']!==true)return self::error('confirm','Bevestig het verplaatsen naar de prullenbak.');
  if(!wp_trash_post($id))return self::error('trash','Verwijderen is niet gelukt.',500);return ['deleted'=>true];
 }
 static function upload($r,$parent=0) {
  $files=$r->get_file_params();if(empty($files['photo']))return self::error('photo','Foto ontbreekt.');$file=$files['photo'];
  if(!empty($file['error'])||empty($file['tmp_name'])||!is_uploaded_file($file['tmp_name']))return self::error('photo','Ongeldige foto-upload.');
  if(($file['size']??0)>wp_max_upload_size())return self::error('photo','De foto is te groot.');
  require_once ABSPATH.'wp-admin/includes/file.php';require_once ABSPATH.'wp-admin/includes/media.php';require_once ABSPATH.'wp-admin/includes/image.php';
  $type=wp_check_filetype_and_ext($file['tmp_name'],$file['name']);
  if(!in_array($type['type'],['image/jpeg','image/png','image/webp','image/gif'],true))return self::error('photo','Kies een JPG-, PNG-, WebP- of GIF-foto.');
  $_FILES['rvaz_native_photo']=$file;
  try{return media_handle_upload('rvaz_native_photo',$parent,[],['test_form'=>false,'mimes'=>['jpg|jpeg|jpe'=>'image/jpeg','png'=>'image/png','webp'=>'image/webp','gif'=>'image/gif']]);}
  finally{unset($_FILES['rvaz_native_photo']);}
 }
 static function photo($r) {
  $id=absint($r['id']);if(!self::owned($id))return self::error('forbidden','Geen toegang tot deze woning.',403);
  $aid=self::upload($r,$id);if(is_wp_error($aid))return $aid;
  $gallery=array_map('absint',(array)get_post_meta($id,'_rvaz_wonen_gallery',true));$gallery[]=$aid;update_post_meta($id,'_rvaz_wonen_gallery',array_values(array_unique($gallery)));if(!has_post_thumbnail($id))set_post_thumbnail($id,$aid);return self::listing($id,true);
 }
 static function gallery($r) {
  $id=absint($r['id']);if(!self::owned($id))return self::error('forbidden','Geen toegang tot deze woning.',403);
  $ids=$r['photo_ids'];if(!is_array($ids))return self::error('gallery','Ongeldige fotolijst.');
  $old=array_map('absint',(array)get_post_meta($id,'_rvaz_wonen_gallery',true));$new=array_values(array_unique(array_map('absint',$ids)));
  foreach($new as $aid)if(!$aid||!in_array($aid,$old,true))return self::error('gallery','Deze foto hoort niet bij deze woning.',403);
  update_post_meta($id,'_rvaz_wonen_gallery',$new);if($new)set_post_thumbnail($id,$new[0]);else delete_post_thumbnail($id);
  return self::listing($id,true); // Verwijder alleen de koppeling; behoud mediabestanden.
 }
 static function office() {$data=[];$uid=get_current_user_id();foreach(self::OFFICE as $key)$data[$key]=(string)get_user_meta($uid,'rvaz_wonen_'.$key,true);$data['logo']=(string)(wp_get_attachment_image_url((int)get_user_meta($uid,'rvaz_wonen_office_logo',true),'medium')?:'');return $data;}
 static function save_office($r) {foreach(self::OFFICE as $key)if($r->has_param($key)){if(!is_scalar($r[$key]))return self::error('field','Ongeldige kantoorwaarde.');update_user_meta(get_current_user_id(),'rvaz_wonen_'.$key,sanitize_text_field($r[$key]));}return self::office();}
 static function logo($r) {$id=self::upload($r);if(is_wp_error($id))return $id;update_user_meta(get_current_user_id(),'rvaz_wonen_office_logo',$id);return self::office();}
 static function settings() {$uid=get_current_user_id();return ['contact_email'=>get_user_meta($uid,'rvaz_wonen_contact_email',true)?:wp_get_current_user()->user_email,'email_notifications'=>get_user_meta($uid,'rvaz_wonen_email_notifications',true)==='1'];}
 static function save_settings($r) {
  $email=sanitize_email($r['contact_email']);if(!is_email($email))return self::error('email','Vul een geldig e-mailadres in.');
  update_user_meta(get_current_user_id(),'rvaz_wonen_contact_email',$email);update_user_meta(get_current_user_id(),'rvaz_wonen_email_notifications',$r['email_notifications']===true?'1':'0');return self::settings();
 }
 static function inbox(){global $wpdb;return $wpdb->get_results($wpdb->prepare("SELECT id,property_id,name,email,phone,message,status,created FROM {$wpdb->prefix}rvaz_wonen_messages WHERE agent_user_id=%d ORDER BY created DESC LIMIT 200",get_current_user_id()),ARRAY_A);}
 static function message($r) {
  global $wpdb;$id=absint($r['id']);$table=$wpdb->prefix.'rvaz_wonen_messages';
  $row=$wpdb->get_row($wpdb->prepare("SELECT id FROM $table WHERE id=%d AND agent_user_id=%d",$id,get_current_user_id()));if(!$row)return self::error('forbidden','Geen toegang tot dit bericht.',403);
  if($r['action']==='read')$wpdb->update($table,['status'=>'read'],['id'=>$id]);elseif($r['action']==='delete'&&$r['confirm']===true)$wpdb->delete($table,['id'=>$id]);else return self::error('action','Ongeldige berichtactie.');return ['success'=>true];
 }
 static function dashboard() {
  $data=['published'=>0,'draft'=>0,'sold'=>0,'views'=>0,'contact_clicks'=>0,'agent_clicks'=>0];foreach(self::own_posts() as $p){$data[$p->post_status==='publish'?'published':'draft']++;$status=strtolower((string)get_post_meta($p->ID,'_rvaz_wonen_status',true));if(in_array($status,['verkocht','verhuurd'],true))$data['sold']++;foreach(['views','contact_clicks','agent_clicks'] as $key)$data[$key]+=(int)get_post_meta($p->ID,'_rvaz_wonen_'.$key,true);}
  global $wpdb;$uid=get_current_user_id();$data['unread_messages']=(int)$wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM {$wpdb->prefix}rvaz_wonen_messages WHERE agent_user_id=%d AND status='new'",$uid));
  $sub=self::subscription();$active=($sub['subscription']['status']??'')==='active';$plan=$sub['subscription']['plan']??'';$price=$sub['plans'][$plan]??[];
  $data['subscription_active']=$active;$data['plan_name']=$price['name']??'Geen actief abonnement';$data['limit']=$active?($sub['limit_override']!==''?(int)$sub['limit_override']:(int)($price['limit']??0)):0;
  $data['remaining']=$active?($data['limit']===0?null:max(0,$data['limit']-$data['published'])):0;
  $data['attention']=[];foreach(self::own_posts() as $p){$d=self::listing($p->ID,true);$missing=[];foreach(['adres'=>'Adres','plaats'=>'Plaats','prijs'=>'Prijs','transactie'=>'Koop/huur'] as $key=>$label)if(empty($d[$key]))$missing[]=$label;if(empty($d['image']))$missing[]='Hoofdfoto';if($missing)$data['attention'][]=['id'=>$p->ID,'title'=>$p->post_title,'missing'=>$missing];}
  return $data;
 }
 static function subscription() {
  global $wpdb;return ['subscription'=>$wpdb->get_row($wpdb->prepare("SELECT id,plan,status,start_date,end_date,next_invoice_date,cancelled_date FROM {$wpdb->prefix}rvaz_wonen_subscriptions WHERE user_id=%d ORDER BY id DESC LIMIT 1",get_current_user_id()),ARRAY_A),'plans'=>RVAZ_Wonen::prices(),'limit_override'=>get_user_meta(get_current_user_id(),'rvaz_wonen_limit_override',true)];
 }
 static function change_plan($r) {
  if($r['confirm']!==true)return self::error('confirm','Bevestig het gekozen pakket en de maandprijs.');$plan=sanitize_key($r['plan']);$p=RVAZ_Wonen::prices();
  if(!in_array($plan,['basis','plus','pro'],true)||empty($p[$plan]['enabled']))return self::error('plan','Ongeldig pakket.');
  if(!isset($r['expected_price'])||(string)$r['expected_price']!==(string)$p[$plan]['price'])return self::error('price','De prijs is gewijzigd. Vernieuw de pakketten voordat je bevestigt.',409);
  global $wpdb;$uid=get_current_user_id();$table=$wpdb->prefix.'rvaz_wonen_subscriptions';$sub=$wpdb->get_row($wpdb->prepare("SELECT * FROM $table WHERE user_id=%d AND status='active' ORDER BY id DESC LIMIT 1",$uid));
  if(!$sub)return self::error('subscription','Een nieuw abonnement moet eerst door RVAZ worden goedgekeurd.',403);
  if($sub->plan===$plan)return self::subscription();
  $limit=(int)$p[$plan]['limit'];if($limit>0&&count_user_posts($uid,RVAZ_Wonen::TYPE,true)>$limit)return self::error('limit','Maak eerst woningen inactief om dit pakket te kiezen.',409);
  if($wpdb->update($table,['plan'=>$plan],['id'=>$sub->id])===false)return self::error('database','Pakket wijzigen is niet gelukt.',500);
  if(!RVAZ_Wonen::create_invoice($uid,$plan)){$wpdb->update($table,['plan'=>$sub->plan],['id'=>$sub->id]);return self::error('invoice','Factuur kon niet worden aangemaakt; pakket is teruggezet.',500);}return self::subscription();
 }
 static function cancel($r) {
  if($r['confirm']!==true)return self::error('confirm','Bevestig dat je abonnement stopt en woningen concept worden.');
  global $wpdb;$wpdb->update($wpdb->prefix.'rvaz_wonen_subscriptions',['status'=>'cancelled','cancelled_date'=>current_time('Y-m-d'),'next_invoice_date'=>null],['user_id'=>get_current_user_id(),'status'=>'active']);
  foreach(self::own_posts() as $p)if(in_array($p->post_status,['publish','pending'],true))wp_update_post(['ID'=>$p->ID,'post_status'=>'draft']);return self::subscription();
 }
 static function invoices() {
  global $wpdb;$rows=$wpdb->get_results($wpdb->prepare("SELECT id,invoice_no,period,subtotal,vat,total,status,invoice_date,due_date,tikkie_url,pdf_url,paid_date FROM {$wpdb->prefix}rvaz_wonen_invoices WHERE user_id=%d ORDER BY id DESC",get_current_user_id()),ARRAY_A);return ['items'=>RVAZ_Wonen_Invoice_Tools::visible($rows),'billing'=>RVAZ_Wonen::billing()];
 }
 static function invoice_pdf($r) {
  global $wpdb;$row=$wpdb->get_row($wpdb->prepare("SELECT * FROM {$wpdb->prefix}rvaz_wonen_invoices WHERE id=%d AND user_id=%d",absint($r['id']),get_current_user_id()));
  if(!$row||RVAZ_Wonen_Invoice_Tools::removed(absint($r['id'])))return self::error('forbidden','Geen toegang tot deze factuur.',403);
  return self::render_invoice_pdf($row,wp_get_current_user());
 }
 static function render_invoice_pdf($row,$u) {
  $b=RVAZ_Wonen::billing();$office=get_user_meta($u->ID,'rvaz_wonen_office_name',true);
  $lines=['RVAZ Wonen','FACTUUR '.$row->invoice_no,'','Aan: '.($office?:$u->display_name),$u->user_email,'','Factuurdatum: '.$row->invoice_date,'Vervaldatum: '.$row->due_date,'Periode: '.$row->period,'',
    'Subtotaal: EUR '.number_format((float)$row->subtotal,2,',','.'),'BTW: EUR '.number_format((float)$row->vat,2,',','.'),'Totaal: EUR '.number_format((float)$row->total,2,',','.'),'Status: '.$row->status,'',
    'IBAN: '.$b['iban'],'Rekeninghouder: '.$b['account_name'],$b['address'],$b['postcode_city'],$b['email'],$b['note']];
  $content="BT\n/F1 11 Tf\n50 790 Td\n";foreach($lines as $i=>$line){if($i)$content.="0 -24 Td\n";$content.="(".RVAZ_Wonen::pdf_escape($line).") Tj\n";}$content.="ET";
  $objects=["1 0 obj<< /Type /Catalog /Pages 2 0 R >>endobj","2 0 obj<< /Type /Pages /Kids [3 0 R] /Count 1 >>endobj","3 0 obj<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>endobj","4 0 obj<< /Length ".strlen($content)." >>stream\n$content\nendstream\nendobj","5 0 obj<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>endobj"];
  $pdf="%PDF-1.4\n";$offset=[0];foreach($objects as $object){$offset[]=strlen($pdf);$pdf.=$object."\n";}$xref=strlen($pdf);$pdf.="xref\n0 6\n0000000000 65535 f \n";for($i=1;$i<=5;$i++)$pdf.=sprintf("%010d 00000 n \n",$offset[$i]);$pdf.="trailer<< /Size 6 /Root 1 0 R >>\nstartxref\n$xref\n%%EOF";
  return ['filename'=>sanitize_file_name($row->invoice_no).'.pdf','pdf_base64'=>base64_encode($pdf)];
 }
 static function promo($r) {
  $id=absint($r['id']);if(!self::owned($id))return self::error('forbidden','Geen toegang tot deze woning.',403);
  if($r['confirm']!==true||$r['expected_price']!=='29.00')return self::error('confirm','Bevestig de nieuwsaanvraag voor €29.');
  if(get_post_meta($id,'_rvaz_wonen_news_promo',true)!=='requested'){update_post_meta($id,'_rvaz_wonen_news_promo','requested');update_post_meta($id,'_rvaz_wonen_news_promo_price','29.00');update_post_meta($id,'_rvaz_wonen_news_promo_requested',current_time('mysql'));}return self::listing($id,true);
 }
 static function apply($r) {
  if(RVAZ_Wonen::blocked(get_current_user_id()))return self::error('blocked','Neem contact op met RVAZ.',403);
  global $wpdb;$uid=get_current_user_id();$plan=sanitize_key($r['plan']);$prices=RVAZ_Wonen::prices();if(!in_array($plan,['basis','plus','pro'],true)||empty($prices[$plan]['enabled']))return self::error('plan','Ongeldig abonnement.');
  if($r['confirm']!==true||(string)$r['expected_price']!==(string)$prices[$plan]['price'])return self::error('confirm','Bevestig het abonnement en de actuele maandprijs.');
  $quote=RVAZ_Wonen_Intro::plans($uid)[$plan];if($r->has_param('expected_first_month_price')&&(string)$r['expected_first_month_price']!==(string)$quote['first_month_price'])return self::error('quote','De introductieprijs is gewijzigd. Vernieuw de tarieven.',409);
  $values=[];foreach(['office','contact_name','phone'] as $key){$values[$key]=sanitize_text_field($r[$key]);if($values[$key]==='')return self::error('required','Vul alle verplichte velden in.');}
  $table=$wpdb->prefix.'rvaz_wonen_applications';$existing=$wpdb->get_row($wpdb->prepare("SELECT id,status FROM $table WHERE user_id=%d AND status IN ('email_pending','pending','approved') ORDER BY id DESC LIMIT 1",$uid));if($existing)return ['status'=>$existing->status,'id'=>(int)$existing->id];
  if(!$wpdb->insert($table,$values+['user_id'=>$uid,'plan'=>$plan,'status'=>'email_pending','created'=>current_time('mysql')]))return self::error('database','Aanvraag opslaan is niet gelukt.',500);
  $id=$wpdb->insert_id;update_user_meta($uid,'rvaz_wonen_intro_quote_'.$id,['regular'=>(string)$quote['price'],'first'=>(string)$quote['first_month_price']]);$token=wp_generate_password(32,false,false);update_user_meta($uid,'rvaz_wonen_verify_token',wp_hash_password($token));$url=add_query_arg(['action'=>'rvaz_wonen_verify_agent','uid'=>$uid,'app'=>$id,'token'=>$token],admin_url('admin-post.php'));
  if(!wp_mail(wp_get_current_user()->user_email,'Bevestig je RVAZ Wonen makelaarsaanvraag',"Bevestig je e-mailadres:\n$url\n\nDaarna moet RVAZ je aanvraag nog goedkeuren."))return self::error('email','Aanvraag opgeslagen, maar de bevestigingsmail kon niet worden verstuurd. Neem contact op met RVAZ.',500);
  return ['id'=>$id,'status'=>'email_pending'];
 }
 static function install() {
  // Alleen ontbrekende kolommen toevoegen. Geen bedragen, abonnementen of pagina's herschrijven.
  if(!class_exists('RVAZ_Wonen'))return;global $wpdb;require_once ABSPATH.'wp-admin/includes/upgrade.php';$c=$wpdb->get_charset_collate();
  $schemas=[
   'applications'=>"id bigint unsigned NOT NULL AUTO_INCREMENT,\nuser_id bigint unsigned NOT NULL,\noffice varchar(190) NOT NULL,\nplan varchar(20) NOT NULL DEFAULT '',\ncontact_name varchar(190) NOT NULL DEFAULT '',\nphone varchar(60) NOT NULL DEFAULT '',\nstatus varchar(20) NOT NULL DEFAULT 'pending',\ncreated datetime NOT NULL,\nPRIMARY KEY  (id)",
   'subscriptions'=>"id bigint unsigned NOT NULL AUTO_INCREMENT,\nuser_id bigint unsigned NOT NULL,\nplan varchar(20) NOT NULL,\nstatus varchar(20) NOT NULL DEFAULT 'active',\nstart_date date NULL,\nend_date date NULL,\nnext_invoice_date date NULL,\ncancelled_date date NULL,\nPRIMARY KEY  (id)",
   'invoices'=>"id bigint unsigned NOT NULL AUTO_INCREMENT,\nuser_id bigint unsigned NOT NULL,\ninvoice_no varchar(50) NOT NULL,\nperiod varchar(100) NOT NULL,\nsubtotal decimal(10,2) NOT NULL,\nvat decimal(10,2) NOT NULL,\ntotal decimal(10,2) NOT NULL,\nstatus varchar(20) NOT NULL DEFAULT 'open',\ninvoice_date date NULL,\ndue_date date NULL,\ntikkie_url text NULL,\npdf_url text NULL,\npaid_date date NULL,\nPRIMARY KEY  (id),\nUNIQUE KEY invoice_no (invoice_no)",
   'messages'=>"id bigint unsigned NOT NULL AUTO_INCREMENT,\nproperty_id bigint unsigned NOT NULL,\nagent_user_id bigint unsigned NOT NULL,\nname varchar(190) NOT NULL,\nemail varchar(190) NOT NULL,\nphone varchar(60) NOT NULL DEFAULT '',\nmessage text NOT NULL,\nstatus varchar(20) NOT NULL DEFAULT 'new',\ncreated datetime NOT NULL,\nPRIMARY KEY  (id),\nKEY agent_user_id (agent_user_id),\nKEY property_id (property_id)"
  ];foreach($schemas as $table=>$schema)dbDelta("CREATE TABLE {$wpdb->prefix}rvaz_wonen_$table (\n$schema\n) $c;");update_option('rvaz_wonen_native_api_version','1.2.4');
 }
}
add_action('rest_api_init',['RVAZ_Wonen_Native_API','register'],20);
register_activation_hook(__FILE__,['RVAZ_Wonen_Native_API','install']);
add_action('admin_init',function(){if(get_option('rvaz_wonen_native_api_version')!=='1.2.4')RVAZ_Wonen_Native_API::install();});

require_once __DIR__.'/reader-features.php';

require_once __DIR__.'/private-offers.php';
require_once __DIR__.'/intro-offer.php';
require_once __DIR__.'/account-dashboard.php';

require_once __DIR__.'/invoice-tools.php';

require_once __DIR__.'/broker-registration.php';

require_once __DIR__.'/private-account.php';
require_once __DIR__.'/invoice-mail.php';

require_once __DIR__.'/featured-homes.php';

require_once __DIR__.'/room-types.php';
