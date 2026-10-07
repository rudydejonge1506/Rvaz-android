<?php
/**
 * Plugin Name: RVAZ Wonen
 * Description: Zelfstandige woningmodule voor Regio Voorne aan Zee.
 * Version: 0.1.0
 */
if (!defined('ABSPATH')) exit;

final class RVAZ_Wonen {
 const TYPE='rvaz_woning';
 const ROLE='rvaz_makelaar';
 const NS='rvaz-wonen/v1';

 static function init(){
  add_action('init',[__CLASS__,'register']);
  add_action('rest_api_init',[__CLASS__,'rest']);
  add_shortcode('rvaz_wonen',[__CLASS__,'shortcode']);
  add_filter('template_include',[__CLASS__,'template']);
 }
 static function activate(){
  add_role(self::ROLE,'RVAZ Makelaar',['read'=>true,'upload_files'=>true]);
  self::register(); flush_rewrite_rules();
 }
 static function deactivate(){ flush_rewrite_rules(); }

 static function register(){
  register_post_type(self::TYPE,[
   'labels'=>['name'=>'RVAZ Wonen','singular_name'=>'Woning','add_new_item'=>'Nieuwe woning'],
   'public'=>true,'show_in_rest'=>true,'has_archive'=>'wonen','rewrite'=>['slug'=>'wonen'],
   'menu_icon'=>'dashicons-admin-home','supports'=>['title','editor','thumbnail','author']
  ]);
  foreach(['koop','huur','nieuwbouw','bedrijfspand'] as $tax){
   register_taxonomy('rvaz_'.$tax,self::TYPE,['label'=>ucfirst($tax),'public'=>true,'show_in_rest'=>true]);
  }
 }

 static function fields($id){
  $keys=['adres','postcode','plaats','prijs','woningtype','status','slaapkamers','woonoppervlak','perceel','energielabel','makelaar_url','featured','lat','lng'];
  $out=['id'=>$id,'title'=>get_the_title($id),'description'=>apply_filters('the_content',get_post_field('post_content',$id)),'url'=>get_permalink($id),'image'=>get_the_post_thumbnail_url($id,'large') ?: ''];
  foreach($keys as $k) $out[$k]=get_post_meta($id,'_rvaz_wonen_'.$k,true);
  $out['gallery']=array_values(array_filter((array)get_post_meta($id,'_rvaz_wonen_gallery',true)));
  return $out;
 }
 static function list_rest($req){
  $args=['post_type'=>self::TYPE,'post_status'=>'publish','posts_per_page'=>min(100,max(1,(int)($req['per_page']?:30)))];
  if(!empty($req['search'])) $args['s']=sanitize_text_field($req['search']);
  if(!empty($req['plaats'])) $args['meta_query']=[['key'=>'_rvaz_wonen_plaats','value'=>sanitize_text_field($req['plaats']),'compare'=>'LIKE']];
  return array_map([__CLASS__,'fields'],get_posts($args));
 }
 static function detail_rest($req){
  $id=(int)$req['id']; if(get_post_type($id)!==self::TYPE) return new WP_Error('not_found','Woning niet gevonden',['status'=>404]);
  return self::fields($id);
 }
 static function me(){
  if(!is_user_logged_in()) return new WP_Error('unauthorized','Inloggen vereist',['status'=>401]);
  $u=wp_get_current_user();
  return ['user_id'=>$u->ID,'makelaar'=>in_array(self::ROLE,(array)$u->roles,true),'name'=>$u->display_name];
 }
 static function rest(){
  register_rest_route(self::NS,'/woningen',['methods'=>'GET','callback'=>[__CLASS__,'list_rest'],'permission_callback'=>'__return_true']);
  register_rest_route(self::NS,'/woningen/(?P<id>\d+)',['methods'=>'GET','callback'=>[__CLASS__,'detail_rest'],'permission_callback'=>'__return_true']);
  register_rest_route(self::NS,'/makelaar/me',['methods'=>'GET','callback'=>[__CLASS__,'me'],'permission_callback'=>'__return_true']);
 }

 static function shortcode(){
  $q=new WP_Query(['post_type'=>self::TYPE,'post_status'=>'publish','posts_per_page'=>24]);
  ob_start(); ?>
  <div class="rvaz-wonen">
   <section class="rvaz-hero"><h1>Wonen op Voorne</h1><p>Vind koopwoningen, huurwoningen, nieuwbouw en bedrijfspanden op Voorne aan Zee.</p>
    <form method="get"><input name="s" value="<?php echo esc_attr(get_query_var('s')); ?>" placeholder="Plaats, straat of postcode..."><button>Zoeken</button></form>
   </section>
   <nav class="rvaz-filters"><span>Alle</span><span>Koop</span><span>Huur</span><span>Nieuwbouw</span><span>Bedrijfspanden</span></nav>
   <h2>Nieuw op Voorne</h2><div class="rvaz-grid">
   <?php while($q->have_posts()):$q->the_post();$d=self::fields(get_the_ID()); ?>
    <a class="rvaz-card" href="<?php the_permalink(); ?>"><?php if($d['image']): ?><img src="<?php echo esc_url($d['image']); ?>"><?php endif; ?><div><strong><?php the_title(); ?></strong><p><?php echo esc_html($d['plaats']); ?></p><b><?php echo esc_html($d['prijs']); ?></b><small><?php echo esc_html($d['slaapkamers']); ?> slaapkamers · <?php echo esc_html($d['woonoppervlak']); ?> m²</small></div></a>
   <?php endwhile;wp_reset_postdata(); ?></div>
  </div>
  <style>
  .rvaz-wonen{max-width:1180px;margin:auto;padding:24px;color:#073b63}.rvaz-hero{background:#eaf5fb;border-radius:18px;padding:42px}.rvaz-hero h1{font-size:44px;margin:0 0 8px}.rvaz-hero form{display:flex;gap:8px;max-width:700px}.rvaz-hero input{flex:1;padding:14px;border:1px solid #d6e1e8;border-radius:9px}.rvaz-hero button{background:#0878f9;color:white;border:0;border-radius:9px;padding:0 24px}.rvaz-filters{display:flex;gap:8px;flex-wrap:wrap;margin:20px 0}.rvaz-filters span{background:white;border:1px solid #d8e2e9;border-radius:20px;padding:8px 15px}.rvaz-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:18px}.rvaz-card{background:white;border:1px solid #e2e8ed;border-radius:14px;overflow:hidden;text-decoration:none;color:#073b63;box-shadow:0 3px 12px #073b6312}.rvaz-card img{width:100%;height:190px;object-fit:cover}.rvaz-card div{padding:15px}.rvaz-card strong,.rvaz-card b,.rvaz-card small{display:block}.rvaz-card b{font-size:20px;margin:8px 0}@media(max-width:750px){.rvaz-grid{grid-template-columns:1fr}.rvaz-hero{padding:24px}.rvaz-hero h1{font-size:32px}}
  </style><?php return ob_get_clean();
 }
 static function template($template){ return $template; }
}
register_activation_hook(__FILE__,['RVAZ_Wonen','activate']);
register_deactivation_hook(__FILE__,['RVAZ_Wonen','deactivate']);
RVAZ_Wonen::init();
