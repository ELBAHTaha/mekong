<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Database\QueryException;
use Throwable;
use App\Models\Personnel;

class UsersController extends Controller
{
    /**
     * Return the authenticated Personnel via bearer token, or null.
     */
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

        return Personnel::find($row->personnel_id);
    }

    public function index(Request $request)
    {
        $me = $this->authFromRequest($request);
        if (!$me) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        $users = Personnel::orderBy('nom')->get(['id', 'nom', 'email', 'role', 'telephone', 'actif']);
        return response()->json(['data' => $users]);
    }

    public function show(Request $request, $id)
    {
        $me = $this->authFromRequest($request);
        if (!$me) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        $user = Personnel::find($id);
        if (!$user) {
            return response()->json(['error' => 'Not found'], 404);
        }

        return response()->json([
            'id' => $user->id,
            'nom' => $user->nom,
            'email' => $user->email,
            'role' => $user->role,
            'telephone' => $user->telephone,
            'actif' => $user->actif,
        ]);
    }

    public function store(Request $request)
    {
        $me = $this->authFromRequest($request);
        if (!$me) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        $data = $request->validate([
            'nom' => 'required|string|max:255',
            'email' => 'required|email|max:255|unique:personnel,email',
            'telephone' => 'nullable|string|max:50',
            'role' => 'nullable|string|max:100',
            'mot_de_passe' => 'nullable|string|min:6',
            'actif' => 'nullable|boolean',
        ]);

        $user = new Personnel();
        $user->nom = $data['nom'];
        $user->email = $data['email'];
        $user->telephone = $data['telephone'] ?? null;
        $user->role = $data['role'] ?? null;
        $user->actif = isset($data['actif']) ? (bool) $data['actif'] : true;
        if (!empty($data['mot_de_passe'])) {
            $user->mot_de_passe = Hash::make($data['mot_de_passe']);
        } else {
            $user->mot_de_passe = null;
        }
        $user->created_at = now();
        $user->save();

        return response()->json([
            'id' => $user->id,
            'nom' => $user->nom,
            'email' => $user->email,
            'role' => $user->role,
            'telephone' => $user->telephone,
        ], 201);
    }

    public function update(Request $request, $id)
    {
        $me = $this->authFromRequest($request);
        if (!$me) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        $user = Personnel::find($id);
        if (!$user) {
            return response()->json(['error' => 'Not found'], 404);
        }

        $data = $request->validate([
            'nom' => 'nullable|string|max:255',
            'email' => 'nullable|email|max:255|unique:personnel,email,' . $id,
            'telephone' => 'nullable|string|max:50',
            'role' => 'nullable|string|max:100',
            'mot_de_passe' => 'nullable|string|min:6',
            'actif' => 'nullable|boolean',
        ]);

        if (isset($data['nom'])) $user->nom = $data['nom'];
        if (isset($data['email'])) $user->email = $data['email'];
        if (array_key_exists('telephone', $data)) $user->telephone = $data['telephone'];
        if (isset($data['role'])) $user->role = $data['role'];
        if (isset($data['actif'])) $user->actif = (bool) $data['actif'];
        if (!empty($data['mot_de_passe'])) {
            $user->mot_de_passe = Hash::make($data['mot_de_passe']);
        }

        $user->save();

        return response()->json([
            'id' => $user->id,
            'nom' => $user->nom,
            'email' => $user->email,
            'role' => $user->role,
            'telephone' => $user->telephone,
        ]);
    }

    public function destroy(Request $request, $id)
    {
        $me = $this->authFromRequest($request);
        if (!$me) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        $user = Personnel::find($id);
        if (!$user) {
            return response()->json(['error' => 'Not found'], 404);
        }

        // Try to remove permanently; first clear or reassign FK references to allow deletion
        try {
            DB::beginTransaction();

            // Find FK constraints referencing personnel.id in the current database
            $refs = DB::select(
                "SELECT k.TABLE_NAME, k.COLUMN_NAME, c.IS_NULLABLE
                 FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE k
                 JOIN INFORMATION_SCHEMA.COLUMNS c
                   ON k.TABLE_NAME = c.TABLE_NAME AND k.COLUMN_NAME = c.COLUMN_NAME AND c.TABLE_SCHEMA = k.CONSTRAINT_SCHEMA
                 WHERE k.REFERENCED_TABLE_NAME = 'personnel' AND k.REFERENCED_COLUMN_NAME = 'id' AND k.CONSTRAINT_SCHEMA = DATABASE()"
            );

            // Choose a replacement id for non-nullable FKs: prefer an active ADMIN, else any active user
            $replacementId = Personnel::where('role', 'ADMIN')->where('actif', 1)->value('id');
            if (!$replacementId) {
                $replacementId = Personnel::where('actif', 1)->value('id');
            }

            foreach ($refs as $r) {
                $table = $r->TABLE_NAME;
                $col = $r->COLUMN_NAME;
                $nullable = strtoupper($r->IS_NULLABLE) === 'YES';

                if ($nullable) {
                    DB::table($table)->where($col, $user->id)->update([$col => null]);
                } else {
                    if (!$replacementId) {
                        // cannot reassign non-nullable FK if no replacement exists
                        DB::rollBack();
                        return response()->json(['error' => 'Cannot delete user: referenced by other records and no replacement available'], 409);
                    }
                    DB::table($table)->where($col, $user->id)->update([$col => $replacementId]);
                }
            }

            $user->delete();
            DB::commit();
            return response()->json(['status' => 'deleted']);
        } catch (Throwable $e) {
            DB::rollBack();
            if ($e instanceof QueryException && ($e->getCode() === '23000' || str_contains($e->getMessage(), 'foreign key'))) {
                return response()->json(['error' => 'Cannot delete user: referenced by other records'], 409);
            }
            return response()->json(['error' => 'Database error', 'detail' => $e->getMessage()], 500);
        }
    }
}
