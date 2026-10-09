<?php
if(!defined('ABSPATH'))exit;
// Extend the existing broker wizard and public housing filters, retaining the original form handlers.
add_filter('do_shortcode_tag',function($html,$tag){
 if(!in_array($tag,['rvaz_wonen','rvaz_wonen_portal'],true))return $html;
 return preg_replace_callback('#(<select\b[^>]*\bname=["\x27]woningtype["\x27][^>]*>)(.*?)(</select>)#is',function($m){
  $options=$m[2];foreach(['Kamer','Studio'] as $type)if(!preg_match('#value=["\x27]'.preg_quote($type,'#').'["\x27]#i',$options))$options.='<option value="'.$type.'"'.selected(($_GET['wonen_woningtype']??''),$type,false).'>'.$type.'</option>';
  return $m[1].$options.$m[3];
 },$html);
},80,2);
