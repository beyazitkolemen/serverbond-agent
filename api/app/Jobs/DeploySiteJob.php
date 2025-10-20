<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Models\Deploy;
use App\Models\Site;
use App\Services\DeployService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class DeploySiteJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $timeout = 600; // 10 dakika
    public int $tries = 1;

    public function __construct(
        public Deploy $deploy,
        public Site $site,
        public array $options,
    ) {}

    public function handle(DeployService $deployService): void
    {
        Log::info("Deploy job başladı: {$this->deploy->id}");
        
        $deployService->executeDeploy($this->deploy, $this->site, $this->options);
        
        Log::info("Deploy job tamamlandı: {$this->deploy->id}");
    }

    public function failed(\Throwable $exception): void
    {
        Log::error("Deploy job başarısız: {$exception->getMessage()}", [
            'deploy_id' => $this->deploy->id,
            'site_id' => $this->site->id,
        ]);
        
        $this->deploy->markAsFailed($exception->getMessage());
    }
}

