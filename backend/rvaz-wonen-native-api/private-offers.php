<?php
if(!defined('ABSPATH'))exit;
final class RVAZ_Wonen_Private {
 const FLAG='_rvaz_wonen_private';
 const PRICE='25.00';
 static function register(){
  if(!class_exists('RVAZ_Wonen'))return;
  foreach([
   '/particulier/woningen'=>[['GET','own'],['POST','save']],
   '/particulier/woningen/(?P<id>\d+)'=>[['POST','save']],
   '/particulier/woningen/(?P<id>\d+)/fotos'=>[['POST','photo']],
   '/particulier/woningen/(?P<id>\d+)/galerij'=>[['POST','gallery']],
   '/particulier/woningen/(?P<id>\d+)/verwijderen'=>[['POST','trash']],
   '/particulier/woningen/(?P<id>\d+)/indienen'=>[['POST','submit']],
   '/particulier/woningen/(?P<id>\d+)/bestellen'=>[['POST','order']],
   '/particulier/facturen'=>[['GET','invoices']],
   '/particulier/facturen/(?P<id>\d+)/pdf'=>[['GET','pdf']],
   '/particulier/aanvragen'=>[['GET','messages']],
   '/particulier/aanvragen/(?P<id>\d+)'=>[['POST','message']],
   '/particulier/tarief'=>[['GET','tariff']],
  ] as $path=>$routes){$handlers=[];foreach($routes as $route)$handlers[]=['methods'=>$route[0],'callback'=>[__CLASS__,$route[1]],'permission_callback'=>[__CLASS__,'allowed']];register_rest_route(RVAZ_Wonen_Native_API::NS,$path,$handlers);}
  register_rest_route(RVAZ_Wonen_Native_API::NS,'/woningen/(?P<id>\d+)/contact',['methods'=>'POST','callback'=>[__CLASS__,'contact'],'permission_callback'=>'__return_true']);
  register_rest_route(RVAZ_Wonen_Native_API::NS,'/beheer/particulier/(?P<id>\d+)',['methods'=>'POST','callback'=>[__CLASS__,'review'],'permission_callback'=>function(){return current_user_can('manage_options');}]);
 }
 static function allowed($r){$ok=RVAZ_Wonen_Native_API::authenticated($r);if(is_wp_error($ok))return $ok;if(RVAZ_Wonen::blocked(get_current_user_id()))return RVAZ_Wonen_Native_API::error('blocked','Je Wonen-account is geblokkeerd.',403);return true;}
 static function is_private($id){return get_post_type($id)===RVAZ_Wonen::TYPE&&get_post_meta($id,self::FLAG,true)==='1';}
 static function owns($id){return self::is_private($id)&&(int)get_post_field('post_author',$id)===get_current_user_id()&&get_post_status($id)!=='trash';}
 static function require_owner($r){return self::owns(absint($r['id']))?true:RVAZ_Wonen_Native_API::error('owner','Geen toegang tot deze particuliere woning.',403);}
 static function tariff(){return ['price'=>self::PRICE,'homes'=>1,'period'=>'1 kalendermaand','automatic_renewal'=>false,'review_required'=>true];}
 static function own(){return array_map(function($p){return RVAZ_Wonen_Native_API::listing($p->ID,true);},get_posts(['post_type'=>RVAZ_Wonen::TYPE,'author'=>get_current_user_id(),'post_status'=>['draft','pending','publish'],'numberposts'=>-1,'meta_key'=>self::FLAG,'meta_value'=>'1']));}
 static function save($r){
  $id=absint($r['id']);if($id){$ok=self::require_owner($r);if(is_wp_error($ok))return $ok;}
  if(!$id&&self::own())return RVAZ_Wonen_Native_API::error('limit','Je kunt één particuliere woning tegelijk aanbieden. Archiveer eerst je vorige woning.',409);
  if($r->has_param('publication_status')&&$r['publication_status']!=='draft')return RVAZ_Wonen_Native_API::error('review','Particulier aanbod wordt eerst door RVAZ beoordeeld.');
  if($r->has_param('transactie')&&$r['transactie']!=='Koop')return RVAZ_Wonen_Native_API::error('sale','Particulier aanbod is voorlopig alleen voor verkoop.');
  foreach(array_merge(RVAZ_Wonen_Native_API::FIELDS,['title','description']) as $k)if($r->has_param($k)&&!is_scalar($r[$k]))return RVAZ_Wonen_Native_API::error('field','Ongeldige woninggegevens.');
  $post=['post_status'=>'draft'];if($id)$post['ID']=$id;else $post+=['post_type'=>RVAZ_Wonen::TYPE,'post_author'=>get_current_user_id(),'post_title'=>'Mijn woning'];
  if($r->has_param('title'))$post['post_title']=sanitize_text_field($r['title']);if($r->has_param('description'))$post['post_content']=wp_kses_post($r['description']);
  $result=$id?wp_update_post($post,true):wp_insert_post($post,true);if(is_wp_error($result))return $result;$id=(int)$result;update_post_meta($id,self::FLAG,'1');
  foreach(RVAZ_Wonen_Native_API::FIELDS as $k)if($k!=='makelaar_url'&&$r->has_param($k))update_post_meta($id,'_rvaz_wonen_'.$k,sanitize_text_field($r[$k]));update_post_meta($id,'_rvaz_wonen_transactie','Koop');
  delete_post_meta($id,'_rvaz_wonen_private_approved');delete_post_meta($id,'_rvaz_wonen_private_reviewed');return RVAZ_Wonen_Native_API::listing($id,true);
 }
 static function photo($r){$ok=self::require_owner($r);if(is_wp_error($ok))return $ok;$id=absint($r['id']);$aid=RVAZ_Wonen_Native_API::upload($r,$id);if(is_wp_error($aid))return $aid;self::edited($id);$gallery=array_filter(array_map('absint',(array)get_post_meta($id,'_rvaz_wonen_gallery',true)));$gallery[]=$aid;update_post_meta($id,'_rvaz_wonen_gallery',array_values(array_unique($gallery)));if(!has_post_thumbnail($id))set_post_thumbnail($id,$aid);return RVAZ_Wonen_Native_API::listing($id,true);}
 static function gallery($r){$ok=self::require_owner($r);if(is_wp_error($ok))return $ok;$id=absint($r['id']);$ids=$r['photo_ids'];if(!is_array($ids))return RVAZ_Wonen_Native_API::error('gallery','Ongeldige fotolijst.');$old=array_map('absint',(array)get_post_meta($id,'_rvaz_wonen_gallery',true));foreach($ids as $aid)if(!is_scalar($aid)||!in_array(absint($aid),$old,true))return RVAZ_Wonen_Native_API::error('gallery','Deze foto hoort niet bij deze woning.',403);self::edited($id);return RVAZ_Wonen_Native_API::gallery($r);}
 static function edited($id){delete_post_meta($id,'_rvaz_wonen_private_approved');delete_post_meta($id,'_rvaz_wonen_private_reviewed');if(get_post_status($id)==='publish')wp_update_post(['ID'=>$id,'post_status'=>'pending']);}
 static function trash($r){$ok=self::require_owner($r);return is_wp_error($ok)?$ok:RVAZ_Wonen_Native_API::trash($r);}
 static function invoice($id){global $wpdb;$iid=absint(get_post_meta($id,'_rvaz_wonen_private_invoice',true));return $iid?$wpdb->get_row($wpdb->prepare("SELECT * FROM {$wpdb->prefix}rvaz_wonen_invoices WHERE id=%d AND user_id=%d",$iid,(int)get_post_field('post_author',$id)),ARRAY_A):null;}
 static function paid($id){$row=self::invoice($id);return $row&&$row['status']==='paid'&&(float)$row['total']===(float)self::PRICE;}
 static function complete($id){$d=RVAZ_Wonen_Native_API::listing($id,true);foreach(['title','description','adres','postcode','plaats','prijs','woningtype','woonoppervlak','energielabel'] as $k)if(empty($d[$k]))return RVAZ_Wonen_Native_API::error('required','Vul alle verplichte kenmerken, omschrijving en energielabel in.');if(RVAZ_Wonen_Reader::number($d['prijs'])===null||RVAZ_Wonen_Reader::number($d['prijs'])<=0)return RVAZ_Wonen_Native_API::error('price','Gebruik een geldige positieve vraagprijs.');if(!has_post_thumbnail($id))return RVAZ_Wonen_Native_API::error('photo','Voeg minstens één foto toe.');return true;}
 static function submit($r){
  $ok=self::require_owner($r);if(is_wp_error($ok))return $ok;$id=absint($r['id']);if($r['authority_confirmed']!==true||$r['photos_confirmed']!==true)return RVAZ_Wonen_Native_API::error('rights','Bevestig dat je bevoegd bent de woning aan te bieden en de foto’s mag gebruiken.');
  $ok=self::complete($id);if(is_wp_error($ok))return $ok;update_post_meta($id,'_rvaz_wonen_private_authority',current_time('mysql'));delete_post_meta($id,'_rvaz_wonen_private_approved');delete_post_meta($id,'_rvaz_wonen_private_reviewed');wp_update_post(['ID'=>$id,'post_status'=>'pending']);return RVAZ_Wonen_Native_API::listing($id,true);
 }
 static function order($r){
  $ok=self::require_owner($r);if(is_wp_error($ok))return $ok;$id=absint($r['id']);if($r['confirm']!==true||$r['expected_price']!==self::PRICE||$r['expected_period']!=='1_month')return RVAZ_Wonen_Native_API::error('quote','Bevestig €25 voor één woning, één kalendermaand.',409);
  if(get_post_status($id)!=='pending'||!get_post_meta($id,'_rvaz_wonen_private_authority',true)||!get_post_meta($id,'_rvaz_wonen_private_reviewed',true))return RVAZ_Wonen_Native_API::error('review','Dien eerst je complete woning in.');
  $old=self::invoice($id);$end=(int)get_post_meta($id,'_rvaz_wonen_private_expires',true);if($old&&$old['status']!=='cancelled'&&(!$end||$end>time()))return ['invoice_id'=>(int)$old['id'],'status'=>$old['status']];
  global $wpdb;$generation=(int)get_post_meta($id,'_rvaz_wonen_private_invoice_generation',true)+1;$no='RVAZ-P-'.$id.'-'.$generation;
  $existing=$wpdb->get_var($wpdb->prepare("SELECT id FROM {$wpdb->prefix}rvaz_wonen_invoices WHERE invoice_no=%s",$no));
  if(!$existing&&!$wpdb->insert($wpdb->prefix.'rvaz_wonen_invoices',['user_id'=>get_current_user_id(),'invoice_no'=>$no,'period'=>'Particuliere woning '.$id.' — één kalendermaand vanaf publicatie','subtotal'=>25,'vat'=>0,'total'=>25,'status'=>'open','invoice_date'=>current_time('Y-m-d'),'due_date'=>wp_date('Y-m-d',time()+14*DAY_IN_SECONDS)]))return RVAZ_Wonen_Native_API::error('invoice','Factuur opslaan is niet gelukt.',500);
  $iid=$existing?:$wpdb->insert_id;update_post_meta($id,'_rvaz_wonen_private_invoice',(int)$iid);update_post_meta($id,'_rvaz_wonen_private_invoice_generation',$generation);delete_post_meta($id,'_rvaz_wonen_private_expires');return ['invoice_id'=>(int)$iid,'status'=>'open'];
 }
 static function month_end($start){$d=(new DateTimeImmutable('@'.$start))->setTimezone(wp_timezone());$next=$d->modify('first day of next month');return $next->setDate((int)$next->format('Y'),(int)$next->format('m'),min((int)$d->format('d'),(int)$next->format('t')))->getTimestamp();}
 static function review($r){
  $id=absint($r['id']);if(!self::is_private($id)||get_post_status($id)==='trash')return RVAZ_Wonen_Native_API::error('property','Woning niet gevonden.',404);
  if($r['decision']==='reject'){update_post_meta($id,'_rvaz_wonen_private_reason',sanitize_textarea_field($r['reason']??''));self::edited($id);wp_update_post(['ID'=>$id,'post_status'=>'draft']);return ['status'=>'rejected'];}
  if($r['decision']!=='approve'||$r['authority_checked']!==true)return RVAZ_Wonen_Native_API::error('review','Bevestig de beoordeling van de bevoegdheid en woninggegevens.');
  if(get_post_status($id)!=='pending')return RVAZ_Wonen_Native_API::error('review','De woning is niet ingediend.',409);
  $ok=self::complete($id);if(is_wp_error($ok))return $ok;if(!get_post_meta($id,'_rvaz_wonen_private_authority',true))return RVAZ_Wonen_Native_API::error('rights','De verkoper heeft de bevoegdheid nog niet bevestigd.');update_post_meta($id,'_rvaz_wonen_private_reviewed',get_current_user_id());
  $end=(int)get_post_meta($id,'_rvaz_wonen_private_expires',true);if(!self::paid($id)||($end&&$end<=time()))return ['status'=>'awaiting_payment'];
  if(!$end){$start=time();update_post_meta($id,'_rvaz_wonen_private_started',$start);update_post_meta($id,'_rvaz_wonen_private_expires',self::month_end($start));}
  update_post_meta($id,'_rvaz_wonen_private_approved',get_current_user_id());delete_post_meta($id,'_rvaz_wonen_private_reason');wp_update_post(['ID'=>$id,'post_status'=>'publish']);return RVAZ_Wonen_Native_API::listing($id,true);
 }
 static function expires(){if(!class_exists('RVAZ_Wonen'))return;foreach(get_posts(['post_type'=>RVAZ_Wonen::TYPE,'post_status'=>'publish','numberposts'=>-1,'fields'=>'ids','meta_key'=>self::FLAG,'meta_value'=>'1']) as $id)if((int)get_post_meta($id,'_rvaz_wonen_private_expires',true)<=time()||!get_post_meta($id,'_rvaz_wonen_private_approved',true)||!self::paid($id))wp_update_post(['ID'=>$id,'post_status'=>'draft']);}
 static function contact($r){
  $id=absint($r['id']);if(!RVAZ_Wonen_Reader::visible($id))return RVAZ_Wonen_Native_API::error('property','Deze woning is niet beschikbaar.',404);
  foreach(['name','email','phone','message'] as $k)if($r->has_param($k)&&!is_scalar($r[$k]))return RVAZ_Wonen_Native_API::error('field','Ongeldige contactgegevens.');
  $name=sanitize_text_field($r['name']);$email=sanitize_email($r['email']);$phone=sanitize_text_field($r['phone']??'');$message=sanitize_textarea_field($r['message']);if(!$name||!is_email($email)||strlen($message)<3||strlen($message)>4000)return RVAZ_Wonen_Native_API::error('contact','Vul naam, geldig e-mailadres en een bericht van maximaal 4000 tekens in.');
  $duplicate='rvaz_contact_'.hash('sha256',$id.':'.$email.':'.$message);if(get_transient($duplicate))return ['success'=>true];
  $rate='rvaz_contact_rate_'.hash_hmac('sha256',($_SERVER['REMOTE_ADDR']??'unknown').':'.$id,wp_salt());$n=(int)get_transient($rate);if($n>=5)return RVAZ_Wonen_Native_API::error('rate','Je hebt al meerdere reacties gestuurd. Probeer later opnieuw.',429);
  global $wpdb;$owner=(int)get_post_field('post_author',$id);if(!$wpdb->insert($wpdb->prefix.'rvaz_wonen_messages',['property_id'=>$id,'agent_user_id'=>$owner,'name'=>$name,'email'=>$email,'phone'=>$phone,'message'=>$message,'status'=>'new','created'=>current_time('mysql')]))return RVAZ_Wonen_Native_API::error('message','Reactie opslaan is niet gelukt.',500);
  set_transient($duplicate,1,120);set_transient($rate,$n+1,HOUR_IN_SECONDS);$user=get_userdata($owner);if($user)wp_mail($user->user_email,'Reactie op jouw woning: '.get_the_title($id),"Naam: $name\nE-mail: $email\nTelefoon: $phone\n\n$message");return ['success'=>true];
 }
 static function invoices(){global $wpdb;return ['billing'=>RVAZ_Wonen::billing(),'items'=>RVAZ_Wonen_Invoice_Tools::visible($wpdb->get_results($wpdb->prepare("SELECT id,invoice_no,total,status,invoice_date,tikkie_url FROM {$wpdb->prefix}rvaz_wonen_invoices WHERE user_id=%d AND invoice_no LIKE 'RVAZ-P-%%' ORDER BY id DESC",get_current_user_id()),ARRAY_A))];}
 static function pdf($r){global $wpdb;$ok=$wpdb->get_var($wpdb->prepare("SELECT id FROM {$wpdb->prefix}rvaz_wonen_invoices WHERE id=%d AND user_id=%d AND invoice_no LIKE 'RVAZ-P-%%'",absint($r['id']),get_current_user_id()));return $ok?RVAZ_Wonen_Native_API::invoice_pdf($r):RVAZ_Wonen_Native_API::error('invoice','Geen toegang tot deze factuur.',403);}
 static function messages(){return RVAZ_Wonen_Native_API::inbox();}
 static function message($r){return RVAZ_Wonen_Native_API::message($r);}
}
add_action('rest_api_init',['RVAZ_Wonen_Private','expires'],5);
add_action('rest_api_init',['RVAZ_Wonen_Private','register'],40);
add_action('wp',['RVAZ_Wonen_Private','expires'],5);
add_action('rvaz_wonen_search_scan',['RVAZ_Wonen_Private','expires'],5);
add_filter('wp_insert_post_data',function($data,$postarr){$id=absint($postarr['ID']??0);if($id&&RVAZ_Wonen_Private::is_private($id)&&$data['post_status']==='publish'&&(!current_user_can('manage_options')||!get_post_meta($id,'_rvaz_wonen_private_approved',true)||!RVAZ_Wonen_Private::paid($id)||(int)get_post_meta($id,'_rvaz_wonen_private_expires',true)<=time()))$data['post_status']='pending';return $data;},20,2);
require_once __DIR__.'/private-website.php';
