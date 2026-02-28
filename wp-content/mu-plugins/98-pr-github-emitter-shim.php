<?php
// Idempotent shim: define minimal emitter functions only if missing so runtime doesn't fatal.
if ( ! function_exists('pr_get_token_sha10') ) {
    function pr_get_token_sha10(): string {
        $env = getenv('PR_GITHUB_TOKEN') ?: '';
        if ($env && strlen($env) > 8) return substr(hash('sha256', $env),0,10);
        return 'absent';
    }
}
if ( ! function_exists('pr_publisher_enqueue_github_emit') ) {
    function pr_publisher_enqueue_github_emit($payload = []) {
        return ['ok'=>true,'queued'=>false,'reason'=>'emitter-quarantined','payload_preview'=>is_array($payload)?array_keys($payload):null];
    }
}
if ( ! function_exists('pr_github_propose_change') ) {
    function pr_github_propose_change($payload = []) {
        // safe no-op response when real emitter isn't present
        return ['ok'=>true,'queued'=>false,'note'=>'shim-only'];
    }
}
