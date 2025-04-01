import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:developer' as developer;
import '../services/api.dart';
import '../widgets/sidebar.dart';
import 'package:intl/intl.dart';

class DriverReportsScreen extends StatefulWidget {
  const DriverReportsScreen({Key? key}) : super(key: key);

  @override
  _DriverReportsScreenState createState() => _DriverReportsScreenState();
}

class _DriverReportsScreenState extends State<DriverReportsScreen> {
  bool isSidebarVisible = false;
  bool loading = false;
  List<Trip> trips = [];
  DateTime startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime endDate = DateTime.now();
  bool showDrivers = false;
  List<DriverProfile> drivers = [];
  DriverProfile? selectedDriver;
  String searchTerm = '';

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    try {
      final driverService = DriverService();
      final driversData = await driverService.getAllDrivers();

      if (mounted) {
        setState(() {
          drivers = driversData;
        });
      }
    } catch (error) {
      developer.log('Error cargando conductores: $error');
    }
  }

  Future<void> _fetchTrips() async {
    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingrese ambas fechas')),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final analyticsService = AnalyticsService();
      final data = await analyticsService.getCompletedTrips(
        startDate: "${DateFormat('yyyy-MM-dd').format(startDate)}T00:00:00",
        endDate: "${DateFormat('yyyy-MM-dd').format(endDate)}T23:59:59",
        driverId: selectedDriver?.id,
      );

      setState(() {
        trips = data.map((map) => Trip.fromJson(map)).toList();
        loading = false;
      });
    } catch (error) {
      developer.log('Error al obtener viajes: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al obtener los viajes')),
      );
      setState(() {
        loading = false;
      });
    }
  }

  List<DriverProfile> get filteredDrivers {
    return drivers.where((driver) {
      final fullName = "${driver.firstName} ${driver.lastName}".toLowerCase();
      return fullName.contains(searchTerm.toLowerCase());
    }).toList();
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? startDate : endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2025),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de Choferes'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => setState(() => isSidebarVisible = true),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Contenedor de filtros
              Container(
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
                          child: GestureDetector(
                            onTap: () => _selectDate(true),
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    LucideIcons.calendar,
                                    size: 20,
                                    color: Color(0xFFDC2626),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('dd/MM/yyyy').format(startDate),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectDate(false),
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    LucideIcons.calendar,
                                    size: 20,
                                    color: Color(0xFFDC2626),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('dd/MM/yyyy').format(endDate),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Filtro de conductor
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap:
                                () =>
                                    setState(() => showDrivers = !showDrivers),
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    LucideIcons.user,
                                    size: 20,
                                    color: Color(0xFFDC2626),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      selectedDriver != null
                                          ? "${selectedDriver!.firstName} ${selectedDriver!.lastName}"
                                          : "Seleccionar Chofer",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF0F172A),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (selectedDriver != null)
                                    GestureDetector(
                                      onTap:
                                          () => setState(
                                            () => selectedDriver = null,
                                          ),
                                      child: const Icon(
                                        LucideIcons.x,
                                        size: 16,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: loading ? null : _fetchTrips,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child:
                                  loading
                                      ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Color(0xFFDC2626),
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Icon(
                                        LucideIcons.search,
                                        size: 24,
                                        color: Color(0xFFDC2626),
                                      ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Dropdown de conductores
                    if (showDrivers)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                  hintText: "Buscar chofer...",
                                  hintStyle: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF0F172A),
                                ),
                                onChanged:
                                    (value) =>
                                        setState(() => searchTerm = value),
                              ),
                            ),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredDrivers.length,
                                itemBuilder: (context, index) {
                                  final driver = filteredDrivers[index];
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedDriver = driver;
                                        showDrivers = false;
                                        searchTerm = '';
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: Color(0xFFE2E8F0),
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        "${driver.firstName} ${driver.lastName}",
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
                      ),
                  ],
                ),
              ),

              // Lista de viajes
              Expanded(
                child:
                    trips.isEmpty
                        ? const Center(
                          child: Text(
                            "No hay viajes en este período",
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 16,
                            ),
                          ),
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: trips.length,
                          itemBuilder: (context, index) {
                            final trip = trips[index];
                            return _buildTripCard(trip);
                          },
                        ),
              ),
            ],
          ),

          // Sidebar
          if (isSidebarVisible)
            Sidebar(
              isVisible: isSidebarVisible,
              onClose: () => setState(() => isSidebarVisible = false),
              role: 'admin',
            ),
        ],
      ),
    );
  }

  Widget _buildTripCard(Trip trip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3.84,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    fontSize: 14,
                    color: Color(0xFFDC2626),
                  ),
                ),
                Text(
                  "\$${trip.price.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Detalles del viaje
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 60,
                  child: Text(
                    "Origen:",
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ),
                Expanded(
                  child: Text(
                    trip.origin,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 60,
                  child: Text(
                    "Destino:",
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ),
                Expanded(
                  child: Text(
                    trip.destination,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Pie del viaje
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 60,
                        child: Text(
                          "Chofer:",
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          trip.driver_profiles != null
                              ? "${trip.driver_profiles.first_name} ${trip.driver_profiles.last_name}"
                              : "No asignado",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(
                        width: 60,
                        child: Text(
                          "Operador:",
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          trip.operator_profiles != null
                              ? "${trip.operator_profiles.first_name} ${trip.operator_profiles.last_name}"
                              : "No asignado",
                          style: const TextStyle(
                            fontSize: 14,
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
