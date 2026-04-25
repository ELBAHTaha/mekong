import 'package:flutter/material.dart';
import '../widgets/main_bottom_nav.dart';
 

class LivraisonsScreen extends StatefulWidget {
  const LivraisonsScreen({Key? key}) : super(key: key);

  @override
  State<LivraisonsScreen> createState() => _LivraisonsScreenState();
}

class _LivraisonsScreenState extends State<LivraisonsScreen> {
  // ============ DONNÉES STATIQUES ============
  final List<Livraison> _livraisons = [
    Livraison(
      id: 1001,
      clientNom: 'Jean Dupont',
      adresse: '15 rue de Paris, 75001 Paris',
      telephone: '06 12 34 56 78',
      montant: 32.50,
      statut: 'EN_ATTENTE',
      dateCommande: DateTime.now().subtract(const Duration(minutes: 5)),
      livreurNom: 'Non assigné',
      tempsEstime: 45,
    ),
    Livraison(
      id: 1002,
      clientNom: 'Marie Martin',
      adresse: '8 avenue Victor Hugo, 75016 Paris',
      telephone: '07 98 76 54 32',
      montant: 45.80,
      statut: 'EN_ROUTE',
      dateCommande: DateTime.now().subtract(const Duration(minutes: 15)),
      livreurId: 1,
      livreurNom: 'Thomas Laurent',
      tempsEstime: 12,
      latitudeLivreur: 48.8566,
      longitudeLivreur: 2.3522,
      latitudeClient: 48.8584,
      longitudeClient: 2.2945,
      historique: [
        {'statut': 'EN_ATTENTE', 'date': DateTime.now().subtract(const Duration(minutes: 15))},
        {'statut': 'EN_ROUTE', 'date': DateTime.now().subtract(const Duration(minutes: 8))},
      ],
    ),
    Livraison(
      id: 1003,
      clientNom: 'Sophie Bernard',
      adresse: '22 rue de la Paix, 75002 Paris',
      telephone: '06 45 67 89 01',
      montant: 28.90,
      statut: 'EN_ROUTE',
      dateCommande: DateTime.now().subtract(const Duration(minutes: 25)),
      livreurId: 2,
      livreurNom: 'Marc Dubois',
      tempsEstime: 8,
      latitudeLivreur: 48.8700,
      longitudeLivreur: 2.3300,
      latitudeClient: 48.8650,
      longitudeClient: 2.3400,
      historique: [
        {'statut': 'EN_ATTENTE', 'date': DateTime.now().subtract(const Duration(minutes: 25))},
        {'statut': 'EN_ROUTE', 'date': DateTime.now().subtract(const Duration(minutes: 18))},
      ],
    ),
    Livraison(
      id: 1004,
      clientNom: 'Pierre Durand',
      adresse: '5 boulevard Haussmann, 75009 Paris',
      telephone: '07 23 45 67 89',
      montant: 52.30,
      statut: 'LIVREE',
      dateCommande: DateTime.now().subtract(const Duration(minutes: 45)),
      livreurNom: 'Sophie Petit',
      tempsEstime: 0,
      historique: [
        {'statut': 'EN_ATTENTE', 'date': DateTime.now().subtract(const Duration(minutes: 45))},
        {'statut': 'EN_ROUTE', 'date': DateTime.now().subtract(const Duration(minutes: 38))},
        {'statut': 'LIVREE', 'date': DateTime.now().subtract(const Duration(minutes: 5))},
      ],
    ),
    Livraison(
      id: 1005,
      clientNom: 'Isabelle Moreau',
      adresse: '12 rue de Rivoli, 75004 Paris',
      telephone: '06 56 78 90 12',
      montant: 67.20,
      statut: 'ANNULEE',
      dateCommande: DateTime.now().subtract(const Duration(minutes: 60)),
      livreurNom: 'Non assigné',
      tempsEstime: 0,
      historique: [
        {'statut': 'EN_ATTENTE', 'date': DateTime.now().subtract(const Duration(minutes: 60))},
        {'statut': 'ANNULEE', 'date': DateTime.now().subtract(const Duration(minutes: 30))},
      ],
    ),
  ];

  // ============ ÉTATS ============
  List<Livraison> _filteredLivraisons = [];
  String _selectedStatut = 'TOUS';
  String _searchQuery = '';
  
  
  // ============ RÔLE SIMULÉ ============
  // Admins have view-only rights (no action buttons)
  final bool _isAdmin = false;

  // ============ CONSTANTES ============
  static const Color bg = Color(0xFFF7F7FB);
  static const Color cardBg = Colors.white;
  static const Color accentColor = Color(0xFFD43B3B);
  static const Color successColor = Color(0xFF2ECC71);
  static const Color warningColor = Color(0xFFF39C12);
  static const Color infoColor = Color(0xFF3498DB);
  
  final List<String> _statuts = ['TOUS', 'EN_ATTENTE', 'EN_ROUTE', 'LIVREE', 'ANNULEE'];

  @override
  void initState() {
    super.initState();
    _filteredLivraisons = _livraisons;
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ============ FILTRES ============
  void _applyFilters() {
    setState(() {
      _filteredLivraisons = _livraisons.where((l) {
        // Filtre statut
        if (_selectedStatut != 'TOUS' && l.statut != _selectedStatut) {
          return false;
        }
        
        // Filtre recherche
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final matches = l.clientNom.toLowerCase().contains(query) ||
              l.adresse.toLowerCase().contains(query) ||
              (l.telephone?.contains(query) ?? false) ||
              l.id.toString().contains(query);
          if (!matches) return false;
        }
        
        return true;
      }).toList();
      
      // Tri par date (plus récent d'abord)
      _filteredLivraisons.sort((a, b) => b.dateCommande.compareTo(a.dateCommande));
    });
  }

  // ============ ACTIONS SIMULÉES ============
  void _updateStatut(Livraison livraison, String nouveauStatut) {
    if (!_isAdmin) {
      _showMessage('Seuls les administrateurs peuvent modifier les statuts', isError: true);
      return;
    }

    setState(() {
      final index = _livraisons.indexWhere((l) => l.id == livraison.id);
      if (index != -1) {
        _livraisons[index] = livraison.copyWith(
          statut: nouveauStatut,
          dateModification: DateTime.now(),
        );
        _applyFilters();
      }
    });
    
    _showMessage('Statut mis à jour : $nouveauStatut');
  }

  void _reassignerLivreur(Livraison livraison) {
    if (!_isAdmin) {
      _showMessage('Seuls les administrateurs peuvent réassigner', isError: true);
      return;
    }
    
    // Simulation de dialogue
    _showMessage('Fonctionnalité de réassignation (simulation)');
  }

  void _annulerLivraison(Livraison livraison) {
    if (!_isAdmin) {
      _showMessage('Seuls les administrateurs peuvent annuler', isError: true);
      return;
    }
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        title: const Text('Annuler livraison',
            style: TextStyle(color: Colors.black87)),
        content: Text(
          'Êtes-vous sûr de vouloir annuler la livraison #${livraison.id} ?',
          style: const TextStyle(color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Non', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatut(livraison, 'ANNULEE');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : successColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ============ VUE ============
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _buildListView(),
          ),
        ],
      ),
      floatingActionButton: null,
      bottomNavigationBar: const MainBottomNav(currentIndex: 3),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Livraisons',
            style: TextStyle(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.w700),
          ),
          Text(
            '${_filteredLivraisons.length} livraison${_filteredLivraisons.length > 1 ? 's' : ''}',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
      actions: [
        // Badge admin
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _isAdmin
                ? successColor.withOpacity(0.14)
                : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isAdmin ? successColor : Colors.black45,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _isAdmin ? 'ADMIN' : 'LECTURE',
                style: TextStyle(
                  color: _isAdmin ? successColor : Colors.black45,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Rafraîchir (simulé)
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.black54),
          onPressed: () {
            _applyFilters();
            _showMessage('Données rafraîchies');
          },
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Barre de recherche
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _applyFilters();
              });
            },
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              hintText: 'Rechercher client, adresse, téléphone...',
              hintStyle: const TextStyle(color: Colors.black38),
              prefixIcon: const Icon(Icons.search, color: Colors.black45),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.black45),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _applyFilters();
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: cardBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Filtres par statut
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statuts.map((statut) {
                final isSelected = _selectedStatut == statut;
                final color = _getStatutColor(statut);
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: FilterChip(
                    label: Text(
                      statut,
                      style: TextStyle(
                        color: isSelected ? Colors.black87 : Colors.black54,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedStatut = statut;
                        _applyFilters();
                      });
                    },
                    backgroundColor: Colors.white,
                    selectedColor: color.withOpacity(0.35),
                    showCheckmark: false,
                    side: BorderSide(
                      color: isSelected ? color : Colors.black12,
                      width: isSelected ? 1.6 : 1,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }


  // ============ VUE LISTE ============
  Widget _buildListView() {
    if (_filteredLivraisons.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredLivraisons.length,
      itemBuilder: (context, index) {
        return _buildLivraisonCard(_filteredLivraisons[index]);
      },
    );
  }

  Widget _buildLivraisonCard(Livraison livraison) {
    final color = _getStatutColor(livraison.statut);
    final isUrgente = livraison.tempsEstime != null && 
        livraison.tempsEstime! < 15;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUrgente && livraison.statut == 'EN_ROUTE' 
              ? accentColor.withOpacity(0.5) 
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showLivraisonDetails(livraison),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getStatutIcon(livraison.statut),
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
                                '#${livraison.id}',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  livraison.statut,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            livraison.clientNom,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${livraison.montant.toStringAsFixed(2)} MAD',
                          style: TextStyle(
                            color: color,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (livraison.tempsEstime != null && livraison.statut == 'EN_ROUTE') ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: livraison.tempsEstime! < 15
                                  ? accentColor.withOpacity(0.2)
                                  : Colors.black.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${livraison.tempsEstime} min',
                              style: TextStyle(
                                color: livraison.tempsEstime! < 15
                                    ? accentColor
                                    : Colors.black54,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Adresse
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.black38),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        livraison.adresse,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Téléphone
                if (livraison.telephone != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 14, color: Colors.black38),
                      const SizedBox(width: 8),
                      Text(
                        livraison.telephone!,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
                
                // Livreur
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: livraison.livreurNom != 'Non assigné'
                            ? successColor.withOpacity(0.1)
                            : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 12,
                            color: livraison.livreurNom != 'Non assigné'
                                ? successColor
                                : Colors.black38,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            livraison.livreurNom ?? 'Non assigné',
                            style: TextStyle(
                              color: livraison.livreurNom != 'Non assigné'
                                  ? successColor
                                  : Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (livraison.livreurId != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: infoColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.gps_fixed,
                              size: 12,
                              color: infoColor,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'GPS actif',
                              style: TextStyle(
                                color: infoColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                
                // Admin actions removed: admins have view-only rights per requirements.
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
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


  // ============ DÉTAILS LIVRAISON ============
  void _showLivraisonDetails(Livraison livraison) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: bg,
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
                
                // Contenu
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // En-tête
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _getStatutColor(livraison.statut).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              _getStatutIcon(livraison.statut),
                              color: _getStatutColor(livraison.statut),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Livraison #${livraison.id}',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatutColor(livraison.statut).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    livraison.statut,
                                    style: TextStyle(
                                      color: _getStatutColor(livraison.statut),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      const Divider(color: Colors.black12),
                      const SizedBox(height: 16),
                      
                      // Informations client
                      const Text(
                        'CLIENT',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      _buildDetailRow(
                        Icons.person_outline,
                        'Nom',
                        livraison.clientNom,
                      ),
                      _buildDetailRow(
                        Icons.location_on_outlined,
                        'Adresse',
                        livraison.adresse,
                      ),
                      if (livraison.telephone != null)
                        _buildDetailRow(
                          Icons.phone_outlined,
                          'Téléphone',
                          livraison.telephone!,
                        ),
                      
                      const SizedBox(height: 16),
                      const Divider(color: Colors.black12),
                      const SizedBox(height: 16),
                      
                      // Informations commande
                      const Text(
                        'COMMANDE',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      _buildDetailRow(
                        Icons.receipt_outlined,
                        'Montant',
                        '${livraison.montant.toStringAsFixed(2)} MAD',
                      ),
                      _buildDetailRow(
                        Icons.calendar_today,
                        'Date',
                        _formatDate(livraison.dateCommande),
                      ),
                      if (livraison.tempsEstime != null && livraison.statut == 'EN_ROUTE')
                        _buildDetailRow(
                          Icons.timer_outlined,
                          'Temps estimé',
                          '${livraison.tempsEstime} min',
                        ),
                      
                      const SizedBox(height: 16),
                      const Divider(color: Colors.black12),
                      const SizedBox(height: 16),
                      
                      // Informations livreur
                      const Text(
                        'LIVREUR',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      _buildDetailRow(
                        Icons.person_outline,
                        'Nom',
                        livraison.livreurNom ?? 'Non assigné',
                      ),
                      if (livraison.livreurId != null)
                        _buildDetailRow(
                          Icons.gps_fixed,
                          'Position',
                          '48.8566, 2.3522 (simulé)',
                        ),
                      
                      const SizedBox(height: 16),
                      const Divider(color: Colors.black12),
                      const SizedBox(height: 16),
                      
                      // Historique
                      const Text(
                        'HISTORIQUE',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (livraison.historique != null && livraison.historique!.isNotEmpty)
                        ...livraison.historique!.map((event) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 6),
                                decoration: BoxDecoration(
                                  color: _getStatutColor(event['statut']),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event['statut'],
                                      style: TextStyle(
                                        color: _getStatutColor(event['statut']),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      _formatDateTime(event['date']),
                                      style: const TextStyle(
                                        color: Colors.black38,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ))
                      else
                        const Text(
                          'Aucun historique',
                          style: TextStyle(color: Colors.black38, fontSize: 13),
                        ),
                      
                      const SizedBox(height: 32),
                      
                      // Actions admin
                      if (_isAdmin && livraison.statut != 'LIVREE' && livraison.statut != 'ANNULEE') ...[
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final double halfWidth = (constraints.maxWidth - 12) / 2;
                            final bool canSplit = halfWidth >= 160;
                            final double buttonWidth = canSplit ? halfWidth : constraints.maxWidth;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: buttonWidth,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _reassignerLivreur(livraison);
                                    },
                                    icon: const Icon(Icons.swap_horiz, size: 18),
                                    label: const Text('Réassigner'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: infoColor,
                                      side: const BorderSide(color: infoColor),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: buttonWidth,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _annulerLivraison(livraison);
                                    },
                                    icon: const Icon(Icons.cancel, size: 18),
                                    label: const Text('Annuler'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        if (livraison.statut == 'EN_ATTENTE')
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _updateStatut(livraison, 'EN_ROUTE');
                              },
                              icon: const Icon(Icons.play_arrow, size: 18),
                              label: const Text('Démarrer la livraison'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: successColor,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        if (livraison.statut == 'EN_ROUTE')
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _updateStatut(livraison, 'LIVREE');
                              },
                              icon: const Icon(Icons.check_circle, size: 18),
                              label: const Text('Marquer comme livrée'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: successColor,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                      ],
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.black38),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87, fontSize: 13),
            ),
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
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delivery_dining,
              size: 60,
              color: Colors.black12,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aucune livraison',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Les livraisons apparaîtront ici',
            style: TextStyle(color: Colors.black54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ============ UTILITAIRES ============
  Color _getStatutColor(String statut) {
    switch (statut) {
      case 'EN_ATTENTE': return warningColor;
      case 'EN_ROUTE': return infoColor;
      case 'LIVREE': return successColor;
      case 'ANNULEE': return Colors.redAccent;
      default: return Colors.grey;
    }
  }

  IconData _getStatutIcon(String statut) {
    switch (statut) {
      case 'EN_ATTENTE': return Icons.hourglass_empty;
      case 'EN_ROUTE': return Icons.delivery_dining;
      case 'LIVREE': return Icons.check_circle;
      case 'ANNULEE': return Icons.cancel;
      default: return Icons.help_outline;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatHeure(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} à ${_formatHeure(date)}';
  }
}

// ============ MODÈLE STATIQUE ============
class Livraison {
  final int id;
  final String clientNom;
  final String adresse;
  final String? telephone;
  final double montant;
  final String statut;
  final DateTime dateCommande;
  final DateTime? dateModification;
  final int? livreurId;
  final String? livreurNom;
  final int? tempsEstime;
  final double? latitudeLivreur;
  final double? longitudeLivreur;
  final double? latitudeClient;
  final double? longitudeClient;
  final List<Map<String, dynamic>>? historique;

  Livraison({
    required this.id,
    required this.clientNom,
    required this.adresse,
    this.telephone,
    required this.montant,
    required this.statut,
    required this.dateCommande,
    this.dateModification,
    this.livreurId,
    this.livreurNom,
    this.tempsEstime,
    this.latitudeLivreur,
    this.longitudeLivreur,
    this.latitudeClient,
    this.longitudeClient,
    this.historique,
  });

  Livraison copyWith({
    int? id,
    String? clientNom,
    String? adresse,
    String? telephone,
    double? montant,
    String? statut,
    DateTime? dateCommande,
    DateTime? dateModification,
    int? livreurId,
    String? livreurNom,
    int? tempsEstime,
    double? latitudeLivreur,
    double? longitudeLivreur,
    double? latitudeClient,
    double? longitudeClient,
    List<Map<String, dynamic>>? historique,
  }) {
    return Livraison(
      id: id ?? this.id,
      clientNom: clientNom ?? this.clientNom,
      adresse: adresse ?? this.adresse,
      telephone: telephone ?? this.telephone,
      montant: montant ?? this.montant,
      statut: statut ?? this.statut,
      dateCommande: dateCommande ?? this.dateCommande,
      dateModification: dateModification ?? this.dateModification,
      livreurId: livreurId ?? this.livreurId,
      livreurNom: livreurNom ?? this.livreurNom,
      tempsEstime: tempsEstime ?? this.tempsEstime,
      latitudeLivreur: latitudeLivreur ?? this.latitudeLivreur,
      longitudeLivreur: longitudeLivreur ?? this.longitudeLivreur,
      latitudeClient: latitudeClient ?? this.latitudeClient,
      longitudeClient: longitudeClient ?? this.longitudeClient,
      historique: historique ?? this.historique,
    );
  }
}
