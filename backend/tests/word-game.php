<?php
// Isolated API contract test: real plugin logic, fake WP/session/database boundaries.
define('ABSPATH',__DIR__.'/');
function add_action(...$args){} function add_filter(...$args){} function add_shortcode(...$args){} function register_activation_hook(...$args){}
function current_datetime(){return new DateTimeImmutable('2026-11-17T12:00:00+01:00');}
function wp_timezone(){return new DateTimeZone('Europe/Amsterdam');}
function absint($n){return abs((int)$n);} function sanitize_text_field($s){return trim($s);} function wp_json_encode($d){return json_encode($d);}
$uid=0;$valid_token=true;$blocked=false;
function get_current_user_id(){return $GLOBALS['uid'];} function wp_set_current_user($id){$GLOBALS['uid']=$id;}
function get_userdata($id){return $id?(object)['user_login'=>'speler'.$id]:false;}
function get_user_meta($id,$key,$single){return $key==='_rvaz_member_blocked'&&$GLOBALS['blocked']?'1':'';}
function get_option($key,$default=[]){return ['2026-11-16'=>'strand','2026-11-17'=>'zeeman'];}
function get_post($id){return $id>=10&&$id<=13?(object)['post_type'=>'post','post_status'=>$id===12?'draft':'publish','post_content'=>'[rvaz_woordspel]']:null;}
function get_post_meta($id,$key,$single){return [10=>'2026-11-16',11=>'2026-11-17',12=>'2026-11-17',13=>'2026-11-18'][$id]??'';}
function has_shortcode($s,$code){return str_contains($s,'['.$code.']');}
class WP_Error {function __construct(public $code,public $message,public $data){} function get_error_data(){return $this->data;}}
class WP_REST_Response {public $headers=[];function __construct(public $data,public $status=200){}function get_data(){return $this->data;}function get_status(){return $this->status;}function header($k,$v){$this->headers[$k]=$v;}}
class WP_REST_Request {public $params=[],$headers=[];function __construct(...$args){}function get_header($k){return $this->headers[$k]??'';}function set_header($k,$v){$this->headers[$k]=$v;}function get_param($k){return $this->params[$k]??null;}function set_param($k,$v){$this->params[$k]=$v;}}
function rest_do_request($r){wp_set_current_user(99);return $GLOBALS['valid_token']?new WP_REST_Response(['user'=>['id'=>7]]):new WP_REST_Response([],401);}
class FakeDB {
 public $prefix='wp_', $rows=[];
 function prepare($sql,...$args){return json_encode([$sql,$args]);}
 function get_var($q){return 1;}
 function get_row($q){[$sql,$a]=json_decode($q,true);return isset($this->rows[$a[0].':'.$a[1]])?clone $this->rows[$a[0].':'.$a[1]]:null;}
 function get_results($q){[$sql,$a]=json_decode($q,true);return array_values(array_filter($this->rows,fn($r)=>$r->day===$a[0]));}
 function query($q){[$sql,$a]=json_decode($q,true);if(str_starts_with($sql,'INSERT')){$k=$a[0].':'.$a[1];if(!isset($this->rows[$k]))$this->rows[$k]=(object)['user_id'=>$a[0],'day'=>$a[1],'answer'=>$a[2],'guesses'=>'[]','revision'=>0];return 1;}
  if(str_starts_with($sql,'UPDATE')){$k=$a[1].':'.$a[2];$r=$this->rows[$k]??null;if(!$r||$r->revision!==$a[3])return 0;$r->guesses=$a[0];$r->revision++;return 1;}return 0;}
}
$wpdb=new FakeDB();
require __DIR__.'/../rvaz-woordspel/rvaz-woordspel.php';
function check($yes,$label){if(!$yes)throw new RuntimeException($label);echo "PASS $label\n";}
function req($id,$word=null){$r=new WP_REST_Request();$r->set_param('post_id',$id);$r->set_param('word',$word);return $r;}
$r=req(11);check(RVAZ_Woordspel::app_permission($r)->data['status']===401,'anonymous denied');
$r->set_header('authorization','Bearer test-session');$valid_token=false;check(RVAZ_Woordspel::app_permission($r)->data['status']===401&&$uid===0,'revoked token denied and user restored');
$valid_token=true;$blocked=true;check(RVAZ_Woordspel::app_permission($r)->data['status']===403,'blocked member denied');
$blocked=false;check(RVAZ_Woordspel::app_permission($r)===true&&$uid===7,'existing App API selects real account');
foreach([0,12,13,999] as $id)check(RVAZ_Woordspel::app_state(req($id))->data['status']===404,'unpublished or invalid day denied '.$id);
$initial=RVAZ_Woordspel::app_state(req(10));check($initial->data['answer']===null,'answer hidden before completion');check($initial->headers['Cache-Control']==='private, no-store','private response not cached');
$won=RVAZ_Woordspel::app_guess(req(10,'strand'));check($won->data['won']===true&&count($won->data['rows'])===1,'old article uses its own word');
$today=RVAZ_Woordspel::app_state(req(11));check($today->data['rows']===[]&&$today->data['ranking']===[],'daily attempts and rankings isolated');
foreach(['aaaaaa','bbbbbb','cccccc','dddddd','eeeeee','ffffff'] as $word)$last=RVAZ_Woordspel::app_guess(req(11,$word));
check($last->data['done']&&$last->data['remaining']===0,'six attempts enforced');
$seventh=RVAZ_Woordspel::app_guess(req(11,'zeeman'));check(!$seventh->data['won']&&count($seventh->data['rows'])===6,'seventh attempt rejected by server');
check(RVAZ_Woordspel::score('aaaaaa','banane')===['absent','correct','absent','correct','absent','absent'],'repeated letters consume only available occurrences');
wp_set_current_user(8);check(RVAZ_Woordspel::app_state(req(11))->data['rows']===[],'different members cannot see each others guesses');
echo "Word game API checks passed\n";
