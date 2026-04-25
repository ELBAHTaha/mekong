<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Http;

class ApiController extends Controller
{
    public function hello(Request $request)
    {
        return response()->json([
            'app' => 'Mekong',
            'message' => "Bonjour depuis l'API Laravel",
        ]);
    }

    public function ventesParMois(Request $request)
    {
        $year = (int) $request->query('year', Carbon::now()->year);
        $month = (int) $request->query('month', Carbon::now()->month);

        $start = Carbon::create($year, $month, 1)->startOfMonth();
        $daysInMonth = $start->daysInMonth;

        $result = [];
        for ($d = 1; $d <= $daysInMonth; $d++) {
            $day = Carbon::create($year, $month, $d);
            $totalCommandes = (float) DB::table('commandes')
                ->whereDate('date_commande', $day)
                ->whereNotIn('statut', ['ANNULEE'])
                ->sum('total');
            $totalServeur = (float) DB::table('commande_serveur')
                ->whereDate('commande_serveur.date_commande', $day)
                ->whereNotIn('commande_serveur.statut', ['ANNULEE'])
                ->sum('total');
            $total = $totalCommandes + $totalServeur;
            $result[] = [
                'day' => $d,
                'date' => $day->toDateString(),
                'total' => $total,
            ];
        }

        return response()->json($result);
    }

    public function dashboard(Request $request)
    {
        $today = Carbon::today();

        // Ventes et dépenses du jour
        $ventesDuJour = (float) (DB::table('commandes')
            ->whereDate('date_commande', $today)
            ->whereNotIn('statut', ['ANNULEE'])
            ->sum('total'));

        $commandesMontantCommandes = (float) DB::table('commandes')
            ->whereDate('date_commande', $today)
            ->sum('total');

        $commandesMontantServeur = (float) DB::table('commande_serveur')
            ->whereDate('commande_serveur.date_commande', $today)
            ->sum('total');

        // Total montant commandes (commandes + commande_serveur)
        $commandesMontant = $commandesMontantCommandes + $commandesMontantServeur;

        $depensesDuJour = (float) (DB::table('charges')
            ->whereDate('date_charge', $today)
            ->sum('montant'));

        // Commandes en cours (toutes les commandes)
        $commandesEnCours = (int) DB::table('commandes')
            ->whereIn('statut', ['NOUVELLE','PREPARATION','PRETE','LIVRAISON'])
            ->count();

        // Livraisons actives (separate table)
        $livraisonsActives = (int) DB::table('livraisons')
            ->whereIn('statut', ['EN_ROUTE'])
            ->count();

        // Graph des ventes: derniers 7 jours
        $graph = [];
        for ($i = 6; $i >= 0; $i--) {
            $day = Carbon::today()->subDays($i);
            $total = (float) DB::table('commandes')
                ->whereDate('date_commande', $day)
                ->whereNotIn('statut', ['ANNULEE'])
                ->sum('total');
            $graph[] = [
                'date' => $day->toDateString(),
                'total' => $total,
            ];
        }

        // Ventes par jour de la semaine (Lundi -> Dimanche) pour la semaine courante
        $startOfWeek = Carbon::now()->startOfWeek();
        $jours = ['Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'];
        $ventesParJourSemaine = [];
        for ($i = 0; $i < 7; $i++) {
            $day = $startOfWeek->copy()->addDays($i);
            $totalCommandes = (float) DB::table('commandes')
                ->whereDate('date_commande', $day)
                ->whereNotIn('statut', ['ANNULEE'])
                ->sum('total');
            $totalServeur = (float) DB::table('commande_serveur')
                ->whereDate('commande_serveur.date_commande', $day)
                ->whereNotIn('commande_serveur.statut', ['ANNULEE'])
                ->sum('total');
            $total = $totalCommandes + $totalServeur;
            $ventesParJourSemaine[] = [
                'jour' => $jours[$i],
                'date' => $day->toDateString(),
                'total' => $total,
            ];
        }


        // Commandes récentes du jour: combiner `commandes` et `commande_serveur`, trier par date.
        // Quand client_nom est vide (POS / sur place), on renvoie un libellé lisible (type + table si dispo).
        $recentCommandes = DB::table('commandes')
            ->leftJoin('tables_restaurant', 'commandes.table_id', '=', 'tables_restaurant.id')
            ->whereDate('commandes.date_commande', $today)
            ->orderByDesc('commandes.date_commande')
            ->limit(10)
            ->select([
                'commandes.id',
                DB::raw("COALESCE(NULLIF(TRIM(commandes.client_nom), ''), CASE commandes.type
                    WHEN 'LIVRAISON' THEN 'Livraison'
                    WHEN 'SUR_PLACE' THEN CASE WHEN tables_restaurant.numero IS NOT NULL
                        THEN CONCAT('Sur place · Table ', tables_restaurant.numero)
                        ELSE 'Sur place' END
                    ELSE CONCAT('Commande #', commandes.id)
                END) as client_nom"),
                'commandes.statut',
                'commandes.total',
                'commandes.date_commande',
                'commandes.type',
            ])
            ->get();

        $recentServeur = DB::table('commande_serveur')
            ->whereDate('commande_serveur.date_commande', $today)
            ->leftJoin('personnel', 'commande_serveur.serveur_id', '=', 'personnel.id')
            ->leftJoin('tables_restaurant', 'commande_serveur.table_id', '=', 'tables_restaurant.id')
            ->orderByDesc('commande_serveur.date_commande')
            ->limit(10)
            ->select([
                'commande_serveur.id',
                DB::raw("COALESCE(NULLIF(TRIM(personnel.nom), ''), CASE WHEN tables_restaurant.numero IS NOT NULL
                    THEN CONCAT('Serveur · Table ', tables_restaurant.numero)
                    ELSE 'Commande serveur' END) as client_nom"),
                'commande_serveur.statut',
                'commande_serveur.total',
                'commande_serveur.date_commande',
                DB::raw("'serveur' as type"),
            ])
            ->get();

        // Fusionner, trier et limiter à 3 éléments
        $merged = $recentCommandes->concat($recentServeur)
            ->sortByDesc(function ($item) {
                return $item->date_commande;
            })->values()->slice(0, 3);

        // Compteurs du jour: livraisons (type = LIVRAISON) et total commandes (commandes + commande_serveur)
        $livraisonCount = (int) DB::table('commandes')
            ->whereDate('date_commande', $today)
            ->where('type', 'LIVRAISON')
            ->count();

        $countCommandesToday = (int) DB::table('commandes')
            ->whereDate('date_commande', $today)
            ->count();

        $countServeurToday = (int) DB::table('commande_serveur')
            ->whereDate('date_commande', $today)
            ->count();

        $totalCommandesToday = $countCommandesToday + $countServeurToday;

        return response()->json([
            'ventes_du_jour' => $ventesDuJour,
            'commandes_montant_du_jour' => $commandesMontant,
            // legacy key expected by frontend model
            'commandes_montant' => $commandesMontant,
            'depenses_du_jour' => $depensesDuJour,
            'commandes_en_cours' => $commandesEnCours,
            'livraisons_actives' => $livraisonsActives,
            'graph_ventes' => $graph,
            'ventes_par_jour_semaine' => $ventesParJourSemaine,
            'commandes_recent' => $merged,
            'livraison_count_du_jour' => $livraisonCount,
            'total_commandes_du_jour' => $totalCommandesToday,
        ]);
    }

    /**
     * Notify kitchen/printer server about a cancelled item.
     * The realtime server URL is configured via REALTIME_NOTIFY_URL.
     */
    public function kitchenCancel(Request $request)
    {
        $data = $request->validate([
            'event' => 'nullable|string|max:50',
            'table_id' => 'nullable|integer',
            'table_numero' => 'nullable|integer',
            'serveur_id' => 'nullable|integer',
            'serveur_nom' => 'nullable|string|max:255',
            'produit_id' => 'nullable|integer',
            'produit_nom' => 'required|string|max:255',
            'quantite' => 'required|integer|min:1',
            'prix_unitaire' => 'nullable|numeric',
            'timestamp' => 'nullable|string|max:50',
        ]);

        $payload = $data;
        $payload['event'] = $payload['event'] ?? 'order_item_cancelled';

        $notifyUrl = env('REALTIME_NOTIFY_URL', 'http://127.0.0.1:3132/notify');
        if (!empty($notifyUrl)) {
            try {
                Http::timeout(1)->post($notifyUrl, $payload);
            } catch (\Throwable $e) {
                // Do not fail if realtime server is down.
            }
        }

        return response()->json(['status' => 'ok']);
    }

    /**
     * Notify kitchen/printer server about an added item.
     * The realtime server URL is configured via REALTIME_NOTIFY_URL.
     */
    public function kitchenAdd(Request $request)
    {
        $data = $request->validate([
            'event' => 'nullable|string|max:50',
            'table_id' => 'nullable|integer',
            'table_numero' => 'nullable|integer',
            'serveur_id' => 'nullable|integer',
            'serveur_nom' => 'nullable|string|max:255',
            'produit_id' => 'nullable|integer',
            'produit_nom' => 'required|string|max:255',
            'quantite' => 'required|integer|min:1',
            'prix_unitaire' => 'nullable|numeric',
            'timestamp' => 'nullable|string|max:50',
        ]);

        $payload = $data;
        $payload['event'] = $payload['event'] ?? 'order_item_added';

        $notifyUrl = env('REALTIME_NOTIFY_URL', 'http://127.0.0.1:3132/notify');
        if (!empty($notifyUrl)) {
            try {
                Http::timeout(1)->post($notifyUrl, $payload);
            } catch (\Throwable $e) {
                // Do not fail if realtime server is down.
            }
        }

        return response()->json(['status' => 'ok']);
    }

    /**
     * Store a livraison (driver) position.
     * Expects JSON: { latitude: float, longitude: float, timestamp?: string }
     */
    public function storeLivraisonPosition(Request $request, $id)
    {
        $data = $request->validate([
            'latitude' => 'required|numeric',
            'longitude' => 'required|numeric',
            'timestamp' => 'nullable|date',
        ]);

        $livraison = DB::table('livraisons')->where('id', $id)->first();
        if (!$livraison) {
            return response()->json(['error' => 'livraison_not_found'], 404);
        }

        $update = [
            'latitude' => $data['latitude'],
            'longitude' => $data['longitude'],
            'updated_at' => Carbon::now(),
        ];

        // Optionally update date_depart when provided and not set
        if (!empty($data['timestamp'])) {
            try {
                $ts = Carbon::parse($data['timestamp']);
                $update['date_depart'] = $ts;
            } catch (\Exception $e) {
                // ignore parse error; client may send incorrect timestamp
            }
        }

        DB::table('livraisons')->where('id', $id)->update($update);

        $fresh = DB::table('livraisons')->where('id', $id)->first();
        return response()->json(['ok' => true, 'livraison' => $fresh]);
    }

    /**
     * Return positions for livraisons. Optional ?since=ISO8601 to filter recent updates.
     */
    public function getLivraisonsPositions(Request $request)
    {
        $since = $request->query('since');
        $query = DB::table('livraisons')
            ->select('id','commande_id','livreur_id','adresse','telephone','statut','date_depart','date_livraison','latitude','longitude','updated_at');

        if (!empty($since)) {
            try {
                $dt = Carbon::parse($since);
                $query->where('updated_at', '>=', $dt);
            } catch (\Exception $e) {
                // ignore invalid since parameter
            }
        }

        $rows = $query->get();
        return response()->json($rows);
    }
}
