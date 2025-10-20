<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('deploys', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('site_id')->constrained()->onDelete('cascade');
            $table->enum('status', ['pending', 'in_progress', 'success', 'failed', 'rolled_back'])
                ->default('pending');
            $table->string('git_branch')->nullable();
            $table->string('commit_hash')->nullable();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->json('logs')->nullable();
            $table->text('error')->nullable();
            $table->json('metadata')->nullable();
            $table->timestamps();
            
            $table->index('site_id');
            $table->index('status');
            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('deploys');
    }
};

