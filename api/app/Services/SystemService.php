<?php

declare(strict_types=1);

namespace App\Services;

use Illuminate\Support\Facades\Process;

class SystemService
{
    public function getSystemInfo(): array
    {
        return [
            'hostname' => gethostname(),
            'platform' => PHP_OS,
            'php_version' => PHP_VERSION,
            'laravel_version' => app()->version(),
            'cpu_count' => $this->getCpuCount(),
            'memory_total' => $this->getMemoryTotal(),
            'uptime' => $this->getUptime(),
        ];
    }

    public function getSystemStats(): array
    {
        return [
            'cpu' => [
                'percent' => $this->getCpuPercent(),
                'count' => $this->getCpuCount(),
            ],
            'memory' => $this->getMemoryStats(),
            'disk' => $this->getDiskStats(),
            'timestamp' => now()->toIso8601String(),
        ];
    }

    public function getServiceStatuses(): array
    {
        $services = ['nginx', 'mysql', 'redis-server', 'serverbond-agent'];
        $statuses = [];
        
        foreach ($services as $service) {
            $result = Process::run(['systemctl', 'is-active', $service]);
            $statuses[$service] = trim($result->output());
        }
        
        return $statuses;
    }

    public function restartService(string $service): bool
    {
        $result = Process::run(['systemctl', 'restart', $service]);
        return $result->successful();
    }

    private function getCpuCount(): int
    {
        $result = Process::run(['nproc']);
        return (int) trim($result->output());
    }

    private function getCpuPercent(): float
    {
        $load = sys_getloadavg();
        $cpuCount = $this->getCpuCount();
        return round(($load[0] / $cpuCount) * 100, 2);
    }

    private function getMemoryTotal(): int
    {
        $result = Process::run(['free', '-b']);
        $lines = explode("\n", $result->output());
        
        if (isset($lines[1])) {
            $parts = preg_split('/\s+/', $lines[1]);
            return (int) ($parts[1] ?? 0);
        }
        
        return 0;
    }

    private function getMemoryStats(): array
    {
        $result = Process::run(['free', '-b']);
        $lines = explode("\n", $result->output());
        
        if (isset($lines[1])) {
            $parts = preg_split('/\s+/', $lines[1]);
            
            $total = (int) ($parts[1] ?? 0);
            $used = (int) ($parts[2] ?? 0);
            $free = (int) ($parts[3] ?? 0);
            
            return [
                'total' => $total,
                'used' => $used,
                'free' => $free,
                'percent' => $total > 0 ? round(($used / $total) * 100, 2) : 0,
            ];
        }
        
        return [];
    }

    private function getDiskStats(): array
    {
        $result = Process::run(['df', '-B1', '/']);
        $lines = explode("\n", $result->output());
        
        if (isset($lines[1])) {
            $parts = preg_split('/\s+/', $lines[1]);
            
            $total = (int) ($parts[1] ?? 0);
            $used = (int) ($parts[2] ?? 0);
            $free = (int) ($parts[3] ?? 0);
            
            return [
                'total' => $total,
                'used' => $used,
                'free' => $free,
                'percent' => (int) trim($parts[4] ?? '0', '%'),
            ];
        }
        
        return [];
    }

    private function getUptime(): int
    {
        $result = Process::run(['cat', '/proc/uptime']);
        $uptime = explode(' ', trim($result->output()))[0] ?? 0;
        
        return (int) $uptime;
    }
}

