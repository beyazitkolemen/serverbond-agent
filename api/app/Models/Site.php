<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Site extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'domain',
        'site_type',
        'root_path',
        'git_repo',
        'git_branch',
        'php_version',
        'ssl_enabled',
        'status',
        'metadata',
    ];

    protected $casts = [
        'ssl_enabled' => 'boolean',
        'metadata' => 'array',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    protected $attributes = [
        'git_branch' => 'main',
        'php_version' => '8.2',
        'ssl_enabled' => false,
        'status' => 'active',
    ];

    public const TYPE_STATIC = 'static';
    public const TYPE_PHP = 'php';
    public const TYPE_LARAVEL = 'laravel';
    public const TYPE_PYTHON = 'python';
    public const TYPE_NODEJS = 'nodejs';

    public const TYPES = [
        self::TYPE_STATIC,
        self::TYPE_PHP,
        self::TYPE_LARAVEL,
        self::TYPE_PYTHON,
        self::TYPE_NODEJS,
    ];

    public function deploys()
    {
        return $this->hasMany(Deploy::class);
    }

    public function latestDeploy()
    {
        return $this->hasOne(Deploy::class)->latestOfMany();
    }

    public function getSiteIdAttribute(): string
    {
        return str_replace('.', '-', $this->domain);
    }

    public function isPhpSite(): bool
    {
        return in_array($this->site_type, [self::TYPE_PHP, self::TYPE_LARAVEL]);
    }

    public function isPythonSite(): bool
    {
        return $this->site_type === self::TYPE_PYTHON;
    }

    public function isNodejsSite(): bool
    {
        return $this->site_type === self::TYPE_NODEJS;
    }
}

