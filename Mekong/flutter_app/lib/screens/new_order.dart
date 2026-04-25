import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../widgets/main_bottom_nav.dart';

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({Key? key}) : super(key: key);

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

enum OrderKind { surPlace, livraison }

enum OrderFlowStep { type, category, product }

class OrderCategory {
  final int id;
  final String name;
  final String imageUrl;
  final int count;

  const OrderCategory({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.count,
  });
}

class OrderProduct {
  final int id;
  final String name;
  final double price;
  final String description;
  final String imageUrl;
  final String categoryName;
  final int? categoryId;

  const OrderProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.imageUrl,
    required this.categoryName,
    required this.categoryId,
  });
}

class CartItem {
  final OrderProduct product;
  final int quantity;

  const CartItem({required this.product, required this.quantity});

  double get total => product.price * quantity;

  CartItem copyWith({OrderProduct? product, int? quantity}) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}

class _CatalogueData {
  final List<OrderCategory> categories;
  final List<OrderProduct> products;

  const _CatalogueData({
    required this.categories,
    required this.products,
  });
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  static const Color _bg = Color(0xFFF6F7F9);
  static const Color _card = Colors.white;
  static const Color _cardAlt = Color(0xFFF1F3F5);
  static const Color _accent = Color(0xFFD43B3B);
  static const Color _accentAlt = Color(0xFFE7813A);
  static const Color _textPrimary = Color(0xFF1F2937);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);

  final ApiService _api = ApiService();

  User? _me;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  OrderKind? _selectedType;
  String? _selectedCategory;
  OrderFlowStep _step = OrderFlowStep.type;

  final List<OrderCategory> _categories = [];
  final List<OrderProduct> _products = [];
  final Map<int, CartItem> _cart = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _api.fetchProducts(),
        _api.fetchUser('basic'),
      ]);
      final rawProducts = results[0] as List<dynamic>;
      final me = results[1] as User;
      final parsed = _parseCatalogue(rawProducts);
      if (!mounted) return;
      setState(() {
        _me = me;
        _products
          ..clear()
          ..addAll(parsed.products);
        _categories
          ..clear()
          ..addAll(parsed.categories);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  _CatalogueData _parseCatalogue(List<dynamic> raw) {
    final Map<String, List<OrderProduct>> grouped = {};
    final Map<String, String?> categoryPhotos = {};

    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      final isAvailable = ((item['actif'] ?? 1) as dynamic) == 1 ||
          (item['Disponible'] ?? 'OUI').toString().toUpperCase() == 'OUI';
      if (!isAvailable) continue;

      final category = (item['categorie_nom'] ?? 'Autre').toString();
      final categoryId = item['categorie_id'] is int
          ? item['categorie_id'] as int
          : int.tryParse('${item['categorie_id']}');
      final product = OrderProduct(
        id: item['id'] is int
            ? item['id'] as int
            : int.parse(item['id'].toString()),
        name: (item['nom'] ?? '').toString(),
        price: double.tryParse((item['prix'] ?? '0').toString()) ?? 0,
        description: (item['description'] ?? '').toString(),
        imageUrl: _cleanImageUrl(item['photo']?.toString()),
        categoryName: category,
        categoryId: categoryId,
      );

      grouped.putIfAbsent(category, () => []).add(product);
      final categoryPhoto = _cleanImageUrl(item['categorie_photo']?.toString());
      if (categoryPhoto.isNotEmpty && !categoryPhotos.containsKey(category)) {
        categoryPhotos[category] = categoryPhoto;
      }
    }

    final categories = grouped.entries.map((entry) {
      final sample = entry.value.first;
      return OrderCategory(
        id: sample.categoryId ?? sample.id,
        name: entry.key,
        imageUrl: categoryPhotos[entry.key] ?? sample.imageUrl,
        count: entry.value.length,
      );
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final products = grouped.values.expand((list) => list).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return _CatalogueData(categories: categories, products: products);
  }

  String _resolveImageUrl(String? raw) {
    if (raw == null) return '';
    final value = raw.trim();
    if (value.isEmpty) return '';
    final base = Uri.parse(_api.baseUrl);
    final origin =
        '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';

    String normalizePath(String path) {
      final trimmed = path.startsWith('/') ? path.substring(1) : path;
      if (trimmed.startsWith('uploads/')) return '/storage/$trimmed';
      if (trimmed.startsWith('storage/')) return '/$trimmed';
      return path.startsWith('/') ? path : '/$path';
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      try {
        final uri = Uri.parse(value);
        final host = uri.host.toLowerCase();
        final normalizedPath = normalizePath(uri.path.isEmpty ? '/' : uri.path);
        if (host == 'localhost' || host == '127.0.0.1') {
          return '$origin$normalizedPath${uri.hasQuery ? '?${uri.query}' : ''}';
        }
        if (normalizedPath != uri.path) {
          return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}$normalizedPath'
              '${uri.hasQuery ? '?${uri.query}' : ''}';
        }
      } catch (_) {}
      return value;
    }

    return '$origin${normalizePath(value)}';
  }

  String _cleanImageUrl(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return '';
    final lower = value.toLowerCase();
    if (lower == 'null' || lower == 'undefined' || lower == '0') return '';
    return _resolveImageUrl(value);
  }

  List<OrderProduct> get _visibleProducts {
    if (_selectedCategory == null) return const [];
    return _products.where((p) => p.categoryName == _selectedCategory).toList();
  }

  int get _itemCount =>
      _cart.values.fold<int>(0, (sum, item) => sum + item.quantity);

  double get _total =>
      _cart.values.fold<double>(0, (sum, item) => sum + item.total);

  void _selectType(OrderKind kind) {
    setState(() {
      _selectedType = kind;
      _selectedCategory = null;
      _step = OrderFlowStep.category;
    });
  }

  void _openCategory(OrderCategory category) {
    setState(() {
      _selectedCategory = category.name;
      _step = OrderFlowStep.product;
    });
  }

  void _goBackStep() {
    setState(() {
      if (_step == OrderFlowStep.product) {
        _selectedCategory = null;
        _step = OrderFlowStep.category;
      } else if (_step == OrderFlowStep.category) {
        _selectedType = null;
        _selectedCategory = null;
        _step = OrderFlowStep.type;
      }
    });
  }

  void _addProduct(OrderProduct product) {
    setState(() {
      final existing = _cart[product.id];
      if (existing == null) {
        _cart[product.id] = CartItem(product: product, quantity: 1);
      } else {
        _cart[product.id] = existing.copyWith(quantity: existing.quantity + 1);
      }
    });
  }

  void _increment(CartItem item) => _addProduct(item.product);

  void _decrement(CartItem item) {
    setState(() {
      final existing = _cart[item.product.id];
      if (existing == null) return;
      if (existing.quantity <= 1) {
        _cart.remove(item.product.id);
      } else {
        _cart[item.product.id] =
            existing.copyWith(quantity: existing.quantity - 1);
      }
    });
  }

  Future<void> _validateOrder() async {
    if (_selectedType == null) {
      _showMessage('Choisissez d\'abord un type de commande.', isError: true);
      return;
    }
    if (_cart.isEmpty) {
      _showMessage('Ajoutez au moins un produit au panier.', isError: true);
      return;
    }

    final items = _cart.values
        .map((item) => {
              'produit_id': item.product.id,
              'nom': item.product.name,
              'quantite': item.quantity,
              'prix_unitaire': item.product.price,
              'total': item.total,
            })
        .toList();

    final payload = <String, dynamic>{
      'type': _selectedType == OrderKind.livraison ? 'LIVRAISON' : 'SUR_PLACE',
      'statut': 'NOUVELLE',
      'total': _total,
      'date_commande': DateTime.now().toIso8601String(),
      'items': items,
      'caissier_id': _me?.id,
      'notes': _selectedType == OrderKind.livraison
          ? 'Commande créée depuis l\'écran Commande (livraison)'
          : 'Commande créée depuis l\'écran Commande',
    };

    setState(() => _saving = true);
    try {
      await _api.createCommande(payload);
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _selectedCategory = null;
        _selectedType = null;
        _step = OrderFlowStep.type;
        _saving = false;
      });
      _showMessage('Commande enregistrée avec succès.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Erreur lors de l\'enregistrement: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Put the cart on the right on web/desktop as soon as we have enough width.
    // The old 1100px breakpoint kept the cart at the bottom for many laptop widths.
    final wide = MediaQuery.of(context).size.width >= 900;
    final showCart = _step != OrderFlowStep.type;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Commande',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _textSecondary),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _accent))
            : _loadError != null
                ? _buildLoadError()
                : wide && showCart
                    ? Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              child: _buildMainContent(),
                            ),
                          ),
                          SizedBox(
                            width: 340,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 8, 16, 16),
                              child: _buildCartPanel(compact: false),
                            ),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMainContent(),
                            if (showCart) ...[
                              const SizedBox(height: 16),
                              _buildCartPanel(compact: true),
                            ],
                          ],
                        ),
                      ),
      ),
      bottomNavigationBar: const MainBottomNav(currentIndex: 2),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 42),
            const SizedBox(height: 12),
            const Text(
              'Impossible de charger le catalogue',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _loadError ?? '',
              style: const TextStyle(color: _textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _bootstrap,
              icon: const Icon(Icons.refresh_rounded),
              style: ElevatedButton.styleFrom(backgroundColor: _accent),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderCard(),
        const SizedBox(height: 12),
        _buildStepNavigator(),
        const SizedBox(height: 12),
        if (_step == OrderFlowStep.type) _buildTypeSection(),
        if (_step == OrderFlowStep.category) _buildCategorySection(),
        if (_step == OrderFlowStep.product) _buildProductsSection(),
      ],
    );
  }

  Widget _buildStepNavigator() {
    final stepTitle = _step == OrderFlowStep.type
        ? 'Étape 1 sur 3'
        : _step == OrderFlowStep.category
            ? 'Étape 2 sur 3'
            : 'Étape 3 sur 3';

    final path = <String>[
      'Type',
      if (_selectedType != null) 'Catégories',
      if (_selectedCategory != null) _selectedCategory!,
    ].join('  •  ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          if (_step != OrderFlowStep.type)
            IconButton(
              onPressed: _goBackStep,
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _textSecondary, size: 18),
            ),
          if (_step != OrderFlowStep.type) const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stepTitle,
                  style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  path,
                  style: const TextStyle(color: _textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    final typeLabel = _selectedType == null
        ? 'Aucun type sélectionné'
        : _selectedType == OrderKind.livraison
            ? 'Livraison'
            : 'Sur place / À emporter';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: _accent),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Nouvelle commande',
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Type: $typeLabel',
                style: const TextStyle(color: _textSecondary, fontSize: 12),
              ),
            ],
          ),
          if (_me != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _cardAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Utilisateur: ${_me!.name}',
                style: const TextStyle(color: _textSecondary, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choisir le type de commande',
          style: TextStyle(
              color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 760;
            final first = Expanded(
              child: _buildTypeCard(
                title: 'Sur place / À emporter',
                subtitle: 'Parcours standard pour une commande sur caisse',
                icon: Icons.storefront_rounded,
                selected: _selectedType == OrderKind.surPlace,
                onTap: () => _selectType(OrderKind.surPlace),
              ),
            );
            final second = Expanded(
              child: _buildTypeCard(
                title: 'Livraison',
                subtitle: 'Créer une commande de livraison',
                icon: Icons.local_shipping_rounded,
                selected: _selectedType == OrderKind.livraison,
                onTap: () => _selectType(OrderKind.livraison),
              ),
            );

            if (stacked) {
              return Column(
                children: [
                  Row(children: [first]),
                  const SizedBox(height: 12),
                  Row(children: [second]),
                ],
              );
            }

            return Row(
              children: [
                first,
                const SizedBox(width: 12),
                second,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTypeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF1F1) : _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _accent : _border,
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (selected ? _accent : _accentAlt).withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: selected ? _accent : _accentAlt),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        color: _textPrimary, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: _accent),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choisir une catégorie',
          style: TextStyle(
              color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (_categories.isEmpty)
          _buildEmptyCard('Aucune catégorie disponible')
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 128,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _categories.length,
            itemBuilder: (context, index) =>
                _buildCategoryCard(_categories[index]),
          ),
      ],
    );
  }

  Widget _buildCategoryCard(OrderCategory category) {
    return InkWell(
      onTap: () => _openCategory(category),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _border,
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: category.imageUrl.isEmpty
                    ? Container(
                        color: _cardAlt,
                        child: const Center(
                          child: Icon(Icons.category_outlined,
                              color: _textSecondary, size: 32),
                        ),
                      )
                    : Image.network(
                        category.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: _cardAlt,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: _textSecondary, size: 32),
                          ),
                        ),
                      ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${category.count}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsSection() {
    final products = _visibleProducts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _selectedCategory ?? 'Produits',
                style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _cardAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _selectedCategory ?? '',
                style: const TextStyle(color: _textSecondary, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (products.isEmpty)
          _buildEmptyCard('Aucun produit dans cette catégorie')
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width >= 1400 ? 3 : 2,
              mainAxisExtent: 208,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) => _buildProductCard(products[index]),
          ),
      ],
    );
  }

  Widget _buildProductCard(OrderProduct product) {
    final quantity = _cart[product.id]?.quantity ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                child: product.imageUrl.isEmpty
                    ? Container(
                        height: 78,
                        color: _cardAlt,
                        child: const Center(
                          child: Icon(Icons.fastfood_outlined,
                              color: _textSecondary, size: 28),
                        ),
                      )
                    : Image.network(
                        product.imageUrl,
                        height: 78,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 78,
                          color: _cardAlt,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: _textSecondary, size: 28),
                          ),
                        ),
                      ),
              ),
              if (quantity > 0)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: _accent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$quantity',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _textPrimary, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.description.isEmpty
                        ? 'Produit du catalogue'
                        : product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _textSecondary, fontSize: 11),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${product.price.toStringAsFixed(2)} MAD',
                        style: const TextStyle(
                            color: _textPrimary, fontWeight: FontWeight.w700),
                      ),
                      ElevatedButton(
                        onPressed: () => _addProduct(product),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          minimumSize: const Size(0, 34),
                        ),
                        child: const Text('Ajouter'),
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

  Widget _buildCartPanel({required bool compact}) {
    final cartItems = _cart.values.toList()
      ..sort((a, b) =>
          a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase()));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Panier',
                  style: TextStyle(
                      color: _textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '$_itemCount article${_itemCount > 1 ? 's' : ''}',
                  style: const TextStyle(
                      color: _accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _selectedType == null
                ? 'Choisissez un type pour commencer'
                : _selectedType == OrderKind.livraison
                    ? 'Commande livraison'
                    : 'Commande sur place / à emporter',
            style: const TextStyle(color: _textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 12),
          if (compact)
            SizedBox(
              height: 180,
              child: cartItems.isEmpty
                  ? _buildCartEmpty()
                  : ListView(children: cartItems.map(_buildCartRow).toList()),
            )
          else
            Expanded(
              child: cartItems.isEmpty
                  ? _buildCartEmpty()
                  : ListView(children: cartItems.map(_buildCartRow).toList()),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _cardAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(color: _textSecondary)),
                Text(
                  '${_total.toStringAsFixed(2)} MAD',
                  style: const TextStyle(
                      color: _textPrimary, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _validateOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                disabledBackgroundColor: _accent.withOpacity(0.45),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
              label:
                  Text(_saving ? 'Enregistrement...' : 'Valider la commande'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.remove_shopping_cart_outlined,
              color: _textSecondary.withOpacity(0.6), size: 36),
          const SizedBox(height: 10),
          const Text(
            'Aucun article sélectionné',
            style: TextStyle(color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCartRow(CartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _cardAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _textPrimary, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.product.price.toStringAsFixed(2)} MAD',
                  style: const TextStyle(color: _textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              IconButton(
                onPressed: () => _decrement(item),
                icon: const Icon(Icons.remove_circle_outline,
                    color: _textSecondary),
              ),
              Text(
                '${item.quantity}',
                style: const TextStyle(
                    color: _textPrimary, fontWeight: FontWeight.w700),
              ),
              IconButton(
                onPressed: () => _increment(item),
                icon:
                    const Icon(Icons.add_circle_outline, color: _textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Text(
        message,
        style: const TextStyle(color: _textSecondary),
      ),
    );
  }
}
