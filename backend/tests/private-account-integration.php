<?php
if(!defined('ABSPATH'))exit;
wp_set_current_user($seller);$_GET['rvaz_wonen']='particulier';
$account='<div class="rvaz-account-wrap"><nav class="rvaz-account-nav"><a class="is-active" href="?tab=overzicht">Overzicht</a><a href="?tab=profiel">Profiel</a></nav><div class="rvaz-account-content"><h2>Overzicht</h2><input name="old-form"></div></div>';
$integrated=RVAZ_Wonen_Private_Account::integrate($account,'rvaz_member_account');
check(strpos($integrated,'rvaz-private-root')!==false&&strpos($integrated,'old-form')===false,'private housing panel replaces only selected account content');
check(strpos($integrated,'?tab=profiel')!==false&&strpos($integrated,'Mijn Wonen')!==false,'private account panel preserves existing profile navigation');
check(strpos($integrated,'aria-current="page"')!==false,'private account menu marks active housing section');
unset($_GET['rvaz_wonen']);$overview=RVAZ_Wonen_Private_Account::integrate($account,'rvaz_member_account');check(strpos($overview,'old-form')!==false&&strpos($overview,'rvaz-private-root')===false,'ordinary account overview and forms remain unchanged');
wp_set_current_user(0);check(RVAZ_Wonen_Private_Account::integrate($account,'rvaz_member_account')===$account,'anonymous account view does not expose private management');
$public=apply_filters('do_shortcode_tag','Public stock','rvaz_wonen');check(strpos($public,'rvaz-private-root')===false&&strpos($public,RVAZ_Wonen_Private_Account::url())!==false,'public housing page links to account instead of separate private editor');
