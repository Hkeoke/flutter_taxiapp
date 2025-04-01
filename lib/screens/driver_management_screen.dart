import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../widgets/sidebar.dart';

class DriverManagementScreen extends StatefulWidget {
  const DriverManagementScreen({Key? key}) : super(key: key);

  @override
  _DriverManagementScreenState createState() => _DriverManagementScreenState();
}

class _DriverManagementScreenState extends State<DriverManagementScreen> {
  bool isSidebarVisible = false;

  // Define colores para consistencia (iguales a otras pantallas admin)
  final Color primaryColor = Colors.red;
  final Color scaffoldBackgroundColor = Colors.grey.shade100;
  final Color cardBackgroundColor = Colors.white;
  final Color textColorPrimary = Colors.black87;
  final Color textColorSecondary = Colors.grey.shade600;
  final Color iconColor = Colors.red;
  final Color listTileIconColor =
      Colors.red.shade400; // Un tono ligeramente diferente para iconos de lista
  final Color borderColor = Colors.grey.shade300;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardBackgroundColor,
        foregroundColor: textColorPrimary,
        elevation: 1.0,
        title: const Text(
          'Gestión de Choferes',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          // Usar icono rojo consistente para abrir sidebar
          icon: Icon(Icons.menu, color: iconColor),
          onPressed: () => setState(() => isSidebarVisible = true),
        ),
      ),
      body: Stack(
        children: [
          // Contenido principal con padding
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              // Usar ListView en lugar de SingleChildScrollView+Column para mejor rendimiento si hay muchas tarjetas
              children: [
                // Sección de Gestión de Choferes
                _buildManagementCard(
                  title: 'Gestión de Choferes',
                  items: [
                    _buildMenuItem(
                      icon: LucideIcons.userPlus, // Icono más específico
                      title: 'Crear Nuevo Chofer',
                      onTap:
                          () => Navigator.pushNamed(
                            context,
                            '/createDriverScreen',
                          ),
                    ),
                    _buildMenuItem(
                      icon: LucideIcons.users, // Icono para lista
                      title: 'Lista de Choferes',
                      onTap:
                          () => Navigator.pushNamed(
                            context,
                            '/driversListScreen',
                          ),
                    ),
                    _buildMenuItem(
                      // Añadido: Gestión de Balances
                      icon: LucideIcons.wallet,
                      title: 'Balances de Choferes',
                      onTap:
                          () => Navigator.pushNamed(
                            context,
                            '/adminDriverBalances',
                          ),
                    ),
                  ],
                ),

                const SizedBox(height: 16), // Espacio entre tarjetas
                // Sección de Reportes
                _buildManagementCard(
                  title: 'Reportes',
                  items: [
                    _buildMenuItem(
                      icon: LucideIcons.calendarClock, // Icono más específico
                      title: 'Reportes por Período',
                      onTap:
                          () => Navigator.pushNamed(context, '/driverReports'),
                    ),
                    // Puedes añadir más opciones de reportes aquí
                  ],
                ),
                const SizedBox(height: 16), // Espacio adicional al final
              ],
            ),
          ),

          // Sidebar (se mantiene igual)
          if (isSidebarVisible)
            Sidebar(
              isVisible: isSidebarVisible,
              onClose: () => setState(() => isSidebarVisible = false),
              role: 'admin', // Asegúrate que el rol sea correcto
            ),
        ],
      ),
    );
  }

  // Widget para construir una tarjeta de gestión
  Widget _buildManagementCard({
    required String title,
    required List<Widget> items,
  }) {
    return Card(
      elevation: 2.0, // Sombra sutil
      margin: EdgeInsets.zero, // El padding se maneja externamente
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 16.0,
          horizontal: 8.0,
        ), // Padding interno ajustado
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                bottom: 8.0,
              ), // Padding para el título
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColorPrimary,
                ),
              ),
            ),
            // Usar ListView.separated para añadir divisores automáticamente
            ListView.separated(
              shrinkWrap:
                  true, // Para que funcione dentro de otra lista/columna
              physics:
                  const NeverScrollableScrollPhysics(), // Deshabilitar scroll interno
              itemCount: items.length,
              itemBuilder: (context, index) => items[index],
              separatorBuilder:
                  (context, index) => Divider(
                    height: 1,
                    thickness: 0.5,
                    color: borderColor.withOpacity(0.5),
                    indent: 16, // Indentación del divisor
                    endIndent: 16,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget para construir un elemento de menú usando ListTile
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: listTileIconColor,
        size: 22,
      ), // Icono a la izquierda
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: textColorPrimary.withOpacity(0.9),
        ),
      ),
      trailing: Icon(
        LucideIcons.chevronRight,
        color: textColorSecondary,
        size: 18,
      ), // Flecha a la derecha
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 4.0,
      ), // Ajustar padding
      dense: true, // Hacerlo un poco más compacto
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ), // Opcional: bordes redondeados al hacer tap
    );
  }
}
