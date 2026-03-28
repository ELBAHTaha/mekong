<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CommandeServeurDetail extends Model
{
    protected $table = 'commande_serveur_details';

    protected $fillable = [
        'commande_id', 'produit_id', 'quantite', 'prix_unitaire'
    ];

    public $timestamps = false;

    public function commandeServeur()
    {
        return $this->belongsTo(CommandeServeur::class, 'commande_id');
    }

    public function produit()
    {
        return $this->belongsTo(Produit::class, 'produit_id');
    }
}
