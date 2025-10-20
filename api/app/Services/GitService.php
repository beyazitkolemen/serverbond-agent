<?php

declare(strict_types=1);

namespace App\Services;

use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Process;

class GitService
{
    public function cloneRepository(string $repoUrl, string $targetPath, string $branch = 'main'): bool
    {
        try {
            // Dizin varsa sil
            if (File::exists($targetPath)) {
                File::deleteDirectory($targetPath);
            }
            
            // Clone
            $result = Process::run([
                'git', 'clone',
                '--branch', $branch,
                '--depth', '1',
                $repoUrl,
                $targetPath,
            ]);
            
            if (!$result->successful()) {
                throw new \Exception($result->errorOutput());
            }
            
            Log::info("Repository klonlandı: {$repoUrl} -> {$targetPath}");
            
            return true;
        } catch (\Exception $e) {
            Log::error("Git klonlama hatası: {$e->getMessage()}");
            return false;
        }
    }

    public function pullLatest(string $repoPath, ?string $branch = null): array
    {
        try {
            if ($branch) {
                Process::path($repoPath)->run(['git', 'checkout', $branch]);
            }
            
            $result = Process::path($repoPath)->run(['git', 'pull']);
            
            if (!$result->successful()) {
                return [false, $result->errorOutput()];
            }
            
            $commitHash = Process::path($repoPath)
                ->run(['git', 'rev-parse', '--short', 'HEAD'])
                ->output();
            
            Log::info("Repository güncellendi: {$repoPath}");
            
            return [true, "Güncellendi: " . trim($commitHash)];
        } catch (\Exception $e) {
            Log::error("Git pull hatası: {$e->getMessage()}");
            return [false, $e->getMessage()];
        }
    }

    public function getCurrentCommit(string $repoPath): ?string
    {
        try {
            $result = Process::path($repoPath)->run(['git', 'rev-parse', 'HEAD']);
            
            return $result->successful() ? trim($result->output()) : null;
        } catch (\Exception $e) {
            return null;
        }
    }

    public function getCurrentBranch(string $repoPath): ?string
    {
        try {
            $result = Process::path($repoPath)->run(['git', 'rev-parse', '--abbrev-ref', 'HEAD']);
            
            return $result->successful() ? trim($result->output()) : null;
        } catch (\Exception $e) {
            return null;
        }
    }

    public function resetToPrevious(string $repoPath): bool
    {
        try {
            $result = Process::path($repoPath)->run(['git', 'reset', '--hard', 'HEAD~1']);
            
            Log::info("Repository önceki commit'e döndürüldü: {$repoPath}");
            
            return $result->successful();
        } catch (\Exception $e) {
            Log::error("Git reset hatası: {$e->getMessage()}");
            return false;
        }
    }
}

