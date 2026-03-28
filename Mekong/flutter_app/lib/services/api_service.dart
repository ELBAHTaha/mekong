import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/dashboard.dart';

class ApiService {
  /// Default points to the VPS backend on port 1000.
  /// If you need another host, use `ApiService.forHost('http://<host>:1000/api')`.
  ApiService({this.baseUrl = 'http://69.62.108.186:1000/api'});
  final String baseUrl;

  ApiService.forHost(String host) : baseUrl = host;

  Future<Map<String, String>> _basicAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('auth_email') ?? '';
    final password = prefs.getString('auth_password') ?? '';
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Missing credentials');
    }
    final basic = base64Encode(utf8.encode('$email:$password'));
    return {
      'Authorization': 'Basic $basic',
      'Accept': 'application/json',
    };
  }

  Future<Map<String, String>> _jsonAuthHeaders() async {
    final headers = await _basicAuthHeaders();
    headers['Content-Type'] = 'application/json';
    return headers;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final uri = Uri.parse('$baseUrl/login');
    final res = await http
        .post(
          uri,
          headers: {'Accept': 'application/json'},
          body: {'email': email, 'password': password},
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Login failed: ${res.statusCode}');
  }

  Future<User> fetchUser(String token) async {
    final uri = Uri.parse('$baseUrl/user');
    final res = await http.get(uri, headers: await _basicAuthHeaders());
    if (res.statusCode == 200) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return User.fromJson(data);
    }
    throw Exception('Failed to load user');
  }

  Future<bool> sendPasswordReset(String email) async {
    final uri = Uri.parse('$baseUrl/forgot-password');
    final res = await http.post(uri, body: {'email': email});
    if (res.statusCode == 200 || res.statusCode == 202) return true;
    return false;
  }

  Future<DashboardData> fetchDashboard(String token) async {
    final uri = Uri.parse('$baseUrl/dashboard');
    final res = await http.get(uri, headers: await _basicAuthHeaders());
    if (res.statusCode == 200) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return DashboardData.fromJson(data);
    }
    throw Exception('Failed to load dashboard');
  }

  /// Fetch daily sales for a given month (returns list of day objects)
  Future<List<MonthDaySale>> fetchVentesParMois(String token, int year, int month) async {
    final uri = Uri.parse('$baseUrl/ventes-par-mois').replace(queryParameters: {
      'year': year.toString(),
      'month': month.toString(),
    });
    final res = await http.get(uri, headers: await _basicAuthHeaders());
    if (res.statusCode == 200) {
      final list = json.decode(res.body) as List<dynamic>;
      return list.map((e) => MonthDaySale.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load ventes par mois: ${res.statusCode}');
  }

  Future<User> updateUser(String token, Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl/user');
    final headers = await _basicAuthHeaders();
    headers['Content-Type'] = 'application/json';
    final res = await http.put(uri,
        headers: headers,
        body: json.encode(payload));
    if (res.statusCode == 200) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return User.fromJson(data);
    }
    throw Exception('Failed to update user: ${res.statusCode}');
  }

  // Personnel (users) endpoints
  Future<List<User>> fetchPersonnelList() async {
    final uri = Uri.parse('$baseUrl/personnel');
    final res = await http.get(uri, headers: await _basicAuthHeaders());
    if (res.statusCode == 200) {
      final body = json.decode(res.body) as Map<String, dynamic>;
      final list = body['data'] as List<dynamic>;
      return list.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load personnel: ${res.statusCode}');
  }

  Future<User> createPersonnel(Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl/personnel');
    final headers = await _basicAuthHeaders();
    headers['Content-Type'] = 'application/json';
    final res = await http.post(uri,
        headers: headers,
        body: json.encode(payload));
    if (res.statusCode == 201) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return User.fromJson(data);
    }
    throw Exception(
        'Failed to create personnel: ${res.statusCode} ${res.body}');
  }

  Future<User> updatePersonnel(int id, Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl/personnel/$id');
    final headers = await _basicAuthHeaders();
    headers['Content-Type'] = 'application/json';
    final res = await http.put(uri,
        headers: headers,
        body: json.encode(payload));
    if (res.statusCode == 200) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return User.fromJson(data);
    }
    throw Exception(
        'Failed to update personnel: ${res.statusCode} ${res.body}');
  }

  Future<http.Response> deletePersonnel(int id) async {
    final uri = Uri.parse('$baseUrl/personnel/$id');
    final res =
        await http.delete(uri, headers: await _basicAuthHeaders());
    return res;
  }

  // Produits endpoints
  Future<List<dynamic>> fetchProducts() async {
    final headers = await _basicAuthHeaders();
    final List<dynamic> all = [];
    int page = 1;
    int lastPage = 1;
    do {
      final uri = Uri.parse('$baseUrl/produits').replace(queryParameters: {
        'page': page.toString(),
        'per_page': '100',
      });
      final res = await http.get(uri, headers: headers);
      if (res.statusCode != 200) {
        throw Exception('Failed to load produits: ${res.statusCode} ${res.body}');
      }
      final body = json.decode(res.body) as Map<String, dynamic>;
      final list = body['data'] as List<dynamic>;
      all.addAll(list);
      final meta = body['meta'] as Map<String, dynamic>?;
      lastPage = (meta?['last_page'] is int)
          ? meta!['last_page'] as int
          : int.tryParse('${meta?['last_page']}') ?? 1;
      page += 1;
    } while (page <= lastPage);
    return all;
  }

  // Categories endpoints
  Future<List<dynamic>> fetchCategories() async {
    final uri = Uri.parse('$baseUrl/categories_produits');
    final res =
        await http.get(uri, headers: await _basicAuthHeaders());
    if (res.statusCode == 200) {
      final body = json.decode(res.body) as Map<String, dynamic>;
      final list = body['data'] as List<dynamic>;
      return list;
    }
    throw Exception('Failed to load categories: ${res.statusCode} ${res.body}');
  }

  // Charges categories (categories_charges)
  Future<List<dynamic>> fetchChargeCategories() async {
    final uri = Uri.parse('$baseUrl/categories_charges');
    final res = await http.get(uri, headers: await _basicAuthHeaders());
    if (res.statusCode == 200) {
      return json.decode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to load charge categories: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> createChargeCategory(Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl/categories_charges');
    final res = await http.post(uri,
        headers: await _jsonAuthHeaders(),
        body: json.encode(payload));
    if (res.statusCode == 201) return json.decode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to create category: ${res.statusCode} ${res.body}');
  }

  Future<bool> deleteChargeCategory(int id) async {
    final uri = Uri.parse('$baseUrl/categories_charges/$id');
    final res = await http.delete(uri, headers: await _basicAuthHeaders());
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>> updateChargeCategory(int id, Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl/categories_charges/$id');
    final res = await http.put(uri,
        headers: await _jsonAuthHeaders(),
        body: json.encode(payload));
    if (res.statusCode == 200) return json.decode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to update charge category: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> createCategory(
      Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl/categories_produits');
    final filePath = payload.remove('photo_file_path')?.toString();
    if (filePath != null && filePath.isNotEmpty) {
      return _multipartWithFile(uri, payload, filePath, method: 'POST');
    }
    final res = await http.post(uri,
        headers: await _jsonAuthHeaders(),
        body: json.encode(payload));
    if (res.statusCode == 201)
      return json.decode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to create category: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> updateCategory(
      int id, Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl/categories_produits/$id');
    final filePath = payload.remove('photo_file_path')?.toString();
    if (filePath != null && filePath.isNotEmpty) {
      return _multipartWithFile(uri, payload, filePath, method: 'PUT');
    }
    final res = await http.put(uri,
        headers: await _jsonAuthHeaders(),
        body: json.encode(payload));
    if (res.statusCode == 200)
      return json.decode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to update category: ${res.statusCode} ${res.body}');
  }

  Future<bool> deleteCategory(int id) async {
    final uri = Uri.parse('$baseUrl/categories_produits/$id');
    final res =
        await http.delete(uri, headers: await _basicAuthHeaders());
    if (res.statusCode == 200) return true;
    return false;
  }

  Future<Map<String, dynamic>> createProduct(
      Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl/produits');
    final filePath = payload.remove('photo_file_path')?.toString();
    if (filePath != null && filePath.isNotEmpty) {
      return _multipartWithFile(uri, payload, filePath, method: 'POST');
    }
    final res = await http.post(uri,
        headers: await _jsonAuthHeaders(),
        body: json.encode(payload));
    if (res.statusCode == 201) {
      return json.decode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create produit: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> updateProduct(
      int id, Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl/produits/$id');
    final filePath = payload.remove('photo_file_path')?.toString();
    if (filePath != null && filePath.isNotEmpty) {
      return _multipartWithFile(uri, payload, filePath, method: 'PUT');
    }
    final res = await http.put(uri,
        headers: await _jsonAuthHeaders(),
        body: json.encode(payload));
    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to update produit: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> _multipartWithFile(
    Uri uri,
    Map<String, dynamic> payload,
    String filePath, {
    required String method,
  }) async {
    final req = http.MultipartRequest('POST', uri);
    final headers = await _basicAuthHeaders();
    req.headers.addAll(headers);
    if (method.toUpperCase() != 'POST') {
      req.fields['_method'] = method.toUpperCase();
    }
    payload.forEach((key, value) {
      if (value == null) return;
      req.fields[key] = value.toString();
    });
    req.files.add(await http.MultipartFile.fromPath('photo_file', filePath));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200 || res.statusCode == 201) {
      return json.decode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Request failed: ${res.statusCode} ${res.body}');
  }

  Future<bool> deleteProduct(int id) async {
    final uri = Uri.parse('$baseUrl/produits/$id');
    final res =
        await http.delete(uri, headers: await _basicAuthHeaders());
    if (res.statusCode == 200) return true;
    return false;
  }

  // Tables restaurant endpoints
  Future<List<dynamic>> fetchTables() async {
    final uri = Uri.parse('$baseUrl/tables_restaurant');
    final res =
        await http.get(uri, headers: await _basicAuthHeaders());
    if (res.statusCode == 200) {
      final body = json.decode(res.body) as List<dynamic>;
      return body;
    }
    throw Exception('Failed to load tables: ${res.statusCode} ${res.body}');
  }

  // Charges endpoints
  Future<List<dynamic>> fetchCharges({int? categorieId, String? from, String? to, String? search}) async {
    final uri = Uri.parse('$baseUrl/charges').replace(queryParameters: {
      if (categorieId != null) 'categorie_id': categorieId.toString(),
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (search != null) 'search': search,
    });
    final res = await http.get(uri, headers: await _basicAuthHeaders());
    if (res.statusCode == 200) {
      return json.decode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to load charges: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> createCharge(Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl/charges');
    final res = await http.post(uri,
        headers: await _jsonAuthHeaders(),
        body: json.encode(payload));
    if (res.statusCode == 201) return json.decode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to create charge: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> updateCharge(int id, Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl/charges/$id');
    final res = await http.put(uri,
        headers: await _jsonAuthHeaders(),
        body: json.encode(payload));
    if (res.statusCode == 200) return json.decode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to update charge: ${res.statusCode} ${res.body}');
  }

  Future<bool> deleteCharge(int id) async {
    final uri = Uri.parse('$baseUrl/charges/$id');
    final res = await http.delete(uri, headers: await _basicAuthHeaders());
    return res.statusCode == 200;
  }

  /// Fetch current positions for livraisons (real-time tracking)
  /// Optional `since` ISO timestamp to filter updates.
  Future<List<Map<String, dynamic>>> fetchLivraisonsPositions({String? since}) async {
    final uri = Uri.parse('$baseUrl/livraisons/positions').replace(queryParameters: {
      if (since != null) 'since': since,
    });
    final res = await http.get(uri, headers: await _basicAuthHeaders());
    if (res.statusCode == 200) {
      final list = json.decode(res.body) as List<dynamic>;
      return list.map((e) => e as Map<String, dynamic>).toList();
    }
    throw Exception('Failed to load livraisons positions: ${res.statusCode} ${res.body}');
  }

  /// Send a livraison position (driver device)
  Future<bool> postLivraisonPosition(int id, double latitude, double longitude, {String? timestamp}) async {
    final uri = Uri.parse('$baseUrl/livraisons/$id/position');
    final payload = {
      'latitude': latitude,
      'longitude': longitude,
      if (timestamp != null) 'timestamp': timestamp,
    };
    final res = await http.post(uri,
        headers: await _jsonAuthHeaders(),
        body: json.encode(payload));
    return res.statusCode == 200 || res.statusCode == 201;
  }

  Future<Map<String, dynamic>> createTable(Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl/tables_restaurant');
    final res = await http.post(uri,
        headers: await _jsonAuthHeaders(),
        body: json.encode(payload));
    if (res.statusCode == 201)
      return json.decode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to create table: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> updateTable(
      int id, Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl/tables_restaurant/$id');
    final res = await http.put(uri,
        headers: await _jsonAuthHeaders(),
        body: json.encode(payload));
    if (res.statusCode == 200)
      return json.decode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to update table: ${res.statusCode} ${res.body}');
  }

  Future<bool> deleteTable(int id) async {
    final uri = Uri.parse('$baseUrl/tables_restaurant/$id');
    final res =
        await http.delete(uri, headers: await _basicAuthHeaders());
    if (res.statusCode == 204 || res.statusCode == 200) return true;
    return false;
  }

  // Commandes endpoints
  Future<List<dynamic>> fetchCommandes({String? statut, String? type, int? serveurId, int? caissierId, String? from, String? to, bool? includeServeur}) async {
    final uri = Uri.parse('$baseUrl/commandes').replace(queryParameters: {
      if (statut != null) 'statut': statut,
      if (type != null) 'type': type,
      if (serveurId != null) 'serveur_id': serveurId.toString(),
      if (caissierId != null) 'caissier_id': caissierId.toString(),
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (includeServeur == true) 'include_serveur': '1',
    });
    final res = await http.get(uri, headers: await _basicAuthHeaders());
    if (res.statusCode == 200) {
      final String body = res.body.trim();
      if (body.isEmpty) return <dynamic>[];
      dynamic decoded;
      try {
        decoded = json.decode(body);
      } on FormatException {
        // Try to repair common truncated JSON responses by balancing brackets.
        final buf = StringBuffer(body);
        int openCurly = 0;
        int openSquare = 0;
        for (int i = 0; i < body.length; i++) {
          final ch = body[i];
          if (ch == '{') openCurly++;
          if (ch == '}') openCurly--;
          if (ch == '[') openSquare++;
          if (ch == ']') openSquare--;
        }
        for (int i = 0; i < openSquare; i++) {
          buf.write(']');
        }
        for (int i = 0; i < openCurly; i++) {
          buf.write('}');
        }
        decoded = json.decode(buf.toString());
      }

      if (decoded is List) {
        return decoded;
      }
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is List) return data;
      }
      if (decoded is Map) {
        final data = decoded['data'];
        if (data is List) return data;
      }
      return <dynamic>[];
    }
    throw Exception('Failed to load commandes: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> createCommande(Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl/commandes');
    final res = await http.post(uri,
        headers: await _jsonAuthHeaders(),
        body: json.encode(payload));
    if (res.statusCode == 201) return json.decode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to create commande: ${res.statusCode} ${res.body}');
  }

  // Commandes serveur (tables)
  Future<Map<String, dynamic>> createCommandeServeur(Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl/commande_serveur');
    final res = await http.post(uri,
        headers: await _jsonAuthHeaders(),
        body: json.encode(payload));
    if (res.statusCode == 201) return json.decode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to create commande serveur: ${res.statusCode} ${res.body}');
  }

  Future<List<dynamic>> fetchCommandeServeurList() async {
    final uri = Uri.parse('$baseUrl/commande_serveur');
    final res = await http.get(uri, headers: await _basicAuthHeaders());
    if (res.statusCode == 200) {
      final body = json.decode(res.body);
      if (body is List) return body;
      if (body is Map<String, dynamic>) {
        final data = body['data'];
        if (data is List) return data;
      }
      if (body is Map) {
        final data = body['data'];
        if (data is List) return data;
      }
      return <dynamic>[];
    }
    throw Exception('Failed to load commande_serveur: ${res.statusCode} ${res.body}');
  }

  Future<int> fetchUnreadNotificationsCount() async {
    final uri = Uri.parse('$baseUrl/notifications/unread-count');
    final res = await http.get(uri, headers: await _basicAuthHeaders());
    if (res.statusCode == 200) {
      final body = json.decode(res.body) as Map<String, dynamic>;
      final v = body['unread'];
      if (v is int) return v;
      return int.tryParse('$v') ?? 0;
    }
    throw Exception('Failed to load notifications count: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> updateCommande(int id, Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl/commandes/$id');
    final res = await http.put(uri,
        headers: await _jsonAuthHeaders(),
        body: json.encode(payload));
    if (res.statusCode == 200) return json.decode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to update commande: ${res.statusCode} ${res.body}');
  }

  Future<bool> deleteCommande(int id) async {
    final uri = Uri.parse('$baseUrl/commandes/$id');
    final res = await http.delete(uri, headers: await _basicAuthHeaders());
    return res.statusCode == 200;
  }

  /// Returns a non-empty marker when stored basic credentials exist.
  Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('auth_email') ?? '';
    final password = prefs.getString('auth_password') ?? '';
    if (email.isEmpty || password.isEmpty) return null;
    return 'basic';
  }

  /// Verifies the stored token by attempting to fetch the current user.
  /// Returns true when the token exists and the server accepts it.
  Future<bool> verifyToken() async {
    final token = await getStoredToken();
    if (token == null || token.isEmpty) return false;
    try {
      await fetchUser(token);
      return true;
    } catch (_) {
      return false;
    }
  }
}







