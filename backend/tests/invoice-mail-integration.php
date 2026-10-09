<?php
if(!defined('ABSPATH'))exit;
global $wpdb;$table=$wpdb->prefix.'rvaz_wonen_invoices';
$wpdb->insert($table,['user_id'=>$seller,'invoice_no'=>'RVAZ-P-CI-MAIL','period'=>'test','subtotal'=>25,'vat'=>0,'total'=>25,'status'=>'open']);$mail_private=$wpdb->insert_id;
$wpdb->insert($table,['user_id'=>$agent,'invoice_no'=>'RVAZ-CI-MAIL','period'=>'test','subtotal'=>99,'vat'=>0,'total'=>99,'status'=>'open']);$mail_agent=$wpdb->insert_id;
wp_set_current_user($seller);check(is_wp_error(RVAZ_Wonen_Invoice_Mail::send($mail_private))&&is_wp_error(RVAZ_Wonen_Invoice_Mail::save_link($mail_private,'https://tikkie.me/pay/ci')),'customer cannot send invoices or set payment link');
wp_set_current_user(1);check(is_wp_error(RVAZ_Wonen_Invoice_Mail::send($mail_private)),'sending requires saved payment link');
check(is_wp_error(RVAZ_Wonen_Invoice_Mail::save_link($mail_private,'javascript:alert(1)')),'unsafe payment link rejected');
check(RVAZ_Wonen_Invoice_Mail::save_link($mail_private,'https://tikkie.me/pay/private-ci')['status']==='saved','administrator saves private invoice Tikkie link');
check(RVAZ_Wonen_Invoice_Mail::save_link($mail_agent,'https://tikkie.me/pay/agent-ci')['status']==='saved','administrator saves broker invoice Tikkie link');
$captured=[];$capture=function($pre,$args)use(&$captured){$captured[]=$args;$attachment=$args['attachments'][0];check(str_ends_with($attachment,'.pdf')&&str_starts_with(file_get_contents($attachment),'%PDF-1.4'),'mail attaches actual PDF with PDF filename');return true;};add_filter('pre_wp_mail',$capture,20,2);
check(RVAZ_Wonen_Invoice_Mail::send($mail_private)['status']==='sent','private invoice and Tikkie sent through mail service');
check(RVAZ_Wonen_Invoice_Mail::send($mail_agent)['status']==='sent','broker invoice and Tikkie sent through mail service');remove_filter('pre_wp_mail',$capture,20);
check($captured[0]['to']==='seller@example.invalid'&&strpos($captured[0]['message'],'https://tikkie.me/pay/private-ci')!==false,'private mail goes only to invoice owner with correct link');
check($captured[1]['to']==='agent-a@example.invalid'&&strpos($captured[1]['message'],'https://tikkie.me/pay/agent-ci')!==false,'broker mail goes only to invoice owner with correct link');
check(!file_exists($captured[0]['attachments'][0])&&!file_exists($captured[1]['attachments'][0]),'temporary invoice attachments removed after sending');
check($wpdb->get_var($wpdb->prepare("SELECT status FROM $table WHERE id=%d",$mail_private))==='open','email does not mark invoice paid or publish property');
$fail=function(){return false;};add_filter('pre_wp_mail',$fail,30);check(is_wp_error(RVAZ_Wonen_Invoice_Mail::send($mail_private)),'mail failure reported without altering invoice');remove_filter('pre_wp_mail',$fail,30);
