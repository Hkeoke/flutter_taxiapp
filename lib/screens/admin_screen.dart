import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';
import '../widgets/sidebar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool isSidebarVisible = false;
  Map<String, dynamic>? stats;
  bool loading = true;
  bool refreshing = false;

  // Define colores para consistencia
  final Color primaryColor = Colors.red;
  final Color scaffoldBackgroundColor = Colors.grey.shade100;
  final Color cardBackgroundColor = Colors.white;
  final Color textColorPrimary = Colors.black87;
  final Color textColorSecondary = Colors.grey.shade600;
  final Color iconColor = Colors.red;
  final Color logoutColor = Colors.red.shade700;
  final Color logoutBackgroundColor = Colors.red.shade50;
  final Color listIconColor = Colors.red.shade600;
  final Color borderColor = Colors.grey.shade300;

  @override
  void initState() {
    super.initState();
    fetchStats();
  }

  Future<void> fetchStats() async {
    // No es necesario resetear loading aquí si solo se llama desde initState y handleRefresh
    // setState(() => loading = true); // Podría causar un rebuild innecesario si ya está cargando
    try {
      final analyticsService = AnalyticsService();
      final dashboardStats = await analyticsService.getAdminDashboardStats();
      if (mounted) {
        // Verificar si el widget sigue montado
        setState(() {
          stats = dashboardStats;
          loading = false;
          refreshing = false;
        });
      }
    } catch (error) {
      developer.log('Error fetching stats: $error');
      if (mounted) {
        // Verificar si el widget sigue montado
        setState(() {
          loading = false; // Asegúrate de detener la carga incluso si hay error
          refreshing = false;
        });
        // Mostrar un mensaje de error al usuario
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar estadísticas: ${error.toString()}'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  void handleRefresh() {
    if (!refreshing) {
      // Evitar múltiples refrescos simultáneos
      setState(() {
        refreshing = true;
      });
      fetchStats();
    }
  }

  Future<void> handleLogout() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
      // La navegación debería ocurrir automáticamente por el listener del AuthProvider
    } catch (error) {
      developer.log('Error logging out: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: ${error.toString()}'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.user?.role ?? 'desconocido';

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardBackgroundColor,
        foregroundColor: textColorPrimary,
        elevation: 1.0,
        title: const Text(
          'Panel de Admin',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: Icon(LucideIcons.menu, color: iconColor),
          onPressed: () {
            setState(() {
              isSidebarVisible = !isSidebarVisible;
            });
          },
          tooltip: 'Menú',
        ),
        actions: [
          IconButton(
            icon:
                refreshing
                    ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: primaryColor,
                        strokeWidth: 2.5,
                      ),
                    )
                    : Icon(Icons.refresh, color: iconColor),
            onPressed: refreshing ? null : handleRefresh,
            tooltip: 'Refrescar datos',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Builder(
              builder: (context) {
                if (loading) {
                  return Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                } else {
                  return _buildAdminContent();
                }
              },
            ),
          ),
          if (isSidebarVisible)
            Sidebar(
              isVisible: isSidebarVisible,
              onClose: () => setState(() => isSidebarVisible = false),
              role: userRole,
            ),
        ],
      ),
    );
  }

  Widget _buildAdminContent() {
    return RefreshIndicator(
      onRefresh: () async => handleRefresh(),
      color: primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildManagementCard(),
            const SizedBox(height: 16),
            _buildStatsCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementCard() {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestión de Usuarios',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColorPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            _buildManagementListItem(
              icon: LucideIcons.users,
              title: 'Gestionar Choferes',
              routeName: '/driverManagementScreen',
            ),
            const Divider(),
            _buildManagementListItem(
              icon: LucideIcons.userCog,
              title: 'Gestionar Operadores',
              routeName: '/operatorManagementScreen',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementListItem({
    required IconData icon,
    required String title,
    required String routeName,
  }) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, routeName),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, color: listIconColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 16, color: textColorPrimary),
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              color: Colors.grey.shade400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estadísticas Clave',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColorPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.local_taxi,
                  label: 'Viajes Hoy',
                  value: stats?['tripsToday'] ?? 0,
                ),
                _buildStatItem(
                  icon: Icons.person_pin_circle,
                  label: 'Choferes Activos',
                  value: stats?['activeDrivers'] ?? 0,
                ),
                _buildStatItem(
                  icon: Icons.group,
                  label: 'Total Usuarios',
                  value: stats?['totalUsers'] ?? 0,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required int value,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: textColorSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
