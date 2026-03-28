<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\TableRestaurant;

class TablesController extends Controller
{
    public function index()
    {
        return response()->json(TableRestaurant::orderBy('numero')->get());
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'numero' => 'required|integer|min:1',
            'etat' => 'required|in:LIBRE,OCCUPEE,RESERVEE',
            'x' => 'required|integer',
            'y' => 'required|integer',
        ]);

        $table = TableRestaurant::create($data);
        return response()->json($table, 201);
    }

    public function show($id)
    {
        $table = TableRestaurant::findOrFail($id);
        return response()->json($table);
    }

    public function update(Request $request, $id)
    {
        $table = TableRestaurant::findOrFail($id);
        $data = $request->validate([
            'numero' => 'sometimes|integer|min:1',
            'etat' => 'sometimes|in:LIBRE,OCCUPEE,RESERVEE',
            'x' => 'sometimes|integer',
            'y' => 'sometimes|integer',
        ]);

        $table->update($data);
        return response()->json($table);
    }

    public function destroy($id)
    {
        $table = TableRestaurant::findOrFail($id);
        $table->delete();
        return response()->json(null, 204);
    }
}
