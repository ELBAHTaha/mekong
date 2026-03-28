<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use App\Models\Personnel;

class AuthController extends Controller
{
    public function login(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        $email = $request->input('email');
        $password = $request->input('password');

        $user = Personnel::where('email', $email)->first();
        if (!$user || !$user->actif) {
            return response()->json(['error' => 'Invalid credentials'], 401);
        }

        $stored = (string) $user->mot_de_passe;
        $passwordOk = false;
        if (strlen($stored) > 0) {
            if (Hash::check($password, $stored)) {
                $passwordOk = true;
            } elseif ($stored === $password) {
                $passwordOk = true;
            }
        }

        if (!$passwordOk) {
            return response()->json(['error' => 'Invalid credentials'], 401);
        }

        $token = Str::random(60);
        DB::table('auth_tokens')->insert([
            'token' => hash('sha256', $token),
            'personnel_id' => $user->id,
            'created_at' => now(),
            'expires_at' => now()->addDays(7),
        ]);

        return response()->json([
            'token' => $token,
            'user' => [
                'id' => $user->id,
                'nom' => $user->nom,
                'email' => $user->email,
                'role' => $user->role,
                'telephone' => $user->telephone,
            ],
        ]);
    }

    public function user(Request $request)
    {
        $authHeader = $request->header('Authorization');
        if (!$authHeader || !str_starts_with($authHeader, 'Bearer ')) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }
        $plain = substr($authHeader, 7);
        $hashed = hash('sha256', $plain);

        $row = DB::table('auth_tokens')->where('token', $hashed)->first();
        if (!$row || ($row->expires_at && now()->greaterThan($row->expires_at))) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        $user = Personnel::find($row->personnel_id);
        if (!$user) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        return response()->json([
            'id' => $user->id,
            'nom' => $user->nom,
            'email' => $user->email,
            'role' => $user->role,
            'telephone' => $user->telephone,
        ]);
    }

    public function update(Request $request)
    {
        $authHeader = $request->header('Authorization');
        if (!$authHeader || !str_starts_with($authHeader, 'Bearer ')) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }
        $plain = substr($authHeader, 7);
        $hashed = hash('sha256', $plain);

        $row = DB::table('auth_tokens')->where('token', $hashed)->first();
        if (!$row || ($row->expires_at && now()->greaterThan($row->expires_at))) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        $user = Personnel::find($row->personnel_id);
        if (!$user) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        $data = $request->only(['nom','email','telephone','mot_de_passe']);
        if (isset($data['nom'])) $user->nom = $data['nom'];
        if (isset($data['email'])) $user->email = $data['email'];
        if (isset($data['telephone'])) $user->telephone = $data['telephone'];
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

    public function forgotPassword(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
        ]);
        // Stub: in real app, send email or SMS
        return response()->json(['status' => 'accepted'], 202);
    }

    public function logout(Request $request)
    {
        $authHeader = $request->header('Authorization');
        if ($authHeader && str_starts_with($authHeader, 'Bearer ')) {
            $plain = substr($authHeader, 7);
            $hashed = hash('sha256', $plain);

            $row = DB::table('auth_tokens')->where('token', $hashed)->first();
            if ($row) {
                // update personnel last_login if exists
                $user = Personnel::find($row->personnel_id);
                if ($user) {
                    $user->last_login = now();
                    $user->save();
                }

                // remove token
                DB::table('auth_tokens')->where('token', $hashed)->delete();
            }
        }

        return response()->json(['status' => 'logged_out']);
    }
}
