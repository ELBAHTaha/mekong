<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Models\Charge;
use App\Models\CategorieCharge;

class ChargesController extends Controller
{
    // Basic token check similar to AuthController
    protected function authFromRequest(Request $request)
    {
        $authHeader = $request->header('Authorization');
        if (!$authHeader || !str_starts_with($authHeader, 'Bearer ')) return null;
        $plain = substr($authHeader, 7);
        $hashed = hash('sha256', $plain);
        $row = DB::table('auth_tokens')->where('token', $hashed)->first();
        if (!$row || ($row->expires_at && now()->greaterThan($row->expires_at))) return null;
        $user = DB::table('personnel')->where('id', $row->personnel_id)->first();
        return $user;
    }

    // Categories
    public function categoriesIndex(Request $request)
    {
        $cats = CategorieCharge::orderBy('nom')->get();
        return response()->json($cats);
    }

    public function categoriesStore(Request $request)
    {
        $request->validate(['nom' => 'required|string|max:150']);
        $cat = CategorieCharge::create(['nom' => $request->input('nom')]);
        return response()->json($cat, 201);
    }

    public function categoriesShow(Request $request, $id)
    {
        $cat = CategorieCharge::find($id);
        if (!$cat) return response()->json(['error' => 'not_found'], 404);
        return response()->json($cat);
    }

    public function categoriesUpdate(Request $request, $id)
    {
        $cat = CategorieCharge::find($id);
        if (!$cat) return response()->json(['error' => 'not_found'], 404);
        $data = $request->only(['nom']);
        $cat->fill($data);
        $cat->save();
        return response()->json($cat);
    }

    public function categoriesDestroy(Request $request, $id)
    {
        $cat = CategorieCharge::find($id);
        if (!$cat) return response()->json(['error' => 'not_found'], 404);
        // optional: prevent deletion if charges exist
        $count = Charge::where('categorie_id', $cat->id)->count();
        if ($count > 0) {
            return response()->json(['error' => 'category_has_charges'], 400);
        }
        $cat->delete();
        return response()->json(['status' => 'deleted']);
    }

    // Charges
    public function index(Request $request)
    {
        $q = Charge::query();
        if ($request->has('categorie_id')) {
            $q->where('categorie_id', $request->input('categorie_id'));
        }
        if ($request->has('from')) {
            $q->whereDate('date_charge', '>=', $request->input('from'));
        }
        if ($request->has('to')) {
            $q->whereDate('date_charge', '<=', $request->input('to'));
        }
        if ($request->has('search')) {
            $s = $request->input('search');
            $q->where(function($w) use ($s) {
                $w->where('titre', 'like', "%$s%")
                  ->orWhere('description', 'like', "%$s%");
            });
        }
        $charges = $q->orderByDesc('date_charge')->get();
        return response()->json($charges);
    }

    public function store(Request $request)
    {
        $request->validate([
            'titre' => 'nullable|string|max:150',
            'montant' => 'required|numeric',
            'categorie_id' => 'nullable|integer',
            'date_charge' => 'nullable|date',
            'description' => 'nullable|string',
        ]);
        $c = Charge::create($request->only(['titre','montant','categorie_id','date_charge','description']));
        return response()->json($c, 201);
    }

    public function show(Request $request, $id)
    {
        $c = Charge::find($id);
        if (!$c) return response()->json(['error' => 'not_found'], 404);
        return response()->json($c);
    }

    public function update(Request $request, $id)
    {
        $c = Charge::find($id);
        if (!$c) return response()->json(['error' => 'not_found'], 404);
        $data = $request->only(['titre','montant','categorie_id','date_charge','description']);
        $c->fill($data);
        $c->save();
        return response()->json($c);
    }

    public function destroy(Request $request, $id)
    {
        $c = Charge::find($id);
        if (!$c) return response()->json(['error' => 'not_found'], 404);
        $c->delete();
        return response()->json(['status' => 'deleted']);
    }
}
