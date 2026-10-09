<?php
/**
 * Plugin Name: RVAZ Nieuwsbrief
 * Description: Eigen nieuwsbriefsysteem voor Regio Voorne aan Zee met nieuws, RVAZ-advertenties, planning, publieke HTTPS-afbeeldingen en statistieken.
 * Version: 1.10.0
 * Author: Regio Voorne aan Zee
 * Text Domain: rvaz-nieuwsbrief
 */
if (!defined('ABSPATH')) exit;
final class RVAZ_Nieuwsbrief_144 {
 const V='1.10.0'; const BATCH_LIMIT=800; const CHUNK_SIZE=20; const CHUNK_DELAY=90; const OPT='rvaz_newsletter_settings';
 public function __construct(){
  register_activation_hook(__FILE__,[$this,'activate']);
  add_action('admin_menu',[$this,'menu'],99); add_action('admin_init',[$this,'settings']); add_filter('plugin_action_links_'.plugin_basename(__FILE__),[$this,'action_links']); add_action('admin_enqueue_scripts',[$this,'admin_assets']); add_action('init',[$this,'upgrade_schedule']);
  add_action('admin_post_rvaz_nl_import',[$this,'import']); add_action('admin_post_rvaz_nl_subscriber_add',[$this,'subscriber_add']); add_action('admin_post_rvaz_nl_subscriber_bulk',[$this,'subscriber_bulk']); add_action('admin_post_rvaz_nl_delete_all_unsubscribed',[$this,'delete_all_unsubscribed']); add_action('admin_post_rvaz_nl_list_create',[$this,'list_create']); add_action('admin_post_rvaz_nl_list_rename',[$this,'list_rename']); add_action('admin_post_rvaz_nl_list_delete',[$this,'list_delete']); add_action('admin_post_rvaz_nl_custom_save',[$this,'custom_save']); add_action('admin_post_rvaz_nl_subscriber_save',[$this,'subscriber_save']); add_action('admin_post_rvaz_nl_subscriber_delete',[$this,'subscriber_delete']); add_action('admin_post_rvaz_nl_export',[$this,'export']);
  add_action('wp_mail_failed',[$this,'mail_failed']); add_action('admin_post_rvaz_nl_send',[$this,'send_now']); add_action('admin_post_rvaz_nl_delete_mailing',[$this,'delete_mailing']); add_action('admin_post_rvaz_nl_cancel',[$this,'cancel_mailing']); add_action('admin_post_rvaz_nl_repair_queue',[$this,'repair_queue']); add_action('admin_post_rvaz_nl_test',[$this,'send_test']); add_action('admin_post_rvaz_nl_pause',[$this,'pause_mailing']); add_action('admin_post_rvaz_nl_resume',[$this,'resume_mailing']); add_action('admin_post_rvaz_nl_kick_worker',[$this,'kick_worker']); add_action('admin_post_rvaz_nl_edit_mailing',[$this,'edit_mailing']); add_action('phpmailer_init',[$this,'smtp']);
  add_action('admin_post_nopriv_rvaz_nl_subscribe',[$this,'subscribe']); add_action('admin_post_rvaz_nl_subscribe',[$this,'subscribe']);
  add_action('admin_post_nopriv_rvaz_nl_unsubscribe',[$this,'unsubscribe']); add_action('admin_post_rvaz_nl_unsubscribe',[$this,'unsubscribe']);
  add_action('admin_post_nopriv_rvaz_nl_open',[$this,'track_open']); add_action('admin_post_rvaz_nl_open',[$this,'track_open']);
  add_action('admin_post_nopriv_rvaz_nl_click',[$this,'track_click']); add_action('admin_post_rvaz_nl_click',[$this,'track_click']);
  add_action('rvaz_weekblad_published',[$this,'weekblad_published'],10,1);
  add_shortcode('rvaz_nieuwsbrief',[$this,'form']); add_shortcode('rvaz_app_tester_link',[$this,'app_tester_link_shortcode']); add_shortcode('rvaz_weekblad_inschrijven',[$this,'weekblad_form']); add_action('rvaz_nl_cron',[$this,'cron']); add_action('rvaz_nl_queue_worker',[$this,'queue_worker']); add_action('rvaz_nl_worker_tick',[$this,'worker_tick']);
  add_filter('cron_schedules',function($s){$s['rvaz_hourly']=['interval'=>HOUR_IN_SECONDS,'display'=>'Ieder uur'];$s['rvaz_nl_minute']=['interval'=>60,'display'=>'RVAZ nieuwsbrief iedere minuut'];return $s;});
 }
 private function table(){global $wpdb; return $wpdb->prefix.'rvaz_newsletter_subscribers';}
 private function mailings_table(){global $wpdb; return $wpdb->prefix.'rvaz_newsletter_mailings';}
 private function events_table(){global $wpdb; return $wpdb->prefix.'rvaz_newsletter_events';}
 private function recipients_table(){global $wpdb; return $wpdb->prefix.'rvaz_newsletter_recipients';}
 public function upgrade_schedule(){
 if(get_option('rvaz_nl_version')===self::V)return;
 $this->activate();$this->ensure_queue_schema();$this->ensure_recipients_schema();$this->reconcile_mailings(); global $wpdb; $wpdb->query("UPDATE {$this->mailings_table()} SET status='paused' WHERE status IN ('queued','sending')"); delete_option('rvaz_nl_authorized_mailing'); update_option('rvaz_nl_safety_181','1');
 wp_clear_scheduled_hook('rvaz_nl_cron');wp_clear_scheduled_hook('rvaz_nl_queue_worker');wp_clear_scheduled_hook('rvaz_nl_worker_tick');
 if(!wp_next_scheduled('rvaz_nl_cron'))wp_schedule_event(time()+300,'rvaz_hourly','rvaz_nl_cron');
 if(!wp_next_scheduled('rvaz_nl_worker_tick'))wp_schedule_event(time()+30,'rvaz_nl_minute','rvaz_nl_worker_tick');
 delete_transient('rvaz_nl_batch_lock');
 $this->refresh_wonen_drafts();
 update_option('rvaz_nl_version',self::V);
}
private function sync_mailing_recipients($mailing_id){
 global $wpdb;$mailing_id=absint($mailing_id);if(!$mailing_id)return [0,0,0,0];
 $this->ensure_recipients_schema();$rt=$this->recipients_table();$st=$this->table();
 $mailing=$wpdb->get_row($wpdb->prepare("SELECT mailing_type FROM {$this->mailings_table()} WHERE id=%d",$mailing_id));
 if(!$mailing || $mailing->mailing_type!=='custom'){
  $subs=$wpdb->get_results("SELECT id,email,unsub_token FROM $st WHERE status='confirmed' AND TRIM(COALESCE(lists,'')) <> 'Makelaars' ORDER BY id ASC");
  foreach((array)$subs as $sub)$wpdb->query($wpdb->prepare("INSERT IGNORE INTO $rt (mailing_id,subscriber_id,email,unsub_token,status) VALUES (%d,%d,%s,%s,'pending')",$mailing_id,(int)$sub->id,(string)$sub->email,(string)$sub->unsub_token));
 }
 $sent=(int)$wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $rt WHERE mailing_id=%d AND status='sent'",$mailing_id));
 $failed=(int)$wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $rt WHERE mailing_id=%d AND status='failed'",$mailing_id));
 $pending=(int)$wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $rt WHERE mailing_id=%d AND status='pending'",$mailing_id));
 return [$sent+$failed+$pending,$sent,$failed,$pending];
}
private function reconcile_mailings(){
 global $wpdb;$mt=$this->mailings_table();$rt=$this->recipients_table();
 delete_transient('rvaz_nl_batch_lock');
 /* 1.6.7: eerder als definitief mislukt gemarkeerde adressen krijgen opnieuw maximaal 3 kansen. */
 $wpdb->query("UPDATE $rt SET status='pending',next_attempt_at=NULL WHERE status='failed' AND attempt_count<3");
 /* Snapshot-data is leidend voor nieuwe mailings. */
 $ids=$wpdb->get_col("SELECT id FROM $mt WHERE status IN ('queued','sending','paused') OR (status='completed' AND total_count>sent_count+failed_count)");
 foreach((array)$ids as $id){
  $id=(int)$id;list($snap,$sent,$failed,$pending)=$this->sync_mailing_recipients($id);
  if($snap>0){
   $data=['total_count'=>$snap,'sent_count'=>$sent,'failed_count'=>$failed];
   if($pending>0){$current=$wpdb->get_var($wpdb->prepare("SELECT status FROM $mt WHERE id=%d",$id));if($current!=='paused')$data['status']='queued';}
   $wpdb->update($mt,$data,['id'=>$id]);
  }
 }
 $wpdb->query("UPDATE $mt SET status='completed',completed_at=COALESCE(completed_at,NOW()) WHERE status IN ('queued','sending') AND total_count>0 AND sent_count+failed_count>=total_count");
 $wpdb->query("UPDATE $mt SET status='cancelled',completed_at=COALESCE(completed_at,NOW()) WHERE status IN ('queued','sending') AND total_count=0");
}
private function ensure_recipients_schema(){
 global $wpdb;require_once ABSPATH.'wp-admin/includes/upgrade.php';
 $table=$this->recipients_table();$charset=$wpdb->get_charset_collate();
 dbDelta("CREATE TABLE $table (
  id bigint unsigned NOT NULL AUTO_INCREMENT,
  mailing_id bigint unsigned NOT NULL,
  subscriber_id bigint unsigned NOT NULL,
  email varchar(190) NOT NULL,
  unsub_token varchar(100) NOT NULL DEFAULT '',
  status varchar(20) NOT NULL DEFAULT 'pending',
  sent_at datetime NULL,
  error_text text NULL,
  attempt_count int unsigned NOT NULL DEFAULT 0,
  next_attempt_at datetime NULL,
  PRIMARY KEY (id),
  UNIQUE KEY mailing_subscriber (mailing_id,subscriber_id),
  KEY mailing_status (mailing_id,status)
 ) $charset;");
}
private function ensure_queue_schema(){
 global $wpdb;$table=$this->mailings_table();
 if($wpdb->get_var($wpdb->prepare("SHOW TABLES LIKE %s",$table))!==$table)return false;
 $required=['sent_count'=>"int unsigned NOT NULL DEFAULT 0",'total_count'=>"int unsigned NOT NULL DEFAULT 0",'failed_count'=>"int unsigned NOT NULL DEFAULT 0",'status'=>"varchar(20) NOT NULL DEFAULT 'queued'",'cursor_id'=>"bigint unsigned NOT NULL DEFAULT 0",'post_ids'=>"text NULL",'content_html'=>"longtext NULL",'last_batch_at'=>"datetime NULL",'window_started_at'=>"datetime NULL",'window_sent'=>"int unsigned NOT NULL DEFAULT 0",'completed_at'=>"datetime NULL",'mailing_type'=>"varchar(20) NOT NULL DEFAULT 'automatic'",'target_list'=>"varchar(190) NOT NULL DEFAULT ''",'include_donation'=>"tinyint(1) unsigned NOT NULL DEFAULT 0"];
 $cols=$wpdb->get_col("SHOW COLUMNS FROM `$table`",0);
 foreach($required as $name=>$definition)if(!in_array($name,$cols,true))$wpdb->query("ALTER TABLE `$table` ADD COLUMN `$name` $definition");
 return true;
}
 public function activate(){global $wpdb; require_once ABSPATH.'wp-admin/includes/upgrade.php'; $t=$this->table(); $m=$this->mailings_table(); $e=$this->events_table(); $c=$wpdb->get_charset_collate(); dbDelta("CREATE TABLE $t (id bigint unsigned NOT NULL AUTO_INCREMENT,email varchar(190) NOT NULL,first_name varchar(100) DEFAULT '',last_name varchar(100) DEFAULT '',status varchar(20) DEFAULT 'confirmed',lists text NULL,consent_at datetime NULL,created_at datetime NOT NULL,unsub_token varchar(64) NOT NULL,PRIMARY KEY(id),UNIQUE KEY email(email)) $c;"); dbDelta("CREATE TABLE $m (id bigint unsigned NOT NULL AUTO_INCREMENT,subject varchar(255) NOT NULL,sent_at datetime NOT NULL,sent_count int unsigned DEFAULT 0,total_count int unsigned DEFAULT 0,failed_count int unsigned DEFAULT 0,status varchar(20) DEFAULT 'queued',cursor_id bigint unsigned DEFAULT 0,post_ids text NULL,content_html longtext NULL,last_batch_at datetime NULL,window_started_at datetime NULL,window_sent int unsigned DEFAULT 0,completed_at datetime NULL,mailing_type varchar(20) NOT NULL DEFAULT 'automatic',target_list varchar(190) NOT NULL DEFAULT '',include_donation tinyint(1) unsigned NOT NULL DEFAULT 0,PRIMARY KEY(id),KEY sent_at(sent_at),KEY status(status)) $c;"); dbDelta("CREATE TABLE $e (id bigint unsigned NOT NULL AUTO_INCREMENT,mailing_id bigint unsigned NOT NULL,subscriber_id bigint unsigned DEFAULT 0,event_type varchar(12) NOT NULL,url text NULL,region varchar(120) DEFAULT '',created_at datetime NOT NULL,PRIMARY KEY(id),KEY mailing_type(mailing_id,event_type),KEY subscriber(subscriber_id)) $c;"); if(!wp_next_scheduled('rvaz_nl_cron')) wp_schedule_event(time()+300,'rvaz_hourly','rvaz_nl_cron'); }
 public function action_links($links){array_unshift($links,'<a href="'.esc_url(admin_url('admin.php?page=rvaz-newsletter')).'">Open nieuwsbrief</a>');return $links;}
 public function menu(){add_menu_page('RVAZ Nieuwsbrief','RVAZ Nieuwsbrief','manage_options','rvaz-newsletter',[$this,'dashboard'],'dashicons-email-alt2',26); add_submenu_page('rvaz-newsletter','Abonnees','Abonnees','manage_options','rvaz-newsletter-subscribers',[$this,'subscribers_page']); add_submenu_page('rvaz-newsletter','Verzendlijsten','Verzendlijsten','manage_options','rvaz-newsletter-lists',[$this,'lists_page']); add_submenu_page('rvaz-newsletter','Nieuwsbrief maken','Nieuwsbrief maken','manage_options','rvaz-newsletter-compose',[$this,'compose_page']); add_submenu_page('rvaz-newsletter','Statistieken','Statistieken','manage_options','rvaz-newsletter-stats',[$this,'stats_page']); add_submenu_page('rvaz-newsletter','Instellingen','Instellingen','manage_options','rvaz-newsletter-settings',[$this,'settings_page']); add_submenu_page('rvaz-newsletter','Import / Export','Import / Export','manage_options','rvaz-newsletter-migrate',[$this,'migrate_page']);}
 public function settings(){register_setting('rvaz_nl',self::OPT,['sanitize_callback'=>[$this,'sanitize']]);}
 public function admin_assets($hook){if(strpos($hook,'rvaz-newsletter')===false)return;wp_enqueue_media();$js=<<<'JS'
jQuery(function($){$(document).on('click','.rvaz-pick-logo',function(e){e.preventDefault();var input=$('#rvaz-nl-logo');var frame=wp.media({title:'Kies nieuwsbrieflogo',button:{text:'Gebruik dit logo'},multiple:false});frame.on('select',function(){var a=frame.state().get('selection').first().toJSON();input.val(a.url);$('#rvaz-nl-logo-id').val(a.id||0);$('#rvaz-nl-logo-preview').attr('src',a.url).show();});frame.open();});});
JS;wp_add_inline_script('jquery-core',$js);}
 public function sanitize($v){$v=(array)$v; foreach($v as $k=>$x){if(is_array($x))continue;$v[$k]=in_array($k,['apology_body','app_banner_body','app_banner_account','app_banner_note','extra_notes'],true)?sanitize_textarea_field($x):sanitize_text_field($x);} update_option('rvaz_nl_apology_pending',!empty($v['apology_once'])?'1':'0',false); return $v;}
 private function opt($k,$d=''){ $o=get_option(self::OPT,[]); return isset($o[$k])?$o[$k]:$d; }
 private function count(){global $wpdb; return (int)$wpdb->get_var("SELECT COUNT(*) FROM {$this->table()} WHERE status='confirmed'");}
 public function dashboard(){ if(!current_user_can('manage_options'))return; $preview='';$preview_error='';try{$preview=$this->newsletter_html(true);}catch(\Throwable $e){$preview_error=$e->getMessage();$preview='<p><strong>Voorbeeld tijdelijk niet beschikbaar.</strong></p><p>De nieuwsbriefinstellingen en abonnees blijven bereikbaar.</p>';} ?>
 <div class="wrap"><h1>RVAZ Nieuwsbrief</h1><?php $this->notice(); $active=$this->active_mailing(); if($active): 
 $actual_total=$this->count(); $display_total=(int)$active->total_count>0?(int)$active->total_count:$actual_total; ?>
 <div class="notice <?php echo ((int)$active->total_count===0?'notice-warning':'notice-info'); ?>">
 <p><strong>Verzendwachtrij:</strong> <?php echo intval($active->sent_count); ?> van <?php echo intval($display_total); ?> verzonden. Maximaal <?php echo intval(self::BATCH_LIMIT); ?> mails per uur, verdeeld in kleine batches. Status: <?php echo esc_html($active->status); ?>.</p>
 <?php if((int)$active->total_count===0 && $actual_total>0): ?><p><strong>Let op:</strong> deze wachtrij is door een eerdere pluginversie met 0 ontvangers opgeslagen. Klik op <em>Wachtrij herstellen</em> om <?php echo number_format_i18n($actual_total); ?> actieve ontvangers aan deze verzending te koppelen.</p><?php endif; ?>
 <div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap;margin:8px 0">
 <?php if($active->status==='paused'): ?><form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>"><input type="hidden" name="action" value="rvaz_nl_resume"><input type="hidden" name="mailing_id" value="<?php echo intval($active->id); ?>"><?php wp_nonce_field('rvaz_nl_resume_'.$active->id); ?><button class="button button-primary">Verzending hervatten</button></form>
 <?php else: ?><form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>"><input type="hidden" name="action" value="rvaz_nl_pause"><input type="hidden" name="mailing_id" value="<?php echo intval($active->id); ?>"><?php wp_nonce_field('rvaz_nl_pause_'.$active->id); ?><button class="button">Verzending pauzeren</button></form><?php endif; ?>
 <a class="button" href="<?php echo esc_url(add_query_arg(['page'=>'rvaz-newsletter-stats','mailing'=>$active->id],admin_url('admin.php'))); ?>">Resterende nieuwsbrief wijzigen</a>
 <?php if((int)$active->total_count===0 || $actual_total!==(int)$active->total_count): ?><form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>"><input type="hidden" name="action" value="rvaz_nl_repair_queue"><?php wp_nonce_field('rvaz_nl_repair_queue'); ?><button class="button">Wachtrij herstellen</button></form><?php endif; ?>
 <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>" onsubmit="return confirm('Deze verzendwachtrij annuleren? Reeds verzonden mails worden niet opnieuw verzonden.');"><input type="hidden" name="action" value="rvaz_nl_cancel"><input type="hidden" name="mailing_id" value="<?php echo intval($active->id); ?>"><?php wp_nonce_field('rvaz_nl_cancel_'.$active->id); ?><button class="button">Wachtrij annuleren</button></form>
 </div></div><?php endif; if($preview_error && current_user_can('manage_options')): ?><div class="notice notice-error"><p><strong>Fout in nieuwsbriefvoorbeeld:</strong> <?php echo esc_html($preview_error); ?></p></div><?php endif; ?><p><strong><?php echo number_format_i18n($this->count()); ?></strong> actieve abonnees.</p>
 <div style="margin:0 0 10px"><label><input type="checkbox" id="rvaz-nl-donation-toggle" value="1"> <strong>Donatieblok opnemen</strong></label> <span class="description">Geldt voor zowel ‘Nieuwsbrief nu verzenden’ als ‘Testmail’.</span></div>
 <div style="display:flex;gap:12px;flex-wrap:wrap"><form id="rvaz-nl-send-form" method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>"><input type="hidden" name="action" value="rvaz_nl_send"><input type="hidden" name="include_donation" value="0" class="rvaz-nl-donation-value"><?php wp_nonce_field('rvaz_nl_send'); ?><button class="button button-primary">Nieuwsbrief nu verzenden</button></form>
 <form id="rvaz-nl-test-form" method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>"><input type="hidden" name="action" value="rvaz_nl_test"><input type="hidden" name="include_donation" value="0" class="rvaz-nl-donation-value"><?php wp_nonce_field('rvaz_nl_test'); ?><input type="email" required name="email" placeholder="test@adres.nl"> <button class="button">Testmail</button></form></div>
 <script>(function(){var t=document.getElementById('rvaz-nl-donation-toggle');if(!t)return;function sync(){document.querySelectorAll('.rvaz-nl-donation-value').forEach(function(i){i.value=t.checked?'1':'0';});}t.addEventListener('change',sync);sync();var ib=document.getElementById('rvaz-insert-app-banner');if(ib)ib.addEventListener('click',function(){var block=<?php echo wp_json_encode($app_banner); ?>;if(window.tinymce&&tinymce.get('rvaz_custom_content')){var ed=tinymce.get('rvaz_custom_content');ed.execCommand('mceInsertContent',false,block);}else{var t=document.getElementById('rvaz_custom_content');if(t)t.value+=block;}});})();</script>
 <h2>Voorbeeld van de volgende nieuwsbrief</h2><div style="max-width:760px;background:#fff;border:1px solid #ccd0d4;padding:18px"><?php echo $preview; ?></div></div><?php }
 public function subscribers_page(){
  if(!current_user_can('manage_options'))return;global $wpdb;$t=$this->table();
  $q=sanitize_text_field(wp_unslash($_GET['s']??''));$status=sanitize_key($_GET['status']??'');$list=sanitize_text_field(wp_unslash($_GET['list']??''));
  $where='1=1';$args=[];
  if($q!==''){$like='%'.$wpdb->esc_like($q).'%';$where.=' AND (email LIKE %s OR first_name LIKE %s OR last_name LIKE %s)';$args=[$like,$like,$like];}
  if(in_array($status,['confirmed','unsubscribed'],true)){$where.=' AND status=%s';$args[]=$status;}
  if($list!==''){$where.=' AND FIND_IN_SET(%s, REPLACE(lists, ", ", ","))';$args[]=$list;}
  $sql="SELECT * FROM $t WHERE $where ORDER BY id DESC LIMIT 500";if($args)$sql=$wpdb->prepare($sql,$args);$rows=$wpdb->get_results($sql);
  $all=(int)$wpdb->get_var("SELECT COUNT(*) FROM $t");$active=(int)$wpdb->get_var("SELECT COUNT(*) FROM $t WHERE status='confirmed'");$unsub=(int)$wpdb->get_var("SELECT COUNT(*) FROM $t WHERE status='unsubscribed'");$lists=$this->known_lists();
  echo '<div class="wrap"><h1>Abonnees</h1>';$this->notice();echo '<p><strong>'.$all.'</strong> totaal &nbsp; • &nbsp; <strong>'.$active.'</strong> actief &nbsp; • &nbsp; <strong>'.$unsub.'</strong> uitgeschreven</p>';
  echo '<h2>Handmatig e-mailadres toevoegen</h2><form method="post" action="'.esc_url(admin_url('admin-post.php')).'" style="background:#fff;border:1px solid #ccd0d4;padding:16px;max-width:1000px">';wp_nonce_field('rvaz_nl_subscriber_add');echo '<input type="hidden" name="action" value="rvaz_nl_subscriber_add"><input type="email" name="email" required placeholder="e-mailadres" style="min-width:250px"> <input name="first_name" placeholder="Voornaam / bedrijfsnaam"> <input name="last_name" placeholder="Achternaam"> <select name="target_list" required><option value="">— Verzendlijst —</option>';foreach($lists as $l)echo '<option value="'.esc_attr($l).'">'.esc_html($l).'</option>';echo '</select> <select name="status"><option value="confirmed">Actief</option><option value="unsubscribed">Uitgeschreven</option></select> <button class="button button-primary">Toevoegen</button><p class="description">Toevoegen start nooit een nieuwsbriefverzending. Een bestaand adres wordt alleen aan de gekozen lijst toegevoegd en een uitgeschreven adres wordt niet stilzwijgend opnieuw geactiveerd.</p></form>';
  echo '<form method="get" style="margin-top:18px"><input type="hidden" name="page" value="rvaz-newsletter-subscribers"><input type="search" name="s" value="'.esc_attr($q).'" placeholder="Zoek naam of e-mail"> <select name="status"><option value="">Alle statussen</option><option value="confirmed" '.selected($status,'confirmed',false).'>Actief</option><option value="unsubscribed" '.selected($status,'unsubscribed',false).'>Uitgeschreven</option></select> <select name="list"><option value="">Alle verzendlijsten</option>';foreach($lists as $l)echo '<option value="'.esc_attr($l).'" '.selected($list,$l,false).'>'.esc_html($l).'</option>';echo '</select> <button class="button">Filter</button></form>';
  echo '<div style="margin:12px 0;display:flex;gap:8px;align-items:center;flex-wrap:wrap"><a class="button'.($status==='unsubscribed'?' button-primary':'').'" href="'.esc_url(add_query_arg(['page'=>'rvaz-newsletter-subscribers','status'=>'unsubscribed'],admin_url('admin.php'))).'">Toon uitgeschreven ('.intval($unsub).')</a>'; if($unsub>0){echo '<form method="post" action="'.esc_url(admin_url('admin-post.php')).'" style="display:inline;margin:0">';wp_nonce_field('rvaz_nl_delete_all_unsubscribed');echo '<input type="hidden" name="action" value="rvaz_nl_delete_all_unsubscribed"><button class="button button-link-delete" onclick="return confirm(\'Alle '.intval($unsub).' uitgeschreven abonnees definitief verwijderen? Dit kan niet ongedaan worden gemaakt.\')">Alle uitgeschreven verwijderen</button></form>';} echo '</div>';
  echo '<form method="post" action="'.esc_url(admin_url('admin-post.php')).'" style="margin-top:16px">';wp_nonce_field('rvaz_nl_subscriber_bulk');echo '<input type="hidden" name="action" value="rvaz_nl_subscriber_bulk"><div style="margin:8px 0"><select name="bulk_action" required><option value="">Bulkactie</option><option value="delete">Definitief verwijderen</option><option value="unsubscribe">Markeer als uitgeschreven</option><option value="activate">Markeer als actief</option></select> <button class="button">Toepassen</button> <button type="button" class="button" id="rvaz-select-unsubscribed">Selecteer uitgeschreven op dit scherm</button></div><table class="widefat striped"><thead><tr><td class="check-column"><input type="checkbox" id="rvaz-select-all"></td><th>E-mail</th><th>Voornaam</th><th>Achternaam</th><th>Status</th><th>Lijst(en)</th><th>Acties</th></tr></thead><tbody>';
  foreach($rows as $r){echo '<tr data-status="'.esc_attr($r->status).'"><th class="check-column"><input type="checkbox" name="subscriber_ids[]" value="'.intval($r->id).'"></th><td>'.esc_html($r->email).'</td><td>'.esc_html($r->first_name).'</td><td>'.esc_html($r->last_name).'</td><td>'.($r->status==='unsubscribed'?'<strong>Uitgeschreven</strong>':'Actief').'</td><td>'.esc_html($r->lists).'</td><td><a class="button" href="'.esc_url(add_query_arg(['page'=>'rvaz-newsletter-subscribers','edit_subscriber'=>$r->id],admin_url('admin.php'))).'">Bewerken</a> <a class="button" href="'.esc_url(wp_nonce_url(admin_url('admin-post.php?action=rvaz_nl_subscriber_delete&id='.$r->id),'rvaz_nl_delete_'.$r->id)).'" onclick="return confirm(\'Abonnee definitief verwijderen?\')">Verwijder</a></td></tr>';}
  echo '</tbody></table><p>Maximaal 500 resultaten per scherm; gebruik zoeken en filters voor grotere lijsten. Met “Alle uitgeschreven verwijderen” hierboven verwijder je ook uitgeschreven adressen die niet op dit scherm staan.</p></form><script>document.getElementById("rvaz-select-all").addEventListener("change",function(){document.querySelectorAll("input[name=\"subscriber_ids[]\"]").forEach(function(x){x.checked=this.checked}.bind(this));});var su=document.getElementById("rvaz-select-unsubscribed");if(su)su.addEventListener("click",function(){document.querySelectorAll("tr[data-status=\"unsubscribed\"] input[name=\"subscriber_ids[]\"]").forEach(function(x){x.checked=true;});});</script>';
  $edit=absint($_GET['edit_subscriber']??0);if($edit){$r=$wpdb->get_row($wpdb->prepare("SELECT * FROM $t WHERE id=%d",$edit));if($r){echo '<hr><h2>Abonnee bewerken</h2><form method="post" action="'.esc_url(admin_url('admin-post.php')).'">';wp_nonce_field('rvaz_nl_subscriber_'.$r->id);echo '<input type="hidden" name="action" value="rvaz_nl_subscriber_save"><input type="hidden" name="id" value="'.intval($r->id).'"><table class="form-table"><tr><th>E-mail</th><td><input type="email" name="email" value="'.esc_attr($r->email).'" required></td></tr><tr><th>Voornaam</th><td><input name="first_name" value="'.esc_attr($r->first_name).'"></td></tr><tr><th>Achternaam</th><td><input name="last_name" value="'.esc_attr($r->last_name).'"></td></tr><tr><th>Status</th><td><select name="status"><option value="confirmed" '.selected($r->status,'confirmed',false).'>Actief</option><option value="unsubscribed" '.selected($r->status,'unsubscribed',false).'>Uitgeschreven</option></select></td></tr><tr><th>Lijst(en)</th><td><input class="regular-text" name="lists" value="'.esc_attr($r->lists).'"></td></tr></table><button class="button button-primary">Opslaan</button></form>';}}
  echo '</div>';
 }
 public function subscriber_add(){
  if(!current_user_can('manage_options')||!check_admin_referer('rvaz_nl_subscriber_add'))wp_die('Geen toegang');global $wpdb;$email=sanitize_email($_POST['email']??'');$list=sanitize_text_field(wp_unslash($_POST['target_list']??''));$status=in_array($_POST['status']??'',['confirmed','unsubscribed'],true)?$_POST['status']:'confirmed';if(!$email||$list==='')wp_die('E-mailadres en verzendlijst zijn verplicht.');
  $existing=$wpdb->get_row($wpdb->prepare("SELECT * FROM {$this->table()} WHERE email=%s",$email));
  if($existing){$ls=array_values(array_filter(array_map('trim',preg_split('/[,;]+/',(string)$existing->lists))));if(!in_array($list,$ls,true))$ls[]=$list;$data=['lists'=>implode(', ',$ls)];if($existing->status!=='unsubscribed')$data['status']=$status;if(!empty($_POST['first_name']))$data['first_name']=sanitize_text_field(wp_unslash($_POST['first_name']));if(!empty($_POST['last_name']))$data['last_name']=sanitize_text_field(wp_unslash($_POST['last_name']));$wpdb->update($this->table(),$data,['id'=>(int)$existing->id]);$msg=$existing->status==='unsubscribed'?'Bestaand uitgeschreven adres aan de lijst gekoppeld; de uitschrijving is behouden.':'Bestaand adres aan de verzendlijst toegevoegd.';}
  else{$wpdb->insert($this->table(),['email'=>$email,'first_name'=>sanitize_text_field(wp_unslash($_POST['first_name']??'')),'last_name'=>sanitize_text_field(wp_unslash($_POST['last_name']??'')),'status'=>$status,'lists'=>$list,'consent_at'=>null,'created_at'=>current_time('mysql'),'unsub_token'=>wp_generate_password(40,false,false)]);$msg='E-mailadres handmatig toegevoegd aan de verzendlijst.';}
  wp_safe_redirect(add_query_arg('rvaz_nl_msg',rawurlencode($msg),admin_url('admin.php?page=rvaz-newsletter-subscribers')));exit;
 }
 public function delete_all_unsubscribed(){
  if(!current_user_can('manage_options')||!check_admin_referer('rvaz_nl_delete_all_unsubscribed'))wp_die('Geen toegang');
  global $wpdb;$t=$this->table();$count=(int)$wpdb->get_var("SELECT COUNT(*) FROM $t WHERE status='unsubscribed'");
  if($count>0)$wpdb->query("DELETE FROM $t WHERE status='unsubscribed'");
  $msg=$count.' uitgeschreven abonnee(s) definitief verwijderd.';
  wp_safe_redirect(add_query_arg(['page'=>'rvaz-newsletter-subscribers','status'=>'unsubscribed','rvaz_nl_msg'=>rawurlencode($msg)],admin_url('admin.php')));exit;
 }
 public function subscriber_bulk(){
  if(!current_user_can('manage_options')||!check_admin_referer('rvaz_nl_subscriber_bulk'))wp_die('Geen toegang');global $wpdb;$ids=array_values(array_filter(array_map('absint',(array)($_POST['subscriber_ids']??[]))));$action=sanitize_key($_POST['bulk_action']??'');if(!$ids||!in_array($action,['delete','unsubscribe','activate'],true))wp_die('Selecteer eerst abonnees en een geldige bulkactie.');$ph=implode(',',array_fill(0,count($ids),'%d'));
  if($action==='delete'){$sql=$wpdb->prepare("DELETE FROM {$this->table()} WHERE id IN ($ph)",$ids);$wpdb->query($sql);$msg=count($ids).' geselecteerde abonnee(s) definitief verwijderd.';}
  elseif($action==='unsubscribe'){$sql=$wpdb->prepare("UPDATE {$this->table()} SET status='unsubscribed' WHERE id IN ($ph)",$ids);$wpdb->query($sql);$msg=count($ids).' geselecteerde abonnee(s) als uitgeschreven gemarkeerd.';}
  else{$sql=$wpdb->prepare("UPDATE {$this->table()} SET status='confirmed' WHERE id IN ($ph)",$ids);$wpdb->query($sql);$msg=count($ids).' geselecteerde abonnee(s) als actief gemarkeerd.';}
  wp_safe_redirect(add_query_arg('rvaz_nl_msg',rawurlencode($msg),admin_url('admin.php?page=rvaz-newsletter-subscribers')));exit;
 }
 public function subscriber_save(){if(!current_user_can('manage_options'))wp_die('Geen toegang');global $wpdb;$id=absint($_POST['id']??0);check_admin_referer('rvaz_nl_subscriber_'.$id);$email=sanitize_email($_POST['email']??'');if(!$id||!$email)wp_die('Ongeldige abonnee.');$wpdb->update($this->table(),['email'=>$email,'first_name'=>sanitize_text_field($_POST['first_name']??''),'last_name'=>sanitize_text_field($_POST['last_name']??''),'status'=>in_array($_POST['status']??'',['confirmed','unsubscribed'],true)?$_POST['status']:'confirmed','lists'=>sanitize_text_field($_POST['lists']??'')],['id'=>$id],['%s','%s','%s','%s','%s'],['%d']);wp_safe_redirect(add_query_arg('rvaz_nl_msg',rawurlencode('Abonnee bijgewerkt.'),admin_url('admin.php?page=rvaz-newsletter-subscribers')));exit;}
 public function subscriber_delete(){if(!current_user_can('manage_options'))wp_die('Geen toegang');global $wpdb;$id=absint($_GET['id']??0);check_admin_referer('rvaz_nl_delete_'.$id);if($id)$wpdb->delete($this->table(),['id'=>$id],['%d']);wp_safe_redirect(add_query_arg('rvaz_nl_msg',rawurlencode('Abonnee verwijderd.'),admin_url('admin.php?page=rvaz-newsletter-subscribers')));exit;}
 public function stats_page(){if(!current_user_can('manage_options'))return;global $wpdb;$m=$this->mailings_table();$e=$this->events_table();$rows=$wpdb->get_results("SELECT m.*, (SELECT COUNT(DISTINCT subscriber_id) FROM $e x WHERE x.mailing_id=m.id AND x.event_type='open') opens,(SELECT COUNT(*) FROM $e x WHERE x.mailing_id=m.id AND x.event_type='click') clicks,(SELECT COUNT(DISTINCT subscriber_id) FROM $e x WHERE x.mailing_id=m.id AND x.event_type='click') unique_clicks FROM $m m ORDER BY id DESC LIMIT 50");echo '<div class="wrap"><h1>Nieuwsbrief statistieken</h1><p>Openpercentages zijn een schatting door privacyfuncties van mailapps. Klikken zijn betrouwbaarder. Regio wordt alleen geaggregeerd opgeslagen; ruwe IP-adressen worden niet bewaard.</p><table class="widefat striped"><thead><tr><th>Datum</th><th>Onderwerp</th><th>Status</th><th>Voortgang</th><th>Mislukt</th><th>Unieke opens</th><th>Kliks</th><th>Unieke klikkers</th><th>CTR</th><th>Acties</th></tr></thead><tbody>';foreach($rows as $r){$ctr=$r->sent_count?round(($r->unique_clicks/$r->sent_count)*100,1):0;echo '<tr><td>'.esc_html($r->sent_at).'</td><td><a href="'.esc_url(add_query_arg(['page'=>'rvaz-newsletter-stats','mailing'=>$r->id],admin_url('admin.php'))).'">'.esc_html($r->subject).'</a></td><td>'.esc_html($r->status?:'voltooid').'</td><td>'.intval($r->sent_count).' / '.intval($r->total_count?:$r->sent_count).'</td><td>'.intval($r->failed_count).'</td><td>'.intval($r->opens).'</td><td>'.intval($r->clicks).'</td><td>'.intval($r->unique_clicks).'</td><td>'.esc_html($ctr).'%</td><td>'; if(in_array($r->status,['paused','cancelled','completed'],true)){echo '<form method="post" action="'.esc_url(admin_url('admin-post.php')).'" style="display:inline" onsubmit="return confirm(\'Deze nieuwsbrief en de bijbehorende statistieken definitief verwijderen? Dit kan niet ongedaan worden gemaakt.\');"><input type="hidden" name="action" value="rvaz_nl_delete_mailing"><input type="hidden" name="mailing_id" value="'.intval($r->id).'">';wp_nonce_field('rvaz_nl_delete_mailing_'.$r->id);echo '<button class="button button-link-delete">Verwijderen</button></form>'; }else{echo '<span style="color:#777">Eerst pauzeren</span>';} echo '</td></tr>';}echo '</tbody></table>';
  $mid=absint($_GET['mailing']??0);if($mid){$editing=$wpdb->get_row($wpdb->prepare("SELECT * FROM $m WHERE id=%d",$mid));if($editing && in_array($editing->status,['queued','sending','paused'],true)){ $edit_html=(string)$editing->content_html;if($edit_html===''){$edit_html=$this->newsletter_html(false,$this->mailing_posts($editing));} echo '<h2>Resterende verzending beheren</h2><p>Wijzigingen hieronder gelden alleen voor ontvangers die deze nieuwsbrief nog niet hebben ontvangen. Reeds verzonden e-mails veranderen niet.</p><form method="post" action="'.esc_url(admin_url('admin-post.php')).'"><input type="hidden" name="action" value="rvaz_nl_edit_mailing"><input type="hidden" name="mailing_id" value="'.intval($mid).'">';wp_nonce_field('rvaz_nl_edit_'.$mid);echo '<table class="form-table"><tr><th>Onderwerp</th><td><input class="large-text" name="subject" value="'.esc_attr($editing->subject).'"></td></tr><tr><th>Nieuwsbriefinhoud</th><td>';wp_editor($edit_html,'rvaz_mailing_content',['textarea_name'=>'content_html','textarea_rows'=>18,'media_buttons'=>true]);echo '</td></tr></table><p><button class="button button-primary">Wijzigingen opslaan voor resterende ontvangers</button></p></form>';
   $remaining=max(0,(int)$editing->total_count-(int)$editing->sent_count-(int)$editing->failed_count);
   echo '<div style="margin:20px 0;padding:18px 20px;background:#fff;border:1px solid #c3c4c7;border-left:4px solid #2271b1;max-width:1000px"><h2 style="margin-top:0">Verzending</h2><p><strong>'.intval($remaining).' ontvanger(s) resterend.</strong> De nieuwsbrief wordt alleen verzonden na een expliciete klik hieronder.</p>';
   if($editing->status==='paused'){
    echo '<form method="post" action="'.esc_url(admin_url('admin-post.php')).'" onsubmit="return confirm(\'Nieuwsbrief nu verzenden naar de resterende '.intval($remaining).' ontvanger(s)?\');"><input type="hidden" name="action" value="rvaz_nl_resume"><input type="hidden" name="mailing_id" value="'.intval($mid).'">';wp_nonce_field('rvaz_nl_resume_'.$mid);echo '<button class="button button-primary button-hero">▶ Verzending starten</button></form>';
   }else{
    echo '<p><strong>Status:</strong> verzending is actief.</p><div style="display:flex;gap:8px;flex-wrap:wrap"><form method="post" action="'.esc_url(admin_url('admin-post.php')).'"><input type="hidden" name="action" value="rvaz_nl_kick_worker"><input type="hidden" name="mailing_id" value="'.intval($mid).'">';wp_nonce_field('rvaz_nl_kick_'.$mid);echo '<button class="button button-primary">↻ Verzending nu hervatten</button></form><form method="post" action="'.esc_url(admin_url('admin-post.php')).'"><input type="hidden" name="action" value="rvaz_nl_pause"><input type="hidden" name="mailing_id" value="'.intval($mid).'">';wp_nonce_field('rvaz_nl_pause_'.$mid);echo '<button class="button">⏸ Verzending pauzeren</button></form></div>';
   }
   echo '</div>'; } $links=$wpdb->get_results($wpdb->prepare("SELECT url,COUNT(*) clicks,COUNT(DISTINCT subscriber_id) unique_clicks FROM $e WHERE mailing_id=%d AND event_type='click' GROUP BY url ORDER BY clicks DESC LIMIT 30",$mid));$regions=$wpdb->get_results($wpdb->prepare("SELECT region,COUNT(*) clicks FROM $e WHERE mailing_id=%d AND event_type='click' AND region<>'' GROUP BY region ORDER BY clicks DESC",$mid));echo '<h2>Meest aangeklikte links</h2><table class="widefat striped"><tr><th>Link</th><th>Kliks</th><th>Uniek</th></tr>';foreach($links as $x)echo '<tr><td style="word-break:break-all">'.esc_html($x->url).'</td><td>'.intval($x->clicks).'</td><td>'.intval($x->unique_clicks).'</td></tr>';echo '</table><h2>Regio op basis van kliks</h2><table class="widefat striped"><tr><th>Regio</th><th>Kliks</th></tr>';foreach($regions as $x)echo '<tr><td>'.esc_html($x->region).'</td><td>'.intval($x->clicks).'</td></tr>';echo '</table>';}echo '</div>';}
 private function notice(){if(!empty($_GET['rvaz_nl_msg'])) echo '<div class="notice notice-success is-dismissible"><p>'.esc_html(wp_unslash($_GET['rvaz_nl_msg'])).'</p></div>';}
 public function settings_page(){if(!current_user_can('manage_options'))return; $o=get_option(self::OPT,[]); ?>
 <div class="wrap"><h1>Nieuwsbrief instellingen</h1><form method="post" action="options.php"><?php settings_fields('rvaz_nl'); ?><table class="form-table">
 <?php $fields=['from_name'=>'Afzendernaam','from_email'=>'Afzender e-mail','reply_to'=>'Reply-to e-mail','subject'=>'Onderwerp (gebruik {date})','intro'=>'Introductietekst','post_count'=>'Aantal nieuwsberichten','send_time'=>'Dagelijkse verzendtijd (HH:MM)','smtp_host'=>'SMTP server / host','smtp_port'=>'SMTP poort','smtp_user'=>'SMTP gebruikersnaam','smtp_pass'=>'SMTP wachtwoord','rvaz_ad_top'=>'RVAZ advertentie-shortcode bovenaan','rvaz_ad_middle'=>'RVAZ advertentie-shortcode tussen nieuws','rvaz_ad_bottom'=>'RVAZ advertentie-shortcode onderaan','app_tester_url'=>'Registratieformulier app-testers','app_play_test_url'=>'Google Play testlink (Android)','app_store_url'=>'Apple App Store-link (iPhone & iPad)']; foreach($fields as $k=>$lab): ?><tr><th><?php echo esc_html($lab); ?></th><td><input class="regular-text" name="<?php echo self::OPT.'['.$k.']'; ?>" value="<?php echo esc_attr($o[$k]??''); ?>"></td></tr><?php endforeach; ?>
 <tr><th></th><td><p class="description"><strong>App-testers:</strong> de echte Google Play-testlink kan hier worden overschreven. Versie 1.9.4 bevat standaard de huidige RVAZ interne-testlink. De app-testersnieuwsbrief en shortcode <code>[rvaz_app_tester_link]</code> gebruiken daarna automatisch deze URL. Zolang het veld leeg is, wordt het registratieformulier gebruikt.</p></td></tr>
 <tr><th>App-testers label</th><td><input class="large-text" name="<?php echo self::OPT; ?>[app_banner_label]" value="<?php echo esc_attr($o['app_banner_label']??'WORD APP-TESTER'); ?>"></td></tr>
 <tr><th>App-testers titel</th><td><input class="large-text" name="<?php echo self::OPT; ?>[app_banner_title]" value="<?php echo esc_attr($o['app_banner_title']??'Help de nieuwe RVAZ-app testen'); ?>"></td></tr>
 <tr><th>App-testers tekst</th><td><textarea class="large-text" rows="4" name="<?php echo self::OPT; ?>[app_banner_body]"><?php echo esc_textarea($o['app_banner_body']??'Test nieuws, P2000, advertenties, agenda en Mijn RVAZ. Onder alle geldige testers verloten we 5× een bol.com-waardebon van €25.'); ?></textarea></td></tr>
 <tr><th>App-testers accounttekst</th><td><textarea class="large-text" rows="3" name="<?php echo self::OPT; ?>[app_banner_account]"><?php echo esc_textarea($o['app_banner_account']??'Voor deelname aan de verloting is een RVAZ-account nodig. Meld je eerst aan als tester met het e-mailadres van je RVAZ-account.'); ?></textarea></td></tr>
 <tr><th>App-testers knoptekst</th><td><input class="large-text" name="<?php echo self::OPT; ?>[app_banner_button]" value="<?php echo esc_attr($o['app_banner_button']??'Aanmelden als tester →'); ?>"></td></tr>
 <tr><th>App-testers tekst onder knop</th><td><textarea class="large-text" rows="2" name="<?php echo self::OPT; ?>[app_banner_note]"><?php echo esc_textarea($o['app_banner_note']??'Gebruik de Google Play-testlink om deel te nemen. Voor de interne test moet het gebruikte Google-account toegang hebben tot de test.'); ?></textarea></td></tr>
 <tr><th>Extra opmerkingen reguliere nieuwsbrief</th><td><textarea class="large-text" rows="8" name="<?php echo self::OPT; ?>[extra_notes]" placeholder="Eerste losse opmerking...&#10;&#10;---&#10;&#10;Tweede losse opmerking..."><?php echo esc_textarea($o['extra_notes']??''); ?></textarea><p class="description">Optioneel. Scheid meerdere losse blokken met een regel met alleen <code>---</code>. Ieder blok wordt apart in de reguliere nieuwsbrief geplaatst.</p></td></tr>
 <tr><th>Eenmalig mededelingsblok</th><td><label><input type="checkbox" name="<?php echo self::OPT; ?>[apology_once]" value="1" <?php checked(get_option('rvaz_nl_apology_pending','1'),'1'); ?>> Opnemen in de eerstvolgende reguliere nieuwsbrief</label><p class="description">Na het aanmaken van die reguliere mailing wordt dit automatisch uitgezet. Je kunt het later opnieuw aanvinken.</p></td></tr>
 <tr><th>Titel mededelingsblok</th><td><input class="large-text" name="<?php echo self::OPT; ?>[apology_title]" value="<?php echo esc_attr($o['apology_title']??'Onze excuses voor de extra nieuwsbrieven'); ?>"></td></tr>
 <tr><th>Tekst mededelingsblok</th><td><textarea class="large-text" rows="5" name="<?php echo self::OPT; ?>[apology_body]"><?php echo esc_textarea($o['apology_body']??'Door de vernieuwing van Regio Voorne aan Zee is ons nieuwsbriefsysteem tijdelijk in de war geraakt. Daardoor zijn sommige nieuwsbrieven vaker verzonden dan wij zelf wilden. Onze excuses voor het ongemak. We hebben dit inmiddels aangepakt.'); ?></textarea></td></tr>
 <tr><th>Ondertekening mededelingsblok</th><td><input class="regular-text" name="<?php echo self::OPT; ?>[apology_signature]" value="<?php echo esc_attr($o['apology_signature']??'Rudy de Jonge'); ?>"></td></tr>
 <tr><th>Klein logo bovenaan</th><td><input id="rvaz-nl-logo" class="regular-text" name="<?php echo self::OPT; ?>[logo_url]" value="<?php echo esc_attr($o['logo_url']??''); ?>"><input type="hidden" id="rvaz-nl-logo-id" name="<?php echo self::OPT; ?>[logo_id]" value="<?php echo absint($o['logo_id']??0); ?>"> <button type="button" class="button rvaz-pick-logo">Kies uit mediabibliotheek</button><br><?php if(!empty($o['logo_url'])): ?><img id="rvaz-nl-logo-preview" src="<?php echo esc_url($o['logo_url']); ?>" style="max-height:55px;max-width:220px;margin-top:8px"><?php else: ?><img id="rvaz-nl-logo-preview" style="display:none;max-height:55px;max-width:220px;margin-top:8px"><?php endif; ?><p class="description">Wordt compact bovenaan iedere nieuwsbrief geplaatst.</p></td></tr>
 <tr><th>WhatsApp-kanaallink</th><td><input class="regular-text" name="<?php echo self::OPT; ?>[whatsapp_url]" value="<?php echo esc_attr($o['whatsapp_url']??get_theme_mod('rvaz_whatsapp_url','')); ?>" placeholder="https://whatsapp.com/channel/..."><p class="description">De groene WhatsApp-banner verschijnt zodra hier een link staat.</p></td></tr>
 <tr><th>WhatsApp-banner</th><td><label><input type="checkbox" name="<?php echo self::OPT; ?>[whatsapp_enabled]" value="1" <?php checked(isset($o['whatsapp_enabled']) ? !empty($o['whatsapp_enabled']) : true); ?>> Tonen in de nieuwsbrief</label></td></tr>
<tr><th>Regiostatistieken</th><td><label><input type="checkbox" name="<?php echo self::OPT; ?>[geo_stats]" value="1" <?php checked(isset($o['geo_stats']) ? !empty($o['geo_stats']) : true); ?>> Bepaal provincie/regio bij klikken (geen ruwe IP-adressen opslaan)</label></td></tr>
 <tr><th>Automatisch verzenden</th><td><label><input type="checkbox" name="<?php echo self::OPT; ?>[auto]" value="1" <?php checked(!empty($o['auto'])); ?>> Dagelijks automatisch de nieuwste nieuwsberichten verzenden</label></td></tr>
 <tr><th>SMTP gebruiken</th><td><label><input type="checkbox" name="<?php echo self::OPT; ?>[smtp_enabled]" value="1" <?php checked(!empty($o['smtp_enabled'])); ?>> Gebruik eigen SMTP voor RVAZ Nieuwsbrief</label></td></tr>
 <tr><th>SMTP authenticatie</th><td><label><input type="checkbox" name="<?php echo self::OPT; ?>[smtp_auth]" value="1" <?php checked(!empty($o['smtp_auth'])); ?>> Gebruikersnaam/wachtwoord gebruiken</label></td></tr>
 <tr><th>SMTP beveiliging</th><td><select name="<?php echo self::OPT; ?>[smtp_secure]"><option value="" <?php selected($o['smtp_secure']??'',''); ?>>Geen</option><option value="tls" <?php selected($o['smtp_secure']??'','tls'); ?>>TLS</option><option value="ssl" <?php selected($o['smtp_secure']??'','ssl'); ?>>SSL</option></select></td></tr>
 </table><?php submit_button(); ?></form><p><strong>Eigen RVAZ Advertentiebeheer:</strong> gebruik <code>[rvaz_advertentie_email position=&quot;newsletter-top&quot;]</code>, <code>[rvaz_advertentie_email position=&quot;newsletter-middle&quot;]</code> en <code>[rvaz_advertentie_email position=&quot;newsletter-bottom&quot;]</code>. Advanced Ads is hiervoor niet nodig.</p></div><?php }
 private function known_lists(){global $wpdb;$known=[];foreach((array)get_option('rvaz_nl_lists',[]) as $x){$x=trim((string)$x);if($x!=='')$known[$x]=1;}$vals=$wpdb->get_col("SELECT lists FROM {$this->table()} WHERE lists IS NOT NULL AND lists<>''");foreach((array)$vals as $v){foreach(preg_split('/[,;]+/',(string)$v) as $x){$x=trim($x);if($x!=='')$known[$x]=1;}}ksort($known,SORT_NATURAL|SORT_FLAG_CASE);return array_keys($known);}
 private function save_lists($lists){$clean=[];foreach((array)$lists as $x){$x=sanitize_text_field($x);if($x!==''&&!in_array($x,$clean,true))$clean[]=$x;}sort($clean,SORT_NATURAL|SORT_FLAG_CASE);update_option('rvaz_nl_lists',$clean,false);}
 public function lists_page(){if(!current_user_can('manage_options'))return;global $wpdb;$lists=$this->known_lists();echo '<div class="wrap"><h1>Verzendlijsten</h1>';$this->notice();echo '<p>Maak hier vaste verzendlijsten. Een lijst aanmaken, wijzigen of verwijderen <strong>verzendt nooit e-mail</strong>.</p><h2>Nieuwe verzendlijst</h2><form method="post" action="'.esc_url(admin_url('admin-post.php')).'"><input type="hidden" name="action" value="rvaz_nl_list_create">';wp_nonce_field('rvaz_nl_list_create');echo '<input class="regular-text" name="list_name" required placeholder="bijv. Bedrijven Voorne aan Zee"> <button class="button button-primary">Verzendlijst maken</button></form><h2 style="margin-top:28px">Bestaande verzendlijsten</h2><table class="widefat striped"><thead><tr><th>Naam</th><th>Ontvangers</th><th>Acties</th></tr></thead><tbody>';if(!$lists)echo '<tr><td colspan="3">Nog geen verzendlijsten.</td></tr>';foreach($lists as $list){$cnt=0;$rows=$wpdb->get_col("SELECT lists FROM {$this->table()} WHERE status='confirmed' AND lists IS NOT NULL AND lists<>''");foreach((array)$rows as $v){$a=array_map('trim',preg_split('/[,;]+/',(string)$v));if(in_array($list,$a,true))$cnt++;}echo '<tr><td><strong>'.esc_html($list).'</strong></td><td>'.intval($cnt).'</td><td><form style="display:inline-flex;gap:6px;align-items:center" method="post" action="'.esc_url(admin_url('admin-post.php')).'"><input type="hidden" name="action" value="rvaz_nl_list_rename"><input type="hidden" name="old_name" value="'.esc_attr($list).'">';wp_nonce_field('rvaz_nl_list_rename_'.$list);echo '<input name="new_name" value="'.esc_attr($list).'" required><button class="button">Hernoemen</button></form> <form style="display:inline" method="post" action="'.esc_url(admin_url('admin-post.php')).'" onsubmit="return confirm(\'Verzendlijst verwijderen? Abonnees zelf worden niet verwijderd.\');"><input type="hidden" name="action" value="rvaz_nl_list_delete"><input type="hidden" name="list_name" value="'.esc_attr($list).'">';wp_nonce_field('rvaz_nl_list_delete_'.$list);echo '<button class="button">Verwijderen</button></form></td></tr>';}echo '</tbody></table></div>';}
 public function list_create(){if(!current_user_can('manage_options'))wp_die('Geen toegang');check_admin_referer('rvaz_nl_list_create');$name=sanitize_text_field(wp_unslash($_POST['list_name']??''));if($name==='')wp_die('Vul een lijstnaam in.');$lists=$this->known_lists();if(!in_array($name,$lists,true))$lists[]=$name;$this->save_lists($lists);wp_safe_redirect(add_query_arg('rvaz_nl_msg',rawurlencode('Verzendlijst aangemaakt. Er is niets verzonden.'),admin_url('admin.php?page=rvaz-newsletter-lists')));exit;}
 public function list_rename(){if(!current_user_can('manage_options'))wp_die('Geen toegang');$old=sanitize_text_field(wp_unslash($_POST['old_name']??''));check_admin_referer('rvaz_nl_list_rename_'.$old);$new=sanitize_text_field(wp_unslash($_POST['new_name']??''));if($old===''||$new==='')wp_die('Ongeldige lijstnaam.');global $wpdb;$rows=$wpdb->get_results("SELECT id,lists FROM {$this->table()} WHERE lists IS NOT NULL AND lists<>''");foreach($rows as $r){$a=array_values(array_filter(array_map('trim',preg_split('/[,;]+/',(string)$r->lists))));$changed=false;foreach($a as &$x){if($x===$old){$x=$new;$changed=true;}}unset($x);if($changed)$wpdb->update($this->table(),['lists'=>implode(', ',array_values(array_unique($a)))],['id'=>(int)$r->id],['%s'],['%d']);}$lists=array_values(array_filter($this->known_lists(),fn($x)=>$x!==$old));if(!in_array($new,$lists,true))$lists[]=$new;$this->save_lists($lists);wp_safe_redirect(add_query_arg('rvaz_nl_msg',rawurlencode('Verzendlijst hernoemd. Er is niets verzonden.'),admin_url('admin.php?page=rvaz-newsletter-lists')));exit;}
 public function list_delete(){if(!current_user_can('manage_options'))wp_die('Geen toegang');$name=sanitize_text_field(wp_unslash($_POST['list_name']??''));check_admin_referer('rvaz_nl_list_delete_'.$name);global $wpdb;$rows=$wpdb->get_results("SELECT id,lists FROM {$this->table()} WHERE lists IS NOT NULL AND lists<>''");foreach($rows as $r){$a=array_values(array_filter(array_map('trim',preg_split('/[,;]+/',(string)$r->lists)),fn($x)=>$x!==$name));$wpdb->update($this->table(),['lists'=>implode(', ',$a)],['id'=>(int)$r->id],['%s'],['%d']);}$this->save_lists(array_values(array_filter($this->known_lists(),fn($x)=>$x!==$name)));wp_safe_redirect(add_query_arg('rvaz_nl_msg',rawurlencode('Verzendlijst verwijderd; abonnees zijn behouden. Er is niets verzonden.'),admin_url('admin.php?page=rvaz-newsletter-lists')));exit;}
 public function compose_page(){if(!current_user_can('manage_options'))return;$lists=$this->known_lists(); ?>
 <div class="wrap"><h1>Nieuwsbrief maken</h1><?php $this->notice(); ?>
 <p>Maak een losse nieuwsbrief en kies precies naar welke verzendlijst hij bestemd is. <strong>Opslaan start nooit de verzending.</strong> De mailing wordt altijd als gepauzeerd concept aangemaakt.</p>
 <form id="rvaz-compose-form" method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>"><input type="hidden" name="action" value="rvaz_nl_custom_save"><input type="hidden" id="rvaz-template-type" name="template_type" value=""><?php wp_nonce_field('rvaz_nl_custom_save'); ?>
 <table class="form-table"><tr><th><label for="rvaz-target-list">Verzendlijst</label></th><td><select id="rvaz-target-list" name="target_list" required><option value="">— Kies verzendlijst —</option><?php foreach($lists as $list): global $wpdb;$like='%'.$wpdb->esc_like($list).'%';$n=(int)$wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM {$this->table()} WHERE status='confirmed' AND lists LIKE %s",$like)); ?><option value="<?php echo esc_attr($list); ?>"><?php echo esc_html($list); ?> (<?php echo intval($n); ?>)</option><?php endforeach; ?></select></td></tr>
 <tr><th><label for="rvaz-subject">Onderwerp</label></th><td><input id="rvaz-subject" class="regular-text" name="subject" required></td></tr><tr><th>Donatie</th><td><label><input type="checkbox" name="include_donation" value="1"> Donatieblok opnemen in deze nieuwsbrief</label></td></tr></table>
 <h2>Inhoud</h2>
 <p><button type="button" class="button button-primary" id="rvaz-builder-mode">Vrij ontwerp (drag &amp; drop)</button> <button type="button" class="button" id="rvaz-classic-mode">Klassieke editor</button></p>
 <div id="rvaz-builder" style="display:none;max-width:1050px">
  <p><strong>Sleep blokken naar je nieuwsbrief.</strong> Logo/header en de uitschrijflink worden bij opslaan automatisch door het bestaande RVAZ-sjabloon toegevoegd.</p>
  <div style="display:grid;grid-template-columns:220px minmax(0,680px);gap:18px;align-items:start">
   <div id="rvaz-palette" style="background:#fff;border:1px solid #ccd0d4;padding:12px;position:sticky;top:40px">
    <strong>Blokken</strong>
    <div class="rvaz-block-add" draggable="true" data-type="heading">Koptekst</div><div class="rvaz-block-add" draggable="true" data-type="text">Tekst</div><div class="rvaz-block-add" draggable="true" data-type="image">Afbeelding</div><div class="rvaz-block-add" draggable="true" data-type="button">Knop</div><div class="rvaz-block-add" draggable="true" data-type="columns">2 kolommen</div><div class="rvaz-block-add" draggable="true" data-type="divider">Scheidingslijn</div><div class="rvaz-block-add" draggable="true" data-type="spacer">Witruimte</div>
   </div>
   <div id="rvaz-canvas" style="min-height:420px;background:#f6f7f7;border:2px dashed #a7aaad;padding:14px"><div id="rvaz-empty" style="padding:60px 20px;text-align:center;color:#646970">Sleep hier je eerste blok naartoe of klik op een blok links.</div></div>
  </div>
 </div>
 <div id="rvaz-classic">
  <p><label for="rvaz-template"><strong>Eenmalige template:</strong></label> <select id="rvaz-template"><option value="">— Lege nieuwsbrief —</option><option value="app-testers">APP-test uitnodiging — met en zonder RVAZ-account</option><option value="app-apple-android">APP — Apple downloaden + Android tester aanmelden</option><option value="wonen-makelaars">RVAZ Wonen — uitnodiging makelaars (eenmalig)</option></select> <button type="button" class="button" id="rvaz-load-template">Template laden</button> <button type="button" class="button" id="rvaz-insert-app-banner">App-testersbanner als blok invoegen</button> <button type="button" class="button" id="rvaz-insert-apology">Mededelingsblok invoegen</button> <button type="button" class="button" id="rvaz-insert-note">Los opmerkingenblok invoegen</button> <button type="button" class="button" id="rvaz-insert-wonen">Wonen op Voorne invoegen</button></p>
  <?php wp_editor('', 'rvaz_custom_content', ['textarea_name'=>'content_html','media_buttons'=>true,'textarea_rows'=>18,'teeny'=>false]); ?>
 </div>
 <p style="margin-top:18px"><button class="button button-primary button-hero" type="submit">Opslaan als gepauzeerd concept</button></p>
 </form>
 <style>.rvaz-block-add{margin:8px 0;padding:10px 12px;background:#f0f6fa;border:1px solid #b8cad6;border-radius:4px;cursor:grab;font-weight:600}.rvaz-builder-item{position:relative;background:#fff;border:1px solid #c3c4c7;margin:0 0 10px;padding:18px 42px 18px 18px;cursor:move}.rvaz-builder-item:hover{border-color:#2271b1}.rvaz-builder-remove{position:absolute;right:8px;top:8px;border:0;background:transparent;color:#b32d2e;font-size:20px;cursor:pointer}.rvaz-builder-edit{cursor:text;outline:none}.rvaz-builder-image{max-width:100%;height:auto;display:block;margin:auto}.rvaz-builder-image-placeholder{padding:32px;text-align:center;background:#f0f0f1;cursor:pointer}.rvaz-builder-button{display:inline-block;background:#064b7c;color:#fff;padding:11px 18px;border-radius:5px;text-decoration:none;font-weight:bold}.rvaz-builder-cols{display:grid;grid-template-columns:1fr 1fr;gap:16px}.rvaz-builder-col{padding:10px;border:1px dashed #c3c4c7;min-height:70px}</style>
 <?php $app_tpl=$this->app_tester_template_html(); $app_apple_android_tpl=$this->app_apple_android_template_html(); $makelaars_tpl=$this->wonen_makelaars_template_html(); $wonen_block=$this->wonen_email_html(); $app_banner=$this->app_tester_banner_email_html(); $apology_block=$this->apology_email_html(); $note_block='<div style="margin:16px 0;padding:16px 18px;background:#f3f7fa;border:1px solid #dce5eb;border-left:5px solid #0877b9;border-radius:8px"><strong style="color:#073b63">Extra opmerking</strong><p style="margin:6px 0 0;font-size:13px;color:#40536b">Pas deze tekst aan.</p></div>'; ?>
 <script>(function($){
 function ed(){return window.tinymce&&tinymce.get('rvaz_custom_content');} function insert(html){var e=ed();if(e)e.execCommand('mceInsertContent',false,html);else $('#rvaz_custom_content').val($('#rvaz_custom_content').val()+html);}
 $('#rvaz-builder-mode').on('click',function(){$('#rvaz-builder').show();$('#rvaz-classic').hide();$('#rvaz-template-type').val('free-builder');});
 $('#rvaz-classic-mode').on('click',function(){$('#rvaz-builder').hide();$('#rvaz-classic').show();if($('#rvaz-template-type').val()==='free-builder')$('#rvaz-template-type').val('');});
 function shell(inner){return $('<div class="rvaz-builder-item" draggable="true"><button type="button" class="rvaz-builder-remove" title="Verwijderen">×</button>'+inner+'</div>');}
 function add(type){var x;if(type==='heading')x=shell('<h2 class="rvaz-builder-edit" contenteditable="true" style="margin:0;color:#073b63">Nieuwe koptekst</h2>');else if(type==='text')x=shell('<div class="rvaz-builder-edit" contenteditable="true" style="font-size:15px;line-height:1.6">Klik hier en typ je tekst.</div>');else if(type==='image')x=shell('<div class="rvaz-builder-image-placeholder">Klik om een afbeelding toe te voegen</div>');else if(type==='button')x=shell('<div><a class="rvaz-builder-button" href="#" data-edit-button="1">Knoptekst</a></div>');else if(type==='columns')x=shell('<div class="rvaz-builder-cols"><div class="rvaz-builder-col rvaz-builder-edit" contenteditable="true">Linker kolom</div><div class="rvaz-builder-col rvaz-builder-edit" contenteditable="true">Rechter kolom</div></div>');else if(type==='divider')x=shell('<hr style="border:0;border-top:1px solid #dce5eb;margin:12px 0">');else x=shell('<div style="height:32px"></div>');$('#rvaz-empty').remove();$('#rvaz-canvas').append(x);}
 $('.rvaz-block-add').on('click',function(){add($(this).data('type'));}).on('dragstart',function(e){e.originalEvent.dataTransfer.setData('text/rvaz-block',$(this).data('type'));});
 $('#rvaz-canvas').on('dragover',function(e){e.preventDefault();}).on('drop',function(e){e.preventDefault();var t=e.originalEvent.dataTransfer.getData('text/rvaz-block');if(t)add(t);}).on('click','.rvaz-builder-remove',function(){$(this).closest('.rvaz-builder-item').remove();}).on('click','.rvaz-builder-image-placeholder,.rvaz-builder-image',function(){var box=$(this).closest('.rvaz-builder-item');var frame=wp.media({title:'Kies afbeelding voor nieuwsbrief',button:{text:'Afbeelding gebruiken'},multiple:false});frame.on('select',function(){var a=frame.state().get('selection').first().toJSON();box.find('.rvaz-builder-image-placeholder,.rvaz-builder-image').remove();box.append('<img class="rvaz-builder-image" src="'+$('<div>').text(a.url).html()+'" alt="">');});frame.open();}).on('click','[data-edit-button]',function(e){e.preventDefault();var a=$(this),label=window.prompt('Tekst op de knop',a.text());if(label===null)return;var url=window.prompt('Link van de knop',a.attr('href')==='#'?'https://':a.attr('href'));if(url===null)return;a.text(label).attr('href',url);});
 var dragging=null;$('#rvaz-canvas').on('dragstart','.rvaz-builder-item',function(e){dragging=this;e.originalEvent.dataTransfer.effectAllowed='move';}).on('dragover','.rvaz-builder-item',function(e){e.preventDefault();if(!dragging||dragging===this)return;var r=this.getBoundingClientRect();if(e.originalEvent.clientY<r.top+r.height/2)this.parentNode.insertBefore(dragging,this);else this.parentNode.insertBefore(dragging,this.nextSibling);}).on('dragend','.rvaz-builder-item',function(){dragging=null;});
 $('#rvaz-compose-form').on('submit',function(){if($('#rvaz-template-type').val()!=='free-builder')return;var c=$('<div>');$('#rvaz-canvas .rvaz-builder-item').each(function(){var n=$(this).clone();n.removeAttr('draggable').removeClass('rvaz-builder-item');n.find('.rvaz-builder-remove').remove();n.find('[contenteditable]').removeAttr('contenteditable').removeClass('rvaz-builder-edit');n.find('[data-edit-button]').removeAttr('data-edit-button');n.find('.rvaz-builder-cols').attr('style','display:table;width:100%;table-layout:fixed').removeClass('rvaz-builder-cols');n.find('.rvaz-builder-col').attr('style','display:table-cell;width:50%;padding:10px;vertical-align:top').removeClass('rvaz-builder-col');n.find('.rvaz-builder-image').removeClass('rvaz-builder-image').attr('style','max-width:100%;height:auto;display:block;margin:auto');c.append(n.html());});var html=c.html();var e=ed();if(e)e.setContent(html);$('#rvaz_custom_content').val(html);});
 var b=$('#rvaz-load-template'),sel=$('#rvaz-template');b.on('click',function(){var html='',subject='';if(sel.val()==='app-testers'){html=<?php echo wp_json_encode($app_tpl); ?>;subject='Help mee de RVAZ-app voor Android te testen';$('#rvaz-template-type').val('app-testers');}else if(sel.val()==='app-apple-android'){html=<?php echo wp_json_encode($app_apple_android_tpl); ?>;subject='De RVAZ-app is nu beschikbaar voor iPhone en iPad';$('#rvaz-template-type').val('app-apple-android');}else if(sel.val()==='wonen-makelaars'){html=<?php echo wp_json_encode($makelaars_tpl); ?>;subject='Nieuw: RVAZ Wonen voor makelaars op Voorne aan Zee';$('#rvaz-template-type').val('wonen-makelaars');$('#rvaz-target-list').val('Makelaars');$('#rvaz-subject').val(subject);$('#rvaz-compose-form input[name=include_donation]').prop('checked',false);}else return;var e=ed();if(e)e.setContent(html);else $('#rvaz_custom_content').val(html);if(!$('#rvaz-subject').val())$('#rvaz-subject').val(subject);});
 $('#rvaz-insert-wonen').on('click',function(){insert(<?php echo wp_json_encode($wonen_block); ?>);});$('#rvaz-insert-app-banner').on('click',function(){insert(<?php echo wp_json_encode($app_banner); ?>);});$('#rvaz-insert-apology').on('click',function(){insert(<?php echo wp_json_encode($apology_block); ?>);});$('#rvaz-insert-note').on('click',function(){insert(<?php echo wp_json_encode($note_block); ?>);});
 })(jQuery);</script></div><?php }
 public function custom_save(){
  if(!current_user_can('manage_options')||!check_admin_referer('rvaz_nl_custom_save'))wp_die('Geen toegang');
  global $wpdb;$list=sanitize_text_field(wp_unslash($_POST['target_list']??''));$subject=sanitize_text_field(wp_unslash($_POST['subject']??''));$body=wp_kses_post(wp_unslash($_POST['content_html']??''));
  $template_type=sanitize_key(wp_unslash($_POST['template_type']??''));
  if(!empty($_POST['send_test_to_me'])){
   if($subject===''||trim(wp_strip_all_tags($body))==='')wp_die('Vul eerst het onderwerp en de inhoud van de nieuwsbrief in.');
   $user=wp_get_current_user();$email=sanitize_email($user->user_email??'');if(!$email)wp_die('Bij je huidige WordPress-account is geen geldig e-mailadres ingesteld.');
   $site=get_bloginfo('name');$donation=!empty($_POST['include_donation'])?$this->donation_email_html():'';
   if(in_array($template_type,['app-testers','app-apple-android','wonen-makelaars'],true)){$html=$body.$donation.'<p style="max-width:680px;margin:12px auto;font-family:Arial,sans-serif;font-size:11px;color:#687386;text-align:center">'.($template_type==='wonen-makelaars'?'Eenmalige zakelijke aankondiging. Je bent niet ingeschreven voor onze nieuwsbrief.':'Dit is een testmail via '.esc_html($site).'.').' {{unsubscribe}}</p>';}
   else{$logo_id=absint($this->opt('logo_id',0));$logo=$logo_id?$this->attachment_image_url($logo_id,'full'):$this->public_image_url($this->opt('logo_url',''));$brand=$logo?'<img src="'.esc_url($logo).'" alt="'.esc_attr($site).'" style="display:block;max-height:70px;max-width:420px;width:auto;height:auto;margin:0 auto">':'<strong style="font-size:20px">'.esc_html($site).'</strong>';$html='<div style="max-width:680px;margin:auto;font-family:Arial,sans-serif;color:#10233f;line-height:1.5;background:#fff"><div style="background:#064b7c;color:#fff;padding:16px 20px;text-align:center">'.$brand.'</div><div style="padding:20px">'.$body.$donation.'<p style="margin-top:24px;font-size:11px;color:#687386">Dit is een testmail via '.esc_html($site).'. {{unsubscribe}}</p></div></div>';}
   $ok=$this->send_to($email,'',true,null,0,0,$subject,$html);$msg=$ok?'Testmail verzonden naar '.$email.'. Er is niets naar een verzendlijst verzonden.':'Testmail kon niet worden verzonden naar '.$email.'. Controleer de mailinstellingen.';
   wp_safe_redirect(add_query_arg(['page'=>'rvaz-newsletter-compose','rvaz_nl_msg'=>rawurlencode($msg)],admin_url('admin.php')));exit;
  }
  $template_type=sanitize_key(wp_unslash($_POST['template_type']??''));$has_content=trim(wp_strip_all_tags($body))!==''||($template_type==='free-builder'&&stripos($body,'<img')!==false);if($list===''||$subject===''||!$has_content)wp_die('Verzendlijst, onderwerp en inhoud zijn verplicht.');
  $subs=$wpdb->get_results("SELECT id,email,unsub_token,lists FROM {$this->table()} WHERE status='confirmed' ORDER BY id ASC");$subs=array_values(array_filter($subs,function($sub)use($list){$ls=array_map('trim',preg_split('/[,;]+/',(string)$sub->lists));return in_array($list,$ls,true);}));
  if(!$subs)wp_die('Deze verzendlijst bevat geen actieve ontvangers.');
  $site=get_bloginfo('name');$template_type=sanitize_key(wp_unslash($_POST['template_type']??''));$donation=!empty($_POST['include_donation'])?$this->donation_email_html():'';if(in_array($template_type,['app-testers','app-apple-android','wonen-makelaars'],true)){$html=$body.$donation.'<p style="max-width:680px;margin:12px auto;font-family:Arial,sans-serif;font-size:11px;color:#687386;text-align:center">'.($template_type==='wonen-makelaars'?'Eenmalige zakelijke aankondiging. Je bent niet ingeschreven voor onze nieuwsbrief.':'Je ontvangt deze nieuwsbrief via '.esc_html($site).'.').' {{unsubscribe}}</p>';}else{$logo_id=absint($this->opt('logo_id',0));$logo=$logo_id?$this->attachment_image_url($logo_id,'full'):$this->public_image_url($this->opt('logo_url',''));$brand=$logo?'<img src="'.esc_url($logo).'" alt="'.esc_attr($site).'" style="display:block;max-height:70px;max-width:420px;width:auto;height:auto;margin:0 auto">':'<strong style="font-size:20px">'.esc_html($site).'</strong>';$html='<div style="max-width:680px;margin:auto;font-family:Arial,sans-serif;color:#10233f;line-height:1.5;background:#fff"><div style="background:#064b7c;color:#fff;padding:16px 20px;text-align:center">'.$brand.'</div><div style="padding:20px">'.$body.$donation.'<p style="margin-top:24px;font-size:11px;color:#687386">Je ontvangt deze nieuwsbrief via '.esc_html($site).'. {{unsubscribe}}</p></div></div>'; }
  $ok=$wpdb->insert($this->mailings_table(),['subject'=>$subject,'sent_at'=>current_time('mysql'),'sent_count'=>0,'total_count'=>count($subs),'failed_count'=>0,'status'=>'paused','cursor_id'=>0,'post_ids'=>'[]','content_html'=>$html,'window_started_at'=>current_time('mysql'),'window_sent'=>0,'mailing_type'=>'custom','target_list'=>$list,'include_donation'=>!empty($_POST['include_donation'])?1:0]);
  if(!$ok)wp_die('Nieuwsbrief kon niet worden opgeslagen.');$mid=(int)$wpdb->insert_id;$rt=$this->recipients_table();foreach($subs as $sub)$wpdb->query($wpdb->prepare("INSERT IGNORE INTO $rt (mailing_id,subscriber_id,email,unsub_token,status) VALUES (%d,%d,%s,%s,'pending')",$mid,(int)$sub->id,(string)$sub->email,(string)$sub->unsub_token));
  wp_safe_redirect(add_query_arg(['page'=>'rvaz-newsletter-stats','mailing'=>$mid,'rvaz_nl_msg'=>rawurlencode('Nieuwsbrief opgeslagen als gepauzeerd concept voor lijst ‘'.$list.'’. Er is niets verzonden. Controleer de mailing en klik alleen op Verzending hervatten wanneer je echt wilt verzenden.')],admin_url('admin.php')));exit;
 }

 private function app_tester_data(){
  $api=(array)get_option('rvaz_app_api_settings',[]);
  $signup=trim((string)($api['tester_form_page']??$api['tester_url']??''));
  if($signup==='')$signup=trim((string)$this->opt('app_tester_url',''));
  if($signup==='')$signup=home_url('/test-de-rvaz-app/');
  $play=trim((string)($api['play_test_url']??''));
  if($play==='')$play=trim((string)$this->opt('app_play_test_url',''));
  if($play==='')$play='https://play.google.com/apps/internaltest/4700540275930678035';
  return ['signup'=>$signup,'play'=>$play];
 }
 private function app_tester_banner_email_html(){
  $d=$this->app_tester_data();$signup=$d['signup'];
  if($signup==='')$signup=home_url('/test-de-rvaz-app/');
  $apple=trim((string)$this->opt('app_store_url','https://apps.apple.com/us/app/regio-voorne-aan-zee/id6817375521'));if($apple==='')$apple='https://apps.apple.com/us/app/regio-voorne-aan-zee/id6817375521';
  $h='<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:14px 0 16px;background:#ffffff;border:1px solid #dce5eb;border-radius:10px"><tr><td style="padding:12px 14px">';
  $h.='<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>';
  $h.='<td valign="middle" width="50%" style="padding:5px 12px 5px 2px"><table role="presentation" cellpadding="0" cellspacing="0"><tr><td valign="middle" style="font-size:26px;line-height:1;padding-right:9px;color:#111">🍎</td><td><div style="font-size:13px;font-weight:bold;color:#10233f">RVAZ voor iPhone &amp; iPad</div><div style="font-size:11px;color:#65758b;margin-top:2px">Nu vrij te downloaden</div></td></tr></table><div style="margin-top:8px"><a href="'.esc_url($apple).'" style="display:inline-block;background:#111;color:#fff;padding:8px 13px;border-radius:6px;text-decoration:none;font-size:12px;font-weight:bold">Download in de App Store</a></div></td>';
  $h.='<td valign="middle" width="50%" style="padding:5px 2px 5px 14px;border-left:1px solid #e5e7eb"><table role="presentation" cellpadding="0" cellspacing="0"><tr><td valign="middle" style="font-size:23px;line-height:1;padding-right:9px;color:#3ddc84">&#9679;</td><td><div style="font-size:13px;font-weight:bold;color:#10233f">RVAZ voor Android</div><div style="font-size:11px;color:#65758b;margin-top:2px">Verplichte Google Play-test</div></td></tr></table><div style="margin-top:8px"><a href="'.esc_url($signup).'" style="display:inline-block;background:#0877b9;color:#fff;padding:8px 13px;border-radius:6px;text-decoration:none;font-size:12px;font-weight:bold">Aanmelden als tester</a></div></td>';
  return $h.'</tr></table></td></tr></table>';
 }
 private function extra_notes_email_html(){
  $raw=trim((string)$this->opt('extra_notes',''));if($raw==='')return '';
  $parts=preg_split('/\R\s*---\s*\R/', $raw);$html='';
  foreach((array)$parts as $part){$part=trim($part);if($part==='')continue;$html.='<div style="margin:16px 0;padding:16px 18px;background:#f3f7fa;border:1px solid #dce5eb;border-left:5px solid #0877b9;border-radius:8px;font-size:13px;color:#40536b">'.nl2br(esc_html($part)).'</div>';}
  return $html;
 }
 private function apology_email_html(){
  $title=$this->opt('apology_title','Onze excuses voor de extra nieuwsbrieven');$body=$this->opt('apology_body','Door de vernieuwing van Regio Voorne aan Zee is ons nieuwsbriefsysteem tijdelijk in de war geraakt. Daardoor zijn sommige nieuwsbrieven vaker verzonden dan wij zelf wilden. Onze excuses voor het ongemak. We hebben dit inmiddels aangepakt.');$sig=$this->opt('apology_signature','Rudy de Jonge');
  return '<div style="margin:16px 0;padding:16px 18px;background:#fff7e8;border:1px solid #f0d59d;border-left:5px solid #e2a72e;border-radius:8px"><strong style="color:#073b63">'.esc_html($title).'</strong><p style="margin:6px 0 0;font-size:13px;color:#40536b">'.nl2br(esc_html($body)).'</p>'.($sig!==''?'<p style="margin:12px 0 0;font-size:13px;color:#073b63;font-weight:bold">'.esc_html($sig).'</p>':'').'</div>';
 }
 public function app_tester_link_shortcode($atts=[]){
  $d=$this->app_tester_data();$play=$d['play'];$signup=$d['signup'];
  $url=$play!==''?$play:$signup;
  if($url==='')return '';
  $label=$play!==''?'Test de Android-app via Google Play':'Aanmelden als app-tester';
  return '<a class="rvaz-app-tester-link" href="'.esc_url($url).'" target="_blank" rel="noopener noreferrer">'.esc_html($label).'</a>';
 }

 private function wonen_makelaars_template_html(){
  $header=plugins_url('assets/rvaz-header.png',__FILE__);
  return '<div style="max-width:680px;margin:0 auto;font-family:Arial,Helvetica,sans-serif;line-height:1.6;color:#203253;background:#fff;border:1px solid #dce5eb">'
   .'<img src="'.esc_url($header).'" alt="Regio Voorne aan Zee" width="680" style="width:100%;max-width:680px;height:auto;display:block;border:0;border-bottom:4px solid #00a8d7">'
   .'<div style="padding:24px 18px">'
   .'<p style="margin:0 0 8px;font-size:12px;font-weight:bold;color:#0877b9">EENMALIGE UITNODIGING VOOR MAKELAARS</p>'
   .'<h1 style="font-size:27px;line-height:1.25;margin:0 0 16px;color:#073b63">Uw woningaanbod op Voorne aan Zee.<br>Via onze website én app.</h1>'
   .'<p style="margin:0 0 14px">Beste makelaar,</p>'
   .'<p style="margin:0 0 18px">Met <strong>RVAZ Wonen</strong> presenteert u koopwoningen, huurwoningen en kamers aan woningzoekers uit de regio. Uw aanbod is te bekijken op <strong>regiovoorneaanzee.nl</strong> én via onze <strong>veel gedownloade RVAZ-app</strong>.</p>'
   .'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#edf6fb;border:1px solid #dce5eb;border-radius:8px"><tr><td style="padding:18px">'
   .'<h2 style="font-size:18px;margin:0 0 10px;color:#073b63">Eén account, eenvoudig beheren</h2>'
   .'<p style="margin:0;font-size:14px">✓ Woningen plaatsen en bewerken via <strong>website én app</strong><br>✓ Foto’s en woningkenmerken beheren<br>✓ Reacties van woningzoekers bekijken in Mijn Wonen<br>✓ Uw abonnement en facturen op één plek</p></td></tr></table>'
   .'<h2 style="font-size:20px;margin:24px 0 8px;color:#073b63">Probeer RVAZ Wonen met introductiekorting</h2>'
   .'<p style="margin:0 0 16px">Nieuwe makelaarskantoren krijgen normaal <strong>50% korting op de eerste abonnementsmaand</strong>. Voor de <strong>eerste twee verschillende makelaarskantoren</strong> is die maand helemaal gratis met de code hieronder.</p>'
   .'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 16px;background:#f2faff;border:2px dashed #0877b9;border-radius:8px"><tr><td style="padding:18px;text-align:center">'
   .'<div style="font-size:14px;font-weight:bold;color:#36516e">&#127915; UW KORTINGSCODE</div>'
   .'<strong style="display:block;margin:6px 0;font-size:29px;letter-spacing:2px;color:#073b63">MAKELAAR</strong>'
   .'<div style="font-size:17px;font-weight:bold;color:#073b63">Eerste maand € 0,00</div>'
   .'<div style="font-size:13px;color:#40536b;margin-top:6px">Voor Basis, Plus en Pro · maximaal 2 kantoren · zolang beschikbaar</div></td></tr></table>'
   .'<h2 style="font-size:18px;margin:22px 0 8px;color:#073b63">Zo wisselt u de korting in</h2>'
   .'<ol style="padding-left:22px;margin:0 0 18px;font-size:14px">'
   .'<li style="margin-bottom:9px">Klik op <strong>Aanmelden als makelaar</strong>. Log in of maak een RVAZ-account aan.</li>'
   .'<li style="margin-bottom:9px">Ga naar <strong>Mijn Wonen → Makelaar aanmelden</strong> en kies <strong>Basis, Plus of Pro</strong>.</li>'
   .'<li style="margin-bottom:9px">Vul <strong>MAKELAAR</strong> in bij <strong>Kortingscode</strong>. Controleer vóór het versturen dat de eerste-maandprijs <strong>€ 0,00</strong> is. Is de code opgebruikt, dan geldt de normale introductieaanbieding zonder code.</li>'
   .'<li>Verstuur uw aanvraag en volg de bevestiging en beoordeling. Daarna beheert u uw aanbod via <strong>Mijn Wonen op de website én in de RVAZ-app</strong>.</li></ol>'
   .'<p style="margin:0 0 18px;font-size:12px;color:#56667a">De code geldt alleen voor de eerste abonnementsmaand van een nieuw makelaarskantoor en is niet stapelbaar met de 50%-introductiekorting. <strong>Vanaf maand twee geldt het normale maandtarief.</strong> U kunt uw abonnement op ieder moment eenvoudig opzeggen via <strong>Mijn Wonen</strong>.</p>'
   .'<p style="margin:20px 0 10px"><a href="https://www.regiovoorneaanzee.nl/wonen-voor-makelaars/" style="display:inline-block;background:#0877b9;color:#fff;padding:13px 18px;border-radius:6px;font-weight:bold;font-size:14px;text-decoration:none">Aanmelden als makelaar</a></p>'
   .'<p style="margin:0 0 24px;font-size:14px"><a href="https://www.regiovoorneaanzee.nl/wonen-tarieven/" style="color:#0877b9;font-weight:bold;text-decoration:underline">Bekijk pakketten en tarieven</a></p>'
   .'<p style="margin:0 0 20px">Met vriendelijke groet,<br><strong>Regio Voorne aan Zee</strong></p>'
   .'<div style="padding-top:14px;border-top:1px solid #dce5eb;font-size:12px;color:#56667a"><strong>Eenmalige aankondiging</strong><br>Deze uitnodiging schrijft uw kantoor niet in voor de reguliere nieuwsbrief. Er volgen hierdoor geen automatische reguliere nieuwsbrieven.</div>'
   .'</div></div>';
 }
 private function refresh_wonen_drafts(){
  // Only the old, never-sent Wonen invitation. Keep recipients, counters and pause intact.
  global $wpdb;$table=$this->mailings_table();
  $rows=$wpdb->get_results("SELECT id,content_html FROM $table WHERE status='paused' AND sent_count=0 AND failed_count=0 AND mailing_type='custom' AND target_list='Makelaars' AND subject='Nieuw: RVAZ Wonen voor makelaars op Voorne aan Zee'");
  foreach((array)$rows as $row){
   if(strpos((string)$row->content_html,'Nieuw: RVAZ Wonen op Voorne aan Zee')===false||strpos((string)$row->content_html,'MAKELAAR')===false)continue;
   $html=$this->wonen_makelaars_template_html().'<p style="max-width:680px;margin:12px auto;font-family:Arial,sans-serif;font-size:11px;color:#687386;text-align:center">Eenmalige zakelijke aankondiging. Je bent niet ingeschreven voor onze nieuwsbrief. {{unsubscribe}}</p>';
   $wpdb->update($table,['content_html'=>$html],['id'=>(int)$row->id,'status'=>'paused','sent_count'=>0,'failed_count'=>0,'target_list'=>'Makelaars']);
  }
 }
 private function wonen_email_html(){
  return '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:20px 0;background:#edf6fb;border:1px solid #c9e2ee;border-radius:8px"><tr><td style="padding:18px">'
   .'<p style="margin:0 0 6px;font-size:12px;font-weight:bold;color:#0877b9">&#127968; RVAZ WONEN</p>'
   .'<h2 style="margin:0 0 10px;font-size:21px;line-height:1.25;color:#073b63">Wonen op Voorne</h2>'
   .'<p style="margin:0 0 12px;font-size:14px">Een koopwoning, huurwoning of kamer vinden in Voorne aan Zee? Bekijk het lokale aanbod van <strong>makelaars én particulieren</strong> op onze website en in onze <strong>veel gedownloade RVAZ-app</strong>.</p>'
   .'<p style="margin:0 0 14px;font-size:13px">Zelf een woning of kamer aanbieden? Particulieren plaatsen en beheren hun advertentie en reacties via <strong>Mijn account → Mijn Wonen</strong>. Makelaars beheren hun woningaanbod via <strong>Mijn Wonen op de website én in de app</strong>.</p>'
   .'<p style="margin:0 0 10px"><a href="'.esc_url(home_url('/wonen/')).'" style="display:inline-block;background:#0877b9;color:#fff;padding:11px 16px;border-radius:5px;font-size:14px;font-weight:bold;text-decoration:none">Bekijk het woningaanbod</a></p>'
   .'<p style="margin:0;font-size:13px"><a href="'.esc_url(home_url('/mijn-account/?rvaz_wonen=particulier')).'" style="color:#0877b9">Zelf een woning aanbieden</a> · <a href="'.esc_url(home_url('/wonen-voor-makelaars/')).'" style="color:#0877b9">Voor makelaars</a></p>'
   .'</td></tr></table>';
 }

 private function app_tester_template_html(){
  $d=$this->app_tester_data();$signup=$d['signup'];$play=$d['play'];
  $header=plugins_url('assets/rvaz-header.png',__FILE__);
  $html='<div style="max-width:680px;margin:0 auto;font-family:Arial,sans-serif;color:#10233f;line-height:1.5;background:#fff;border:1px solid #dce5eb">';
  $html.='<div style="background:#fff;border-bottom:4px solid #0aa7df"><img src="'.esc_url($header).'" alt="Regio Voorne aan Zee – Onze regio. Ons verhaal." width="680" style="display:block;width:100%;max-width:680px;height:auto;border:0"></div>';
  $html.='<div style="padding:24px 24px 10px"><div style="font-size:12px;font-weight:bold;letter-spacing:1.5px;text-transform:uppercase;color:#0877b9;margin-bottom:8px">Uitnodiging · Android-app test</div><h1 style="font-size:28px;line-height:1.18;margin:0 0 12px;color:#10233f">Test als eerste de nieuwe RVAZ-app</h1><p style="font-size:16px;margin:0 0 20px">De nieuwe Regio Voorne aan Zee-app komt eraan. Voor de bredere uitrol zoeken we mensen uit de regio die nieuws, agenda, P2000, Weekblad, pushmeldingen en de andere onderdelen alvast willen testen.</p>';
  $html.='<div style="margin:18px 0;padding:20px;background:#fff8df;border:2px solid #e6c24b;border-radius:10px"><div style="font-size:12px;font-weight:bold;letter-spacing:1px;color:#775d00;text-transform:uppercase">Met RVAZ-account</div><h2 style="font-size:21px;margin:5px 0 7px;color:#10233f">🎁 Test mee en maak kans op een cadeaubon</h2><p style="font-size:14px;margin:0 0 13px">Wil je ook kans maken op <strong>1 van 5 bol.com-waardebonnen van €25</strong>? Log dan in op je RVAZ-account en meld je aan als tester met hetzelfde e-mailadres. Zo kunnen we je deelname registreren en een eventuele winnaar bereiken.</p>';
  if($signup!=='')$html.='<div style="text-align:center"><a href="'.esc_url($signup).'" style="display:inline-block;background:#064b7c;color:#fff;padding:13px 20px;border-radius:7px;text-decoration:none;font-size:15px;font-weight:bold">INLOGGEN &amp; MEEDOEN VOOR DE CADEAUBON →</a></div>';
  $html.='</div>';
  $html.='<div style="margin:22px 0;padding:22px;background:#eaf8ff;border:3px solid #0aa7df;border-radius:10px"><div style="display:inline-block;background:#0aa7df;color:#fff;padding:5px 9px;border-radius:999px;font-size:11px;font-weight:bold;letter-spacing:.5px">OOK ZONDER ACCOUNT</div><h2 style="font-size:22px;margin:9px 0 7px;color:#073b63">👋 Geen RVAZ-account? Je kunt gewoon meedoen!</h2><p style="font-size:15px;margin:0 0 12px"><strong>Een RVAZ-account is niet verplicht om de app te testen.</strong> Wil je alleen helpen om de app beter te maken? Dan kun je de testversie gebruiken en feedback doorgeven zonder een RVAZ-account aan te maken. Je hoeft hiervoor geen RVAZ-account te hebben. Meld je eerst aan als app-tester met het Google-account waarmee je de app wilt installeren.</p><p style="font-size:13px;margin:0 0 15px;color:#40536b">Alleen deelname aan de cadeaubonactie is gekoppeld aan een RVAZ-account.</p>';
  $html.='<div style="text-align:center"><a href="'.esc_url($signup).'" style="display:inline-block;background:#079a61;color:#fff;padding:13px 22px;border-radius:7px;text-decoration:none;font-size:16px;font-weight:bold">MELD JE AAN ALS APP-TESTER →</a></div>';
  if($play!=='')$html.='<p style="font-size:12px;margin:12px 0 0;color:#526b80;text-align:center">Al toegelaten tot de interne Google Play-test? <a href="'.esc_url($play).'">Open dan hier de test in Google Play</a>.</p>';
  else $html.='<div style="padding:12px 14px;background:#fff;border:1px solid #b9e4f5;border-radius:7px;font-size:13px;color:#40536b"><strong>De Google Play-testlink is nog geblokkeerd.</strong><br>Zodra Google de interne test heeft vrijgegeven, wordt hier de echte testlink gebruikt. We tonen nooit een verzonnen downloadlink.</div>';
  $html.='</div>';
  $html.='<div style="margin:18px 0;padding:18px;background:#f3f7fa;border:1px solid #dce5eb;border-radius:8px"><strong style="font-size:18px;color:#10233f">Via Google Play — updates gaan vanzelf</strong><p style="font-size:14px;margin:7px 0 0">Je installeert de testversie via Google Play. Nieuwe testversies worden daarna via Google Play aangeboden, net als updates van andere apps.</p></div>';
  $html.='<h2 style="font-size:20px;margin:26px 0 12px;color:#10233f">Wat kun je testen?</h2><p style="font-size:14px;margin-top:0">Nieuws lezen, lokale berichten openen, P2000 en pushmeldingen controleren, de agenda bekijken, het Weekblad gebruiken en feedback geven. Zie je iets dat niet werkt, ontbreekt er informatie of kan iets makkelijker? Laat het ons weten.</p>';
  $html.='<div style="margin:24px 0;padding:18px;background:#eef5f9;border-left:4px solid #0877b9;border-radius:7px"><strong style="font-size:17px">Android-test</strong><p style="font-size:14px;margin:5px 0 0">Deze testronde is voor Android-telefoons en -tablets. Meld je aan met het Google-account waarmee je wilt testen. Zodra dat account tot de interne Google Play-test is toegelaten, kun je de app via Google Play installeren. Een Google-account is iets anders dan een RVAZ-account.</p></div>';
  $html.='<div style="margin:26px 0 8px;padding:18px;background:#f3f7fa;border-radius:8px;text-align:center"><strong style="font-size:17px">Jouw feedback helpt ons de RVAZ-app beter te maken voor heel Voorne aan Zee.</strong></div></div>';
  $html.='<div style="padding:14px 22px;background:#064b7c;color:#fff;text-align:center;font-size:11px">Regio Voorne aan Zee · lokaal nieuws, dicht bij huis</div></div>';
  return $html;
 }

 private function app_apple_android_template_html(){
  $d=$this->app_tester_data();$signup=$d['signup'];
  if($signup==='')$signup=home_url('/test-de-rvaz-app/');
  $apple=trim((string)$this->opt('app_store_url','https://apps.apple.com/us/app/regio-voorne-aan-zee/id6817375521'));if($apple==='')$apple='https://apps.apple.com/us/app/regio-voorne-aan-zee/id6817375521';
  $header=plugins_url('assets/rvaz-header.png',__FILE__);
  $html='<div style="max-width:680px;margin:0 auto;font-family:Arial,sans-serif;color:#10233f;line-height:1.5;background:#fff;border:1px solid #dce5eb">';
  $html.='<div style="background:#fff;border-bottom:4px solid #0aa7df"><img src="'.esc_url($header).'" alt="Regio Voorne aan Zee – Onze regio. Ons verhaal." width="680" style="display:block;width:100%;max-width:680px;height:auto;border:0"></div>';
  $html.='<div style="padding:26px 24px 10px;text-align:center"><div style="font-size:12px;font-weight:bold;letter-spacing:1.4px;text-transform:uppercase;color:#0877b9;margin-bottom:8px">De RVAZ-app</div><h1 style="font-size:29px;line-height:1.15;margin:0 0 12px;color:#10233f">Regio Voorne aan Zee nu ook op iPhone en iPad</h1><p style="font-size:16px;margin:0 auto 22px;max-width:590px;color:#40536b">Goed nieuws: de RVAZ-app is nu voor iedereen vrij te downloaden via de Apple App Store. Voor Android loopt nog de verplichte Google Play-test en daarvoor zoeken we testers.</p></div>';
  $html.='<div style="padding:0 24px 24px"><table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td valign="top" width="50%" style="padding:6px"><div style="height:100%;padding:22px 18px;background:#f5f5f7;border:1px solid #d9d9df;border-radius:12px;text-align:center"><div style="font-size:38px;line-height:1">🍎</div><div style="font-size:12px;font-weight:bold;letter-spacing:1px;text-transform:uppercase;color:#555;margin-top:9px">iPhone &amp; iPad</div><h2 style="font-size:21px;line-height:1.2;margin:7px 0;color:#10233f">Nu vrij te downloaden</h2><p style="font-size:13px;color:#526b80;margin:0 0 16px">Download de officiële Regio Voorne aan Zee-app direct vanuit de Apple App Store.</p><a href="'.esc_url($apple).'" style="display:inline-block;background:#111;color:#fff;padding:12px 17px;border-radius:8px;text-decoration:none;font-size:14px;font-weight:bold"> Download in de App Store</a></div></td><td valign="top" width="50%" style="padding:6px"><div style="height:100%;padding:22px 18px;background:#eaf8ff;border:1px solid #b9e4f5;border-radius:12px;text-align:center"><div style="font-size:38px;line-height:1">▶️</div><div style="font-size:12px;font-weight:bold;letter-spacing:1px;text-transform:uppercase;color:#0877b9;margin-top:9px">Android</div><h2 style="font-size:21px;line-height:1.2;margin:7px 0;color:#073b63">Word Android-tester</h2><p style="font-size:13px;color:#526b80;margin:0 0 16px">Voor Google Play geldt nog de verplichte testfase. Meld je aan en help ons de Android-versie te testen.</p><a href="'.esc_url($signup).'" style="display:inline-block;background:#079a61;color:#fff;padding:12px 17px;border-radius:8px;text-decoration:none;font-size:14px;font-weight:bold">Aanmelden als Android-tester →</a></div></td></tr></table>';
  $html.='<div style="margin:20px 6px 4px;padding:18px;background:#f3f7fa;border-left:4px solid #0877b9;border-radius:8px"><strong style="font-size:17px;color:#073b63">Eén app voor Regio Voorne aan Zee</strong><p style="font-size:14px;margin:6px 0 0;color:#40536b">Blijf op de hoogte van lokaal nieuws en gebruik de onderdelen van Regio Voorne aan Zee ook gemakkelijk onderweg.</p></div></div>';
  $html.='<div style="padding:14px 22px;background:#064b7c;color:#fff;text-align:center;font-size:11px">Regio Voorne aan Zee · Onze regio. Ons verhaal.</div></div>';
  return $html;
 }

 public function migrate_page(){if(!current_user_can('manage_options'))return;global $wpdb;$known=[];$vals=$wpdb->get_col("SELECT lists FROM {$this->table()} WHERE lists IS NOT NULL AND lists<>''");foreach((array)$vals as $v){foreach(preg_split('/[,;]+/',(string)$v) as $x){$x=trim($x);if($x!=='')$known[$x]=1;}}ksort($known,SORT_NATURAL|SORT_FLAG_CASE);?>
 <div class="wrap"><h1>Abonnees importeren / exporteren</h1><?php $this->notice(); ?><h2>Importeer CSV</h2><p>Kies vóór het importeren in welke verzendlijst de adressen moeten komen. Je kunt een bestaande lijst kiezen of direct een nieuwe lijstnaam invullen. Importeren start <strong>nooit</strong> een verzending.</p><form enctype="multipart/form-data" method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>"><input type="hidden" name="action" value="rvaz_nl_import"><?php wp_nonce_field('rvaz_nl_import'); ?><table class="form-table"><tr><th><label for="rvaz-import-list">Verzendlijst</label></th><td><select id="rvaz-import-list" name="target_list"><option value="">— Kies verzendlijst —</option><?php foreach(array_keys($known) as $list): ?><option value="<?php echo esc_attr($list); ?>"><?php echo esc_html($list); ?></option><?php endforeach; ?></select> <span>of nieuwe lijst:</span> <input name="new_target_list" class="regular-text" placeholder="bijv. Bedrijven Voorne aan Zee"><p class="description">Bestaande lijsten van een abonnee blijven behouden. Uitgeschreven adressen worden niet opnieuw geactiveerd.</p></td></tr><tr><th>CSV-bestand</th><td><input type="file" name="csv" accept=".csv,text/csv" required></td></tr></table><?php submit_button('Importeren in gekozen lijst'); ?></form><hr><h2>Exporteren</h2><form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>"><input type="hidden" name="action" value="rvaz_nl_export"><?php wp_nonce_field('rvaz_nl_export'); ?><button class="button">Exporteer RVAZ-abonnees als CSV</button></form></div><?php }
 private function delimiter($line){return substr_count($line,';')>substr_count($line,',')?';':',';}
 public function import(){
  if(!current_user_can('manage_options')||!check_admin_referer('rvaz_nl_import'))wp_die('Geen toegang');
  if(empty($_FILES['csv']['tmp_name']))wp_die('Geen CSV');
  $target=sanitize_text_field(wp_unslash($_POST['new_target_list']??''));if($target==='')$target=sanitize_text_field(wp_unslash($_POST['target_list']??''));if($target==='')wp_die('Kies of maak eerst een verzendlijst.');$lists=$this->known_lists();if(!in_array($target,$lists,true)){$lists[]=$target;$this->save_lists($lists);}
  $fh=fopen($_FILES['csv']['tmp_name'],'r');$first=fgets($fh);rewind($fh);$d=$this->delimiter($first);
  $h=array_map(function($x){return strtolower(trim(preg_replace('/[^a-z0-9_]+/i','_',trim($x," \t\n\r\0\x0B\xEF\xBB\xBF"))));},fgetcsv($fh,0,$d));
  $map=function($names)use($h){foreach($names as $n){$i=array_search($n,$h,true);if($i!==false)return $i;}return false;};
  $ei=$map(['email','email_address','e_mail']);$fi=$map(['first_name','name','voornaam']);$li=$map(['last_name','surname','achternaam']);if($ei===false)wp_die('Geen e-mailkolom gevonden.');
  global $wpdb;$n=0;$skipped=0;
  while(($r=fgetcsv($fh,0,$d))!==false){
   $email=sanitize_email($r[$ei]??'');if(!$email){$skipped++;continue;}
   $existing=$wpdb->get_row($wpdb->prepare("SELECT * FROM {$this->table()} WHERE email=%s",$email));
   if($existing){
    $lists=array_values(array_filter(array_map('trim',preg_split('/[,;]+/',(string)$existing->lists))));if(!in_array($target,$lists,true))$lists[]=$target;
    $data=['lists'=>implode(', ',array_unique($lists))];
    if($fi!==false && !empty($r[$fi]))$data['first_name']=sanitize_text_field($r[$fi]);if($li!==false && !empty($r[$li]))$data['last_name']=sanitize_text_field($r[$li]);
    $wpdb->update($this->table(),$data,['id'=>(int)$existing->id]);
   }else{
    $wpdb->insert($this->table(),['email'=>$email,'first_name'=>sanitize_text_field($fi!==false?($r[$fi]??''):''),'last_name'=>sanitize_text_field($li!==false?($r[$li]??''):''),'status'=>'confirmed','lists'=>$target,'consent_at'=>null,'created_at'=>current_time('mysql'),'unsub_token'=>wp_generate_password(40,false,false)]);
   }
   $n++;
  }
  fclose($fh);
  wp_safe_redirect(add_query_arg('rvaz_nl_msg',rawurlencode("$n adressen geïmporteerd in lijst ‘$target’. Er is geen verzending gestart."),admin_url('admin.php?page=rvaz-newsletter-migrate')));exit;
 }
 public function export(){if(!current_user_can('manage_options')||!check_admin_referer('rvaz_nl_export'))wp_die('Geen toegang'); global $wpdb;$rows=$wpdb->get_results("SELECT email,first_name,last_name,status,lists,consent_at,created_at FROM {$this->table()} ORDER BY id",ARRAY_A); nocache_headers();header('Content-Type:text/csv; charset=utf-8');header('Content-Disposition:attachment; filename=rvaz-abonnees-'.gmdate('Y-m-d').'.csv');$f=fopen('php://output','w');fputcsv($f,array_keys($rows[0]??['email'=>'','first_name'=>'','last_name'=>'','status'=>'','lists'=>'','consent_at'=>'','created_at'=>'']),';');foreach($rows as $r)fputcsv($f,$r,';');fclose($f);exit;}
 private function abs_img($url){$url=trim((string)$url);if(!$url)return '';if(strpos($url,'//')===0)$url='https:'.$url;elseif(strpos($url,'/')===0)$url=home_url($url);elseif(!preg_match('~^https?://~i',$url))$url=home_url('/'.ltrim($url,'/'));return set_url_scheme($url,'https');}
 private function owned_ad($position){if(!function_exists('rvaz_advertentie_get_email_slot'))return '';return (string)rvaz_advertentie_get_email_slot($position);}
 private function rvaz_ad_shortcode($key,$position){$code=trim((string)$this->opt($key,''));if(!$code)$code='[rvaz_advertentie_email position="'.esc_attr($position).'"]';if(strpos($code,'[rvaz_advertentie_email')===false)return '';if(shortcode_exists('rvaz_advertentie_email'))return trim(do_shortcode($code));return $this->owned_ad($position);}
 private function fresh_posts(){ $count=max(1,min(20,absint($this->opt('post_count',6)))); $sent=array_map('absint',(array)get_option('rvaz_nl_sent_posts',[])); return get_posts(['post_type'=>'post','post_status'=>'publish','numberposts'=>$count,'post__not_in'=>$sent,'orderby'=>'date','order'=>'DESC']); }
 private function pro_companies($limit=3){
  $q=new WP_Query(['post_type'=>'rvaz_bedrijf','post_status'=>'publish','posts_per_page'=>-1,'orderby'=>'ID','order'=>'ASC','no_found_rows'=>true]);$all=[];
  while($q->have_posts()){$q->the_post();$id=get_the_ID();$plan=strtolower((string)get_post_meta($id,'_rvaz_plan',true));if($plan!=='pro')continue;$until=get_post_meta($id,'_rvaz_pro_until',true);$until_ts=is_numeric($until)?(int)$until:($until?strtotime($until):0);if($until_ts && $until_ts<current_time('timestamp'))continue;$all[]=$id;}wp_reset_postdata();
  if(!$all)return [];$offset=(int)get_option('rvaz_nl_company_offset',0);$out=[];$take=min(max(1,(int)$limit),count($all));for($i=0;$i<$take;$i++)$out[]=$all[($offset+$i)%count($all)];return $out;
 }
 private function events($limit=5){
  if(!post_type_exists('rvaz_event'))return [];
  try{
   $out=[];$today=current_time('Y-m-d');$today_ts=strtotime($today.' 00:00:00');
   /* Haal ruimer op: terugkerende evenementen kunnen een oorspronkelijke startdatum in het verleden hebben. */
   $q=new WP_Query(['post_type'=>'rvaz_event','post_status'=>'publish','posts_per_page'=>100,'orderby'=>'meta_value','meta_key'=>'_rvaz_event_start_date','order'=>'ASC','no_found_rows'=>true,'ignore_sticky_posts'=>true]);
   foreach($q->posts as $e){
    if(!($e instanceof WP_Post))continue;
    $d=(string)get_post_meta($e->ID,'_rvaz_event_start_date',true);if(!$d)continue;
    $repeat=(string)get_post_meta($e->ID,'_rvaz_event_repeat',true);$event_ts=strtotime($d.' 00:00:00');if(!$event_ts)continue;
    $next_ts=$event_ts;
    if($next_ts<$today_ts){
     if($repeat==='weekly'){while($next_ts<$today_ts)$next_ts=strtotime('+1 week',$next_ts);}
     elseif($repeat==='biweekly'){while($next_ts<$today_ts)$next_ts=strtotime('+2 weeks',$next_ts);}
     elseif($repeat==='monthly'){while($next_ts<$today_ts)$next_ts=strtotime('+1 month',$next_ts);}
     else continue;
    }
    $st=(string)get_post_meta($e->ID,'_rvaz_event_start_time',true);$et=(string)get_post_meta($e->ID,'_rvaz_event_end_time',true);
    $loc=(string)get_post_meta($e->ID,'_rvaz_event_location',true);$price=(string)get_post_meta($e->ID,'_rvaz_event_price',true);
    $rep=['weekly'=>'Elke week','biweekly'=>'Elke 2 weken','monthly'=>'Elke maand'];
    $date=date_i18n('j F Y',$next_ts);if($st)$date.=' · '.substr($st,0,5).($et?'–'.substr($et,0,5):'');
    $extra=array_values(array_filter([$loc,$price,isset($rep[$repeat])?$rep[$repeat]:'']));
    $url=get_permalink($e->ID);if(!$url)continue;
    $out[]=['title'=>get_the_title($e->ID),'url'=>$url,'date'=>$date.($extra?' · '.implode(' · ',$extra):''),'sort'=>$next_ts];
   }
   wp_reset_postdata();usort($out,function($a,$b){return $a['sort']<=>$b['sort'];});return array_slice($out,0,max(1,(int)$limit));
  }catch(\Throwable $e){return [];}
 }
 public function track_open(){global $wpdb;$m=absint($_GET['m']??0);$s=absint($_GET['s']??0);if($m&&$s){$exists=$wpdb->get_var($wpdb->prepare("SELECT id FROM {$this->events_table()} WHERE mailing_id=%d AND subscriber_id=%d AND event_type='open' LIMIT 1",$m,$s));if(!$exists)$wpdb->insert($this->events_table(),['mailing_id'=>$m,'subscriber_id'=>$s,'event_type'=>'open','created_at'=>current_time('mysql')],['%d','%d','%s','%s']);}nocache_headers();header('Content-Type:image/gif');echo base64_decode('R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==');exit;}
 public function track_click(){global $wpdb;$m=absint($_GET['m']??0);$s=absint($_GET['s']??0);$u=base64_decode(rawurldecode(wp_unslash($_GET['u']??'')),true);if(!$u||!wp_http_validate_url($u))$u=home_url('/');if($m&&$s)$wpdb->insert($this->events_table(),['mailing_id'=>$m,'subscriber_id'=>$s,'event_type'=>'click','url'=>esc_url_raw($u),'region'=>$this->region_from_ip(),'created_at'=>current_time('mysql')],['%d','%d','%s','%s','%s','%s']);wp_redirect($u,302);exit;}
 private function tracked_html($html,$mailing_id,$subscriber_id){
  $mailing_id=absint($mailing_id);$subscriber_id=absint($subscriber_id);$html=(string)$html;
  if(!$mailing_id)return $html;
  $html=preg_replace_callback('/<a\b([^>]*?)href=(["\'])(.*?)\2([^>]*)>/i',function($m)use($mailing_id,$subscriber_id){
   $url=html_entity_decode($m[3],ENT_QUOTES,'UTF-8');
   if(!$url || strpos($url,'mailto:')===0 || strpos($url,'tel:')===0 || strpos($url,'#')===0)return $m[0];
   $track=add_query_arg(['action'=>'rvaz_nl_click','m'=>$mailing_id,'s'=>$subscriber_id,'u'=>rawurlencode(base64_encode($url))],admin_url('admin-post.php'));
   return '<a'.$m[1].'href='.$m[2].esc_url($track).$m[2].$m[4].'>';
  },$html);
  $pixel=add_query_arg(['action'=>'rvaz_nl_open','m'=>$mailing_id,'s'=>$subscriber_id],admin_url('admin-post.php'));
  $img='<img src="'.esc_url($pixel).'" width="1" height="1" alt="" style="display:block;width:1px;height:1px;border:0;overflow:hidden">';
  if(stripos($html,'</body>')!==false)$html=preg_replace('/<\/body>/i',$img.'</body>',$html,1);else $html.=$img;
  return $html;
 }
 private function region_from_ip(){
  /* Privacy-first: do not retain or infer a precise region without a configured geo provider. */
  return '';
 }
 private function public_image_url($url){
  $url=trim((string)$url);if(!$url)return '';
  if(strpos($url,'//')===0)$url='https:'.$url;
  if(strpos($url,'http://')===0 && is_ssl())$url='https://'.substr($url,7);
  return esc_url_raw($url);
 }
 private function attachment_image_url($attachment_id,$size='full'){
  $attachment_id=absint($attachment_id);if(!$attachment_id)return '';
  $img=wp_get_attachment_image_url($attachment_id,$size);
  if(!$img && $size!=='full')$img=wp_get_attachment_image_url($attachment_id,'full');
  return $this->public_image_url($img?:'');
 }
 private function post_image_src($post_id,$size='medium'){
  $post_id=absint($post_id);if(!$post_id)return '';
  $thumb=get_post_thumbnail_id($post_id);
  if($thumb){$img=$this->attachment_image_url($thumb,$size);if($img)return $img;}
  $content=(string)get_post_field('post_content',$post_id);
  if($content && preg_match('/<img[^>]+src=["\']([^"\']+)["\']/i',$content,$m))return $this->public_image_url($m[1]);
  return '';
 }
 private function donation_email_html(){
  $o=(array)get_option('rvaz_donaties_options',[]);$url=esc_url_raw(trim((string)($o['tikkie_url']??'')));if(!$url)return '';
  $expiry=sanitize_text_field((string)($o['expiry_date']??''));if($expiry && preg_match('/^\d{4}-\d{2}-\d{2}$/',$expiry)){try{$dt=new DateTimeImmutable($expiry.' 23:59:59',wp_timezone());if($dt->getTimestamp()<current_time('timestamp'))return '';}catch(\Throwable $e){return '';}}
  $title=sanitize_text_field((string)($o['title']??'Steun Regio Voorne aan Zee'));$text=wp_kses_post((string)($o['text']??'Help ons lokaal nieuws gratis toegankelijk te houden.'));$button=sanitize_text_field((string)($o['button']??'Doneer via Tikkie'));
  return '<!-- RVAZ_DONATION_BLOCK --><table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:22px 0;background:#f3f7fa;border:1px solid #dce5eb;border-radius:8px"><tr><td style="padding:20px;text-align:center"><strong style="font-size:18px;color:#10233f">'.esc_html($title).'</strong><div style="font-size:13px;line-height:1.55;color:#40536b;margin:8px 0 14px">'.wp_kses_post($text).'</div><a href="'.esc_url($url).'" target="_blank" rel="noopener noreferrer nofollow" style="display:inline-block;background:#e52329;color:#fff;padding:11px 18px;border-radius:6px;text-decoration:none;font-weight:bold">'.esc_html($button).'</a><div style="font-size:10px;color:#687386;margin-top:10px">Vrijwillige bijdrage · het nieuws blijft gratis toegankelijk.</div></td></tr></table>';
 }
 private function inject_donation_html($html){
  $html=(string)$html;
  if($html==='' || strpos($html,'RVAZ_DONATION_BLOCK')!==false)return $html;
  $don=$this->donation_email_html();if($don==='')return $html;
  /* Voeg alleen toe vlak vóór de bestaande nieuwsbrief-footer; vervang nooit de nieuwsbriefinhoud. */
  $footer='Je ontvangt deze nieuwsbrief';
  $pos=strpos($html,$footer);
  if($pos!==false){
   $pstart=strrpos(substr($html,0,$pos),'<p');
   if($pstart!==false)return substr($html,0,$pstart).$don.substr($html,$pstart);
  }
  $close=strripos($html,'</div></div>');
  if($close!==false)return substr($html,0,$close).$don.substr($html,$close);
  return $html.$don;
 }
 private function prepare_public_images($html){
  return preg_replace_callback('/(<img\b[^>]*\bsrc=["\'])([^"\']+)(["\'])/i',function($m){
   $u=$this->public_image_url(html_entity_decode($m[2],ENT_QUOTES,'UTF-8'));return $m[1].esc_url($u).$m[3];
  },(string)$html);
 }
 private function newsletter_html($preview=false,$posts=null){if($posts===null)$posts=$this->fresh_posts();$site=get_bloginfo('name');$intro=$this->opt('intro','Het laatste nieuws uit Voorne aan Zee, overzichtelijk in je mailbox.');$logo_id=absint($this->opt('logo_id',0));$logo=$logo_id?$this->attachment_image_url($logo_id,'full'):$this->public_image_url($this->opt('logo_url',''));$brand=$logo?'<img src="'.esc_url($logo).'" alt="'.esc_attr($site).'" style="display:block;max-height:48px;max-width:190px;width:auto;height:auto;margin:0 0 7px">':'<h1 style="margin:0;font-size:22px">'.esc_html($site).'</h1>';$header=plugins_url('assets/rvaz-header.png',__FILE__);$html='<div style="max-width:680px;margin:auto;font-family:Arial,sans-serif;color:#10233f;line-height:1.4;background:#fff"><div style="background:#fff;border-bottom:4px solid #0aa7df"><img src="'.esc_url($header).'" alt="Regio Voorne aan Zee – Onze regio. Ons verhaal." width="680" style="display:block;width:100%;max-width:680px;height:auto;border:0"><div style="background:#073b63;color:#fff;padding:8px 20px;font-size:12px">Nieuwsbrief · '.esc_html(wp_date('j F Y')).'</div></div><div style="padding:20px"><p style="margin-top:0;color:#526b80">'.esc_html($intro).'</p>'.(get_option('rvaz_nl_apology_pending','1')==='1'?$this->apology_email_html():'').$this->app_tester_banner_email_html().$this->extra_notes_email_html().$this->rvaz_ad_shortcode('rvaz_ad_top','newsletter-top');$i=0;if(!$posts)$html.='<p><strong>Vandaag zijn er geen nieuwe, nog niet eerder verzonden nieuwsberichten.</strong></p>';foreach($posts as $p){$i++;$url=get_permalink($p);$img=$this->post_image_src($p->ID,'medium');$html.='<div style="display:block;padding:12px 0;border-bottom:1px solid #e5e7eb">';if($img)$html.='<a href="'.esc_url($url).'" style="float:left;width:120px;margin:0 14px 8px 0"><img src="'.esc_url($img).'" alt="" style="width:120px;height:78px;object-fit:cover;border-radius:6px;display:block"></a>';$html.='<div style="font-size:11px;color:#65758b">'.esc_html(get_the_date('j F Y · H:i',$p)).'</div><h2 style="font-size:17px;line-height:1.2;margin:3px 0 5px"><a style="color:#10233f;text-decoration:none" href="'.esc_url($url).'">'.esc_html(get_the_title($p)).'</a></h2><p style="font-size:13px;margin:0">'.esc_html(wp_trim_words(get_the_excerpt($p),18)).'</p><div style="clear:both"></div></div>';if($i===3)$html.=$this->rvaz_ad_shortcode('rvaz_ad_middle','newsletter-middle');}
 $companies=$this->pro_companies(3);if($companies){$html.='<div style="margin:16px 0;padding:14px;background:#f3f7fa;border-radius:8px"><h2 style="font-size:17px;margin:0 0 4px">Lokale Pro-bedrijven</h2><p style="font-size:11px;color:#65758b;margin:0 0 10px">Een wisselende selectie van ondernemers uit Voorne aan Zee.</p>';foreach($companies as $id){$logo_id=(int)get_post_meta($id,'_rvaz_logo_id',true);$logo=$logo_id?$this->attachment_image_url($logo_id,'thumbnail'):$this->post_image_src($id,'thumbnail');$places=wp_get_post_terms($id,'rvaz_bedrijf_plaats',['fields'=>'names']);$cats=wp_get_post_terms($id,'rvaz_bedrijf_cat',['fields'=>'names']);$meta=trim(($cats[0]??'Lokaal bedrijf').' · '.($places[0]??'Voorne aan Zee'),' ·');$html.='<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 8px;background:#fff;border:1px solid #dce5eb;border-radius:7px"><tr>';if($logo)$html.='<td width="64" style="padding:8px"><img src="'.esc_url($logo).'" alt="" width="48" height="48" style="display:block;width:48px;height:48px;object-fit:contain"></td>';$html.='<td style="padding:8px"><a href="'.esc_url(get_permalink($id)).'" style="font-weight:700;color:#064b7c;text-decoration:none;font-size:13px">'.esc_html(get_the_title($id)).'</a><div style="font-size:11px;color:#65758b;margin-top:2px">'.esc_html($meta).'</div></td><td width="72" style="padding:8px;text-align:right"><a href="'.esc_url(get_permalink($id)).'" style="display:inline-block;background:#064b7c;color:#fff;padding:6px 8px;border-radius:5px;text-decoration:none;font-size:10px;font-weight:bold">Bekijk</a></td></tr></table>';}$html.='</div>';}else{$html.='<!-- Geen actieve, gepubliceerde Pro-bedrijven gevonden -->';}
 $html.=$this->wonen_email_html();
 $events=$this->events(5);if($events){$event_count=count($events);$event_heading=$event_count===1?'1 evenement om naar uit te kijken':$event_count.' evenementen om naar uit te kijken';$html.='<div style="margin:18px 0"><h2 style="font-size:18px;margin-bottom:8px">'.esc_html($event_heading).'</h2>';foreach($events as $e)$html.='<div style="padding:7px 0;border-bottom:1px solid #e5e7eb"><span style="font-size:11px;color:#65758b">'.esc_html($e['date']).'</span><br><a href="'.esc_url($e['url']).'" style="font-weight:bold;color:#064b7c;text-decoration:none">'.esc_html($e['title']).'</a></div>';$html.='</div>';}
 $html.='<div style="margin:18px 0;padding:18px;background:#f3f7fa;border:1px solid #dce5eb;border-radius:8px;text-align:center"><strong style="font-size:17px">Gratis RVAZ-account</strong><p style="font-size:13px;margin:6px 0 10px">Maak gratis een account aan en haal meer uit Regio Voorne aan Zee.</p><div style="font-size:12px;line-height:1.7;margin-bottom:12px">✓ Volg nieuws uit jouw favoriete plaatsen en onderwerpen<br>✓ Bewaar artikelen om later terug te lezen<br>✓ Reageer op nieuws en beheer je reacties<br>✓ Stuur nieuwstips in en beheer je eigen evenementen</div><a href="'.esc_url(home_url('/registreren/')).'" style="display:inline-block;background:#064b7c;color:#fff;padding:10px 15px;border-radius:5px;text-decoration:none;font-weight:bold">Gratis account aanmaken</a></div>';
 $html.='<div style="margin:18px 0;padding:16px;background:#eef5f9;text-align:center"><strong>Ondernemer in Voorne aan Zee?</strong><p style="font-size:13px;margin:5px 0 10px">Maak je eigen bedrijfspagina in de RVAZ-bedrijvengids.</p><a href="'.esc_url(home_url('/bedrijf-registreren/')).'" style="display:inline-block;background:#e52329;color:#fff;padding:10px 15px;border-radius:5px;text-decoration:none;font-weight:bold">Bedrijfspagina maken</a></div>';
 $wa=trim((string)$this->opt('whatsapp_url',get_theme_mod('rvaz_whatsapp_url','')));if($wa && $this->opt('whatsapp_enabled','1')){$html.='<div style="margin:16px 0;padding:14px 16px;background:#eaf8ef;border:1px solid #bfe8cb;border-radius:8px"><table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td width="48" valign="middle"><div style="width:38px;height:38px;line-height:38px;border-radius:50%;background:#25D366;color:#fff;text-align:center;font-size:20px;font-weight:bold">☎</div></td><td valign="middle"><strong style="font-size:15px;color:#103f2b">RVAZ op WhatsApp</strong><div style="font-size:12px;color:#355c49;margin-top:2px">Ontvang het laatste lokale nieuws rechtstreeks via ons WhatsApp-kanaal.</div></td><td width="92" valign="middle" align="right"><a href="'.esc_url($wa).'" style="display:inline-block;background:#128C7E;color:#fff;padding:9px 12px;border-radius:6px;text-decoration:none;font-weight:bold;font-size:12px">Lid worden</a></td></tr></table></div>';}
 $html.=$this->rvaz_ad_shortcode('rvaz_ad_bottom','newsletter-bottom');$html.='<p style="margin-top:18px;font-size:11px;color:#687386">Je ontvangt deze nieuwsbrief omdat je je hebt ingeschreven bij '.esc_html($site).'. {{unsubscribe}}</p></div></div>';return $html;}
 public function mail_failed($error){
  if(empty($GLOBALS['rvaz_nl_sending']) || !is_wp_error($error))return;
  $msg=$error->get_error_message();if($msg)set_transient('rvaz_nl_last_mail_error',sanitize_text_field($msg),10*MINUTE_IN_SECONDS);
 }
 private function send_to($email,$token='',$test=false,$posts=null,$mailing_id=0,$subscriber_id=0,$subject_override='',$html_override=''){$subject=$subject_override!==''?$subject_override:str_replace('{date}',wp_date('j F Y'),$this->opt('subject','Het laatste nieuws van {date}'));$html=$html_override!==''?$html_override:$this->newsletter_html(false,$posts);$u=add_query_arg(['action'=>'rvaz_nl_unsubscribe','email'=>rawurlencode($email),'token'=>$token],admin_url('admin-post.php'));$html=str_replace('{{unsubscribe}}',$test?'Uitschrijflink wordt in de echte nieuwsbrief toegevoegd.':'<a href="'.esc_url($u).'">Uitschrijven</a>',$html);if(!$test)$html=$this->tracked_html($html,$mailing_id,$subscriber_id);$html=$this->prepare_public_images($html);$headers=['Content-Type: text/html; charset=UTF-8'];$from=$this->opt('from_email');$name=$this->opt('from_name',get_bloginfo('name'));if(is_email($from))$headers[]='From: '.$name.' <'.$from.'>'; $reply=$this->opt('reply_to'); if(is_email($reply))$headers[]='Reply-To: '.$reply;$GLOBALS['rvaz_nl_sending']=true;$ok=wp_mail($email,$subject,$html,$headers);$GLOBALS['rvaz_nl_sending']=false;return $ok;}
 private function active_mailing(){
 global $wpdb;$table=$this->mailings_table();$this->ensure_queue_schema();
 /* Ruim legacy wachtrijen op die administratief actief zijn maar feitelijk klaar/leeg zijn. */
 $wpdb->query("UPDATE $table SET status='completed',completed_at=COALESCE(completed_at,NOW()) WHERE status IN ('queued','sending') AND total_count>0 AND sent_count+failed_count>=total_count");
 $wpdb->query("UPDATE $table SET status='cancelled',completed_at=COALESCE(completed_at,NOW()) WHERE status IN ('queued','sending') AND total_count=0");
 /* Nieuwste echte actieve verzending heeft voorrang; oude foutrecords blokkeren hem niet meer. */
 return $wpdb->get_row("SELECT * FROM $table WHERE status IN ('queued','sending','paused') AND total_count>0 AND sent_count+failed_count<total_count ORDER BY id DESC LIMIT 1");
}
 private function create_mailing($include_donation=false){
  global $wpdb;if($this->active_mailing())return 0;$this->ensure_queue_schema();$this->ensure_recipients_schema();
  $posts=$this->fresh_posts();$ids=array_map('absint',wp_list_pluck($posts,'ID'));
  $subject=str_replace('{date}',wp_date('j F Y'),$this->opt('subject','Het laatste nieuws van {date}'));
  $subs=$wpdb->get_results("SELECT id,email,unsub_token FROM {$this->table()} WHERE status='confirmed' AND TRIM(COALESCE(lists,'')) <> 'Makelaars' ORDER BY id ASC");
  $total=count($subs);
  if($total<1){set_transient('rvaz_nl_last_queue_error','Er zijn geen actieve bevestigde abonnees gevonden.',5*MINUTE_IN_SECONDS);return 0;}
  $content=$this->newsletter_html(false,$posts);if($include_donation)$content=$this->inject_donation_html($content);
  $ok=$wpdb->insert($this->mailings_table(),['subject'=>$subject,'sent_at'=>current_time('mysql'),'sent_count'=>0,'total_count'=>$total,'failed_count'=>0,'status'=>'queued','cursor_id'=>0,'post_ids'=>wp_json_encode($ids),'content_html'=>$content,'window_started_at'=>current_time('mysql'),'window_sent'=>0,'include_donation'=>$include_donation?1:0],['%s','%s','%d','%d','%d','%s','%d','%s','%s','%s','%d','%d']);
  if($ok===false){$detail=$wpdb->last_error?sanitize_text_field($wpdb->last_error):'Onbekende databasefout bij het aanmaken van de verzendwachtrij.';set_transient('rvaz_nl_last_queue_error',$detail,5*MINUTE_IN_SECONDS);return 0;}
  $mid=(int)$wpdb->insert_id;$rt=$this->recipients_table();
  foreach(array_chunk($subs,200) as $chunk)foreach($chunk as $sub)$wpdb->query($wpdb->prepare("INSERT IGNORE INTO $rt (mailing_id,subscriber_id,email,unsub_token,status) VALUES (%d,%d,%s,%s,'pending')",$mid,(int)$sub->id,(string)$sub->email,(string)$sub->unsub_token));
  $snap=(int)$wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $rt WHERE mailing_id=%d",$mid));
  if($snap!==$total){$wpdb->delete($rt,['mailing_id'=>$mid],['%d']);$wpdb->delete($this->mailings_table(),['id'=>$mid],['%d']);set_transient('rvaz_nl_last_queue_error','De volledige ontvangerslijst kon niet veilig worden vastgelegd.',5*MINUTE_IN_SECONDS);return 0;}
  delete_transient('rvaz_nl_last_queue_error');update_option('rvaz_nl_apology_pending','0',false);return $mid;
 }
 private function mailing_posts($mailing){$ids=json_decode((string)$mailing->post_ids,true);$ids=array_values(array_filter(array_map('absint',(array)$ids)));if(!$ids)return [];$posts=get_posts(['post_type'=>'post','post_status'=>'publish','post__in'=>$ids,'orderby'=>'post__in','numberposts'=>count($ids)]);return $posts;}
 private function finish_mailing($mailing,$posts){global $wpdb;$this->revoke_mailing_authorization($mailing->id);$wpdb->update($this->mailings_table(),['status'=>'completed','completed_at'=>current_time('mysql')],['id'=>$mailing->id],['%s','%s'],['%d']);if((int)$mailing->sent_count>0 || $posts){$sent=array_map('absint',(array)get_option('rvaz_nl_sent_posts',[]));$sent=array_values(array_unique(array_merge($sent,wp_list_pluck($posts,'ID'))));update_option('rvaz_nl_sent_posts',array_slice($sent,-2000));update_option('rvaz_nl_company_offset',(int)get_option('rvaz_nl_company_offset',0)+4);update_option('rvaz_nl_last_sent',current_time('mysql'));}}
 private function authorize_mailing($id){update_option('rvaz_nl_authorized_mailing',absint($id),false);}
 private function revoke_mailing_authorization($id=0){$authorized=absint(get_option('rvaz_nl_authorized_mailing',0));if(!$id || $authorized===absint($id))delete_option('rvaz_nl_authorized_mailing');}
 private function is_mailing_authorized($id){return absint($id)>0 && absint(get_option('rvaz_nl_authorized_mailing',0))===absint($id);}
 private function schedule_next_worker($delay=self::CHUNK_DELAY){
  $delay=max(5,(int)$delay);$next=wp_next_scheduled('rvaz_nl_queue_worker');$wanted=time()+$delay;
  if(!$next || $next>$wanted+15){if($next)wp_clear_scheduled_hook('rvaz_nl_queue_worker');wp_schedule_single_event($wanted,'rvaz_nl_queue_worker');}
 }
 public function worker_tick(){
  $m=$this->active_mailing();
  if($m && $m->status!=='paused' && $this->is_mailing_authorized($m->id)){ $this->schedule_next_worker(10); $this->queue_worker(); }
 }
 public function queue_worker(){
  if(get_transient('rvaz_nl_batch_lock'))return;set_transient('rvaz_nl_batch_lock',1,5*MINUTE_IN_SECONDS);
  global $wpdb;$mailing=$this->active_mailing();if(!$mailing || $mailing->status==='paused' || !$this->is_mailing_authorized($mailing->id)){delete_transient('rvaz_nl_batch_lock');return;}
  $now=current_time('timestamp');
  /* 20 pogingen per 90 seconden = maximaal 800 per uur; de uurgrens hieronder is extra beveiliging. */
  if(!empty($mailing->last_batch_at)){
   $last=strtotime($mailing->last_batch_at);
   if($last && ($now-$last)<self::CHUNK_DELAY){$this->schedule_next_worker(max(5,self::CHUNK_DELAY-($now-$last)+2));delete_transient('rvaz_nl_batch_lock');return;}
  }$window_start=$mailing->window_started_at?strtotime($mailing->window_started_at):0;$window_sent=(int)$mailing->window_sent;
  if(!$window_start || ($now-$window_start)>=HOUR_IN_SECONDS){$window_start=$now;$window_sent=0;$wpdb->update($this->mailings_table(),['window_started_at'=>current_time('mysql'),'window_sent'=>0],['id'=>$mailing->id],['%s','%d'],['%d']);}
  $allowance=max(0,self::BATCH_LIMIT-$window_sent);if($allowance<1){$wait=max(60,HOUR_IN_SECONDS-($now-$window_start)+5);$this->schedule_next_worker($wait);delete_transient('rvaz_nl_batch_lock');return;}
  $limit=min(self::CHUNK_SIZE,$allowance);$wpdb->update($this->mailings_table(),['status'=>'sending','last_batch_at'=>current_time('mysql')],['id'=>$mailing->id],['%s','%s'],['%d']);
  $this->ensure_recipients_schema();$rt=$this->recipients_table();
  /* Zorg dat iedere actieve bevestigde abonnee in de snapshot staat; bestaande sent-rijen blijven onaangeroerd. */
  list($snap_total,$snap_sent,$snap_failed,$snap_pending)=$this->sync_mailing_recipients((int)$mailing->id);
  $wpdb->update($this->mailings_table(),['total_count'=>$snap_total,'sent_count'=>$snap_sent,'failed_count'=>$snap_failed],['id'=>(int)$mailing->id],['%d','%d','%d'],['%d']);
  $rows=$wpdb->get_results($wpdb->prepare("SELECT id,subscriber_id,email,unsub_token,attempt_count FROM $rt WHERE mailing_id=%d AND status='pending' AND (next_attempt_at IS NULL OR next_attempt_at<=%s) ORDER BY id ASC LIMIT %d",(int)$mailing->id,current_time('mysql'),$limit));
  $posts=$this->mailing_posts($mailing);$html=(string)$mailing->content_html;if($html==='')$html=$this->newsletter_html(false,$posts);if(!empty($mailing->include_donation))$html=$this->inject_donation_html($html);$ok=0;$fail=0;$cursor=(int)$mailing->cursor_id;
  foreach($rows as $r){
   $cursor=(int)$r->id;$attempt=(int)$r->attempt_count+1;
   delete_transient('rvaz_nl_last_mail_error');
   $sent=$this->send_to($r->email,$r->unsub_token,false,$posts,(int)$mailing->id,(int)$r->subscriber_id,(string)$mailing->subject,$html);
   if($sent){$ok++;$wpdb->update($rt,['status'=>'sent','sent_at'=>current_time('mysql'),'error_text'=>null,'attempt_count'=>$attempt,'next_attempt_at'=>null],['id'=>(int)$r->id],['%s','%s','%s','%d','%s'],['%d']);}
   else{
    $err=(string)get_transient('rvaz_nl_last_mail_error');if($err==='')$err='wp_mail retourneerde false';
    if($attempt>=3){$fail++;$wpdb->update($rt,['status'=>'failed','error_text'=>$err,'attempt_count'=>$attempt,'next_attempt_at'=>null],['id'=>(int)$r->id],['%s','%s','%d','%s'],['%d']);}
    else{$retry=wp_date('Y-m-d H:i:s',current_time('timestamp')+(5*MINUTE_IN_SECONDS));$wpdb->update($rt,['status'=>'pending','error_text'=>$err,'attempt_count'=>$attempt,'next_attempt_at'=>$retry],['id'=>(int)$r->id],['%s','%s','%d','%s'],['%d']);}
   }
  }
  $attempted=count($rows);$wpdb->query($wpdb->prepare("UPDATE {$this->mailings_table()} SET sent_count=sent_count+%d,failed_count=failed_count+%d,cursor_id=%d,window_sent=window_sent+%d WHERE id=%d",$ok,$fail,$cursor,$attempted,(int)$mailing->id));
  list($snap_total,$snap_sent,$snap_failed,$remaining)=$this->sync_mailing_recipients((int)$mailing->id);
  $wpdb->update($this->mailings_table(),['total_count'=>$snap_total,'sent_count'=>$snap_sent,'failed_count'=>$snap_failed],['id'=>(int)$mailing->id],['%d','%d','%d'],['%d']);
  if($snap_total>0 && $remaining===0 && ($snap_sent+$snap_failed)===$snap_total){$mailing=$wpdb->get_row($wpdb->prepare("SELECT * FROM {$this->mailings_table()} WHERE id=%d",$mailing->id));$this->finish_mailing($mailing,$posts);wp_clear_scheduled_hook('rvaz_nl_queue_worker');}else{/* Niet voltooien zolang er nog snapshot-ontvangers pending zijn. */$this->schedule_next_worker(self::CHUNK_DELAY+2);}
  delete_transient('rvaz_nl_batch_lock');
 }
 public function delete_mailing(){
  if(!current_user_can('manage_options'))wp_die('Geen toegang');
  $id=absint($_POST['mailing_id']??0);check_admin_referer('rvaz_nl_delete_mailing_'.$id);if(!$id)wp_die('Ongeldige nieuwsbrief.');
  global $wpdb;$mt=$this->mailings_table();$et=$this->events_table();$rt=$this->recipients_table();
  $row=$wpdb->get_row($wpdb->prepare("SELECT id,status FROM $mt WHERE id=%d",$id));
  if(!$row)wp_die('Nieuwsbrief niet gevonden.');
  if(in_array($row->status,['queued','sending'],true))wp_die('Deze nieuwsbrief wordt momenteel verzonden. Pauzeer de verzending eerst voordat je hem verwijdert.');
  $this->revoke_mailing_authorization($id);$wpdb->delete($rt,['mailing_id'=>$id],['%d']);$wpdb->delete($et,['mailing_id'=>$id],['%d']);$wpdb->delete($mt,['id'=>$id],['%d']);
  delete_transient('rvaz_nl_batch_lock');
  wp_safe_redirect(add_query_arg('rvaz_nl_msg',rawurlencode('Nieuwsbrief en bijbehorende statistieken definitief verwijderd.'),admin_url('admin.php?page=rvaz-newsletter-stats')));exit;
 }
 public function kick_worker(){if(!current_user_can('manage_options'))wp_die('Geen toegang');$id=absint($_POST['mailing_id']??0);check_admin_referer('rvaz_nl_kick_'.$id);global $wpdb;$row=$wpdb->get_row($wpdb->prepare("SELECT id,status,total_count,sent_count,failed_count FROM {$this->mailings_table()} WHERE id=%d",$id));if(!$row||!in_array($row->status,['queued','sending'],true))wp_die('Deze nieuwsbrief is niet actief.');if(!$this->is_mailing_authorized($id))wp_die('Verzending is niet geautoriseerd. Klik eerst bewust op Verzending hervatten.');delete_transient('rvaz_nl_batch_lock');wp_clear_scheduled_hook('rvaz_nl_queue_worker');wp_schedule_single_event(time()+5,'rvaz_nl_queue_worker');if(!wp_next_scheduled('rvaz_nl_worker_tick'))wp_schedule_event(time()+30,'rvaz_nl_minute','rvaz_nl_worker_tick');wp_safe_redirect(add_query_arg(['page'=>'rvaz-newsletter-stats','mailing'=>$id,'rvaz_nl_msg'=>rawurlencode('Verzendworker opnieuw gestart. Reeds verzonden ontvangers worden overgeslagen.')],admin_url('admin.php')));exit;}
 public function pause_mailing(){if(!current_user_can('manage_options'))wp_die('Geen toegang');$id=absint($_POST['mailing_id']??0);check_admin_referer('rvaz_nl_pause_'.$id);global $wpdb;$this->revoke_mailing_authorization($id);$wpdb->query($wpdb->prepare("UPDATE {$this->mailings_table()} SET status='paused' WHERE id=%d AND status IN ('queued','sending')",$id));wp_clear_scheduled_hook('rvaz_nl_queue_worker');wp_safe_redirect(add_query_arg('rvaz_nl_msg',rawurlencode('Verzending gepauzeerd. De resterende ontvangers krijgen niets totdat je hervat.'),admin_url('admin.php?page=rvaz-newsletter')));exit;}
 public function resume_mailing(){if(!current_user_can('manage_options'))wp_die('Geen toegang');$id=absint($_POST['mailing_id']??0);check_admin_referer('rvaz_nl_resume_'.$id);global $wpdb;$updated=$wpdb->query($wpdb->prepare("UPDATE {$this->mailings_table()} SET status='queued' WHERE id=%d AND status='paused'",$id));if($updated===false)wp_die('De nieuwsbrief kon niet in de verzendwachtrij worden gezet.');$this->authorize_mailing($id);if(!wp_next_scheduled('rvaz_nl_worker_tick'))wp_schedule_event(time()+10,'rvaz_nl_minute','rvaz_nl_worker_tick');if(!wp_next_scheduled('rvaz_nl_queue_worker'))wp_schedule_single_event(time()+5,'rvaz_nl_queue_worker');delete_transient('rvaz_nl_batch_lock');wp_safe_redirect(add_query_arg(['page'=>'rvaz-newsletter-stats','mailing'=>$id,'rvaz_nl_msg'=>rawurlencode('Verzending gestart. De eerste batch wordt op de achtergrond verwerkt; ververs Statistieken om de voortgang te volgen.')],admin_url('admin.php')));exit;}
 public function edit_mailing(){if(!current_user_can('manage_options'))wp_die('Geen toegang');$id=absint($_POST['mailing_id']??0);check_admin_referer('rvaz_nl_edit_'.$id);$subject=sanitize_text_field(wp_unslash($_POST['subject']??''));$html=wp_kses_post(wp_unslash($_POST['content_html']??''));global $wpdb;$row=$wpdb->get_row($wpdb->prepare("SELECT status FROM {$this->mailings_table()} WHERE id=%d",$id));if($row&&in_array($row->status,['queued','sending','paused'],true))$wpdb->update($this->mailings_table(),['subject'=>$subject,'content_html'=>$html],['id'=>$id],['%s','%s'],['%d']);wp_safe_redirect(add_query_arg(['page'=>'rvaz-newsletter-stats','mailing'=>$id,'rvaz_nl_msg'=>rawurlencode('Wijzigingen opgeslagen. Ze gelden voor de resterende ontvangers.')],admin_url('admin.php')));exit;}
 public function repair_queue(){
  if(!current_user_can('manage_options'))wp_die('Geen toegang');check_admin_referer('rvaz_nl_repair_queue');
  global $wpdb;$m=$this->active_mailing();if(!$m){$msg='Er is geen actieve verzendwachtrij.';}
  else{
   $this->ensure_recipients_schema();$rt=$this->recipients_table();$et=$this->events_table();
   if(($m->mailing_type??'')==='custom' && !empty($m->target_list)){
    $all=$wpdb->get_results("SELECT id,email,unsub_token,lists FROM {$this->table()} WHERE status='confirmed' ORDER BY id ASC");
    $subs=array_values(array_filter((array)$all,function($sub)use($m){
     $names=array_map('trim',preg_split('/[,;]+/',(string)$sub->lists));
     return in_array((string)$m->target_list,$names,true);
    }));
   } else {
    $subs=$wpdb->get_results("SELECT id,email,unsub_token FROM {$this->table()} WHERE status='confirmed' AND TRIM(COALESCE(lists,'')) <> 'Makelaars' ORDER BY id ASC");
   }
   $total=count($subs);
   if($total<1){$msg='Wachtrij niet hersteld: er zijn geen actieve bevestigde abonnees.';}
   else{
    $existing=(int)$wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $rt WHERE mailing_id=%d",(int)$m->id));
    if($existing===0){
     /* Oude wachtrij: maak een veilige snapshot. Ontvangers met aantoonbare open/klik-events worden niet opnieuw verzonden. */
     $known=array_map('intval',(array)$wpdb->get_col($wpdb->prepare("SELECT DISTINCT subscriber_id FROM $et WHERE mailing_id=%d AND subscriber_id>0",(int)$m->id)));
     foreach($subs as $sub){$status=in_array((int)$sub->id,$known,true)?'sent':'pending';$wpdb->query($wpdb->prepare("INSERT IGNORE INTO $rt (mailing_id,subscriber_id,email,unsub_token,status) VALUES (%d,%d,%s,%s,%s)",(int)$m->id,(int)$sub->id,(string)$sub->email,(string)$sub->unsub_token,$status));}
     $known_count=(int)$wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $rt WHERE mailing_id=%d AND status='sent'",(int)$m->id));
     /* Een oude teller (bijv. 25/25) bewijst niet welke adressen zijn verstuurd. Daarom alleen aantoonbare adressen uitsluiten. */
     $wpdb->update($this->mailings_table(),['total_count'=>$total,'sent_count'=>$known_count,'failed_count'=>0,'cursor_id'=>0,'window_started_at'=>current_time('mysql'),'window_sent'=>0],['id'=>(int)$m->id],['%d','%d','%d','%d','%s','%d'],['%d']);
     $msg='Wachtrij opnieuw opgebouwd voor '.number_format_i18n($total).' actieve ontvangers. '.number_format_i18n($known_count).' ontvangers met aantoonbare tracking zijn als reeds verwerkt gemarkeerd.';
    }else{
     $pending=(int)$wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $rt WHERE mailing_id=%d AND status='pending'",(int)$m->id));$sent=(int)$wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $rt WHERE mailing_id=%d AND status='sent'",(int)$m->id));$failed=(int)$wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $rt WHERE mailing_id=%d AND status='failed'",(int)$m->id));$snap=$pending+$sent+$failed;
     $wpdb->update($this->mailings_table(),['total_count'=>$snap,'sent_count'=>$sent,'failed_count'=>$failed],['id'=>(int)$m->id],['%d','%d','%d'],['%d']);
     $msg='Wachtrij gecontroleerd: '.number_format_i18n($snap).' ontvangers, waarvan '.number_format_i18n($pending).' nog te verzenden.';
    }
    if($m->status!=='paused'){if(!wp_next_scheduled('rvaz_nl_worker_tick'))wp_schedule_event(time()+30,'rvaz_nl_minute','rvaz_nl_worker_tick');delete_transient('rvaz_nl_batch_lock');}
   }
  }
  wp_safe_redirect(add_query_arg('rvaz_nl_msg',rawurlencode($msg),admin_url('admin.php?page=rvaz-newsletter')));exit;
 }
 public function cancel_mailing(){
  if(!current_user_can('manage_options'))wp_die('Geen toegang');$id=absint($_POST['mailing_id']??0);check_admin_referer('rvaz_nl_cancel_'.$id);
  global $wpdb;$m=$wpdb->get_row($wpdb->prepare("SELECT * FROM {$this->mailings_table()} WHERE id=%d",$id));
  if($m&&in_array($m->status,['queued','sending','paused'],true)){
   $this->revoke_mailing_authorization($id);$wpdb->update($this->mailings_table(),['status'=>'cancelled','completed_at'=>current_time('mysql')],['id'=>$id],['%s','%s'],['%d']);
   wp_clear_scheduled_hook('rvaz_nl_queue_worker');delete_transient('rvaz_nl_batch_lock');
   $msg='Verzendwachtrij geannuleerd. Reeds verzonden mails blijven in de statistieken staan; resterende ontvangers krijgen deze nieuwsbrief niet meer.';
  }else{$msg='Deze verzendwachtrij kon niet worden geannuleerd.';}
  wp_safe_redirect(add_query_arg('rvaz_nl_msg',rawurlencode($msg),admin_url('admin.php?page=rvaz-newsletter')));exit;
 }
 public function send_now(){
 if(!current_user_can('manage_options')||!check_admin_referer('rvaz_nl_send'))wp_die('Geen toegang');
 $existing=$this->active_mailing();
 if($existing){$msg='Er staat al een nieuwsbrief in de verzendwachtrij.';}
 else{$mid=$this->create_mailing(!empty($_POST['include_donation']));if($mid){$this->authorize_mailing($mid);$scheduled=wp_next_scheduled('rvaz_nl_worker_tick');if(!$scheduled)$scheduled=wp_schedule_event(time()+30,'rvaz_nl_minute','rvaz_nl_worker_tick',[],true);if(is_wp_error($scheduled)){$this->revoke_mailing_authorization($mid);global $wpdb;$wpdb->update($this->mailings_table(),['status'=>'paused'],['id'=>$mid],['%s'],['%d']);$msg='Nieuwsbrief is aangemaakt maar de vaste verzendworker kon niet worden gestart: '.$scheduled->get_error_message().'. De nieuwsbrief staat gepauzeerd.';}else{delete_transient('rvaz_nl_batch_lock');$this->queue_worker();$msg='Nieuwsbrief gestart. De vaste worker verwerkt iedere minuut een kleine batch, met maximaal '.self::BATCH_LIMIT.' verzendpogingen per uur.';}}else{$detail=get_transient('rvaz_nl_last_queue_error');$msg='Nieuwsbrief kon niet worden ingepland'.($detail?': '.$detail:'.');}}
 wp_safe_redirect(add_query_arg('rvaz_nl_msg',rawurlencode($msg),admin_url('admin.php?page=rvaz-newsletter')));exit;
}
 public function send_test(){if(!current_user_can('manage_options')||!check_admin_referer('rvaz_nl_test'))wp_die('Geen toegang');$e=sanitize_email($_POST['email']??'');if($e){$html=$this->newsletter_html(false);if(!empty($_POST['include_donation']))$html=$this->inject_donation_html($html);$this->send_to($e,'',true,null,0,0,'',$html);}wp_safe_redirect(add_query_arg('rvaz_nl_msg',rawurlencode('Testmail verzonden.'),admin_url('admin.php?page=rvaz-newsletter')));exit;}
 public function cron(){
  /* Veiligheidsstand 1.7.0: cron mag nooit zelfstandig een nieuwe mailing starten. Alleen een expliciete beheeractie (Nu verzenden / Hervatten) kan verzending activeren. */
  return;
 }
 public function smtp($m){if(empty($GLOBALS['rvaz_nl_sending']))return;if(!$this->opt('smtp_enabled'))return;$host=trim($this->opt('smtp_host'));if(!$host)return;$m->isSMTP();$m->Host=$host;$m->Port=max(1,absint($this->opt('smtp_port',587)));$m->SMTPAuth=(bool)$this->opt('smtp_auth');$m->Username=$this->opt('smtp_user');$m->Password=$this->opt('smtp_pass');$sec=$this->opt('smtp_secure','tls');if(in_array($sec,['tls','ssl'],true))$m->SMTPSecure=$sec;else $m->SMTPSecure='';$m->SMTPAutoTLS=($sec==='tls');}
 public function form($a=[]){$action=esc_url(admin_url('admin-post.php'));$msg=!empty($_GET['rvaz_nl'])?'<p class="rvaz-nl-success">Bedankt! Je bent ingeschreven voor de RVAZ-nieuwsbrief.</p>':'';return '<div class="rvaz-nl-box"><h3>Het laatste nieuws in je mailbox</h3><p>Ontvang het belangrijkste nieuws uit Voorne aan Zee.</p>'.$msg.'<form method="post" action="'.$action.'"><input type="hidden" name="action" value="rvaz_nl_subscribe"><input type="text" name="first_name" placeholder="Voornaam"><input type="email" name="email" required placeholder="E-mailadres"><label><input type="checkbox" name="consent" value="1" required> Ik wil de nieuwsbrief ontvangen en ga akkoord met verwerking van mijn e-mailadres.</label><button type="submit">Aanmelden</button></form></div>';}
 public function weekblad_published($issue_id){
  $issue_id=absint($issue_id);if(!$issue_id||get_post_type($issue_id)!=='rvaz_weekkrant')return;
  global $wpdb;$list='Weekblad Voorne aan Zee';$all=$wpdb->get_results("SELECT id,email,unsub_token,lists FROM {$this->table()} WHERE status='confirmed' ORDER BY id ASC");
  $subs=array_values(array_filter((array)$all,function($sub)use($list){$ls=array_map('trim',preg_split('/[,;]+/',(string)$sub->lists));return in_array($list,$ls,true);}));
  if(!$subs){update_post_meta($issue_id,'_rvaz_weekblad_mail_status','Geen actieve Weekblad-abonnees gevonden.');return;}
  if($this->active_mailing()){update_post_meta($issue_id,'_rvaz_weekblad_mail_status','Niet gestart: er stond al een andere nieuwsbrief in de verzendwachtrij.');return;}
  $this->ensure_queue_schema();$this->ensure_recipients_schema();$title=get_the_title($issue_id);$date=(string)get_post_meta($issue_id,'_rvaz_issue_date',true);$pdf=(string)get_post_meta($issue_id,'_rvaz_pdf_url',true);$read=home_url('/digitale-krant/');
  $subject='Nieuw Weekblad Voorne aan Zee'.($date?' – '.wp_date('j F Y',strtotime($date)):'');$html='<div style="max-width:640px;margin:auto;font-family:Arial,sans-serif;color:#10233f"><div style="background:#064b7c;color:#fff;padding:22px;text-align:center"><strong style="font-size:24px">WEEKBLAD VOORNE AAN ZEE</strong></div><div style="padding:24px"><h1 style="font-size:24px;color:#102b53">'.esc_html($title).'</h1><p>De nieuwe editie van Weekblad Voorne aan Zee staat klaar.</p><p><a href="'.esc_url($read).'" style="display:inline-block;background:#0877b9;color:#fff;padding:12px 18px;border-radius:6px;text-decoration:none;font-weight:bold">Blader door de nieuwe editie</a></p>'.($pdf?'<p style="font-size:13px"><a href="'.esc_url($pdf).'">PDF rechtstreeks openen</a></p>':'').'<p style="margin-top:24px;font-size:11px;color:#687386">Je ontvangt deze e-mail omdat je bent ingeschreven voor Weekblad Voorne aan Zee. {{unsubscribe}}</p></div></div>';
  $ok=$wpdb->insert($this->mailings_table(),['subject'=>$subject,'sent_at'=>current_time('mysql'),'sent_count'=>0,'total_count'=>count($subs),'failed_count'=>0,'status'=>'queued','cursor_id'=>0,'post_ids'=>'[]','content_html'=>$html,'window_started_at'=>current_time('mysql'),'window_sent'=>0,'mailing_type'=>'custom','target_list'=>$list,'include_donation'=>0]);
  if(!$ok){update_post_meta($issue_id,'_rvaz_weekblad_mail_status','Kon de Weekblad-mailing niet aanmaken.');return;}$mid=(int)$wpdb->insert_id;$rt=$this->recipients_table();foreach($subs as $sub)$wpdb->query($wpdb->prepare("INSERT IGNORE INTO $rt (mailing_id,subscriber_id,email,unsub_token,status) VALUES (%d,%d,%s,%s,'pending')",$mid,(int)$sub->id,(string)$sub->email,(string)$sub->unsub_token));
  $this->authorize_mailing($mid);delete_transient('rvaz_nl_batch_lock');$this->queue_worker();update_post_meta($issue_id,'_rvaz_weekblad_mail_status','Weekblad-mailing gestart voor '.count($subs).' abonnee(s).');update_post_meta($issue_id,'_rvaz_weekblad_mailing_id',$mid);
 }
 public function weekblad_form(){
  $action=esc_url(admin_url('admin-post.php'));
  $msg=!empty($_GET['rvaz_nl'])?'<div class="rvaz-weekblad-success" role="status"><strong>Gelukt!</strong> Je ontvangt het Weekblad Voorne aan Zee voortaan in je mailbox.</div>':'';
  $style='<style>.rvaz-weekblad-signup{margin:26px 0 6px;padding:24px 26px;background:#f5f9fc;border:1px solid #d8e5ee;border-left:5px solid #0877b9;border-radius:10px;max-width:760px}.rvaz-weekblad-signup h3{margin:0 0 7px;color:#062b50;font-size:22px;line-height:1.3}.rvaz-weekblad-signup .rvaz-weekblad-intro{margin:0 0 18px;color:#526b80}.rvaz-weekblad-signup form{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1.25fr) auto;gap:10px;align-items:center}.rvaz-weekblad-signup input[type=text],.rvaz-weekblad-signup input[type=email]{box-sizing:border-box;width:100%;min-height:44px;margin:0;padding:10px 12px;border:1px solid #b9cbd8;border-radius:6px;background:#fff;font-size:16px}.rvaz-weekblad-signup button{min-height:44px;border:0;border-radius:6px;padding:10px 17px;background:#07598b;color:#fff;font-weight:800;cursor:pointer;white-space:nowrap}.rvaz-weekblad-signup button:hover{background:#064b75}.rvaz-weekblad-consent{grid-column:1/-1;display:flex;gap:9px;align-items:flex-start;margin:3px 0 0;color:#263f54;font-size:14px;line-height:1.45}.rvaz-weekblad-consent input{margin-top:3px}.rvaz-weekblad-success{margin:0 0 15px;padding:11px 13px;background:#eaf7ef;border:1px solid #b9dfc7;border-radius:6px;color:#205b35}@media(max-width:760px){.rvaz-weekblad-signup{padding:20px 18px}.rvaz-weekblad-signup form{grid-template-columns:1fr}.rvaz-weekblad-consent{grid-column:1}.rvaz-weekblad-signup button{width:100%}}</style>';
  return $style.'<div class="rvaz-nl-box rvaz-weekblad-signup"><h3>Ontvang het Weekblad Voorne aan Zee iedere week gratis in je mailbox.</h3><p class="rvaz-weekblad-intro">Schrijf je in voor de aparte Weekblad-lijst. Je ontvangt alleen nieuwe edities waarvoor de redactie de verzending start.</p>'.$msg.'<form method="post" action="'.$action.'"><input type="hidden" name="action" value="rvaz_nl_subscribe"><input type="hidden" name="target_list" value="Weekblad Voorne aan Zee"><input type="text" name="first_name" autocomplete="given-name" placeholder="Voornaam" aria-label="Voornaam"><input type="email" name="email" autocomplete="email" required placeholder="E-mailadres" aria-label="E-mailadres"><button type="submit">Gratis inschrijven</button><label class="rvaz-weekblad-consent"><input type="checkbox" name="consent" value="1" required><span>Ja, stuur mij iedere nieuwe editie per e-mail.</span></label></form></div>';
 }
 public function subscribe(){if(empty($_POST['consent']))wp_die('Toestemming is vereist.');$e=sanitize_email($_POST['email']??'');if(!$e)wp_die('Ongeldig e-mailadres.');$list=sanitize_text_field(wp_unslash($_POST['target_list']??''));global $wpdb;$existing=$wpdb->get_row($wpdb->prepare("SELECT * FROM {$this->table()} WHERE email=%s",$e));$lists=$existing?array_filter(array_map('trim',preg_split('/[,;]+/',(string)$existing->lists))):[];if($list&&!in_array($list,$lists,true))$lists[]=$list;$wpdb->replace($this->table(),['email'=>$e,'first_name'=>sanitize_text_field($_POST['first_name']??($existing->first_name??'')),'last_name'=>$existing->last_name??'','status'=>'confirmed','lists'=>implode(', ',array_unique($lists)),'consent_at'=>current_time('mysql'),'created_at'=>$existing->created_at??current_time('mysql'),'unsub_token'=>$existing->unsub_token??wp_generate_password(40,false,false)],['%s','%s','%s','%s','%s','%s','%s','%s']);$back=wp_get_referer()?:home_url('/');wp_safe_redirect(add_query_arg('rvaz_nl','1',$back));exit;}
 public function unsubscribe(){$e=sanitize_email($_GET['email']??'');$t=sanitize_text_field($_GET['token']??'');global $wpdb;$row=$wpdb->get_row($wpdb->prepare("SELECT id,unsub_token FROM {$this->table()} WHERE email=%s",$e));if($row&&hash_equals($row->unsub_token,$t))$wpdb->update($this->table(),['status'=>'unsubscribed'],['id'=>$row->id],['%s'],['%d']);wp_die('<h1>Uitgeschreven</h1><p>Je ontvangt geen RVAZ-nieuwsbrieven meer.</p>','RVAZ Nieuwsbrief',['response'=>200]);}
}
new RVAZ_Nieuwsbrief_144();
