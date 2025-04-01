import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import '../services/api.dart';

class OperatorReportsScreen extends StatefulWidget {
  const OperatorReportsScreen({Key? key}) : super(key: key);

  @override
  _OperatorReportsScreenState createState() => _OperatorReportsScreenState();
}

class _OperatorReportsScreenState extends State<OperatorReportsScreen> {
  bool loading = false;
  List<Trip> trips = [];
  DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime endDate = DateTime.now();
  bool showOperators = false;
  List<OperatorProfile> operators = [];
  OperatorProfile? selectedOperator;
  String searchTerm = '';

  @override
  void initState() {
    super.initState();
    _loadOperators();
  }

  Future<void> _loadOperators() async {
    try {
      final operatorService = OperatorService();
      final data = await operatorService.getAllOperators();
      setState(() {
        operators = data;
      });
    } catch (error) {
      developer.log('Error al cargar operadores: $error');
    }
  }

  Future<void> _fetchTrips() async {
    try {
      setState(() {
        loading = true;
      });

      final analyticsService = AnalyticsService();
      final data = await analyticsService.getOperatorCompletedTrips(
        startDate.toIso8601String(),
        endDate.toIso8601String(),
        selectedOperator?.id,
      );

      setState(() {
        trips = data.map((tripData) => Trip.fromJson(tripData)).toList();
        loading = false;
      });
    } catch (error) {
      developer.log('Error al obtener viajes: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar los viajes')),
      );
      setState(() {
        loading = false;
      });
    }
  }

  List<OperatorProfile> get filteredOperators {
    return operators.where((operator) {
      final fullName =
          '${operator.firstName} ${operator.lastName}'.toLowerCase();
      return fullName.contains(searchTerm.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de Operadores'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [_buildFiltersSection(), Expanded(child: _buildTripsList())],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          // Filtros de fecha
          Row(
            children: [
              Expanded(
                child: _buildDatePicker(
                  'Desde',
                  startDate,
                  (date) => setState(() => startDate = date),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDatePicker(
                  'Hasta',
                  endDate,
                  (date) => setState(() => endDate = date),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Filtro de operador y botón de búsqueda
          Row(
            children: [
              Expanded(child: _buildOperatorSelector()),
              const SizedBox(width: 8),
              _buildSearchButton(),
            ],
          ),

          // Dropdown de operadores
          if (showOperators) _buildOperatorsDropdown(),
        ],
      ),
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime value,
    Function(DateTime) onChanged,
  ) {
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
        );
        if (picked != null && picked != value) {
          onChanged(picked);
        }
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.calendar,
              size: 20,
              color: const Color(0xFFDC2626),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('dd/MM/yyyy').format(value),
              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatorSelector() {
    return InkWell(
      onTap: () {
        setState(() {
          showOperators = !showOperators;
        });
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.user, size: 20, color: const Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selectedOperator != null
                    ? '${selectedOperator!.firstName} ${selectedOperator!.lastName}'
                    : 'Seleccionar Operador',
                style: TextStyle(
                  fontSize: 14,
                  color:
                      selectedOperator != null
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF94A3B8),
                ),
              ),
            ),
            if (selectedOperator != null)
              GestureDetector(
                onTap: () {
                  setState(() {
                    selectedOperator = null;
                  });
                },
                child: Icon(
                  LucideIcons.x,
                  size: 16,
                  color: const Color(0xFFEF4444),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    return InkWell(
      onTap: loading ? null : _fetchTrips,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child:
              loading
                  ? const CircularProgressIndicator(color: Color(0xFFDC2626))
                  : Icon(
                    LucideIcons.search,
                    size: 24,
                    color: const Color(0xFFDC2626),
                  ),
        ),
      ),
    );
  }

  Widget _buildOperatorsDropdown() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar operador...',
                hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
              onChanged: (value) {
                setState(() {
                  searchTerm = value;
                });
              },
            ),
          ),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filteredOperators.length,
              itemBuilder: (context, index) {
                final operator = filteredOperators[index];
                return InkWell(
                  onTap: () {
                    setState(() {
                      selectedOperator = operator;
                      showOperators = false;
                      searchTerm = '';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Text(
                      '${operator.firstName} ${operator.lastName}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripsList() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (trips.isEmpty) {
      return Center(
        child: Text(
          'No hay viajes en este período',
          style: TextStyle(fontSize: 16, color: const Color(0xFF64748B)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        return _buildTripCard(trips[index]);
      },
    );
  }

  Widget _buildTripCard(Trip trip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado del viaje
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat(
                    'dd/MM/yyyy',
                  ).format(DateTime.parse(trip.createdAt)),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFDC2626),
                  ),
                ),
                Text(
                  '\$${trip.price}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Detalles del viaje
            Row(
              children: [
                const Text(
                  'Origen:',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.origin,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text(
                  'Destino:',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.destination,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Pie del viaje
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        child: const Text(
                          'Chofer:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          trip.driver_profiles != null
                              ? '${trip.driver_profiles!['first_name']} ${trip.driver_profiles!['last_name']}'
                              : 'No asignado',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 60,
                        child: const Text(
                          'Operador:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          trip.operator_profiles != null
                              ? '${trip.operator_profiles!['first_name']} ${trip.operator_profiles!['last_name']}'
                              : 'No asignado',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
