import 'package:flutter/material.dart';
import '../services/api_service.dart';
// (models moved to top)

class ChargesScreen extends StatefulWidget {
  const ChargesScreen({Key? key}) : super(key: key);

  @override
  State<ChargesScreen> createState() => _ChargesScreenState();
}

// ============ DONNÉES ==========

class _ChargesScreenState extends State<ChargesScreen> {
  final _api = ApiService();

  // ============ DONNÉES ============
  List<CategorieCharge> _categories = [];

  List<Charge> _charges = [];

  // ============ ÉTATS ============
  int _selectedIndex = 0;
  String _periodFilter = 'Ce mois';
  String _searchQuery = '';
  final List<String> _periods = ['Aujourd\'hui', 'Cette semaine', 'Ce mois', 'Cette année', 'Tout'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black54),
          onPressed: () {
            final nav = Navigator.of(context);
            if (nav.canPop()) {
              nav.pop();
            } else {
              nav.pushReplacementNamed('/home');
            }
          },
        ),
        title: const Text(
          'Charges & Dépenses',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
        ),
        actions: [
          // Filtre période
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_month, color: Color(0xFFD43B3B)),
            color: Colors.white,
            onSelected: (value) {
              setState(() => _periodFilter = value);
              // reload data from server for selected period
              _loadData();
            },
            itemBuilder: (context) => _periods.map((period) {
              return PopupMenuItem(
                value: period,
                child: Text(
                  period,
                  style: TextStyle(
                    color: _periodFilter == period
                        ? const Color(0xFFD43B3B)
                        : Colors.black87,
                    fontWeight: _periodFilter == period ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
          // Ajouter (contextuel: charge ou catégorie selon l'onglet)
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFFD43B3B)),
            onPressed: () {
              if (_selectedIndex == 1) {
                _showAddCategorieDialog();
              } else {
                _showAddChargeDialog();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          _buildSearchBar(),
          
          // Navigation par onglets
          _buildTabBar(),
          
          // Contenu principal
          Expanded(
            child: _selectedIndex == 0 
                ? _buildDashboardView() 
                : _buildCategoriesView(),
          ),
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    try {
      final cats = await _api.fetchChargeCategories();
      // compute date range for server-side filtering
      String? from;
      String? to;
      final range = _computePeriodRange(_periodFilter);
      from = range['from'];
      to = range['to'];
      final charges = await _api.fetchCharges(from: from, to: to);
      // Debug: log number of items returned by backend for quick verification
      // (temporary; can be removed after verification)
      // ignore: avoid_print
      print('DEBUG fetchCharges returned ${charges.length} items (from=$from to=$to)');

      setState(() {
        if (cats.isNotEmpty) {
          _categories = cats.map((e) => CategorieCharge(id: e['id'] as int, nom: e['nom'] as String, budget: (e['budget'] != null) ? (e['budget'] as num).toDouble() : null)).toList();
        }
        if (charges.isNotEmpty) {
          _charges = charges.map((e) => Charge(
            id: e['id'] as int,
            titre: e['titre'] ?? '',
            montant: (() {
              final m = e['montant'];
              if (m == null) return 0.0;
              if (m is num) return m.toDouble();
              if (m is String) return double.tryParse(m.replaceAll(',', '.')) ?? 0.0;
              return 0.0;
            })(),
            categorie_id: e['categorie_id'] ?? 0,
            date_charge: DateTime.tryParse(e['date_charge'] ?? '') ?? DateTime.now(),
            description: e['description'] ?? '',
            type: e['type'] ?? 'Variable',
          )).toList();
        }
      });
    } catch (e) {
      // ignore network errors silently for now
    }
  }

  // ============ BARRE DE RECHERCHE ============
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: 'Rechercher une charge...',
          hintStyle: const TextStyle(color: Colors.black45),
          prefixIcon: const Icon(Icons.search, color: Colors.black45),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.black45),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.black12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.black12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color(0xFFD43B3B), width: 1.5),
          ),
        ),
      ),
    );
  }

  // ============ BARRE D'ONGLETS ============
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          _buildTabItem(0, 'Tableau de bord', Icons.dashboard),
          _buildTabItem(1, 'Catégories', Icons.category),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFD43B3B) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.black54, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black54,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ VUE TABLEAU DE BORD ============
  Widget _buildDashboardView() {
    final filteredCharges = _filterCharges();
    
    // Statistiques
    double totalDepenses = filteredCharges.fold(0, (sum, c) => sum + c.montant);
    double totalFixes = filteredCharges.where((c) => c.type == 'Fixe').fold(0, (sum, c) => sum + c.montant);
    double totalVariables = filteredCharges.where((c) => c.type == 'Variable').fold(0, (sum, c) => sum + c.montant);
    
    // Top catégories
    Map<int, double> categoriesTotals = {};
    for (var charge in filteredCharges) {
      categoriesTotals[charge.categorie_id] = (categoriesTotals[charge.categorie_id] ?? 0) + charge.montant;
    }
    
    var sortedCategories = categoriesTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête période
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _periodFilter,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD43B3B).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD43B3B)),
                ),
                child: Text(
                  '${filteredCharges.length} charges',
                  style: const TextStyle(color: Color(0xFFD43B3B), fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Cartes statistiques
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                    'Dépenses totales',
                    '${totalDepenses.toStringAsFixed(2)} MAD',
                  Icons.euro,
                  Colors.white,
                  const Color(0xFFD43B3B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Charges fixes',
                    '${totalFixes.toStringAsFixed(2)} MAD',
                  Icons.lock,
                  Colors.blue,
                  Colors.blue.withOpacity(0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Charges variables',
                    '${totalVariables.toStringAsFixed(2)} MAD',
                  Icons.trending_up,
                  Colors.orange,
                  Colors.orange.withOpacity(0.2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Moyenne',
                    '${(totalDepenses / filteredCharges.length).toStringAsFixed(2)} MAD',
                  Icons.calculate,
                  Colors.green,
                  Colors.green.withOpacity(0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Graphique des catégories (simulé)
          const Text(
            'Répartition par catégorie',
            style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ...List.generate(
            sortedCategories.length > 5 ? 5 : sortedCategories.length,
            (index) {
              final entry = sortedCategories[index];
              final categorie = _categories.firstWhere((c) => c.id == entry.key);
              final percentage = totalDepenses > 0 ? (entry.value / totalDepenses * 100) : 0.0;

              return _buildCategoryProgress(
                categorie.nom,
                entry.value,
                percentage.clamp(0.0, 100.0) as double,
                _getCategorieColor(categorie.id),
              );
            },
          ),
          const SizedBox(height: 24),
          
          // Dernières charges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Dernières charges',
                style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedIndex = 1),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFD43B3B)),
                child: const Text('Voir tout'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Liste des dernières charges
          ...List.generate(
            filteredCharges.length > 3 ? 3 : filteredCharges.length,
            (index) => _buildCompactChargeCard(filteredCharges[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.black87, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryProgress(String name, double amount, double percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(color: Colors.black87, fontSize: 14)),
              Text(
                '${amount.toStringAsFixed(2)} €',
                style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: ((percentage.isFinite ? (percentage / 100) : 0.0).clamp(0.0, 1.0)) as double,
                    backgroundColor: Colors.black.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactChargeCard(Charge charge) {
    final cat = _categories.firstWhere(
      (c) => c.id == charge.categorie_id,
      orElse: () => CategorieCharge(id: 0, nom: 'Inconnue', budget: 0),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_getCategorieIcon(cat.id), color: _getCategorieColor(cat.id), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  charge.titre,
                  style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      cat.nom,
                      style: const TextStyle(color: Colors.black54, fontSize: 11),
                    ),
                    Text(
                      ' • ${_formatDate(charge.date_charge)}',
                      style: const TextStyle(color: Colors.black54, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${charge.montant.toStringAsFixed(2)} MAD',
                style: const TextStyle(color: Color(0xFFD43B3B), fontSize: 14, fontWeight: FontWeight.w700),
              ),
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: charge.type == 'Fixe' ? Colors.blue.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  charge.type ?? 'Variable',
                  style: TextStyle(
                    color: charge.type == 'Fixe' ? Colors.blue : Colors.orange,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============ VUE CATÉGORIES ============
  Widget _buildCategoriesView() {
    final filteredCategories = _categories
        .where((c) => c.nom.toLowerCase().contains(_searchQuery))
        .toList();

    // Calcul des dépenses par catégorie
    final Map<int, double> depenses = {};
    for (var charge in _filterCharges()) {
      depenses[charge.categorie_id] = (depenses[charge.categorie_id] ?? 0) + charge.montant;
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredCategories.length,
      itemBuilder: (context, index) {
        final cat = filteredCategories[index];
        final totalDepense = depenses[cat.id] ?? 0;
        final budget = cat.budget ?? 0;
        final ratio = budget > 0 ? totalDepense / budget : 0;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1D20),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ExpansionTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _getCategorieColor(cat.id).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getCategorieIcon(cat.id),
                color: _getCategorieColor(cat.id),
                size: 24,
              ),
            ),
            title: Text(
              cat.nom,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${totalDepense.toStringAsFixed(2)} €',
                      style: TextStyle(
                        color: _getCategorieColor(cat.id),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (budget > 0) ...[
                      const Text(
                        ' / ',
                        style: TextStyle(color: Colors.white54),
                      ),
                      Text(
                        '\$budget €',
                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ],
                ),
                if (budget > 0) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0).toDouble(),
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ratio > 0.9 ? Colors.redAccent : _getCategorieColor(cat.id),
                      ),
                      minHeight: 4,
                    ),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                  onPressed: () => _showEditCategorieDialog(cat),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                  onPressed: () => _deleteCategorie(cat),
                ),
              ],
            ),
            children: [
              // Liste des charges de cette catégorie
              ..._charges
                  .where((c) => c.categorie_id == cat.id)
                  .where((c) => _filterByPeriod(c.date_charge))
                  .map((charge) => ListTile(
                    contentPadding: const EdgeInsets.only(left: 66, right: 16, bottom: 8),
                    title: Text(
                      charge.titre,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: Text(
                      _formatDate(charge.date_charge),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${charge.montant.toStringAsFixed(2)} €',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton(
                          icon: const Icon(Icons.more_vert, color: Colors.white54, size: 18),
                          color: const Color(0xFF1B1D20),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, color: Colors.blueAccent, size: 16),
                                  SizedBox(width: 8),
                                  Text('Modifier', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.redAccent, size: 16),
                                  SizedBox(width: 8),
                                  Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showEditChargeDialog(charge);
                            } else if (value == 'delete') {
                              _deleteCharge(charge);
                            }
                          },
                        ),
                      ],
                    ),
                  )),
              // Bouton ajouter
              Padding(
                padding: const EdgeInsets.only(left: 66, right: 16, bottom: 16, top: 8),
                child: OutlinedButton.icon(
                  onPressed: () => _showAddChargeDialog(cat.id),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ajouter une charge'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _getCategorieColor(cat.id),
                    side: BorderSide(color: _getCategorieColor(cat.id)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============ FILTRES ============
  List<Charge> _filterCharges() {
    return _charges
        .where((c) => _filterByPeriod(c.date_charge))
        .where((c) => 
            c.titre.toLowerCase().contains(_searchQuery) ||
            c.description.toLowerCase().contains(_searchQuery))
        .toList()
      ..sort((a, b) => b.date_charge.compareTo(a.date_charge));
  }

  bool _filterByPeriod(DateTime date) {
    final now = DateTime.now();
    switch (_periodFilter) {
      case 'Aujourd\'hui':
        return date.year == now.year && date.month == now.month && date.day == now.day;
      case 'Cette semaine':
        final start = now.subtract(Duration(days: now.weekday - 1));
        return date.isAfter(start) && date.isBefore(start.add(const Duration(days: 7)));
      case 'Ce mois':
        return date.year == now.year && date.month == now.month;
      case 'Cette année':
        return date.year == now.year;
      case 'Tout':
      default:
        return true;
    }
  }

  Map<String, String?> _computePeriodRange(String period) {
    final now = DateTime.now();
    String formatDate(DateTime d) => d.toIso8601String().split('T').first;

    switch (period) {
      case 'Aujourd\'hui':
        final day = DateTime(now.year, now.month, now.day);
        return {'from': formatDate(day), 'to': formatDate(day)};
      case 'Cette semaine':
        final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return {'from': formatDate(start), 'to': formatDate(end)};
      case 'Ce mois':
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0);
        return {'from': formatDate(start), 'to': formatDate(end)};
      case 'Cette année':
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31);
        return {'from': formatDate(start), 'to': formatDate(end)};
      case 'Tout':
      default:
        return {'from': null, 'to': null};
    }
  }

  // ============ DIALOGS ============
  void _showAddChargeDialog([int? preselectedCategorieId]) {
    final titreCtrl = TextEditingController();
    final montantCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    int selectedCategorieId = preselectedCategorieId ?? _categories.first.id;
    String selectedType = 'Variable';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1B1D20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Nouvelle charge', style: TextStyle(color: Colors.white, fontSize: 20)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titreCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Titre',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: montantCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Montant',
                            labelStyle: TextStyle(color: Colors.white70),
                            prefixText: '€ ',
                              border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Type',
                            labelStyle: TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(),
                          ),
                          dropdownColor: const Color(0xFF1B1D20),
                          style: const TextStyle(color: Colors.white),
                          items: ['Fixe', 'Variable'].map((type) {
                            return DropdownMenuItem(value: type, child: Text(type));
                          }).toList(),
                          onChanged: (value) => setDialogState(() => selectedType = value!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedCategorieId,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                    dropdownColor: const Color(0xFF1B1D20),
                    style: const TextStyle(color: Colors.white),
                    items: _categories.map((c) => 
                      DropdownMenuItem(value: c.id, child: Text(c.nom))
                    ).toList(),
                    onChanged: (value) => setDialogState(() => selectedCategorieId = value!),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (context, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Color(0xFFD43B3B),
                              surface: Color(0xFF1B1D20),
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (date != null) setDialogState(() => selectedDate = date);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDate(selectedDate),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const Icon(Icons.calendar_today, color: Colors.white70, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Description (optionnelle)',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (titreCtrl.text.isEmpty || montantCtrl.text.isEmpty) return;
                  // call API to create charge
                  () async {
                    final payload = {
                      'titre': titreCtrl.text,
                      'montant': double.tryParse(montantCtrl.text) ?? 0,
                      'categorie_id': selectedCategorieId,
                      'date_charge': selectedDate.toIso8601String(),
                      'description': descriptionCtrl.text,
                      'type': selectedType,
                    };
                    try {
                      final resp = await _api.createCharge(payload);
                      setState(() {
                        _charges.add(Charge(
                          id: resp['id'] as int,
                          titre: resp['titre'] ?? titreCtrl.text,
                          montant: resp['montant'] != null ? (resp['montant'] is num ? (resp['montant'] as num).toDouble() : double.tryParse(resp['montant'].toString().replaceAll(',', '.')) ?? (double.tryParse(montantCtrl.text) ?? 0.0)) : (double.tryParse(montantCtrl.text) ?? 0.0),
                          categorie_id: resp['categorie_id'] ?? selectedCategorieId,
                          date_charge: DateTime.tryParse(resp['date_charge'] ?? selectedDate.toIso8601String()) ?? selectedDate,
                          description: resp['description'] ?? descriptionCtrl.text,
                          type: resp['type'] ?? selectedType,
                        ));
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Charge ajoutée')));
                    } catch (e) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur ajout charge')));
                    }
                  }();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD43B3B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Ajouter'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditCategorieDialog(CategorieCharge categorie) {
    final nomCtrl = TextEditingController(text: categorie.nom);
    final budgetCtrl = TextEditingController(text: categorie.budget?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1D20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Modifier catégorie', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nom',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: budgetCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Budget mensuel (€)',
                labelStyle: TextStyle(color: Colors.white70),
                prefixText: '€ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nomCtrl.text.isNotEmpty) {
                // call API to update category
                () async {
                  Navigator.pop(ctx);
                  final payload = {
                    'nom': nomCtrl.text,
                    'budget': budgetCtrl.text.isNotEmpty ? double.tryParse(budgetCtrl.text) : null,
                  };
                  try {
                    final resp = await _api.updateChargeCategory(categorie.id, payload);
                    setState(() {
                      final index = _categories.indexWhere((c) => c.id == categorie.id);
                      if (index != -1) {
                        _categories[index] = CategorieCharge(
                          id: resp['id'] as int,
                          nom: resp['nom'] ?? nomCtrl.text,
                          budget: resp['budget'] != null ? (resp['budget'] as num).toDouble() : null,
                        );
                      }
                    });
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Catégorie mise à jour')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur mise à jour catégorie')));
                  }
                }();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD43B3B)),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showEditChargeDialog(Charge charge) {
    final titreCtrl = TextEditingController(text: charge.titre);
    final montantCtrl = TextEditingController(text: charge.montant.toString());
    final descriptionCtrl = TextEditingController(text: charge.description);
    DateTime selectedDate = charge.date_charge;
    int selectedCategorieId = charge.categorie_id;
    String selectedType = charge.type ?? 'Variable';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1B1D20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text('Modifier ${charge.titre}', style: const TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titreCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Titre'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: montantCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Montant',
                            prefixText: '€ ',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: selectedType,
                          decoration: const InputDecoration(labelText: 'Type'),
                          dropdownColor: const Color(0xFF1B1D20),
                          style: const TextStyle(color: Colors.white),
                          items: ['Fixe', 'Variable'].map((type) {
                            return DropdownMenuItem(value: type, child: Text(type));
                          }).toList(),
                          onChanged: (value) => setDialogState(() => selectedType = value!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedCategorieId,
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                    dropdownColor: const Color(0xFF1B1D20),
                    style: const TextStyle(color: Colors.white),
                    items: _categories.map((c) => 
                      DropdownMenuItem(value: c.id, child: Text(c.nom))
                    ).toList(),
                    onChanged: (value) => setDialogState(() => selectedCategorieId = value!),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (context, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Color(0xFFD43B3B),
                              surface: Color(0xFF1B1D20),
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (date != null) setDialogState(() => selectedDate = date);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDate(selectedDate), style: const TextStyle(color: Colors.white)),
                          const Icon(Icons.calendar_today, color: Colors.white70, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (titreCtrl.text.isEmpty || montantCtrl.text.isEmpty) return;
                  // call API to update charge
                  () async {
                    Navigator.pop(ctx);
                    final payload = {
                      'titre': titreCtrl.text,
                      'montant': double.tryParse(montantCtrl.text) ?? charge.montant,
                      'categorie_id': selectedCategorieId,
                      'date_charge': selectedDate.toIso8601String(),
                      'description': descriptionCtrl.text,
                      'type': selectedType,
                    };
                    try {
                      final resp = await _api.updateCharge(charge.id, payload);
                      setState(() {
                        final index = _charges.indexWhere((c) => c.id == charge.id);
                        if (index != -1) {
                          _charges[index] = Charge(
                            id: resp['id'] as int,
                            titre: resp['titre'] ?? titreCtrl.text,
                            montant: resp['montant'] != null ? (resp['montant'] is num ? (resp['montant'] as num).toDouble() : double.tryParse(resp['montant'].toString().replaceAll(',', '.')) ?? (double.tryParse(montantCtrl.text) ?? charge.montant)) : (double.tryParse(montantCtrl.text) ?? charge.montant),
                            categorie_id: resp['categorie_id'] ?? selectedCategorieId,
                            date_charge: DateTime.tryParse(resp['date_charge'] ?? selectedDate.toIso8601String()) ?? selectedDate,
                            description: resp['description'] ?? descriptionCtrl.text,
                            type: resp['type'] ?? selectedType,
                          );
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Charge mise à jour')));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur mise à jour charge')));
                    }
                  }();
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD43B3B)),
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============ SUPPRESSION ============
  void _deleteCategorie(CategorieCharge categorie) {
    final hasCharges = _charges.any((c) => c.categorie_id == categorie.id);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1D20),
        title: const Text('Supprimer la catégorie', style: TextStyle(color: Colors.white)),
        content: Text(
          hasCharges
              ? 'Cette catégorie contient ${_charges.where((c) => c.categorie_id == categorie.id).length} charge(s). La suppression est définitive.'
              : 'Supprimer "${categorie.nom}" ?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              // call API to delete category
              () async {
                Navigator.pop(ctx);
                try {
                  await _api.deleteChargeCategory(categorie.id);
                  setState(() {
                    _categories.removeWhere((c) => c.id == categorie.id);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Catégorie supprimée')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur suppression catégorie')));
                }
              }();
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _deleteCharge(Charge charge) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1D20),
        title: const Text('Supprimer la charge', style: TextStyle(color: Colors.white)),
        content: Text('Supprimer "${charge.titre}" ?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              // call API to delete charge
              () async {
                Navigator.pop(ctx);
                try {
                  await _api.deleteCharge(charge.id);
                  setState(() => _charges.removeWhere((c) => c.id == charge.id));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Charge supprimée')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur suppression charge')));
                }
              }();
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // ============ UTILITAIRES ============
  Color _getCategorieColor(int id) {
    final colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple, 
      Colors.teal, Colors.pink, Colors.indigo, Colors.cyan,
    ];
    return colors[id % colors.length];
  }

  IconData _getCategorieIcon(int id) {
    final icons = [
      Icons.home, Icons.electrical_services, Icons.water_drop, Icons.local_gas_station,
      Icons.wifi, Icons.phone, Icons.inventory, Icons.people,
    ];
    return icons[id % icons.length];
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showAddCategorieDialog() {
    final nomCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1D20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Nouvelle catégorie', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nom',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: budgetCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Budget mensuel (€)',
                labelStyle: TextStyle(color: Colors.white70),
                prefixText: '€ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            onPressed: () {
              if (nomCtrl.text.isEmpty) return;
              () async {
                final payload = {
                  'nom': nomCtrl.text,
                  'budget': budgetCtrl.text.isNotEmpty ? double.tryParse(budgetCtrl.text) : null,
                };
                Navigator.pop(ctx);
                try {
                  final resp = await _api.createChargeCategory(payload);
                  setState(() {
                    _categories.add(CategorieCharge(
                      id: resp['id'] as int,
                      nom: resp['nom'] ?? nomCtrl.text,
                      budget: resp['budget'] != null ? (resp['budget'] as num).toDouble() : null,
                    ));
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Catégorie créée')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur création catégorie')));
                }
              }();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD43B3B)),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

}

// ============ MODÈLES ============
class CategorieCharge {
  final int id;
  final String nom;
  final double? budget;
  
  CategorieCharge({
    required this.id,
    required this.nom,
    this.budget,
  });
  
  CategorieCharge copyWith({
    int? id,
    String? nom,
    double? budget,
  }) {
    return CategorieCharge(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      budget: budget ?? this.budget,
    );
  }
}

class Charge {
  final int id;
  final String titre;
  final double montant;
  final int categorie_id;
  final DateTime date_charge;
  final String description;
  final String? type;
  
  Charge({
    required this.id,
    required this.titre,
    required this.montant,
    required this.categorie_id,
    required this.date_charge,
    required this.description,
    this.type,
  });
  
  Charge copyWith({
    int? id,
    String? titre,
    double? montant,
    int? categorie_id,
    DateTime? date_charge,
    String? description,
    String? type,
  }) {
    return Charge(
      id: id ?? this.id,
      titre: titre ?? this.titre,
      montant: montant ?? this.montant,
      categorie_id: categorie_id ?? this.categorie_id,
      date_charge: date_charge ?? this.date_charge,
      description: description ?? this.description,
      type: type ?? this.type,
    );
  }
}