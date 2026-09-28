<?php
$user = get_user_by('login', 'topo-admin');
if (!$user) {
    throw new RuntimeException('The local admin account does not exist.');
}

global $wpdb;
$roles_table = $wpdb->prefix . 'crux_roles';
$user_roles_table = $wpdb->prefix . 'crux_user_roles';
$admin_role_id = $wpdb->get_var(
    $wpdb->prepare("SELECT id FROM {$roles_table} WHERE slug = %s", 'admin')
);

if (!$admin_role_id) {
    throw new RuntimeException('The plugin admin role is missing; check plugin activation.');
}

$existing_id = $wpdb->get_var(
    $wpdb->prepare(
        "SELECT id FROM {$user_roles_table} WHERE user_id = %d AND role_id = %d",
        $user->ID,
        $admin_role_id
    )
);

$role_data = array(
    'assigned_by' => $user->ID,
    'is_active' => 1,
);

if ($existing_id) {
    $result = $wpdb->update(
        $user_roles_table,
        $role_data,
        array('id' => $existing_id),
        array('%d', '%d'),
        array('%d')
    );
} else {
    $role_data['user_id'] = $user->ID;
    $role_data['role_id'] = $admin_role_id;
    $role_data['assigned_at'] = current_time('mysql');
    $result = $wpdb->insert(
        $user_roles_table,
        $role_data,
        array('%d', '%d', '%d', '%d', '%s')
    );
}

if ($result === false) {
    throw new RuntimeException('Could not assign the local application admin role: ' . $wpdb->last_error);
}

echo "Assigned the Crux admin role to topo-admin.\n";
