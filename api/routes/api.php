<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
*/

// Health check
Route::get('/health', function () {
    return response()->json([
        'status' => 'healthy',
        'timestamp' => now()->toIso8601String(),
        'service' => 'ServerBond Agent API',
        'version' => '1.0.0'
    ]);
});

// System info
Route::get('/system/info', function () {
    return response()->json([
        'hostname' => gethostname(),
        'php_version' => PHP_VERSION,
        'laravel_version' => app()->version(),
        'os' => PHP_OS,
        'server_time' => now()->toDateTimeString(),
    ]);
});

// System stats
Route::get('/system/stats', function () {
    try {
        // CPU
        $cpuLoad = sys_getloadavg();
        $cpuCores = (int)shell_exec('nproc 2>/dev/null') ?: 1;
        $cpuPercent = round(($cpuLoad[0] / $cpuCores) * 100, 2);
        
        // Memory (Ubuntu/Linux)
        $memTotal = (int)shell_exec("free | grep Mem | awk '{print $2}'") ?: 1;
        $memUsed = (int)shell_exec("free | grep Mem | awk '{print $3}'") ?: 0;
        $memPercent = $memTotal > 0 ? round(($memUsed / $memTotal) * 100, 2) : 0;
        
        // Disk
        $diskInfo = trim(shell_exec("df -h / | awk 'NR==2 {print $5}' | sed 's/%//'") ?: '0');
        $diskPercent = (int)$diskInfo;
        
        // Uptime
        $uptime = trim(shell_exec('uptime -p 2>/dev/null') ?: shell_exec('uptime'));
        
        return response()->json([
            'uptime' => $uptime,
            'cpu' => [
                'percent' => min($cpuPercent, 100),
                'load_average' => $cpuLoad,
                'cores' => $cpuCores,
            ],
            'memory' => [
                'percent' => min($memPercent, 100),
                'used_mb' => round($memUsed / 1024, 2),
                'total_mb' => round($memTotal / 1024, 2),
            ],
            'disk' => [
                'percent' => $diskPercent,
            ],
        ]);
    } catch (\Exception $e) {
        return response()->json([
            'error' => 'Failed to get system stats',
            'message' => $e->getMessage()
        ], 500);
    }
});

// Sites
Route::get('/sites', function () {
    return response()->json([]);
});

Route::post('/sites', function (Request $request) {
    return response()->json([
        'message' => 'Site creation endpoint',
        'data' => $request->all()
    ], 201);
});

// Databases
Route::get('/database', function () {
    try {
        $databases = \DB::select('SHOW DATABASES');
        $result = array_map(fn($db) => $db->Database, $databases);
        return response()->json($result);
    } catch (\Exception $e) {
        return response()->json(['error' => 'Database connection failed'], 500);
    }
});

// PHP versions
Route::get('/php/versions', function () {
    $versions = [];
    foreach (['8.1', '8.2', '8.3'] as $version) {
        $check = shell_exec("which php{$version}");
        if ($check) {
            $versions[] = [
                'version' => $version,
                'installed' => true,
                'path' => trim($check),
            ];
        }
    }
    return response()->json($versions);
});

