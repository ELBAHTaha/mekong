<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Commande;
use App\Models\CommandeProduit;
use Illuminate\Support\Facades\DB;

class CommandesController extends Controller
{
    public function index(Request $request)
    {
        $q = Commande::with(['produits','caissier','table','commandeServeur']);

        if ($request->has('statut')) {
            $q->where('statut', $request->input('statut'));
        }
        if ($request->has('type')) {
            $q->where('type', $request->input('type'));
        }
        if ($request->has('caissier_id')) {
            // filter by caissier (direct column on commandes)
            $q->where('caissier_id', $request->input('caissier_id'));
        }

        $includeServeur = false;
        if ($request->has('include_serveur')) {
            $val = $request->input('include_serveur');
            if ($val === true || $val === '1' || $val === 'true' || $val == 1) $includeServeur = true;
        }

        // If serveur_id provided and include_serveur not set, return only serveur entries.
        if ($request->has('serveur_id') && !$includeServeur) {
            $serveurId = $request->input('serveur_id');
            $serveurCommandes = \App\Models\CommandeServeur::with(['serveur', 'details.produit'])
                ->where('serveur_id', $serveurId)
                ->orderByDesc('date_commande')
                ->get();

            $out = $serveurCommandes->map(function($cs) {
                $produits = $cs->details->map(function($d) {
                    return [
                        'id' => $d->produit_id,
                        'nom' => optional($d->produit)->name ?? optional($d->produit)->nom ?? '',
                        'quantite' => $d->quantite,
                        'prix_unitaire' => (float) $d->prix_unitaire,
                        'total' => (float) ($d->prix_unitaire * $d->quantite),
                    ];
                })->values();

                return [
                    'id' => $cs->id,
                    'client_nom' => null,
                    'type' => $cs->type_commande ?? 'SUR_PLACE',
                    'statut' => $cs->statut ?? 'NOUVELLE',
                    'total' => (float) $cs->total,
                    'table_id' => $cs->table_id ?? null,
                    'serveur_nom' => optional($cs->serveur)->name ?? null,
                    'date_commande' => $cs->date_commande ? $cs->date_commande->toDateTimeString() : null,
                    'produits' => $produits,
                    'notes' => $cs->notes ?? null,
                ];
            });

            return response()->json($out);
        }

        // If include_serveur requested, fetch both commandes and commande_serveur and merge.
        if ($includeServeur) {
            // apply date filters to commandes query
            if ($request->has('from')) {
                $q->whereDate('date_commande', '>=', $request->input('from'));
            }
            if ($request->has('to')) {
                $q->whereDate('date_commande', '<=', $request->input('to'));
            }
            $commandes = $q->orderByDesc('date_commande')->get();

            $serveurQuery = \App\Models\CommandeServeur::with(['serveur', 'details.produit']);
            if ($request->has('serveur_id')) {
                $serveurQuery->where('serveur_id', $request->input('serveur_id'));
            }
            if ($request->has('from')) {
                $serveurQuery->whereDate('date_commande', '>=', $request->input('from'));
            }
            if ($request->has('to')) {
                $serveurQuery->whereDate('date_commande', '<=', $request->input('to'));
            }
            $serveurCommandes = $serveurQuery->orderByDesc('date_commande')->get();

            $mappedServeur = $serveurCommandes->map(function($cs) {
                $produits = $cs->details->map(function($d) {
                    return [
                        'id' => $d->produit_id,
                        'nom' => optional($d->produit)->name ?? optional($d->produit)->nom ?? '',
                        'quantite' => $d->quantite,
                        'prix_unitaire' => (float) $d->prix_unitaire,
                        'total' => (float) ($d->prix_unitaire * $d->quantite),
                    ];
                })->values();

                return [
                    'id' => $cs->id,
                    'client_nom' => null,
                    'type' => $cs->type_commande ?? 'SUR_PLACE',
                    'statut' => $cs->statut ?? 'NOUVELLE',
                    'total' => (float) $cs->total,
                    'table_id' => $cs->table_id ?? null,
                    'serveur_nom' => optional($cs->serveur)->name ?? null,
                    'date_commande' => $cs->date_commande ? $cs->date_commande->toDateTimeString() : null,
                    'produits' => $produits,
                    'notes' => $cs->notes ?? null,
                ];
            });

            // merge and sort by date_commande desc
            $merged = $commandes->map(function($c) {
                return $c->toArray();
            })->merge($mappedServeur);

            $sorted = $merged->sortByDesc(function($item) {
                return $item['date_commande'] ?? null;
            })->values();

            return response()->json($sorted);
        }
        if ($request->has('from')) {
            $q->whereDate('date_commande', '>=', $request->input('from'));
        }
        if ($request->has('to')) {
            $q->whereDate('date_commande', '<=', $request->input('to'));
        }

        $commandes = $q->orderByDesc('date_commande')->get();
        return response()->json($commandes);
    }

    public function store(Request $request)
    {
        $request->validate([
            'client_nom' => 'nullable|string|max:150',
            'type' => 'required|in:SUR_PLACE,LIVRAISON',
            'statut' => 'nullable|in:NOUVELLE,PREPARATION,PRETE,LIVRAISON,LIVREE,ANNULEE',
            'total' => 'nullable|numeric',
            'table_id' => 'nullable|integer',
            'caissier_id' => 'nullable|integer',
            'date_commande' => 'nullable|date',
            'adresse' => 'nullable|string',
            'telephone' => 'nullable|string',
            'notes' => 'nullable|string',
            'items' => 'nullable|array',
        ]);

        $data = $request->only(['client_nom','type','statut','total','table_id','caissier_id','date_commande','adresse','telephone','notes']);
        if (empty($data['statut'])) $data['statut'] = 'NOUVELLE';
        $commande = Commande::create($data);

        // items
        $items = $request->input('items', []);
        foreach ($items as $it) {
            $cp = new CommandeProduit();
            $cp->commande_id = $commande->id;
            $cp->produit_id = $it['produit_id'] ?? null;
            $cp->nom = $it['nom'] ?? ($it['produit_name'] ?? '');
            $cp->quantite = $it['quantite'] ?? 1;
            $cp->prix_unitaire = $it['prix_unitaire'] ?? 0;
            $cp->total = ($it['total'] ?? ($cp->quantite * $cp->prix_unitaire));
            $cp->save();
        }

        // refresh with produits
        $commande->load('produits');
        return response()->json($commande, 201);
    }

    public function show(Request $request, $id)
    {
        $commande = Commande::with('produits')->find($id);
        if (!$commande) return response()->json(['error' => 'not_found'], 404);
        return response()->json($commande);
    }

    public function update(Request $request, $id)
    {
        $commande = Commande::find($id);
        if (!$commande) return response()->json(['error' => 'not_found'], 404);

        $data = $request->only(['client_nom','type','statut','total','table_id','caissier_id','date_commande','adresse','telephone','notes']);
        $commande->fill($data);
        $commande->save();

        // replace items if provided
        if ($request->has('items')) {
            CommandeProduit::where('commande_id', $commande->id)->delete();
            $items = $request->input('items', []);
            foreach ($items as $it) {
                $cp = new CommandeProduit();
                $cp->commande_id = $commande->id;
                $cp->produit_id = $it['produit_id'] ?? null;
                $cp->nom = $it['nom'] ?? ($it['produit_name'] ?? '');
                $cp->quantite = $it['quantite'] ?? 1;
                $cp->prix_unitaire = $it['prix_unitaire'] ?? 0;
                $cp->total = ($it['total'] ?? ($cp->quantite * $cp->prix_unitaire));
                $cp->save();
            }
        }

        $commande->load('produits');
        return response()->json($commande);
    }

    public function destroy(Request $request, $id)
    {
        $commande = Commande::find($id);
        if (!$commande) return response()->json(['error' => 'not_found'], 404);
        $commande->delete();
        return response()->json(['status' => 'deleted']);
    }
}
