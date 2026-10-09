<?php
if(!defined('ABSPATH'))exit;
final class RVAZ_Wonen_Subscription_Access {
 static function writable($uid){
  if(RVAZ_Wonen::blocked($uid))return false;
  $s=RVAZ_Wonen_Account_Fix::subscription($uid);
  return ($s&&$s->status==='active')||(current_user_can('manage_options')&&!RVAZ_Wonen_Account_Fix::history($uid));
 }
 static function permission($request,$original){$ok=call_user_func($original,$request);if(is_wp_error($ok)||$ok!==true)return $ok;return self::writable(get_current_user_id())?true:RVAZ_Wonen_Native_API::error('subscription_required','Kies eerst een nieuw abonnement via Mijn Wonen. Je huidige abonnement is niet actief.',403);}
 static function portal($html,$tag){
  if($tag!=='rvaz_wonen_portal'||!is_user_logged_in()||($_GET['wonen_portal']??'')!=='nieuw'||self::writable(get_current_user_id()))return $html;
  $dom=new DOMDocument();$old=libxml_use_internal_errors(true);$dom->loadHTML('<?xml encoding="UTF-8"><div id="rvaz-access-fragment">'.$html.'</div>',LIBXML_HTML_NOIMPLIED|LIBXML_HTML_NODEFDTD);libxml_clear_errors();libxml_use_internal_errors($old);
  $xpath=new DOMXPath($dom);$main=$xpath->query('//div[contains(concat(" ",normalize-space(@class)," ")," rvw-layout ")]/main')->item(0);
  if(!$main)return $html;
  while($main->firstChild)$main->removeChild($main->firstChild);$panel=$dom->createElement('div');$panel->setAttribute('class','rvw-panel');$panel->appendChild($dom->createElement('h2','Een actief abonnement is nodig'));
  $panel->appendChild($dom->createElement('p','Je abonnement is gestopt. Kies eerst opnieuw een pakket. Na goedkeuring kun je weer woningen plaatsen en bewerken. Je eerdere woningen en facturen blijven bewaard.'));
  $a=$dom->createElement('a','Nieuw pakket kiezen');$a->setAttribute('href',add_query_arg('wonen_portal','abonnement',home_url('/mijn-wonen/')));$a->setAttribute('class','rvw-btn');$panel->appendChild($a);$main->appendChild($panel);
  $output='';foreach($dom->getElementById('rvaz-access-fragment')->childNodes as $node)$output.=$dom->saveHTML($node);return $output;
 }
}
add_filter('rest_endpoints',function($routes){foreach($routes as $path=>&$endpoints){if(!preg_match('#^/rvaz-wonen/v1/makelaar/woningen(?:$|/\(\?P<id>.+)#',$path)||strpos($path,'verwijderen')!==false)continue;
 foreach($endpoints as &$endpoint){if(!is_array($endpoint)||empty($endpoint['permission_callback'])||empty($endpoint['methods']))continue;$methods=$endpoint['methods'];if(is_string($methods))$methods=explode(',',$methods);$allowed=[];foreach($methods as $key=>$value)$allowed[]=strtoupper(trim(is_int($key)?(string)$value:(string)$key));if(!array_intersect($allowed,['POST','PUT','PATCH']))continue;
  $original=$endpoint['permission_callback'];$endpoint['permission_callback']=function($r)use($original){return RVAZ_Wonen_Subscription_Access::permission($r,$original);};
 }unset($endpoint);
}unset($endpoints);return $routes;},1100);
add_filter('do_shortcode_tag',['RVAZ_Wonen_Subscription_Access','portal'],1200,2);
foreach(['rvaz_wonen_wizard','rvaz_wonen_request_news_promo'] as $action)add_action('admin_post_'.$action,function(){if(!RVAZ_Wonen_Subscription_Access::writable(get_current_user_id()))wp_die('Kies eerst een actief pakket via Mijn Wonen → Abonnement.');},-100);
