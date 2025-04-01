import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class Sidebar extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onClose;
  final String role;

  const Sidebar({
    Key? key,
    required this.isVisible,
    required this.onClose,
    required this.role,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return Container();

    return Stack(
      children: [
        // Overlay oscuro
        GestureDetector(
          onTap: onClose,
          child: Container(
            color: Colors.black.withOpacity(0.5),
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
          ),
        ),
        // Sidebar
        Container(
          width: MediaQuery.of(context).size.width * 0.75,
          height: MediaQuery.of(context).size.height,
          color: Colors.white,
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Menú',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x),
                        onPressed: onClose,
                      ),
                    ],
                  ),
                ),
                // Menú
                Expanded(child: ListView(children: _buildMenuItems(context))),
                // Footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      final authProvider = Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      );
                      authProvider.logout();
                    },
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Color(0xFFEF4444), size: 24),
                        const SizedBox(width: 12),
                        const Text(
                          'Cerrar Sesión',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMenuItems(BuildContext context) {
    final List<Widget> items = [];

    if (role == 'admin') {
      items.addAll([
        _buildMenuItem(
          context,
          'Panel Principal',
          Icons.home,
          () => Navigator.pushReplacementNamed(context, '/adminTabs'),
        ),
        _buildMenuItem(
          context,
          'Gestionar Choferes',
          Icons.people,
          () => Navigator.pushNamed(context, '/driverManagementScreen'),
        ),
        _buildMenuItem(
          context,
          'Gestionar Operadores',
          Icons.people,
          () => Navigator.pushNamed(context, '/operatorManagementScreen'),
        ),
        _buildMenuItem(
          context,
          'Solicitar Viaje',
          Icons.directions_car,
          () => Navigator.pushNamed(context, '/operatorScreen'),
        ),
        _buildMenuItem(
          context,
          'Mapa de Choferes',
          Icons.map,
          () => Navigator.pushNamed(context, '/driverMapScreen'),
        ),
        _buildMenuItem(
          context,
          'Reportes Generales',
          Icons.pie_chart,
          () => Navigator.pushNamed(context, '/generalReportsScreen'),
        ),
        _buildMenuItem(
          context,
          'Gestionar Balances',
          Icons.account_balance_wallet,
          () => Navigator.pushNamed(context, '/adminDriverBalances'),
        ),
      ]);
    } else if (role == 'chofer') {
      items.addAll([
        _buildMenuItem(
          context,
          'Panel Principal',
          Icons.home,
          () => Navigator.pushReplacementNamed(context, '/driverTabs'),
        ),
        _buildMenuItem(
          context,
          'Mis Viajes',
          Icons.assignment,
          () => Navigator.pushNamed(context, '/driverTrips'),
        ),
        _buildMenuItem(
          context,
          'Historial de Balance',
          Icons.history,
          () => Navigator.pushNamed(context, '/driverBalanceHistory'),
        ),
      ]);
    } else if (role == 'operador') {
      items.addAll([
        _buildMenuItem(
          context,
          'Panel Principal',
          Icons.home,
          () => Navigator.pushReplacementNamed(context, '/operatorTabs'),
        ),
        _buildMenuItem(
          context,
          'Mis Viajes',
          Icons.assignment,
          () => Navigator.pushNamed(context, '/operatorTrips'),
        ),
      ]);
    }

    return items;
  }

  Widget _buildMenuItem(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: () {
        onClose();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.red, size: 24),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, color: Color(0xFF334155)),
            ),
          ],
        ),
      ),
    );
  }
}
