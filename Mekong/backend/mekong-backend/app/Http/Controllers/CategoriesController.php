<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use App\Models\CategorieProduit;

class CategoriesController extends Controller
{
    private function storeUploadedPhoto(Request $request, string $folder): ?string
    {
        if (!$request->hasFile('photo_file')) {
            return null;
        }
        $file = $request->file('photo_file');
        if (!$file || !$file->isValid()) {
            return null;
        }
        return $file->store($folder, 'public');
    }

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

        $items = CategorieProduit::orderBy('nom')->get();
        return response()->json(['data' => $items]);
    }

    public function show(Request $request, $id)
    {
        $me = $this->authFromRequest($request);
        if (!$me) return response()->json(['error' => 'Unauthorized'], 401);

        $item = CategorieProduit::find($id);
        if (!$item) return response()->json(['error' => 'Not found'], 404);
        return response()->json($item);
    }

    public function store(Request $request)
    {
        $me = $this->authFromRequest($request);
        if (!$me) return response()->json(['error' => 'Unauthorized'], 401);

        $data = $request->validate([
            'nom' => 'required|string|max:150',
            'photo' => 'nullable|string|max:255',
            'photo_file' => 'nullable|file|image|max:5120',
        ]);

        $cat = new CategorieProduit();
        $cat->nom = $data['nom'];
        $uploaded = $this->storeUploadedPhoto($request, 'uploads/categories');
        $cat->photo = $uploaded ?? ($data['photo'] ?? null);
        $cat->created_at = now();
        $cat->save();

        return response()->json([
            'id' => $cat->id,
            'nom' => $cat->nom,
            'photo' => $cat->photo,
        ], 201);
    }

    public function update(Request $request, $id)
    {
        $me = $this->authFromRequest($request);
        if (!$me) return response()->json(['error' => 'Unauthorized'], 401);

        $cat = CategorieProduit::find($id);
        if (!$cat) return response()->json(['error' => 'Not found'], 404);

        $data = $request->validate([
            'nom' => 'nullable|string|max:150',
            'photo' => 'nullable|string|max:255',
            'photo_file' => 'nullable|file|image|max:5120',
        ]);

        if (isset($data['nom'])) $cat->nom = $data['nom'];
        $uploaded = $this->storeUploadedPhoto($request, 'uploads/categories');
        if ($uploaded) {
            $cat->photo = $uploaded;
        } elseif (array_key_exists('photo', $data)) {
            $cat->photo = $data['photo'];
        }
        $cat->save();

        return response()->json([
            'id' => $cat->id,
            'nom' => $cat->nom,
            'photo' => $cat->photo,
        ]);
    }

    public function destroy(Request $request, $id)
    {
        $me = $this->authFromRequest($request);
        if (!$me) return response()->json(['error' => 'Unauthorized'], 401);

        $cat = CategorieProduit::find($id);
        if (!$cat) return response()->json(['error' => 'Not found'], 404);

        $cat->delete();
        return response()->json(['status' => 'deleted']);
    }
}
