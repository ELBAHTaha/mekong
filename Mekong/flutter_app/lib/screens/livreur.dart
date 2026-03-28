import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class LivreurScreen extends StatefulWidget {
  const LivreurScreen({Key? key}) : super(key: key);

  @override
  State<LivreurScreen> createState() => _LivreurScreenState();
}

class _LivreurScreenState extends State<LivreurScreen> {
  final ApiService _api = ApiService();
  bool _loading = false;
  String _filter = 'A_PRENDRE'; // A_PRENDRE | EN_COURS | LIVREE
  List<DeliveryOrder> _orders = [];
  User? _me;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadUser();
    await _loadOrders();
  }

  Future<void> _loadUser() async {
    try {
      final user = await _api.fetchUser('basic');
      if (!mounted) return;
      setState(() => _me = user);
    } catch (_) {}
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      List<dynamic> list = await _api.fetchCommandes(type: 'LIVRAISON');
      List<DeliveryOrder> parsed = list
          .map((e) => DeliveryOrder.fromJson(e as Map<String, dynamic>))
          .where((o) => _isLivraisonType(o.type))
          .toList();

      // Fallback in case backend stores a different casing or key name.
      if (parsed.isEmpty) {
        list = await _api.fetchCommandes();
        parsed = list
            .map((e) => DeliveryOrder.fromJson(e as Map<String, dynamic>))
            .where((o) => _isLivraisonType(o.type))
            .toList();
      }
      if (parsed.isEmpty) {
        list = await _api.fetchCommandes(includeServeur: true);
        parsed = list
            .map((e) => DeliveryOrder.fromJson(e as Map<String, dynamic>))
            .where((o) => _isLivraisonType(o.type))
            .toList();
      }
      setState(() => _orders = parsed);
    } catch (e) {
      _showMessage('Erreur de chargement: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isLivraisonType(String raw) {
    final u = raw.trim().toUpperCase();
    return u.contains('LIVRAISON') || u.contains('LIVRAIS') || u == 'DELIVERY';
  }

  List<DeliveryOrder> get _filtered {
    if (_filter == 'EN_COURS') {
      return _orders
          .where((o) => o.statut == 'LIVRAISON' || o.statut == 'EN_ROUTE')
          .where((o) => _me == null || o.livreurId == null || o.livreurId == _me!.id)
          .toList();
    }
    if (_filter == 'LIVREE') {
      return _orders
          .where((o) => o.statut == 'LIVREE')
          .where((o) => _me == null || o.livreurId == null || o.livreurId == _me!.id)
          .toList();
    }
    // A prendre
    return _orders
        .where((o) =>
            o.statut == 'PRETE' ||
            o.statut == 'NOUVELLE' ||
            o.statut == 'PREPARATION' ||
            o.statut == 'EN_ATTENTE')
        .where((o) => o.livreurId == null || o.livreurId == 0)
        .toList();
  }

  Future<void> _callPhone(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      _showMessage('Numéro indisponible', isError: true);
      return;
    }
    final uri = Uri.parse('tel:${phone.trim()}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      _showMessage('Impossible d’ouvrir l’appel', isError: true);
    }
  }

  Future<void> _takeOrder(DeliveryOrder order) async {
    try {
      final payload = <String, dynamic>{
        'statut': 'LIVRAISON',
        if (_me != null) 'livreur_id': _me!.id,
      };
      await _api.updateCommande(order.id, payload);
      if (!mounted) return;
      setState(() {
        _orders = _orders.map((o) {
          if (o.id == order.id) {
            return o.copyWith(statut: 'LIVRAISON', livreurId: _me?.id);
          }
          return o;
        }).toList();
      });
      _showMessage('Commande prise');
    } catch (e) {
      _showMessage('Échec: $e', isError: true);
    }
  }

  Future<void> _markDelivered(DeliveryOrder order) async {
    try {
      final payload = <String, dynamic>{
        'statut': 'LIVREE',
        if (_me != null) 'livreur_id': _me!.id,
      };
      await _api.updateCommande(order.id, payload);
      if (!mounted) return;
      setState(() {
        _orders = _orders.map((o) {
          if (o.id == order.id) {
            return o.copyWith(statut: 'LIVREE', livreurId: _me?.id);
          }
          return o;
        }).toList();
      });
      _showMessage('Livraison terminée');
    } catch (e) {
      _showMessage('Échec: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF2ECC71),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1113),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Livraisons',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadOrders,
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFD43B3B)),
                    )
                  : _buildList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D20),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Compte',
            icon: const Icon(Icons.account_circle, color: Colors.white70, size: 26),
            onPressed: () => Navigator.of(context).pushNamed('/profile'),
          ),
          IconButton(
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout, color: Colors.redAccent, size: 24),
            onPressed: _logout,
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_email');
    await prefs.remove('auth_password');
    await prefs.remove('auth_role');
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip('À prendre', 'A_PRENDRE'),
            const SizedBox(width: 8),
            _chip('En cours', 'EN_COURS'),
            const SizedBox(width: 8),
            _chip('Livrée', 'LIVREE'),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    final bool selected = _filter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      backgroundColor: const Color(0xFF23262B),
      selectedColor: const Color(0xFFD43B3B),
      side: BorderSide(
        color: selected ? const Color(0xFFD43B3B) : Colors.white30,
        width: selected ? 1.6 : 1,
      ),
    );
  }

  Widget _buildList() {
    final items = _filtered;
    if (items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(
            child: Text(
              'Aucune livraison disponible',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildCard(items[index]);
      },
    );
  }

  Widget _buildCard(DeliveryOrder order) {
    final color = order.statut == 'LIVRAISON'
        ? const Color(0xFF3498DB)
        : order.statut == 'LIVREE'
            ? const Color(0xFF2ECC71)
            : const Color(0xFFF39C12);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  order.statutLabel,
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              Text(
                '#${order.id}',
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (order.adresse.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, color: Colors.white54, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.adresse,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          if (order.telephone.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, color: Colors.white54, size: 16),
                const SizedBox(width: 6),
                Text(
                  order.telephone,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callPhone(order.telephone),
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text('Appeler'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: order.statut == 'LIVREE'
                      ? null
                      : (order.statut == 'LIVRAISON'
                          ? () => _markDelivered(order)
                          : () => _takeOrder(order)),
                  icon: Icon(
                    order.statut == 'LIVRAISON' ? Icons.check_circle : Icons.play_arrow,
                    size: 18,
                  ),
                  label: Text(order.statut == 'LIVRAISON' ? 'Livrée' : 'Prendre'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: order.statut == 'LIVRAISON'
                        ? const Color(0xFF2ECC71)
                        : const Color(0xFFD43B3B),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DeliveryOrder {
  DeliveryOrder({
    required this.id,
    required this.clientNom,
    required this.adresse,
    required this.telephone,
    required this.statut,
    required this.type,
    this.livreurId,
    this.caissierId,
  });

  final int id;
  final String clientNom;
  final String adresse;
  final String telephone;
  final String statut;
  final String type;
  final int? livreurId;
  final int? caissierId;

  String get statutLabel {
    switch (statut) {
      case 'LIVRAISON':
        return 'EN COURS';
      case 'PRETE':
        return 'À PRENDRE';
      case 'NOUVELLE':
        return 'NOUVELLE';
      case 'LIVREE':
        return 'LIVRÉE';
      default:
        return statut;
    }
  }

  DeliveryOrder copyWith({String? statut, int? livreurId}) {
    return DeliveryOrder(
      id: id,
      clientNom: clientNom,
      adresse: adresse,
      telephone: telephone,
      statut: statut ?? this.statut,
      type: type,
      livreurId: livreurId ?? this.livreurId,
      caissierId: caissierId,
    );
  }

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    return DeliveryOrder(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      clientNom: (json['client_nom'] ?? json['clientNom'] ?? '') as String,
      adresse: (json['adresse'] ??
              json['address'] ??
              json['adresse_client'] ??
              '') as String? ??
          '',
      telephone: (json['telephone'] ??
              json['tel'] ??
              json['telephone_client'] ??
              '') as String? ??
          '',
      statut: ((json['statut'] ?? '') as String).toUpperCase(),
      type: ((json['type'] ?? json['type_commande'] ?? '') as String).toUpperCase(),
      livreurId: json['livreur_id'] is int
          ? json['livreur_id'] as int
          : int.tryParse('${json['livreur_id']}'),
      caissierId: json['caissier_id'] is int
          ? json['caissier_id'] as int
          : int.tryParse('${json['caissier_id']}'),
    );
  }
}
