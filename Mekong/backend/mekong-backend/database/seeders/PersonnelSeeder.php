<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class PersonnelSeeder extends Seeder
{
    public function run(): void
    {
        DB::table('personnel')->updateOrInsert(
            ['email' => 'admin@example.com'],
            [
                'nom' => 'Admin Test',
                'mot_de_passe' => Hash::make('test'),
                'role' => 'ADMIN',
                'telephone' => null,
                'actif' => 1,
                'created_at' => now(),
                'last_login' => null,
            ]
        );
    }
}
