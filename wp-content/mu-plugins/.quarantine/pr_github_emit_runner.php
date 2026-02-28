<?php
/*
Plugin Name: PeopleRun - pr_github_emit_runner placeholder
Description: Minimal placeholder to register pr_github_emit_runner for diagnostics.
Version: 0.0.1
Author: PeopleRun Diagnostics
*/

// register a simple action/hook name so pr_hook_inspect.sh can detect it
if ( ! defined( 'PR_GITHUB_EMIT_RUNNER_REGISTERED' ) ) {
    define( 'PR_GITHUB_EMIT_RUNNER_REGISTERED', true );
}

// register a noop action so any WP-based inspector can find the action/hook
add_action( 'pr_github_emit_runner', function( $payload = null ){
    // noop: diagnostics only - write a tiny log for visibility if uploads writable
    $logdir = WP_CONTENT_DIR . '/uploads/peoplerun';
    if ( is_dir( $logdir ) && is_writable( $logdir ) ) {
        @file_put_contents( $logdir . '/pr_github_emit_runner.placeholder.log', date('c') . " - placeholder fired\n", FILE_APPEND | LOCK_EX );
    }
    return true;
});
