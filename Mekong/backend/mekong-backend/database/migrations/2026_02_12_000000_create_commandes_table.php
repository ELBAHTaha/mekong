<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateCommandesTable extends Migration
{
    public function up()
    {
        Schema::create('commandes', function (Blueprint $table) {
            $table->id();
            $table->string('client_nom', 150)->nullable();
            $table->enum('type', ['SUR_PLACE','LIVRAISON'])->default('SUR_PLACE');
            $table->enum('statut', ['NOUVELLE','PREPARATION','PRETE','LIVRAISON','LIVREE','ANNULEE'])->default('NOUVELLE');
            $table->decimal('total', 10, 2)->default(0);
            $table->unsignedBigInteger('table_id')->nullable();
            $table->unsignedBigInteger('caissier_id')->nullable();
            $table->timestamp('date_commande')->useCurrent();
            $table->string('adresse')->nullable();
            $table->string('telephone')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->foreign('table_id')->references('id')->on('tables_restaurant')->onDelete('set null');
            $table->foreign('caissier_id')->references('id')->on('personnel')->onDelete('set null');
        });
    }

    public function down()
    {
        Schema::dropIfExists('commandes');
    }
}
