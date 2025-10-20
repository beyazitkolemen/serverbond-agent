<?php

declare(strict_types=1);

namespace App\Services;

use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Process;

class PhpService
{
    private string $fpmPoolTemplate = '/etc/php/{version}/fpm/pool.d';
    
    public function getInstalledVersions(): array
    {
        $versions = [];
        
        foreach (config('serverbond.php_versions') as $version) {
            $result = Process::run(["php{$version}", '-v']);
            
            if ($result->successful()) {
                $versions[] = $version;
            }
        }
        
        return $versions;
    }

    public function createFpmPool(string $siteId, string $phpVersion): bool
    {
        try {
            $poolDir = str_replace('{version}', $phpVersion, $this->fpmPoolTemplate);
            $poolFile = "{$poolDir}/{$siteId}.conf";
            
            $socketPath = "/var/run/php/php{$phpVersion}-fpm-{$siteId}.sock";
            
            $config = <<<EOT
[{$siteId}]
user = www-data
group = www-data

listen = {$socketPath}
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 500

php_admin_value[error_log] = /var/log/php{$phpVersion}-fpm-{$siteId}.log
php_admin_flag[log_errors] = on

chdir = /
EOT;
            
            File::put($poolFile, $config);
            
            $this->reloadFpm($phpVersion);
            
            Log::info("PHP-FPM pool oluşturuldu: {$siteId} (PHP {$phpVersion})");
            
            return true;
        } catch (\Exception $e) {
            Log::error("PHP-FPM pool oluşturma hatası: {$e->getMessage()}");
            return false;
        }
    }

    public function deleteFpmPool(string $siteId, string $phpVersion): bool
    {
        try {
            $poolDir = str_replace('{version}', $phpVersion, $this->fpmPoolTemplate);
            $poolFile = "{$poolDir}/{$siteId}.conf";
            
            if (File::exists($poolFile)) {
                File::delete($poolFile);
                $this->reloadFpm($phpVersion);
                
                Log::info("PHP-FPM pool silindi: {$siteId}");
                return true;
            }
            
            return false;
        } catch (\Exception $e) {
            Log::error("PHP-FPM pool silme hatası: {$e->getMessage()}");
            return false;
        }
    }

    public function switchSitePhpVersion(string $siteId, string $oldVersion, string $newVersion): bool
    {
        if (!in_array($newVersion, $this->getInstalledVersions())) {
            throw new \Exception("PHP {$newVersion} kurulu değil");
        }
        
        // Eski pool'u sil
        $this->deleteFpmPool($siteId, $oldVersion);
        
        // Yeni pool oluştur
        return $this->createFpmPool($siteId, $newVersion);
    }

    public function reloadFpm(string $version): bool
    {
        $result = Process::run(['systemctl', 'reload', "php{$version}-fpm"]);
        return $result->successful();
    }

    public function getPhpInfo(string $version): array
    {
        $result = Process::run(["php{$version}", '-v']);
        
        if (!$result->successful()) {
            return [];
        }
        
        $status = Process::run(['systemctl', 'is-active', "php{$version}-fpm"]);
        
        return [
            'version' => $version,
            'full_version' => explode("\n", $result->output())[0] ?? '',
            'status' => trim($status->output()),
        ];
    }
}

