<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\SystemService;
use Illuminate\Http\JsonResponse;

class SystemController extends Controller
{
    public function __construct(
        private readonly SystemService $systemService,
    ) {}

    public function info(): JsonResponse
    {
        return response()->json($this->systemService->getSystemInfo());
    }

    public function stats(): JsonResponse
    {
        return response()->json($this->systemService->getSystemStats());
    }

    public function services(): JsonResponse
    {
        return response()->json($this->systemService->getServiceStatuses());
    }

    public function restart(string $service): JsonResponse
    {
        $allowed = ['nginx', 'mysql', 'redis-server', 'serverbond-agent'];
        
        if (!in_array($service, $allowed)) {
            return response()->json([
                'success' => false,
                'message' => "Geçersiz servis: {$service}",
            ], 400);
        }
        
        $success = $this->systemService->restartService($service);
        
        if (!$success) {
            return response()->json([
                'success' => false,
                'message' => "Servis yeniden başlatılamadı: {$service}",
            ], 500);
        }
        
        return response()->json([
            'success' => true,
            'message' => "{$service} servisi yeniden başlatıldı",
        ]);
    }
}

