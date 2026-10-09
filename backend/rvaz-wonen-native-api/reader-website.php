<?php
if (!defined('ABSPATH')) exit;
add_action('wp_enqueue_scripts',function(){
 if(!class_exists('RVAZ_Wonen')||!(is_page(['wonen','mijn-wonen'])||is_singular(RVAZ_Wonen::TYPE)))return;
 wp_enqueue_script('rvaz-reader',plugins_url('reader-website.js',__FILE__),[], '1.1.0',true);
 wp_add_inline_script('rvaz-reader','window.rvazReader='.wp_json_encode(['api'=>rest_url(RVAZ_Wonen_Native_API::NS),'nonce'=>is_user_logged_in()?wp_create_nonce('wp_rest'):'','login'=>wp_login_url(get_permalink())]).';','before');
 wp_enqueue_style('rvaz-reader',plugins_url('reader-website.css',__FILE__),[], '1.1.0');
});
add_filter('do_shortcode_tag',function($output,$tag){
 if(!class_exists('RVAZ_Wonen'))return $output;
 if($tag==='rvaz_wonen_portal'&&is_user_logged_in()&&!RVAZ_Wonen::blocked(get_current_user_id())&&(in_array(RVAZ_Wonen::ROLE,wp_get_current_user()->roles,true)||current_user_can('manage_options'))&&(!isset($_GET['wonen_portal'])||$_GET['wonen_portal']==='dashboard')){
  $d=RVAZ_Wonen_Native_API::dashboard();ob_start();echo RVAZ_Wonen::css().'<div class="rvw"><div class="rvw-layout">';RVAZ_Wonen::portal_nav('dashboard');echo '<main><div class="rvw-panel"><h1>Makelaarsdashboard</h1><div class="rvaz-reader-stats">';
  foreach(['published'=>'Gepubliceerd','draft'=>'Concept / beoordeling','sold'=>'Verkocht / verhuurd','unread_messages'=>'Nieuwe aanvragen','views'=>'Weergaven'] as $key=>$label)echo '<div><strong>'.(int)$d[$key].'</strong><br>'.esc_html($label).'</div>';
  echo '</div><p>Abonnement: '.esc_html($d['plan_name']).' · '.($d['subscription_active']?'Actief':'Niet actief').'</p><p>Publicatieruimte: '.($d['remaining']===null?'Onbeperkt':(int)$d['remaining'].' woningen').'</p><p><a class="rvw-btn" href="?wonen_portal=nieuw">Woning toevoegen</a> <a class="rvw-btn alt" href="?wonen_portal=berichten">Aanvragen bekijken</a></p><h2>Te controleren</h2>';
  if(!$d['attention'])echo '<p>Je woninggegevens zijn compleet.</p>';
  foreach($d['attention'] as $a)echo '<p><a href="'.esc_url(add_query_arg(['wonen_portal'=>'nieuw','stap'=>1,'woning_id'=>$a['id']],home_url('/mijn-wonen/'))).'">'.esc_html($a['title']).'</a>: '.esc_html(implode(', ',$a['missing'])).'</p>';
  echo '<h2>Woningen importeren</h2><p>Een officiële Funda- of CRM-koppeling is nog niet beschikbaar. Voor automatische import zijn toegang en afspraken met de leverancier nodig. Er worden hiervoor nog geen kosten gerekend.</p></div></main></div></div>';$output=ob_get_clean();
 }
 if(in_array($tag,['rvaz_wonen','rvaz_wonen_portal'],true))$output.='<section class="rvaz-reader" aria-label="Mijn favoriete woningen"><h2>Mijn Wonen: favorieten en zoekmeldingen</h2><div id="rvaz-reader-root" aria-live="polite"></div></section>';
 return $output;
},10,2);
