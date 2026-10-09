<?php
if(!defined('ABSPATH'))exit;
// Disposable CI database only. Production snapshots contain no credentials.
add_filter('pre_wp_mail',function(){return true;});
require __DIR__.'/coupons.php';
require __DIR__.'/intro.php';
require __DIR__.'/private.php';
RVAZ_Wonen_Coupons::install();
function audit_check($ok,$message){if(!$ok)throw new RuntimeException($message);echo "PASS: $message\n";}
global $wpdb;$prices=RVAZ_Wonen::prices();
foreach(['basis','plus','pro'] as $plan){$q=RVAZ_Wonen_Coupons::quote('MAKELAAR','makelaar',$prices[$plan]['price']);audit_check(!is_wp_error($q)&&$q['total']==='0.00',"$plan first month is zero with MAKELAAR");}
$officeA=wp_create_user('audit-office-a','test-only-password','audit-a@example.invalid');
$duplicate=wp_create_user('audit-office-duplicate','test-only-password','audit-duplicate@example.invalid');
$officeB=wp_create_user('audit-office-b','test-only-password','audit-b@example.invalid');
$officeC=wp_create_user('audit-office-c','test-only-password','audit-c@example.invalid');
function audit_application($uid,$office,$plan){global $wpdb;$wpdb->insert($wpdb->prefix.'rvaz_wonen_applications',['user_id'=>$uid,'office'=>$office,'plan'=>$plan,'contact_name'=>'CI test','phone'=>'000','status'=>'pending','created'=>current_time('mysql')]);return $wpdb->insert_id;}
$a=audit_application($officeA,'Audit Office A','basis');
$q=RVAZ_Wonen_Coupons::reserve('MAKELAAR','makelaar',49,$officeA,$a);audit_check(!is_wp_error($q),'first office reserves first coupon place');
$dup=audit_application($duplicate,' AUDIT OFFICE A ','basis');
audit_check(is_wp_error(RVAZ_Wonen_Coupons::reserve('MAKELAAR','makelaar',49,$duplicate,$dup)),'same office through another account rejected');
$approved=RVAZ_Wonen_Audit_Intro::approve($a,'approve');
audit_check(!is_wp_error($approved)&&$approved['first_month_price']==='0.00','coupon replaces rather than stacks with introductory discount');
$invoice=$wpdb->get_row($wpdb->prepare("SELECT * FROM {$wpdb->prefix}rvaz_wonen_invoices WHERE id=%d",$approved['invoice_id']));
audit_check((float)$invoice->total===0.0&&$invoice->status==='paid','first free invoice has zero balance and no payment due');
$b=audit_application($officeB,'Audit Office B','plus');
audit_check(!is_wp_error(RVAZ_Wonen_Coupons::reserve('MAKELAAR','makelaar',99,$officeB,$b)),'second distinct office reserves remaining place');
audit_check(!is_wp_error(RVAZ_Wonen_Audit_Intro::approve($b,'approve')),'second office approved');
$c=audit_application($officeC,'Audit Office C','pro');
audit_check(is_wp_error(RVAZ_Wonen_Coupons::reserve('MAKELAAR','makelaar',179,$officeC,$c)),'third office cannot reserve a coupon');
audit_check(RVAZ_Wonen_Coupons::count(RVAZ_Wonen_Coupons::get('MAKELAAR')->id)===2,'limit remains exactly two uses');
foreach([$officeA=>'basis',$officeB=>'plus'] as $uid=>$plan){
 $id=RVAZ_Wonen::create_invoice($uid,$plan);$next=$wpdb->get_row($wpdb->prepare("SELECT * FROM {$wpdb->prefix}rvaz_wonen_invoices WHERE id=%d",$id));
 audit_check((float)$next->total===(float)$prices[$plan]['price'],"$plan next recurring invoice uses the full normal tariff");
}
foreach([['PRIV20','percent',20,20],['PRIV10','fixed',10,15],['PRIVFREE','fixed',50,0]] as [$code,$kind,$value,$expected]){
 $wpdb->insert(RVAZ_Wonen_Coupons::table(),['code'=>$code,'audience'=>'particulier','kind'=>$kind,'value'=>$value,'max_uses'=>3,'enabled'=>1,'created'=>current_time('mysql')]);
 $uid=wp_create_user('audit-'.strtolower($code),'test-only-password',strtolower($code).'@example.invalid');wp_set_current_user($uid);
 $id=wp_insert_post(['post_type'=>RVAZ_Wonen::TYPE,'post_status'=>'pending','post_title'=>'Private audit housing','post_author'=>$uid]);
 update_post_meta($id,'_rvaz_wonen_private','1');update_post_meta($id,'_rvaz_wonen_private_authority','1');update_post_meta($id,'_rvaz_wonen_private_reviewed',1);
 $r=new WP_REST_Request('POST');$r->set_body_params(['id'=>$id,'confirm'=>true,'expected_price'=>'25.00','expected_period'=>'1_month','coupon_code'=>$code]);
 $result=RVAZ_Wonen_Audit_Private::order($r);
 audit_check(!is_wp_error($result)&&(float)$result['total']===(float)$expected,"$code private invoice has the correct discounted amount");
 audit_check($result['status']===($expected===0?'paid':'open'),"$code private invoice payment state is correct");
 $again=RVAZ_Wonen_Audit_Private::order($r);audit_check($again['invoice_id']===$result['invoice_id'],"$code order retry cannot duplicate an invoice");
 audit_check(is_wp_error(RVAZ_Wonen_Coupons::quote($code,'makelaar',49)),"$code cannot be used for brokers");
}
echo "All isolated live-coupon snapshot checks passed. No production writes or real emails.\n";

require __DIR__.'/portal-focus.php';
$markup='<div class="rvaz-reader"><strong>Introductieactie voor nieuwe makelaars: 50%</strong><ul><li>Prijs</li></ul></div><div class="rvw"><h2>Abonnement</h2><form><input name="nonce" value="keep-existing-nonce"><button>Opzeggen</button></form></div><section class="rvaz-reader" aria-label="Mijn favoriete woningen"><h2>Favorieten</h2><div id="rvaz-reader-root"></div></section><section class="rvaz-reader"><h2>Zelf je woning verkopen</h2><a href="/account/">Account</a></section>';
wp_set_current_user($officeA);$_GET['wonen_portal']='abonnement';
$focused=rvaz_wonen_portal_focus_20261009($markup,'rvaz_wonen_portal');
audit_check(strpos($focused,'Introductieactie')===false&&strpos($focused,'rvaz-reader-root')===false&&strpos($focused,'Zelf je woning')===false,'subscription portal excludes appended marketing and reader blocks');
audit_check(strpos($focused,'keep-existing-nonce')!==false&&strpos($focused,'Opzeggen')!==false,'existing subscription form remains intact');
$_GET['wonen_portal']='dashboard';$dashboard=rvaz_wonen_portal_focus_20261009($markup,'rvaz_wonen_portal');
audit_check(strpos($dashboard,'<details')!==false&&strpos($dashboard,'rvaz-reader-root')!==false,'dashboard keeps reader functions collapsed');
update_user_meta($officeA,'rvaz_wonen_blocked','1');
$blocked=rvaz_wonen_portal_focus_20261009('<h2>RVAZ Wonen geblokkeerd</h2>'.$markup,'rvaz_wonen_portal');
audit_check(strpos($blocked,'RVAZ Wonen geblokkeerd')!==false&&strpos($blocked,'rvaz-reader-root')===false,'blocked access remains blocked and uncluttered');
audit_check(rvaz_wonen_portal_focus_20261009($markup,'rvaz_wonen')===$markup,'public housing page unchanged');
echo "All portal layout preservation checks passed.\n";

require dirname(__DIR__,2).'/website/rvaz-wonen-account-fix/rvaz-wonen-account-fix.php';
delete_user_meta($officeA,'rvaz_wonen_blocked');
wp_set_current_user($officeA);
audit_check(is_wp_error(RVAZ_Wonen_Account_Fix::archive($officeA,true)),'broker cannot deactivate accounts through administrator action');
$admin=get_user_by('login','ci_admin');wp_set_current_user($admin->ID);
audit_check(is_wp_error(RVAZ_Wonen_Account_Fix::archive($officeA,false)),'deactivation requires explicit confirmation');
$brokerPost=wp_insert_post(['post_type'=>RVAZ_Wonen::TYPE,'post_status'=>'publish','post_title'=>'Broker archive test','post_author'=>$officeA]);
$privatePost=wp_insert_post(['post_type'=>RVAZ_Wonen::TYPE,'post_status'=>'publish','post_title'=>'Private archive test','post_author'=>$officeA]);update_post_meta($privatePost,'_rvaz_wonen_private','1');
$before=$wpdb->get_results($wpdb->prepare("SELECT * FROM {$wpdb->prefix}rvaz_wonen_invoices WHERE user_id=%d ORDER BY id",$officeA),ARRAY_A);
$result=RVAZ_Wonen_Account_Fix::archive($officeA,true);
audit_check(!is_wp_error($result)&&get_userdata($officeA)!==false,'deactivation preserves the ordinary user account');
audit_check(!in_array(RVAZ_Wonen::ROLE,get_userdata($officeA)->roles,true)&&RVAZ_Wonen_Account_Fix::inactive($officeA),'deactivation removes broker access and stops subscription');
audit_check(get_post_status($brokerPost)==='draft'&&get_post_status($privatePost)==='publish','deactivation drafts broker listings and preserves private listings');
audit_check($before===$wpdb->get_results($wpdb->prepare("SELECT * FROM {$wpdb->prefix}rvaz_wonen_invoices WHERE user_id=%d ORDER BY id",$officeA),ARRAY_A),'past invoices remain unchanged');
wp_set_current_user($officeA);
$r=new WP_REST_Request('POST');$data=['plan'=>'basis','confirm'=>true,'expected_price'=>$prices['basis']['price'],'expected_first_month_price'=>$prices['basis']['price'],'office'=>'Audit Office A','contact_name'=>'CI return','phone'=>'000','coupon_code'=>'MAKELAAR'];$r->set_body_params($data);
audit_check(is_wp_error(RVAZ_Wonen_Account_Fix::apply($r)),'returning office cannot receive new-customer MAKELAAR discount again');
$data['coupon_code']='';$data['expected_price']='0.00';$r->set_body_params($data);audit_check(is_wp_error(RVAZ_Wonen_Account_Fix::apply($r)),'returning application rejects stale or tampered pricing');
$data['expected_price']=$prices['basis']['price'];$r->set_body_params($data);
update_user_meta($officeA,'rvaz_wonen_blocked','1');audit_check(is_wp_error(RVAZ_Wonen_Account_Fix::apply($r)),'separate access block prevents reapplication');delete_user_meta($officeA,'rvaz_wonen_blocked');
$return=RVAZ_Wonen_Account_Fix::apply($r);audit_check(!is_wp_error($return)&&$return['status']==='pending'&&$return['id']!==$a,'cancelled broker can request a fresh package despite old approved application');
audit_check($wpdb->get_var($wpdb->prepare("SELECT status FROM {$wpdb->prefix}rvaz_wonen_applications WHERE id=%d",$a))==='approved','old approved application history remains intact');
$repeat=RVAZ_Wonen_Account_Fix::apply($r);audit_check($repeat['id']===$return['id'],'repeated request does not duplicate returning application');
$approve=RVAZ_Wonen_Audit_Intro::approve($return['id'],'approve');audit_check(!is_wp_error($approve)&&$approve['first_month_price']===(string)$prices['basis']['price'],'returning broker approval uses full normal first-month price');
audit_check(!RVAZ_Wonen_Account_Fix::inactive($officeA)&&in_array(RVAZ_Wonen::ROLE,get_userdata($officeA)->roles,true),'approval restores broker role and active subscription');
audit_check(is_wp_error(RVAZ_Wonen_Account_Fix::apply($r)),'active subscription cannot create another subscription request');
echo "All account deactivation and returning subscription checks passed.\n";
wp_set_current_user($officeA);$wpdb->update($wpdb->prefix.'rvaz_wonen_subscriptions',['status'=>'cancelled'],['user_id'=>$officeA]);
audit_check(!RVAZ_Wonen_Subscription_Access::writable($officeA),'cancelled broker cannot write properties');
$wizard='<div class="rvw"><div class="rvw-layout"><nav>Facturen</nav><main><form><input name="adres"><button>Publiceren</button></form></main></div></div>';$_GET['wonen_portal']='nieuw';
$gated=RVAZ_Wonen_Subscription_Access::portal($wizard,'rvaz_wonen_portal');audit_check(strpos($gated,'name="adres"')===false&&strpos($gated,'Nieuw pakket kiezen')!==false,'cancelled portal replaces property form with package link');
$req=new WP_REST_Request('POST');audit_check(is_wp_error(RVAZ_Wonen_Subscription_Access::permission($req,'__return_true')),'cancelled broker API write denied');
$wpdb->update($wpdb->prefix.'rvaz_wonen_subscriptions',['status'=>'active'],['user_id'=>$officeA]);audit_check(RVAZ_Wonen_Subscription_Access::writable($officeA),'active broker keeps property write access');
wp_set_current_user($officeC);$r=new WP_REST_Request('POST');$r->set_body_params(['title'=>'Room for rent','transactie'=>'Huur','woningtype'=>'Kamer','prijs'=>'650','borg'=>'650','publication_status'=>'draft']);
$room=RVAZ_Wonen_Private_UI::save($r,['RVAZ_Wonen_Audit_Private','save']);audit_check(!is_wp_error($room)&&$room['transactie']==='Huur'&&$room['woningtype']==='Kamer','compatibility layer allows private room rental using original owner validation');
$edit=new WP_REST_Request('POST');$edit->set_body_params(['id'=>$room['id'],'title'=>'Room updated']);$kept=RVAZ_Wonen_Private_UI::save($edit,['RVAZ_Wonen_Audit_Private','save']);audit_check($kept['transactie']==='Huur','editing without transaction retains existing rental type');
wp_set_current_user($officeB);audit_check(is_wp_error(RVAZ_Wonen_Private_UI::save($edit,['RVAZ_Wonen_Audit_Private','save'])),'compatibility layer rejects editing another private owner room');
echo "All subscription access and private rental compatibility checks passed.\n";
