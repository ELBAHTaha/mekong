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
  factory DashboardData.fromJson(Map<String, dynamic> j) => DashboardData(
    ventesDuJour: (j['ventes_du_jour'] as num).toDouble(),
    commandesMontant: (j['commandes_montant'] as num).toDouble(),
    depensesDuJour: (j['depenses_du_jour'] as num).toDouble(),
    commandesEnCours: j['commandes_en_cours'] as int,
    livraisonsActives: j['livraisons_actives'] as int,
    livraisonCountDuJour: (j['livraison_count_du_jour'] as int?) ?? 0,
    totalCommandesDuJour: (j['total_commandes_du_jour'] as int?) ?? 0,
    graphVentes: ((j['graph_ventes'] as List?) ?? []).map((e) => SalesPoint.fromJson(e as Map<String, dynamic>)).toList(),
    ventesParJourSemaine: ((j['ventes_par_jour_semaine'] as List?) ?? []).map((e) => WeekDaySale.fromJson(e as Map<String, dynamic>)).toList(),
    ventesParJourMois: ((j['ventes_par_jour_mois'] as List?) ?? []).map((e) => MonthDaySale.fromJson(e as Map<String, dynamic>)).toList(),
    commandesRecent: ((j['commandes_recent'] as List?) ?? []).map((e) => RecentOrder.fromJson(e as Map<String, dynamic>)).toList(),
  );
}
