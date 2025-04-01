import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class OperatorManagementScreen extends StatelessWidget {
  const OperatorManagementScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Operadores'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección de Gestión de Operadores
            _buildSection(context, 'Gestión de Operadores', [
              _buildMenuItem(
                context,
                LucideIcons.plus,
                'Crear Nuevo Operador',
                () => Navigator.pushNamed(context, '/createOperatorScreen'),
              ),
              _buildMenuItem(
                context,
                LucideIcons.user,
                'Lista de Operadores',
                () => Navigator.pushNamed(context, '/operatorsListScreen'),
              ),
            ]),

            const SizedBox(height: 16),

            // Sección de Reportes
            _buildSection(context, 'Reportes', [
              _buildMenuItem(
                context,
                LucideIcons.calendar,
                'Reportes por Período',
                () => Navigator.pushNamed(context, '/operatorReports'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> items) {
    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          ...items,
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String text,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFDC2626), width: 1),
          ),
        ),
        child: Row(
          children: [
            // Icono y texto
            Expanded(
              child: Row(
                children: [
                  Icon(icon, size: 24, color: const Color(0xFFDC2626)),
                  const SizedBox(width: 12),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),

            // Flecha derecha
            Icon(
              LucideIcons.chevronRight,
              size: 20,
              color: const Color(0xFFDC2626),
            ),
          ],
        ),
      ),
    );
  }
}
