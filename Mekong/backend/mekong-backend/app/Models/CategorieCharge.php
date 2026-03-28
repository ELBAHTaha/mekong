<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CategorieCharge extends Model
{
    protected $table = 'categories_charges';
    public $timestamps = false;

    protected $fillable = [
        'nom',
    ];
}
