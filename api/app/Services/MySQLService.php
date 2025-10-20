<?php

declare(strict_types=1);

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Process;

class MySQLService
{
    public function listDatabases(): array
    {
        try {
            $databases = DB::select('SHOW DATABASES');
            
            // Sistem veritabanlarını filtrele
            $systemDatabases = ['information_schema', 'performance_schema', 'mysql', 'sys'];
            
            return collect($databases)
                ->pluck('Database')
                ->reject(fn($db) => in_array($db, $systemDatabases))
                ->values()
                ->toArray();
        } catch (\Exception $e) {
            Log::error("Veritabanı listeleme hatası: {$e->getMessage()}");
            return [];
        }
    }

    public function createDatabase(string $name, string $user, string $password, string $host = 'localhost'): bool
    {
        try {
            // Veritabanı oluştur
            DB::statement("CREATE DATABASE IF NOT EXISTS `{$name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
            
            // Kullanıcı oluştur
            DB::statement("CREATE USER IF NOT EXISTS '{$user}'@'{$host}' IDENTIFIED BY '{$password}'");
            
            // Yetkileri ver
            DB::statement("GRANT ALL PRIVILEGES ON `{$name}`.* TO '{$user}'@'{$host}'");
            
            // Yetkileri yenile
            DB::statement('FLUSH PRIVILEGES');
            
            Log::info("Veritabanı oluşturuldu: {$name}");
            
            return true;
        } catch (\Exception $e) {
            Log::error("Veritabanı oluşturma hatası: {$e->getMessage()}");
            return false;
        }
    }

    public function dropDatabase(string $name): bool
    {
        try {
            DB::statement("DROP DATABASE IF EXISTS `{$name}`");
            
            Log::info("Veritabanı silindi: {$name}");
            
            return true;
        } catch (\Exception $e) {
            Log::error("Veritabanı silme hatası: {$e->getMessage()}");
            return false;
        }
    }

    public function backupDatabase(string $name): ?string
    {
        try {
            $timestamp = now()->format('Ymd_His');
            $backupFile = config('serverbond.backups_dir') . "/{$name}_{$timestamp}.sql";
            
            $password = config('database.connections.mysql.password');
            
            $result = Process::run([
                'mysqldump',
                '--host=' . config('database.connections.mysql.host'),
                '--user=' . config('database.connections.mysql.username'),
                '--password=' . $password,
                '--single-transaction',
                '--quick',
                '--lock-tables=false',
                $name,
            ]);
            
            if (!$result->successful()) {
                throw new \Exception($result->errorOutput());
            }
            
            file_put_contents($backupFile, $result->output());
            
            Log::info("Veritabanı yedeklendi: {$backupFile}");
            
            return $backupFile;
        } catch (\Exception $e) {
            Log::error("Yedekleme hatası: {$e->getMessage()}");
            return null;
        }
    }
}

