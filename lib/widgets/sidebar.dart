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

  // --- Colores Estándar (Idealmente vendrían del Theme) ---
  static const Color primaryColor = Colors.red;
  static const Color sidebarBackgroundColor = Colors.white;
  static const Color overlayColor = Colors.black54;
  static const Color textColorPrimary = Colors.black87;
  static const Color textColorSecondary =
      Colors.grey; // Para iconos/texto secundario
  static const Color iconColor = primaryColor; // Iconos principales del menú
  static const Color logoutColor = Colors.red; // Color para logout
  static const Color borderColor = Colors.black12; // Borde sutil

  @override
  Widget build(BuildContext context) {
    // Usar AnimatedPositioned o similar para una transición suave (Opcional)
    // Por ahora, solo mostramos/ocultamos
    if (!isVisible) return const SizedBox.shrink();

    return Stack(
      children: [
        // Overlay oscuro
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: Container(color: overlayColor),
          ),
        ),
        // Sidebar
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width:
                MediaQuery.of(context).size.width * 0.75, // Ancho del sidebar
            decoration: BoxDecoration(
              color: sidebarBackgroundColor,
              boxShadow: [
                // Sombra para darle profundidad
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: SafeArea(
              // Evitar notch/barra de estado
              child: Column(
                children: [
                  // Header
                  _buildHeader(context),
                  // Separador
                  const Divider(height: 1, color: borderColor),
                  // Menú
                  Expanded(
                    child: ListView(
                      padding:
                          EdgeInsets.zero, // Sin padding extra del ListView
                      children: _buildMenuItems(context),
                    ),
                  ),
                  // Separador
                  const Divider(height: 1, color: borderColor),
                  // Footer (Logout)
                  _buildFooter(context),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Widget para el Header
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12), // Ajustar padding
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Menú',
            style: TextStyle(
              fontSize: 18, // Tamaño ajustado
              fontWeight: FontWeight.w600, // Peso semibold
              color: textColorPrimary,
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.x, size: 22), // Icono Lucide
            color: textColorSecondary, // Color secundario
            onPressed: onClose,
            tooltip: 'Cerrar Menú',
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  // Widget para el Footer (Logout)
  Widget _buildFooter(BuildContext context) {
    return ListTile(
      // Usar ListTile para consistencia
      leading: const Icon(LucideIcons.logOut, color: logoutColor, size: 22),
      title: const Text(
        'Cerrar Sesión',
        style: TextStyle(
          fontSize: 15,
          color: logoutColor, // Color rojo
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        onClose(); // Cerrar sidebar primero
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.logout();
        // Navegar a login después de logout (AuthProvider debería manejar esto)
      },
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      dense: true,
    );
  }

  List<Widget> _buildMenuItems(BuildContext context) {
    final List<Widget> items = [];

    // Definir iconos Lucide para cada rol
    final Map<String, IconData> adminIcons = {
      'Panel Principal': LucideIcons.layoutDashboard,
      'Gestionar Choferes': LucideIcons.users,
      'Gestionar Operadores':
          LucideIcons.userCog, // Icono diferente para operadores
      'Solicitar Viaje': LucideIcons.mapPin, // Icono más específico
      'Mapa de Choferes': LucideIcons.map,
      'Reportes Generales': LucideIcons.chartPie,
      'Gestionar Balances': LucideIcons.wallet,
    };

    final Map<String, IconData> driverIcons = {
      'Panel Principal': LucideIcons.layoutDashboard,
      'Mis Viajes': LucideIcons.route, // Icono más específico
      'Historial de Balance': LucideIcons.history,
    };

    final Map<String, IconData> operatorIcons = {
      'Panel Principal': LucideIcons.layoutDashboard,
      'Mis Viajes': LucideIcons.route,
    };

    if (role == 'admin') {
      items.addAll([
        _buildMenuItem(
          context,
          'Panel Principal',
          adminIcons['Panel Principal']!,
          () => Navigator.pushReplacementNamed(context, '/adminTabs'),
        ),
        _buildMenuItem(
          context,
          'Gestionar Choferes',
          adminIcons['Gestionar Choferes']!,
          () => Navigator.pushNamed(context, '/driverManagementScreen'),
        ),
        _buildMenuItem(
          context,
          'Gestionar Operadores',
          adminIcons['Gestionar Operadores']!,
          () => Navigator.pushNamed(context, '/operatorManagementScreen'),
        ),
        _buildMenuItem(
          context,
          'Solicitar Viaje',
          adminIcons['Solicitar Viaje']!,
          () => Navigator.pushNamed(context, '/operatorScreen'),
        ), // Asumiendo que admin puede solicitar
        _buildMenuItem(
          context,
          'Mapa de Choferes',
          adminIcons['Mapa de Choferes']!,
          () => Navigator.pushNamed(context, '/driverMapScreen'),
        ),
        _buildMenuItem(
          context,
          'Reportes Generales',
          adminIcons['Reportes Generales']!,
          () => Navigator.pushNamed(context, '/generalReportsScreen'),
        ),
        _buildMenuItem(
          context,
          'Gestionar Balances',
          adminIcons['Gestionar Balances']!,
          () => Navigator.pushNamed(context, '/adminDriverBalances'),
        ),
      ]);
    } else if (role == 'chofer') {
      items.addAll([
        _buildMenuItem(
          context,
          'Panel Principal',
          driverIcons['Panel Principal']!,
          () => Navigator.pushReplacementNamed(context, '/driverTabs'),
        ),
        _buildMenuItem(
          context,
          'Mis Viajes',
          driverIcons['Mis Viajes']!,
          () => Navigator.pushNamed(context, '/driverTrips'),
        ),
        _buildMenuItem(
          context,
          'Historial de Balance',
          driverIcons['Historial de Balance']!,
          () => Navigator.pushNamed(context, '/driverBalanceHistory'),
        ),
      ]);
    } else if (role == 'operador') {
      items.addAll([
        _buildMenuItem(
          context,
          'Panel Principal',
          operatorIcons['Panel Principal']!,
          () => Navigator.pushReplacementNamed(context, '/operatorTabs'),
        ),
        _buildMenuItem(
          context,
          'Mis Viajes',
          operatorIcons['Mis Viajes']!,
          () => Navigator.pushNamed(context, '/operatorTrips'),
        ),
        // Añadir aquí más opciones si el operador las necesita
      ]);
    }

    return items;
  }

  // Refactorizado para usar ListTile
  Widget _buildMenuItem(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    // Determinar si esta es la ruta actual (aproximación simple)
    // Una mejor solución implicaría pasar la ruta actual al Sidebar
    final currentRoute = ModalRoute.of(context)?.settings.name;
    bool isSelected = false;
    // TODO: Mejorar la lógica de selección basada en las rutas reales
    // if (currentRoute == '/rutaAsociadaAEsteItem') {
    //    isSelected = true;
    // }

    return Material(
      // Necesario para el InkWell dentro de ListTile
      color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? primaryColor : iconColor,
          size: 22,
        ), // Icono a la izquierda
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15, // Tamaño ajustado
            color:
                isSelected
                    ? primaryColor
                    : textColorPrimary, // Color según selección
            fontWeight:
                isSelected
                    ? FontWeight.w600
                    : FontWeight.w500, // Peso según selección
          ),
        ),
        onTap: () {
          onClose(); // Cerrar sidebar
          // Evitar navegar a la misma página
          // if (!isSelected) {
          onTap();
          // }
        },
        contentPadding: const EdgeInsets.symmetric(
          vertical: 4,
          horizontal: 16,
        ), // Padding ajustado
        dense: true, // Hacerlo más compacto
        // selected: isSelected, // Marcar como seleccionado (afecta estilo)
        // selectedTileColor: primaryColor.withOpacity(0.1), // Color de fondo si está seleccionado
      ),
    );
  }
}
