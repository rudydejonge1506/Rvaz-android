<?php
if(!defined('ABSPATH'))exit;
final class RVAZ_Wonen_Private_Account {
 static function url(){return add_query_arg('rvaz_wonen','particulier',home_url('/account/'));}
 static function panel(){return '<section class="rvaz-reader"><h2>Mijn Wonen</h2><p>Je particuliere woning, foto’s, plaatsing en reacties op één plek in Mijn account. €25 voor één woning, één kalendermaand vanaf publicatie, na beoordeling en bevestigde betaling.</p><div id="rvaz-private-root" aria-live="polite"></div></section>';}
 static function integrate($html,$tag){
  if($tag!=='rvaz_member_account'||!is_user_logged_in()||strpos($html,'rvaz-private-root')!==false)return $html;
  $active=($_GET['rvaz_wonen']??'')==='particulier';
  $dom=new DOMDocument();$old=libxml_use_internal_errors(true);$dom->loadHTML('<?xml encoding="UTF-8"><div id="rvaz-account-fragment">'.$html.'</div>',LIBXML_HTML_NOIMPLIED|LIBXML_HTML_NODEFDTD);libxml_clear_errors();libxml_use_internal_errors($old);$xpath=new DOMXPath($dom);
  $nav=$xpath->query('//*[contains(concat(" ",normalize-space(@class)," ")," rvaz-account-nav ")]')->item(0);
  if($nav){$link=null;foreach($nav->getElementsByTagName('a') as $a)if(stripos($a->textContent,'Mijn Wonen')!==false){$link=$a;break;}
   if(!$link){$link=$dom->createElement('a','Mijn Wonen');$nav->insertBefore($link,$nav->firstChild);}$link->setAttribute('href',self::url());
   if($active){foreach($nav->getElementsByTagName('a') as $a){$a->setAttribute('class',trim(str_replace('is-active','',$a->getAttribute('class'))));$a->removeAttribute('aria-current');}$link->setAttribute('class',trim($link->getAttribute('class').' is-active'));$link->setAttribute('aria-current','page');}
  }
  if($active){$target=$xpath->query('//*[contains(concat(" ",normalize-space(@class)," ")," rvaz-account-content ")]')->item(0);
   if($target){while($target->firstChild)$target->removeChild($target->firstChild);$fragment=new DOMDocument();$previous=libxml_use_internal_errors(true);$fragment->loadHTML('<?xml encoding="UTF-8"><div id="panel">'.self::panel().'</div>',LIBXML_HTML_NOIMPLIED|LIBXML_HTML_NODEFDTD);libxml_clear_errors();libxml_use_internal_errors($previous);foreach(iterator_to_array($fragment->getElementById('panel')->childNodes) as $node)$target->appendChild($dom->importNode($node,true));}
   else {return $html.self::panel();}
  }
  $root=$dom->getElementById('rvaz-account-fragment');$out='';foreach($root->childNodes as $node)$out.=$dom->saveHTML($node);return $out;
 }
}
add_filter('do_shortcode_tag',['RVAZ_Wonen_Private_Account','integrate'],60,2);
