<?php
class RVAZ_App_API {
 static $sent=[],$fail=false,$callback=null;
 static function send_push_target($target,$title,$body,$data=[]){
  self::$sent[]=compact('target','title','body','data');
  if(self::$callback)(self::$callback)();
  return self::$fail?new WP_Error('fcm','Synthetic transport failure'):new WP_REST_Response(['ok'=>true]);
 }
}
require getenv('GITHUB_WORKSPACE').'/backend/rvaz-waste-reminders/rvaz-waste-reminders.php';
function waste_check($ok,$label){if(!$ok)throw new Exception($label);echo 'PASS '.$label."\n";}
add_action('rest_api_init',function(){register_rest_route('rvaz-app/v1','/device',['methods'=>'POST','permission_callback'=>'__return_true','callback'=>fn()=>new WP_REST_Response(['ok'=>true])]);});
function waste_register($token,$bag,$enabled=true){$r=new WP_REST_Request('POST','/rvaz-app/v1/device');$r->set_header('Content-Type','application/json');$r->set_body(wp_json_encode(['token'=>$token,'waste'=>['enabled'=>$enabled,'bag_id'=>$bag]]));return rest_do_request($r)->get_data();}
$calendar_rows=[];$calendar_requests=[];
add_filter('pre_http_request',function($pre,$args,$url)use(&$calendar_rows,&$calendar_requests){
 if(strpos($url,'https://reinis.nl/rest/waste-calendar/dates')!==0)throw new Exception('Unexpected outbound request in waste test');
 parse_str(parse_url($url,PHP_URL_QUERY),$q);$calendar_requests[]=$q;
 return ['headers'=>[],'response'=>['code'=>200,'message'=>'OK'],'body'=>wp_json_encode($calendar_rows[$q['bagId']]??[])];
},10,3);
$token='fictitious-device-token-0000001';$bag='0000000000000001';
$d=waste_register($token,$bag);waste_check($d['waste']['registered']&&$d['waste']['enabled'],'device registration explicitly confirms waste preference');
waste_check($d['waste']['timezone']==='Europe/Amsterdam','Dutch timezone is explicit');
$calendar_rows[$bag]=[['ophaaldatum'=>'2026-12-01','afvalstroom_id'=>2],['ophaaldatum'=>'2026-12-01','afvalstroom_id'=>3]];
RVAZ_Waste_Reminders::process(new DateTimeImmutable('2026-11-30 18:59:00',new DateTimeZone('Europe/Amsterdam')));
waste_check(!RVAZ_App_API::$sent,'no premature morning or afternoon push');
RVAZ_Waste_Reminders::process(new DateTimeImmutable('2026-11-30T18:00:00Z'));
waste_check(count(RVAZ_App_API::$sent)===1,'Dutch 19:00 sends one reminder for tomorrow');
waste_check($calendar_requests[0]['month']==='12'&&$calendar_requests[0]['year']==='2026','month boundary uses tomorrow calendar');
$sent=RVAZ_App_API::$sent[0];waste_check($sent['target']===['token'=>$token]&&!isset($sent['target']['topic']),'reminder is per device, never a broadcast');
waste_check(strpos($sent['body'],'GFT+e en PMD')!==false&&$sent['data']['screen']==='waste','container types are combined and open the native calendar');
RVAZ_Waste_Reminders::process(new DateTimeImmutable('2026-11-30T20:00:00+01:00'));
waste_check(count(RVAZ_App_API::$sent)===1,'repeated cron does not duplicate a successful reminder');
waste_register($token,$bag,false);waste_check(!get_option(RVAZ_Waste_Reminders::OPTION,[]),'opting out removes the server registration');
$token2='fictitious-device-token-0000002';$bag2='0000000000000002';waste_register($token2,$bag2);$calendar_rows[$bag2]=[['ophaaldatum'=>'2026-12-02','afvalstroom_id'=>25]];
RVAZ_App_API::$sent=[];RVAZ_App_API::$fail=true;
RVAZ_Waste_Reminders::process(new DateTimeImmutable('2026-12-01T19:00:00+01:00'));
RVAZ_Waste_Reminders::process(new DateTimeImmutable('2026-12-01T19:05:00+01:00'));
waste_check(count(RVAZ_App_API::$sent)===1,'failed transport respects retry backoff');
RVAZ_App_API::$fail=false;RVAZ_Waste_Reminders::process(new DateTimeImmutable('2026-12-01T19:11:00+01:00'));
waste_check(count(RVAZ_App_API::$sent)===2,'a failed push can be retried successfully');
$health=wp_json_encode(RVAZ_Waste_Reminders::health()->get_data());waste_check(strpos($health,$token2)===false&&strpos($health,$bag2)===false,'diagnostics never disclose tokens or address IDs');
RVAZ_Waste_Reminders::schedule();waste_check((bool)wp_next_scheduled(RVAZ_Waste_Reminders::HOOK),'five minute worker is scheduled');
$bad=waste_register('fictitious-device-token-0000003','not-an-address');waste_check(!$bad['waste']['registered'],'invalid address cannot look registered');
// An opt-out while the transport call is in flight must not be resurrected.
$token3='fictitious-device-token-0000004';$bag3='0000000000000004';waste_register($token3,$bag3);$calendar_rows[$bag3]=[['ophaaldatum'=>'2026-12-03','afvalstroom_id'=>2]];
RVAZ_App_API::$callback=function()use($token3,$bag3){waste_register($token3,$bag3,false);};
RVAZ_Waste_Reminders::process(new DateTimeImmutable('2026-12-02T19:00:00+01:00'));
waste_check(!isset(get_option(RVAZ_Waste_Reminders::OPTION,[])[$token3]),'sending never resurrects a concurrent opt-out');
