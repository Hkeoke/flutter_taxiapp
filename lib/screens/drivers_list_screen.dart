import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:developer' as developer;
import '../services/api.dart';
import '../widgets/sidebar.dart';
import '../screens/driver_trips_analytics_screen.dart';

class DriversListScreen extends StatefulWidget {
  const DriversListScreen({Key? key}) : super(key: key);

  @override
  _DriversListScreenState createState() => _DriversListScreenState();
}

class _DriversListScreenState extends State<DriversListScreen> {
  bool isSidebarVisible = false;
  bool loading = true;
  bool refreshing = false;
  List<DriverProfile> drivers = [];
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
  }

  Future<void> _fetchDrivers() async {
    try {
      final driverService = DriverService();
      final response = await driverService.getAllDrivers();

      if (mounted) {
        setState(() {
          drivers = response;
          loading = false;
          refreshing = false;
        });
      }
    } catch (error) {
      developer.log('Error cargando conductores: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron cargar los choferes')),
        );
        setState(() {
          loading = false;
          refreshing = false;
        });
      }
    }
  }

  Future<void> _handleToggleActive(String driverId, bool currentStatus) async {
    try {
      final driverService = DriverService();
      await driverService.deactivateUser(driverId, !currentStatus);

      await _fetchDrivers();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chofer ${currentStatus ? 'desactivado' : 'activado'} correctamente',
          ),
        ),
      );
    } catch (error) {
      developer.log('Error al cambiar estado del chofer: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el estado del chofer'),
        ),
      );
    }
  }

  Future<void> _handleDelete(String driverId) async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar'),
            content: const Text(
              '¿Estás seguro de que quieres eliminar este chofer?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    final authService = AuthService();
                    await authService.deleteUser(driverId);
                    await _fetchDrivers();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Chofer eliminado correctamente'),
                      ),
                    );
                  } catch (error) {
                    developer.log('Error al eliminar chofer: $error');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No se pudo eliminar el chofer'),
                      ),
                    );
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );
  }

  List<DriverProfile> get filteredDrivers {
    if (searchQuery.isEmpty) {
      return drivers;
    }

    final query = searchQuery.toLowerCase();
    return drivers.where((driver) {
      final fullName = "${driver.firstName} ${driver.lastName}".toLowerCase();
      final phone = driver.phoneNumber.toLowerCase();
      final vehicle = driver.vehicle.toLowerCase();

      return fullName.contains(query) ||
          phone.contains(query) ||
          vehicle.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Lista de Choferes'),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => setState(() => isSidebarVisible = true),
          ),
        ),
        body: const Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Choferes'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => setState(() => isSidebarVisible = true),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Barra de búsqueda
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: TextField(
                  controller: searchController,
                  onChanged: (value) => setState(() => searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, teléfono o vehículo...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),

              // Lista de conductores
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    setState(() => refreshing = true);
                    await _fetchDrivers();
                  },
                  color: Colors.red,
                  child:
                      filteredDrivers.isEmpty
                          ? Center(
                            child: Text(
                              searchQuery.isNotEmpty
                                  ? 'No se encontraron choferes con esa búsqueda'
                                  : 'No hay choferes registrados',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredDrivers.length,
                            itemBuilder: (context, index) {
                              final driver = filteredDrivers[index];
                              return _buildDriverCard(driver);
                            },
                          ),
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

  Widget _buildDriverCard(DriverProfile driver) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado del conductor
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      LucideIcons.user,
                      size: 16,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${driver.firstName} ${driver.lastName}",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color:
                                    (driver.users != null &&
                                            driver.users['active'] == true)
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              (driver.users != null &&
                                      driver.users['active'] == true)
                                  ? 'Activo'
                                  : 'Inactivo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color:
                                    (driver.users != null &&
                                            driver.users['active'] == true)
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Detalles del conductor
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.phone,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        driver.phoneNumber,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.car,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        driver.vehicle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Acciones
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Botón de editar
                _buildActionButton(
                  icon: LucideIcons.pencil,
                  color: const Color(0xFF0891B2),
                  backgroundColor: const Color(0xFFFEF2F2),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/editDriverScreen',
                      arguments: driver,
                    );
                  },
                ),

                // Botón de activar/desactivar
                _buildActionButton(
                  icon:
                      (driver.users != null && driver.users['active'] == true)
                          ? LucideIcons.powerOff
                          : LucideIcons.power,
                  color:
                      (driver.users != null && driver.users['active'] == true)
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF22C55E),
                  backgroundColor:
                      (driver.users != null && driver.users['active'] == true)
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFDCFCE7),
                  onPressed:
                      () => _handleToggleActive(
                        driver.id,
                        (driver.users != null &&
                            driver.users['active'] == true),
                      ),
                ),

                // Botón de eliminar
                _buildActionButton(
                  icon: LucideIcons.trash,
                  color: const Color(0xFFEF4444),
                  backgroundColor: const Color(0xFFFEE2E2),
                  onPressed: () => _handleDelete(driver.id),
                ),

                // Botón de estadísticas
                _buildActionButton(
                  icon: LucideIcons.trendingUp,
                  color: const Color(0xFF0891B2),
                  backgroundColor: const Color(0xFFF0FDF4),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                DriverTripsAnalyticsScreen(driverId: driver.id),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: color),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }
}
