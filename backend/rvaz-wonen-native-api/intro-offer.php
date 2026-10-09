<?php
if(!defined('ABSPATH'))exit;
final class RVAZ_Wonen_Intro {
 static function eligible($uid){global $wpdb;return !get_user_meta($uid,'rvaz_wonen_intro_used',true)&&!$wpdb->get_var($wpdb->prepare("SELECT id FROM {$wpdb->prefix}rvaz_wonen_subscriptions WHERE user_id=%d LIMIT 1",$uid))&&!$wpdb->get_var($wpdb->prepare("SELECT id FROM {$wpdb->prefix}rvaz_wonen_invoices WHERE user_id=%d AND invoice_no NOT LIKE 'RVAZ-P-%%' LIMIT 1",$uid));}
 static function plans($uid){$plans=RVAZ_Wonen::prices();foreach(['basis','plus','pro'] as $key)if(isset($plans[$key]))$plans[$key]['first_month_price']=self::eligible($uid)?number_format(round((float)$plans[$key]['price']*.5,2),2,'.',''):(string)$plans[$key]['price'];return $plans;}
 static function approve($id,$decision){$lock='rvaz_wonen_review_lock_'.absint($id);if((int)get_option($lock,0)<time()-1800)delete_option($lock);if(!add_option($lock,time(),'','no'))return RVAZ_Wonen_Native_API::error('busy','Deze aanvraag wordt al verwerkt.',409);try{return self::decide($id,$decision);}finally{delete_option($lock);}}
 static function decide($id,$decision){
  global $wpdb;$row=$wpdb->get_row($wpdb->prepare("SELECT * FROM {$wpdb->prefix}rvaz_wonen_applications WHERE id=%d",$id));
  if(!$row||$row->status!=='pending'||!in_array($decision,['approve','reject'],true))return RVAZ_Wonen_Native_API::error('application','Ongeldige aanvraag.');
  if($decision==='reject'){$wpdb->update($wpdb->prefix.'rvaz_wonen_applications',['status'=>'rejected'],['id'=>$id]);return ['status'=>'rejected'];}
  $uid=(int)$row->user_id;if(!get_userdata($uid))return RVAZ_Wonen_Native_API::error('account','Account niet gevonden.');$plans=RVAZ_Wonen::prices();if(empty($plans[$row->plan]['enabled']))return RVAZ_Wonen_Native_API::error('plan','Dit abonnement is niet beschikbaar.');
  $eligible=self::eligible($uid);$amount=$eligible?number_format(round((float)$plans[$row->plan]['price']*.5,2),2,'.',''):(string)$plans[$row->plan]['price'];
  $quote=get_user_meta($uid,'rvaz_wonen_intro_quote_'.$id,true);if(is_array($quote)&&((string)$quote['regular']!==(string)$plans[$row->plan]['price']||(float)$quote['first']!==(float)$amount))return RVAZ_Wonen_Native_API::error('quote','De afgesproken prijs is gewijzigd. Laat eerst een nieuwe aanvraag bevestigen.',409);
  // Only the first invoice receives a temporary quote; stored tariff options never change.
  $priced=function($values)use($plans,$row,$amount){$values=wp_parse_args((array)$values,$plans);$values[$row->plan]['price']=$amount;return $values;};
  $existing=$wpdb->get_row($wpdb->prepare("SELECT * FROM {$wpdb->prefix}rvaz_wonen_subscriptions WHERE user_id=%d AND status='active' LIMIT 1",$uid));
  $start=time();$end=RVAZ_Wonen_Private::month_end($start);$sub=['plan'=>$row->plan,'status'=>'active','start_date'=>wp_date('Y-m-d',$start),'end_date'=>wp_date('Y-m-d',$end-1),'next_invoice_date'=>wp_date('Y-m-d',$end)];
  $changed=$existing?$wpdb->update($wpdb->prefix.'rvaz_wonen_subscriptions',['plan'=>$row->plan],['id'=>$existing->id]):$wpdb->insert($wpdb->prefix.'rvaz_wonen_subscriptions',$sub+['user_id'=>$uid]);if($changed===false)return RVAZ_Wonen_Native_API::error('database','Abonnement opslaan is niet gelukt.',500);$sid=$existing?$existing->id:$wpdb->insert_id;
  add_filter('option_rvaz_wonen_pricing',$priced);add_filter('default_option_rvaz_wonen_pricing',$priced);
  try{$invoice=RVAZ_Wonen::create_invoice($uid,$row->plan);}finally{remove_filter('option_rvaz_wonen_pricing',$priced);remove_filter('default_option_rvaz_wonen_pricing',$priced);}
  if(!$invoice){if($existing)$wpdb->update($wpdb->prefix.'rvaz_wonen_subscriptions',['plan'=>$existing->plan],['id'=>$sid]);else $wpdb->delete($wpdb->prefix.'rvaz_wonen_subscriptions',['id'=>$sid]);return RVAZ_Wonen_Native_API::error('invoice','Factuur kon niet worden aangemaakt.',500);}
  (new WP_User($uid))->add_role(RVAZ_Wonen::ROLE);update_user_meta($uid,'rvaz_wonen_office_name',$row->office);$wpdb->update($wpdb->prefix.'rvaz_wonen_applications',['status'=>'approved'],['id'=>$id]);
  if(!$existing)$wpdb->update($wpdb->prefix.'rvaz_wonen_invoices',['period'=>($eligible?'Introductieactie 50% — ':'').wp_date('d-m-Y',$start).' t/m '.wp_date('d-m-Y',$end-1)],['id'=>$invoice]);
  if($eligible){update_user_meta($uid,'rvaz_wonen_intro_used','1');update_user_meta($uid,'rvaz_wonen_intro_invoice',(int)$invoice);}
  return ['status'=>'approved','invoice_id'=>(int)$invoice,'first_month_price'=>$amount,'discount_applied'=>$eligible];
 }
 static function handler(){
  if(!current_user_can('manage_options'))wp_die('Niet toegestaan');$id=absint($_GET['id']??0);if(!$id||!wp_verify_nonce($_GET['nonce']??'','rvaz_wonen_application_'.$id))wp_die('Niet toegestaan');
  $result=self::approve($id,sanitize_key($_GET['decision']??''));if(is_wp_error($result))wp_die(esc_html($result->get_error_message()));wp_safe_redirect(admin_url('admin.php?page=rvaz-wonen-aanvragen'));exit;
 }
}
add_action('plugins_loaded',function(){if(class_exists('RVAZ_Wonen')&&method_exists('RVAZ_Wonen','application_decision')){remove_action('admin_post_rvaz_wonen_application_decision',['RVAZ_Wonen','application_decision']);add_action('admin_post_rvaz_wonen_application_decision',['RVAZ_Wonen_Intro','handler']);}},30);
add_filter('do_shortcode_tag',function($output,$tag){if(in_array($tag,['rvaz_wonen_agents','rvaz_wonen_pricing','rvaz_wonen_portal'],true)){$text='<div class="rvaz-reader"><strong>Introductieactie voor nieuwe makelaars: 50% korting op de eerste abonnementsmaand.</strong><p>Daarna geldt het normale maandtarief. Eenmalig per nieuw makelaarsaccount; bestaande abonnementen worden niet aangepast.</p><ul>';foreach(['basis','plus','pro'] as $key){$p=RVAZ_Wonen::prices()[$key];if(!empty($p['enabled']))$text.='<li>'.esc_html($p['name']).': eerste maand €'.esc_html(number_format((float)$p['price']*.5,2,',','.')).', daarna €'.esc_html(number_format((float)$p['price'],2,',','.')).' per maand.</li>';}$text.='</ul></div>';$output=$text.$output;}return $output;},40,2);
