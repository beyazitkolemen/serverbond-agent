<?php

declare(strict_types=1);

return [
    /*
    |--------------------------------------------------------------------------
    | ServerBond Agent Configuration
    |--------------------------------------------------------------------------
    */

    'sites_dir' => env('SERVERBOND_SITES_DIR', '/opt/serverbond-agent/sites'),
    
    'backups_dir' => env('SERVERBOND_BACKUPS_DIR', '/opt/serverbond-agent/backups'),
    
    'logs_dir' => env('SERVERBOND_LOGS_DIR', '/opt/serverbond-agent/logs'),
    
    'nginx_sites_available' => env('SERVERBOND_NGINX_SITES_AVAILABLE', '/etc/nginx/sites-available'),
    
    'nginx_sites_enabled' => env('SERVERBOND_NGINX_SITES_ENABLED', '/etc/nginx/sites-enabled'),
    
    /*
    |--------------------------------------------------------------------------
    | PHP Configuration
    |--------------------------------------------------------------------------
    */

    'php_versions' => array_map('trim', explode(',', env('SERVERBOND_PHP_VERSIONS', '8.1,8.2,8.3'))),
    
    'default_php_version' => env('SERVERBOND_DEFAULT_PHP_VERSION', '8.2'),
    
    /*
    |--------------------------------------------------------------------------
    | Git Configuration
    |--------------------------------------------------------------------------
    */

    'git_timeout' => (int) env('SERVERBOND_GIT_TIMEOUT', 300),
    
    'deploy_timeout' => (int) env('SERVERBOND_DEPLOY_TIMEOUT', 600),
];

