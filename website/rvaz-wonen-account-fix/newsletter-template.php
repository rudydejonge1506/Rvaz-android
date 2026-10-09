<?php
if(!defined('ABSPATH'))exit;
add_action('admin_menu',function(){if(!class_exists('RVAZ_Wonen'))return;add_submenu_page('rvaz-wonen','Makelaarsmailing voorbereiden','Makelaarsmailing','manage_options','rvaz-wonen-mailtemplate',function(){
 if(!current_user_can('manage_options'))return;$html=file_get_contents(__DIR__.'/makelaars-uitnodiging.html');
 echo '<div class="wrap"><h1>RVAZ Wonen – uitnodiging makelaars (eenmalig)</h1><p><strong>Onderwerp:</strong> Nieuw: uw woningaanbod op RVAZ — eerste maand gratis voor de eerste 2 kantoren</p><p>Verbeterd HTML-template om te kopiëren naar RVAZ Nieuwsbrief. Deze pagina verstuurt geen e-mails. Gebruik uitsluitend de aparte lijst Makelaars en controleer toestemming vóór verzending. Laat de verzending gepauzeerd totdat deze uitdrukkelijk is goedgekeurd.</p><form method="post" action="'.esc_url(admin_url('admin-post.php')).'"><input type="hidden" name="action" value="rvaz_wonen_improve_mailing">'.wp_nonce_field('rvaz_wonen_improve_mailing','nonce',true,false).'<p><button class="button button-primary">Verbeter gepauzeerde makelaarsmailing 21</button> — bewaart de verzendlijst en blijft gepauzeerd; verstuurt niets.</p></form><label for="rvaz-mail-template">HTML-template</label><textarea id="rvaz-mail-template" readonly style="display:block;width:100%;height:240px">'.esc_textarea($html).'</textarea><p>Selecteer de HTML hierboven en kopieer die naar het HTML-veld van de makelaarsmailing. Bewaar de afmeldlink-placeholder van de nieuwsbriefplugin.</p><h2>Voorbeeld</h2><iframe title="Voorbeeld makelaarsmailing" sandbox="" srcdoc="'.esc_attr($html).'" style="width:100%;height:1000px;border:1px solid #ccd7df"></iframe></div>';
 });},110);

add_action('admin_post_rvaz_wonen_improve_mailing',function(){
 if(!current_user_can('manage_options'))wp_die('Geen toegang');check_admin_referer('rvaz_wonen_improve_mailing','nonce');
 global $wpdb;$table=$wpdb->prefix.'rvaz_newsletter_mailings';$row=$wpdb->get_row($wpdb->prepare("SELECT id,status,sent_count,target_list FROM $table WHERE id=%d",21));
 if(!$row||$row->status!=='paused'||(int)$row->sent_count!==0||$row->target_list!=='Makelaars')wp_die('De mailing is niet meer een onverzonden, gepauzeerde makelaarsmailing. Er is niets gewijzigd.');
 $html=file_get_contents(__DIR__.'/makelaars-uitnodiging.html');
 $result=$wpdb->update($table,['content_html'=>$html,'subject'=>'Nieuw: uw woningaanbod op RVAZ — eerste maand gratis voor de eerste 2 kantoren'],['id'=>21,'status'=>'paused','sent_count'=>0,'target_list'=>'Makelaars']);
 if($result===false)wp_die('Opslaan mislukt; er is niets verzonden.');
 wp_safe_redirect(admin_url('admin.php?page=rvaz-wonen-mailtemplate&opgeslagen=1'));exit;
});
