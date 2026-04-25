import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RestaurantTablesScreen extends StatefulWidget {
  const RestaurantTablesScreen({Key? key}) : super(key: key);

  @override
  State<RestaurantTablesScreen> createState() => _RestaurantTablesScreenState();
}

class _RestaurantTablesScreenState extends State<RestaurantTablesScreen> {
  List<RestaurantTable> _tables = [];

  final ApiService _api = ApiService();

  bool _showPlanView = true;
  Timer? _refreshTimer;
  static const Duration _refreshInterval = Duration(seconds: 5);

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
          'Plan des Tables',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showPlanView ? Icons.list : Icons.grid_view,
              color: const Color(0xFFD43B3B),
            ),
            onPressed: () {
              setState(() {
                _showPlanView = !_showPlanView;
              });
            },
            tooltip: _showPlanView ? 'Vue liste' : 'Vue plan',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFFD43B3B)),
            onPressed: _showAddTableDialog,
            tooltip: 'Ajouter une table',
          ),
        ],
      ),
      body: Column(
        children: [
          // Légende
          _buildLegend(),
          const SizedBox(height: 10),

          // Zone du plan avec dimensions fixes
          Expanded(
            child: _showPlanView ? _buildPlanView() : _buildListView(),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadTables();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      // Keep tables updated "near real-time" by polling the backend.
      _loadTables(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTables({bool silent = false}) async {
    try {
      final raw = await _api.fetchTables();
      if (!mounted) return;
      final next = raw
          .map((e) => RestaurantTable.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() => _tables = next);
    } catch (e) {
      if (!silent) {
        // ignore: avoid_print
        print('Failed to load tables: $e');
      }
    }
  }

  /// Table widget size on plan (must match [_buildTableWidget]).
  double _planTableWidth(RestaurantTable table) {
    final size = table.capacity * 15 + 40;
    return table.shape == TableShape.RECTANGLE ? size * 1.5 : size.toDouble();
  }

  double _planTableHeight(RestaurantTable table) {
    final size = table.capacity * 15 + 40;
    return table.shape == TableShape.RECTANGLE ? size * 0.75 : size.toDouble();
  }

  /// Minimum plan size so background + comptoir fit; grows to include every table.
  Size _planContentSize() {
    const double minW = 520;
    const double minH = 360;
    if (_tables.isEmpty) return const Size(minW, minH);
    double maxR = minW;
    double maxB = minH;
    for (final t in _tables) {
      final w = _planTableWidth(t);
      final h = _planTableHeight(t);
      maxR = math.max(maxR, t.x.toDouble() + w + 20);
      maxB = math.max(maxB, t.y.toDouble() + h + 20);
    }
    return Size(maxR, maxB);
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          _buildLegendItem(Colors.green, 'Libre'),
          _buildLegendItem(Colors.red, 'Occupée'),
          _buildLegendItem(Colors.orange, 'Réservée'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanView() {
    final content = _planContentSize();
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: content.width,
                height: content.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildRestaurantBackground(),

                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F1F3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: const Center(
                          child: Text(
                            'COMPTOIR',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    ..._tables.map((table) {
                      return Positioned(
                        left: table.x.toDouble(),
                        // Move tables well above the comptoir area for clarity.
                        top: math.max(0, table.y.toDouble() - 140),
                        child: GestureDetector(
                          onTap: () => _showTableDetails(table),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: _buildTableWidget(table),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRestaurantBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF6F7F9),
      child: CustomPaint(
        painter: _GridPainter(light: true),
      ),
    );
  }

  Widget _buildTableWidget(RestaurantTable table) {
    final color = _getTableColor(table.state);
    final size = table.capacity * 15 + 40;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: table.shape == TableShape.RECTANGLE ? size * 1.5 : size.toDouble(),
      height:
          table.shape == TableShape.RECTANGLE ? size * 0.75 : size.toDouble(),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: table.shape == TableShape.CIRCLE
            ? BoxShape.circle
            : BoxShape.rectangle,
        borderRadius: table.shape != TableShape.CIRCLE
            ? BorderRadius.circular(table.shape == TableShape.SQUARE ? 12 : 16)
            : null,
        border: Border.all(
          color: color.withOpacity(0.9),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.translate(
                  offset: const Offset(0, 6),
                  child: Text(
                    '${table.number}',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Badge d'état
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.35)),
              ),
              child: Text(
                _getStateLabel(table.state),
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tables.length,
      itemBuilder: (context, index) {
        final table = _tables[index];
        return _buildTableListItem(table);
      },
    );
  }

  Widget _buildTableListItem(RestaurantTable table) {
    final color = _getTableColor(table.state);

    return Card(
      color: const Color(0xFF1B1D20),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: table.shape == TableShape.CIRCLE
                ? BoxShape.circle
                : BoxShape.rectangle,
            borderRadius: table.shape != TableShape.CIRCLE
                ? BorderRadius.circular(10)
                : null,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              '${table.number}',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        title: Text(
          'Table ${table.number}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStateLabel(table.state),
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${table.capacity} pers.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Position: (${table.x}, ${table.y}) • ${_getShapeLabel(table.shape)}',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
              onPressed: () => _showEditTableDialog(table),
              tooltip: 'Modifier',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 20),
              onPressed: () => _deleteTable(table),
              tooltip: 'Supprimer',
            ),
          ],
        ),
        onTap: () => _showTableDetails(table),
      ),
    );
  }

  void _showAddTableDialog() {
    final numberCtrl = TextEditingController();
    final capacityCtrl = TextEditingController(text: '2');
    // Avoid stacking all tables at the same position in plan view.
    // Compute a simple grid-like default position based on current count.
    final idx = _tables.length;
    final baseX = 80 + (idx % 6) * 80;
    final baseY = 240 + (idx ~/ 6) * 80;
    final xCtrl = TextEditingController(text: '$baseX');
    final yCtrl = TextEditingController(text: '$baseY');
    TableState selectedState = TableState.LIBRE;
    TableShape selectedShape = TableShape.SQUARE;

    showDialog(
      context: context,
      builder: (ctx) => _buildTableDialog(
        title: 'Nouvelle Table',
        onSave: () {
          if (numberCtrl.text.isEmpty) {
            return;
          }

          final payload = {
            'numero': int.tryParse(numberCtrl.text) ?? (_tables.length + 1),
            'etat': selectedState.name.toUpperCase(),
            'x': int.tryParse(xCtrl.text) ?? 100,
            'y': int.tryParse(yCtrl.text) ?? 100,
          };

          _api.createTable(payload).then((res) {
            if (!mounted) return;
            setState(() {
              _tables.add(RestaurantTable.fromJson(res));
            });
            Navigator.pop(ctx);
          }).catchError((e) {
            // ignore: avoid_print
            print('Create table failed: $e');
          });
        },
        numberCtrl: numberCtrl,
        capacityCtrl: capacityCtrl,
        xCtrl: xCtrl,
        yCtrl: yCtrl,
        selectedState: selectedState,
        selectedShape: selectedShape,
      ),
    );
  }

  void _showEditTableDialog(RestaurantTable table) {
    final numberCtrl = TextEditingController(text: table.number.toString());
    final capacityCtrl = TextEditingController(text: table.capacity.toString());
    final xCtrl = TextEditingController(text: table.x.toString());
    final yCtrl = TextEditingController(text: table.y.toString());
    TableState selectedState = table.state;
    TableShape selectedShape = table.shape;

    showDialog(
      context: context,
      builder: (ctx) => _buildTableDialog(
        title: 'Modifier Table ${table.number}',
        onSave: () {
          final updatedTable = table.copyWith(
            number: int.tryParse(numberCtrl.text) ?? table.number,
            state: selectedState,
            x: int.tryParse(xCtrl.text) ?? table.x,
            y: int.tryParse(yCtrl.text) ?? table.y,
            capacity: int.tryParse(capacityCtrl.text) ?? table.capacity,
            shape: selectedShape,
          );

          final payload = {
            'numero': updatedTable.number,
            'etat': updatedTable.state.name.toUpperCase(),
            'x': updatedTable.x,
            'y': updatedTable.y,
          };

          _api.updateTable(int.tryParse(table.id) ?? 0, payload).then((res) {
            if (!mounted) return;
            setState(() {
              final index = _tables.indexWhere((t) => t.id == table.id);
              if (index != -1) {
                _tables[index] = RestaurantTable.fromJson(res);
              }
            });
            Navigator.pop(ctx);
          }).catchError((e) {
            // ignore: avoid_print
            print('Update table failed: $e');
          });
        },
        numberCtrl: numberCtrl,
        capacityCtrl: capacityCtrl,
        xCtrl: xCtrl,
        yCtrl: yCtrl,
        selectedState: selectedState,
        selectedShape: selectedShape,
      ),
    );
  }

  Widget _buildTableDialog({
    required String title,
    required VoidCallback onSave,
    required TextEditingController numberCtrl,
    required TextEditingController capacityCtrl,
    required TextEditingController xCtrl,
    required TextEditingController yCtrl,
    required TableState selectedState,
    required TableShape selectedShape,
  }) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1D20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Numéro de table',
                labelStyle: TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: capacityCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Capacité',
                labelStyle: TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: xCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Position X',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: yCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Position Y',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TableState>(
              value: selectedState,
              decoration: const InputDecoration(
                labelText: 'État',
                labelStyle: TextStyle(color: Colors.white70),
              ),
              dropdownColor: const Color(0xFF1B1D20),
              style: const TextStyle(color: Colors.white),
              items: TableState.values.map((state) {
                return DropdownMenuItem(
                  value: state,
                  child: Text(_getStateLabel(state)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedState = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TableShape>(
              value: selectedShape,
              decoration: const InputDecoration(
                labelText: 'Forme',
                labelStyle: TextStyle(color: Colors.white70),
              ),
              dropdownColor: const Color(0xFF1B1D20),
              style: const TextStyle(color: Colors.white),
              items: TableShape.values.map((shape) {
                return DropdownMenuItem(
                  value: shape,
                  child: Text(_getShapeLabel(shape)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedShape = value;
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD43B3B),
          ),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }

  void _showTableDetails(RestaurantTable table) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B1D20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _getTableColor(table.state).withOpacity(0.2),
                        shape: table.shape == TableShape.CIRCLE
                            ? BoxShape.circle
                            : BoxShape.rectangle,
                        borderRadius: table.shape != TableShape.CIRCLE
                            ? BorderRadius.circular(12)
                            : null,
                        border: Border.all(
                          color: _getTableColor(table.state),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${table.number}',
                          style: TextStyle(
                            color: _getTableColor(table.state),
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
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
                            'Table ${table.number}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${_getShapeLabel(table.shape)} • ${table.capacity} personnes',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDetailItem('État', _getStateLabel(table.state)),
                _buildDetailItem('Capacité', '${table.capacity} personnes'),
                _buildDetailItem('Forme', _getShapeLabel(table.shape)),
                _buildDetailItem('Position', 'X: ${table.x}, Y: ${table.y}'),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showEditTableDialog(table);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Modifier'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _deleteTable(table);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Supprimer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _deleteTable(RestaurantTable table) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1D20),
        title: const Text(
          'Supprimer la table',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer la table ${table.number} ?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              _api.deleteTable(int.tryParse(table.id) ?? 0).then((ok) {
                if (!mounted) return;
                if (ok) {
                  setState(() {
                    _tables.removeWhere((t) => t.id == table.id);
                  });
                }
                Navigator.pop(ctx);
              }).catchError((e) {
                // ignore: avoid_print
                print('Delete table failed: $e');
                Navigator.pop(ctx);
              });
            },
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTableColor(TableState state) {
    switch (state) {
      case TableState.LIBRE:
        return Colors.green;
      case TableState.OCCUPEE:
        return Colors.redAccent;
      case TableState.RESERVEE:
        return Colors.orange;
    }
  }

  String _getStateLabel(TableState state) {
    switch (state) {
      case TableState.LIBRE:
        return 'LIBRE';
      case TableState.OCCUPEE:
        return 'OCCUPÉE';
      case TableState.RESERVEE:
        return 'RÉSERVÉE';
    }
  }

  String _getShapeLabel(TableShape shape) {
    switch (shape) {
      case TableShape.CIRCLE:
        return 'Ronde';
      case TableShape.SQUARE:
        return 'Carrée';
      case TableShape.RECTANGLE:
        return 'Rectangulaire';
    }
  }
}

class RestaurantTable {
  final String id;
  final int number;
  final TableState state;
  final int x;
  final int y;
  final int capacity;
  final TableShape shape;

  RestaurantTable({
    required this.id,
    required this.number,
    required this.state,
    required this.x,
    required this.y,
    required this.capacity,
    required this.shape,
  });

  RestaurantTable copyWith({
    String? id,
    int? number,
    TableState? state,
    int? x,
    int? y,
    int? capacity,
    TableShape? shape,
  }) {
    return RestaurantTable(
      id: id ?? this.id,
      number: number ?? this.number,
      state: state ?? this.state,
      x: x ?? this.x,
      y: y ?? this.y,
      capacity: capacity ?? this.capacity,
      shape: shape ?? this.shape,
    );
  }

  factory RestaurantTable.fromJson(Map<String, dynamic> j) {
    TableState parseState(String s) {
      switch (s.toUpperCase()) {
        case 'LIBRE':
          return TableState.LIBRE;
        case 'OCCUPEE':
        case 'OCCUPÉE':
          return TableState.OCCUPEE;
        case 'RESERVEE':
        case 'RÉSERVÉE':
          return TableState.RESERVEE;
        default:
          return TableState.LIBRE;
      }
    }

    TableShape parseShape(String? s) {
      if (s == null) return TableShape.SQUARE;
      switch (s.toUpperCase()) {
        case 'CIRCLE':
          return TableShape.CIRCLE;
        case 'RECTANGLE':
          return TableShape.RECTANGLE;
        case 'SQUARE':
        default:
          return TableShape.SQUARE;
      }
    }

    return RestaurantTable(
      id: (j['id'] ?? j['ID'] ?? '').toString(),
      number: (j['numero'] ?? j['number'] ?? 0) as int,
      state: parseState((j['etat'] ?? j['state'] ?? 'LIBRE').toString()),
      x: (j['x'] ?? 0) as int,
      y: (j['y'] ?? 0) as int,
      capacity: (j['capacity'] ?? j['capacite'] ?? 2) as int,
      shape: parseShape((j['shape'] ?? j['forme'])?.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    String stateToString(TableState s) {
      switch (s) {
        case TableState.LIBRE:
          return 'LIBRE';
        case TableState.OCCUPEE:
          return 'OCCUPEE';
        case TableState.RESERVEE:
          return 'RESERVEE';
      }
    }

    String shapeToString(TableShape s) {
      switch (s) {
        case TableShape.CIRCLE:
          return 'CIRCLE';
        case TableShape.RECTANGLE:
          return 'RECTANGLE';
        case TableShape.SQUARE:
          return 'SQUARE';
      }
    }

    return {
      'id': id,
      'numero': number,
      'etat': stateToString(state),
      'x': x,
      'y': y,
      'capacity': capacity,
      'shape': shapeToString(shape),
    };
  }
}

enum TableState { LIBRE, OCCUPEE, RESERVEE }

enum TableShape { CIRCLE, SQUARE, RECTANGLE }

class _GridPainter extends CustomPainter {
  final bool light;
  _GridPainter({this.light = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = light
          ? Colors.black.withOpacity(0.06)
          : Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    // Lignes verticales
    for (double x = 0; x < size.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Lignes horizontales
    for (double y = 0; y < size.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
