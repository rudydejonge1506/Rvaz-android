<?php
if(!defined('ABSPATH'))exit;
final class RVAZ_Wonen_Invoice_Tools {
 static function key($id){return 'rvaz_wonen_invoice_test_'.absint($id);}
 static function removed($id){if(empty(get_option(self::key($id),[])['removed']))return false;global $wpdb;$r=$wpdb->get_row($wpdb->prepare("SELECT status,paid_date FROM {$wpdb->prefix}rvaz_wonen_invoices WHERE id=%d",absint($id)));return $r&&$r->status!=='paid'&&empty($r->paid_date);}
 static function visible($rows){return array_values(array_filter($rows,function($r){return !self::removed($r['id']);}));}
 static function change($id,$action){
  if(!current_user_can('manage_options'))return RVAZ_Wonen_Native_API::error('admin','Alleen RVAZ-beheer mag testfacturen beheren.',403);
  global $wpdb;$id=absint($id);$table=$wpdb->prefix.'rvaz_wonen_invoices';$row=$wpdb->get_row($wpdb->prepare("SELECT * FROM $table WHERE id=%d",$id));
  if(!$row)return RVAZ_Wonen_Native_API::error('invoice','Factuur niet gevonden.',404);
  if($row->status==='paid'||!empty($row->paid_date))return RVAZ_Wonen_Native_API::error('paid','Een betaalde factuur kan hier niet worden verwijderd of gewijzigd.',409);
  $lock='rvaz_wonen_invoice_cleanup_lock_'.$id;if((int)get_option($lock,0)<time()-1800)delete_option($lock);
  if(!add_option($lock,time(),'','no'))return RVAZ_Wonen_Native_API::error('busy','Deze factuur wordt al verwerkt.',409);
  try {
   $meta=get_option(self::key($id),[]);
   if($action==='mark'){$meta['test']=true;update_option(self::key($id),$meta,false);return ['status'=>'test'];}
   if(empty($meta['test']))return RVAZ_Wonen_Native_API::error('test','Markeer deze factuur eerst expliciet als testfactuur.',409);
   if($action==='unmark'){if(!empty($meta['removed']))return RVAZ_Wonen_Native_API::error('restore','Zet de factuur eerst terug.',409);delete_option(self::key($id));return ['status'=>'normal'];}
   if($action==='remove'){
    if(!empty($meta['removed']))return ['status'=>'removed'];
    if(!in_array($row->status,['open','cancelled'],true))return RVAZ_Wonen_Native_API::error('status','Deze factuurstatus kan niet worden verwijderd.',409);
    if($row->status==='open'&&$wpdb->update($table,['status'=>'cancelled'],['id'=>$id,'status'=>'open'])!==1)return RVAZ_Wonen_Native_API::error('changed','De betaalstatus is gewijzigd. Vernieuw de pagina.',409);
    $meta+=['previous_status'=>$row->status];$meta['removed']=true;$meta['removed_by']=get_current_user_id();$meta['removed_at']=current_time('mysql');update_option(self::key($id),$meta,false);return ['status'=>'removed'];
   }
   if($action==='restore'){
    if(empty($meta['removed']))return ['status'=>'restored'];
    if($row->status!=='cancelled')return RVAZ_Wonen_Native_API::error('changed','De factuurstatus is gewijzigd. Herstel wordt niet toegepast.',409);
    if(($meta['previous_status']??'cancelled')==='open'&&$wpdb->update($table,['status'=>'open'],['id'=>$id,'status'=>'cancelled'])!==1)return RVAZ_Wonen_Native_API::error('changed','De factuurstatus is gewijzigd.',409);
    unset($meta['removed'],$meta['previous_status']);update_option(self::key($id),$meta,false);return ['status'=>'restored'];
   }
   return RVAZ_Wonen_Native_API::error('action','Ongeldige actie.');
  } finally {delete_option($lock);}
 }
 static function page(){
  if(!current_user_can('manage_options'))return;global $wpdb;
  $removed=!empty($_GET['verwijderd']);$search=sanitize_text_field($_GET['zoek']??'');
  $rows=$wpdb->get_results($wpdb->prepare("SELECT id,invoice_no,user_id,total,status,paid_date FROM {$wpdb->prefix}rvaz_wonen_invoices WHERE invoice_no LIKE %s ORDER BY id DESC",'%'.$wpdb->esc_like($search).'%'));
  echo '<div class="wrap"><h1>Testfacturen beheren</h1><p>Markeer uitsluitend je eigen testfacturen. Verwijderen haalt ze uit de actieve overzichten en annuleert een open factuur. De gegevens en factuurnummers blijven bewaard en kunnen worden teruggezet. Betaalde facturen zijn beschermd.</p><p><a href="'.esc_url(admin_url('admin.php?page=rvaz-wonen-testfacturen')).'">Actieve facturen</a> | <a href="'.esc_url(admin_url('admin.php?page=rvaz-wonen-testfacturen&verwijderd=1')).'">Verwijderde testfacturen</a></p><form method="get"><input type="hidden" name="page" value="rvaz-wonen-testfacturen"><input type="hidden" name="verwijderd" value="'.(int)$removed.'"><label>Factuurnummer <input name="zoek" value="'.esc_attr($search).'"></label><button class="button">Zoeken</button></form><table class="widefat striped"><thead><tr><th>Factuur</th><th>Account</th><th>Bedrag</th><th>Status</th><th>Acties</th></tr></thead><tbody>';
  foreach($rows as $r){if(self::removed($r->id)!==$removed)continue;$meta=get_option(self::key($r->id),[]);echo '<tr><td>'.esc_html($r->invoice_no).'</td><td>'.(int)$r->user_id.'</td><td>€'.esc_html(number_format((float)$r->total,2,',','.')).'</td><td>'.esc_html($r->status).(!empty($meta['test'])?' · TEST':'').'</td><td>';
   if($r->status==='paid'||!empty($r->paid_date))echo 'Betaald — beschermd';else {
    $actions=$removed?['restore'=>'Terugzetten']:(!empty($meta['test'])?['remove'=>'Testfactuur verwijderen','unmark'=>'Testmarkering opheffen']:['mark'=>'Markeren als test']);
    foreach($actions as $action=>$label)echo '<form style="display:inline" method="post" action="'.esc_url(admin_url('admin-post.php')).'"><input type="hidden" name="action" value="rvaz_wonen_test_invoice"><input type="hidden" name="id" value="'.(int)$r->id.'"><input type="hidden" name="operation" value="'.esc_attr($action).'">'.wp_nonce_field('rvaz_wonen_test_invoice_'.$r->id,'nonce',true,false).'<label><input type="checkbox" name="confirmed" value="1" required> Bevestig</label> <button class="button">'.esc_html($label).'</button></form> ';
   }echo '</td></tr>';
  }echo '</tbody></table></div>';
 }
}
add_action('admin_menu',function(){if(class_exists('RVAZ_Wonen'))add_submenu_page('rvaz-wonen','Testfacturen beheren','Testfacturen beheren','manage_options','rvaz-wonen-testfacturen',['RVAZ_Wonen_Invoice_Tools','page']);},35);
add_action('admin_post_rvaz_wonen_test_invoice',function(){
 if(!current_user_can('manage_options'))wp_die('Niet toegestaan');$id=absint($_POST['id']??0);
 if(!$id||empty($_POST['confirmed'])||!wp_verify_nonce($_POST['nonce']??'','rvaz_wonen_test_invoice_'.$id))wp_die('Bevestiging ontbreekt of verlopen.');
 $result=RVAZ_Wonen_Invoice_Tools::change($id,sanitize_key($_POST['operation']??''));if(is_wp_error($result))wp_die(esc_html($result->get_error_message()));wp_safe_redirect(admin_url('admin.php?page=rvaz-wonen-testfacturen'));exit;
});
// Hide removed test rows in the existing administration without changing its source.
add_action('admin_footer',function(){
 if(!current_user_can('manage_options')||($_GET['page']??'')!=='rvaz-wonen-facturen')return;global $wpdb;
 $numbers=[];foreach($wpdb->get_results("SELECT id,invoice_no,status,paid_date FROM {$wpdb->prefix}rvaz_wonen_invoices") as $r)if(RVAZ_Wonen_Invoice_Tools::removed($r->id)&&$r->status!=='paid'&&empty($r->paid_date))$numbers[]=$r->invoice_no;
 echo '<p><a class="button" href="'.esc_url(admin_url('admin.php?page=rvaz-wonen-testfacturen')).'">Testfacturen beheren</a></p><script>const rvazRemovedInvoices='.wp_json_encode($numbers).';document.querySelectorAll("table tr").forEach(row=>{const number=row.querySelector("td strong");if(number&&rvazRemovedInvoices.includes(number.textContent.trim()))row.hidden=true;});</script>';
});
add_filter('do_shortcode_tag',function($output,$tag){
 if($tag!=='rvaz_wonen_portal'||!is_user_logged_in())return $output;global $wpdb;$numbers=[];
 foreach($wpdb->get_results($wpdb->prepare("SELECT id,invoice_no FROM {$wpdb->prefix}rvaz_wonen_invoices WHERE user_id=%d",get_current_user_id())) as $r)if(RVAZ_Wonen_Invoice_Tools::removed($r->id))$numbers[]=$r->invoice_no;
 return preg_replace_callback('/<tr\b[^>]*>.*?<\/tr>/si',function($m)use($numbers){if(preg_match('/<td\b[^>]*>(.*?)<\/td>/si',$m[0],$cell)&&in_array(trim(wp_strip_all_tags($cell[1])),$numbers,true))return '';return $m[0];},$output);
},50,2);
