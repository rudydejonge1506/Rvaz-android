<?php
if (!defined('ABSPATH')) exit;
final class RVAZ_Wonen_Reader {
 const FAVORITES='rvaz_wonen_favorites';
 const SEARCHES='rvaz_wonen_searches';
 const NOTICES='rvaz_wonen_notices';
 static function register() {
  if(!class_exists('RVAZ_Wonen'))return;
  foreach([
   '/favorieten'=>[['GET','favorites'],['POST','save_favorite']],
   '/zoekopdrachten'=>[['GET','searches'],['POST','save_search']],
   '/zoekopdrachten/(?P<id>[a-z0-9-]+)/verwijderen'=>[['POST','delete_search']],
   '/zoekmeldingen'=>[['GET','notices'],['POST','read_notices']],
  ] as $path=>$routes){$handlers=[];foreach($routes as $route)$handlers[]=['methods'=>$route[0],'callback'=>[__CLASS__,$route[1]],'permission_callback'=>['RVAZ_Wonen_Native_API','authenticated']];register_rest_route(RVAZ_Wonen_Native_API::NS,$path,$handlers);}
 }
 static function visible($id) { $p=get_post($id);return $p&&$p->post_type===RVAZ_Wonen::TYPE&&$p->post_status==='publish'&&!RVAZ_Wonen::blocked((int)$p->post_author); }
 static function favorites() {
  $ids=array_values(array_unique(array_map('absint',(array)get_user_meta(get_current_user_id(),self::FAVORITES,true))));
  return ['ids'=>$ids,'items'=>array_map(['RVAZ_Wonen_Native_API','listing'],array_values(array_filter($ids,[__CLASS__,'visible'])))];
 }
 static function save_favorite($r) {
  $id=is_scalar($r['woning_id'])?absint($r['woning_id']):0;if(!$id||!is_bool($r['saved']))return RVAZ_Wonen_Native_API::error('favorite','Ongeldige favoriet.');
  $ids=self::favorites()['ids'];
  if($r['saved']){if(!self::visible($id))return RVAZ_Wonen_Native_API::error('favorite','Deze woning is niet meer beschikbaar.',404);if(!in_array($id,$ids,true)){if(count($ids)>=1000)return RVAZ_Wonen_Native_API::error('limit','Je kunt maximaal 1000 woningen bewaren.');$ids[]=$id;}}
  else $ids=array_values(array_diff($ids,[$id]));
  update_user_meta(get_current_user_id(),self::FAVORITES,$ids);return self::favorites();
 }
 static function rows($uid) { $rows=get_user_meta($uid,self::SEARCHES,true);return is_array($rows)?$rows:[]; }
 static function searches() {return array_values(array_map(function($row){unset($row['seen']);return $row;},self::rows(get_current_user_id())));}
 static function criteria($r) {
  foreach(['plaats','transactie','woningtype'] as $k)if($r->has_param($k)&&!is_scalar($r[$k]))return RVAZ_Wonen_Native_API::error('criteria','Ongeldige zoekcriteria.');
  $d=['plaats'=>sanitize_text_field($r['plaats']??''),'transactie'=>sanitize_text_field($r['transactie']??''),'woningtype'=>sanitize_text_field($r['woningtype']??'')];
  if(!in_array($d['transactie'],['','Koop','Huur'],true))return RVAZ_Wonen_Native_API::error('criteria','Kies koop, huur of beide.');
  foreach(['min_prijs','max_prijs'] as $k){$v=$r[$k];if($v!==null&&$v!==''&&(!is_numeric($v)||!is_finite((float)$v)||(float)$v<0))return RVAZ_Wonen_Native_API::error('criteria','Gebruik een geldige prijs.');$d[$k]=$v===null||$v===''?null:(float)$v;}
  if($d['min_prijs']!==null&&$d['max_prijs']!==null&&$d['min_prijs']>$d['max_prijs'])return RVAZ_Wonen_Native_API::error('criteria','Minimumprijs ligt boven maximumprijs.');
  if(!$d['plaats']&&!$d['transactie']&&!$d['woningtype']&&$d['min_prijs']===null&&$d['max_prijs']===null)return RVAZ_Wonen_Native_API::error('criteria','Kies minstens één zoekfilter.');
  return $d;
 }
 static function number($raw) { $raw=preg_replace('/[^0-9,.]/','',(string)$raw);if($raw==='')return null;if(strpos($raw,',')!==false)$raw=str_replace(',','.',str_replace('.','',$raw));elseif(preg_match('/^\d{1,3}(\.\d{3})+$/',$raw))$raw=str_replace('.','',$raw);return is_numeric($raw)?(float)$raw:null; }
 static function matches($d,$s) {
  if(in_array(mb_strtolower($d['status']??''),['verkocht','verhuurd'],true))return false;
  foreach(['plaats','transactie','woningtype'] as $k)if($s[$k]!==''&&mb_strtolower(trim($d[$k]??''))!==mb_strtolower(trim($s[$k])))return false;
  $price=self::number($d['prijs']??'');foreach(['min_prijs','max_prijs'] as $k)if($s[$k]!==null&&($price===null||($k==='min_prijs'?$price<$s[$k]:$price>$s[$k])))return false;
  return true;
 }
 static function save_search($r) {
  if(!is_bool($r['enabled']))return RVAZ_Wonen_Native_API::error('criteria','Bevestig of je zoekmeldingen wilt ontvangen.');
  $criteria=self::criteria($r);if(is_wp_error($criteria))return $criteria;
  $uid=get_current_user_id();$rows=self::rows($uid);$id=sanitize_key($r['id']??'');
  if($id&&!isset($rows[$id]))return RVAZ_Wonen_Native_API::error('search','Deze zoekopdracht is niet van jou.',404);
  if(!$id&&count($rows)>=10)return RVAZ_Wonen_Native_API::error('limit','Je kunt maximaal 10 zoekopdrachten bewaren.');
  $id=$id?:wp_generate_uuid4();$seen=[];foreach(RVAZ_Wonen_Native_API::public_list() as $d)if(self::matches($d,$criteria))$seen[]=$d['id'];
  $rows[$id]=$criteria+['id'=>$id,'enabled'=>$r['enabled'],'seen'=>$seen,'created'=>current_time('mysql')];update_user_meta($uid,self::SEARCHES,$rows);return self::searches();
 }
 static function delete_search($r) {$uid=get_current_user_id();$rows=self::rows($uid);if(!isset($rows[$r['id']]))return RVAZ_Wonen_Native_API::error('search','Zoekopdracht niet gevonden.',404);unset($rows[$r['id']]);update_user_meta($uid,self::SEARCHES,$rows);return self::searches();}
 static function scan($uid) {
  $rows=self::rows($uid);if(!$rows)return;
  $notices=get_user_meta($uid,self::NOTICES,true);if(!is_array($notices))$notices=[];
  foreach(RVAZ_Wonen_Native_API::public_list() as $d)foreach($rows as $key=>&$s)if($s['enabled']&&self::matches($d,$s)&&!in_array($d['id'],$s['seen'],true)){
   $s['seen'][]=$d['id'];$nid=hash('sha256',$key.':'.$d['id']);$notices[$nid]=['id'=>$nid,'woning_id'=>$d['id'],'title'=>$d['title'],'url'=>$d['url'],'created'=>current_time('mysql'),'read'=>false];
  }unset($s);
  update_user_meta($uid,self::SEARCHES,$rows);update_user_meta($uid,self::NOTICES,array_slice($notices,-200,null,true));
 }
 static function notices() { $uid=get_current_user_id();self::scan($uid);$rows=(array)get_user_meta($uid,self::NOTICES,true);return array_values(array_reverse(array_filter($rows,function($row){return is_array($row)&&self::visible($row['woning_id']);}),true)); }
 static function read_notices($r) {if($r['confirm']!==true)return RVAZ_Wonen_Native_API::error('confirm','Bevestig gelezen meldingen.');$uid=get_current_user_id();$rows=(array)get_user_meta($uid,self::NOTICES,true);foreach($rows as &$row)if(is_array($row))$row['read']=true;unset($row);update_user_meta($uid,self::NOTICES,$rows);return self::notices();}
 static function cron() {if(!class_exists('RVAZ_Wonen'))return;for($offset=0;;$offset+=100){$users=get_users(['meta_key'=>self::SEARCHES,'meta_compare'=>'EXISTS','fields'=>'ID','number'=>100,'offset'=>$offset]);foreach($users as $uid)self::scan((int)$uid);if(count($users)<100)break;}}
}
add_action('rest_api_init',['RVAZ_Wonen_Reader','register'],30);
add_action('rvaz_wonen_search_scan',['RVAZ_Wonen_Reader','cron']);
add_action('init',function(){if(class_exists('RVAZ_Wonen')&&!wp_next_scheduled('rvaz_wonen_search_scan'))wp_schedule_event(time()+60,'hourly','rvaz_wonen_search_scan');});

require_once __DIR__.'/reader-website.php';
