<?php
if(!defined('ABSPATH'))exit;
global $wpdb;$table=$wpdb->prefix.'rvaz_wonen_invoices';
$wpdb->insert($table,['user_id'=>$agent,'invoice_no'=>'CI-REMOVABLE','period'=>'test','subtotal'=>25,'vat'=>0,'total'=>25,'status'=>'open']);$test_invoice=$wpdb->insert_id;
wp_set_current_user($agent);check(is_wp_error(RVAZ_Wonen_Invoice_Tools::change($test_invoice,'mark')),'ordinary account cannot mark or remove invoices');
wp_set_current_user(1);check(is_wp_error(RVAZ_Wonen_Invoice_Tools::change($test_invoice,'remove')),'unmarked invoice cannot be removed');
check(RVAZ_Wonen_Invoice_Tools::change($test_invoice,'mark')['status']==='test','administrator explicitly marks test invoice');
check(RVAZ_Wonen_Invoice_Tools::change($test_invoice,'remove')['status']==='removed','marked unpaid test invoice removed reversibly');
check($wpdb->get_var($wpdb->prepare("SELECT status FROM $table WHERE id=%d",$test_invoice))==='cancelled','removed test invoice cannot remain an open bill');
check((int)$wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $table WHERE id=%d",$test_invoice))===1,'removal retains invoice number and recovery data');
wp_set_current_user($agent);check(!in_array($test_invoice,array_column(RVAZ_Wonen_Native_API::invoices()['items'],'id')),'removed test invoice hidden from native invoice overview');
$portal=apply_filters('do_shortcode_tag','<table><tr><td>CI-REMOVABLE</td><td>test</td></tr><tr><td>PROTECTED-OLD</td><td>paid</td></tr></table>','rvaz_wonen_portal');check(strpos($portal,'CI-REMOVABLE')===false&&strpos($portal,'PROTECTED-OLD')!==false,'legacy website hides only removed test invoice');
wp_set_current_user(1);check(RVAZ_Wonen_Invoice_Tools::change($test_invoice,'restore')['status']==='restored','administrator restores test invoice');
check($wpdb->get_var($wpdb->prepare("SELECT status FROM $table WHERE id=%d",$test_invoice))==='open','restore recovers original open status');
check(!RVAZ_Wonen_Invoice_Tools::removed($test_invoice),'restored invoice reappears');
$protected=$wpdb->get_var("SELECT id FROM $table WHERE invoice_no='PROTECTED-OLD'");check(is_wp_error(RVAZ_Wonen_Invoice_Tools::change($protected,'mark'))&&is_wp_error(RVAZ_Wonen_Invoice_Tools::change($protected,'remove')),'paid historical invoice cannot be marked or removed');
check((float)$wpdb->get_var("SELECT total FROM $table WHERE invoice_no='PROTECTED-OLD'")===121.0,'historical paid invoice amount remains unchanged');
check(RVAZ_Wonen_Invoice_Tools::change($test_invoice,'unmark')['status']==='normal','test label can be removed after restoration');
