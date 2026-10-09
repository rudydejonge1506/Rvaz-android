<?php
if(!defined('ABSPATH'))exit;
add_action('wp_enqueue_scripts',function(){
 if(!is_page(['mijn-wonen','mijn-account']))return;
 wp_enqueue_script('rvaz-housing-fields',plugins_url('housing-fields.js',__FILE__),[], '1.0.2',true);
 wp_register_style('rvaz-housing-fields',false,[], '1.0.2');wp_enqueue_style('rvaz-housing-fields');
 wp_add_inline_style('rvaz-housing-fields','[data-rvaz-housing-hidden]{display:none!important}');
},1000);
