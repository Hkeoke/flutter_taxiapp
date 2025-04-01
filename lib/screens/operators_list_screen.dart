import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:developer' as developer;
import '../services/api.dart';

class OperatorsListScreen extends StatefulWidget {
  const OperatorsListScreen({Key? key}) : super(key: key);

  @override
  _OperatorsListScreenState createState() => _OperatorsListScreenState();
}

class _OperatorsListScreenState extends State<OperatorsListScreen> {
  bool loading = true;
  List<OperatorProfile> operators = [];

  @override
  void initState() {
    super.initState();
    fetchOperators();
  }

  Future<void> fetchOperators() async {
    try {
      setState(() {
        loading = true;
      });

      final operatorService = OperatorService();
      final response = await operatorService.getAllOperators();

      setState(() {
        operators = response;
        loading = false;
      });
    } catch (error) {
      developer.log('Error al cargar operadores: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar los operadores')),
      );
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> handleToggleActive(String operatorId, bool currentStatus) async {
    try {
      final operatorService = OperatorService();
      await operatorService.updateOperatorStatus(operatorId, !currentStatus);
      fetchOperators();
    } catch (error) {
      developer.log('Error al actualizar estado: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el estado del operador'),
        ),
      );
    }
  }

  Future<void> handleDelete(String operatorId) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar'),
          content: const Text('¿Está seguro que desea eliminar este operador?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  final authService = AuthService();
                  await authService.deleteUser(operatorId);
                  fetchOperators();
                } catch (error) {
                  developer.log('Error al eliminar operador: $error');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No se pudo eliminar el operador'),
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Operadores'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : _buildOperatorsList(),
    );
  }

  Widget _buildOperatorsList() {
    if (operators.isEmpty) {
      return const Center(
        child: Text(
          'No hay operadores registrados',
          style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: operators.length,
      itemBuilder: (context, index) {
        final operator = operators[index];
        return _buildOperatorCard(operator);
      },
    );
  }

  Widget _buildOperatorCard(OperatorProfile operator) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 2,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // Información del operador
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color:
                              operator.users?['active'] == true
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFF94A3B8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${operator.firstName} ${operator.lastName}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    operator.identityCard,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    operator.phoneNumber ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            // Acciones
            Row(
              children: [
                _buildActionButton(
                  icon: LucideIcons.pencil,
                  color: const Color(0xFF64748B),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/editOperatorScreen',
                      arguments: operator,
                    );
                  },
                ),
                const SizedBox(width: 4),
                _buildActionButton(
                  icon:
                      operator.users?['active'] == true
                          ? LucideIcons.powerOff
                          : LucideIcons.power,
                  color: const Color(0xFF64748B),
                  onTap:
                      () => handleToggleActive(
                        operator.id,
                        operator.users?['active'] == true,
                      ),
                ),
                const SizedBox(width: 4),
                _buildActionButton(
                  icon: LucideIcons.trash,
                  color: const Color(0xFFEF4444),
                  onTap: () => handleDelete(operator.id),
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}
