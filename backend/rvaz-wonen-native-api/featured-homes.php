<?php
if(!defined('ABSPATH'))exit;
final class RVAZ_Wonen_Featured {
 static function broker_paid($uid){
  global $wpdb;$today=current_time('Y-m-d');
  $sub=$wpdb->get_row($wpdb->prepare("SELECT * FROM {$wpdb->prefix}rvaz_wonen_subscriptions WHERE user_id=%d ORDER BY id DESC LIMIT 1",$uid));
  if(!$sub||$sub->status!=='active'||!$sub->start_date||$sub->start_date>$today||($sub->end_date&&$sub->end_date<$today))return false;
  // A paid invoice must cover the current billing interval, never an old subscription.
  $start=$sub->start_date;
  return (bool)$wpdb->get_var($wpdb->prepare("SELECT id FROM {$wpdb->prefix}rvaz_wonen_invoices WHERE user_id=%d AND status='paid' AND total>0 AND invoice_no NOT LIKE 'RVAZ-P-%%' AND invoice_date>=%s AND invoice_date<=%s LIMIT 1",$uid,$start,$today));
 }
 static function items(){
  $items=[];$paid=[];
  for($page=1;;$page++){
   $query=new WP_Query(['post_type'=>RVAZ_Wonen::TYPE,'post_status'=>'publish','posts_per_page'=>24,'paged'=>$page,'orderby'=>['date'=>'DESC','ID'=>'DESC']]);
   foreach($query->posts as $post){
    if(!RVAZ_Wonen_Reader::visible($post->ID))continue;
    $status=get_post_meta($post->ID,'_rvaz_wonen_status',true);
    if(in_array(strtolower($status),['verkocht','verhuurd'],true))continue;
    if(!RVAZ_Wonen_Private::is_private($post->ID)){
     $uid=(int)$post->post_author;
     if(!array_key_exists($uid,$paid))$paid[$uid]=self::broker_paid($uid);
     if(!$paid[$uid])continue;
    }
    $items[]=RVAZ_Wonen_Native_API::listing($post->ID);
    if(count($items)===6)return $items;
   }
   if($page>=$query->max_num_pages)return $items;
  }
 }
}
add_action('rest_api_init',function(){register_rest_route(RVAZ_Wonen_Native_API::NS,'/uitgelicht',['methods'=>'GET','permission_callback'=>'__return_true','callback'=>['RVAZ_Wonen_Featured','items']]);},30);
