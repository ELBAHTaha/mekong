<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class TableRestaurant extends Model
{
    use HasFactory;

    protected $table = 'tables_restaurant';

    protected $fillable = [
        'numero',
        'etat',
        'x',
        'y',
    ];

    // Casts if needed
    protected $casts = [
        'numero' => 'integer',
        'x' => 'integer',
        'y' => 'integer',
    ];
}
