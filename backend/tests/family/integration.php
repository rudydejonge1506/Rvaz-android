<?php
// Disposable WordPress integration: deliberately fictitious test data only.
class RVAZ_Family {
 const TYPE='rvaz_family';
 static function kinds(){return ['geboorte'=>'Geboorte','herinnering'=>'Overlijden','jubileum'=>'Jubilea','felicitatie'=>'Felicitaties'];}
 static function backgrounds(){return array_fill_keys(['papier','bloesem','duinen','hemel','goud','klassiek'],1);}
 static function style($id){$d=[];foreach(['kind','background','font','align','layout'] as $k)$d[$k]=get_post_meta($id,'_rf_'.$k,true);return $d;}
 static function image_url($id){return 'https://example.invalid/image/'.$id;}
}
class RVAZ_Wonen_Native_API {
 static function authenticated($r){return get_current_user_id()?true:new WP_Error('auth','Log in',['status'=>401]);}
}
register_post_type('rvaz_family',['public'=>true]);
require getenv('GITHUB_WORKSPACE').'/backend/rvaz-family-native-api.php';
function check_family($ok,$label){if(!$ok)throw new Exception($label);echo 'PASS '.$label."\n";}
function request_family($method,$path,$data=[]){$r=new WP_REST_Request($method,'/rvaz-family/v1'.$path);$r->set_body_params($data);return rest_do_request($r);}
$a=wp_create_user('family_one','fictitious-only','family1@example.invalid');
$b=wp_create_user('family_two','fictitious-only','family2@example.invalid');
$fields=['title'=>'Fictieve familie Voorbeeld','message'=>'Uitsluitend testgegevens.','kind'=>'geboorte','background'=>'bloesem','font'=>'serif','align'=>'center','layout'=>'card','place'=>'Brielle','permission'=>'1','request_id'=>'fictitious-request-0001','post_status'=>'publish','post_author'=>$b];
wp_set_current_user(0);
check_family(request_family('GET','/mine')->get_status()===401,'anonymous mine denied');
check_family(request_family('POST','/notices',$fields)->get_status()===401,'anonymous submit denied');
wp_set_current_user($a);
check_family(request_family('POST','/notices',array_merge($fields,['permission'=>'0']))->get_status()===400,'consent required');
check_family(request_family('POST','/notices',array_merge($fields,['background'=>'invalid']))->get_status()===400,'enum validated');
check_family(request_family('POST','/notices',array_merge($fields,['layout'=>'image']))->get_status()===400,'full card requires image');
$r=request_family('POST','/notices',$fields);check_family($r->get_status()===200,'authenticated submission accepted');
$id=$r->get_data()['id'];$p=get_post($id);
check_family($p->post_status==='pending'&&(int)$p->post_author===$a,'client cannot publish or impersonate another author');
check_family(request_family('POST','/notices',$fields)->get_data()['id']===$id,'retry is idempotent');
update_post_meta($id,'_rf_image','private-preview');update_post_meta($id,'_rf_has_image',1);
$own=request_family('GET','/mine')->get_data();check_family(count($own['items'])===1&&$own['items'][0]['image_base64']==='private-preview','owner receives pending preview');
wp_set_current_user(0);$public=request_family('GET','/notices')->get_data();check_family(!$public['items'],'pending excluded from public list');
wp_set_current_user($b);check_family(!request_family('GET','/mine')->get_data()['items'],'other account has no private preview');
check_family(request_family('DELETE','/notices/'.$id)->get_status()===403,'other account cannot delete');
wp_update_post(['ID'=>$id,'post_status'=>'publish']);
wp_set_current_user(0);$public=request_family('GET','/notices')->get_data()['items'];check_family(count($public)===1&&!isset($public[0]['image_base64'])&&!isset($public[0]['status']),'public list excludes private metadata');
wp_set_current_user($a);check_family(request_family('DELETE','/notices/'.$id)->get_status()===200&&get_post_status($id)==='trash','owner removal uses trash');
