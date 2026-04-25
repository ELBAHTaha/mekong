import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../models/dashboard.dart';
import '../widgets/main_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  User? _user;
  DashboardData? _dashboard;
  bool _loading = false;
  final _api = ApiService();
  String? _token;
  // Monthly sales state
  int _currentYear = DateTime.now().year;
  int _currentMonth = DateTime.now().month;
  List<MonthDaySale> _ventesParMois = [];
  bool _loadingMois = false;

  // Animation controllers for staggered entrance
  bool _showMetrics = false;
  bool _showActions = false;
  bool _showOrders = false;
  bool _showChart = false;

  // Déplacer les constantes de couleur au niveau de la classe
  static const Color bg = Color(0xFFF7F7FB);
  static const Color cardBg = Colors.white;
  static const Color accentColor = Color(0xFFFF7A18);
  static const Color successColor = Color(0xFF2ECC71);
  static const Color warningColor = Color(0xFFF39C12);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = ModalRoute.of(context)!.settings.arguments as String?;
    if (_token == null) {
      _token = token;
      if (_token != null) {
        _loadAll(_token!);
      } else {
        _loadTokenFromPrefs();
      }
    }
  }

  Color _statutColor(String statut) {
    final s = (statut ?? '').toString().toUpperCase();
    if (s.contains('ANNU')) return Colors.redAccent;
    if (s.contains('LIVREE') || s.contains('TERM'))
      return const Color(0xFF3498DB);
    if (s.contains('LIVRAISON') || s.contains('PRETE')) return successColor;
    return warningColor;
  }

  Future<void> _loadTokenFromPrefs() async {
    try {
      final t = await _api.getStoredToken();
      if (t != null && t.isNotEmpty) {
        setState(() => _token = t);
        _loadAll(t);
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    // Staggered entrance animations
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _showMetrics = true);
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showActions = true);
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showOrders = true);
    });
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _showChart = true);
    });
  }

  Future<void> _loadAll(String token) async {
    setState(() => _loading = true);
    try {
      final user = await _api.fetchUser(token);
      final dash = await _api.fetchDashboard(token);
      setState(() {
        _user = user;
        _dashboard = dash;
      });
      await _loadMonthData(_currentYear, _currentMonth);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de chargement: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.96),
                bg,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: Text(
              _user?.name?.substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bonjour,',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
            Text(
              _user?.name?.split(' ').first ?? 'Utilisateur',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.notifications_outlined,
                        color: Colors.black54),
                    onPressed: () {},
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: accentColor,
                strokeWidth: 2.5,
              ),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date and Summary
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getCurrentDate(),
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: successColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: successColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Performance: ${_getPerformanceIndicator()}',
                            style: TextStyle(
                              color: successColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Metrics Grid
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 500),
                    opacity: _showMetrics ? 1.0 : 0.0,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 500),
                      offset: _showMetrics ? Offset.zero : const Offset(0, 0.2),
                      child: GridView.count(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        // childAspectRatio = width / height. Higher => shorter cards.
                        childAspectRatio: 1.35,
                        children: [
                          _buildMetricCard(
                            icon: Icons.trending_up_rounded,
                            title: 'Ventes du Jour',
                            value:
                                'MAD ${_dashboard?.ventesDuJour.toStringAsFixed(0) ?? "0"}',
                            color: successColor,
                            trend: '+12%',
                          ),
                          _buildMetricCard(
                            icon: Icons.attach_money_rounded,
                            title: 'Revenus Totaux',
                            value:
                                'MAD ${_dashboard?.commandesMontant.toStringAsFixed(0) ?? "0"}',
                            color: accentColor,
                            trend: '+8%',
                          ),
                          _buildMetricCard(
                            icon: Icons.shopping_bag_rounded,
                            title: 'Commandes (aujourd\'hui)',
                            value: '${_dashboard?.totalCommandesDuJour ?? 0}',
                            color: const Color(0xFF3498DB),
                            trend: 'Actives',
                          ),
                          _buildMetricCard(
                            icon: Icons.delivery_dining_rounded,
                            title: 'Livraisons (aujourd\'hui)',
                            value: '${_dashboard?.livraisonCountDuJour ?? 0}',
                            color: warningColor,
                            trend: 'En cours',
                            onTap: () {
                              try {
                                Navigator.of(context).pushNamed('/deliveries');
                              } catch (_) {}
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Quick Actions Section
                  const Text(
                    'Actions Rapides',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 500),
                    opacity: _showActions ? 1.0 : 0.0,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 500),
                      offset: _showActions ? Offset.zero : const Offset(0, 0.2),
                      child: GridView.count(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.25,
                        children: [
                          _buildActionCard(
                            icon: Icons.shopping_bag_rounded,
                            title: 'Produits',
                            color: accentColor,
                            route: '/products',
                          ),
                          _buildActionCard(
                            icon: Icons.group_rounded,
                            title: 'Utilisateurs',
                            color: const Color(0xFF3498DB),
                            route: '/users',
                          ),
                          _buildActionCard(
                            icon: Icons.receipt_long_rounded,
                            title: 'Charges',
                            color: warningColor,
                            route: '/charges',
                          ),
                          _buildActionCard(
                            icon: Icons.table_bar_rounded,
                            title: 'Tables',
                            color: const Color(0xFF9B59B6),
                            route: '/tables',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Recent Orders Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Commandes Récentes',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed('/orders');
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                        ),
                        child: const Row(
                          children: [
                            Text(
                              'Voir tout',
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: accentColor,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 500),
                    opacity: _showOrders ? 1.0 : 0.0,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 500),
                      offset: _showOrders ? Offset.zero : const Offset(0, 0.2),
                      child: Column(
                        children: [
                          if ((_dashboard?.commandesRecent ?? []).isEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: const Center(
                                child: Text(
                                  'Aucune commande récente',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ),
                            )
                          else ...[
                            for (var o in (_dashboard?.commandesRecent ?? [])
                                .take(3)) ...[
                              _buildOrderItem(
                                orderId: '#${o.id}',
                                customer: o.displayTitle,
                                amount: o.total,
                                status: o.statut,
                                statusColor: _statutColor(o.statut),
                                time: () {
                                  try {
                                    final dt = DateTime.parse(o.date).toLocal();
                                    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                                  } catch (_) {
                                    return o.date;
                                  }
                                }(),
                              ),
                              const SizedBox(height: 12),
                            ]
                          ]
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Ventes Mensuelles
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ventes Mensuelles',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => _prevMonth(),
                            icon:
                                const Icon(Icons.chevron_left, color: Colors.black54),
                          ),
                          Text(
                            _getMonthLabel(_currentYear, _currentMonth),
                            style: const TextStyle(color: Colors.black54),
                          ),
                          IconButton(
                            onPressed: () => _nextMonth(),
                            icon: const Icon(Icons.chevron_right, color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: _showChart ? 1.0 : 0.0,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 400),
                      offset: _showChart ? Offset.zero : const Offset(0, 0.1),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: _loadingMois
                            ? SizedBox(
                                height: 120,
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: accentColor)))
                            : Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildMonthStatCard(
                                          'Total',
                                          'MAD ${_getTotalVentesMois().toStringAsFixed(2)}',
                                          const Color(0xFF2ECC71),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildMonthStatCard(
                                          'Moyenne/j',
                                          'MAD ${_getMoyenneVentesJour().toStringAsFixed(2)}',
                                          accentColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildMonthStatCard(
                                          'Meilleur jour',
                                          _getBestDay(),
                                          Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if ((_ventesParMois ?? []).isNotEmpty)
                                    SizedBox(
                                      height: 160,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: _ventesParMois.length,
                                        itemBuilder: (context, idx) {
                                          final item = _ventesParMois[idx];
                                          final maxVal = (_ventesParMois
                                              .map((e) => e.total)
                                              .fold<double>(0.0,
                                                  (p, n) => p > n ? p : n));
                                          final width = maxVal == 0
                                              ? 40.0
                                              : (item.total / maxVal) * 120.0 +
                                                  40.0;
                                          return Container(
                                            width: 56,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 6),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                Container(
                                                  height: 100,
                                                  alignment:
                                                      Alignment.bottomCenter,
                                                  child: Container(
                                                    width: 14,
                                                    height: (item.total == 0 ||
                                                            maxVal == 0)
                                                        ? 4
                                                        : (item.total /
                                                                maxVal) *
                                                            100,
                                                    decoration: BoxDecoration(
                                                      color: accentColor,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text('${item.day}',
                                                    style: const TextStyle(
                                                        color: Colors.black54)),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      child: const Center(
                                          child: Text(
                                              'Aucune donnée pour ce mois',
                                              style: TextStyle(
                                                  color: Colors.black54))),
                                    ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
      bottomNavigationBar: const MainBottomNav(currentIndex: 0),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required String trend,
    VoidCallback? onTap,
  }) {
    final child = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color:
            cardBg, // Maintenant accessible car c'est une constante de classe
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 12,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          // Prevent grid cell overflow on small widths / with persistent bottom nav.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: child,
        ),
      );
    }
    return child;
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required String route,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          try {
            Navigator.of(context).pushNamed(route);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Route $route non disponible'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool tight =
                constraints.maxHeight < 90 || constraints.maxWidth < 140;
            final double pad = tight ? 5 : 7;
            final double iconPad = tight ? 3 : 5;
            final double iconSize = tight ? 12 : 14;
            final double gap = tight ? 3 : 5;
            final double fontSize = tight ? 10 : 12;
            return Container(
              padding: EdgeInsets.all(pad),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(iconPad),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: iconSize,
                      ),
                    ),
                    SizedBox(height: gap),
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderItem({
    required String orderId,
    required String customer,
    required double amount,
    required String status,
    required Color statusColor,
    required String time,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                orderId.substring(1),
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'MAD ${amount.toStringAsFixed(2)}',
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Bottom navigation is now shared across main pages (see `MainBottomNav`).

  Future<void> _loadMonthData(int year, int month) async {
    if (_token == null) return;
    setState(() => _loadingMois = true);
    try {
      final data = await _api.fetchVentesParMois(_token!, year, month);
      setState(() {
        _ventesParMois = data;
      });
    } catch (e) {
      // ignore errors silently for now
    }
    setState(() => _loadingMois = false);
  }

  void _prevMonth() {
    setState(() {
      if (_currentMonth == 1) {
        _currentMonth = 12;
        _currentYear -= 1;
      } else {
        _currentMonth -= 1;
      }
    });
    _loadMonthData(_currentYear, _currentMonth);
  }

  void _nextMonth() {
    setState(() {
      if (_currentMonth == 12) {
        _currentMonth = 1;
        _currentYear += 1;
      } else {
        _currentMonth += 1;
      }
    });
    _loadMonthData(_currentYear, _currentMonth);
  }

  String _getMonthLabel(int year, int month) {
    const months = [
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Août',
      'Sep',
      'Oct',
      'Nov',
      'Déc'
    ];
    return '${months[month - 1]} $year';
  }

  double _getTotalVentesMois() {
    return _ventesParMois.fold<double>(0.0, (p, e) => p + (e.total));
  }

  double _getMoyenneVentesJour() {
    if (_ventesParMois.isEmpty) return 0.0;
    return _getTotalVentesMois() / _ventesParMois.length;
  }

  String _getBestDay() {
    if (_ventesParMois.isEmpty) return '—';
    final best = _ventesParMois.reduce((a, b) => a.total >= b.total ? a : b);
    return '${best.day} (${best.total.toStringAsFixed(0)} MAD)';
  }

  Widget _buildMonthStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final months = [
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Août',
      'Sep',
      'Oct',
      'Nov',
      'Déc'
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  String _getPerformanceIndicator() {
    final sales = _dashboard?.ventesDuJour ?? 0;
    if (sales > 1000) return 'Excellent';
    if (sales > 500) return 'Bon';
    if (sales > 100) return 'Moyen';
    return 'Bas';
  }
}

class _SalesChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final List<String> labels;
  _SalesChartPainter({required this.dataPoints, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2ECC71)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF2ECC71).withOpacity(0.3),
          const Color(0xFF2ECC71).withOpacity(0.05),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final points = dataPoints;
    final maxValue =
        (points.isEmpty) ? 1.0 : points.reduce((a, b) => a > b ? a : b);

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final x =
          (i / (points.length - 1).clamp(1, double.infinity)) * size.width;
      final y = size.height -
          (points[i] / (maxValue == 0 ? 1 : maxValue)) * size.height * 0.8;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final prevX = ((i - 1) / (points.length - 1)) * size.width;
        final prevY = size.height -
            (points[i - 1] / (maxValue == 0 ? 1 : maxValue)) *
                size.height *
                0.8;
        final controlX1 = prevX + (x - prevX) * 0.3;
        final controlX2 = x - (x - prevX) * 0.3;
        path.cubicTo(controlX1, prevY, controlX2, y, x, y);
        fillPath.cubicTo(controlX1, prevY, controlX2, y, x, y);
      }

      if (i == points.length - 1) {
        final pointPaint = Paint()
          ..color = const Color(0xFF2ECC71)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), 4, pointPaint);
        canvas.drawCircle(Offset(x, y), 8,
            pointPaint..color = const Color(0xFF2ECC71).withOpacity(0.3));
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;
    for (int i = 1; i <= 4; i++) {
      final y = size.height * (i / 5);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final textStyle = TextStyle(color: Colors.white70, fontSize: 10);
    for (int i = 0; i < labels.length; i++) {
      final x = (i / (labels.length - 1)) * size.width;
      final paragraph = TextPainter(
          text: TextSpan(text: labels[i], style: textStyle),
          textDirection: TextDirection.ltr)
        ..layout();
      paragraph.paint(canvas, Offset(x - paragraph.width / 2, size.height + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _SalesChartPainter oldDelegate) =>
      oldDelegate.dataPoints != dataPoints || oldDelegate.labels != labels;
}
