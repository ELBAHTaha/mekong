<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateBaseSchema extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        if (!Schema::hasTable('personnel')) {
            Schema::create('personnel', function (Blueprint $table) {
            $table->increments('id');
            $table->string('nom', 100);
            $table->string('email', 150)->unique();
            $table->string('mot_de_passe', 255);
            $table->enum('role', ['ADMIN', 'CAISSIER', 'CUISINE', 'LIVREUR']);
            $table->string('telephone', 30)->nullable();
            $table->boolean('actif')->default(true);
            $table->timestamp('created_at')->useCurrent();
            $table->timestamp('last_login')->nullable();
            });
        }

        if (!Schema::hasTable('categories_produits')) {
            Schema::create('categories_produits', function (Blueprint $table) {
            $table->increments('id');
            $table->string('nom', 100);
            $table->timestamp('created_at')->useCurrent();
            });
        }

        if (!Schema::hasTable('produits')) {
            Schema::create('produits', function (Blueprint $table) {
            $table->increments('id');
            $table->string('nom', 150);
            $table->text('description')->nullable();
            $table->decimal('prix', 10, 2);
            $table->string('photo', 255)->nullable();
            $table->unsignedInteger('categorie_id')->nullable();
            $table->boolean('actif')->default(true);
            $table->timestamp('created_at')->useCurrent();
            $table->foreign('categorie_id')->references('id')->on('categories_produits')->onDelete('set null');
            });
        }

        if (!Schema::hasTable('ingredients')) {
            Schema::create('ingredients', function (Blueprint $table) {
            $table->increments('id');
            $table->string('nom', 150);
            $table->decimal('stock', 10, 2)->default(0);
            $table->string('unite', 20)->nullable();
            $table->timestamp('created_at')->useCurrent();
            });
        }

        if (!Schema::hasTable('produit_ingredients')) {
            Schema::create('produit_ingredients', function (Blueprint $table) {
            $table->increments('id');
            $table->unsignedInteger('produit_id');
            $table->unsignedInteger('ingredient_id');
            $table->decimal('quantite', 10, 2)->nullable();
            $table->foreign('produit_id')->references('id')->on('produits')->onDelete('cascade');
            $table->foreign('ingredient_id')->references('id')->on('ingredients')->onDelete('cascade');
            });
        }

        if (!Schema::hasTable('tables_restaurant')) {
            Schema::create('tables_restaurant', function (Blueprint $table) {
                $table->increments('id');
                $table->integer('numero');
                $table->integer('X')->nullable();
                $table->integer('Y')->nullable();
                $table->enum('etat', ['LIBRE', 'OCCUPEE', 'RESERVEE'])->default('LIBRE');
            });
        }

        if (!Schema::hasTable('commandes')) {
            Schema::create('commandes', function (Blueprint $table) {
                $table->increments('id');
                $table->string('client_nom', 150)->nullable();
                $table->enum('type', ['SUR_PLACE', 'LIVRAISON']);
                $table->enum('statut', ['NOUVELLE','PREPARATION','PRETE','LIVRAISON','LIVREE','ANNULEE'])->default('NOUVELLE');
                $table->decimal('total', 10, 2)->default(0);
                $table->unsignedInteger('table_id')->nullable();
                $table->unsignedInteger('caissier_id')->nullable();
                $table->timestamp('date_commande')->useCurrent();
                $table->foreign('table_id')->references('id')->on('tables_restaurant')->onDelete('set null');
                $table->foreign('caissier_id')->references('id')->on('personnel')->onDelete('set null');
            });
        }

        if (!Schema::hasTable('commande_produits')) {
            Schema::create('commande_produits', function (Blueprint $table) {
                $table->increments('id');
                $table->unsignedInteger('commande_id');
                $table->unsignedInteger('produit_id');
                $table->integer('quantite')->default(1);
                $table->decimal('prix_unitaire', 10, 2)->nullable();
                $table->foreign('commande_id')->references('id')->on('commandes')->onDelete('cascade');
                $table->foreign('produit_id')->references('id')->on('produits');
            });
        }

        if (!Schema::hasTable('paiements')) {
            Schema::create('paiements', function (Blueprint $table) {
                $table->increments('id');
                $table->unsignedInteger('commande_id');
                $table->decimal('montant', 10, 2)->nullable();
                $table->enum('mode', ['CASH','CARTE','EN_LIGNE'])->nullable();
                $table->timestamp('date_paiement')->useCurrent();
                $table->foreign('commande_id')->references('id')->on('commandes');
            });
        }

        if (!Schema::hasTable('livraisons')) {
            Schema::create('livraisons', function (Blueprint $table) {
                $table->increments('id');
                $table->unsignedInteger('commande_id');
                $table->unsignedInteger('livreur_id')->nullable();
                $table->text('adresse')->nullable();
                $table->string('telephone', 30)->nullable();
                $table->enum('statut', ['EN_ATTENTE','EN_ROUTE','LIVREE','ANNULEE'])->default('EN_ATTENTE');
                $table->timestamp('date_depart')->nullable();
                $table->timestamp('date_livraison')->nullable();
                $table->foreign('commande_id')->references('id')->on('commandes');
                $table->foreign('livreur_id')->references('id')->on('personnel');
            });
        }

        if (!Schema::hasTable('categories_charges')) {
            Schema::create('categories_charges', function (Blueprint $table) {
                $table->increments('id');
                $table->string('nom', 150);
            });
        }

        if (!Schema::hasTable('charges')) {
            Schema::create('charges', function (Blueprint $table) {
                $table->increments('id');
                $table->string('titre', 150)->nullable();
                $table->decimal('montant', 10, 2)->nullable();
                $table->unsignedInteger('categorie_id')->nullable();
                $table->date('date_charge')->nullable();
                $table->text('description')->nullable();
                $table->foreign('categorie_id')->references('id')->on('categories_charges');
            });
        }
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('charges');
        Schema::dropIfExists('categories_charges');
        Schema::dropIfExists('livraisons');
        Schema::dropIfExists('paiements');
        Schema::dropIfExists('commande_produits');
        Schema::dropIfExists('commandes');
        Schema::dropIfExists('tables_restaurant');
        Schema::dropIfExists('produit_ingredients');
        Schema::dropIfExists('ingredients');
        Schema::dropIfExists('produits');
        Schema::dropIfExists('categories_produits');
        Schema::dropIfExists('personnel');
    }
}
