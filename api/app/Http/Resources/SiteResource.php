<?php

declare(strict_types=1);

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class SiteResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'domain' => $this->domain,
            'site_type' => $this->site_type,
            'root_path' => $this->root_path,
            'git_repo' => $this->git_repo,
            'git_branch' => $this->git_branch,
            'php_version' => $this->php_version,
            'ssl_enabled' => $this->ssl_enabled,
            'status' => $this->status,
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
            'latest_deploy' => $this->whenLoaded('latestDeploy', function () {
                return new DeployResource($this->latestDeploy);
            }),
        ];
    }
}

