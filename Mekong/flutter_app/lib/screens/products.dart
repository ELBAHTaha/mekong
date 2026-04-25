import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../widgets/main_bottom_nav.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({Key? key}) : super(key: key);

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _PickedImage {
  _PickedImage(this.file, this.bytes);

  final XFile file;
  final Uint8List bytes;

  String get name => file.name;
  String get path => file.path;
  String? get mimeType => file.mimeType;
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

  Future<_PickedImage?> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      return _PickedImage(file, bytes);
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
          color: Colors.black.withOpacity(0.04),
          borderRadius: r,
        ),
        child: const Icon(Icons.image_outlined, color: Colors.black45, size: 32),
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
          color: Colors.black.withOpacity(0.04),
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: Colors.black45),
        ),
      ),
    );
  }

  void _showEditProductDialog(Product product) {
    final nameCtrl = TextEditingController(text: product.name);
    final descCtrl = TextEditingController(text: product.description);
    final priceCtrl = TextEditingController(text: product.price.toString());
    _PickedImage? image;
    bool isAvailable = product.isAvailable;
    String? typePersonnel = product.typePersonnel;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.white,
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
                                  color: Colors.black87,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700)),
                          IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close,
                                  color: Colors.black54)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                          controller: nameCtrl,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                              labelText: 'Nom',
                              labelStyle:
                                  const TextStyle(color: Colors.black54),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.04))),
                      const SizedBox(height: 12),
                      TextField(
                          controller: descCtrl,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                              labelText: 'Description',
                              labelStyle:
                                  const TextStyle(color: Colors.black54),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.04))),
                      const SizedBox(height: 12),
                      TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                              labelText: 'Prix',
                              labelStyle:
                                  const TextStyle(color: Colors.black54),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.04))),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await _pickImage();
                                setStateDialog(() => image = picked);
                              },
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Changer l\'image'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black54,
                                side: const BorderSide(color: Colors.black12),
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
                      DropdownButtonFormField<String>(
                        value: typePersonnel,
                        decoration: InputDecoration(
                          labelText: 'Type cuisinier',
                          labelStyle: const TextStyle(color: Colors.black54),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                        ),
                        dropdownColor: Colors.white,
                        items: const [
                          DropdownMenuItem(value: 'AUCUN', child: Text('Aucun')),
                          DropdownMenuItem(
                              value: 'CUISINIER_WOK',
                              child: Text('Cuisinier Wok')),
                          DropdownMenuItem(
                              value: 'CUISINIER_SJS',
                              child: Text('Cuisinier SJS')),
                        ],
                        onChanged: (v) => setStateDialog(() => typePersonnel = v),
                      ),
                      const SizedBox(height: 12),
                      if (image != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? Image.memory(
                                  image!.bytes,
                                  width: double.infinity,
                                  height: 150,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(image!.path),
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
                            style: TextStyle(color: Colors.black54)),
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
                                    foregroundColor: Colors.black54),
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
                                      'type_personnel': typePersonnel,
                                      if (image != null) ...{
                                        'photo_file_bytes': image!.bytes,
                                        'photo_file_name': image!.name,
                                        if (image!.mimeType != null)
                                          'photo_mime_type': image!.mimeType,
                                      },
                                      'categorie_id':
                                          catObj.id == 0 ? null : catObj.id,
                                      'actif': isAvailable ? 1 : 0,
                                      'Disponible': isAvailable ? 'OUI' : 'NON',
                                    };
                                    final res = await _api.updateProduct(
                                        product.id, payload);
                                    final rawPhoto =
                                        (res['photo'] ?? '').toString().trim();
                                    final resolvedPhoto = rawPhoto.isNotEmpty
                                        ? _resolveImageUrl(rawPhoto)
                                        : product.imageUrl;
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
                                      imageUrl: resolvedPhoto,
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
                                      typePersonnel: (res['type_personnel'] ??
                                              typePersonnel ??
                                              product.typePersonnel)
                                          ?.toString(),
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
          typePersonnel: map['type_personnel']?.toString(),
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
    _PickedImage? image;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.white,
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
                              color: Colors.black87,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon:
                                const Icon(Icons.close, color: Colors.black54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Nom de la catégorie
                      TextField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Nom de la catégorie',
                          labelStyle: const TextStyle(color: Colors.black54),
                          prefixIcon: const Icon(Icons.category_outlined,
                              color: Colors.black54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFD43B3B), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.04),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextField(
                        controller: descCtrl,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Description',
                          labelStyle: const TextStyle(color: Colors.black54),
                          prefixIcon: const Icon(Icons.description_outlined,
                              color: Colors.black54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFD43B3B), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.04),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await _pickImage();
                                setStateDialog(() => image = picked);
                              },
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Choisir une image'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black54,
                                side: const BorderSide(color: Colors.black12),
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
                      if (image != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? Image.memory(
                                  image!.bytes,
                                  width: double.infinity,
                                  height: 150,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(image!.path),
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
                                foregroundColor: Colors.black54,
                                side: const BorderSide(color: Colors.black12),
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
                                if (nameCtrl.text.isEmpty || image == null) {
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
                                    'photo_file_bytes': image!.bytes,
                                    'photo_file_name': image!.name,
                                    if (image!.mimeType != null)
                                      'photo_mime_type': image!.mimeType,
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
    _PickedImage? image;
    bool isAvailable = true;
    String typePersonnel = 'CUISINIER_WOK';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.white,
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
                              color: Colors.black87,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon:
                                const Icon(Icons.close, color: Colors.black54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Nom du plat
                      TextField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Nom du plat',
                          labelStyle: const TextStyle(color: Colors.black54),
                          prefixIcon: const Icon(Icons.restaurant_menu_outlined,
                              color: Colors.black54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFD43B3B), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.04),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextField(
                        controller: descCtrl,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Description',
                          labelStyle: const TextStyle(color: Colors.black54),
                          prefixIcon: const Icon(Icons.description_outlined,
                              color: Colors.black54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFD43B3B), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.04),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Prix
                      TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Prix (MAD)',
                          labelStyle: const TextStyle(color: Colors.black54),
                          prefixIcon: const Icon(
                              Icons.currency_exchange_outlined,
                              color: Colors.black54),
                          suffixText: 'MAD',
                          suffixStyle: const TextStyle(color: Colors.black54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFD43B3B), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.04),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await _pickImage();
                                setStateDialog(() => image = picked);
                              },
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Choisir une image'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black54,
                                side: const BorderSide(color: Colors.black12),
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
                      DropdownButtonFormField<String>(
                        value: typePersonnel,
                        decoration: InputDecoration(
                          labelText: 'Type cuisinier',
                          labelStyle: const TextStyle(color: Colors.black54),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                        ),
                        dropdownColor: Colors.white,
                        items: const [
                          DropdownMenuItem(value: 'AUCUN', child: Text('Aucun')),
                          DropdownMenuItem(
                              value: 'CUISINIER_WOK',
                              child: Text('Cuisinier Wok')),
                          DropdownMenuItem(
                              value: 'CUISINIER_SJS',
                              child: Text('Cuisinier SJS')),
                        ],
                        onChanged: (v) => setStateDialog(() {
                          typePersonnel = v ?? 'CUISINIER_WOK';
                        }),
                      ),
                      const SizedBox(height: 12),
                      if (image != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? Image.memory(
                                  image!.bytes,
                                  width: double.infinity,
                                  height: 150,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(image!.path),
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
                          color: Colors.black.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: Colors.black54, size: 20),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Disponible',
                                style: TextStyle(color: Colors.black54),
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
                                foregroundColor: Colors.black54,
                                side: const BorderSide(color: Colors.black12),
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
                                    image == null) {
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
                                  'type_personnel': typePersonnel,
                                  'photo_file_bytes': image!.bytes,
                                  'photo_file_name': image!.name,
                                  if (image!.mimeType != null)
                                    'photo_mime_type': image!.mimeType,
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
                                    typePersonnel:
                                        (map['type_personnel'] ?? typePersonnel)
                                            ?.toString(),
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
        backgroundColor: Colors.white,
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
                        color: Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.black54),
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
                      color: Colors.black87,
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
                        color: Colors.black54, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${product.preparationTime} min',
                      style: const TextStyle(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Description
                const Text(
                  'Description',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.description,
                  style: const TextStyle(
                    color: Colors.black87,
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
    const accentColor = Color(0xFFD43B3B);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black54),
          onPressed: () {
            final nav = Navigator.of(context);
            if (nav.canPop()) {
              nav.pop();
            } else {
              nav.pushReplacementNamed('/home');
            }
          },
        ),
        title: Text(
          _selectedCategory == null ? 'Catalogue Produits' : _selectedCategory!,
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: Colors.black54),
                          onPressed: () {
                            setState(() {
                              _selectedCategory = null;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Retour aux catégories',
                          style: text.bodyMedium?.copyWith(color: Colors.black54),
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
      bottomNavigationBar: const MainBottomNav(currentIndex: 1),
    );
  }

  Widget _buildCategoriesList() {
    const accentColor = Color(0xFFD43B3B);
    final text = Theme.of(context).textTheme;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        // childAspectRatio = width / height. Higher => shorter tiles.
        childAspectRatio: 1.25,
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
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Image de fond
                  _imageBox(
                    category.imageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    radius: BorderRadius.circular(16),
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
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nom de la catégorie
                        Text(
                          category.name,
                          style: text.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            shadows: const [
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
                          style: text.bodySmall?.copyWith(
                            color: Colors.white70,
                            fontSize: 11,
                            shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 8),

                        // Nombre de produits
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$productCount ${productCount == 1 ? 'produit' : 'produits'}',
                            style: text.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white70, size: 16),
                        onPressed: () => _showEditCategoryDialog(category),
                        tooltip: 'Modifier',
                        padding: const EdgeInsets.all(6),
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
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
    _PickedImage? image;

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
                            final picked = await _pickImage();
                            setStateDialog(() => image = picked);
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
                  if (image != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: kIsWeb
                          ? Image.memory(
                              image!.bytes,
                              width: double.infinity,
                              height: 150,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(image!.path),
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
                                  if (image != null) ...{
                                    'photo_file_bytes': image!.bytes,
                                    'photo_file_name': image!.name,
                                    if (image!.mimeType != null)
                                      'photo_mime_type': image!.mimeType,
                                  },
                                };
                                final res = await _api.updateCategory(
                                    category.id, payload);
                                final rawPhoto =
                                    (res['photo'] ?? '').toString().trim();
                                final resolvedPhoto = rawPhoto.isNotEmpty
                                    ? _resolveImageUrl(rawPhoto)
                                    : category.imageUrl;
                                final updatedCat = Category(
                                    id: category.id,
                                    name: res['nom'] ?? category.name,
                                    description: descCtrl.text,
                                    imageUrl: resolvedPhoto,
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
    const accentColor = Color(0xFFD43B3B);
    final text = Theme.of(context).textTheme;

    return products.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.fastfood_outlined,
                  size: 72,
                  color: Colors.black.withOpacity(0.25),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucun plat dans cette catégorie',
                  style: text.bodyLarge?.copyWith(color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ajoutez le premier plat à "$_selectedCategory"',
                  style: text.bodyMedium?.copyWith(color: Colors.black45),
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
            padding: const EdgeInsets.all(8),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildProductCard(product);
            },
          );
  }

  Widget _buildProductCard(Product product) {
    const accentColor = Color(0xFFD43B3B);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image du produit
          _imageBox(
            product.imageUrl,
            width: 44,
            height: 44,
            radius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              bottomLeft: Radius.circular(10),
            ),
          ),

          // Infos du produit
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
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
                  const SizedBox(height: 6),
                  Text(
                    product.description,
                    style: text.bodySmall?.copyWith(
                      color: Colors.black54,
                      height: 1.15,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${product.price.toStringAsFixed(2)} MAD',
                          style: text.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded,
                            color: Colors.black54, size: 18),
                        onPressed: () => _showProductDetails(product),
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit,
                            color: Colors.black54, size: 18),
                        onPressed: () => _showEditProductDialog(product),
                        visualDensity: VisualDensity.compact,
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
  final String? typePersonnel;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.isAvailable,
    required this.preparationTime,
    this.categoryId,
    this.typePersonnel,
  });
}
