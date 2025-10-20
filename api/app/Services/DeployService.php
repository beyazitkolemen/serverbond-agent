<?php

declare(strict_types=1);

namespace App\Services;

use App\Jobs\DeploySiteJob;
use App\Models\Deploy;
use App\Models\Site;
use Illuminate\Support\Facades\Log;

class DeployService
{
    public function __construct(
        private readonly GitService $gitService,
    ) {}

    public function startDeploy(Site $site, array $options): Deploy
    {
        // Deploy kaydı oluştur
        $deploy = Deploy::create([
            'site_id' => $site->id,
            'status' => Deploy::STATUS_PENDING,
            'git_branch' => $options['git_branch'] ?? $site->git_branch,
            'started_at' => now(),
            'metadata' => $options,
        ]);
        
        // Arka planda deploy et
        DeploySiteJob::dispatch($deploy, $site, $options);
        
        Log::info("Deploy başlatıldı: {$deploy->id} - {$site->domain}");
        
        return $deploy;
    }

    public function executeDeploy(Deploy $deploy, Site $site, array $options): void
    {
        try {
            $deploy->markAsInProgress();
            $deploy->addLog("Deploy işlemi başladı: {$site->domain}");
            
            // Git pull
            [$success, $message] = $this->gitService->pullLatest(
                $site->root_path,
                $deploy->git_branch
            );
            
            $deploy->addLog("Git: {$message}");
            
            if (!$success) {
                throw new \Exception("Git pull başarısız: {$message}");
            }
            
            // Current commit'i kaydet
            $commitHash = $this->gitService->getCurrentCommit($site->root_path);
            $deploy->update(['commit_hash' => $commitHash]);
            
            // Site türüne göre işlemler
            match ($site->site_type) {
                Site::TYPE_LARAVEL => $this->deployLaravel($deploy, $site, $options),
                Site::TYPE_PHP => $this->deployPhp($deploy, $site, $options),
                Site::TYPE_PYTHON => $this->deployPython($deploy, $site, $options),
                Site::TYPE_NODEJS => $this->deployNodejs($deploy, $site, $options),
                default => null,
            };
            
            $deploy->addLog("✓ Deploy başarıyla tamamlandı");
            $deploy->markAsSuccess();
            
        } catch (\Exception $e) {
            $deploy->addLog("✗ Deploy başarısız: {$e->getMessage()}");
            $deploy->markAsFailed($e->getMessage());
            
            Log::error("Deploy hatası: {$e->getMessage()}", [
                'deploy_id' => $deploy->id,
                'site_id' => $site->id,
            ]);
        }
    }

    private function deployLaravel(Deploy $deploy, Site $site, array $options): void
    {
        $deploy->addLog("Laravel deployment başlıyor...");
        
        // Composer install
        if ($options['install_dependencies'] ?? true) {
            $deploy->addLog("Composer bağımlılıkları yükleniyor...");
            
            $result = \Illuminate\Support\Facades\Process::path($site->root_path)
                ->run(['composer', 'install', '--no-dev', '--optimize-autoloader', '--no-interaction']);
            
            if (!$result->successful()) {
                throw new \Exception("Composer hatası: {$result->errorOutput()}");
            }
            
            $deploy->addLog("✓ Composer bağımlılıkları yüklendi");
        }
        
        // Migration
        if ($options['run_migrations'] ?? false) {
            $deploy->addLog("Migration'lar çalıştırılıyor...");
            
            $result = \Illuminate\Support\Facades\Process::path($site->root_path)
                ->run(['php', 'artisan', 'migrate', '--force']);
            
            if (!$result->successful()) {
                throw new \Exception("Migration hatası: {$result->errorOutput()}");
            }
            
            $deploy->addLog("✓ Migration'lar tamamlandı");
        }
        
        // Cache
        if ($options['clear_cache'] ?? true) {
            $deploy->addLog("Cache temizleniyor...");
            
            \Illuminate\Support\Facades\Process::path($site->root_path)
                ->run(['php', 'artisan', 'config:cache']);
            \Illuminate\Support\Facades\Process::path($site->root_path)
                ->run(['php', 'artisan', 'route:cache']);
            \Illuminate\Support\Facades\Process::path($site->root_path)
                ->run(['php', 'artisan', 'view:cache']);
            
            $deploy->addLog("✓ Cache optimize edildi");
        }
        
        // Dosya izinleri
        \Illuminate\Support\Facades\Process::run(['chmod', '-R', '775', $site->root_path . '/storage']);
        \Illuminate\Support\Facades\Process::run(['chmod', '-R', '775', $site->root_path . '/bootstrap/cache']);
        
        $deploy->addLog("✓ Dosya izinleri ayarlandı");
    }

    private function deployPhp(Deploy $deploy, Site $site, array $options): void
    {
        if ($options['install_dependencies'] ?? true) {
            $composerFile = $site->root_path . '/composer.json';
            
            if (file_exists($composerFile)) {
                $deploy->addLog("Composer bağımlılıkları yükleniyor...");
                
                \Illuminate\Support\Facades\Process::path($site->root_path)
                    ->run(['composer', 'install', '--no-dev', '--optimize-autoloader']);
                
                $deploy->addLog("✓ Composer tamamlandı");
            }
        }
    }

    private function deployPython(Deploy $deploy, Site $site, array $options): void
    {
        if ($options['install_dependencies'] ?? true) {
            $requirementsFile = $site->root_path . '/requirements.txt';
            
            if (file_exists($requirementsFile)) {
                $deploy->addLog("Python bağımlılıkları yükleniyor...");
                
                $venvPath = $site->root_path . '/venv';
                $pipPath = $venvPath . '/bin/pip';
                
                if (file_exists($pipPath)) {
                    \Illuminate\Support\Facades\Process::run([
                        $pipPath, 'install', '-r', $requirementsFile
                    ]);
                    
                    $deploy->addLog("✓ Python bağımlılıkları yüklendi");
                }
            }
        }
    }

    private function deployNodejs(Deploy $deploy, Site $site, array $options): void
    {
        if ($options['install_dependencies'] ?? true) {
            $packageFile = $site->root_path . '/package.json';
            
            if (file_exists($packageFile)) {
                $deploy->addLog("NPM bağımlılıkları yükleniyor...");
                
                \Illuminate\Support\Facades\Process::path($site->root_path)
                    ->run(['npm', 'ci', '--production']);
                
                $deploy->addLog("✓ NPM bağımlılıkları yüklendi");
            }
        }
    }

    public function rollback(Deploy $deploy, Site $site): void
    {
        $this->gitService->resetToPrevious($site->root_path);
        
        $deploy->update([
            'status' => Deploy::STATUS_ROLLED_BACK,
            'completed_at' => now(),
        ]);
        
        $deploy->addLog("Deploy geri alındı");
        
        Log::info("Deploy geri alındı: {$deploy->id}");
    }
}

