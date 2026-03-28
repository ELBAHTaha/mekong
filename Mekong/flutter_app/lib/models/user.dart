class User {
  final int id;
  final int? numeroId;
  final String name;
  final String email;
  final String? telephone;
  final String? role;

  User({required this.id, this.numeroId, required this.name, required this.email, this.telephone, this.role});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      numeroId: (() {
        final raw = json['numero_id'] ?? json['numero'];
        if (raw is int) return raw;
        if (raw == null) return null;
        return int.tryParse(raw.toString());
      })(),
      name: (json['name'] ?? json['nom'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      telephone: (json['telephone'] ?? json['tel']) as String?,
      role: json['role'] as String?,
    );
  }
}
