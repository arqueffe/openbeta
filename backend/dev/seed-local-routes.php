<?php
global $wpdb;

$routes_table = $wpdb->prefix . 'crux_routes';
$existing_route_count = (int) $wpdb->get_var("SELECT COUNT(*) FROM {$routes_table}");
if ($existing_route_count > 0) {
    echo "Existing routes found; leaving local route data unchanged.\n";
    return;
}

$grade_table = $wpdb->prefix . 'crux_grades';
$color_table = $wpdb->prefix . 'crux_hold_colors';
$section_table = $wpdb->prefix . 'crux_wall_sections';
$lanes_table = $wpdb->prefix . 'crux_lanes';
$grades = $wpdb->get_results("SELECT id FROM {$grade_table} ORDER BY value", ARRAY_A);
$colors = $wpdb->get_results("SELECT id FROM {$color_table} ORDER BY id", ARRAY_A);
$wall_section = $wpdb->get_var("SELECT name FROM {$section_table} ORDER BY sort_order LIMIT 1");
$lanes = $wpdb->get_results("SELECT id FROM {$lanes_table} WHERE is_active = 1 ORDER BY id", ARRAY_A);

if (empty($grades) || empty($colors) || !$wall_section || empty($lanes)) {
    throw new RuntimeException('Required plugin reference data is missing; check plugin activation.');
}

foreach ($lanes as $index => $lane) {
    $result = $wpdb->insert(
        $routes_table,
        array(
            'name' => 'Local Demo Route ' . ($index + 1),
            'grade_id' => $grades[$index % count($grades)]['id'],
            'route_setter' => 'Local Demo',
            'wall_section' => $wall_section,
            'lane_id' => $lane['id'],
            'hold_color_id' => $colors[$index % count($colors)]['id'],
            'description' => 'Development fixture created for local testing.',
            'active' => 1,
        ),
        array('%s', '%d', '%s', '%s', '%d', '%d', '%s', '%d')
    );

    if ($result === false) {
        throw new RuntimeException('Could not create local demo routes: ' . $wpdb->last_error);
    }
}

echo 'Created one local demo route in each active lane: ' . count($lanes) . ".\n";
