<?php
if (!defined('ABSPATH')) exit;
/** Coupon storage shared by broker subscriptions and private placement invoices. */
final class RVAZ_Wonen_Coupons {
 const VERSION = '1.2.4';
 static function table(){global $wpdb;return $wpdb->prefix.'rvaz_wonen_coupons';}
 static function uses(){global $wpdb;return $wpdb->prefix.'rvaz_wonen_coupon_uses';}
 static function code($s){return strtoupper(preg_replace('/[^A-Z0-9_-]/','',strtoupper(sanitize_text_field((string)$s))));}
 static function install(){
  if (!class_exists('RVAZ_Wonen') || get_option('rvaz_wonen_coupons_schema')===self::VERSION) return;
  global $wpdb;require_once ABSPATH.'wp-admin/includes/upgrade.php';$c=$wpdb->get_charset_collate();
  dbDelta('CREATE TABLE '.self::table()." (
    id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
    code varchar(60) NOT NULL,
    audience varchar(20) NOT NULL DEFAULT 'both',
    kind varchar(10) NOT NULL DEFAULT 'percent',
    value decimal(10,2) NOT NULL DEFAULT 0,
    max_uses int(11) unsigned NOT NULL DEFAULT 1,
    enabled tinyint(1) NOT NULL DEFAULT 1,
    expires date NULL,
    created datetime NOT NULL,
    PRIMARY KEY  (id),
    UNIQUE KEY code (code)
  ) $c;");
  dbDelta('CREATE TABLE '.self::uses()." (
    id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
    coupon_id bigint(20) unsigned NOT NULL,
    user_id bigint(20) unsigned NOT NULL,
    audience varchar(20) NOT NULL,
    target_id bigint(20) unsigned NOT NULL,
    status varchar(12) NOT NULL DEFAULT 'reserved',
    created datetime NOT NULL,
    updated datetime NOT NULL,
    PRIMARY KEY  (id),
    UNIQUE KEY target_coupon (coupon_id,audience,target_id),
    KEY coupon_status (coupon_id,status),
    KEY user_coupon (user_id,coupon_id)
  ) $c;");
  if (!$wpdb->get_var($wpdb->prepare('SELECT id FROM '.self::table().' WHERE code=%s','MAKELAAR'))) {
   $wpdb->insert(self::table(),['code'=>'MAKELAAR','audience'=>'makelaar','kind'=>'percent','value'=>100,'max_uses'=>2,'enabled'=>1,'expires'=>null,'created'=>current_time('mysql')]);
  }
  update_option('rvaz_wonen_coupons_schema',self::VERSION,false);
 }
 static function get($code){global $wpdb;$code=self::code($code);return $code?$wpdb->get_row($wpdb->prepare('SELECT * FROM '.self::table().' WHERE code=%s',$code)):null;}
 static function count($id){global $wpdb;return (int)$wpdb->get_var($wpdb->prepare('SELECT COUNT(*) FROM '.self::uses()." WHERE coupon_id=%d AND status IN ('reserved','used')",$id));}
 static function quote($code,$audience,$original,$uid=0){
  $original=round(max(0,(float)$original),2);$coupon=self::get($code);if(!$coupon)return RVAZ_Wonen_Native_API::error('coupon','Kortingscode bestaat niet.',400);
  if(!$coupon->enabled || ($coupon->expires && $coupon->expires<wp_date('Y-m-d')) || !in_array($coupon->audience,['both',$audience],true))return RVAZ_Wonen_Native_API::error('coupon','Kortingscode is niet geldig voor deze aanvraag.',400);
  if(self::count($coupon->id)>=(int)$coupon->max_uses)return RVAZ_Wonen_Native_API::error('coupon_full','De kortingscode is helaas al volledig gebruikt.',409);
  if($uid){global $wpdb;$already=$wpdb->get_var($wpdb->prepare('SELECT id FROM '.self::uses()." WHERE coupon_id=%d AND user_id=%d AND status IN ('reserved','used') LIMIT 1",$coupon->id,$uid));if($already)return RVAZ_Wonen_Native_API::error('coupon_user','Deze kortingscode is al gebruikt door dit account.',409);}
  $off=$coupon->kind==='percent'?$original*(float)$coupon->value/100:(float)$coupon->value;
  return ['code'=>$coupon->code,'coupon_id'=>(int)$coupon->id,'normal'=>number_format($original,2,'.',''),'discount'=>number_format(min($original,max(0,$off)),2,'.',''),'total'=>number_format(max(0,$original-$off),2,'.',''),'remaining'=>max(0,(int)$coupon->max_uses-self::count($coupon->id))];
 }
 static function lock($id){$k='rvaz_wonen_coupon_lock_'.absint($id);if((int)get_option($k,0)<time()-30)delete_option($k);return add_option($k,time(),'','no')?$k:false;}
 static function reserve($code,$audience,$original,$user_id,$target_id){
  $item=self::get($code);if(!$item)return RVAZ_Wonen_Native_API::error('coupon','Kortingscode bestaat niet.');$lock=self::lock($item->id);if(!$lock)return RVAZ_Wonen_Native_API::error('coupon_busy','Er wordt al een kortingscode verwerkt. Probeer het opnieuw.',409);
  try{
   $quote=self::quote($code,$audience,$original,$user_id);if(is_wp_error($quote))return $quote;
   global $wpdb;
   if($audience==='makelaar'){
    $office=(string)$wpdb->get_var($wpdb->prepare('SELECT office FROM '.$wpdb->prefix.'rvaz_wonen_applications WHERE id=%d AND user_id=%d',$target_id,$user_id));
    if(!$office)return RVAZ_Wonen_Native_API::error('coupon_office','Kantoornaam ontbreekt in de aanvraag.',400);
    $used_offices=$wpdb->get_col($wpdb->prepare('SELECT a.office FROM '.self::uses().' u INNER JOIN '.$wpdb->prefix."rvaz_wonen_applications a ON a.id=u.target_id WHERE u.coupon_id=%d AND u.audience='makelaar' AND u.status IN ('reserved','used')",$item->id));
    foreach((array)$used_offices as $existing_office)if(strtolower(trim($office))===strtolower(trim((string)$existing_office)))return RVAZ_Wonen_Native_API::error('coupon_office','Dit makelaarskantoor heeft deze kortingscode al gebruikt.',409);
   }
   $now=current_time('mysql');$ok=$wpdb->insert(self::uses(),['coupon_id'=>$item->id,'user_id'=>$user_id,'audience'=>$audience,'target_id'=>$target_id,'status'=>'reserved','created'=>$now,'updated'=>$now]);
   if(!$ok)return RVAZ_Wonen_Native_API::error('coupon_save','Kortingscode kon niet worden vastgelegd.',409);
   return $quote;
  }finally{delete_option($lock);}
 }
 static function application($id){global $wpdb;return $wpdb->get_row($wpdb->prepare('SELECT u.*,c.code,c.kind,c.value FROM '.self::uses().' u JOIN '.self::table().' c ON c.id=u.coupon_id WHERE u.audience=%s AND u.target_id=%d AND u.status IN (\'reserved\',\'used\') LIMIT 1','makelaar',$id));}
 static function mark($audience,$target_id,$status){global $wpdb;return $wpdb->update(self::uses(),['status'=>$status,'updated'=>current_time('mysql')],['audience'=>$audience,'target_id'=>absint($target_id),'status'=>'reserved']);}
 static function preview($r){
  $audience=sanitize_key($r['audience']??'makelaar');if(!in_array($audience,['makelaar','particulier'],true))return RVAZ_Wonen_Native_API::error('audience','Ongeldige doelgroep.');
  $uid=get_current_user_id();if(!$uid)return RVAZ_Wonen_Native_API::error('auth','Log eerst in.',401);
  if($audience==='makelaar'){$plan=sanitize_key($r['plan']??'basis');$prices=RVAZ_Wonen::prices();if(empty($prices[$plan]['enabled']))return RVAZ_Wonen_Native_API::error('plan','Selecteer eerst een pakket.');$amount=(float)$prices[$plan]['price'];}
  else $amount=(float)RVAZ_Wonen_Private::PRICE;
  $code=self::code($r['code']??'');if(!$code)return ['total'=>number_format($amount,2,'.',''),'discount'=>'0.00'];return self::quote($code,$audience,$amount,$uid);
 }
 static function admin(){
  if(!current_user_can('manage_options'))return;global $wpdb;$rows=$wpdb->get_results('SELECT * FROM '.self::table().' ORDER BY id DESC');
  echo '<div class="wrap"><h1>RVAZ Wonen · Kortingscodes</h1><p>Maak en beheer kortingscodes voor een makelaarsabonnement (alleen de eerste maand) of een particuliere woningplaatsing. Kortingen zijn nooit stapelbaar met de standaard 50% introductieactie.</p>';
  if(isset($_GET['coupon_notice']))echo '<div class="notice notice-info"><p>'.esc_html(sanitize_text_field(wp_unslash($_GET['coupon_notice']))).'</p></div>';
  echo '<h2>Nieuwe kortingscode</h2><form method="post" action="'.esc_url(admin_url('admin-post.php')).'"><input type="hidden" name="action" value="rvaz_coupon_save">';wp_nonce_field('rvaz_coupon_save');
  echo '<table class="form-table"><tr><th>Code</th><td><input name="code" required maxlength="60" pattern="[A-Za-z0-9_-]+" placeholder="bijv. WELKOM20"></td></tr><tr><th>Voor wie?</th><td><select name="audience"><option value="makelaar">Makelaars</option><option value="particulier">Particulieren</option><option value="both">Allebei</option></select></td></tr><tr><th>Korting</th><td><select name="kind"><option value="percent">Percentage (%)</option><option value="fixed">Vast bedrag (€)</option></select> <input name="value" type="number" min="0.01" step="0.01" required placeholder="bijv. 20"></td></tr><tr><th>Maximaal aantal gebruiken</th><td><input name="max_uses" type="number" min="1" value="1" required></td></tr><tr><th>Einddatum (optioneel)</th><td><input name="expires" type="date"></td></tr></table><p><button class="button button-primary">Kortingscode maken</button></p></form>';
  echo '<h2>Bestaande kortingscodes</h2><table class="widefat striped"><thead><tr><th>Code</th><th>Voor wie?</th><th>Korting</th><th>Gebruikt / gereserveerd</th><th>Geldig tot</th><th>Status</th><th>Actie</th></tr></thead><tbody>';
  foreach($rows as $r){$count=self::count($r->id);$type=$r->kind==='percent'?number_format((float)$r->value,0).'%':'€ '.number_format((float)$r->value,2,',','.');echo '<tr><td><strong>'.esc_html($r->code).'</strong></td><td>'.esc_html($r->audience).'</td><td>'.esc_html($type).'</td><td>'.(int)$count.' / '.(int)$r->max_uses.'</td><td>'.esc_html($r->expires?:'Geen').'</td><td>'.($r->enabled?'Actief':'Uitgeschakeld').'</td><td><form method="post" action="'.esc_url(admin_url('admin-post.php')).'"><input type="hidden" name="action" value="rvaz_coupon_toggle"><input type="hidden" name="coupon_id" value="'.(int)$r->id.'">'.wp_nonce_field('rvaz_coupon_toggle_'.$r->id,'_wpnonce',true,false).'<button class="button">'.($r->enabled?'Uitschakelen':'Inschakelen').'</button></form></td></tr>';}
  echo '</tbody></table></div>';
 }
 static function save(){if(!current_user_can('manage_options'))wp_die('Geen toegang');check_admin_referer('rvaz_coupon_save');global $wpdb;$code=self::code(wp_unslash($_POST['code']??''));$audience=sanitize_key($_POST['audience']??'');$kind=sanitize_key($_POST['kind']??'');$value=round((float)($_POST['value']??0),2);$max=absint($_POST['max_uses']??0);$expires=sanitize_text_field(wp_unslash($_POST['expires']??''));if(!$code||strlen($code)>60||!in_array($audience,['makelaar','particulier','both'],true)||!in_array($kind,['percent','fixed'],true)||$value<=0||($kind==='percent'&&$value>100)||$max<1||($expires&&!preg_match('/^\d{4}-\d{2}-\d{2}$/',$expires)))wp_die('Controleer je invoer.');$ok=$wpdb->insert(self::table(),['code'=>$code,'audience'=>$audience,'kind'=>$kind,'value'=>$value,'max_uses'=>$max,'enabled'=>1,'expires'=>$expires?:null,'created'=>current_time('mysql')]);self::back($ok?'Kortingscode aangemaakt.':'Deze code bestaat al of kon niet worden opgeslagen.');}
 static function toggle(){if(!current_user_can('manage_options'))wp_die('Geen toegang');$id=absint($_POST['coupon_id']??0);check_admin_referer('rvaz_coupon_toggle_'.$id);global $wpdb;$r=$wpdb->get_row($wpdb->prepare('SELECT enabled FROM '.self::table().' WHERE id=%d',$id));if($r)$wpdb->update(self::table(),['enabled'=>$r->enabled?0:1],['id'=>$id]);self::back('Status bijgewerkt.');}
 static function back($message){wp_safe_redirect(add_query_arg('coupon_notice',rawurlencode($message),admin_url('admin.php?page=rvaz-wonen-coupons')));exit;}
}
add_action('admin_init',['RVAZ_Wonen_Coupons','install'],20);
add_action('admin_menu',function(){if(class_exists('RVAZ_Wonen'))add_submenu_page('rvaz-wonen','Kortingscodes','Kortingscodes','manage_options','rvaz-wonen-coupons',['RVAZ_Wonen_Coupons','admin']);},45);
add_action('admin_post_rvaz_coupon_save',['RVAZ_Wonen_Coupons','save']);
add_action('admin_post_rvaz_coupon_toggle',['RVAZ_Wonen_Coupons','toggle']);
add_action('rest_api_init',function(){register_rest_route(RVAZ_Wonen_Native_API::NS,'/kortingscode/controleren',['methods'=>'POST','callback'=>['RVAZ_Wonen_Coupons','preview'],'permission_callback'=>['RVAZ_Wonen_Native_API','authenticated']]);},30);

add_action('wp_enqueue_scripts',function(){
 if(!class_exists('RVAZ_Wonen')||!is_user_logged_in()||!is_page(['mijn-wonen','wonen-voor-makelaars']))return;
 global $wpdb;$uid=get_current_user_id();$roles=(array)wp_get_current_user()->roles;
 $has_agent=in_array(RVAZ_Wonen::ROLE,$roles,true)||current_user_can('manage_options');
 $has_application=(bool)$wpdb->get_var($wpdb->prepare("SELECT id FROM {$wpdb->prefix}rvaz_wonen_applications WHERE user_id=%d AND status IN ('email_pending','pending','approved') LIMIT 1",$uid));
 $can_apply=!$has_agent&&!$has_application;
 if(!$can_apply)return;
 wp_enqueue_script('rvaz-wonen-coupons',plugins_url('coupons-website.js',__FILE__),[],RVAZ_Wonen_Coupons::VERSION,true);
 wp_add_inline_script('rvaz-wonen-coupons','window.rvazWonenCoupons='.wp_json_encode(['api'=>rest_url(RVAZ_Wonen_Native_API::NS),'nonce'=>wp_create_nonce('wp_rest'),'loggedIn'=>true,'canApply'=>true,'isMyWonen'=>is_page('mijn-wonen'),'plans'=>RVAZ_Wonen::prices(),'defaultPlan'=>'basis']).';','before');
},25);
