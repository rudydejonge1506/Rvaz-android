<?php
if(!defined('ABSPATH'))exit;
$html='<form><input name="rvaz_member_register" value="1"><label><input type="radio" name="account_type" value="reader" checked>Lezer</label><label><input type="radio" name="account_type" value="business">Bedrijf</label><div id="rvaz-company-field" style="display:none"><label>Bedrijfsnaam<input name="company"></label></div></form>';
$rendered=RVAZ_Wonen_Broker_Registration::content($html);
check(strpos($rendered,'Ik ben makelaar')!==false&&strpos($rendered,'rvaz_wonen_registration_nonce')!==false,'registration shows broker choice with dedicated nonce');
check(substr_count(RVAZ_Wonen_Broker_Registration::content($rendered),'value="makelaar"')===1,'broker registration choice is not duplicated');
$_POST=['rvaz_member_register'=>'1','account_type'=>'makelaar','company'=>'CI makelaarskantoor','email'=>'broker-signup@example.invalid','rvaz_wonen_registration_nonce'=>'invalid'];RVAZ_Wonen_Broker_Registration::normalize();check(!RVAZ_Wonen_Broker_Registration::$intent&&$_POST['account_type']==='makelaar','invalid nonce cannot mark broker onboarding');
$_POST['rvaz_wonen_registration_nonce']=wp_create_nonce('rvaz_wonen_registration');RVAZ_Wonen_Broker_Registration::normalize();check($_POST['account_type']==='business'&&$_POST['return_to']===home_url('/mijn-wonen/'),'broker registration uses existing business account and local return route');
$candidate=wp_create_user('broker-signup','test-only-password','broker-signup@example.invalid');
check(get_user_meta($candidate,'rvaz_wonen_registration_intent',true)==='makelaar'&&get_user_meta($candidate,'rvaz_wonen_office_name',true)==='CI makelaarskantoor','new broker account remembers office and onboarding intent');
check(!in_array(RVAZ_Wonen::ROLE,(new WP_User($candidate))->roles,true),'choosing broker never self-grants publishing role');
check(!get_user_meta($candidate,'rvaz_wonen_email_verified',true),'broker signup does not bypass email verification');
$_POST=[];$_REQUEST=[];RVAZ_Wonen_Broker_Registration::$intent=false;
