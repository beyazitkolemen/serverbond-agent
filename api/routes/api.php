<?php

declare(strict_types=1);

use App\Http\Controllers\Api\DatabaseController;
use App\Http\Controllers\Api\DeployController;
use App\Http\Controllers\Api\PhpController;
use App\Http\Controllers\Api\SiteController;
use App\Http\Controllers\Api\SystemController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
*/

// Health Check
Route::get('/health', function () {
    return response()->json([
        'status' => 'healthy',
        'services' => [
            'api' => 'running',
            'redis' => cache()->getStore()->getRedis()->ping() ? 'connected' : 'disconnected',
        ],
        'timestamp' => now()->toIso8601String(),
    ]);
});

// Sites Management
Route::prefix('sites')->group(function () {
    Route::get('/', [SiteController::class, 'index']);
    Route::post('/', [SiteController::class, 'store']);
    Route::get('/{site}', [SiteController::class, 'show']);
    Route::patch('/{site}', [SiteController::class, 'update']);
    Route::delete('/{site}', [SiteController::class, 'destroy']);
    Route::post('/{site}/reload-nginx', [SiteController::class, 'reloadNginx']);
});

// Deployment
Route::prefix('deploy')->group(function () {
    Route::post('/', [DeployController::class, 'deploy']);
    Route::get('/{deployId}', [DeployController::class, 'status']);
    Route::get('/site/{siteId}', [DeployController::class, 'siteHistory']);
    Route::post('/{deployId}/rollback', [DeployController::class, 'rollback']);
});

// Database Management
Route::prefix('database')->group(function () {
    Route::get('/', [DatabaseController::class, 'index']);
    Route::post('/', [DatabaseController::class, 'store']);
    Route::delete('/{database}', [DatabaseController::class, 'destroy']);
    Route::get('/{database}/backup', [DatabaseController::class, 'backup']);
});

// PHP Version Management
Route::prefix('php')->group(function () {
    Route::get('/versions', [PhpController::class, 'versions']);
    Route::post('/versions/install', [PhpController::class, 'install']);
    Route::get('/versions/{version}/status', [PhpController::class, 'status']);
    Route::post('/sites/{site}/switch-version', [PhpController::class, 'switchVersion']);
    Route::post('/versions/{version}/reload', [PhpController::class, 'reload']);
});

// System Information
Route::prefix('system')->group(function () {
    Route::get('/info', [SystemController::class, 'info']);
    Route::get('/stats', [SystemController::class, 'stats']);
    Route::get('/services', [SystemController::class, 'services']);
    Route::post('/services/{service}/restart', [SystemController::class, 'restart']);
});

