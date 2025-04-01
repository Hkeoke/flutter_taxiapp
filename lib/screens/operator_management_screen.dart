import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../widgets/sidebar.dart';

class OperatorManagementScreen extends StatefulWidget {
  const OperatorManagementScreen({Key? key}) : super(key: key);

  @override
  _OperatorManagementScreenState createState() =>
      _OperatorManagementScreenState();
}

class _OperatorManagementScreenState extends State<OperatorManagementScreen> {
  bool isSidebarVisible = false;

  final Color primaryColor = Colors.red;
  final Color scaffoldBackgroundColor = Colors.grey.shade100;
  final Color cardBackgroundColor = Colors.white;
  final Color textColorPrimary = Colors.black87;
  final Color textColorSecondary = Colors.grey.shade600;
  final Color iconColor = Colors.red;
  final Color listTileIconColor = Colors.red.shade400;
  final Color borderColor = Colors.grey.shade300;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Gestión de Operadores',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: cardBackgroundColor,
        foregroundColor: textColorPrimary,
        elevation: 1.0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: iconColor),
          onPressed: () => setState(() => isSidebarVisible = true),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                _buildManagementCard(
                  title: 'Gestión de Operadores',
                  items: [
                    _buildMenuItem(
                      icon: LucideIcons.userPlus,
                      title: 'Crear Nuevo Operador',
                      onTap:
                          () => Navigator.pushNamed(
                            context,
                            '/createOperatorScreen',
                          ),
                    ),
                    _buildMenuItem(
                      icon: LucideIcons.users,
                      title: 'Lista de Operadores',
                      onTap:
                          () => Navigator.pushNamed(
                            context,
                            '/operatorsListScreen',
                          ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                _buildManagementCard(
                  title: 'Reportes',
                  items: [
                    _buildMenuItem(
                      icon: LucideIcons.chartBar,
                      title: 'Reportes por Operador',
                      onTap:
                          () => Navigator.pushNamed(
                            context,
                            '/operatorReportsScreen',
                          ),
                    ),
                  ],
                ),
              ],
            ),
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

  Widget _buildManagementCard({
    required String title,
    required List<Widget> items,
  }) {
    return Card(
      elevation: 2.0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColorPrimary,
                ),
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) => items[index],
              separatorBuilder:
                  (context, index) => Divider(
                    height: 1,
                    thickness: 0.5,
                    color: borderColor.withOpacity(0.5),
                    indent: 16,
                    endIndent: 16,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: listTileIconColor, size: 22),
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
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 4.0,
      ),
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
