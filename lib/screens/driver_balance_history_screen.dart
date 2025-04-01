import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;
import '../services/api.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';

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
  String filter = 'all'; // 'all' o 'today'

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    try {
      setState(() {
        loading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = widget.driverId ?? authProvider.user?.id;

      if (userId == null) {
        throw Exception('ID de usuario no disponible');
      }

      String? startDate;
      if (filter == 'today') {
        final today = DateTime.now();
        startDate =
            DateTime(today.year, today.month, today.day).toIso8601String();
      }

      final driverService = DriverService();
      final historyData = await driverService.getBalanceHistory(userId);

      setState(() {
        history = historyData;
        loading = false;
      });
    } catch (error) {
      developer.log('Error cargando historial de balance: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo cargar el historial de balance'),
          ),
        );
        setState(() {
          loading = false;
        });
      }
    }
  }

  Color getTypeColor(String type) {
    switch (type) {
      case 'deposito':
        return const Color(0xFF059669); // Verde para recargas
      case 'descuento':
        return const Color(0xFFDC2626); // Rojo para descuentos
      case 'viaje':
        return const Color(0xFF0891B2); // Azul para viajes
      default:
        return const Color(0xFF6B7280); // Gris por defecto
    }
  }

  String formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final formatter = DateFormat("d 'de' MMMM, yyyy HH:mm", 'es');
    return formatter.format(date);
  }

  String getTypeText(String type) {
    switch (type) {
      case 'deposito':
        return 'Recarga';
      case 'descuento':
        return 'Descuento';
      case 'viaje':
        return 'Viaje';
      default:
        return type.substring(0, 1).toUpperCase() + type.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Balance')),
      body: Column(
        children: [
          // Encabezado y filtros
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Historial de Balance',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildFilterButton('all', 'Todo'),
                    const SizedBox(width: 12),
                    _buildFilterButton('today', 'Hoy'),
                  ],
                ),
              ],
            ),
          ),

          // Lista de transacciones
          Expanded(
            child:
                loading
                    ? const Center(
                      child: CircularProgressIndicator(color: Colors.red),
                    )
                    : history.isEmpty
                    ? const Center(
                      child: Text(
                        'No hay transacciones para mostrar',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 16,
                        ),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final item = history[index];
                        return _buildHistoryItem(item);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String value, String label) {
    final isActive = filter == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          filter = value;
        });
        loadHistory();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFDC2626) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isActive ? Colors.white : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(BalanceHistory item) {
    final typeColor = getTypeColor(item.type);
    final isDeduction = item.type == 'descuento';
    final amountPrefix = isDeduction ? '-' : '+';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado con fecha y monto
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatDate(item.createdAt),
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              Text(
                '$amountPrefix\$${item.amount.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: typeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Descripción
          Text(
            item.description,
            style: const TextStyle(fontSize: 16, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 8),

          // Tipo de transacción
          Text(
            getTypeText(item.type),
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF6B7280),
              fontStyle: FontStyle.italic,
            ),
          ),

          // Información del usuario que realizó la transacción
          if (item.user != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Realizado por: ${item.user!['role'] == 'admin' ? 'Administrador' : 'Operador'}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            ),
        ],
      ),
    );
  }
}
