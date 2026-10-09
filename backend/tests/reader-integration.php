<?php
if(!defined('ABSPATH'))exit;
check(call_api('GET','/favorieten')->get_status()===401,'anonymous favorites denied');
check(call_api('GET','/zoekmeldingen')->get_status()===401,'anonymous notices denied');
function reader_property($author,$price='425.000',$place='Rockanje',$status='publish'){
 $id=wp_insert_post(['post_type'=>RVAZ_Wonen::TYPE,'post_status'=>$status,'post_title'=>'CI reader property','post_author'=>$author]);foreach(['prijs'=>$price,'plaats'=>$place,'transactie'=>'Koop','woningtype'=>'Woning','status'=>'Beschikbaar'] as $k=>$v)update_post_meta($id,'_rvaz_wonen_'.$k,$v);return $id;
}
$public_id=reader_property($agent);$private_id=reader_property($agent,'100','Rockanje','draft');
check(call_api('POST','/favorieten',['woning_id'=>$private_id,'saved'=>true],$regular)->get_status()===404,'private listing cannot be favorited');
check(call_api('POST','/favorieten',['woning_id'=>[$public_id],'saved'=>true],$regular)->get_status()===400,'malformed favorite ID rejected');
check(call_api('POST','/favorieten',['woning_id'=>$public_id,'saved'=>true],$regular)->get_status()===200,'ordinary reader can save favorite');
check(count(call_api('POST','/favorieten',['woning_id'=>$public_id,'saved'=>true],$regular)->get_data()['ids'])===1,'favorite save is idempotent');
check(call_api('GET','/favorieten',[],$other)->get_data()['ids']===[],'favorite accounts isolated');
check(call_api('POST','/zoekopdrachten',['enabled'=>true],$regular)->get_status()===400,'empty search rejected');
check(call_api('POST','/zoekopdrachten',['enabled'=>true,'plaats'=>'Rockanje','min_prijs'=>500,'max_prijs'=>100],$regular)->get_status()===400,'inverted prices rejected');
check(call_api('POST','/zoekopdrachten',['enabled'=>true,'plaats'=>'Rockanje','min_prijs'=>'1e999'],$regular)->get_status()===400,'infinite price rejected');
$criteria=['plaats'=>'Rockanje','transactie'=>'Koop','woningtype'=>'Woning','min_prijs'=>400000,'max_prijs'=>450000,'enabled'=>true];
$search=call_api('POST','/zoekopdrachten',$criteria,$regular)->get_data()[0];
check(!isset($search['seen']),'internal search history stays private');
check(call_api('GET','/zoekmeldingen',[],$regular)->get_data()===[],'existing housing stock is not new search alert');
check(call_api('POST','/zoekopdrachten',$criteria+['id'=>$search['id']],$other)->get_status()===404,'foreign search edit denied');
check(call_api('POST','/zoekopdrachten/'.$search['id'].'/verwijderen',[],$other)->get_status()===404,'foreign search deletion denied');
$new_id=reader_property($agent);$nonmatch=reader_property($agent,'350.000');$sold=reader_property($agent);update_post_meta($sold,'_rvaz_wonen_status','Verkocht');
$notices=call_api('GET','/zoekmeldingen',[],$regular)->get_data();
check(count($notices)===1&&$notices[0]['woning_id']===$new_id,'only matching newly published available property alerts');
check(count(call_api('GET','/zoekmeldingen',[],$regular)->get_data())===1,'repeated scan deduplicates notices');
check(call_api('GET','/zoekmeldingen',[],$other)->get_data()===[],'notifications isolated by reader');
check(call_api('POST','/zoekmeldingen',['confirm'=>true],$regular)->get_data()[0]['read']===true,'reader can mark notices read');
check(RVAZ_Wonen_Reader::number('€ 1.299,50 p/m')===1299.5&&RVAZ_Wonen_Reader::number('425.000')===425000.0,'Dutch rental and purchase price matching');
update_user_meta($agent,'rvaz_wonen_blocked','1');
check(call_api('GET','/favorieten',[],$regular)->get_data()['items']===[],'blocked broker listing hidden from favorites');
check(call_api('GET','/zoekmeldingen',[],$regular)->get_data()===[],'blocked broker listing hidden from alerts');delete_user_meta($agent,'rvaz_wonen_blocked');
check(call_api('POST','/favorieten',['woning_id'=>$public_id,'saved'=>false],$regular)->get_data()['ids']===[],'favorite removal persisted');
check(call_api('POST','/zoekopdrachten/'.$search['id'].'/verwijderen',[],$regular)->get_data()===[],'own search deletion persisted');
foreach([$public_id,$private_id,$new_id,$nonmatch,$sold] as $rid)wp_delete_post($rid,true);
