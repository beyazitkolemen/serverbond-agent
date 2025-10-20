<?php

declare(strict_types=1);

namespace App\Http\Requests;

use App\Models\Site;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class SiteCreateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'domain' => ['required', 'string', 'max:255', 'unique:sites,domain'],
            'site_type' => ['required', Rule::in(Site::TYPES)],
            'git_repo' => ['nullable', 'string', 'url'],
            'git_branch' => ['nullable', 'string', 'max:100'],
            'php_version' => ['nullable', 'string', Rule::in(config('serverbond.php_versions'))],
            'ssl_enabled' => ['nullable', 'boolean'],
            'env_vars' => ['nullable', 'array'],
        ];
    }

    public function messages(): array
    {
        return [
            'domain.required' => 'Domain alanı zorunludur',
            'domain.unique' => 'Bu domain için zaten bir site mevcut',
            'site_type.required' => 'Site türü zorunludur',
            'site_type.in' => 'Geçersiz site türü',
            'git_repo.url' => 'Geçerli bir Git URL girin',
            'php_version.in' => 'Desteklenmeyen PHP versiyonu',
        ];
    }

    protected function prepareForValidation(): void
    {
        $domain = $this->input('domain');
        
        if ($domain) {
            // www. prefix'ini kaldır
            $domain = preg_replace('/^www\./', '', strtolower(trim($domain)));
            
            $this->merge([
                'domain' => $domain,
            ]);
        }
    }
}

