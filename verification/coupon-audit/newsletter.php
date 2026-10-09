<?php
if(!defined('ABSPATH'))exit;
$mail_calls=0;
add_filter('pre_wp_mail',function()use(&$mail_calls){$mail_calls++;return true;},-999);
require dirname(__DIR__,2).'/website/newsletter-source/rvaz-nieuwsbrief/rvaz-nieuwsbrief.php';
$reflection=new ReflectionClass('RVAZ_Nieuwsbrief_144');$newsletter=$reflection->newInstanceWithoutConstructor();
function nl_call($method,...$args){global $reflection,$newsletter;return $reflection->getMethod($method)->invoke($newsletter,...$args);}
function nl_check($ok,$message){if(!$ok)throw new RuntimeException($message);echo "PASS: $message\n";}
$newsletter->activate();nl_call('ensure_queue_schema');nl_call('ensure_recipients_schema');
$broker=nl_call('wonen_makelaars_template_html');$block=nl_call('wonen_email_html');$regular=nl_call('newsletter_html',true,[]);
foreach(['MAKELAAR','50% korting','eerste twee verschillende','Basis, Plus en Pro','€ 0,00','vóór het versturen','Vanaf maand twee','niet stapelbaar','opzeggen','veel gedownloade RVAZ-app','website én app','Mijn Wonen → Makelaar aanmelden'] as $text)nl_check(strpos($broker,$text)!==false,'broker invitation includes '.$text);
nl_check(strpos($broker,'handmatige verwerking')===false,'old manual-processing instruction absent');
foreach(['/wonen-voor-makelaars/','/wonen-tarieven/'] as $link)nl_check(strpos($broker,$link)!==false,'broker CTA '.$link);
nl_check(substr_count($regular,'Wonen op Voorne')===1,'regular newsletter includes one Wonen block');
nl_check(strpos($regular,'veel gedownloade RVAZ-app')!==false&&strpos($regular,'makelaars én particulieren')!==false,'regular Wonen block explains website/app and both audiences');
nl_check(strpos($block,'MAKELAAR')===false,'exclusive broker coupon not inserted into regular Wonen block');
nl_check(strpos($regular,'{{unsubscribe}}')!==false,'regular unsubscribe placeholder preserved');
file_put_contents('/tmp/rvaz-newsletter-broker.html',$broker);file_put_contents('/tmp/rvaz-newsletter-regular.html',$regular);
// Real disposable database checks: no production contacts and no delivery.
global $wpdb;$st=$wpdb->prefix.'rvaz_newsletter_subscribers';$mt=$wpdb->prefix.'rvaz_newsletter_mailings';$rt=$wpdb->prefix.'rvaz_newsletter_recipients';
foreach([['regular@example.invalid','Lezers'],['broker-a@example.invalid','Makelaars'],['broker-b@example.invalid','Makelaars']] as [$email,$list])$wpdb->insert($st,['email'=>$email,'status'=>'confirmed','lists'=>$list,'created_at'=>current_time('mysql'),'unsub_token'=>hash('sha256',$email)]);
$automatic=nl_call('create_mailing');nl_check($automatic>0,'automatic mailing snapshot created in disposable database');
$emails=$wpdb->get_col($wpdb->prepare("SELECT email FROM $rt WHERE mailing_id=%d",$automatic));
nl_check($emails===['regular@example.invalid'],'Makelaars list excluded from automatic newsletter creation');
nl_call('sync_mailing_recipients',$automatic);$emails=$wpdb->get_col($wpdb->prepare("SELECT email FROM $rt WHERE mailing_id=%d",$automatic));
nl_check($emails===['regular@example.invalid'],'Makelaars remain excluded during recipient synchronization');
$newsletter->worker_tick();$newsletter->queue_worker();nl_check($mail_calls===0,'unauthorized automatic snapshot sends no mail');
$wpdb->update($mt,['status'=>'completed','sent_count'=>1],['id'=>$automatic]);
$old='<h1>Nieuw: RVAZ Wonen op Voorne aan Zee</h1><p>MAKELAAR</p>{{unsubscribe}}';
foreach([[21,'paused',0],[22,'completed',1]] as [$id,$status,$sent])$wpdb->insert($mt,['id'=>$id,'subject'=>'Nieuw: RVAZ Wonen voor makelaars op Voorne aan Zee','sent_at'=>current_time('mysql'),'status'=>$status,'sent_count'=>$sent,'failed_count'=>0,'total_count'=>2,'mailing_type'=>'custom','target_list'=>'Makelaars','content_html'=>$old]);
$brokers=$wpdb->get_results("SELECT id,email,unsub_token FROM $st WHERE lists='Makelaars'");foreach($brokers as $sub)$wpdb->insert($rt,['mailing_id'=>21,'subscriber_id'=>$sub->id,'email'=>$sub->email,'unsub_token'=>$sub->unsub_token,'status'=>'pending']);
$before=$wpdb->get_results("SELECT * FROM $rt WHERE mailing_id=21",ARRAY_A);
nl_call('refresh_wonen_drafts');$draft=$wpdb->get_row("SELECT * FROM $mt WHERE id=21");
nl_check($draft->status==='paused'&&(int)$draft->sent_count===0&&(int)$draft->total_count===2&&$draft->target_list==='Makelaars','improved existing broker draft preserves pause, counters and list');
nl_check(strpos($draft->content_html,'Zo wisselt u de korting in')!==false&&strpos($draft->content_html,'{{unsubscribe}}')!==false,'old broker draft upgraded with new template and actual unsubscribe placeholder');
nl_check($before===$wpdb->get_results("SELECT * FROM $rt WHERE mailing_id=21",ARRAY_A),'draft update leaves recipient snapshot unchanged');
nl_check($wpdb->get_var("SELECT content_html FROM $mt WHERE id=22")===$old,'already sent broker invitation unchanged');
nl_call('refresh_wonen_drafts');nl_check($wpdb->get_var("SELECT content_html FROM $mt WHERE id=21")===$draft->content_html,'draft refresh idempotent');
$newsletter->worker_tick();$newsletter->queue_worker();nl_check($mail_calls===0,'paused broker mailing sends zero email');
echo "All actual newsletter template, recipient and no-mail checks passed.\n";
