<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ApiController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\UsersController;
use App\Http\Controllers\ProductsController;
use App\Http\Controllers\CategoriesController;
use App\Http\Controllers\ChargesController;
use App\Http\Controllers\CommandesController;

Route::get('/hello', [ApiController::class, 'hello']);
Route::get('/dashboard', [ApiController::class, 'dashboard']);
Route::get('/ventes-par-mois', [ApiController::class, 'ventesParMois']);
Route::post('/login', [AuthController::class, 'login']);
Route::post('/logout', [AuthController::class, 'logout']);
Route::get('/user', [AuthController::class, 'user']);
Route::match(['put','patch'],'/user', [AuthController::class, 'update']);
Route::post('/forgot-password', [AuthController::class, 'forgotPassword']);

// Personnel / users management
Route::get('/personnel', [UsersController::class, 'index']);
Route::post('/personnel', [UsersController::class, 'store']);
Route::get('/personnel/{id}', [UsersController::class, 'show']);
Route::match(['put','patch'], '/personnel/{id}', [UsersController::class, 'update']);
Route::delete('/personnel/{id}', [UsersController::class, 'destroy']);

// Produits
Route::get('/produits', [ProductsController::class, 'index']);
Route::post('/produits', [ProductsController::class, 'store']);
Route::get('/produits/{id}', [ProductsController::class, 'show']);
Route::match(['put','patch'], '/produits/{id}', [ProductsController::class, 'update']);
Route::delete('/produits/{id}', [ProductsController::class, 'destroy']);

// Categories produits
Route::get('/categories_produits', [CategoriesController::class, 'index']);
Route::post('/categories_produits', [CategoriesController::class, 'store']);
Route::get('/categories_produits/{id}', [CategoriesController::class, 'show']);
Route::match(['put','patch'], '/categories_produits/{id}', [CategoriesController::class, 'update']);
Route::delete('/categories_produits/{id}', [CategoriesController::class, 'destroy']);

// Tables restaurant
use App\Http\Controllers\TablesController;
Route::get('/tables_restaurant', [TablesController::class, 'index']);
Route::post('/tables_restaurant', [TablesController::class, 'store']);
Route::get('/tables_restaurant/{id}', [TablesController::class, 'show']);
Route::match(['put','patch'], '/tables_restaurant/{id}', [TablesController::class, 'update']);
Route::delete('/tables_restaurant/{id}', [TablesController::class, 'destroy']);

// Charges & catégories
Route::get('/categories_charges', [ChargesController::class, 'categoriesIndex']);
Route::post('/categories_charges', [ChargesController::class, 'categoriesStore']);
Route::get('/categories_charges/{id}', [ChargesController::class, 'categoriesShow']);
Route::match(['put','patch'], '/categories_charges/{id}', [ChargesController::class, 'categoriesUpdate']);
Route::delete('/categories_charges/{id}', [ChargesController::class, 'categoriesDestroy']);

Route::get('/charges', [ChargesController::class, 'index']);
Route::post('/charges', [ChargesController::class, 'store']);
Route::get('/charges/{id}', [ChargesController::class, 'show']);
Route::match(['put','patch'], '/charges/{id}', [ChargesController::class, 'update']);
Route::delete('/charges/{id}', [ChargesController::class, 'destroy']);

// Commandes
Route::get('/commandes', [CommandesController::class, 'index']);
Route::post('/commandes', [CommandesController::class, 'store']);
Route::get('/commandes/{id}', [CommandesController::class, 'show']);
Route::match(['put','patch'], '/commandes/{id}', [CommandesController::class, 'update']);
Route::delete('/commandes/{id}', [CommandesController::class, 'destroy']);

// Livraisons positions (real-time tracking)
Route::post('/livraisons/{id}/position', [ApiController::class, 'storeLivraisonPosition']);
Route::get('/livraisons/positions', [ApiController::class, 'getLivraisonsPositions']);

// DEBUG: create a short-lived token for the first active personnel (local only)
use Illuminate\Support\Str;
use Illuminate\Support\Facades\DB;
use App\Models\Personnel;
if (env('APP_ENV') === 'local') {
	Route::get('/_debug_token', function () {
		$user = Personnel::where('actif', 1)->first();
		if (!$user) return response()->json(['error' => 'no_user'], 404);
		$token = Str::random(60);
		DB::table('auth_tokens')->insert([
			'token' => hash('sha256', $token),
			'personnel_id' => $user->id,
			'created_at' => now(),
			'expires_at' => now()->addMinutes(30),
		]);
		return response()->json(['token' => $token, 'user' => ['id' => $user->id, 'nom' => $user->nom]]);
	});
}
