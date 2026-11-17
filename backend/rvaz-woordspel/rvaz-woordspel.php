<?php
/**
 * Plugin Name: RVAZ Raad het woord
 * Description: Dagelijks woordspel voor ingelogde gebruikers. Shortcode: [rvaz_woordspel].
 * Version: 1.7.0
 */
defined('ABSPATH') || exit;
final class RVAZ_Woordspel {
 const OPT='rvaz_woordspel_days';
 private static $game_day='';
 static function init(){
  add_action('wp_ajax_rvaz_word_state',[__CLASS__,'ajax_state']);
  add_action('wp_ajax_rvaz_word_guess',[__CLASS__,'ajax_guess']);
  add_shortcode('rvaz_woordspel',[__CLASS__,'render']);
  add_filter('the_content',function($content){if(get_post_meta(get_the_ID(),'_rvaz_word_day',true))$content=str_replace('<p>Dit artikel toont steeds het spel van vandaag. De ranglijst wordt dagelijks opnieuw opgebouwd.</p>','',$content);return $content;},9);
  add_action('admin_menu',function(){add_menu_page('Raad het woord','Woordspel','manage_options','rvaz-woordspel',[__CLASS__,'admin'],'dashicons-editor-spellcheck');});
  add_action('admin_post_rvaz_word_save',[__CLASS__,'save']);
  add_action('admin_post_rvaz_word_publish',[__CLASS__,'publish']);
  add_action('transition_post_status',[__CLASS__,'activate_word'],10,3);
  add_action('rest_api_init',function(){foreach(['state'=>'GET','guess'=>'POST'] as $route=>$method)register_rest_route('rvaz-woord/v1','/'.$route,['methods'=>$method,'permission_callback'=>function(){return is_user_logged_in();},'callback'=>[__CLASS__,$route]]);});
  add_action('rest_api_init',function(){foreach(['state'=>'GET','guess'=>'POST'] as $route=>$method)register_rest_route('rvaz-woord/v1','/app/'.$route,['methods'=>$method,'permission_callback'=>[__CLASS__,'app_permission'],'callback'=>[__CLASS__,'app_'.$route]]);});
  add_action('template_redirect',function(){if(is_singular()&&has_shortcode(get_post()->post_content,'rvaz_woordspel')){if(!defined('DONOTCACHEPAGE'))define('DONOTCACHEPAGE',true);nocache_headers();}});
 }
 // Validate app sessions through the existing App API, including expiry/revocation.
 // The website keeps using its existing AJAX and cookie/nonce flow.
 static function app_permission($request){
  $token=trim((string)$request->get_header('authorization'));
  $extra=trim((string)$request->get_header('x-rvaz-token'));
  if(!$token&&$extra)$token='Bearer '.$extra;
  if(!preg_match('/^Bearer\s+\S+$/i',$token))return new WP_Error('rvaz_word_login','Log in via Mijn RVAZ om mee te spelen.',['status'=>401]);
  $before=get_current_user_id();
  $check=new WP_REST_Request('GET','/rvaz-app/v1/me');$check->set_header('authorization',$token);
  if($extra)$check->set_header('x-rvaz-token',$extra);
  try{$response=rest_do_request($check);}finally{wp_set_current_user($before);}
  if($response->get_status()!==200)return new WP_Error('rvaz_word_login','Log opnieuw in via Mijn RVAZ.',['status'=>401]);
  $data=$response->get_data();$uid=absint($data['user']['id']??$data['user']['ID']??0);
  if(!$uid||!get_userdata($uid))return new WP_Error('rvaz_word_login','Je account kon niet worden bevestigd.',['status'=>401]);
  if(get_user_meta($uid,'_rvaz_member_blocked',true)==='1')return new WP_Error('rvaz_word_blocked','Dit account heeft geen toegang.',['status'=>403]);
  wp_set_current_user($uid);return true;
 }
 static function app_state($request){return self::app_response($request,false);}
 static function app_guess($request){return self::app_response($request,true);}
 static function app_response($request,$guess){
  $id=absint($request->get_param('post_id'));$post=get_post($id);
  $date=$id?get_post_meta($id,'_rvaz_word_day',true):'';
  $parsed=DateTimeImmutable::createFromFormat('!Y-m-d',(string)$date,wp_timezone());
  if(!$post||$post->post_type!=='post'||$post->post_status!=='publish'||!has_shortcode($post->post_content,'rvaz_woordspel')||!$parsed||$parsed->format('Y-m-d')!==$date||$date>self::today())return new WP_Error('rvaz_word_day','Dit dagspel is niet beschikbaar.',['status'=>404]);
  $previous=self::$game_day;self::$game_day=$date;
  try{$result=$guess?self::guess($request):self::state();}
  finally{self::$game_day=$previous;}
  if($result instanceof WP_REST_Response)$result->header('Cache-Control','private, no-store');
  return $result;
 }
 static function word($s){return strtolower(trim((string)$s));}
 static function ajax_state(){self::ajax(false);}
 static function ajax_guess(){self::ajax(true);}
 static function ajax($guess){
  nocache_headers();if(!is_user_logged_in())wp_send_json(['message'=>'Log opnieuw in om te spelen.'],401);
  if(!check_ajax_referer('rvaz_word_ajax','nonce',false))wp_send_json(['message'=>'Je sessie is verlopen. Vernieuw de pagina.'],403);
  $post_id=absint($_POST['post_id']??0);
  if($post_id){$post=get_post($post_id);$date=get_post_meta($post_id,'_rvaz_word_day',true);$dt=DateTimeImmutable::createFromFormat('!Y-m-d',$date,wp_timezone());if(!$post||$post->post_status!=='publish'||!$dt||$dt->format('Y-m-d')!==$date||$date>self::today())wp_send_json(['message'=>'Dit dagspel is nog niet beschikbaar.'],403);self::$game_day=$date;}
  if($guess){$request=new WP_REST_Request('POST');$request->set_param('word',sanitize_text_field(wp_unslash($_POST['word']??'')));$result=self::guess($request);}else $result=self::state();
  if(is_wp_error($result)){$data=$result->get_error_data();wp_send_json(['message'=>$result->get_error_message()],is_array($data)?($data['status']??400):400);}
  wp_send_json($result->get_data());
 }
 static function score($guess,$answer){
  $out=array_fill(0,6,'absent');$left=[];
  for($i=0;$i<6;$i++){if($guess[$i]===$answer[$i])$out[$i]='correct';else $left[$answer[$i]]=($left[$answer[$i]]??0)+1;}
  for($i=0;$i<6;$i++)if($out[$i]!=='correct'&&!empty($left[$guess[$i]])){$out[$i]='present';$left[$guess[$i]]--;}
  return $out;
 }
 static function today(){return current_datetime()->format('Y-m-d');}
 static function game_day(){return self::$game_day?:self::today();}
 static function title_for_day($date){
  $d=DateTimeImmutable::createFromFormat('!Y-m-d',$date,wp_timezone());if(!$d)return 'Raad het woord';
  $week=['zondag','maandag','dinsdag','woensdag','donderdag','vrijdag','zaterdag'];$months=[1=>'januari','februari','maart','april','mei','juni','juli','augustus','september','oktober','november','december'];
  return 'Raad het woord van '.$week[(int)$d->format('w')].' '.$d->format('j').' '.$months[(int)$d->format('n')].' '.$d->format('Y');
 }
 static function data(){global $wpdb;$t=$wpdb->prefix.'rvaz_word_rounds';$date=self::game_day();return [$t,$date,$wpdb->get_row($wpdb->prepare("SELECT * FROM $t WHERE user_id=%d AND day=%s",get_current_user_id(),$date))];}
 static function state(){
  global $wpdb;
  [$t,$date,$row]=self::data();$days=get_option(self::OPT,[]);$answer=$row?$row->answer:($days[$date]??'');$guesses=$row?(json_decode($row->guesses,true)?:[]):[];
  $won=in_array($answer,$guesses,true)&&$answer!=='';$done=$won||count($guesses)>=6;
  $leaders=[];$entries=$wpdb->get_results($wpdb->prepare("SELECT user_id,answer,guesses FROM $t WHERE day=%s",$date));
  foreach((array)$entries as $entry){$tries=json_decode($entry->guesses,true)?:[];if(!in_array($entry->answer,$tries,true))continue;$user=get_userdata($entry->user_id);if(!$user)continue;$leaders[]=['name'=>$user->user_login,'attempts'=>count($tries)];}
  usort($leaders,function($a,$b){return $a['attempts']<=>$b['attempts']?:strnatcasecmp($a['name'],$b['name']);});
  $r=new WP_REST_Response(['date'=>$date,'available'=>$answer!=='','ranking'=>array_slice($leaders,0,50),'rows'=>array_map(function($g)use($answer){return ['word'=>$g,'colors'=>self::score($g,$answer)];},$guesses),'won'=>$won,'done'=>$done,'remaining'=>max(0,6-count($guesses)),'answer'=>$done?$answer:null]);$r->header('Cache-Control','private, no-store');return $r;
 }
 static function guess($req){
  global $wpdb;$lock='rvaz-word-'.md5(self::game_day());
  if(!$wpdb->get_var($wpdb->prepare('SELECT GET_LOCK(%s,5)',$lock)))return new WP_Error('busy','Het is druk. Probeer opnieuw.',['status'=>503]);
  try{return self::guess_locked($req);}finally{$wpdb->get_var($wpdb->prepare('SELECT RELEASE_LOCK(%s)',$lock));}
 }
 static function guess_locked($req){
  global $wpdb;$g=self::word($req->get_param('word'));if(!preg_match('/^[a-z]{6}$/D',$g))return new WP_Error('word','Vul precies zes letters in (a–z).',['status'=>400]);
  [$t,$date,$row]=self::data();$days=get_option(self::OPT,[]);$answer=$row?$row->answer:($days[$date]??'');if(!$answer)return new WP_Error('no_word','Er staat vandaag nog geen woord klaar.',['status'=>409]);
  // A unique row and an atomic compare-and-swap enforce six attempts even across tabs.
  if(!$row){$wpdb->query($wpdb->prepare("INSERT IGNORE INTO $t (user_id,day,answer,guesses,revision) VALUES (%d,%s,%s,'[]',0)",get_current_user_id(),$date,$answer));[$t,$date,$row]=self::data();}
  if(!$row)return new WP_Error('storage','Opslaan lukt niet. Probeer later opnieuw.',['status'=>503]);
  $old=json_decode($row->guesses,true)?:[];if(count($old)>=6||in_array($row->answer,$old,true))return self::state();
  if(in_array($g,$old,true))return new WP_Error('duplicate','Dit woord heb je al geprobeerd.',['status'=>400]);$old[]=$g;
  $n=$wpdb->query($wpdb->prepare("UPDATE $t SET guesses=%s,revision=revision+1 WHERE user_id=%d AND day=%s AND revision=%d",wp_json_encode($old),get_current_user_id(),$date,$row->revision));
  if($n!==1)return new WP_Error('retry','Je spel is elders gewijzigd. Vernieuw de pagina.',['status'=>409]);return self::state();
 }
 static function activate(){global $wpdb;require_once ABSPATH.'wp-admin/includes/upgrade.php';$t=$wpdb->prefix.'rvaz_word_rounds';dbDelta("CREATE TABLE $t (user_id bigint(20) unsigned NOT NULL, day date NOT NULL, answer varchar(6) NOT NULL, guesses text NOT NULL, revision bigint(20) unsigned NOT NULL DEFAULT 0, PRIMARY KEY  (user_id,day)) ".$wpdb->get_charset_collate().';');}
 static function admin(){
  if(!current_user_can('manage_options'))return;
  echo '<div class="wrap"><h1>Raad het woord</h1><p>Kies een datum en een woord van zes letters. Er wordt een conceptnieuwsartikel gemaakt met categorie Algemeen en de uitgelichte afbeelding. Bekijk en bewerk het artikel eerst; alleen jij publiceert het via de normale WordPress-knop.</p><form method="post" action="'.esc_url(admin_url('admin-post.php')).'">';wp_nonce_field('rvaz_word_publish');echo '<input type="hidden" name="action" value="rvaz_word_publish"><label>Datum <input type="date" name="day" required min="'.esc_attr(self::today()).'" value="'.esc_attr(self::today()).'"></label> <label>Woord <input name="word" required pattern="[A-Za-z]{6}" maxlength="6" autocomplete="off"></label> ';submit_button('Conceptartikel maken en bekijken','primary','submit',false);echo '</form><h2>Spelartikelen</h2><table class="widefat"><thead><tr><th>Datum</th><th>Status</th><th>Artikel</th></tr></thead><tbody>';
  $articles=get_option('rvaz_word_articles',[]);krsort($articles);foreach($articles as $date=>$id){if(!get_post($id)||get_post_status($id)==='trash')continue;echo '<tr><td>'.esc_html($date).'</td><td>'.esc_html(get_post_status($id)).'</td><td><a href="'.esc_url(get_edit_post_link($id)).'">Artikel bekijken/bewerken</a></td></tr>';}echo '</tbody></table>';self::participants();echo '</div>';
 }
 static function participants(){
  if(!current_user_can('manage_options'))return;
  $date=sanitize_text_field(wp_unslash($_GET['spel_datum']??self::today()));$dt=DateTimeImmutable::createFromFormat('!Y-m-d',$date,wp_timezone());if(!$dt||$dt->format('Y-m-d')!==$date)$date=self::today();
  $page=max(1,absint($_GET['spel_pagina']??1));$limit=50;$offset=($page-1)*$limit;global $wpdb;$table=$wpdb->prefix.'rvaz_word_rounds';
  // An empty row can exist after an interrupted request; it is not a submitted attempt.
  $where="day=%s AND guesses <> '[]'";
  $total=(int)$wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $table WHERE $where",$date));
  $rows=$wpdb->get_results($wpdb->prepare("SELECT user_id,answer,guesses FROM $table WHERE $where ORDER BY user_id ASC LIMIT %d OFFSET %d",$date,$limit,$offset));
  echo '<h2>Deelnemende leden</h2><form method="get"><input type="hidden" name="page" value="rvaz-woordspel"><label>Speldatum <input type="date" name="spel_datum" value="'.esc_attr($date).'" required></label> ';submit_button('Deelnemers bekijken','secondary','submit',false);echo '</form><p>'.esc_html($total).' leden met minimaal één ingediende poging. Testpogingen in het beheerdersvoorbeeld tellen niet mee.</p><table class="widefat striped"><thead><tr><th>Gebruikersnaam</th><th>Pogingen</th><th>Status</th></tr></thead><tbody>';
  foreach((array)$rows as $row){$guesses=json_decode($row->guesses,true);if(!is_array($guesses)||!count($guesses))continue;$user=get_userdata($row->user_id);$won=in_array($row->answer,$guesses,true);$status=$won?'Geraden':(count($guesses)>=6?'Niet geraden — afgelopen':'Bezig');echo '<tr><td>'.esc_html($user?$user->user_login:'Verwijderd account #'.(int)$row->user_id).'</td><td>'.esc_html(count($guesses)).' / 6</td><td>'.esc_html($status).'</td></tr>';}
  if(!$total)echo '<tr><td colspan="3">Op deze datum zijn nog geen pogingen ingediend.</td></tr>';echo '</tbody></table>';
  $base=admin_url('admin.php?page=rvaz-woordspel');echo '<p>';if($page>1)echo '<a href="'.esc_url(add_query_arg(['spel_datum'=>$date,'spel_pagina'=>$page-1],$base)).'">← Vorige</a> ';if($offset+$limit<$total)echo '<a href="'.esc_url(add_query_arg(['spel_datum'=>$date,'spel_pagina'=>$page+1],$base)).'">Volgende →</a>';echo '</p>';
 }
 static function publish(){
  if(!current_user_can('manage_options')||!current_user_can('publish_posts'))wp_die('Geen toegang.');check_admin_referer('rvaz_word_publish');
  $d=sanitize_text_field(wp_unslash($_POST['day']??self::today()));$dt=DateTimeImmutable::createFromFormat('!Y-m-d',$d,wp_timezone());$w=self::word(wp_unslash($_POST['word']??''));if(!$dt||$dt->format('Y-m-d')!==$d||$d<self::today()||!preg_match('/^[a-z]{6}$/D',$w))wp_die('Kies vandaag of een toekomstige datum en zes letters a–z.');
  global $wpdb;$t=$wpdb->prefix.'rvaz_word_rounds';$lock='rvaz-word-'.md5($d);if(!$wpdb->get_var($wpdb->prepare('SELECT GET_LOCK(%s,5)',$lock)))wp_die('Probeer opnieuw.');
  try{
   $days=get_option(self::OPT,[]);if(isset($days[$d])&&$days[$d]!==$w&&$wpdb->get_var($wpdb->prepare("SELECT user_id FROM $t WHERE day=%s LIMIT 1",$d)))wp_die('Er is vandaag al gespeeld. Het woord kan niet meer veranderen.');
   $published=get_option('rvaz_word_articles',[]);$id=isset($published[$d])?(int)$published[$d]:0;
   // A trashed or unrelated post must never be reopened as the day's editor.
   if($id){$existing=get_post($id);if(!$existing||$existing->post_type!=='post'||$existing->post_status==='trash'||get_post_meta($id,'_rvaz_word_day',true)!==$d)$id=0;}
   $image=self::featured_image();if(is_wp_error($image))wp_die(esc_html($image->get_error_message()));
   $category=get_term_by('slug','algemeen','category');if(!$category)$category=get_term_by('name','Algemeen','category');
   if(!$category){$term=wp_insert_term('Algemeen','category',['slug'=>'algemeen']);if(is_wp_error($term))wp_die(esc_html($term->get_error_message()));$category=get_term((int)$term['term_id'],'category');}
   if(!$id||!get_post($id)){
    $id=wp_insert_post(['post_type'=>'post','post_status'=>'draft','post_title'=>self::title_for_day($d),'post_content'=>"<p>Een nieuw woord, zes pogingen. Log in met je RVAZ-account en speel mee. Wie raadt het woord vandaag in de minste pogingen?</p>\n[rvaz_woordspel]",'post_category'=>[(int)$category->term_id],'meta_input'=>['_rvaz_word_day'=>$d,'_rvaz_word_answer'=>$w,'_thumbnail_id'=>$image]],true);
    if(is_wp_error($id))wp_die(esc_html($id->get_error_message()));$published[$d]=$id;update_option('rvaz_word_articles',$published,false);
   }
   if(!has_post_thumbnail($id))set_post_thumbnail($id,$image);
   $assigned=wp_set_post_categories($id,[(int)$category->term_id]);if(is_wp_error($assigned))wp_die(esc_html($assigned->get_error_message()));
   if(get_post_status($id)==='draft'){update_post_meta($id,'_rvaz_word_answer',$w);wp_update_post(['ID'=>$id,'post_title'=>self::title_for_day($d)]);}
  }finally{$wpdb->get_var($wpdb->prepare('SELECT RELEASE_LOCK(%s)',$lock));}
  $edit=get_edit_post_link($id,'raw');if(!$edit)wp_die('Het concept is opgeslagen, maar kan niet worden geopend. Open Berichten → Alle berichten.');wp_safe_redirect($edit);exit;
 }
 static function activate_word($new,$old,$post){
  if($new!=='publish'||$old==='publish')return;$d=get_post_meta($post->ID,'_rvaz_word_day',true);$w=get_post_meta($post->ID,'_rvaz_word_answer',true);if(!$d||!preg_match('/^[a-z]{6}$/D',$w))return;
  global $wpdb;$lock='rvaz-word-'.md5($d);if(!$wpdb->get_var($wpdb->prepare('SELECT GET_LOCK(%s,5)',$lock)))return;
  try{$t=$wpdb->prefix.'rvaz_word_rounds';$played=$wpdb->get_var($wpdb->prepare("SELECT answer FROM $t WHERE day=%s LIMIT 1",$d));$days=get_option(self::OPT,[]);$days[$d]=$played?:$w;update_option(self::OPT,$days,false);}finally{$wpdb->get_var($wpdb->prepare('SELECT RELEASE_LOCK(%s)',$lock));}
 }
 static function featured_image(){
  $id=(int)get_option('rvaz_word_featured_image',0);if($id&&wp_attachment_is_image($id)&&get_attached_file($id)&&file_exists(get_attached_file($id)))return $id;
  $path=plugin_dir_path(__FILE__).'raad-het-woord.png';if(!is_readable($path))return new WP_Error('image','De standaard spelafbeelding ontbreekt. Het artikel is niet gepubliceerd.');
  $upload=wp_upload_bits('rvaz-raad-het-woord.png',null,file_get_contents($path));if(!empty($upload['error']))return new WP_Error('upload',$upload['error']);
  $id=wp_insert_attachment(['post_title'=>'Raad het woord – Regio Voorne aan Zee','post_mime_type'=>'image/png','post_status'=>'inherit'],$upload['file'],0,true);if(is_wp_error($id))return $id;
  require_once ABSPATH.'wp-admin/includes/image.php';$metadata=wp_generate_attachment_metadata($id,$upload['file']);if($metadata)wp_update_attachment_metadata($id,$metadata);
  update_post_meta($id,'_wp_attachment_image_alt','Raad het woord: elke dag een nieuwe uitdaging bij Regio Voorne aan Zee.');update_option('rvaz_word_featured_image',$id,false);return $id;
 }
 static function save(){
  if(!current_user_can('manage_options'))wp_die('Geen toegang.');check_admin_referer('rvaz_word_save');$d=sanitize_text_field(wp_unslash($_POST['day']??''));$w=self::word(wp_unslash($_POST['word']??''));$dt=DateTimeImmutable::createFromFormat('!Y-m-d',$d,wp_timezone());
  if(!$dt||$dt->format('Y-m-d')!==$d||$d<self::today()||!preg_match('/^[a-z]{6}$/D',$w))wp_die('Kies vandaag of een toekomstige datum en zes letters a–z.');
  global $wpdb;$t=$wpdb->prefix.'rvaz_word_rounds';$lock='rvaz-word-'.md5($d);$got=$wpdb->get_var($wpdb->prepare('SELECT GET_LOCK(%s,5)',$lock));if(!$got)wp_die('Probeer opnieuw.');
  // Lock the configured day as soon as any attempt exists.
  if($wpdb->get_var($wpdb->prepare("SELECT user_id FROM $t WHERE day=%s LIMIT 1",$d))){$wpdb->get_var($wpdb->prepare('SELECT RELEASE_LOCK(%s)',$lock));wp_die('Dit woord is al gespeeld en kan niet meer worden gewijzigd.');}
  $days=get_option(self::OPT,[]);$days[$d]=$w;update_option(self::OPT,$days,false);$wpdb->get_var($wpdb->prepare('SELECT RELEASE_LOCK(%s)',$lock));wp_safe_redirect(admin_url('admin.php?page=rvaz-woordspel'));exit;
 }
 static function render(){
  if(is_preview()&&current_user_can('edit_post',get_the_ID())){
   $answer=get_post_meta(get_the_ID(),'_rvaz_word_answer',true);$date=get_post_meta(get_the_ID(),'_rvaz_word_day',true);
   if(preg_match('/^[a-z]{6}$/D',$answer)){
    wp_enqueue_script('rvaz-word-preview',plugins_url('preview.js',__FILE__),[],'1.6.0',true);wp_enqueue_style('rvaz-word',plugins_url('word.css',__FILE__),[],'1.6.0');
    return '<section class="rvword" data-preview-answer="'.esc_attr($answer).'"><h2>Raad het woord</h2><p>Beheerdersvoorbeeld — '.esc_html($date).'. Testpogingen tellen niet mee en veranderen geen scores.</p><div class="rvword-grid"></div><form><label>Jouw woord <input name="word" maxlength="6" pattern="[A-Za-z]{6}" required autocomplete="off"></label><button>Probeer</button></form><p role="status" aria-live="polite"></p><p>Groen: juiste plek · Geel: andere plek · Grijs: niet in het woord</p></section>';
   }
  }
  if(!is_user_logged_in()){
   $return=rawurlencode(get_permalink());
   return '<section class="rvaz-lockbox"><h2>Log gratis in om mee te spelen</h2><p>Dit spel is beschikbaar voor lezers met een gratis RVAZ-account.</p><div class="rvaz-actions" style="justify-content:center"><a class="rvaz-btn" href="'.esc_url(home_url('/inloggen/?return_to='.$return)).'">Inloggen</a><a class="rvaz-btn alt" href="'.esc_url(home_url('/registreren/?return_to='.$return)).'">Gratis account</a></div></section>';
  }
  wp_enqueue_script('rvaz-word',plugins_url('word.js',__FILE__),[], '1.6.0',true);wp_enqueue_style('rvaz-word',plugins_url('word.css',__FILE__),[],'1.6.0');
  return '<section class="rvword" data-post="'.esc_attr(get_post_meta(get_the_ID(),'_rvaz_word_day',true)?get_the_ID():0).'" data-api="'.esc_url(admin_url('admin-ajax.php')).'" data-nonce="'.esc_attr(wp_create_nonce('rvaz_word_ajax')).'"><small>REGIO VOORNE AAN ZEE</small><h2>Raad het woord</h2><p>Zes letters. Zes pogingen. Iedere dag een nieuw woord.</p><p class="rvword-date"></p><div class="rvword-grid" aria-label="Jouw pogingen"></div><form class="rvword-form"><label>Jouw woord <input name="word" autocomplete="off" autocapitalize="characters" spellcheck="false" maxlength="6" pattern="[A-Za-z]{6}" required></label><button>Probeer</button></form><p class="rvword-status" role="status" aria-live="polite">Spel laden…</p><div class="rvword-keys" aria-label="Toetsenbord"></div><p class="rvword-legend">Groen: juiste plek · Geel: andere plek · Grijs: niet in het woord</p><button type="button" class="rvword-share" hidden>Deel je resultaat</button><h3>Ranglijst van dit dagspel</h3><p>Minste pogingen bovenaan. Bij gelijke score deel je dezelfde plaats. Je gebruikersnaam verschijnt hier als je wint.</p><ol class="rvword-ranking"></ol></section>';
 }
}
RVAZ_Woordspel::init();register_activation_hook(__FILE__,['RVAZ_Woordspel','activate']);
