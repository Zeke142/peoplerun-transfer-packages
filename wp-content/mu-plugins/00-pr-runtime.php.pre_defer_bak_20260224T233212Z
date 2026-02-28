<?php
/**
 * 00-pr-runtime.php
 * (abbreviated installer copy) - full runtime should match what was agreed
 * NOTE: If you replace this file, keep filename exact: 00-pr-runtime.php
 */
if ( ! defined( 'ABSPATH' ) ) {
    exit;
}
define('PR_PHASE_ENV',       'ENV');
define('PR_PHASE_CORE',      'CORE');
define('PR_PHASE_CAPABILITY','CAPABILITY');
define('PR_PHASE_WIRING',    'WIRING');
define('PR_PHASE_EXECUTION', 'EXECUTION');

global $pr_runtime;
$pr_runtime = (object) [
    'phase' => PR_PHASE_ENV,
    'declared_files' => [],
    'hook_snapshots' => [],
    'ledger_path' => WP_CONTENT_DIR . '/pr_boot_ledger.jsonl',
    'proof_path'  => WP_CONTENT_DIR . '/uploads/peoplerun/boot_proof.json',
    'boot_allowed' => false,
];

function PR_DECLARE_PHASE($phase) {
    global $pr_runtime;
    $file = debug_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS, 1)[0]['file'] ?? __FILE__;
    $phase = strtoupper(trim($phase));
    $allowed = [PR_PHASE_ENV, PR_PHASE_CORE, PR_PHASE_CAPABILITY, PR_PHASE_WIRING, PR_PHASE_EXECUTION];
    if (! in_array($phase, $allowed, true)) {
        pr_abort_boot("Invalid phase declaration '{$phase}' in {$file}");
    }
    $pr_runtime->declared_files[$file] = $phase;
}

function pr_set_phase($phase) {
    global $pr_runtime;
    $pr_runtime->phase = $phase;
    $count = 0;
    if (isset($GLOBALS['wp_filter']) && is_array($GLOBALS['wp_filter'])) {
        foreach ($GLOBALS['wp_filter'] as $k => $v) {
            if (is_array($v)) $count += count($v);
            elseif (is_object($v) && isset($v->callbacks)) $count += count($v->callbacks);
        }
    }
    $pr_runtime->hook_snapshots[$phase] = $count;
}

function pr_abort_boot($reason) {
    global $pr_runtime;
    $payload = [
        'ok' => false,
        'reason' => $reason,
        'time_utc' => gmdate('c'),
        'phase' => $pr_runtime->phase ?? 'unknown',
    ];
    @wp_mkdir_p(dirname($pr_runtime->proof_path));
    @file_put_contents($pr_runtime->proof_path, json_encode($payload, JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES));
    header('HTTP/1.1 503 Service Unavailable');
    wp_die("PeopleRun boot abort: " . esc_html($reason), 'PeopleRun boot abort', ['response' => 503]);
    exit;
}

$GLOBALS['pr_registrations'] = [];

function pr_add_action($hook, $callback, $priority = 10, $accepted_args = 1) {
    global $pr_runtime;
    $reg = ['type'=>'action','hook'=>$hook,'phase'=>$pr_runtime->phase,'file'=>debug_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS, 1)[0]['file'] ?? 'unknown'];
    $GLOBALS['pr_registrations'][] = $reg;
    return add_action($hook, $callback, $priority, $accepted_args);
}
function pr_add_filter($hook, $callback, $priority = 10, $accepted_args = 1) {
    global $pr_runtime;
    $reg = ['type'=>'filter','hook'=>$hook,'phase'=>$pr_runtime->phase,'file'=>debug_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS, 1)[0]['file'] ?? 'unknown'];
    $GLOBALS['pr_registrations'][] = $reg;
    return add_filter($hook, $callback, $priority, $accepted_args);
}

function pr_load_ledger() {
    global $pr_runtime;
    $ledger = $pr_runtime->ledger_path;
    if (! file_exists($ledger)) {
        pr_abort_boot("Missing boot ledger: {$ledger}");
    }
    $lines = file($ledger, FILE_IGNORE_NEW_LINES|FILE_SKIP_EMPTY_LINES);
    $entries = [];
    foreach ($lines as $ln) {
        $j = json_decode($ln, true);
        if (! $j || empty($j['path']) || empty($j['phase'])) {
            pr_abort_boot("Malformed ledger line: " . substr($ln,0,200));
        }
        $p = $j['path'];
        if (! file_exists($p)) {
            $alt = WP_CONTENT_DIR . '/' . ltrim($p, '/');
            if (file_exists($alt)) $p = $alt;
            else pr_abort_boot("Boot ledger references missing file: {$p}");
        }
        $entries[] = ['path'=>$p, 'phase'=>strtoupper($j['phase']), 'mode'=>$j['mode'] ?? 'require_once'];
    }
    return $entries;
}

function pr_execute_boot() {
    global $pr_runtime;
    $phases = [PR_PHASE_ENV, PR_PHASE_CORE, PR_PHASE_CAPABILITY, PR_PHASE_WIRING, PR_PHASE_EXECUTION];
    $entries = pr_load_ledger();
    $bucket = [];
    foreach ($entries as $e) $bucket[$e['phase']][] = $e;
    foreach ($phases as $phase) {
        pr_set_phase($phase);
        if (isset($bucket[$phase])) {
            foreach ($bucket[$phase] as $file) {
                if ($file['mode'] === 'require_once') require_once $file['path'];
                else include_once $file['path'];
            }
        }
    }
    pr_validate_post_boot();
    pr_emit_boot_proof(true, "Boot completed successfully.");
    $pr_runtime->boot_allowed = true;
}

function pr_validate_post_boot() {
    global $pr_runtime;
    $ledger_entries = array_map(function($l){ return $l['path']; }, pr_load_ledger());
    foreach ($pr_runtime->declared_files as $file => $phase) {
        if (! in_array($file, $ledger_entries, true)) {
            pr_abort_boot("PeopleRun file {$file} declared phase {$phase} but is not present in boot ledger.");
        }
    }
    $registrations = $GLOBALS['pr_registrations'] ?? [];
    foreach ($registrations as $r) {
        if ($r['phase'] !== PR_PHASE_WIRING) {
            pr_abort_boot("Illegal hook registration: {$r['hook']} registered in phase {$r['phase']} by {$r['file']}. Hooks must be registered in WIRING phase.");
        }
    }
    $snap = $pr_runtime->hook_snapshots;
    if (!isset($snap[PR_PHASE_WIRING])) {
        pr_abort_boot("Missing hook snapshot for WIRING phase — boot ledger execution incomplete.");
    }
}

function pr_emit_boot_proof($ok, $msg) {
    global $pr_runtime;
    $proof = [
        'ok' => $ok,
        'message' => $msg,
        'time_utc' => gmdate('c'),
        'phase' => $pr_runtime->phase,
    ];
    if (file_exists($pr_runtime->ledger_path)) {
        $proof['ledger_sha1'] = sha1_file($pr_runtime->ledger_path);
        $proof['ledger_mtime'] = gmdate('c', filemtime($pr_runtime->ledger_path));
    }
    @wp_mkdir_p(dirname($pr_runtime->proof_path));
    @file_put_contents($pr_runtime->proof_path, json_encode($proof, JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES));
}

pr_set_phase(PR_PHASE_ENV);
@wp_mkdir_p(WP_CONTENT_DIR . '/uploads/peoplerun');
pr_execute_boot();
