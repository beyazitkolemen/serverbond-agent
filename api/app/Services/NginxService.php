<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Site;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Process;

class NginxService
{
    private string $sitesAvailable;
    private string $sitesEnabled;

    public function __construct()
    {
        $this->sitesAvailable = config('serverbond.nginx_sites_available');
        $this->sitesEnabled = config('serverbond.nginx_sites_enabled');
    }

    public function createSiteConfig(Site $site, array $envVars = []): bool
    {
        try {
            $template = $this->getTemplate($site->site_type);
            
            $publicPath = $site->site_type === Site::TYPE_LARAVEL
                ? $site->root_path . '/public'
                : $site->root_path;
            
            $config = $this->renderTemplate($template, [
                'domain' => $site->domain,
                'root_path' => $publicPath,
                'php_version' => $site->php_version,
                'site_id' => $site->site_id,
                'ssl_enabled' => $site->ssl_enabled,
            ]);
            
            // Konfigürasyonu yaz
            $configFile = $this->sitesAvailable . '/' . $site->site_id;
            File::put($configFile, $config);
            
            // Sembolik link oluştur
            $linkFile = $this->sitesEnabled . '/' . $site->site_id;
            if (File::exists($linkFile)) {
                File::delete($linkFile);
            }
            File::link($configFile, $linkFile);
            
            // Test et
            if (!$this->testConfig()) {
                $this->removeSiteConfig($site->site_id);
                throw new \Exception('Nginx konfigürasyonu test başarısız');
            }
            
            Log::info("Nginx konfigürasyonu oluşturuldu: {$site->domain}");
            
            return true;
        } catch (\Exception $e) {
            Log::error("Nginx konfigürasyonu oluşturma hatası: {$e->getMessage()}");
            return false;
        }
    }

    public function removeSiteConfig(string $siteId): bool
    {
        try {
            $linkFile = $this->sitesEnabled . '/' . $siteId;
            $configFile = $this->sitesAvailable . '/' . $siteId;
            
            if (File::exists($linkFile)) {
                File::delete($linkFile);
            }
            
            if (File::exists($configFile)) {
                File::delete($configFile);
            }
            
            Log::info("Nginx konfigürasyonu silindi: {$siteId}");
            
            return true;
        } catch (\Exception $e) {
            Log::error("Nginx konfigürasyonu silme hatası: {$e->getMessage()}");
            return false;
        }
    }

    public function testConfig(): bool
    {
        $result = Process::run('nginx -t');
        return $result->successful();
    }

    public function reload(): bool
    {
        $result = Process::run('systemctl reload nginx');
        return $result->successful();
    }

    private function getTemplate(string $siteType): string
    {
        return match ($siteType) {
            Site::TYPE_STATIC => $this->getStaticTemplate(),
            Site::TYPE_PHP => $this->getPhpTemplate(),
            Site::TYPE_LARAVEL => $this->getLaravelTemplate(),
            Site::TYPE_PYTHON => $this->getPythonTemplate(),
            Site::TYPE_NODEJS => $this->getNodejsTemplate(),
            default => $this->getStaticTemplate(),
        };
    }

    private function renderTemplate(string $template, array $vars): string
    {
        foreach ($vars as $key => $value) {
            $template = str_replace("{{ {$key} }}", $value, $template);
        }
        return $template;
    }

    private function getLaravelTemplate(): string
    {
        return <<<'NGINX'
server {
    listen 80;
    listen [::]:80;
    
    server_name {{ domain }} www.{{ domain }};
    root {{ root_path }};
    index index.php;
    
    access_log /var/log/nginx/{{ site_id }}-access.log;
    error_log /var/log/nginx/{{ site_id }}-error.log;
    
    charset utf-8;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }
    
    error_page 404 /index.php;
    
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php{{ php_version }}-fpm-{{ site_id }}.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
    }
    
    location ~ /\.(?!well-known).* {
        deny all;
    }
}
NGINX;
    }

    private function getPhpTemplate(): string
    {
        return <<<'NGINX'
server {
    listen 80;
    listen [::]:80;
    
    server_name {{ domain }} www.{{ domain }};
    root {{ root_path }};
    index index.php index.html;
    
    access_log /var/log/nginx/{{ site_id }}-access.log;
    error_log /var/log/nginx/{{ site_id }}-error.log;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php{{ php_version }}-fpm-{{ site_id }}.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
NGINX;
    }

    private function getStaticTemplate(): string
    {
        return <<<'NGINX'
server {
    listen 80;
    listen [::]:80;
    
    server_name {{ domain }} www.{{ domain }};
    root {{ root_path }};
    index index.html index.htm;
    
    access_log /var/log/nginx/{{ site_id }}-access.log;
    error_log /var/log/nginx/{{ site_id }}-error.log;
    
    location / {
        try_files $uri $uri/ =404;
    }
}
NGINX;
    }

    private function getPythonTemplate(): string
    {
        return <<<'NGINX'
upstream {{ site_id }}_backend {
    server 127.0.0.1:8001;
}

server {
    listen 80;
    listen [::]:80;
    
    server_name {{ domain }} www.{{ domain }};
    
    access_log /var/log/nginx/{{ site_id }}-access.log;
    error_log /var/log/nginx/{{ site_id }}-error.log;
    
    location / {
        proxy_pass http://{{ site_id }}_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX;
    }

    private function getNodejsTemplate(): string
    {
        return <<<'NGINX'
upstream {{ site_id }}_backend {
    server 127.0.0.1:3000;
}

server {
    listen 80;
    listen [::]:80;
    
    server_name {{ domain }} www.{{ domain }};
    
    access_log /var/log/nginx/{{ site_id }}-access.log;
    error_log /var/log/nginx/{{ site_id }}-error.log;
    
    location / {
        proxy_pass http://{{ site_id }}_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
NGINX;
    }
}

