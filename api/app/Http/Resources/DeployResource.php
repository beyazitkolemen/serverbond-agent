<?php

declare(strict_types=1);

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class DeployResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'deploy_id' => $this->id,
            'site_id' => $this->site_id,
            'status' => $this->status,
            'git_branch' => $this->git_branch,
            'commit_hash' => $this->commit_hash,
            'started_at' => $this->started_at?->toIso8601String(),
            'completed_at' => $this->completed_at?->toIso8601String(),
            'logs' => $this->logs ?? [],
            'error' => $this->error,
            'duration' => $this->started_at && $this->completed_at
                ? $this->started_at->diffInSeconds($this->completed_at) . 's'
                : null,
        ];
    }
}

