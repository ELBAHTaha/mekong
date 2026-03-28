<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CategorieProduit extends Model
{
    protected $table = 'categories_produits';
    public $timestamps = false;

    protected $fillable = [
        'nom',
        'photo',
        'created_at',
    ];
}
