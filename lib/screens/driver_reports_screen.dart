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

  // Define colores para consistencia
  final Color primaryColor = Colors.red;
  final Color scaffoldBackgroundColor = Colors.grey.shade100;
  final Color cardBackgroundColor = Colors.white;
  final Color textColorPrimary = Colors.black87;
  final Color textColorSecondary = Colors.grey.shade600;
  final Color iconColor = Colors.red;
  final Color inputBackgroundColor =
      Colors.grey.shade50; // Fondo sutil para inputs/botones de filtro
  final Color borderColor = Colors.grey.shade300;
  final Color errorColor = Colors.red.shade700;
  final Color buttonTextColor = Colors.white;

  // Formateadores
  final DateFormat _displayDateFormat = DateFormat('dd MMM, yyyy', 'es');
  final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');
  final currencyFormatter = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
  );

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
          // Ordenar alfabéticamente
          drivers.sort(
            (a, b) => '${a.firstName} ${a.lastName}'.compareTo(
              '${b.firstName} ${b.lastName}',
            ),
          );
        });
      }
    } catch (error) {
      developer.log('Error cargando conductores: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudieron cargar los conductores'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  Future<void> _fetchTrips() async {
    if (startDate.isAfter(endDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'La fecha de inicio no puede ser posterior a la fecha de fin',
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    setState(() {
      loading = true;
      trips = [];
    }); // Limpiar viajes anteriores

    try {
      final analyticsService = AnalyticsService();
      final String startIso = "${_apiDateFormat.format(startDate)}T00:00:00";
      final String endIso = "${_apiDateFormat.format(endDate)}T23:59:59";

      final data = await analyticsService.getCompletedTrips(
        startDate: startIso,
        endDate: endIso,
        driverId: selectedDriver?.id,
      );

      if (mounted) {
        setState(() {
          trips = data.map((map) => Trip.fromJson(map)).toList();
          trips.sort(
            (a, b) => DateTime.parse(
              b.createdAt,
            ).compareTo(DateTime.parse(a.createdAt)),
          );
          loading = false;
        });
      }
    } catch (error) {
      developer.log('Error al obtener viajes: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al obtener los viajes: ${error.toString()}'),
            backgroundColor: errorColor,
          ),
        );
        setState(() {
          loading = false;
        });
      }
    }
  }

  List<DriverProfile> get filteredDrivers {
    return drivers.where((driver) {
      final fullName = "${driver.firstName} ${driver.lastName}".toLowerCase();
      return fullName.contains(searchTerm.toLowerCase());
    }).toList();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime initial = isStartDate ? startDate : endDate;
    final DateTime first = DateTime(2020);
    final DateTime last = DateTime.now().add(const Duration(days: 365));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          initial.isBefore(first)
              ? first
              : (initial.isAfter(last) ? last : initial),
      firstDate: first,
      lastDate: last,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: primaryColor,
              onPrimary: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: primaryColor),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          startDate = picked;
          if (endDate.isBefore(startDate)) {
            endDate = startDate;
          }
        } else {
          endDate = picked;
          if (startDate.isAfter(endDate)) {
            startDate = endDate;
          }
        }
      });
    }
  }

  void _showDriverSelectionModal() {
    setState(() {
      searchTerm = '';
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            final List<DriverProfile> filteredModalDrivers =
                drivers.where((driver) {
                  final fullName =
                      "${driver.firstName} ${driver.lastName}".toLowerCase();
                  final query = searchTerm.toLowerCase();
                  return fullName.contains(query);
                }).toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Seleccionar Chofer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColorPrimary,
                        ),
                      ),
                      IconButton(
                        icon: Icon(LucideIcons.x, color: textColorSecondary),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Cerrar',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) {
                      modalSetState(() {
                        searchTerm = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre...',
                      prefixIcon: Icon(
                        LucideIcons.search,
                        size: 20,
                        color: textColorSecondary,
                      ),
                      filled: true,
                      fillColor: inputBackgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Icon(
                      LucideIcons.users,
                      color:
                          selectedDriver == null
                              ? primaryColor
                              : textColorSecondary,
                    ),
                    title: Text(
                      'Todos los Choferes',
                      style: TextStyle(
                        fontWeight:
                            selectedDriver == null
                                ? FontWeight.bold
                                : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        selectedDriver = null;
                      });
                      Navigator.pop(context);
                    },
                    dense: true,
                    selected: selectedDriver == null,
                    selectedTileColor: primaryColor.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Divider(color: borderColor.withOpacity(0.5)),
                  Expanded(
                    child:
                        filteredModalDrivers.isEmpty
                            ? Center(
                              child: Text(
                                'No se encontraron choferes',
                                style: TextStyle(color: textColorSecondary),
                              ),
                            )
                            : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredModalDrivers.length,
                              itemBuilder: (context, index) {
                                final driver = filteredModalDrivers[index];
                                final bool isCurrentlySelected =
                                    selectedDriver?.id == driver.id;
                                return ListTile(
                                  leading: Icon(
                                    LucideIcons.user,
                                    color:
                                        isCurrentlySelected
                                            ? primaryColor
                                            : textColorSecondary,
                                  ),
                                  title: Text(
                                    '${driver.firstName} ${driver.lastName}',
                                  ),
                                  onTap: () {
                                    setState(() {
                                      selectedDriver = driver;
                                    });
                                    Navigator.pop(context);
                                  },
                                  dense: true,
                                  selected: isCurrentlySelected,
                                  selectedTileColor: primaryColor.withOpacity(
                                    0.1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardBackgroundColor,
        foregroundColor: textColorPrimary,
        elevation: 1.0,
        title: const Text(
          'Reportes de Viajes',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: Icon(Icons.menu, color: iconColor),
          onPressed: () => setState(() => isSidebarVisible = true),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildFilterSection(),

              Expanded(
                child:
                    loading
                        ? Center(
                          child: CircularProgressIndicator(color: primaryColor),
                        )
                        : trips.isEmpty
                        ? _buildEmptyState()
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

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        border: Border(bottom: BorderSide(color: borderColor.withOpacity(0.5))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: _buildDateSelector(true)),
              const SizedBox(width: 12),
              Expanded(child: _buildDateSelector(false)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDriverSelector()),
              const SizedBox(width: 12),
              _buildSearchButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(bool isStartDate) {
    return InkWell(
      onTap: () => _selectDate(context, isStartDate),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: inputBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.calendar, size: 20, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _displayDateFormat.format(isStartDate ? startDate : endDate),
                style: TextStyle(fontSize: 14, color: textColorPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(LucideIcons.chevronDown, size: 18, color: textColorSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverSelector() {
    return InkWell(
      onTap: _showDriverSelectionModal,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: inputBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(
              selectedDriver == null ? LucideIcons.users : LucideIcons.user,
              size: 20,
              color: iconColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selectedDriver == null
                    ? 'Todos los Choferes'
                    : '${selectedDriver!.firstName} ${selectedDriver!.lastName}',
                style: TextStyle(fontSize: 14, color: textColorPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(LucideIcons.chevronDown, size: 18, color: textColorSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    return ElevatedButton.icon(
      icon: Icon(LucideIcons.search, size: 18, color: buttonTextColor),
      label: Text('Buscar', style: TextStyle(color: buttonTextColor)),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: buttonTextColor.withOpacity(0.8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 2,
      ),
      onPressed: loading ? null : _fetchTrips,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.fileText, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No se encontraron viajes',
            style: TextStyle(fontSize: 18, color: textColorSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Intenta ajustar los filtros de fecha o conductor.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(Trip trip) {
    String tripDate = '';
    try {
      tripDate = _displayDateFormat.format(
        DateTime.parse(trip.createdAt).toLocal(),
      );
    } catch (e) {
      developer.log('Error formateando fecha del viaje ${trip.id}: $e');
      tripDate = 'Fecha inválida';
    }
    final String tripPrice = currencyFormatter.format(trip.price);

    final String driverName =
        trip.driver_profiles != null
            ? '${trip.driver_profiles!.first_name} ${trip.driver_profiles!.last_name}'
            : 'No asignado';
    final String operatorName =
        trip.operator_profiles != null
            ? '${trip.operator_profiles!.first_name} ${trip.operator_profiles!.last_name}'
            : 'No asignado';

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.calendar,
                      size: 16,
                      color: textColorSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tripDate,
                      style: TextStyle(
                        fontSize: 14,
                        color: textColorSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  tripPrice,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: borderColor.withOpacity(0.5)),
            const SizedBox(height: 12),

            _buildDetailRow(
              icon: LucideIcons.mapPin,
              label: "Origen:",
              value: trip.origin,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              icon: LucideIcons.flag,
              label: "Destino:",
              value: trip.destination,
            ),
            const SizedBox(height: 12),
            Divider(color: borderColor.withOpacity(0.5)),
            const SizedBox(height: 12),

            _buildDetailRow(
              icon: LucideIcons.user,
              label: "Chofer:",
              value: driverName,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              icon: LucideIcons.userCog,
              label: "Operador:",
              value: operatorName,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: textColorSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: textColorSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : 'N/A',
            style: TextStyle(fontSize: 14, color: textColorPrimary),
          ),
        ),
      ],
    );
  }
}
