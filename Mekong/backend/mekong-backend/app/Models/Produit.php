<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Produit extends Model
{
    protected $table = 'produits';
    public $timestamps = false;

    protected $fillable = [
        'nom',
        'description',
        'prix',
        'photo',
        'categorie_id',
        'actif',
        'Disponible',
        'created_at',
    ];
}
