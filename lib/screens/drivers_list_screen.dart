import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:developer' as developer;
import '../services/api.dart';
import '../widgets/sidebar.dart';
import '../screens/driver_trips_analytics_screen.dart';
import 'package:intl/intl.dart';

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

  final Color primaryColor = Colors.red;
  final Color scaffoldBackgroundColor = Colors.grey.shade100;
  final Color cardBackgroundColor = Colors.white;
  final Color textColorPrimary = Colors.black87;
  final Color textColorSecondary = Colors.grey.shade600;
  final Color iconColor = Colors.red;
  final Color borderColor = Colors.grey.shade300;
  final Color errorColor = Colors.red.shade700;
  final Color successColor = Colors.green.shade600;
  final Color inactiveColor = Colors.grey.shade500;
  final Color searchBackgroundColor = Colors.grey.shade200;

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchDrivers({bool isRefresh = false}) async {
    if (!isRefresh && !mounted) return;
    if (!isRefresh) {
      setState(() {
        loading = true;
      });
    } else {
      setState(() {
        refreshing = true;
      });
    }

    try {
      final driverService = DriverService();
      final response = await driverService.getAllDrivers();

      if (mounted) {
        setState(() {
          drivers = response;
          drivers.sort(
            (a, b) => '${a.firstName} ${a.lastName}'.toLowerCase().compareTo(
              '${b.firstName} ${b.lastName}'.toLowerCase(),
            ),
          );
          loading = false;
          refreshing = false;
        });
      }
    } catch (error) {
      developer.log('Error cargando conductores: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudieron cargar los choferes'),
            backgroundColor: errorColor,
          ),
        );
        setState(() {
          loading = false;
          refreshing = false;
        });
      }
    }
  }

  Future<void> _handleToggleActive(DriverProfile driver) async {
    final bool currentStatus = driver.users?['active'] ?? false;
    final String actionText = currentStatus ? 'desactivar' : 'activar';
    final String driverName = '${driver.firstName} ${driver.lastName}';

    bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirmar ${actionText.capitalize()}'),
            content: Text(
              '¿Estás seguro de que quieres $actionText a $driverName?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: currentStatus ? errorColor : successColor,
                ),
                child: Text(actionText.capitalize()),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${actionText.capitalize().substring(0, actionText.length - 1)}ando chofer...',
        ),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final driverService = DriverService();
      await driverService.deactivateUser(driver.id, !currentStatus);

      await _fetchDrivers(isRefresh: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Chofer ${currentStatus ? 'desactivado' : 'activado'} correctamente',
            ),
            backgroundColor: successColor,
          ),
        );
      }
    } catch (error) {
      developer.log('Error al cambiar estado del chofer: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo actualizar el estado del chofer'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  Future<void> _handleDelete(DriverProfile driver) async {
    final String driverName = '${driver.firstName} ${driver.lastName}';

    bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar Eliminación'),
            content: Text(
              '¿Estás seguro de que quieres eliminar a $driverName?\nEsta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: errorColor),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Eliminando chofer...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final authService = AuthService();
      await authService.deleteUser(driver.id);

      await _fetchDrivers(isRefresh: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chofer eliminado correctamente'),
            backgroundColor: successColor,
          ),
        );
      }
    } catch (error) {
      developer.log('Error al eliminar chofer: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo eliminar el chofer'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  List<DriverProfile> get filteredDrivers {
    if (searchQuery.isEmpty) {
      return drivers;
    }
    final query = searchQuery.toLowerCase().trim();
    return drivers.where((driver) {
      final fullName = "${driver.firstName} ${driver.lastName}".toLowerCase();
      final phone = driver.phoneNumber.toLowerCase();
      final vehicle = driver.vehicle?.toLowerCase() ?? '';

      return fullName.contains(query) ||
          phone.contains(query) ||
          vehicle.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Lista de Choferes',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: cardBackgroundColor,
        foregroundColor: textColorPrimary,
        elevation: 1.0,
        leading: IconButton(
          icon: Icon(LucideIcons.menu, color: iconColor),
          onPressed: () => setState(() => isSidebarVisible = true),
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.userPlus, color: primaryColor),
            tooltip: 'Crear Chofer',
            onPressed:
                () => Navigator.pushNamed(
                  context,
                  '/createDriverScreen',
                ).then((_) => _fetchDrivers()),
          ),
          IconButton(
            icon: Icon(LucideIcons.refreshCw, color: primaryColor, size: 20),
            tooltip: 'Refrescar',
            onPressed:
                loading || refreshing
                    ? null
                    : () => _fetchDrivers(isRefresh: true),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child:
                    loading
                        ? Center(
                          child: CircularProgressIndicator(color: primaryColor),
                        )
                        : RefreshIndicator(
                          color: primaryColor,
                          onRefresh: () => _fetchDrivers(isRefresh: true),
                          child:
                              filteredDrivers.isEmpty
                                  ? _buildEmptyState(searchQuery.isNotEmpty)
                                  : ListView.builder(
                                    padding: const EdgeInsets.all(12.0),
                                    itemCount: filteredDrivers.length,
                                    itemBuilder: (context, index) {
                                      return _buildDriverCard(
                                        filteredDrivers[index],
                                      );
                                    },
                                  ),
                        ),
              ),
            ],
          ),
          if (isSidebarVisible)
            Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: Sidebar(
                isVisible: isSidebarVisible,
                onClose: () => setState(() => isSidebarVisible = false),
                role: 'admin',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: cardBackgroundColor,
      child: TextField(
        controller: searchController,
        onChanged: (value) => setState(() => searchQuery = value),
        style: TextStyle(color: textColorPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre, teléfono o vehículo...',
          hintStyle: TextStyle(
            color: textColorSecondary.withOpacity(0.8),
            fontSize: 15,
          ),
          filled: true,
          fillColor: searchBackgroundColor,
          prefixIcon: Icon(
            LucideIcons.search,
            size: 20,
            color: textColorSecondary,
          ),
          suffixIcon:
              searchQuery.isNotEmpty
                  ? IconButton(
                    icon: Icon(
                      LucideIcons.x,
                      size: 18,
                      color: textColorSecondary,
                    ),
                    onPressed: () {
                      searchController.clear();
                      setState(() => searchQuery = '');
                    },
                  )
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildDriverCard(DriverProfile driver) {
    final bool isActive = driver.users?['active'] ?? false;
    final String driverName = '${driver.firstName} ${driver.lastName}';

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    driverName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColorPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Chip(
                  avatar: Icon(
                    isActive
                        ? LucideIcons.circleCheck
                        : LucideIcons.circleSlash,
                    size: 14,
                    color: isActive ? successColor : inactiveColor,
                  ),
                  label: Text(isActive ? 'Activo' : 'Inactivo'),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isActive ? successColor : inactiveColor,
                  ),
                  backgroundColor:
                      isActive
                          ? successColor.withOpacity(0.1)
                          : inactiveColor.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 0,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(color: borderColor.withOpacity(0.5)),
            const SizedBox(height: 10),

            _buildDetailRow(icon: LucideIcons.phone, value: driver.phoneNumber),
            const SizedBox(height: 6),
            _buildDetailRow(
              icon: LucideIcons.car,
              value: driver.vehicle ?? 'N/A',
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildActionButton(
                  icon: LucideIcons.pencil,
                  tooltip: 'Editar',
                  color: Colors.blue.shade700,
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/editDriverScreen',
                      arguments: driver,
                    ).then((_) => _fetchDrivers());
                  },
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: isActive ? LucideIcons.powerOff : LucideIcons.power,
                  tooltip: isActive ? 'Desactivar' : 'Activar',
                  color: isActive ? errorColor : successColor,
                  onPressed: () => _handleToggleActive(driver),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: LucideIcons.trash2,
                  tooltip: 'Eliminar',
                  color: errorColor,
                  onPressed: () => _handleDelete(driver),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: LucideIcons.chartBar,
                  tooltip: 'Ver Estadísticas',
                  color: Colors.teal.shade600,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => DriverTripsAnalyticsScreen(
                              driverId: driver.id,
                              driverName: driverName,
                            ),
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

  Widget _buildDetailRow({required IconData icon, required String value}) {
    return Row(
      children: [
        Icon(icon, size: 15, color: textColorSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, color: textColorSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 20, color: color),
      onPressed: onPressed,
      tooltip: tooltip,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
      splashRadius: 20,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildEmptyState(bool isSearchResult) {
    final message =
        isSearchResult
            ? 'No se encontraron conductores que coincidan con tu búsqueda.'
            : 'Aún no hay conductores registrados.';
    final icon = isSearchResult ? LucideIcons.searchX : LucideIcons.users;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              isSearchResult ? 'Sin Resultados' : 'Lista Vacía',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColorSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            if (!isSearchResult) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: Icon(LucideIcons.userPlus, size: 18),
                label: Text('Crear Chofer'),
                onPressed:
                    () => Navigator.pushNamed(
                      context,
                      '/createDriverScreen',
                    ).then((_) => _fetchDrivers()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return "";
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
