<?php
// Enhance existing account navigation without replacing its role-filtered links.
add_action('wp_enqueue_scripts', function () {
 if (!is_user_logged_in()) return;
 wp_enqueue_style('rvaz-account-navigation', plugins_url('account-dashboard.css', __FILE__), [], '1.2.1');
 wp_enqueue_script('rvaz-account-navigation', plugins_url('account-dashboard.js', __FILE__), [], '1.2.1', true);
});
