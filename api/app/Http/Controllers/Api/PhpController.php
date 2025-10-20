<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Site;
use App\Services\PhpService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PhpController extends Controller
{
    public function __construct(
        private readonly PhpService $phpService,
    ) {}

    public function versions(): JsonResponse
    {
        $installed = $this->phpService->getInstalledVersions();
        $supported = config('serverbond.php_versions');
        
        $versionsInfo = [];
        foreach ($installed as $version) {
            $versionsInfo[$version] = $this->phpService->getPhpInfo($version);
        }
        
        return response()->json([
            'supported' => $supported,
            'installed' => $installed,
            'versions' => $versionsInfo,
        ]);
    }

    public function status(string $version): JsonResponse
    {
        if (!in_array($version, config('serverbond.php_versions'))) {
            return response()->json([
                'success' => false,
                'message' => "Desteklenmeyen PHP versiyonu: {$version}",
            ], 400);
        }
        
        $info = $this->phpService->getPhpInfo($version);
        
        if (empty($info)) {
            return response()->json([
                'success' => false,
                'message' => "PHP {$version} kurulu değil",
            ], 404);
        }
        
        return response()->json($info);
    }

    public function switchVersion(Request $request, string $siteId): JsonResponse
    {
        $validated = $request->validate([
            'new_version' => ['required', 'string'],
        ]);

        try {
            $site = Site::findOrFail($siteId);
            
            if (!$site->isPhpSite()) {
                return response()->json([
                    'success' => false,
                    'message' => 'Bu site türü için PHP versiyonu değiştirilemez',
                ], 400);
            }
            
            $oldVersion = $site->php_version;
            
            $success = $this->phpService->switchSitePhpVersion(
                $site->site_id,
                $oldVersion,
                $validated['new_version']
            );
            
            if (!$success) {
                throw new \Exception('PHP versiyonu değiştirilemedi');
            }
            
            $site->update(['php_version' => $validated['new_version']]);
            
            return response()->json([
                'success' => true,
                'message' => "PHP versiyonu değiştirildi: {$oldVersion} → {$validated['new_version']}",
                'old_version' => $oldVersion,
                'new_version' => $validated['new_version'],
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'PHP versiyonu değiştirilemedi',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    public function reload(string $version): JsonResponse
    {
        if (!in_array($version, $this->phpService->getInstalledVersions())) {
            return response()->json([
                'success' => false,
                'message' => "PHP {$version} kurulu değil",
            ], 404);
        }
        
        $success = $this->phpService->reloadFpm($version);
        
        if (!$success) {
            return response()->json([
                'success' => false,
                'message' => "PHP {$version} FPM yeniden yüklenemedi",
            ], 500);
        }
        
        return response()->json([
            'success' => true,
            'message' => "PHP {$version} FPM yeniden yüklendi",
        ]);
    }
}

