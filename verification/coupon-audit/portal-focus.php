<?php
if(!defined('ABSPATH')||function_exists('rvaz_wonen_portal_focus_20261009'))return;
function rvaz_wonen_portal_focus_20261009($html,$tag){
 if($tag!=='rvaz_wonen_portal'||!class_exists('RVAZ_Wonen'))return $html;
 $view=sanitize_key($_GET['wonen_portal']??'dashboard');
 $dom=new DOMDocument();$previous=libxml_use_internal_errors(true);
 $ok=$dom->loadHTML('<?xml encoding="UTF-8"><div id="rvaz-portal-focus">'.$html.'</div>',LIBXML_HTML_NOIMPLIED|LIBXML_HTML_NODEFDTD);
 libxml_clear_errors();libxml_use_internal_errors($previous);if(!$ok)return $html;
 $xpath=new DOMXPath($dom);
 foreach(iterator_to_array($xpath->query('//div[contains(concat(" ",normalize-space(@class)," ")," rvaz-reader ")][strong[contains(.,"Introductieactie voor nieuwe makelaars")]]')) as $node)$node->parentNode->removeChild($node);
 foreach(iterator_to_array($xpath->query('//section[contains(concat(" ",normalize-space(@class)," ")," rvaz-reader ")][h2[contains(.,"Zelf je woning")]]')) as $node)$node->parentNode->removeChild($node);
 foreach(iterator_to_array($xpath->query('//section[@aria-label="Mijn favoriete woningen"]')) as $node){
  if($view!=='dashboard'||!is_user_logged_in()||RVAZ_Wonen::blocked(get_current_user_id())){$node->parentNode->removeChild($node);continue;}
  if($node->parentNode->nodeName==='details')continue;
  $details=$dom->createElement('details');$details->setAttribute('class','rvaz-portal-reader-details');
  $details->appendChild($dom->createElement('summary','Favorieten en zoekmeldingen'));
  $node->parentNode->replaceChild($details,$node);$details->appendChild($node);
 }
 $root=$dom->getElementById('rvaz-portal-focus');$output='';foreach($root->childNodes as $node)$output.=$dom->saveHTML($node);return $output;
}
add_filter('do_shortcode_tag','rvaz_wonen_portal_focus_20261009',999,2);
add_action('wp_head',function(){if(!is_page('mijn-wonen'))return;
 echo '<style>.page-shell{display:block!important;max-width:1200px}.page-shell>.page-content-wrap{width:100%;min-width:0}.page-shell>:not(.page-content-wrap){display:none!important}.rvaz-portal-reader-details{margin-top:20px;padding:16px;border:1px solid #dce5eb;border-radius:10px}.rvaz-portal-reader-details>summary{cursor:pointer;font-weight:700}.rvw-layout{grid-template-columns:220px minmax(0,1fr)}@media(max-width:760px){.rvw-layout{grid-template-columns:minmax(0,1fr)}}</style>';
});
