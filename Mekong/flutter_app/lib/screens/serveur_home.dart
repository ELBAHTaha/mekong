import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'tables.dart';

class ServeurHomeScreen extends StatefulWidget {
  const ServeurHomeScreen({Key? key}) : super(key: key);

  @override
  State<ServeurHomeScreen> createState() => _ServeurHomeScreenState();
}

class _ServeurHomeScreenState extends State<ServeurHomeScreen> {
  final ApiService _api = ApiService();

  User? _me;
  int _unreadCount = 0;
  bool _loading = true;
  bool _showTables = true;

  List<RestaurantTable> _tables = [];
  List<MenuCategory> _categories = [];
  List<MenuProduct> _products = [];
  String? _activeCategory;

  final Map<int, OrderItem> _order = {};
  final TextEditingController _noteCtrl = TextEditingController();
  bool _loadingTableOrder = false;
  int _fallbackProductId = -1;

  RestaurantTable? _selectedTable;

  Timer? _unreadTimer;
  Timer? _tablesTimer;
  static const Duration _tablesRefreshInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _bootstrap();
    // Keep table states in sync across devices by polling the backend.
    _tablesTimer = Timer.periodic(_tablesRefreshInterval, (_) {
      _loadTables();
    });
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _unreadTimer?.cancel();
    _tablesTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadMe(),
      _loadTables(),
      _loadProducts(),
      _loadUnread(),
    ]);
    _unreadTimer?.cancel();
    _unreadTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadUnread());
    setState(() => _loading = false);
  }

  Future<void> _loadMe() async {
    try {
      final me = await _api.fetchUser('basic');
      if (!mounted) return;
      setState(() => _me = me);
    } catch (_) {}
  }

  Future<void> _loadUnread() async {
    try {
      final count = await _api.fetchUnreadNotificationsCount();
      if (!mounted) return;
      setState(() => _unreadCount = count);
    } catch (_) {}
  }

  Future<void> _loadTables() async {
    try {
      final raw = await _api.fetchTables();
      final list = raw
          .map((e) => RestaurantTable.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() => _tables = list);
    } catch (_) {}
  }

  Future<void> _loadProducts() async {
    try {
      final raw = await _api.fetchProducts();
      final Map<String, List<MenuProduct>> grouped = {};
      final Map<String, String?> categoryImages = {};
      for (final item in raw) {
        final map = item as Map<String, dynamic>;
        final cat = (map['categorie_nom'] ?? 'Autre').toString();
        final catPhoto = map['categorie_photo']?.toString();
        final product = MenuProduct(
          id: map['id'] is int ? map['id'] as int : int.parse(map['id'].toString()),
          name: (map['nom'] ?? '').toString(),
          price: double.tryParse((map['prix'] ?? '0').toString()) ?? 0,
          imageUrl: _cleanImageUrl(map['photo']?.toString()),
          category: cat,
        );
        grouped.putIfAbsent(cat, () => []).add(product);
        final catPhotoUrl = _cleanImageUrl(catPhoto);
        if (catPhotoUrl.isNotEmpty && !categoryImages.containsKey(cat)) {
          categoryImages[cat] = catPhotoUrl;
        }
      }

      final categories = grouped.entries
          .map((e) {
            final fallback = e.value.isNotEmpty ? e.value.first.imageUrl : '';
            final url = categoryImages[e.key] ?? fallback;
            return MenuCategory(
              name: e.key,
              count: e.value.length,
              imageUrl: url,
            );
          })
          .toList();

      if (!mounted) return;
      setState(() {
        _products = grouped.values.expand((e) => e).toList();
        _categories = categories;
        if (_activeCategory != null &&
            !_categories.any((c) => c.name == _activeCategory)) {
          _activeCategory = null;
        }
      });
    } catch (_) {}
  }

  String _resolveImageUrl(String? raw) {
    if (raw == null) return '';
    final value = raw.trim();
    if (value.isEmpty) return '';
    final base = Uri.parse(_api.baseUrl);
    final origin = '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
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
    final v = raw?.trim() ?? '';
    if (v.isEmpty) return '';
    final lower = v.toLowerCase();
    if (lower == 'null' || lower == '0' || lower == 'undefined') return '';
    return _resolveImageUrl(v);
  }

  void _toggleTable(RestaurantTable table) {
    setState(() {
      final already = _selectedTable?.id == table.id;
      _selectedTable = already ? null : table;
      if (already) {
        _activeCategory = null;
        _showTables = true;
        _order.clear();
        _noteCtrl.clear();
      } else {
        _showTables = false;
        _activeCategory = null;
      }
    });
    if (!(_selectedTable?.id == null) && _selectedTable!.id == table.id) {
      _loadActiveCommandeForTable(table);
    }
  }

  void _addProduct(MenuProduct product) {
    // Detect if this add happens on an existing (already loaded) table order.
    final isFullTable = _selectedTable != null && _order.isNotEmpty;
    setState(() {
      final existing = _order[product.id];
      if (existing != null) {
        _order[product.id] = existing.copyWith(quantity: existing.quantity + 1);
      } else {
        _order[product.id] = OrderItem(product: product, quantity: 1);
      }
    });

    // If we are adding to a table that already has items, send an "added" ticket to kitchen.
    if (isFullTable) {
      _notifyKitchenAdd(product, 1);
    }
  }

  void _incItem(MenuProduct product) => _addProduct(product);

  void _decItem(MenuProduct product) {
    final existed = _order[product.id];
    final hadQty = existed?.quantity ?? 0;
    setState(() {
      final existing = _order[product.id];
      if (existing == null) return;
      if (existing.quantity <= 1) {
        _order.remove(product.id);
      } else {
        _order[product.id] = existing.copyWith(quantity: existing.quantity - 1);
      }
    });

    // Send a cancellation ticket to kitchen when a server removes an item.
    // Only when there was actually something to remove.
    if (hadQty > 0) {
      _notifyKitchenCancel(product, 1);
    }
  }

  Future<void> _notifyKitchenCancel(MenuProduct product, int qtyCancelled) async {
    final table = _selectedTable;
    if (table == null) return;
    try {
      await _api.notifyKitchenItemCancelled({
        'event': 'order_item_cancelled',
        'table_id': int.tryParse(table.id),
        'table_numero': table.number,
        'serveur_id': _me?.id,
        'serveur_nom': _me?.name,
        'produit_id': product.id,
        'produit_nom': product.name,
        'quantite': qtyCancelled,
        'prix_unitaire': product.price,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Keep UI responsive even if kitchen notify fails.
    }
  }

  Future<void> _notifyKitchenAdd(MenuProduct product, int qtyAdded) async {
    final table = _selectedTable;
    if (table == null) return;
    try {
      await _api.notifyKitchenItemAdded({
        'event': 'order_item_added',
        'table_id': int.tryParse(table.id),
        'table_numero': table.number,
        'serveur_id': _me?.id,
        'serveur_nom': _me?.name,
        'produit_id': product.id,
        'produit_nom': product.name,
        'quantite': qtyAdded,
        'prix_unitaire': product.price,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  double get _total {
    double sum = 0;
    for (final it in _order.values) {
      sum += it.quantity * it.product.price;
    }
    return sum;
  }

  Future<void> _loadActiveCommandeForTable(RestaurantTable table) async {
    setState(() => _loadingTableOrder = true);
    try {
      final List<dynamic> list = await _api.fetchCommandes(
        type: 'SUR_PLACE',
        includeServeur: true,
      );
      final allowed = {'NOUVELLE', 'PREPARATION', 'PRETE'};
      final matches = list.where((c) {
        final statut = (c['statut'] ?? '').toString().toUpperCase();
        if (!allowed.contains(statut)) return false;
        final tableId = c['table_id'];
        final tableNum = c['table_numero'];
        final sameId = tableId != null && tableId.toString() == table.id;
        final sameNum = tableNum != null && tableNum.toString() == table.number.toString();
        return sameId || sameNum;
      }).toList();

      if (matches.isEmpty) {
        if (!mounted) return;
        setState(() {
          _order.clear();
          _noteCtrl.clear();
        });
        return;
      }

      matches.sort((a, b) {
        final ad = a['date_commande']?.toString() ?? '';
        final bd = b['date_commande']?.toString() ?? '';
        if (ad.isNotEmpty && bd.isNotEmpty) {
          return bd.compareTo(ad);
        }
        final aid = int.tryParse('${a['id']}') ?? 0;
        final bid = int.tryParse('${b['id']}') ?? 0;
        return bid.compareTo(aid);
      });

      final cmd = matches.first;
      final items = (cmd['produits'] as List?) ??
          (cmd['items'] as List?) ??
          const [];
      final Map<int, OrderItem> restored = {};
      for (final it in items) {
        if (it is! Map) continue;
        final pid = it['produit_id'] ?? it['id'];
        final qty = int.tryParse('${it['quantite'] ?? 1}') ?? 1;
        final price = double.tryParse('${it['prix_unitaire'] ?? 0}') ?? 0;
        final name = (it['nom'] ?? '').toString();

        MenuProduct? product;
        if (pid != null) {
          final pidInt = int.tryParse(pid.toString());
          if (pidInt != null) {
            product = _products.firstWhere(
              (p) => p.id == pidInt,
              orElse: () => MenuProduct(
                id: pidInt,
                name: name.isEmpty ? 'Produit' : name,
                price: price,
                imageUrl: '',
                category: '',
              ),
            );
          }
        }
        product ??= _products.firstWhere(
          (p) => p.name == name,
          orElse: () => MenuProduct(
            id: _fallbackProductId--,
            name: name.isEmpty ? 'Produit' : name,
            price: price,
            imageUrl: '',
            category: '',
          ),
        );

        restored[product.id] = OrderItem(product: product, quantity: qty);
      }

      if (!mounted) return;
      setState(() {
        _order
          ..clear()
          ..addAll(restored);
        _noteCtrl.text = (cmd['notes'] ?? '').toString();
      });
    } catch (_) {
      // ignore for now
    } finally {
      if (mounted) setState(() => _loadingTableOrder = false);
    }
  }

  Future<void> _saveCommande() async {
    if (_order.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un produit.')),
      );
      return;
    }
    if (_selectedTable == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez une table.')),
      );
      return;
    }

    final items = _order.values.map((it) {
      return {
        'produit_id': it.product.id,
        'nom': it.product.name,
        'quantite': it.quantity,
        'prix_unitaire': it.product.price,
        'total': it.quantity * it.product.price,
      };
    }).toList();

    final tableToOccupy = _selectedTable;

    final payload = <String, dynamic>{
      'type': 'SUR_PLACE',
      'statut': 'NOUVELLE',
      'total': _total,
      'table_id': tableToOccupy == null
          ? null
          : int.tryParse(tableToOccupy.id),
      'notes': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      'items': items,
      'date_commande': DateTime.now().toIso8601String(),
      'caissier_id': _me?.id,
    };

    try {
      await _api.createCommande(payload);
      if (!mounted) return;
      setState(() {
        _order.clear();
        _noteCtrl.clear();
        if (tableToOccupy != null) {
          final idx = _tables.indexWhere((t) => t.id == tableToOccupy.id);
          if (idx != -1) {
            _tables[idx] = _tables[idx].copyWith(state: TableState.OCCUPEE);
          }
        }
        _activeCategory = null;
        _showTables = true;
        _selectedTable = null;
      });
      if (tableToOccupy != null) {
        final tableId = int.tryParse(tableToOccupy.id) ?? 0;
        if (tableId > 0) {
          await _api.updateTable(tableId, {'etat': 'OCCUPEE'});
        }
      }
      await _loadTables();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Commande enregistrée'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF6F7F9);
    const card = Colors.white;
    const accent = Color(0xFFD43B3B);

    final name = _me?.name ?? 'Serveur';
    final now = DateTime.now();
    final dateText = '${now.day} ${_month(now.month)} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: accent))
            : Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopBar(name, dateText),
                          const SizedBox(height: 12),
                          _buildLegend(),
                          const SizedBox(height: 14),
                          if (_showTables || _selectedTable == null) ...[
                            _buildTablePlan(),
                            const SizedBox(height: 12),
                            const Text(
                              'Sélectionnez une table pour continuer',
                              style: TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 20),
                          ] else ...[
                            _buildCategoryOrProducts(),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: _buildOrderPanel(card, accent, compact: false),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTopBar(String name, String dateText) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final avatar = Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.06),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('T', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
          ),
        );
        final nameBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bonjour,', style: TextStyle(color: Colors.black54, fontSize: 13)),
            Text(name, style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            _buildTableBadge(),
          ],
        );
        final bell = Stack(
          children: [
            IconButton(
              onPressed: () => _loadUnread(),
              icon: const Icon(Icons.notifications_none_rounded, color: Colors.black54),
            ),
            if (_unreadCount > 0)
              Positioned(
                right: 8,
                top: 6,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD43B3B),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _unreadCount > 9 ? '9+' : _unreadCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ],
        );

        if (!compact) {
          return Row(
            children: [
              avatar,
              const SizedBox(width: 12),
              nameBlock,
              const Spacer(),
              Text(dateText, style: const TextStyle(color: Colors.black54)),
              const SizedBox(width: 16),
              bell,
            ],
          );
        }

        final shortDate = dateText.split(' ').take(2).join(' ');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                avatar,
                const SizedBox(width: 12),
                Expanded(child: nameBlock),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(shortDate, style: const TextStyle(color: Colors.black54)),
                bell,
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        _legendDot(Colors.green, 'Libre'),
        _legendDot(Colors.redAccent, 'Plein'),
        _legendDot(Colors.orange, 'Réservée'),
      ],
    );
  }

  Widget _buildTableBadge() {
    final label = _selectedTable == null ? 'Table: —' : 'Table: T${_selectedTable!.number}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      ],
    );
  }

  Widget _buildTablePlan() {
    const panelBg = Colors.white;
    final sortedTables = [..._tables]..sort((a, b) => a.number.compareTo(b.number));
    return Container(
      height: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const minTile = 86.0;
          const gap = 12.0;
          final crossAxisCount = (constraints.maxWidth / (minTile + gap)).floor().clamp(2, 8);

          return GridView.builder(
            itemCount: sortedTables.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: gap,
              mainAxisSpacing: gap,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) => _tableChip(sortedTables[index], 1),
          );
        },
      ),
    );
  }

  Widget _tableChip(RestaurantTable table, double scale) {
    final isSelected = _selectedTable?.id == table.id;
    final color = _tableColor(table.state);
    return GestureDetector(
      onTap: () => _toggleTable(table),
      child: Container(
        width: 88 * scale,
        height: 88 * scale,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(isSelected ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? const Color(0xFFD43B3B) : color, width: isSelected ? 2 : 1.5),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'T${table.number}',
                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _stateLabel(table.state),
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    if (_categories.isEmpty) {
      return const Text('Aucune catégorie', style: TextStyle(color: Colors.black54));
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 140,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final c = _categories[index];
        final imageUrl = c.imageUrl ?? '';
        return GestureDetector(
          onTap: () => setState(() => _activeCategory = c.name),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: imageUrl.isEmpty
                      ? Container(
                          color: Colors.black.withOpacity(0.05),
                          child: const Center(
                            child: Icon(Icons.category_outlined, color: Colors.black45, size: 40),
                          ),
                        )
                      : Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.black.withOpacity(0.05),
                            child: const Center(
                              child: Icon(Icons.broken_image_outlined, color: Colors.black45, size: 40),
                            ),
                          ),
                        ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.white.withOpacity(0.92),
                          Colors.white.withOpacity(0.0),
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
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${c.count}',
                          style: const TextStyle(color: Colors.black54, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductsGrid(bool wide, String category) {
    final list = _products.where((p) => p.category == category).toList();
    if (list.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: const Text('Aucun produit', style: TextStyle(color: Colors.black54)),
      );
    }
    final columns = wide ? 3 : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: 250,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) => _productCard(list[index]),
    );
  }

  Widget _buildCategoryOrProducts() {
    // Guard: categories/products only make sense after selecting a table.
    if (_selectedTable == null) return const SizedBox.shrink();

    if (_activeCategory == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _showTables = true),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black54, size: 18),
              ),
              const Text('Catégories et produits',
                  style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
              if (_loadingTableOrder) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD43B3B)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          _buildCategories(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _activeCategory = null),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black54, size: 18),
            ),
            Text(_activeCategory!, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 10),
        _buildProductsGrid(MediaQuery.of(context).size.width >= 1400, _activeCategory!),
      ],
    );
  }

  Widget _productCard(MenuProduct product) {
    final qty = _order[product.id]?.quantity ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: product.imageUrl.isEmpty
                    ? Container(
                        height: 84,
                        color: Color(0xFFF6F7F9),
                        child: const Center(child: Icon(Icons.image_outlined, color: Colors.black45)),
                      )
                    : Image.network(
                        product.imageUrl,
                        height: 84,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 84,
                          color: Colors.black.withOpacity(0.05),
                          child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.black45)),
                        ),
                      ),
              ),
              if (qty > 0)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD43B3B),
                      shape: BoxShape.circle,
                    ),
                    child: Text('$qty', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Text('${product.price.toStringAsFixed(2)} MAD',
                    style: const TextStyle(color: Colors.black54, fontSize: 11)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 30,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 42,
                        height: 30,
                        child: OutlinedButton(
                          onPressed: qty > 0 ? () => _decItem(product) : null,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor: const Color(0xFFD43B3B),
                            side: const BorderSide(color: Color(0xFFD43B3B)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          child: const Icon(Icons.remove, size: 16),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _addProduct(product),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD43B3B),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text('+  Ajouter', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderPanel(Color cardBg, Color accent, {required bool compact}) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Commande en cours', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            _selectedTable == null ? 'Sur place - Aucune table' : 'Sur place - Table ${_selectedTable!.number}',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (compact)
            SizedBox(
              height: 160,
              child: _order.isEmpty
                  ? const Center(child: Text('Aucun article', style: TextStyle(color: Colors.black54)))
                  : ListView(children: _order.values.map(_orderRow).toList()),
            )
          else
            Expanded(
              child: _order.isEmpty
                  ? const Center(child: Text('Aucun article', style: TextStyle(color: Colors.black54)))
                  : ListView(children: _order.values.map(_orderRow).toList()),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              hintText: 'Note de la commande',
              hintStyle: const TextStyle(color: Colors.black45),
              filled: true,
              fillColor: const Color(0xFFF6F7F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(color: Colors.black54)),
              Text('${_total.toStringAsFixed(2)} MAD',
                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _saveCommande,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Enregistrer la commande'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderRow(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${item.product.price.toStringAsFixed(2)} MAD', style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => _decItem(item.product),
                icon: const Icon(Icons.remove_circle_outline, color: Colors.black54),
              ),
              Text(item.quantity.toString(),
                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
              IconButton(
                onPressed: () => _incItem(item.product),
                icon: const Icon(Icons.add_circle_outline, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _tableColor(TableState state) {
    switch (state) {
      case TableState.LIBRE:
        return Colors.green;
      case TableState.OCCUPEE:
        return Colors.redAccent;
      case TableState.RESERVEE:
        return Colors.orange;
    }
  }

  String _stateLabel(TableState state) {
    switch (state) {
      case TableState.LIBRE:
        return 'LIBRE';
      case TableState.OCCUPEE:
        return 'PLEIN';
      case TableState.RESERVEE:
        return 'RÉSERVÉE';
    }
  }

  String _month(int month) {
    const months = [
      'janv',
      'févr',
      'mars',
      'avr',
      'mai',
      'juin',
      'juil',
      'août',
      'sept',
      'oct',
      'nov',
      'déc',
    ];
    if (month < 1 || month > 12) return '';
    return months[month - 1];
  }
}

class MenuCategory {
  final String name;
  final int count;
  final String? imageUrl;

  MenuCategory({required this.name, required this.count, this.imageUrl});
}

class MenuProduct {
  final int id;
  final String name;
  final double price;
  final String imageUrl;
  final String category;

  MenuProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.category,
  });
}

class OrderItem {
  final MenuProduct product;
  final int quantity;

  OrderItem({required this.product, required this.quantity});

  OrderItem copyWith({MenuProduct? product, int? quantity}) {
    return OrderItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}

// Serveur flow is table-only (no "emporter" mode).
