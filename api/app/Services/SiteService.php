<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Site;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class SiteService
{
    public function __construct(
        private readonly GitService $gitService,
        private readonly NginxService $nginxService,
        private readonly PhpService $phpService,
    ) {}

    public function createSite(array $data): Site
    {
        // Site ID oluştur
        $siteId = Str::slug($data['domain'], '-');
        
        // Site dizini
        $sitePath = config('serverbond.sites_dir') . '/' . $siteId;
        
        // Dizini oluştur
        if (!File::exists($sitePath)) {
            File::makeDirectory($sitePath, 0755, true);
        }
        
        // Git repo varsa klonla
        if (!empty($data['git_repo'])) {
            $this->gitService->cloneRepository(
                $data['git_repo'],
                $sitePath,
                $data['git_branch'] ?? 'main'
            );
        }
        
        // Site kaydı oluştur
        $site = Site::create([
            'domain' => $data['domain'],
            'site_type' => $data['site_type'],
            'root_path' => $sitePath,
            'git_repo' => $data['git_repo'] ?? null,
            'git_branch' => $data['git_branch'] ?? 'main',
            'php_version' => $data['php_version'] ?? config('serverbond.default_php_version'),
            'ssl_enabled' => $data['ssl_enabled'] ?? false,
            'metadata' => $data['env_vars'] ?? [],
        ]);
        
        // PHP site için FPM pool oluştur
        if ($site->isPhpSite()) {
            $this->phpService->createFpmPool($siteId, $site->php_version);
        }
        
        // Nginx konfigürasyonu oluştur
        $this->nginxService->createSiteConfig($site, $data['env_vars'] ?? []);
        
        // Nginx'i reload et
        $this->nginxService->reload();
        
        Log::info("Site oluşturuldu: {$site->domain}", ['site_id' => $site->id]);
        
        return $site;
    }

    public function updateSite(Site $site, array $data): Site
    {
        $site->update($data);
        
        // PHP versiyonu değiştiyse
        if (isset($data['php_version']) && $site->isPhpSite()) {
            $this->phpService->switchSitePhpVersion(
                $site->site_id,
                $site->getOriginal('php_version'),
                $data['php_version']
            );
        }
        
        // Nginx konfigürasyonunu güncelle
        $envVars = $data['metadata'] ?? $site->metadata ?? [];
        $this->nginxService->createSiteConfig($site, $envVars);
        $this->nginxService->reload();
        
        Log::info("Site güncellendi: {$site->domain}", ['site_id' => $site->id]);
        
        return $site->fresh();
    }

    public function deleteSite(Site $site, bool $removeFiles = false): void
    {
        $siteId = $site->site_id;
        $domain = $site->domain;
        
        // PHP-FPM pool'u sil
        if ($site->isPhpSite()) {
            $this->phpService->deleteFpmPool($siteId, $site->php_version);
        }
        
        // Nginx konfigürasyonunu sil
        $this->nginxService->removeSiteConfig($siteId);
        $this->nginxService->reload();
        
        // Dosyaları sil (istenirse)
        if ($removeFiles && File::exists($site->root_path)) {
            File::deleteDirectory($site->root_path);
        }
        
        // Database kaydını sil
        $site->delete();
        
        Log::info("Site silindi: {$domain}", [
            'site_id' => $siteId,
            'files_removed' => $removeFiles,
        ]);
    }
}

