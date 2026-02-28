<?php
/**
 * Safe wrapper — only includes real emitter runner after WP init.
 * Idempotent: will not include if already loaded or if real file missing.
 */
if ( defined('PR_GITHUB_EMIT_RUNNER_SAFE_LOADED') ) {
    return;
}
define('PR_GITHUB_EMIT_RUNNER_SAFE_LOADED', true);

add_action('init', function() {
    // path to the quarantined "real" file
    $real = WP_CONTENT_DIR . '/mu-plugins/.quarantine/pr_github_emit_runner.php';
    if ( ! file_exists( $real ) ) {
        if ( defined('WP_DEBUG_LOG') && WP_DEBUG_LOG ) {
            error_log('[PR_SAFE_WRAPPER] real emitter runner missing: ' . $real);
        }
        return;
    }

    // double-guard: prevent include-time side effects by wrapping in check
    try {
        include_once $real;
    } catch (Throwable $e) {
        if ( defined('WP_DEBUG_LOG') && WP_DEBUG_LOG ) {
            error_log('[PR_SAFE_WRAPPER] including emitter runner failed: ' . $e->getMessage());
        }
    }
}, 9); // run early on init but after core has created $wp and rewrite objects
