<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\DeployResource;
use App\Models\Deploy;
use App\Models\Site;
use App\Services\DeployService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class DeployController extends Controller
{
    public function __construct(
        private readonly DeployService $deployService,
    ) {}

    public function deploy(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'site_id' => ['required', 'exists:sites,id'],
            'git_branch' => ['nullable', 'string'],
            'force' => ['nullable', 'boolean'],
            'run_migrations' => ['nullable', 'boolean'],
            'clear_cache' => ['nullable', 'boolean'],
            'install_dependencies' => ['nullable', 'boolean'],
        ]);

        try {
            $site = Site::findOrFail($validated['site_id']);
            
            $deploy = $this->deployService->startDeploy($site, $validated);
            
            return response()->json([
                'success' => true,
                'message' => 'Deploy başlatıldı',
                'deploy' => new DeployResource($deploy),
            ], 202);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Deploy başlatılamadı',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    public function status(string $deployId): DeployResource|JsonResponse
    {
        $deploy = Deploy::find($deployId);
        
        if (!$deploy) {
            return response()->json([
                'success' => false,
                'message' => 'Deploy bulunamadı',
            ], 404);
        }
        
        return new DeployResource($deploy);
    }

    public function siteHistory(string $siteId, Request $request): AnonymousResourceCollection
    {
        $limit = $request->integer('limit', 10);
        
        $deploys = Deploy::where('site_id', $siteId)
            ->latest()
            ->limit($limit)
            ->get();
        
        return DeployResource::collection($deploys);
    }

    public function rollback(string $deployId): JsonResponse
    {
        try {
            $deploy = Deploy::findOrFail($deployId);
            $site = $deploy->site;
            
            $this->deployService->rollback($deploy, $site);
            
            return response()->json([
                'success' => true,
                'message' => 'Deploy geri alındı',
                'deploy' => new DeployResource($deploy->fresh()),
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Rollback başarısız',
                'error' => $e->getMessage(),
            ], 500);
        }
    }
}

