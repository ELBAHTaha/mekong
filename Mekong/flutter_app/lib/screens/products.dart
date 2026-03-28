import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({Key? key}) : super(key: key);

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  // État pour suivre la catégorie sélectionnée
  String? _selectedCategory;

  // Catégories et produits chargés depuis l'API
  final List<Category> _categories = [];
  final Map<String, List<Product>> _productsByCategory = {};

  bool _loading = false;
  final ApiService _api = ApiService();

  String _resolveImageUrl(String? raw) {
    if (raw == null) return '';
    final value = raw.trim();
    if (value.isEmpty) return '';
    final base = Uri.parse(_api.baseUrl);
    final origin = '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
    String normalizePath(String path) {
      final trimmed = path.startsWith('/') ? path.substring(1) : path;
      if (trimmed.startsWith('uploads/')) {
        return '/storage/$trimmed';
      }
      if (trimmed.startsWith('storage/')) {
        return '/$trimmed';
      }
      return path.startsWith('/') ? path : '/$path';
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      try {
        final uri = Uri.parse(value);
        final host = uri.host.toLowerCase();
        final normalizedPath = normalizePath(uri.path.isEmpty ? '/' : uri.path);
        if (host == 'localhost' || host == '127.0.0.1') {
          final rebuilt =
              '$origin$normalizedPath${uri.hasQuery ? '?${uri.query}' : ''}';
          return rebuilt;
        }
        if (normalizedPath != uri.path) {
          return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}$normalizedPath'
              '${uri.hasQuery ? '?${uri.query}' : ''}';
        }
      } catch (_) {
        // fall through to raw value
      }
      return value;
    }
    final normalized = normalizePath(value);
    return '$origin$normalized';
  }

  @override
  void initState() {
    super.initState();
    // Charger les produits et catégories depuis l'API
    _loadProductsFromApi();
  }

  Future<String?> _pickImagePath() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      return file?.path;
    } catch (_) {
      return null;
    }
  }

  Widget _imageBox(String? url, {double? width, double? height, BorderRadius? radius}) {
    final r = radius ?? BorderRadius.circular(12);
    final resolved = _resolveImageUrl(url);
    if (resolved.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: r,
        ),
        child: const Icon(Icons.image_outlined, color: Colors.white54, size: 40),
      );
    }
    return ClipRRect(
      borderRadius: r,
      child: Image.network(
        resolved,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: height,
          color: Colors.white10,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: Colors.white54),
        ),
      ),
    );
  }

  void _showEditProductDialog(Product product) {
    final nameCtrl = TextEditingController(text: product.name);
    final descCtrl = TextEditingController(text: product.description);
    final priceCtrl = TextEditingController(text: product.price.toString());
    String? imagePath;
    bool isAvailable = product.isAvailable;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setStateDialog) {
            return Dialog(
              backgroundColor: const Color(0xFF1B1D20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Modifier le produit',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700)),
                          IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close,
                                  color: Colors.white70)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                          controller: nameCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                              labelText: 'Nom',
                              labelStyle:
                                  const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.03))),
                      const SizedBox(height: 12),
                      TextField(
                          controller: descCtrl,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                              labelText: 'Description',
                              labelStyle:
                                  const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.03))),
                      const SizedBox(height: 12),
                      TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                              labelText: 'Prix',
                              labelStyle:
                                  const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.03))),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final path = await _pickImagePath();
                                setStateDialog(() => imagePath = path);
                              },
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Changer l\'image'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: Colors.white30),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (imagePath != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(imagePath!),
                            width: double.infinity,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        _imageBox(product.imageUrl, width: double.infinity, height: 150),
                      const SizedBox(height: 12),
                      Row(children: [
                        const Text('Disponible',
                            style: TextStyle(color: Colors.white70)),
                        const SizedBox(width: 12),
                        Switch(
                            value: isAvailable,
                            onChanged: (v) =>
                                setStateDialog(() => isAvailable = v),
                            activeColor: const Color(0xFFD43B3B)),
                      ]),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                            child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white70),
                                child: const Text('Annuler'))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: ElevatedButton(
                                onPressed: () async {
                                  if (nameCtrl.text.isEmpty) return;
                                  try {
                                    // find category id for this product
                                    final catKey = _productsByCategory.keys
                                        .firstWhere(
                                            (k) => _productsByCategory[k]!
                                                .any((p) => p.id == product.id),
                                            orElse: () => '');
                                    final catObj = _categories.firstWhere(
                                        (c) => c.name == catKey,
                                        orElse: () => Category(
                                            id: 0,
                                            name: catKey,
                                            description: '',
                                            imageUrl: '',
                                            color: Colors.grey));
                                    final payload = {
                                      'nom': nameCtrl.text,
                                      'description': descCtrl.text,
                                      'prix': double.tryParse(priceCtrl.text) ??
                                          product.price,
                                      if (imagePath != null)
                                        'photo_file_path': imagePath!,
                                      'categorie_id':
                                          catObj.id == 0 ? null : catObj.id,
                                      'actif': isAvailable ? 1 : 0,
                                      'Disponible': isAvailable ? 'OUI' : 'NON',
                                    };
                                    final res = await _api.updateProduct(
                                        product.id, payload);
                                    final updated = Product(
                                      id: product.id,
                                      name: (res['nom'] ?? nameCtrl.text)
                                          as String,
                                      description: (res['description'] ??
                                          descCtrl.text) as String,
                                      price: double.tryParse(
                                              (res['prix'] ?? product.price)
                                                  .toString()) ??
                                          product.price,
                                      imageUrl: _resolveImageUrl(
                                        (res['photo'] ?? product.imageUrl)
                                            as String,
                                      ),
                                      isAvailable: ((res['actif'] ??
                                                      (isAvailable ? 1 : 0))
                                                  as dynamic) ==
                                              1 ||
                                          (res['Disponible'] ??
                                                  (isAvailable
                                                      ? 'OUI'
                                                      : 'NON')) ==
                                              'OUI',
                                      preparationTime: product.preparationTime,
                                      categoryId: product.categoryId,
                                    );
                                    setState(() {
                                      if (catKey.isNotEmpty) {
                                        final idx = _productsByCategory[catKey]!
                                            .indexWhere(
                                                (p) => p.id == product.id);
                                        if (idx >= 0)
                                          _productsByCategory[catKey]![idx] =
                                              updated;
                                      }
                                    });
                                    Navigator.pop(ctx);
                                  } catch (e) {
                                    showDialog(
                                        context: ctx,
                                        builder: (d) => AlertDialog(
                                                title: const Text('Erreur'),
                                                content: Text(e.toString()),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(d),
                                                      child:
                                                          const Text('Fermer'))
                                                ]));
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD43B3B)),
                                child: const Text('Enregistrer'))),
                      ])
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _loading = false);
  }

  Future<void> _loadProductsFromApi() async {
    setState(() => _loading = true);
    try {
      final list = await _api.fetchProducts();
      // group by categorie_nom or 'Autre'
      final Map<String, List<Product>> grouped = {};
      final Map<String, String?> categoryPhoto = {};
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final cat = (map['categorie_nom'] ?? 'Autre') as String;
        final catPhoto = map['categorie_photo'] as String?;
        final p = Product(
          id: map['id'] is int
              ? map['id'] as int
              : int.parse(map['id'].toString()),
          name: (map['nom'] ?? '') as String,
          description: (map['description'] ?? '') as String,
          price: double.tryParse((map['prix'] ?? '0').toString()) ?? 0.0,
          imageUrl: _resolveImageUrl((map['photo'] ?? '') as String),
          isAvailable: ((map['actif'] ?? 1) as dynamic) == 1 ||
              (map['Disponible'] ?? 'OUI') == 'OUI',
          preparationTime: 20,
          categoryId: map['categorie_id'] is int
              ? map['categorie_id'] as int
              : int.tryParse('${map['categorie_id']}'),
        );
        grouped.putIfAbsent(cat, () => []).add(p);
        if (catPhoto != null && !categoryPhoto.containsKey(cat)) {
          categoryPhoto[cat] = _resolveImageUrl(catPhoto);
        }
      }
      setState(() {
        // replace productsByCategory entries
        for (final e in grouped.entries) {
          _productsByCategory[e.key] = e.value;
        }
        // build categories list from grouped keys
        _categories.clear();
        for (final cat in grouped.keys) {
          final sample = grouped[cat]!.first;
          _categories.add(Category(
            id: sample.categoryId ?? sample.id,
            name: cat,
            description: '',
            imageUrl: categoryPhoto[cat] ?? sample.imageUrl,
            color: _getRandomColor(),
          ));
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement produits: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? imagePath;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setStateDialog) {
            return Dialog(
              backgroundColor: const Color(0xFF1B1D20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Nouvelle Catégorie',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon:
                                const Icon(Icons.close, color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Nom de la catégorie
                      TextField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Nom de la catégorie',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(Icons.category_outlined,
                              color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white30),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white30),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFD43B3B), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextField(
                        controller: descCtrl,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Description',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(Icons.description_outlined,
                              color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white30),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white30),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFD43B3B), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final path = await _pickImagePath();
                                setStateDialog(() => imagePath = path);
                              },
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Choisir une image'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: Colors.white30),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (imagePath != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(imagePath!),
                            width: double.infinity,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Boutons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: Colors.white30),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Annuler'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (nameCtrl.text.isEmpty || imagePath == null) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Veuillez remplir tous les champs'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  final payload = {
                                    'nom': nameCtrl.text,
                                    'photo_file_path': imagePath!,
                                  };
                                  final res =
                                      await _api.createCategory(payload);
                                  final newCategory = Category(
                                    id: res['id'] is int
                                        ? res['id'] as int
                                        : int.parse(res['id'].toString()),
                                    name: res['nom'] ?? nameCtrl.text,
                                    description: descCtrl.text,
                                    imageUrl: res['photo'] ?? '',
                                    color: _getRandomColor(),
                                  );

                                  setState(() {
                                    _categories.add(newCategory);
                                    _productsByCategory[newCategory.name] = [];
                                  });

                                  Navigator.pop(ctx);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Catégorie créée avec succès'),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } catch (e) {
                                  showDialog(
                                      context: ctx,
                                      builder: (d) => AlertDialog(
                                              title: const Text(
                                                  'Erreur création catégorie'),
                                              content: Text(e.toString()),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(d),
                                                    child: const Text('Fermer'))
                                              ]));
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD43B3B),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                              ),
                              child: const Text('Créer'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getRandomColor() {
    final colors = [
      Colors.orangeAccent.withOpacity(0.8),
      Colors.redAccent.withOpacity(0.8),
      Colors.blueAccent.withOpacity(0.8),
      Colors.pinkAccent.withOpacity(0.8),
      Colors.purpleAccent.withOpacity(0.8),
      Colors.greenAccent.withOpacity(0.8),
      Colors.amberAccent.withOpacity(0.8),
      Colors.cyanAccent.withOpacity(0.8),
    ];
    return colors[_categories.length % colors.length];
  }

  void _showAddProductDialog(String category) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String? imagePath;
    bool isAvailable = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setStateDialog) {
            return Dialog(
              backgroundColor: const Color(0xFF1B1D20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ajouter un plat ($category)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon:
                                const Icon(Icons.close, color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Nom du plat
                      TextField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Nom du plat',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(Icons.restaurant_menu_outlined,
                              color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white30),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white30),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFD43B3B), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextField(
                        controller: descCtrl,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Description',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(Icons.description_outlined,
                              color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white30),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white30),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFD43B3B), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Prix
                      TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Prix (MAD)',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(
                              Icons.currency_exchange_outlined,
                              color: Colors.white70),
                          suffixText: 'MAD',
                          suffixStyle: const TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white30),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white30),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFD43B3B), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final path = await _pickImagePath();
                                setStateDialog(() => imagePath = path);
                              },
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Choisir une image'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: Colors.white30),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (imagePath != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(imagePath!),
                            width: double.infinity,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),

                      // Disponibilité
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: Colors.white70, size: 20),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Disponible',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                            Switch(
                              value: isAvailable,
                              onChanged: (value) {
                                setStateDialog(() {
                                  isAvailable = value;
                                });
                              },
                              activeColor: const Color(0xFFD43B3B),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Boutons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: Colors.white30),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Annuler'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (nameCtrl.text.isEmpty ||
                                    priceCtrl.text.isEmpty ||
                                    imagePath == null) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Veuillez remplir tous les champs'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                  return;
                                }

                                final catObj = _categories.firstWhere(
                                    (c) => c.name == category,
                                    orElse: () => Category(
                                        id: 0,
                                        name: category,
                                        description: '',
                                        imageUrl: '',
                                        color: Colors.grey));
                                final payload = {
                                  'nom': nameCtrl.text,
                                  'description': descCtrl.text,
                                  'prix':
                                      double.tryParse(priceCtrl.text) ?? 0.0,
                                  'photo_file_path': imagePath!,
                                  'categorie_id':
                                      catObj.id == 0 ? null : catObj.id,
                                  'actif': isAvailable ? 1 : 0,
                                  'Disponible': isAvailable ? 'OUI' : 'NON',
                                };

                                try {
                                  final created =
                                      await _api.createProduct(payload);
                                  final map = created as Map<String, dynamic>;
                                  final newProduct = Product(
                                    id: map['id'] is int
                                        ? map['id'] as int
                                        : int.parse(map['id'].toString()),
                                    name: (map['nom'] ?? '') as String,
                                    description:
                                        (map['description'] ?? '') as String,
                                    price: double.tryParse(
                                            (map['prix'] ?? '0').toString()) ??
                                        0.0,
                                    imageUrl: (map['photo'] ?? '') as String,
                                    isAvailable:
                                        ((map['actif'] ?? 1) as dynamic) == 1 ||
                                            (map['Disponible'] ?? 'OUI') ==
                                                'OUI',
                                    preparationTime: 20,
                                    categoryId: catObj.id == 0 ? null : catObj.id,
                                  );

                                  setState(() {
                                    if (_productsByCategory
                                        .containsKey(category)) {
                                      _productsByCategory[category]!
                                          .add(newProduct);
                                    } else {
                                      _productsByCategory[category] = [
                                        newProduct
                                      ];
                                    }
                                  });

                                  Navigator.pop(ctx);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Plat ajouté avec succès'),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } catch (e) {
                                  showDialog(
                                    context: ctx,
                                    builder: (dCtx) => AlertDialog(
                                      title:
                                          const Text('Erreur création produit'),
                                      content: SingleChildScrollView(
                                          child: Text(e.toString())),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dCtx),
                                            child: const Text('Fermer'))
                                      ],
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD43B3B),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                              ),
                              child: const Text('Ajouter'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showProductDetails(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1B1D20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Détails du produit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Image du produit
                _imageBox(product.imageUrl, width: double.infinity, height: 200),
                const SizedBox(height: 20),

                // Nom et prix
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD43B3B),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${product.price.toStringAsFixed(2)} MAD',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Disponibilité et temps de préparation
                Row(
                  children: [
                    Icon(
                      product.isAvailable
                          ? Icons.check_circle
                          : Icons.remove_circle,
                      color:
                          product.isAvailable ? Colors.green : Colors.redAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      product.isAvailable ? 'Disponible' : 'Indisponible',
                      style: TextStyle(
                        color: product.isAvailable
                            ? Colors.green
                            : Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.timer_outlined,
                        color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${product.preparationTime} min',
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Description
                const Text(
                  'Description',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Actions: Modifier / Supprimer
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showEditProductDialog(product);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD43B3B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Modifier'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                              context: context,
                              builder: (d) => AlertDialog(
                                      title: const Text('Confirmer'),
                                      content:
                                          const Text('Supprimer ce produit ?'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(d, false),
                                            child: const Text('Annuler')),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(d, true),
                                            child: const Text('Supprimer'))
                                      ]));
                          if (ok == true) {
                            try {
                              await _api.deleteProduct(product.id);
                              setState(() {
                                // remove from productsByCategory
                                final catKey = _productsByCategory.keys
                                    .firstWhere(
                                        (k) => _productsByCategory[k]!
                                            .any((p) => p.id == product.id),
                                        orElse: () => '');
                                if (catKey.isNotEmpty)
                                  _productsByCategory[catKey]!
                                      .removeWhere((p) => p.id == product.id);
                              });
                              Navigator.pop(ctx);
                            } catch (e) {
                              showDialog(
                                  context: context,
                                  builder: (d) => AlertDialog(
                                          title: const Text('Erreur'),
                                          content: Text(e.toString()),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(d),
                                                child: const Text('Fermer'))
                                          ]));
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white30),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: const Text('Supprimer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F1113);
    const cardBg = Color(0xFF1B1D20);
    const accentColor = Color(0xFFD43B3B);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _selectedCategory == null ? 'Catalogue Produits' : _selectedCategory!,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_selectedCategory == null)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: accentColor),
              onPressed: _showAddCategoryDialog,
              tooltip: 'Ajouter une catégorie',
            )
          else
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: accentColor),
              onPressed: () => _showAddProductDialog(_selectedCategory!),
              tooltip: 'Ajouter un plat',
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: accentColor,
                strokeWidth: 2.5,
              ),
            )
          : Column(
              children: [
                // Bouton retour si une catégorie est sélectionnée
                if (_selectedCategory != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white70),
                          onPressed: () {
                            setState(() {
                              _selectedCategory = null;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Retour aux catégories',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),

                // Contenu principal
                Expanded(
                  child: _selectedCategory == null
                      ? _buildCategoriesList()
                      : _buildProductsList(),
                ),
              ],
            ),
    );
  }

  Widget _buildCategoriesList() {
    const cardBg = Color(0xFF1B1D20);
    const accentColor = Color(0xFFD43B3B);

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        final productCount = _productsByCategory[category.name]?.length ?? 0;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedCategory = category.name;
            });
          },
          onLongPress: () async {
            // options: edit / delete
            final choice = await showModalBottomSheet<String>(
              context: context,
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit),
                      title: const Text('Modifier la catégorie'),
                      onTap: () => Navigator.pop(ctx, 'edit'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete),
                      title: const Text('Supprimer la catégorie'),
                      onTap: () => Navigator.pop(ctx, 'delete'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.close),
                      title: const Text('Annuler'),
                      onTap: () => Navigator.pop(ctx, ''),
                    ),
                  ],
                ),
              ),
            );
            if (choice == 'edit') {
              _showEditCategoryDialog(category);
            } else if (choice == 'delete') {
              _confirmDeleteCategory(category);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Image de fond
                  _imageBox(
                    category.imageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    radius: BorderRadius.circular(20),
                  ),

                  // Overlay gradient
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.4),
                        ],
                      ),
                    ),
                  ),

                  // Contenu
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nom de la catégorie
                        Text(
                          category.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 4,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Description
                        Text(
                          category.description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 8),

                        // Nombre de produits
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$productCount ${productCount == 1 ? 'produit' : 'produits'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white70, size: 20),
                        onPressed: () => _showEditCategoryDialog(category),
                        tooltip: 'Modifier',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditCategoryDialog(Category category) {
    final nameCtrl = TextEditingController(text: category.name);
    final descCtrl = TextEditingController(text: category.description);
    String? imagePath;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setStateDialog) => Dialog(
          backgroundColor: const Color(0xFF1B1D20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Modifier la catégorie',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                          labelText: 'Nom',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.03))),
                  const SizedBox(height: 12),
                  TextField(
                      controller: descCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                          labelText: 'Description',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.03))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final path = await _pickImagePath();
                            setStateDialog(() => imagePath = path);
                          },
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Changer l\'image'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (imagePath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(imagePath!),
                        width: double.infinity,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    _imageBox(category.imageUrl, width: double.infinity, height: 150),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70),
                            child: const Text('Annuler'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: ElevatedButton(
                            onPressed: () async {
                              if (nameCtrl.text.isEmpty) return;
                              try {
                                final payload = {
                                  'nom': nameCtrl.text,
                                  if (imagePath != null)
                                    'photo_file_path': imagePath!,
                                };
                                final res = await _api.updateCategory(
                                    category.id, payload);
                                final updatedCat = Category(
                                    id: category.id,
                                    name: res['nom'] ?? category.name,
                                    description: descCtrl.text,
                                    imageUrl: _resolveImageUrl(
                                      res['photo'] ?? category.imageUrl,
                                    ),
                                    color: category.color);
                                setState(() {
                                  final idx = _categories
                                      .indexWhere((c) => c.id == category.id);
                                  if (idx >= 0) _categories[idx] = updatedCat;
                                  if (category.name != updatedCat.name) {
                                    final prods =
                                        _productsByCategory.remove(category.name);
                                    if (prods != null)
                                      _productsByCategory[updatedCat.name] =
                                          prods;
                                  }
                                });
                                Navigator.pop(ctx);
                              } catch (e) {
                                showDialog(
                                    context: ctx,
                                    builder: (d) => AlertDialog(
                                            title: const Text('Erreur'),
                                            content: Text(e.toString()),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(d),
                                                  child: const Text('Fermer'))
                                            ]));
                              }
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD43B3B)),
                            child: const Text('Enregistrer'))),
                  ])
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteCategory(Category category) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Confirmer'),
                content: Text('Supprimer la catégorie "${category.name}" ?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Annuler')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Supprimer'))
                ]));
    if (ok == true) {
      try {
        await _api.deleteCategory(category.id);
        setState(() {
          _categories.removeWhere((c) => c.id == category.id);
          _productsByCategory.remove(category.name);
        });
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur suppression: $e')));
      }
    }
  }

  Widget _buildProductsList() {
    final products = _productsByCategory[_selectedCategory] ?? [];
    const cardBg = Color(0xFF1B1D20);
    const accentColor = Color(0xFFD43B3B);

    return products.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.fastfood_outlined,
                  size: 80,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Aucun plat dans cette catégorie',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ajoutez le premier plat à "$_selectedCategory"',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _showAddProductDialog(_selectedCategory!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                  ),
                  child: const Text('Ajouter un plat'),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildProductCard(product);
            },
          );
  }

  Widget _buildProductCard(Product product) {
    const cardBg = Color(0xFF1B1D20);
    const accentColor = Color(0xFFD43B3B);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image du produit
          _imageBox(
            product.imageUrl,
            width: 120,
            height: 120,
            radius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
          ),

          // Infos du produit
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: product.isAvailable
                              ? Colors.green.withOpacity(0.15)
                              : Colors.redAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          product.isAvailable ? '✓' : '✗',
                          style: TextStyle(
                            color: product.isAvailable
                                ? Colors.green
                                : Colors.redAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${product.price.toStringAsFixed(2)} MAD',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded,
                            color: Colors.white70),
                        onPressed: () => _showProductDetails(product),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white70),
                        onPressed: () => _showEditProductDialog(product),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Modèles de données
class Category {
  final int id;
  final String name;
  final String description;
  final String imageUrl;
  final Color color;

  Category({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.color,
  });
}

class Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final bool isAvailable;
  final int preparationTime;
  final int? categoryId;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.isAvailable,
    required this.preparationTime,
    this.categoryId,
  });
}
