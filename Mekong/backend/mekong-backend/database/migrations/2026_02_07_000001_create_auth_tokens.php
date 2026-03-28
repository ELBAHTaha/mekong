<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (!Schema::hasTable('auth_tokens')) {
            Schema::create('auth_tokens', function (Blueprint $table) {
                $table->id();
                $table->string('token', 64)->unique();
                $table->unsignedInteger('personnel_id');
                $table->timestamp('created_at')->useCurrent();
                $table->timestamp('expires_at')->nullable();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('auth_tokens');
    }
};
