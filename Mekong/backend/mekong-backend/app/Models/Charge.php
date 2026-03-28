<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Charge extends Model
{
    protected $table = 'charges';
    public $timestamps = false;

    protected $fillable = [
        'titre',
        'montant',
        'categorie_id',
        'date_charge',
        'description',
    ];

    public function categorie()
    {
        return $this->belongsTo(CategorieCharge::class, 'categorie_id');
    }
}
