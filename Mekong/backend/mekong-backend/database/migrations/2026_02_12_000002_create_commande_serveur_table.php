<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateCommandeServeurTable extends Migration
{
    public function up()
    {
        Schema::create('commande_serveur', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('serveur_id')->nullable();
            $table->string('serveur_nom', 150)->nullable();
            $table->integer('table_numero')->nullable();
            $table->json('items')->nullable();
            $table->decimal('total', 10, 2)->default(0);
            $table->enum('type_commande', ['SUR_PLACE','LIVRAISON'])->default('SUR_PLACE');
            $table->text('notes')->nullable();
            $table->enum('statut', ['NOUVELLE','PREPARATION','PRETE','LIVRAISON','LIVREE','ANNULEE'])->default('NOUVELLE');
            $table->timestamp('date_commande')->useCurrent();
            $table->timestamps();

            $table->foreign('serveur_id')->references('id')->on('personnel')->onDelete('set null');
        });
    }

    public function down()
    {
        Schema::dropIfExists('commande_serveur');
    }
}
