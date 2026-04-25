<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Commande;
use App\Models\CommandeProduit;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Http;

class CommandesController extends Controller
{
    private function commandeColumnNames(): array
    {
        static $columns = null;
        if ($columns === null) {
            $columns = Schema::getColumnListing('commandes');
        }

        return $columns;
    }

    private function commandeProduitColumnNames(): array
    {
        static $columns = null;
        if ($columns === null) {
            $columns = Schema::getColumnListing('commande_produits');
        }

        return $columns;
    }

    private function filterExistingColumns(array $payload, array $columns): array
    {
        return array_intersect_key($payload, array_flip($columns));
    }

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
            // POS compatibility fields (same table as saveOrder.php)
            'methode_paiement' => 'nullable|string|max:255',
            'statut_paiement' => 'nullable|string|max:255',
            'montant_paye' => 'nullable|numeric',
            'monnaie_rendue' => 'nullable|numeric',
            'GSM_client' => 'nullable|string|max:255',
            'adresse_livraison' => 'nullable|string|max:255',
            'livreur_id' => 'nullable|integer',
            'notes' => 'nullable|string',
            'items' => 'nullable|array',
        ]);

        $commandeColumns = $this->commandeColumnNames();
        $commandeProduitColumns = $this->commandeProduitColumnNames();

        $items = $request->input('items', []);
        // Store items JSON in `commandes.items` for POS compatibility (saveOrder.php).
        $itemsJson = json_encode($items, JSON_UNESCAPED_UNICODE);

        $data = $this->filterExistingColumns($request->only([
            'client_nom',
            'type',
            'statut',
            'total',
            'table_id',
            'caissier_id',
            'date_commande',
            'notes',
            'methode_paiement',
            'statut_paiement',
            'montant_paye',
            'monnaie_rendue',
            'GSM_client',
            'adresse_livraison',
            'livreur_id',
        ]), $commandeColumns);

        if (in_array('items', $commandeColumns, true)) {
            $data['items'] = $itemsJson;
        }
        if (empty($data['statut'])) $data['statut'] = 'NOUVELLE';

        // Ensure POS non-null columns have sane defaults even if DB defaults differ.
        if (in_array('methode_paiement', $commandeColumns, true) && empty($data['methode_paiement'])) {
            $data['methode_paiement'] = 'CASH';
        }
        if (in_array('statut_paiement', $commandeColumns, true) && empty($data['statut_paiement'])) {
            $data['statut_paiement'] = 'CASH';
        }
        if (in_array('adresse_livraison', $commandeColumns, true) && empty($data['adresse_livraison'])) {
            $data['adresse_livraison'] = '';
        }
        if (in_array('GSM_client', $commandeColumns, true) && empty($data['GSM_client'])) {
            $data['GSM_client'] = '';
        }
        if (in_array('montant_paye', $commandeColumns, true) && !isset($data['montant_paye'])) {
            $data['montant_paye'] = 0;
        }
        if (in_array('monnaie_rendue', $commandeColumns, true) && !isset($data['monnaie_rendue'])) {
            $data['monnaie_rendue'] = 0;
        }

        $commande = DB::transaction(function () use ($data, $request, $commandeProduitColumns) {
            $commande = Commande::create($data);

            $items = $request->input('items', []);
            foreach ($items as $it) {
                $itemData = [
                    'commande_id' => $commande->id,
                    'produit_id' => $it['produit_id'] ?? null,
                    'nom' => $it['nom'] ?? ($it['produit_name'] ?? ''),
                    'quantite' => $it['quantite'] ?? 1,
                    'prix_unitaire' => $it['prix_unitaire'] ?? 0,
                    'total' => $it['total'] ?? (($it['quantite'] ?? 1) * ($it['prix_unitaire'] ?? 0)),
                ];

                DB::table('commande_produits')->insert(
                    $this->filterExistingColumns($itemData, $commandeProduitColumns)
                );
            }

            return $commande;
        });

        // Notify realtime/printing server (like saveOrder.php).
        // Configure REALTIME_NOTIFY_URL on the VPS:
        //   REALTIME_NOTIFY_URL=http://127.0.0.1:3132/notify
        $notifyUrl = env('REALTIME_NOTIFY_URL', 'http://127.0.0.1:3132/notify');
        if (!empty($notifyUrl)) {
            try {
                Http::timeout(1)->post($notifyUrl, [
                    'event' => 'order_created',
                    'order_id' => $commande->id,
                ]);
            } catch (\Throwable $e) {
                // Do not fail the order creation if realtime server is down.
            }
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

        $commandeColumns = $this->commandeColumnNames();
        $commandeProduitColumns = $this->commandeProduitColumnNames();

        DB::transaction(function () use ($request, $commande, $commandeColumns, $commandeProduitColumns) {
            $data = $this->filterExistingColumns(
                $request->only(['client_nom','type','statut','total','table_id','caissier_id','date_commande','adresse','telephone','notes']),
                $commandeColumns
            );
            $commande->fill($data);
            $commande->save();

            if ($request->has('items')) {
                CommandeProduit::where('commande_id', $commande->id)->delete();
                $items = $request->input('items', []);
                foreach ($items as $it) {
                    $itemData = [
                        'commande_id' => $commande->id,
                        'produit_id' => $it['produit_id'] ?? null,
                        'nom' => $it['nom'] ?? ($it['produit_name'] ?? ''),
                        'quantite' => $it['quantite'] ?? 1,
                        'prix_unitaire' => $it['prix_unitaire'] ?? 0,
                        'total' => $it['total'] ?? (($it['quantite'] ?? 1) * ($it['prix_unitaire'] ?? 0)),
                    ];

                    DB::table('commande_produits')->insert(
                        $this->filterExistingColumns($itemData, $commandeProduitColumns)
                    );
                }
            }
        });

        $commande->refresh();
        // Commande sur place annulée → libérer la table (aligné POS / affichage serveur).
        if ($commande->statut === 'ANNULEE' && $commande->table_id) {
            DB::table('tables_restaurant')
                ->where('id', $commande->table_id)
                ->update(['etat' => 'LIBRE']);
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
