<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\SiteCreateRequest;
use App\Http\Requests\SiteUpdateRequest;
use App\Http\Resources\SiteResource;
use App\Models\Site;
use App\Services\NginxService;
use App\Services\PhpService;
use App\Services\SiteService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class SiteController extends Controller
{
    public function __construct(
        private readonly SiteService $siteService,
        private readonly NginxService $nginxService,
        private readonly PhpService $phpService,
    ) {}

    public function index(): AnonymousResourceCollection
    {
        $sites = Site::latest()->get();
        
        return SiteResource::collection($sites);
    }

    public function store(SiteCreateRequest $request): JsonResponse
    {
        try {
            $site = $this->siteService->createSite($request->validated());
            
            return response()->json([
                'success' => true,
                'message' => "Site başarıyla oluşturuldu: {$site->domain}",
                'site' => new SiteResource($site),
            ], 201);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Site oluşturulamadı',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    public function show(Site $site): SiteResource
    {
        return new SiteResource($site);
    }

    public function update(SiteUpdateRequest $request, Site $site): JsonResponse
    {
        try {
            $site = $this->siteService->updateSite($site, $request->validated());
            
            return response()->json([
                'success' => true,
                'message' => "Site başarıyla güncellendi: {$site->domain}",
                'site' => new SiteResource($site),
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Site güncellenemedi',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    public function destroy(Site $site): JsonResponse
    {
        try {
            $removeFiles = request()->boolean('remove_files', false);
            
            $this->siteService->deleteSite($site, $removeFiles);
            
            return response()->json([
                'success' => true,
                'message' => "Site başarıyla silindi: {$site->domain}",
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Site silinemedi',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    public function reloadNginx(Site $site): JsonResponse
    {
        try {
            $this->nginxService->reload();
            
            return response()->json([
                'success' => true,
                'message' => 'Nginx başarıyla yeniden yüklendi',
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Nginx yeniden yüklenemedi',
                'error' => $e->getMessage(),
            ], 500);
        }
    }
}

