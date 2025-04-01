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

  // Define colores para consistencia
  final Color primaryColor = Colors.red;
  final Color scaffoldBackgroundColor = Colors.grey.shade100;
  final Color cardBackgroundColor = Colors.white;
  final Color textColorPrimary = Colors.black87;
  final Color textColorSecondary = Colors.grey.shade600;
  final Color iconColor = Colors.red; // Para iconos principales y AppBar
  final Color actionIconColor = Colors.grey.shade700; // Iconos de acción
  final Color deleteIconColor = Colors.red.shade600; // Icono de eliminar
  final Color borderColor = Colors.grey.shade300;
  final Color errorColor = Colors.red.shade700;
  final Color successColor = Colors.green.shade600;
  final Color activeColor = Colors.green.shade500;
  final Color inactiveColor = Colors.grey.shade400;

  @override
  void initState() {
    super.initState();
    fetchOperators();
  }

  Future<void> fetchOperators() async {
    try {
      final operatorService = OperatorService();
      final response = await operatorService.getAllOperators();

      if (mounted) {
        setState(() {
          operators = response;
          // Ordenar alfabéticamente
          operators.sort(
            (a, b) => '${a.firstName} ${a.lastName}'.compareTo(
              '${b.firstName} ${b.lastName}',
            ),
          );
          loading = false;
        });
      }
    } catch (error) {
      developer.log('Error al cargar operadores: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudieron cargar los operadores'),
            backgroundColor: errorColor,
          ),
        );
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> handleToggleActive(String operatorId, bool currentStatus) async {
    // Mostrar un indicador visual temporal
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          currentStatus ? 'Desactivando operador...' : 'Activando operador...',
        ),
        duration: Duration(seconds: 1), // Duración corta
        backgroundColor: Colors.blueGrey,
      ),
    );

    try {
      final operatorService = OperatorService();
      await operatorService.updateOperatorStatus(operatorId, !currentStatus);
      // No es necesario llamar a fetchOperators aquí si la API devuelve el estado actualizado
      // o si actualizamos localmente el estado para una respuesta más rápida.
      // Por simplicidad, recargamos:
      fetchOperators();
    } catch (error) {
      developer.log('Error al actualizar estado: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo actualizar el estado del operador'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  Future<void> handleDelete(String operatorId) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('Confirmar Eliminación'),
          content: const Text(
            '¿Está seguro que desea eliminar este operador? Esta acción no se puede deshacer.',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: TextStyle(color: textColorSecondary),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Cerrar diálogo
                // Mostrar indicador
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                        SizedBox(width: 15),
                        Text('Eliminando...'),
                      ],
                    ),
                    backgroundColor: errorColor.withOpacity(0.8),
                  ),
                );
                try {
                  // Asegúrate que AuthService y deleteUser existan y funcionen
                  final authService = AuthService();
                  await authService.deleteUser(operatorId);

                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Operador eliminado correctamente'),
                      backgroundColor: successColor,
                    ),
                  );
                  fetchOperators(); // Recargar lista
                } catch (error) {
                  developer.log('Error al eliminar operador: $error');
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('No se pudo eliminar el operador'),
                      backgroundColor: errorColor,
                    ),
                  );
                }
              },
              child: Text('Eliminar', style: TextStyle(color: errorColor)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor, // Aplicar color de fondo
      appBar: AppBar(
        title: const Text(
          'Lista de Operadores',
          style: TextStyle(fontWeight: FontWeight.w600), // Estilo de título
        ),
        backgroundColor: cardBackgroundColor, // Fondo blanco
        foregroundColor: textColorPrimary, // Texto oscuro
        elevation: 1.0, // Sombra sutil
        leading: IconButton(
          // Botón para volver
          icon: Icon(Icons.arrow_back, color: iconColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          loading
              ? Center(
                child: CircularProgressIndicator(color: primaryColor),
              ) // Indicador estilizado
              : _buildOperatorsList(),
    );
  }

  Widget _buildOperatorsList() {
    if (operators.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.users, size: 50, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No hay operadores registrados',
                style: TextStyle(fontSize: 16, color: textColorSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Usar RefreshIndicator para recarga manual
    return RefreshIndicator(
      color: primaryColor,
      onRefresh: fetchOperators,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(
          vertical: 8.0,
          horizontal: 12.0,
        ), // Ajustar padding
        itemCount: operators.length,
        itemBuilder: (context, index) {
          final operator = operators[index];
          return _buildOperatorCard(operator);
        },
      ),
    );
  }

  Widget _buildOperatorCard(OperatorProfile operator) {
    final bool isActive = operator.users?['active'] == true;
    final String phone = operator.phoneNumber ?? 'N/A';
    final String dni = operator.identityCard;

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardBackgroundColor,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ), // Padding interno
        leading: Tooltip(
          // Añadir tooltip al indicador de estado
          message: isActive ? 'Activo' : 'Inactivo',
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isActive ? activeColor : inactiveColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
        title: Text(
          '${operator.firstName} ${operator.lastName}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textColorPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            'DNI: $dni • Tel: $phone', // Mostrar DNI y teléfono
            style: TextStyle(fontSize: 13, color: textColorSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Row(
          // Agrupar botones en un Row
          mainAxisSize: MainAxisSize.min, // Para que ocupe el mínimo espacio
          children: [
            _buildActionButton(
              icon: LucideIcons.pencil,
              tooltip: 'Editar',
              color: actionIconColor,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/editOperatorScreen', // Asegúrate que esta ruta exista
                  arguments: operator,
                ).then((_) => fetchOperators()); // Recargar al volver
              },
            ),
            _buildActionButton(
              icon: isActive ? LucideIcons.powerOff : LucideIcons.power,
              tooltip: isActive ? 'Desactivar' : 'Activar',
              color: actionIconColor,
              onTap: () => handleToggleActive(operator.id, isActive),
            ),
            _buildActionButton(
              icon: LucideIcons.trash2, // Icono actualizado
              tooltip: 'Eliminar',
              color: deleteIconColor, // Color rojo para eliminar
              onTap: () => handleDelete(operator.id),
            ),
          ],
        ),
        onTap: () {
          // Acción opcional al tocar la tarjeta (ej. ver detalles)
          Navigator.pushNamed(
            context,
            '/editOperatorScreen',
            arguments: operator,
          ).then((_) => fetchOperators());
        },
      ),
    );
  }

  // Widget para botones de acción usando IconButton
  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(icon, size: 20), // Tamaño ajustado
      color: color,
      tooltip: tooltip,
      onPressed: onTap,
      padding: EdgeInsets.all(8), // Padding alrededor del icono
      constraints: BoxConstraints(), // Para evitar padding extra por defecto
      splashRadius: 20, // Radio del efecto splash
    );
  }
}
