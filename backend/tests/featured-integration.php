<?php
if(!defined('ABSPATH'))exit;
$featured_agent=wp_create_user('featured-agent','test-only-password','featured-agent@example.invalid');
(new WP_User($featured_agent))->set_role(RVAZ_Wonen::ROLE);
$broker_room=call_api('POST','/makelaar/woningen',['transactie'=>'Huur','woningtype'=>'Kamer','prijs'=>'750','borg'=>'750','contractduur'=>'12 maanden'],$featured_agent)->get_data();
check($broker_room['transactie']==='Huur'&&$broker_room['woningtype']==='Kamer'&&$broker_room['borg']==='750','broker can save a rental room with rental terms');
wp_delete_post($broker_room['id'],true);
$featured_id=reader_property($featured_agent);
check(!in_array($featured_id,array_column(call_api('GET','/uitgelicht')->get_data(),'id'),true),'unpaid broker cannot appear on home');
$wpdb->insert($wpdb->prefix.'rvaz_wonen_subscriptions',['user_id'=>$featured_agent,'plan'=>'basis','status'=>'active','start_date'=>current_time('Y-m-d'),'end_date'=>wp_date('Y-m-d',time()+20*DAY_IN_SECONDS)]);
$featured_sub=$wpdb->insert_id;
$wpdb->insert($wpdb->prefix.'rvaz_wonen_invoices',['user_id'=>$featured_agent,'invoice_no'=>'CI-FEATURED','period'=>'test','subtotal'=>49,'vat'=>0,'total'=>49,'status'=>'paid','invoice_date'=>current_time('Y-m-d')]);
$featured_invoice=$wpdb->insert_id;
check(in_array($featured_id,array_column(call_api('GET','/uitgelicht')->get_data(),'id'),true),'paid current active broker appears on home');
update_post_meta($featured_id,'_rvaz_wonen_status','Verkocht');
check(!in_array($featured_id,array_column(call_api('GET','/uitgelicht')->get_data(),'id'),true),'sold paid home excluded');
update_post_meta($featured_id,'_rvaz_wonen_status','Beschikbaar');
update_user_meta($featured_agent,'rvaz_wonen_blocked','1');
check(!in_array($featured_id,array_column(call_api('GET','/uitgelicht')->get_data(),'id'),true),'blocked paid broker excluded');
delete_user_meta($featured_agent,'rvaz_wonen_blocked');
$wpdb->update($wpdb->prefix.'rvaz_wonen_invoices',['invoice_date'=>'2020-01-01'],['id'=>$featured_invoice]);
check(!in_array($featured_id,array_column(call_api('GET','/uitgelicht')->get_data(),'id'),true),'historical payment cannot finance current home feature');
$wpdb->update($wpdb->prefix.'rvaz_wonen_invoices',['invoice_date'=>current_time('Y-m-d')],['id'=>$featured_invoice]);
$wpdb->update($wpdb->prefix.'rvaz_wonen_subscriptions',['status'=>'cancelled'],['id'=>$featured_sub]);
check(!in_array($featured_id,array_column(call_api('GET','/uitgelicht')->get_data(),'id'),true),'cancelled subscription excluded');
wp_delete_post($featured_id,true);

$room_form=apply_filters('do_shortcode_tag','<select name="woningtype"><option value="Woning">Woning</option></select>','rvaz_wonen_portal');
check(strpos($room_form,'value="Kamer"')!==false&&strpos($room_form,'value="Studio"')!==false,'broker website wizard offers rooms and studios');
