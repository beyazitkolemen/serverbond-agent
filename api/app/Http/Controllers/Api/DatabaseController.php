<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\MySQLService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DatabaseController extends Controller
{
    public function __construct(
        private readonly MySQLService $mysqlService,
    ) {}

    public function index(): JsonResponse
    {
        $databases = $this->mysqlService->listDatabases();
        
        return response()->json($databases);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'alpha_dash', 'max:64'],
            'user' => ['required', 'string', 'alpha_dash', 'max:32'],
            'password' => ['required', 'string', 'min:8'],
            'host' => ['nullable', 'string'],
        ]);

        try {
            $result = $this->mysqlService->createDatabase(
                $validated['name'],
                $validated['user'],
                $validated['password'],
                $validated['host'] ?? 'localhost'
            );
            
            if (!$result) {
                throw new \Exception('Veritabanı oluşturulamadı');
            }
            
            return response()->json([
                'success' => true,
                'message' => "Veritabanı başarıyla oluşturuldu: {$validated['name']}",
                'database' => $validated['name'],
                'user' => $validated['user'],
                'host' => $validated['host'] ?? 'localhost',
            ], 201);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Veritabanı oluşturulamadı',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    public function destroy(string $database): JsonResponse
    {
        try {
            $result = $this->mysqlService->dropDatabase($database);
            
            if (!$result) {
                return response()->json([
                    'success' => false,
                    'message' => 'Veritabanı bulunamadı',
                ], 404);
            }
            
            return response()->json([
                'success' => true,
                'message' => "Veritabanı başarıyla silindi: {$database}",
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Veritabanı silinemedi',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    public function backup(string $database): JsonResponse
    {
        try {
            $backupFile = $this->mysqlService->backupDatabase($database);
            
            if (!$backupFile) {
                throw new \Exception('Yedekleme başarısız');
            }
            
            return response()->json([
                'success' => true,
                'message' => 'Veritabanı başarıyla yedeklendi',
                'backup_file' => $backupFile,
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Yedekleme başarısız',
                'error' => $e->getMessage(),
            ], 500);
        }
    }
}

