import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;
import '../services/api.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DriverBalanceHistoryScreen extends StatefulWidget {
  final String? driverId;

  const DriverBalanceHistoryScreen({Key? key, this.driverId}) : super(key: key);

  @override
  _DriverBalanceHistoryScreenState createState() =>
      _DriverBalanceHistoryScreenState();
}

class _DriverBalanceHistoryScreenState
    extends State<DriverBalanceHistoryScreen> {
  bool loading = true;
  List<BalanceHistory> history = [];
  String filter = 'all'; // 'all', 'today', 'week', 'month' (podrías añadir más)

  // Define colores para consistencia
  final Color primaryColor = Colors.red;
  final Color scaffoldBackgroundColor = Colors.grey.shade100;
  final Color cardBackgroundColor = Colors.white;
  final Color textColorPrimary = Colors.black87;
  final Color textColorSecondary = Colors.grey.shade600;
  final Color iconColor = Colors.red;
  final Color successColor = Colors.green.shade600; // Para recargas
  final Color errorColor = Colors.red.shade700; // Para descuentos
  final Color infoColor = Colors.blue.shade600; // Para viajes u otros
  final Color borderColor = Colors.grey.shade300;

  // Formateadores
  final currencyFormatter = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
  );
  // Ajusta 'es' según tu localidad si es necesario para el formato de fecha
  final dateFormatter = DateFormat("d 'de' MMMM, yyyy HH:mm", 'es');

  @override
  void initState() {
    super.initState();
    // Configurar localización para intl (si no está globalmente)
    // initializeDateFormatting('es_MX', null); // Descomentar si es necesario
    loadHistory();
  }

  Future<void> loadHistory() async {
    if (!mounted) return;
    setState(() {
      loading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // Determinar el ID: si viene como parámetro (admin) o del usuario logueado (conductor)
      final userId = widget.driverId ?? authProvider.user?.id;

      if (userId == null) {
        throw Exception('ID de usuario no disponible');
      }

      // Lógica de fechas para filtros (ejemplo)
      DateTime? startDate;
      final now = DateTime.now();
      if (filter == 'today') {
        startDate = DateTime(now.year, now.month, now.day);
      } else if (filter == 'week') {
        startDate = now.subtract(
          Duration(days: now.weekday - 1),
        ); // Inicio de semana (Lunes)
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
      } else if (filter == 'month') {
        startDate = DateTime(now.year, now.month, 1); // Inicio de mes
      }
      // Nota: La API `getBalanceHistory` necesita soportar el filtrado por fecha si usas `startDate`
      // Si no lo soporta, tendrás que filtrar la lista `historyData` *después* de recibirla.

      final driverService = DriverService();
      // Asumiendo que la API puede filtrar o que filtraremos después
      final historyData = await driverService.getBalanceHistory(userId);

      // Filtrado local si la API no lo hace:
      List<BalanceHistory> filteredData = historyData;
      if (startDate != null) {
        filteredData =
            historyData.where((item) {
              final itemDate = DateTime.parse(item.createdAt);
              return itemDate.isAfter(startDate!);
            }).toList();
      }

      if (mounted) {
        setState(() {
          // Ordenar por fecha descendente (más reciente primero)
          filteredData.sort(
            (a, b) => DateTime.parse(
              b.createdAt,
            ).compareTo(DateTime.parse(a.createdAt)),
          );
          history = filteredData;
          loading = false;
        });
      }
    } catch (error) {
      developer.log('Error cargando historial de balance: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo cargar el historial: ${error.toString()}',
            ),
            backgroundColor: errorColor,
          ),
        );
        setState(() {
          loading = false;
        });
      }
    }
  }

  // Mapeo de tipos a colores e iconos
  Map<String, dynamic> getTypeStyle(String type) {
    switch (type.toLowerCase()) {
      case 'deposito':
      case 'recarga': // Añadir alias si es necesario
        return {'color': successColor, 'icon': LucideIcons.circleArrowDown};
      case 'descuento':
        return {'color': errorColor, 'icon': LucideIcons.circleArrowUp};
      case 'viaje':
        return {'color': infoColor, 'icon': LucideIcons.car};
      default:
        return {'color': textColorSecondary, 'icon': LucideIcons.circleHelp};
    }
  }

  String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString).toLocal(); // Convertir a local
      return dateFormatter.format(date);
    } catch (e) {
      developer.log('Error formateando fecha: $dateString -> $e');
      return dateString; // Devolver original si hay error
    }
  }

  String getTypeText(String type) {
    switch (type.toLowerCase()) {
      case 'deposito':
        return 'Recarga';
      case 'descuento':
        return 'Descuento';
      case 'viaje':
        return 'Viaje Completado';
      default:
        // Capitalizar primera letra
        return type.isNotEmpty
            ? type[0].toUpperCase() + type.substring(1)
            : 'Desconocido';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determinar si la vista es para un conductor específico (desde admin) o el propio conductor
    final bool isAdminView = widget.driverId != null;
    final appBarTitle =
        isAdminView ? 'Historial de Conductor' : 'Mi Historial de Balance';

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardBackgroundColor,
        foregroundColor: textColorPrimary,
        elevation: 1.0,
        title: Text(
          appBarTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: iconColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Encabezado y filtros
          _buildFilterSection(),

          // Lista de transacciones
          Expanded(
            child: RefreshIndicator(
              // Añadir para refrescar la lista
              onRefresh: loadHistory,
              color: primaryColor,
              child:
                  loading
                      ? Center(
                        child: CircularProgressIndicator(color: primaryColor),
                      )
                      : history.isEmpty
                      ? _buildEmptyState() // Widget para estado vacío
                      : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 8.0,
                        ),
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final item = history[index];
                          return _buildHistoryItem(item);
                        },
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
        // Opcional: añadir sombra si se prefiere
        // boxShadow: [
        //   BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: Offset(0, 2)),
        // ],
      ),
      child: Row(
        // Usar Row para alinear filtros horizontalmente
        mainAxisAlignment: MainAxisAlignment.start, // Alinear al inicio
        children: [
          _buildFilterChip('all', 'Todo'),
          const SizedBox(width: 8),
          _buildFilterChip('today', 'Hoy'),
          const SizedBox(width: 8),
          _buildFilterChip('week', 'Semana'),
          const SizedBox(width: 8),
          _buildFilterChip('month', 'Mes'),
          // Puedes añadir más filtros aquí
        ],
      ),
    );
  }

  // Usar FilterChip para un look más estándar
  Widget _buildFilterChip(String value, String label) {
    final bool isSelected = filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            filter = value;
          });
          loadHistory();
        }
      },
      backgroundColor: scaffoldBackgroundColor,
      selectedColor: primaryColor.withOpacity(0.15),
      labelStyle: TextStyle(
        color: isSelected ? primaryColor : textColorSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: StadiumBorder(
        side: BorderSide(color: isSelected ? primaryColor : borderColor),
      ),
      showCheckmark: false, // Opcional: mostrar check
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildHistoryItem(BalanceHistory item) {
    final style = getTypeStyle(item.type);
    final Color typeColor = style['color'];
    final IconData typeIcon = style['icon'];
    // Determinar si es débito (descuento, viaje) o crédito (recarga)
    final bool isDebit =
        item.type.toLowerCase() == 'descuento' ||
        item.type.toLowerCase() == 'viaje';
    final amountPrefix = isDebit ? '-' : '+';
    final formattedAmount = currencyFormatter.format(item.amount.abs());

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      elevation: 1.5, // Sombra sutil
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          // Usar Row para icono a la izquierda, contenido a la derecha
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icono representativo
            Icon(typeIcon, color: typeColor, size: 28),
            const SizedBox(width: 16),
            // Contenido (descripción, fecha, monto)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila superior: Descripción y Monto
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        // Permitir que la descripción se ajuste
                        child: Text(
                          item.description.isNotEmpty
                              ? item.description
                              : getTypeText(
                                item.type,
                              ), // Usar tipo si no hay descripción
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: textColorPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8), // Espacio antes del monto
                      Text(
                        '$amountPrefix$formattedAmount',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Fila inferior: Fecha y Tipo/Realizado por
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatDate(item.createdAt),
                        style: TextStyle(
                          fontSize: 13,
                          color: textColorSecondary,
                        ),
                      ),
                      // Mostrar quién realizó (si aplica y hay datos)
                      if (item.user != null &&
                          (item.type == 'deposito' || item.type == 'descuento'))
                        Text(
                          'Por: ${item.user!['role'] == 'admin' ? 'Admin' : 'Operador'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: textColorSecondary.withOpacity(0.8),
                          ),
                        )
                      else // Mostrar tipo si no hay info de usuario o es viaje
                        Text(
                          getTypeText(item.type),
                          style: TextStyle(
                            fontSize: 12,
                            color: textColorSecondary.withOpacity(0.8),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.history, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No hay transacciones',
            style: TextStyle(fontSize: 18, color: textColorSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            filter == 'all'
                ? 'Aún no se han registrado movimientos.'
                : 'No hay movimientos para el periodo seleccionado.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
