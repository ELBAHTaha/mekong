# Mekong Flutter

Client Flutter minimal pour interagir avec le backend Laravel.

Prerequis:
- Flutter installé
- Le backend Laravel en marche (par ex. `php artisan serve --host=127.0.0.1 --port=8000`)

Runnning:

```bash
cd flutter_app
flutter pub get
flutter run
```

Configuration:
- L'URL du backend est configurée dans `lib/services/api_service.dart` (par défaut `http://127.0.0.1:8000/api`).

Prochaines étapes proposées:
- Ajouter stockage sécurisé du token (flutter_secure_storage)
- Gérer erreurs / validations côté formulaire
- Générer modèles plus complets depuis l'API
