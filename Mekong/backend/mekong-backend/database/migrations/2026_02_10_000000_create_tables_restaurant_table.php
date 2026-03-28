<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateTablesRestaurantTable extends Migration
{
    public function up()
    {
        Schema::create('tables_restaurant', function (Blueprint $table) {
            $table->id();
            $table->integer('numero');
            $table->string('etat', 20);
            $table->integer('x');
            $table->integer('y');
            $table->timestamps();
        });
    }

    public function down()
    {
        Schema::dropIfExists('tables_restaurant');
    }
}
