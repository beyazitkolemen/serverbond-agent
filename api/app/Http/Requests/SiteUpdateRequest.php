<?php

declare(strict_types=1);

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class SiteUpdateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'git_branch' => ['nullable', 'string', 'max:100'],
            'php_version' => ['nullable', 'string', Rule::in(config('serverbond.php_versions'))],
            'ssl_enabled' => ['nullable', 'boolean'],
            'status' => ['nullable', 'string', Rule::in(['active', 'inactive', 'maintenance'])],
            'metadata' => ['nullable', 'array'],
        ];
    }
}

