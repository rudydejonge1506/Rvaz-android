<?php
if(!defined('ABSPATH'))exit;
final class RVAZ_Wonen_Private_UI {
 static function save($r,$callback=null){
  $id=absint($r['id']);$transaction=$r->has_param('transactie')?$r['transactie']:($id?get_post_meta($id,'_rvaz_wonen_transactie',true):'Koop');
  if(!$transaction)$transaction='Koop';
  if(!is_string($transaction)||!in_array($transaction,['Koop','Huur'],true))return RVAZ_Wonen_Native_API::error('transaction','Kies koop of huur.');
  // Keep the owning plugin's ownership, draft, field and listing-limit checks.
  $copy=clone $r;$copy->set_param('transactie','Koop');
  $result=call_user_func($callback?:['RVAZ_Wonen_Private','save'],$copy);
  if(is_wp_error($result))return $result;
  update_post_meta($result['id'],'_rvaz_wonen_transactie',$transaction);
  return RVAZ_Wonen_Native_API::listing($result['id'],true);
 }
}
add_filter('rest_endpoints',function($routes){
 foreach($routes as $path=>&$endpoints){if(!preg_match('#^/rvaz-wonen/v1/particulier/woningen(?:/\(\?P<id>.+)?$#',$path))continue;
  foreach($endpoints as &$endpoint)if(is_array($endpoint)&&isset($endpoint['callback'])&&$endpoint['callback']===['RVAZ_Wonen_Private','save'])$endpoint['callback']=['RVAZ_Wonen_Private_UI','save'];unset($endpoint);
 }unset($endpoints);return $routes;
},100);
add_action('wp_enqueue_scripts',function(){
 if(!class_exists('RVAZ_Wonen_Private')||!is_page(['account','mijn-account','mijn-rvaz']))return;
 // Keep the original handle and inline API/nonce configuration; replace only its asset URL.
 $scripts=wp_scripts();if(isset($scripts->registered['rvaz-private'])){$scripts->registered['rvaz-private']->src=plugins_url('private-website.js',__FILE__);$scripts->registered['rvaz-private']->ver='1.0.1';}
 wp_enqueue_style('rvaz-private-account-fix',plugins_url('private-website.css',__FILE__),[],'1.0.1');
},999);
