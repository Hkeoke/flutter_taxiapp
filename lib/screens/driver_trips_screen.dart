import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:developer' as developer;
import '../services/api.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class DriverTripsScreen extends StatefulWidget {
  const DriverTripsScreen({Key? key}) : super(key: key);

  @override
  _DriverTripsScreenState createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen> {
  bool loading = true;
  List<Trip> trips = [];
  String activeTab = 'completed'; // 'completed' o 'cancelled'

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user == null) return;

      final tripService = TripService();
      final driverTrips = await tripService.getDriverTrips(user.id);
      
      if (mounted) {
        setState(() {
          trips = driverTrips;
          loading = false;
        });
      }
    } catch (e) {
      developer.log('Error cargando viajes: $e');
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'in_progress':
        return const Color(0xFF3B82F6);
      case 'completed':
        return const Color(0xFF10B981);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Widget _getStatusIcon(String status) {
    final color = _getStatusColor(status);

    switch (status) {
      case 'pending':
        return Icon(LucideIcons.clock, size: 20, color: color);
      case 'in_progress':
        return Icon(LucideIcons.circleAlert, size: 20, color: color);
      case 'completed':
        return Icon(LucideIcons.circleCheck, size: 20, color: color);
      case 'cancelled':
        return Icon(LucideIcons.ban, size: 20, color: color);
      default:
        return Container();
    }
  }

  Widget _buildTripCard(Trip trip) {
    final commission = trip.price * 0.1; // Calculamos el 10% del precio

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado del viaje
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Estado del viaje
                Row(
                  children: [
                    _getStatusIcon(trip.status),
                    const SizedBox(width: 5),
                    Text(
                      trip.status == 'completed' ? 'Completado' : 'Cancelado',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _getStatusColor(trip.status),
                      ),
                    ),
                  ],
                ),
                // Fecha
                Text(
                  _formatDate(trip.createdAt),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Detalles del viaje
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF374151),
                    ),
                    children: [
                      const TextSpan(
                        text: 'Origen: ',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      TextSpan(text: trip.origin),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF374151),
                    ),
                    children: [
                      const TextSpan(
                        text: 'Destino: ',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      TextSpan(text: trip.destination),
                    ],
                  ),
                ),
              ],
            ),

            // Información de precio (solo para viajes completados)
            if (trip.status == 'completed')
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Precio del viaje
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Precio del viaje:',
                          style: TextStyle(
                            color: Color(0xFF374151),
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '\$${trip.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF059669),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    // Comisión
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Comisión (10%):',
                          style: TextStyle(
                            color: Color(0xFF374151),
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '-\$${commission.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 5),
                      child: Divider(color: Color(0xFFE5E7EB)),
                    ),

                    // Total recibido
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total recibido:',
                          style: TextStyle(
                            color: Color(0xFF374151),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '\$${(trip.price - commission).toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF059669),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
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

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    // Filtrar viajes según la pestaña activa
    final filteredTrips =
        trips.where((trip) => trip.status == activeTab).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Viajes')),
      body: Column(
        children: [
          // Pestañas
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
            child: Row(
              children: [
                // Pestaña Completados
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        activeTab = 'completed';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color:
                                activeTab == 'completed'
                                    ? const Color(0xFFDC2626)
                                    : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'Completados',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color:
                              activeTab == 'completed'
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFFECACA),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),

                // Pestaña Cancelados
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        activeTab = 'cancelled';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color:
                                activeTab == 'cancelled'
                                    ? const Color(0xFFDC2626)
                                    : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'Cancelados',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color:
                              activeTab == 'cancelled'
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFFECACA),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista de viajes
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFDC2626),
                    ),
                  )
                : filteredTrips.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay viajes para mostrar',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: filteredTrips.length,
                        itemBuilder: (context, index) {
                          return _buildTripCard(filteredTrips[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Cancelar cualquier operación asíncrona pendiente
    super.dispose();
  }
}
