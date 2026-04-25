class SalesPoint {
  final String date;
  final double total;
  SalesPoint({required this.date, required this.total});
  factory SalesPoint.fromJson(Map<String, dynamic> j) => SalesPoint(
    date: j['date'] as String,
    total: (j['total'] as num).toDouble(),
  );
}

class RecentOrder {
  final int id;
  final String? clientNom;
  /// SUR_PLACE, LIVRAISON, or `serveur` for legacy commande_serveur rows.
  final String? type;
  final String statut;
  final double total;
  final String date;

  RecentOrder({
    required this.id,
    this.clientNom,
    this.type,
    required this.statut,
    required this.total,
    required this.date,
  });

  /// Shown in dashboard list when [clientNom] is empty (typical for POS / sur place).
  String get displayTitle {
    final n = clientNom?.trim();
    if (n != null && n.isNotEmpty) return n;
    final t = (type ?? '').toUpperCase();
    if (t == 'LIVRAISON') return 'Livraison';
    if (t == 'SUR_PLACE') return 'Sur place';
    if (t == 'SERVEUR') return 'Commande serveur';
    return 'Commande #$id';
  }

  factory RecentOrder.fromJson(Map<String, dynamic> j) => RecentOrder(
        id: () {
          final v = j['id'];
          if (v is int) return v;
          if (v is num) return v.toInt();
          return int.tryParse('$v') ?? 0;
        }(),
        clientNom: j['client_nom'] as String?,
        type: j['type'] as String?,
        statut: (j['statut'] ?? '').toString(),
        total: (() {
          final t = j['total'];
          if (t is num) return t.toDouble();
          if (t is String) return double.tryParse(t) ?? 0.0;
          return 0.0;
        })(),
        date: (j['date_commande'] ?? '').toString(),
      );
}

class WeekDaySale {
  final String jour;
  final String date;
  final double total;
  WeekDaySale({required this.jour, required this.date, required this.total});
  factory WeekDaySale.fromJson(Map<String, dynamic> j) => WeekDaySale(
    jour: j['jour'] as String,
    date: j['date'] as String,
    total: (j['total'] as num).toDouble(),
  );
}

class MonthDaySale {
  final int day;
  final String date;
  final double total;
  MonthDaySale({required this.day, required this.date, required this.total});
  factory MonthDaySale.fromJson(Map<String, dynamic> j) => MonthDaySale(
    day: j['day'] is int ? j['day'] as int : DateTime.parse(j['date'] as String).day,
    date: j['date'] as String,
    total: (j['total'] as num).toDouble(),
  );
}

class DashboardData {
  final double ventesDuJour;
  final double commandesMontant;
  final double depensesDuJour;
  final int commandesEnCours;
  final int livraisonsActives;
  final int livraisonCountDuJour;
  final int totalCommandesDuJour;
  final List<SalesPoint> graphVentes;
  final List<RecentOrder> commandesRecent;
  final List<WeekDaySale> ventesParJourSemaine;
  final List<MonthDaySale> ventesParJourMois;
  DashboardData({
    required this.ventesDuJour,
    required this.commandesMontant,
    required this.depensesDuJour,
    required this.commandesEnCours,
    required this.livraisonsActives,
    required this.livraisonCountDuJour,
    required this.totalCommandesDuJour,
    required this.graphVentes,
    required this.commandesRecent,
    required this.ventesParJourSemaine,
    this.ventesParJourMois = const [],
  });
  factory DashboardData.fromJson(Map<String, dynamic> j) {
    List<dynamic> _asList(dynamic v) {
      if (v == null) return const [];
      if (v is List) return v;
      if (v is Map && v['data'] is List) return v['data'] as List;
      return const [];
    }

    num _asNum(dynamic v) {
      if (v is num) return v;
      if (v is String) return num.tryParse(v.replaceAll(',', '.')) ?? 0;
      return 0;
    }

    int _asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    final recentRaw = j['commandes_recent'] ??
        j['commandes_recents'] ??
        j['commandes_recentes'] ??
        j['recent_commandes'] ??
        j['recent_orders'];

    return DashboardData(
      ventesDuJour: _asNum(j['ventes_du_jour']).toDouble(),
      commandesMontant: _asNum(j['commandes_montant']).toDouble(),
      depensesDuJour: _asNum(j['depenses_du_jour']).toDouble(),
      commandesEnCours: _asInt(j['commandes_en_cours']),
      livraisonsActives: _asInt(j['livraisons_actives']),
      livraisonCountDuJour: _asInt(j['livraison_count_du_jour']),
      totalCommandesDuJour: _asInt(j['total_commandes_du_jour']),
      graphVentes: _asList(j['graph_ventes'])
          .map((e) => SalesPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      ventesParJourSemaine: _asList(j['ventes_par_jour_semaine'])
          .map((e) => WeekDaySale.fromJson(e as Map<String, dynamic>))
          .toList(),
      ventesParJourMois: _asList(j['ventes_par_jour_mois'])
          .map((e) => MonthDaySale.fromJson(e as Map<String, dynamic>))
          .toList(),
      commandesRecent: _asList(recentRaw)
          .map((e) => RecentOrder.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
