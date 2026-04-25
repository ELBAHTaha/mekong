import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class CommandesJourScreen extends StatefulWidget {
  const CommandesJourScreen({Key? key}) : super(key: key);

  @override
  State<CommandesJourScreen> createState() => _CommandesJourScreenState();
}

class _CommandesJourScreenState extends State<CommandesJourScreen> {
  // ============ DONNÉES SIMULÉES ============
  List<Commande> _commandes = [
    ];

  final ApiService _api = ApiService();
  bool _canEdit = false; // whether the current user can modify commandes
  List<User> _personnel = [];
  List<User> _serveurs = [];
  List<User> _caissiers = [];
  int? _selectedPersonneId;
  String _filterBy = 'TOUS'; // 'TOUS' | 'SERVEUR' | 'CAISSIER'
  bool _includeServeur = false;
  List<bool> _filterSelected = [true, false, false]; // Tous, Serveur, Caissier

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  Future<void> _initPage() async {
    await _loadPermissions();
    await _loadServeurs();
    await _loadCommandes();
  }

  Future<void> _loadServeurs() async {
    try {
      final list = await _api.fetchPersonnelList();
      // split into serveurs and caissiers based on role heuristics
      final serveurs = list.where((u) => (u.role ?? '').toLowerCase().contains('serveur') || (u.role ?? '').toLowerCase().contains('serve')).toList();
      final caissiers = list.where((u) => (u.role ?? '').toLowerCase().contains('caissier') || (u.role ?? '').toLowerCase().contains('cash') || (u.role ?? '').toLowerCase().contains('caisse')).toList();
      setState(() {
        _personnel = list;
        _serveurs = serveurs;
        _caissiers = caissiers;
      });
    } catch (e) {
      // ignore errors for now
    }
  }

  Future<void> _loadPermissions() async {
    try {
      final token = await _api.getStoredToken();
      if (token != null && token.isNotEmpty) {
        final user = await _api.fetchUser(token);
        // simple role-based decision: viewers/servers cannot edit
        final role = (user.role ?? '').toLowerCase();
        _canEdit = !(role.contains('view') || role.contains('viewer') || role.contains('serveur') || role.contains('serve'));
      } else {
        _canEdit = false;
      }
    } catch (e) {
      _canEdit = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadCommandes() async {
    try {
      // By default show commandes for today
      final today = DateTime.now();
      final dateStr = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      List<dynamic> list;
      if (_filterBy == 'SERVEUR') {
        list = await _api.fetchCommandes(serveurId: _selectedPersonneId, from: dateStr, to: dateStr, includeServeur: _includeServeur);
      } else if (_filterBy == 'CAISSIER') {
        list = await _api.fetchCommandes(caissierId: _selectedPersonneId, from: dateStr, to: dateStr, includeServeur: _includeServeur);
      } else {
        list = await _api.fetchCommandes(from: dateStr, to: dateStr, includeServeur: _includeServeur);
      }

      setState(() {
        final parsed = (list as List<dynamic>).map<Commande>((e) => Commande.fromJson(e as Map<String, dynamic>)).toList();
        _commandes = parsed;
      });
    } catch (e) {
      // Log and surface the error so we can debug why nothing loads
      // (usually authentication / server down / CORS issues)
      // ignore: avoid_print
      print('fetchCommandes error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur en chargeant les commandes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============ ÉTATS ============
  String _selectedStatut = 'TOUS';
  String _selectedType = 'TOUS';
  String _searchQuery = '';
  int _selectedIndex = 0;
  bool _showStats = true;

  final List<String> _statuts = ['TOUS', 'NOUVELLE', 'PREPARATION', 'PRETE', 'LIVRAISON', 'LIVREE', 'ANNULEE'];
  final List<String> _types = ['TOUS', 'SUR_PLACE', 'LIVRAISON'];

  bool _isPayeOrEnPaiement(Commande c) {
    // "Payée" tab should include orders that are already being paid.
    // We treat any positive amount paid as "in payment", and also allow backend status hints.
    if (c.montantPaye > 0) return true;
    final s = (c.statutPaiement ?? '').trim().toUpperCase();
    if (s.isEmpty) return false;
    // Some deployments may put values like PAYE / PAYÉ / EN_COURS / PARTIEL.
    if (s.contains('PAY')) return true;
    if (s.contains('PAI')) return true;
    if (s.contains('EN_COURS')) return true;
    if (s.contains('PART')) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios, color: Colors.black54, size: 20),
          onPressed: () {
            final nav = Navigator.of(context);
            if (nav.canPop()) {
              nav.pop();
            } else {
              nav.pushReplacementNamed('/home');
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Commandes du jour',
              style: TextStyle(
                  color: Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
            ),
            Text(
              _formatDate(DateTime.now()),
              style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          // Rafraîchir
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFD43B3B)),
            onPressed: _refreshCommandes,
          ),
          // Filtres
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune, color: Colors.black54),
            color: Colors.white,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'stats',
                child: Row(
                  children: [
                    Icon(Icons.show_chart, color: Colors.black54, size: 18),
                    SizedBox(width: 12),
                    Text('Afficher/Masquer stats',
                        style: TextStyle(color: Colors.black87)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, color: Colors.black54, size: 18),
                    SizedBox(width: 12),
                    Text('Exporter', style: TextStyle(color: Colors.black87)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'stats') setState(() => _showStats = !_showStats);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          _buildSearchBar(),
          
          // Filtres rapides
          _buildQuickFilters(),
          
          // Statistiques (optionnelles)
          if (_showStats) _buildStatsCards(),
          
          // Onglets
          _buildTabBar(),
          
          // Liste des commandes
          Expanded(
            child: _buildCommandesList(),
          ),
        ],
      ),
    );
  }

  // ============ BARRE DE RECHERCHE ============
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: 'Rechercher commande, client, table...',
          hintStyle: const TextStyle(color: Colors.black38),
          prefixIcon: const Icon(Icons.search, color: Colors.black45, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.black45, size: 18),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.black12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color(0xFFD43B3B), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  // ============ FILTRES RAPIDES ============
  Widget _buildQuickFilters() {
    final persons = _filterBy == 'SERVEUR'
        ? _serveurs
        : (_filterBy == 'CAISSIER' ? _caissiers : _personnel);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Filter mode segmented control
          ToggleButtons(
            isSelected: _filterSelected,
            borderRadius: BorderRadius.circular(20),
            selectedColor: Colors.black87,
            fillColor: Colors.black.withOpacity(0.06),
            color: Colors.black54,
            constraints: const BoxConstraints(minWidth: 72, minHeight: 36),
            onPressed: (index) {
              setState(() {
                for (int i = 0; i < _filterSelected.length; i++) {
                  _filterSelected[i] = (i == index);
                }
                _filterBy = index == 0 ? 'TOUS' : (index == 1 ? 'SERVEUR' : 'CAISSIER');
                _selectedPersonneId = null;
              });
              _loadCommandes();
            },
            children: const [
              Text('Tous'),
              Text('Serveur'),
              Text('Caissier'),
            ],
          ),
          const SizedBox(width: 8),
          // Include commande_serveur switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Text('Inclure commande_serveur',
                    style: TextStyle(color: Colors.black54, fontSize: 12)),
                const SizedBox(width: 8),
                Switch.adaptive(
                  value: _includeServeur,
                  activeColor: const Color(0xFFD43B3B),
                  onChanged: (val) {
                    setState(() {
                      _includeServeur = val;
                    });
                    _loadCommandes();
                  },
                ),
              ],
            ),
          ),
          // Person selector when filtering by Serveur or Caissier
          if (_filterBy != 'TOUS')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _selectedPersonneId,
                  dropdownColor: Colors.white,
                  hint: const Text('Sélectionner',
                      style: TextStyle(color: Colors.black54, fontSize: 12)),
                  style: const TextStyle(color: Colors.black87, fontSize: 12),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        'Tous',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                    ...persons
                        .map((u) => DropdownMenuItem<int?>(
                              value: u.id,
                              child: Text(
                                u.name,
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ))
                        .toList(),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedPersonneId = val;
                    });
                    _loadCommandes();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        backgroundColor: Colors.transparent,
        selectedColor: color.withOpacity(0.2),
        checkmarkColor: Colors.white,
        side: BorderSide(
          color: selected ? color : Colors.white24,
          width: selected ? 1.5 : 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }

  // ============ STATISTIQUES ============
  Widget _buildStatsCards() {
    final filteredCommandes = _getFilteredCommandes();
    
    int totalCommandes = filteredCommandes.length;
    double totalCA = filteredCommandes.fold(0, (sum, c) => sum + c.total);
    int enPreparation = filteredCommandes.where((c) => c.statut == 'PREPARATION' || c.statut == 'NOUVELLE').length;
    int pretes = filteredCommandes.where((c) => c.statut == 'PRETE' || _isPayeOrEnPaiement(c)).length;
    int livraison = filteredCommandes.where((c) => c.statut == 'LIVRAISON').length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatCard('CA total', '${totalCA.toStringAsFixed(2)} MAD',
                Icons.euro, Colors.black87, const Color(0xFFD43B3B), totalCommandes),
            _buildStatCard('En cours', '$enPreparation', Icons.pending, Colors.orange, Colors.orange.withOpacity(0.2), null),
            _buildStatCard('Payées', '$pretes', Icons.check_circle, Colors.green, Colors.green.withOpacity(0.2), null),
            _buildStatCard('Livraison', '$livraison', Icons.delivery_dining, Colors.blue, Colors.blue.withOpacity(0.2), null),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, Color bgColor, int? total) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54, fontSize: 11),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (total != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '/ $total',
                        style: const TextStyle(color: Colors.black38, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============ BARRE D'ONGLETS ============
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          _buildTabItem(0, 'Toutes', Icons.receipt),
          _buildTabItem(1, 'En cours', Icons.restaurant),
          _buildTabItem(2, 'Payées', Icons.check_circle_outline),
          _buildTabItem(3, 'Livraison', Icons.delivery_dining),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon) {
    final isSelected = _selectedIndex == index;
    int count = 0;
    
    if (index == 1) count = _commandes.where((c) => c.statut == 'NOUVELLE' || c.statut == 'PREPARATION').length;
    if (index == 2) count = _commandes.where((c) => c.statut == 'PRETE' || _isPayeOrEnPaiement(c)).length;
    if (index == 3) count = _commandes.where((c) => c.statut == 'LIVRAISON').length;
    if (index == 0) count = _commandes.length;
    
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
              Icon(icon,
                  color: isSelected ? Colors.white : Colors.black54, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black54,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.35)
                        : Colors.black.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black54,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============ LISTE DES COMMANDES ============
  Widget _buildCommandesList() {
    List<Commande> commandes = _getFilteredCommandes();
    
    // Filtre par onglet
    switch (_selectedIndex) {
      case 1:
        commandes = commandes.where((c) => c.statut == 'NOUVELLE' || c.statut == 'PREPARATION').toList();
        break;
      case 2:
        commandes = commandes
            .where((c) => c.statut == 'PRETE' || _isPayeOrEnPaiement(c))
            .toList();
        break;
      case 3:
        commandes = commandes.where((c) => c.statut == 'LIVRAISON').toList();
        break;
    }
    
    // Grouper par statut
    Map<String, List<Commande>> groupedByStatut = {};
    for (var commande in commandes) {
      if (!groupedByStatut.containsKey(commande.statut)) {
        groupedByStatut[commande.statut] = [];
      }
      groupedByStatut[commande.statut]!.add(commande);
    }
    
    // Ordonner les statuts
    final statutOrder = ['NOUVELLE', 'PREPARATION', 'PRETE', 'LIVRAISON', 'LIVREE', 'ANNULEE'];
    final sortedKeys = groupedByStatut.keys.toList()
      ..sort((a, b) => statutOrder.indexOf(a).compareTo(statutOrder.indexOf(b)));
    
    if (commandes.isEmpty) {
      return _buildEmptyState();
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, sectionIndex) {
        final statut = sortedKeys[sectionIndex];
        final commandesSection = groupedByStatut[statut]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête de section
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatutColor(statut).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getStatutIcon(statut),
                          color: _getStatutColor(statut),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getStatutLabel(statut),
                          style: TextStyle(
                            color: _getStatutColor(statut),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: _getStatutColor(statut),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${commandesSection.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Total: ${commandesSection.fold<double>(0.0, (double sum, Commande c) => sum + c.total).toStringAsFixed(2)} MAD',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Commandes
            ...commandesSection.map((commande) => _buildCommandeCard(commande)),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  // ============ CARTE COMMANDE ============
  Widget _buildCommandeCard(Commande commande) {
    final color = _getStatutColor(commande.statut);
    final isUrgent = commande.date_commande.isAfter(DateTime.now().subtract(const Duration(minutes: 10)));
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: isUrgent && commande.statut == 'NOUVELLE'
              ? const Color(0xFFD43B3B).withOpacity(0.5)
              : Colors.black12,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showCommandeDetails(commande),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        commande.type == 'SUR_PLACE' ? Icons.restaurant : Icons.delivery_dining,
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '#${commande.id}',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getStatutColor(commande.statut).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getStatutLabel(commande.statut),
                                  style: TextStyle(
                                    color: _getStatutColor(commande.statut),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (commande.type == 'LIVRAISON') ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'LIVRAISON',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                commande.type == 'SUR_PLACE' ? Icons.table_restaurant : Icons.person,
                                size: 12,
                                color: Colors.black45,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                commande.clientNom,
                                style: const TextStyle(
                                    color: Colors.black54, fontSize: 13),
                              ),
                              if (commande.table_id != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.black12),
                                  ),
                                  child: Text(
                                    'Table ${commande.table_id}',
                                    style: const TextStyle(
                                        color: Colors.black54, fontSize: 11),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${commande.total.toStringAsFixed(2)} MAD',
                          style: TextStyle(
                            color: color,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatHeure(commande.date_commande),
                          style: TextStyle(
                            color: isUrgent && commande.statut == 'NOUVELLE' 
                                ? const Color(0xFFD43B3B) 
                                : Colors.black45,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Liste des produits (compacte)
                const SizedBox(height: 12),
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: commande.produits.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final produit = commande.produits[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${produit.quantite}x',
                              style: TextStyle(
                                color: _getStatutColor(commande.statut),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              produit.nom,
                              style: const TextStyle(
                                  color: Colors.black87, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                // Informations supplémentaires
                if (commande.notes != null || commande.serveur_nom != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (commande.serveur_nom != null) ...[
                        Icon(Icons.person_outline,
                            size: 12, color: Colors.black45),
                        const SizedBox(width: 4),
                        Text(
                          commande.serveur_nom!,
                          style:
                              const TextStyle(color: Colors.black45, fontSize: 11),
                        ),
                      ],
                      const SizedBox(width: 12),
                      if (commande.notes != null) ...[
                        Icon(Icons.note_outlined,
                            size: 12, color: Colors.black45),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            commande.notes!,
                            style: const TextStyle(
                                color: Colors.black45, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                
                // Actions rapides — uniquement lecture (Détails)
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQuickAction(
                      'Détails',
                      Icons.visibility,
                      Colors.blueAccent,
                      () => _showCommandeDetails(commande),
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

  Widget _buildQuickAction(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ DÉTAILS COMMANDE ============
  void _showCommandeDetails(Commande commande) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF7F7FB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  // Poignée
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // En-tête
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _getStatutColor(commande.statut).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            commande.type == 'SUR_PLACE' ? Icons.restaurant : Icons.delivery_dining,
                            color: _getStatutColor(commande.statut),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Commande #${commande.id}',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                commande.clientNom,
                                style: const TextStyle(
                                    color: Colors.black54, fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black54),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  
                  // Contenu scrollable
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        // Statut et heure
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _getStatutColor(commande.statut).withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getStatutIcon(commande.statut),
                                      color: _getStatutColor(commande.statut),
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Statut',
                                        style: TextStyle(
                                            color: Colors.black54, fontSize: 11),
                                      ),
                                      Text(
                                        _getStatutLabel(commande.statut),
                                        style: TextStyle(
                                          color: _getStatutColor(commande.statut),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Heure',
                                    style: TextStyle(
                                        color: Colors.black54, fontSize: 11),
                                  ),
                                  Text(
                                    _formatHeure(commande.date_commande),
                                    style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Informations client
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.black54, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Informations',
                                    style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildDetailRow('Type', commande.type),
                              if (commande.table_id != null) _buildDetailRow('Table', '${commande.table_id}'),
                              if (commande.adresse != null) _buildDetailRow('Adresse', commande.adresse!),
                              if (commande.telephone != null) _buildDetailRow('Téléphone', commande.telephone!),
                              if (commande.serveur_nom != null) _buildDetailRow('Serveur', commande.serveur_nom!),
                              if (commande.notes != null) ...[
                                const Divider(color: Colors.black12, height: 24),
                                const Text(
                                  'Notes',
                                  style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.black12),
                                  ),
                                  child: Text(
                                    commande.notes!,
                                    style: const TextStyle(
                                        color: Colors.black87, fontSize: 14),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Produits commandés
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.receipt,
                                          color: Colors.black54, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Articles',
                                        style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.black12),
                                    ),
                                    child: Text(
                                      '${commande.produits.length} article${commande.produits.length > 1 ? 's' : ''}',
                                      style: const TextStyle(
                                          color: Colors.black54, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ...commande.produits.map((produit) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD43B3B).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${produit.quantite}',
                                          style: const TextStyle(
                                            color: Color(0xFFD43B3B),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            produit.nom,
                                            style: const TextStyle(
                                                color: Colors.black87,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500),
                                          ),
                                          Text(
                                            '${produit.prix_unitaire.toStringAsFixed(2)} MAD',
                                            style: const TextStyle(
                                                color: Colors.black54, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${produit.total.toStringAsFixed(2)} MAD',
                                      style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              )),
                              const Divider(color: Colors.black12, height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${commande.total.toStringAsFixed(2)} MAD',
                                    style: const TextStyle(
                                      color: Color(0xFFD43B3B),
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Actions
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close, size: 18),
                                label: const Text('Fermer'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.black54,
                                  side: const BorderSide(color: Colors.black12),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Action de validation désactivée
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ============ ÉTAT VIDE ============
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.04),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long,
              size: 60,
              color: Colors.black12,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aucune commande',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Les commandes du jour apparaîtront ici',
            style: TextStyle(color: Colors.black54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _refreshCommandes,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD43B3B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Rafraîchir'),
          ),
        ],
      ),
    );
  }

  // ============ UTILITAIRES ============
  List<Commande> _getFilteredCommandes() {
    return _commandes.where((commande) {
      // Filtre recherche
      final matchesSearch = _searchQuery.isEmpty ||
          commande.id.toString().contains(_searchQuery) ||
          commande.clientNom.toLowerCase().contains(_searchQuery) ||
          (commande.table_id?.toString().contains(_searchQuery) ?? false);
      
      // Filtre statut
      final matchesStatut = _selectedStatut == 'TOUS' || commande.statut == _selectedStatut;
      
      // Filtre type
      final matchesType = _selectedType == 'TOUS' || commande.type == _selectedType;
      
      // Filtre date du jour
      final isToday = commande.date_commande.year == DateTime.now().year &&
          commande.date_commande.month == DateTime.now().month &&
          commande.date_commande.day == DateTime.now().day;
      
      return matchesSearch && matchesStatut && matchesType && isToday;
    }).toList();
  }

  void _updateStatut(int commandeId, String nouveauStatut) {
    // Fonctionnalité de validation/fin de commande supprimée — informer l'utilisateur
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('La validation/terminaison des commandes est désactivée.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _refreshCommandes() {
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Commandes mises à jour'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Color _getStatutColor(String statut) {
    switch (statut) {
      case 'NOUVELLE': return const Color(0xFFD43B3B);
      case 'PREPARATION': return Colors.orange;
      case 'PRETE': return Colors.green;
      case 'LIVRAISON': return Colors.blue;
      case 'LIVREE': return Colors.grey;
      case 'ANNULEE': return Colors.redAccent;
      default: return Colors.white;
    }
  }

  IconData _getStatutIcon(String statut) {
    switch (statut) {
      case 'NOUVELLE': return Icons.fiber_new;
      case 'PREPARATION': return Icons.restaurant;
      case 'PRETE': return Icons.check_circle;
      case 'LIVRAISON': return Icons.delivery_dining;
      case 'LIVREE': return Icons.done_all;
      case 'ANNULEE': return Icons.cancel;
      default: return Icons.receipt;
    }
  }

  String _getStatutLabel(String statut) {
    switch (statut) {
      // Admin wording: unpaid orders are "En cours", paid orders are "Payées".
      case 'NOUVELLE': return 'EN COURS';
      case 'PREPARATION': return 'EN COURS';
      case 'PRETE': return 'PAYÉE';
      case 'LIVRAISON': return 'LIVRAISON';
      case 'LIVREE': return 'LIVRÉE';
      case 'ANNULEE': return 'ANNULÉE';
      default: return statut;
    }
  }

  String _getActionLabel(String statut) {
    switch (statut) {
      case 'NOUVELLE': return 'Préparer';
      case 'PREPARATION': return 'Marquer prête';
      case 'PRETE': return 'Servir / Livrer';
      case 'LIVRAISON': return 'Confirmer livrée';
      case 'LIVREE': return 'Terminée';
      case 'ANNULEE': return 'Réactiver';
      default: return 'Suivant';
    }
  }

  String _getNextStatut(String statut) {
    switch (statut) {
      case 'NOUVELLE': return 'PREPARATION';
      case 'PREPARATION': return 'PRETE';
      case 'PRETE': return 'LIVREE';
      case 'LIVRAISON': return 'LIVREE';
      default: return statut;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatHeure(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}h${date.minute.toString().padLeft(2, '0')}';
  }
}

// ============ MODÈLES ============
class Commande {
  final int id;
  final String clientNom;
  final String type;
  final String statut;
  final double total;
  final double montantPaye;
  final String? statutPaiement;
  final int? table_id;
  final String? serveur_nom;
  final DateTime date_commande;
  final List<CommandeProduit> produits;
  final String? adresse;
  final String? telephone;
  final String? notes;

  Commande({
    required this.id,
    required this.clientNom,
    required this.type,
    required this.statut,
    required this.total,
    this.montantPaye = 0.0,
    this.statutPaiement,
    this.table_id,
    this.serveur_nom,
    required this.date_commande,
    required this.produits,
    this.adresse,
    this.telephone,
    this.notes,
  });

  Commande copyWith({
    int? id,
    String? clientNom,
    String? type,
    String? statut,
    double? total,
    double? montantPaye,
    String? statutPaiement,
    int? table_id,
    String? serveur_nom,
    DateTime? date_commande,
    List<CommandeProduit>? produits,
    String? adresse,
    String? telephone,
    String? notes,
  }) {
    return Commande(
      id: id ?? this.id,
      clientNom: clientNom ?? this.clientNom,
      type: type ?? this.type,
      statut: statut ?? this.statut,
      total: total ?? this.total,
      montantPaye: montantPaye ?? this.montantPaye,
      statutPaiement: statutPaiement ?? this.statutPaiement,
      table_id: table_id ?? this.table_id,
      serveur_nom: serveur_nom ?? this.serveur_nom,
      date_commande: date_commande ?? this.date_commande,
      produits: produits ?? this.produits,
      adresse: adresse ?? this.adresse,
      telephone: telephone ?? this.telephone,
      notes: notes ?? this.notes,
    );
  }

  factory Commande.fromJson(Map<String, dynamic> json) {
    // parse produits (relation) or fallback to items (stringified JSON used by older orders)
    List<CommandeProduit> parsedProduits = [];
    if (json['produits'] != null && (json['produits'] as List).isNotEmpty) {
      parsedProduits = (json['produits'] as List<dynamic>)
          .map((e) => CommandeProduit.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json['items'] != null) {
      try {
        final items = jsonDecode(json['items'] as String) as List<dynamic>;
        parsedProduits = items.map<CommandeProduit>((it) {
          final prix = (it['price'] is num) ? (it['price'] as num).toDouble() : double.tryParse('${it['price']}') ?? 0.0;
          final qtyRaw = it['quantity'] ?? it['quantite'];
          final qty = (qtyRaw is int) ? qtyRaw : (int.tryParse('${qtyRaw}') ?? 1);
          final totRaw = it['total'] ?? prix;
          double totVal;
          if (totRaw is num) {
            totVal = (totRaw as num).toDouble();
          } else {
            totVal = double.tryParse('${totRaw}') ?? (prix * qty);
          }
          return CommandeProduit(
            id: (it['id'] is int) ? it['id'] as int : 0,
            nom: (it['name'] ?? it['nom'] ?? '') as String,
            quantite: qty,
            prix_unitaire: prix,
            total: totVal,
          );
        }).toList();
      } catch (_) {
        parsedProduits = <CommandeProduit>[];
      }
    }

    return Commande(
      id: json['id'] as int,
      clientNom: json['client_nom'] as String? ?? '',
      type: (json['type'] as String?)?.isNotEmpty == true ? json['type'] as String : 'SUR_PLACE',
      statut: (json['statut'] as String?)?.isNotEmpty == true ? json['statut'] as String : 'NOUVELLE',
      total: (json['total'] is num) ? (json['total'] as num).toDouble() : double.tryParse('${json['total']}') ?? 0.0,
      montantPaye: (json['montant_paye'] is num)
          ? (json['montant_paye'] as num).toDouble()
          : double.tryParse('${json['montant_paye']}') ?? 0.0,
      statutPaiement: json['statut_paiement']?.toString(),
      table_id: json['table_id'] as int?,
      serveur_nom: json['serveur_nom'] as String?,
      date_commande: json['date_commande'] != null ? DateTime.parse(json['date_commande'] as String) : DateTime.now(),
      produits: parsedProduits,
      notes: json['notes'] as String?,
      adresse: json['adresse'] as String?,
      telephone: json['telephone'] as String?,
    );
  }
}

class CommandeProduit {
  final int id;
  final String nom;
  final int quantite;
  final double prix_unitaire;
  final double total;

  CommandeProduit({
    required this.id,
    required this.nom,
    required this.quantite,
    required this.prix_unitaire,
    required this.total,
  });

  factory CommandeProduit.fromJson(Map<String, dynamic> json) {
    String nom = '';
    if (json['nom'] != null) {
      nom = json['nom'].toString();
    } else if (json['name'] != null) {
      nom = json['name'].toString();
    } else if (json['produit'] != null && json['produit'] is Map) {
      final p = json['produit'] as Map<String, dynamic>;
      if (p['name'] != null) nom = p['name'].toString();
      else if (p['nom'] != null) nom = p['nom'].toString();
    }

    double prixUnitaire = 0.0;
    if (json['prix_unitaire'] != null) {
      if (json['prix_unitaire'] is num) prixUnitaire = (json['prix_unitaire'] as num).toDouble();
      else prixUnitaire = double.tryParse('${json['prix_unitaire']}') ?? 0.0;
    } else if (json['price'] != null) {
      if (json['price'] is num) prixUnitaire = (json['price'] as num).toDouble();
      else prixUnitaire = double.tryParse('${json['price']}') ?? 0.0;
    } else if (json['produit'] != null && json['produit'] is Map) {
      final p = json['produit'] as Map<String, dynamic>;
      if (p['price'] != null) prixUnitaire = (p['price'] is num) ? (p['price'] as num).toDouble() : double.tryParse('${p['price']}') ?? 0.0;
    }

    double totalVal = 0.0;
    if (json['total'] != null) {
      if (json['total'] is num) totalVal = (json['total'] as num).toDouble();
      else totalVal = double.tryParse('${json['total']}') ?? prixUnitaire;
    } else if (json['price'] != null && (json['quantity'] != null || json['quantite'] != null)) {
      final q = (json['quantity'] ?? json['quantite']);
      final qty = (q is int) ? q : (int.tryParse('$q') ?? 1);
      totalVal = prixUnitaire * qty;
    }

    return CommandeProduit(
      id: json['id'] as int,
      nom: nom,
      quantite: json['quantite'] as int? ?? json['quantity'] as int? ?? 1,
      prix_unitaire: prixUnitaire,
      total: totalVal,
    );
  }
}
