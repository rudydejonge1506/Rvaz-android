<?php
if(!defined('ABSPATH'))exit;
final class RVAZ_Wonen_Broker_Registration {
 static $intent=false;
 static function normalize(){
  if(empty($_POST['rvaz_member_register'])||($_POST['account_type']??'')!=='makelaar')return;
  if(!wp_verify_nonce($_POST['rvaz_wonen_registration_nonce']??'','rvaz_wonen_registration'))return;
  // Let Members perform its existing account, nonce and email verification flow.
  self::$intent=true;$_POST['account_type']='business';$_REQUEST['account_type']='business';
  $_POST['return_to']=home_url('/mijn-wonen/');$_REQUEST['return_to']=$_POST['return_to'];
 }
 static function remember($uid){if(!self::$intent||sanitize_email($_POST['email']??'')!==get_userdata($uid)->user_email)return;update_user_meta($uid,'rvaz_wonen_registration_intent','makelaar');$office=sanitize_text_field($_POST['company']??'');if($office)update_user_meta($uid,'rvaz_wonen_office_name',$office);}
 static function content($html){
  if(strpos($html,'name="rvaz_member_register"')!==false&&strpos($html,'value="makelaar"')===false){
   $choice='<label><input type="radio" name="account_type" value="makelaar"> Ik ben makelaar</label><p class="rvaz-note">Makelaar? Maak je account aan en bevestig je e-mail. Daarna kies je in Mijn Wonen je abonnement en dien je je makelaarsaanvraag in. RVAZ beoordeelt de aanvraag vóór je woningen kunt publiceren.</p>'.wp_nonce_field('rvaz_wonen_registration','rvaz_wonen_registration_nonce',false,false);
   $html=preg_replace('/(<div\s+id="rvaz-company-field"[^>]*>)/',$choice.'$1',$html,1);
   $html=str_replace('id="rvaz-company-field" style="display:none"','id="rvaz-company-field" style="display:block"',$html);
   $html=str_replace('Bedrijfsnaam<input','Bedrijfsnaam / makelaarskantoor<input',$html);
  }
  if(is_user_logged_in()&&is_page(['mijn-rvaz','mijn-wonen'])&&get_user_meta(get_current_user_id(),'rvaz_wonen_registration_intent',true)==='makelaar'&&!in_array(RVAZ_Wonen::ROLE,wp_get_current_user()->roles,true)){
   $html='<section class="rvaz-reader"><h2>Je makelaarsaccount afronden</h2><p>Je RVAZ-account is aangemaakt. Rond nu je makelaarsaanvraag en abonnementskeuze af in Mijn Wonen. Reeds ingediend? Daar zie je de aanvraagstatus.</p><a href="'.esc_url(home_url('/mijn-wonen/')).'">Naar Mijn Wonen en mijn makelaarsaanvraag</a></section>'.$html;
  }return $html;
 }
}
add_action('init',['RVAZ_Wonen_Broker_Registration','normalize'],0);
add_action('plugins_loaded',['RVAZ_Wonen_Broker_Registration','normalize'],0);
add_action('user_register',['RVAZ_Wonen_Broker_Registration','remember'],30);
add_filter('the_content',['RVAZ_Wonen_Broker_Registration','content'],90);
add_action('wp_enqueue_scripts',function(){if(is_page('registreren'))wp_enqueue_script('rvaz-broker-registration',plugins_url('broker-registration.js',__FILE__),[],'1.2.2',true);});
