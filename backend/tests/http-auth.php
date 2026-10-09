<?php
// Installed only into disposable CI mu-plugins. Never shipped in the API ZIP.
add_action('rest_api_init',function(){
 register_rest_route('rvaz-app/v1','/me',['methods'=>'GET','permission_callback'=>'__return_true','callback'=>function($r){
  $users=['Bearer VALID_APP_TOKEN'=>'agent-a','Bearer VALID_PRIVATE_TOKEN'=>'private-seller'];
  $header=$r->get_header('authorization');
  if(!isset($users[$header]))return new WP_Error('invalid','Test token rejected',['status'=>401]);
  $u=get_user_by('login',$users[$header]);return ['user'=>['id'=>$u->ID]];
 }],30);
},30);
