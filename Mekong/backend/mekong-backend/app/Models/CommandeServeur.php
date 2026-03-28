<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CommandeServeur extends Model
{
    protected $table = 'commande_serveur';
    protected $fillable = [
        'serveur_id', 'table_id', 'total', 'type_commande', 'notes', 'statut', 'date_commande'
    ];

    protected $casts = [
        'date_commande' => 'datetime',
    ];
    public function serveur()
    {
        return $this->belongsTo(Personnel::class, 'serveur_id');
    }

    public function details()
    {
        return $this->hasMany(CommandeServeurDetail::class, 'commande_id');
    }
}
