<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use App\Models\Produit;
use App\Models\CategorieProduit;

class ProductsController extends Controller
{
    private function authFromRequest(Request $request)
    {
        $authHeader = $request->header('Authorization');
        if (!$authHeader || !str_starts_with($authHeader, 'Bearer ')) {
            return null;
        }
        $plain = substr($authHeader, 7);
        $hashed = hash('sha256', $plain);

        $row = DB::table('auth_tokens')->where('token', $hashed)->first();
        if (!$row || ($row->expires_at && now()->greaterThan($row->expires_at))) {
            return null;
        }

        return DB::table('personnel')->where('id', $row->personnel_id)->first();
    }

    public function index(Request $request)
    {
        $me = $this->authFromRequest($request);
        if (!$me) return response()->json(['error' => 'Unauthorized'], 401);

        $items = DB::table('produits as p')
            ->leftJoin('categories_produits as c', 'p.categorie_id', '=', 'c.id')
            ->select('p.*', 'c.nom as categorie_nom', 'c.photo as categorie_photo')
            ->orderBy('p.nom')
            ->get();

        return response()->json(['data' => $items]);
    }

    public function show(Request $request, $id)
    {
        $me = $this->authFromRequest($request);
        if (!$me) return response()->json(['error' => 'Unauthorized'], 401);

        $item = DB::table('produits as p')
            ->leftJoin('categories_produits as c', 'p.categorie_id', '=', 'c.id')
            ->select('p.*', 'c.nom as categorie_nom', 'c.photo as categorie_photo')
            ->where('p.id', $id)
            ->first();

        if (!$item) return response()->json(['error' => 'Not found'], 404);
        return response()->json($item);
    }

    public function store(Request $request)
    {
        $me = $this->authFromRequest($request);
        if (!$me) return response()->json(['error' => 'Unauthorized'], 401);

        $data = $request->validate([
            'nom' => 'required|string|max:150',
            'description' => 'nullable|string',
            'prix' => 'required|numeric',
            'photo' => 'nullable|string|max:255',
            'categorie_id' => 'nullable|integer|exists:categories_produits,id',
            'actif' => 'nullable|boolean',
            'Disponible' => 'nullable|in:OUI,NON',
        ]);

        $prod = new Produit();
        $prod->nom = $data['nom'];
        $prod->description = $data['description'] ?? null;
        $prod->prix = $data['prix'];
        $prod->photo = $data['photo'] ?? null;
        $prod->categorie_id = $data['categorie_id'] ?? null;
        $prod->actif = isset($data['actif']) ? (bool)$data['actif'] : 1;
        $prod->Disponible = $data['Disponible'] ?? null;
        $prod->created_at = now();
        $prod->save();

        return response()->json([
            'id' => $prod->id,
            'nom' => $prod->nom,
            'description' => $prod->description,
            'prix' => $prod->prix,
            'photo' => $prod->photo,
            'categorie_id' => $prod->categorie_id,
            'actif' => $prod->actif,
            'Disponible' => $prod->Disponible,
        ], 201);
    }

    public function update(Request $request, $id)
    {
        $me = $this->authFromRequest($request);
        if (!$me) return response()->json(['error' => 'Unauthorized'], 401);

        $prod = Produit::find($id);
        if (!$prod) return response()->json(['error' => 'Not found'], 404);

        $data = $request->validate([
            'nom' => 'nullable|string|max:150',
            'description' => 'nullable|string',
            'prix' => 'nullable|numeric',
            'photo' => 'nullable|string|max:255',
            'categorie_id' => 'nullable|integer|exists:categories_produits,id',
            'actif' => 'nullable|boolean',
            'Disponible' => 'nullable|in:OUI,NON',
        ]);

        if (isset($data['nom'])) $prod->nom = $data['nom'];
        if (array_key_exists('description', $data)) $prod->description = $data['description'];
        if (isset($data['prix'])) $prod->prix = $data['prix'];
        if (array_key_exists('photo', $data)) $prod->photo = $data['photo'];
        if (isset($data['categorie_id'])) $prod->categorie_id = $data['categorie_id'];
        if (isset($data['actif'])) $prod->actif = (bool)$data['actif'];
        if (isset($data['Disponible'])) $prod->Disponible = $data['Disponible'];

        $prod->save();

        return response()->json([
            'id' => $prod->id,
            'nom' => $prod->nom,
            'description' => $prod->description,
            'prix' => $prod->prix,
            'photo' => $prod->photo,
            'categorie_id' => $prod->categorie_id,
            'actif' => $prod->actif,
            'Disponible' => $prod->Disponible,
        ]);
    }

    public function destroy(Request $request, $id)
    {
        $me = $this->authFromRequest($request);
        if (!$me) return response()->json(['error' => 'Unauthorized'], 401);

        $prod = Produit::find($id);
        if (!$prod) return response()->json(['error' => 'Not found'], 404);

        $prod->delete();
        return response()->json(['status' => 'deleted']);
    }
}
