<?php
add_filter('pre_wp_mail','__return_true');
function word_check($ok,$label){if(!$ok)throw new RuntimeException($label);echo "PASS $label\n";}
$a=wp_insert_user(['user_login'=>'word-player-a','user_pass'=>wp_generate_password(),'user_email'=>'a@example.invalid']);
$b=wp_insert_user(['user_login'=>'word-player-b','user_pass'=>wp_generate_password(),'user_email'=>'b@example.invalid']);
$tokens=['Bearer SESSION_A'=>$a,'Bearer SESSION_B'=>$b];
add_action('rest_api_init',function()use(&$tokens){register_rest_route('rvaz-app/v1','/me',['methods'=>'GET','permission_callback'=>'__return_true','callback'=>function($r)use(&$tokens){$id=$tokens[$r->get_header('authorization')]??0;return $id?['user'=>['id'=>$id]]:new WP_Error('expired','Session rejected',['status'=>401]);}]);});
$today=RVAZ_Woordspel::today();$yesterday=current_datetime()->modify('-1 day')->format('Y-m-d');
$future=current_datetime()->modify('+1 day')->format('Y-m-d');
$posts=[];
foreach([[$yesterday,'strand','publish'],[$today,'zeeman','publish'],[$future,'straks','publish'],[$today,'straks','draft']] as [$date,$answer,$status]){
 $posts[]=wp_insert_post(['post_title'=>'CI dagspel','post_type'=>'post','post_status'=>$status,'post_content'=>'Openbare intro [rvaz_woordspel]','meta_input'=>['_rvaz_word_day'=>$date,'_rvaz_word_answer'=>$answer]]);
}
update_option(RVAZ_Woordspel::OPT,[$yesterday=>'strand',$today=>'zeeman']);
function word_call($method,$post,$token='SESSION_A',$word=null){wp_set_current_user(0);$r=new WP_REST_Request($method,'/rvaz-woord/v1/app/'.($method==='GET'?'state':'guess'));if($token)$r->set_header('authorization','Bearer '.$token);$r->set_param('post_id',$post);if($word!==null)$r->set_param('word',$word);return rest_do_request($r);}
word_check(word_call('GET',$posts[1],null)->get_status()===401,'anonymous cannot fetch game state');
word_check(word_call('GET',$posts[1],'EXPIRED')->get_status()===401,'expired session denied');
foreach([$posts[2],$posts[3],999999] as $p)word_check(word_call('GET',$p)->get_status()===404,'unavailable article denied '.$p);
$one=word_call('POST',$posts[0],'SESSION_A','strand');word_check($one->get_status()===200&&$one->get_data()['won'],'published older article retains its own word');
word_check(count(word_call('GET',$posts[0])->get_data()['rows'])===1,'saved website/app round can be restored');
word_check(word_call('GET',$posts[1])->get_data()['rows']===[],'today starts independently');
word_check(word_call('GET',$posts[0],'SESSION_B')->get_data()['rows']===[],'other account cannot see guesses');
foreach(['aaaaaa','bbbbbb','cccccc','dddddd','eeeeee','ffffff'] as $word)$last=word_call('POST',$posts[1],'SESSION_A',$word);
word_check($last->get_status()===200&&$last->get_data()['remaining']===0,'real DB enforces six attempts');
$last=word_call('POST',$posts[1],'SESSION_A','zeeman');word_check(!$last->get_data()['won']&&count($last->get_data()['rows'])===6,'seventh guess does not change result');
$state=word_call('GET',$posts[0],'SESSION_B')->get_data();word_check($state['answer']===null&&$state['ranking'][0]['name']==='word-player-a','ranking uses usernames and hides unfinished answer');
unset($tokens['Bearer SESSION_A']);word_check(word_call('GET',$posts[1])->get_status()===401,'revoked session no longer works');
update_user_meta($b,'_rvaz_member_blocked','1');word_check(word_call('GET',$posts[1],'SESSION_B')->get_status()===403,'blocked member denied');
echo "Real WordPress/database word game checks passed\n";
