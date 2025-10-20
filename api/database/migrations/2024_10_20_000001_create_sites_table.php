<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sites', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('domain')->unique();
            $table->enum('site_type', ['static', 'php', 'laravel', 'python', 'nodejs']);
            $table->string('root_path');
            $table->string('git_repo')->nullable();
            $table->string('git_branch')->default('main');
            $table->string('php_version')->nullable();
            $table->boolean('ssl_enabled')->default(false);
            $table->string('status')->default('active');
            $table->json('metadata')->nullable();
            $table->timestamps();
            
            $table->index('domain');
            $table->index('site_type');
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sites');
    }
};

