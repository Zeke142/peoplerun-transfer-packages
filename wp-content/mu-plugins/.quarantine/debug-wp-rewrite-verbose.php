<?php
/**
 * Debug: detect wp_rewrite corruption early and capture context.
 * Idempotent — defines constant to avoid double include.
 */
if ( defined('PR_DEBUG_WP_REWRITE_VERBOSE_LOADED') ) {
    return;
}
define('PR_DEBUG_WP_REWRITE_VERBOSE_LOADED', true);

$logfile = WP_CONTENT_DIR . '/uploads/peoplerun/wp_rewrite_corruption.log';
@mkdir(dirname($logfile), 0755, true);

$report = function($stage) use ($logfile) {
    global $wp_rewrite;
    if ( is_object($wp_rewrite) ) {
        // nothing to log when healthy
        return;
    }
    $entry = [
        'ts' => date('c'),
        'stage' => $stage,
        'type' => gettype($wp_rewrite),
        'preview' => is_scalar($wp_rewrite) ? substr((string)$wp_rewrite,0,1200) : null,
        'memory_get_usage' => memory_get_usage(),
        'included_files_count' => count(get_included_files()),
        'included_files' => array_slice(get_included_files(), 0, 120),
        'backtrace' => [],
        'env' => [
            'SAPI' => php_sapi_name(),
            'argv' => isset($_SERVER['argv']) ? array_slice($_SERVER['argv'],0,10) : null,
        ],
    ];
    $bt = debug_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS, 30);
    foreach ($bt as $f) {
        $entry['backtrace'][] = [
            'file' => $f['file'] ?? '(no-file)',
            'line' => $f['line'] ?? '(no-line)',
            'function' => $f['function'] ?? '(no-fn)',
            'class' => $f['class'] ?? null,
        ];
    }
    // append as JSON line
    file_put_contents($logfile, json_encode($entry, JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES).PHP_EOL, FILE_APPEND|LOCK_EX);
};

// stages to hook early and later
add_action('muplugins_loaded',   function() use ($report){ $report('muplugins_loaded'); }, PHP_INT_MIN);
add_action('plugins_loaded',     function() use ($report){ $report('plugins_loaded'); }, 0);
add_action('setup_theme',        function() use ($report){ $report('setup_theme'); }, 0);
add_action('init',               function() use ($report){ $report('init'); }, 0);
add_action('after_setup_theme',  function() use ($report){ $report('after_setup_theme'); }, 0);
add_action('wp_loaded',          function() use ($report){ $report('wp_loaded'); }, 0);

// also run an immediate check in case mu-plugin loaded after the corruption already happened:
$report('immediate_check_at_include');
