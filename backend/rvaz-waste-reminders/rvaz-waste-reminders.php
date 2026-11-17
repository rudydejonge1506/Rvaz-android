<?php
/**
 * Plugin Name: RVAZ Afvalherinneringen
 * Description: Persoonlijke afvalpush op de avond vóór inzameling, via de bestaande App API.
 * Version: 1.0.0
 */
defined('ABSPATH') || exit;
final class RVAZ_Waste_Reminders {
 const OPTION='rvaz_app_waste_devices';
 const HOOK='rvaz_waste_reminders_tick';
 const ZONE='Europe/Amsterdam';
 static function init(){
  add_filter('cron_schedules',function($s){$s['rvaz_waste_five_minutes']=['interval'=>300,'display'=>'RVAZ afval elke vijf minuten'];return $s;});
  add_action('init',[__CLASS__,'schedule']);
  add_action(self::HOOK,[__CLASS__,'tick']);
  add_action('rvaz_app_p2000_poll',[__CLASS__,'tick'],99);
  add_filter('rest_request_after_callbacks',[__CLASS__,'registered'],30,3);
  add_action('rest_api_init',function(){register_rest_route('rvaz-waste/v1','/health',['methods'=>'GET','permission_callback'=>fn()=>current_user_can('manage_options'),'callback'=>[__CLASS__,'health']]);});
 }
 static function schedule(){if(!wp_next_scheduled(self::HOOK))wp_schedule_event(time()+60,'rvaz_waste_five_minutes',self::HOOK);}
 static function registered($response,$handler,$request){
  if($request->get_route()!=='/rvaz-app/v1/device'||$request->get_method()!=='POST'||is_wp_error($response)||!($response instanceof WP_HTTP_Response)||$response->get_status()<200||$response->get_status()>=300)return $response;
  $p=$request->get_json_params();if(!is_array($p)||!array_key_exists('waste',$p))return $response;
  $token=$p['token']??$p['device_token']??$p['fcm_token']??'';
  if(!is_string($token)||strlen($token)<20||strlen($token)>4096||preg_match('/\s/',$token))return $response;
  $in=is_array($p['waste'])?$p['waste']:[];$enabled=($in['enabled']??false)===true||($in['enabled']??false)===1;
  $bag=$in['bag_id']??'';$valid=is_string($bag)&&preg_match('/^[0-9]{10,24}$/D',$bag);
  $data=$response->get_data();if(!is_array($data))return $response;
  $receipt=['registered'=>!$enabled||$valid,'enabled'=>$enabled&&$valid,'reminder'=>'evening_before','hour'=>19,'timezone'=>self::ZONE];
  if($enabled&&!$valid){$receipt['error']='Laad eerst een geldig adres en de afvalkalender.';$data['waste']=$receipt;$response->set_data($data);return $response;}
  $devices=(array)get_option(self::OPTION,[]);
  if($enabled){
   $old=$devices[$token]??[];$same=($old['bag_id']??'')===$bag;
   $devices[$token]=['bag_id'=>$bag,'updated'=>time(),'sent'=>$same?($old['sent']??[]):[],'attempts'=>$same?($old['attempts']??[]):[]];
  }else unset($devices[$token]);
  foreach($devices as $key=>$device)if(($device['updated']??0)<time()-90*DAY_IN_SECONDS)unset($devices[$key]);
  if(count($devices)>5000)$devices=array_slice($devices,-5000,null,true);
  update_option(self::OPTION,$devices,false);
  $stored=(array)get_option(self::OPTION,[]);$receipt['registered']=$enabled?(($stored[$token]['bag_id']??'')===$bag):!isset($stored[$token]);
  $data['waste']=$receipt;$response->set_data($data);$response->header('Cache-Control','private, no-store');
  return $response;
 }
 static function calendar($bag,DateTimeImmutable $date){
  $key='rvaz_waste_'.hash('sha256',$bag.'|'.$date->format('Y-m'));
  $cached=get_transient($key);if(is_array($cached))return $cached;
  $url=add_query_arg(['bagId'=>$bag,'month'=>(int)$date->format('n'),'year'=>(int)$date->format('Y')],'https://reinis.nl/rest/waste-calendar/dates');
  $r=wp_remote_get($url,['timeout'=>8,'limit_response_size'=>1024*1024,'headers'=>['Accept'=>'application/json']]);
  if(is_wp_error($r)||wp_remote_retrieve_response_code($r)!==200)return new WP_Error('waste_calendar','Afvalkalender tijdelijk niet beschikbaar.');
  $rows=json_decode(wp_remote_retrieve_body($r),true);
  if(!is_array($rows)||!array_is_list($rows))return new WP_Error('waste_calendar','Onbekende reactie van de afvalkalender.');
  set_transient($key,$rows,HOUR_IN_SECONDS);return $rows;
 }
 static function names_for_date($rows,$date){
  $labels=[2=>'GFT+e',3=>'PMD',4=>'oud papier en karton',25=>'restafval'];$names=[];
  foreach($rows as $row){if(!is_array($row)||substr((string)($row['ophaaldatum']??''),0,10)!==$date)continue;
   $id=(int)($row['afvalstroom_id']??$row['afvalstroomId']??0);$names[]=$labels[$id]??'afval';
  }
  return array_values(array_unique($names));
 }
 static function tick(){self::process(new DateTimeImmutable('now',new DateTimeZone(self::ZONE)));}
 static function process(DateTimeImmutable $clock){
  $now=$clock->setTimezone(new DateTimeZone(self::ZONE));
  $report=['last_run'=>time(),'checked'=>0,'sent'=>0,'failed'=>0,'calendar_errors'=>0,'timezone'=>self::ZONE];
  // Never send a morning reminder or use the server's UTC hour as Dutch time.
  if((int)$now->format('G')<19){$report['window']='before_evening';update_option('rvaz_waste_last_run',$report,false);return $report;}
  $lock='rvaz_waste_worker_lock';$old=(int)get_option($lock,0);if($old&&$old<time()-300)delete_option($lock);
  if(!add_option($lock,time(),'','no'))return $report;
  try{
   $target=$now->modify('+1 day');$date=$target->format('Y-m-d');$devices=(array)get_option(self::OPTION,[]);$changed=false;$started=microtime(true);
   $keys=array_keys($devices);$count=count($keys);$offset=$count?((int)get_option('rvaz_waste_cursor',0)%$count):0;$visited=0;
   for($index=0;$index<$count;$index++){
    if(microtime(true)-$started>20)break;
    $token=$keys[($offset+$index)%$count];$device=&$devices[$token];$visited++;
    if(($device['updated']??0)<time()-90*DAY_IN_SECONDS)continue;
    if(isset($device['sent'][$date]))continue;
    $attempt=$device['attempts'][$date]??[];
    if(($attempt['count']??0)>=3||($attempt['next']??0)>$now->getTimestamp())continue;
    $report['checked']++;
    $rows=self::calendar($device['bag_id'],$target);if(is_wp_error($rows)){$report['calendar_errors']++;continue;}
    $names=self::names_for_date($rows,$date);if(!$names)continue;
    $device['attempts'][$date]=['count'=>(int)($attempt['count']??0)+1,'next'=>$now->getTimestamp()+10*MINUTE_IN_SECONDS];$changed=true;
    if(!is_callable(['RVAZ_App_API','send_push_target'])){$report['failed']++;continue;}
    wp_cache_delete(self::OPTION,'options');$current=(array)get_option(self::OPTION,[]);
    if(!isset($current[$token])||$current[$token]['bag_id']!==$device['bag_id'])continue;
    $result=RVAZ_App_API::send_push_target(['token'=>$token],'Afvalherinnering','Morgen wordt '.implode(' en ',$names).' opgehaald. Zet je container op tijd klaar.',['type'=>'waste','screen'=>'waste','date'=>$date]);
    if(is_wp_error($result)){$report['failed']++;continue;}
    $device['sent'][$date]=$now->getTimestamp();$report['sent']++;
    foreach(['sent','attempts'] as $field)foreach((array)($device[$field]??[]) as $day=>$unused)if($day<$now->modify('-14 days')->format('Y-m-d'))unset($device[$field][$day]);
   }
   unset($device);
   if($count)update_option('rvaz_waste_cursor',($offset+$visited)%$count,false);
   if($changed){
    wp_cache_delete(self::OPTION,'options');$latest=(array)get_option(self::OPTION,[]);
    foreach($devices as $token=>$record){if(!isset($latest[$token])||$latest[$token]['bag_id']!==$record['bag_id'])continue;
     foreach(['sent','attempts'] as $field)$latest[$token][$field]=array_replace((array)($latest[$token][$field]??[]),(array)($record[$field]??[]));
    }
    update_option(self::OPTION,$latest,false);
   }
   update_option('rvaz_waste_last_run',$report,false);return $report;
  }finally{delete_option($lock);}
 }
 static function health(){
  $result=['version'=>'1.0.0','timezone'=>self::ZONE,'hour'=>19,'registered_devices'=>count((array)get_option(self::OPTION,[])),
   'next_cron'=>wp_next_scheduled(self::HOOK)?:0,'transport_ready'=>is_callable(['RVAZ_App_API','send_push_target']),
   'last_run'=>get_option('rvaz_waste_last_run',[])];
  $r=new WP_REST_Response($result);$r->header('Cache-Control','private, no-store');return $r;
 }
}
RVAZ_Waste_Reminders::init();
