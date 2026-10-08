<?php
// Installed only into disposable CI mu-plugins. Never shipped in the API ZIP.
add_action('rest_api_init',function(){
 register_rest_route('rvaz-app/v1','/me',['methods'=>'GET','permission_callback'=>'__return_true','callback'=>function($r){
  if($r->get_header('authorization')!=='Bearer VALID_APP_TOKEN')return new WP_Error('invalid','Test token rejected',['status'=>401]);
  $u=get_user_by('login','agent-a');return ['user'=>['id'=>$u->ID]];
 }],30);
},30);
