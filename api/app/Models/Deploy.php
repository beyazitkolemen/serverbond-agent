<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Deploy extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'site_id',
        'status',
        'git_branch',
        'commit_hash',
        'started_at',
        'completed_at',
        'logs',
        'error',
        'metadata',
    ];

    protected $casts = [
        'started_at' => 'datetime',
        'completed_at' => 'datetime',
        'logs' => 'array',
        'metadata' => 'array',
    ];

    public const STATUS_PENDING = 'pending';
    public const STATUS_IN_PROGRESS = 'in_progress';
    public const STATUS_SUCCESS = 'success';
    public const STATUS_FAILED = 'failed';
    public const STATUS_ROLLED_BACK = 'rolled_back';

    public const STATUSES = [
        self::STATUS_PENDING,
        self::STATUS_IN_PROGRESS,
        self::STATUS_SUCCESS,
        self::STATUS_FAILED,
        self::STATUS_ROLLED_BACK,
    ];

    public function site()
    {
        return $this->belongsTo(Site::class);
    }

    public function addLog(string $message): void
    {
        $logs = $this->logs ?? [];
        $logs[] = [
            'timestamp' => now()->toIso8601String(),
            'message' => $message,
        ];
        $this->logs = $logs;
        $this->save();
    }

    public function markAsInProgress(): void
    {
        $this->update([
            'status' => self::STATUS_IN_PROGRESS,
            'started_at' => now(),
        ]);
    }

    public function markAsSuccess(): void
    {
        $this->update([
            'status' => self::STATUS_SUCCESS,
            'completed_at' => now(),
        ]);
    }

    public function markAsFailed(string $error): void
    {
        $this->update([
            'status' => self::STATUS_FAILED,
            'completed_at' => now(),
            'error' => $error,
        ]);
    }
}

