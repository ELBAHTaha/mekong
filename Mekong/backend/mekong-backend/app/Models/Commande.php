<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Commande extends Model
{
    protected $table = 'commandes';
    protected $fillable = [
        'client_nom','type','statut','total','table_id','caissier_id','date_commande','adresse','telephone','notes'
    ];

    public function produits()
    {
        return $this->hasMany(CommandeProduit::class, 'commande_id');
    }

    public function caissier()
    {
        return $this->belongsTo(Personnel::class, 'caissier_id');
    }

    public function table()
    {
        return $this->belongsTo(TableRestaurant::class, 'table_id');
    }

    public function commandeServeur()
    {
        // commande_serveur.id references commandes.id (one-to-one)
        return $this->hasOne(CommandeServeur::class, 'id', 'id');
    }
}
