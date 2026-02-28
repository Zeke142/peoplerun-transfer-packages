<?php
/**
 * 00-pr-env-loader.php
 * Loads PeopleRun secrets from environment variables and defines constants if not already defined.
 */

function pr_define_from_env($const, $env) {
  if (!defined($const)) {
    $v = getenv($env);
    if ($v !== false && $v !== '') {
      define($const, $v);
    }
  }
}

// Example mapping (adjust env var names as you prefer)
pr_define_from_env('PR_EXECUTOR_TOKEN', 'PR_EXECUTOR_TOKEN');
pr_define_from_env('PR_OS_TOKEN', 'PR_OS_TOKEN');
pr_define_from_env('PR_OS_TOKEN_PROD', 'PR_OS_TOKEN_PROD');
pr_define_from_env('PR_OS_TOKEN_DEV', 'PR_OS_TOKEN_DEV');
pr_define_from_env('PR_PUBLISH_BRIDGE_TOKEN', 'PR_PUBLISH_BRIDGE_TOKEN');
pr_define_from_env('PR_OS_WRITE_ENABLED', 'PR_OS_WRITE_ENABLED');

