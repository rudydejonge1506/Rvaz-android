<?php
if (!defined('ABSPATH')) exit;
final class RVAZ_Broker_Application_Admin {
 static function menu() {
  if (!class_exists('RVAZ_Wonen')) return;
  add_submenu_page('rvaz-wonen', 'Makelaarsaanvragen', 'Makelaarsaanvragen', 'manage_options', 'rvaz-wonen-makelaarsaanvragen', [__CLASS__, 'render']);
 }
 static function render() {
  if (!current_user_can('manage_options')) wp_die('Geen toegang.');
  global $wpdb;
  $rows = $wpdb->get_results("SELECT a.*, u.display_name FROM {$wpdb->prefix}rvaz_wonen_applications a LEFT JOIN {$wpdb->users} u ON u.ID=a.user_id ORDER BY a.id DESC LIMIT 200");
  echo '<div class="wrap"><h1>Makelaarsaanvragen</h1><p>Aanvragen vanuit website en app. Een aanvraag is nog geen winkelbetaling. Goedkeuren gebruikt de bestaande abonnements-, factuur- en kortingsregels.</p><table class="widefat striped"><thead><tr><th>Kantoor / contact</th><th>Pakket</th><th>Status</th><th>Datum</th><th>Beoordelen</th></tr></thead><tbody>';
  if (!$rows) echo '<tr><td colspan="5">Geen makelaarsaanvragen.</td></tr>';
  $statuses = ['pending'=>'In behandeling', 'email_pending'=>'Wacht op e-mailbevestiging', 'approved'=>'Goedgekeurd', 'rejected'=>'Afgewezen', 'cancelled'=>'Geannuleerd'];
  foreach ($rows as $row) {
   echo '<tr><td><strong>'.esc_html($row->office).'</strong><br>'.esc_html($row->contact_name ?: $row->display_name).'</td><td>'.esc_html(ucfirst($row->plan)).'</td><td>'.esc_html($statuses[$row->status] ?? $row->status).'</td><td>'.esc_html($row->created).'</td><td>';
   if ($row->status === 'pending' && class_exists('RVAZ_Wonen_Intro')) {
    foreach (['approve'=>'Goedkeuren', 'reject'=>'Afwijzen'] as $decision=>$label) {
     $url = add_query_arg(['action'=>'rvaz_wonen_application_decision', 'id'=>(int)$row->id, 'decision'=>$decision], admin_url('admin-post.php'));
     $url = wp_nonce_url($url, 'rvaz_wonen_application_'.(int)$row->id, 'nonce');
     echo '<a class="button" href="'.esc_url($url).'">'.esc_html($label).'</a> ';
    }
   } elseif ($row->status === 'pending') echo 'Bestaande beoordelingsmodule niet beschikbaar.';
   else echo '—';
   echo '</td></tr>';
  }
  echo '</tbody></table></div>';
 }
 static function notice() {
  if (!current_user_can('manage_options') || !class_exists('RVAZ_Wonen')) return;
  global $wpdb;
  $count=(int)$wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->prefix}rvaz_wonen_applications WHERE status='pending'");
  if ($count) echo '<div class="notice notice-info"><p>'.esc_html($count).' makelaarsaanvraag/aanvragen wachten op beoordeling. <a href="'.esc_url(admin_url('admin.php?page=rvaz-wonen-makelaarsaanvragen')).'">Bekijk makelaarsaanvragen</a></p></div>';
 }
}
add_action('admin_menu', ['RVAZ_Broker_Application_Admin','menu'], 110);
add_action('admin_notices', ['RVAZ_Broker_Application_Admin','notice']);
