import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:url_launcher/url_launcher.dart';
import '../services/api.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class OperatorTripsScreen extends StatefulWidget {
  final String? operatorId;

  const OperatorTripsScreen({Key? key, this.operatorId}) : super(key: key);

  @override
  _OperatorTripsScreenState createState() => _OperatorTripsScreenState();
}

class _OperatorTripsScreenState extends State<OperatorTripsScreen> {
  bool loading = true;
  List<Trip> trips = [];
  String activeTab = 'active';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    loadTrips();
    // Actualizar cada 10 segundos
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => loadTrips(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadTrips() async {
    try {
      setState(() {
        loading = true;
      });

      final tripService = TripService();
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      final operatorId = widget.operatorId ?? user?.id;

      if (operatorId == null) {
        throw Exception('ID de operador no disponible');
      }

      final operatorTrips = await tripService.getOperatorTrips(operatorId);

      setState(() {
        trips = operatorTrips;
        loading = false;
      });
    } catch (error) {
      developer.log('Error cargando viajes: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron cargar los viajes')),
        );
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> handleCancelTrip(Trip trip) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Cancelación'),
          content: const Text(
            '¿Estás seguro de que deseas cancelar este viaje?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  final tripRequestService = TripRequestService();
                  final tripService = TripService();
                  final user =
                      Provider.of<AuthProvider>(context, listen: false).user;
                  final userId = user?.id;

                  if (trip.status == 'broadcasting') {
                    await tripRequestService.cancelBroadcastingRequest(trip.id);
                  } else {
                    await tripService.updateTripStatus(
                      trip.id,
                      TripStatus.cancelled,
                    );
                  }

                  loadTrips();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Viaje cancelado correctamente'),
                    ),
                  );
                } catch (error) {
                  developer.log('Error cancelando viaje: $error');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No se pudo cancelar el viaje'),
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Sí'),
            ),
          ],
        );
      },
    );
  }

  Future<void> handleResendTrip(String tripId) async {
    try {
      final tripRequestService = TripRequestService();
      await tripRequestService.resendCancelledTrip(tripId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El viaje ha sido reenviado como nueva solicitud'),
        ),
      );

      loadTrips();
    } catch (error) {
      developer.log('Error reenviando viaje: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo reenviar el viaje')),
      );
    }
  }

  Future<void> handleCallDriver(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Número de teléfono no disponible')),
      );
      return;
    }

    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo realizar la llamada')),
      );
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'broadcasting':
        return const Color(0xFF8B5CF6); // Morado
      case 'pending':
        return const Color(0xFFF59E0B); // Ámbar
      case 'in_progress':
        return const Color(0xFF3B82F6); // Azul
      case 'completed':
        return const Color(0xFF10B981); // Verde
      case 'cancelled':
      case 'rejected':
        return const Color(0xFFEF4444); // Rojo
      case 'expired':
        return const Color(0xFF9CA3AF); // Gris
      default:
        return const Color(0xFF6B7280); // Gris oscuro
    }
  }

  Widget getStatusIcon(String status) {
    final color = getStatusColor(status);

    switch (status) {
      case 'broadcasting':
        return Icon(LucideIcons.circleAlert, size: 20, color: color);
      case 'pending':
        return Icon(LucideIcons.clock, size: 20, color: color);
      case 'in_progress':
        return Icon(LucideIcons.circleAlert, size: 20, color: color);
      case 'completed':
        return Icon(LucideIcons.circleCheck, size: 20, color: color);
      case 'cancelled':
      case 'expired':
      case 'rejected':
        return Icon(LucideIcons.ban, size: 20, color: color);
      default:
        return const SizedBox.shrink();
    }
  }

  String getStatusText(String status) {
    switch (status) {
      case 'broadcasting':
        return 'Buscando Chofer';
      case 'pending':
        return 'Pendiente';
      case 'in_progress':
        return 'En Progreso';
      case 'completed':
        return 'Completado';
      case 'cancelled':
        return 'Cancelado';
      case 'expired':
        return 'Expirado';
      case 'rejected':
        return 'Rechazado';
      default:
        return status;
    }
  }

  List<Trip> getFilteredTrips() {
    return trips.where((trip) {
      if (activeTab == 'active') {
        return ['broadcasting', 'pending', 'in_progress'].contains(trip.status);
      }
      if (activeTab == 'cancelled') {
        return ['cancelled', 'expired', 'rejected'].contains(trip.status);
      }
      return trip.status == activeTab;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Viajes'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child:
                loading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildTripsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          _buildTab('active', 'Activos'),
          _buildTab('completed', 'Completados'),
          _buildTab('cancelled', 'Cancelados'),
        ],
      ),
    );
  }

  Widget _buildTab(String tabId, String label) {
    final isActive = activeTab == tabId;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => activeTab = tabId),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? const Color(0xFFDC2626) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color:
                  isActive ? const Color(0xFFDC2626) : const Color(0xFFFECACA),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTripsList() {
    final filteredTrips = getFilteredTrips();

    if (filteredTrips.isEmpty) {
      return const Center(
        child: Text(
          'No hay viajes para mostrar',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: filteredTrips.length,
      itemBuilder: (context, index) => _buildTripCard(filteredTrips[index]),
    );
  }

  Widget _buildTripCard(Trip trip) {
    final canCancel = [
      'broadcasting',
      'pending',
      'in_progress',
    ].contains(trip.status);
    final canResend = ['cancelled', 'expired'].contains(trip.status);
    final showCallDriver =
        trip.status == 'cancelled' &&
        trip.driverId != null &&
        trip.driver_profiles != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado del viaje
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    getStatusIcon(trip.status),
                    const SizedBox(width: 5),
                    Text(
                      getStatusText(trip.status),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: getStatusColor(trip.status),
                      ),
                    ),
                    if (showCallDriver)
                      IconButton(
                        icon: const Icon(
                          LucideIcons.phone,
                          size: 20,
                          color: Color(0xFF3B82F6),
                        ),
                        onPressed:
                            () => handleCallDriver(
                              trip.driver_profiles != null
                                  ? trip.driver_profiles['phone_number']
                                  : null,
                            ),
                      ),
                  ],
                ),
                Text(
                  '\$${trip.price}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),

            // Detalles del viaje
            const SizedBox(height: 10),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
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
                style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
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

            // Botones de acción
            if (canCancel || canResend)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    if (canCancel)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => handleCancelTrip(trip),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Cancelar Viaje',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    if (canCancel && canResend) const SizedBox(width: 10),
                    if (canResend)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => handleResendTrip(trip.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Reenviar Solicitud',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
