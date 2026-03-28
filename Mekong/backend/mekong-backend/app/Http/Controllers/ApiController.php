<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Carbon;

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


        // Commandes récentes du jour: combiner `commandes` et `commande_serveur`, trier par date
        $recentCommandes = DB::table('commandes')
            ->whereDate('date_commande', $today)
            ->orderByDesc('date_commande')
            ->limit(10)
            ->get(['id','client_nom','statut','total','date_commande','type']);

        $recentServeur = DB::table('commande_serveur')
            ->whereDate('commande_serveur.date_commande', $today)
            ->leftJoin('personnel', 'commande_serveur.serveur_id', '=', 'personnel.id')
            ->orderByDesc('commande_serveur.date_commande')
            ->limit(10)
            ->get(['commande_serveur.id', DB::raw('personnel.nom as client_nom'), 'commande_serveur.statut', 'commande_serveur.total', 'commande_serveur.date_commande', DB::raw("'serveur' as type")]);

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
