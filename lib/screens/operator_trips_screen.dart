import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:url_launcher/url_launcher.dart';
import '../services/api.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

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
  final TextEditingController _reasonController = TextEditingController();

  final Color primaryColor = Colors.red;
  final Color scaffoldBackgroundColor = Colors.grey.shade100;
  final Color cardBackgroundColor = Colors.white;
  final Color textColorPrimary = Colors.black87;
  final Color textColorSecondary = Colors.grey.shade600;
  final Color iconColor = Colors.red;
  final Color borderColor = Colors.grey.shade300;
  final Color errorColor = Colors.red.shade700;
  final Color successColor = Colors.green.shade600;
  final Color warningColor = Colors.orange.shade700;
  final Color infoColor = Colors.blue.shade600;
  final Color tabInactiveColor = Colors.grey.shade500;

  final DateFormat _displayDateTimeFormat = DateFormat(
    "d MMM, yyyy HH:mm",
    'es',
  );
  final currencyFormatter = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
  );

  @override
  void initState() {
    super.initState();
    loadTrips();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => loadTrips(isRefresh: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> loadTrips({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        loading = true;
      });
    }

    try {
      print('Iniciando carga de viajes...');
      final tripService = TripService();
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      final operatorId = widget.operatorId ?? user?.id;

      print('ID del operador: $operatorId');

      if (operatorId == null) {
        throw Exception('ID de operador no disponible');
      }

      final operatorTrips = await tripService.getOperatorTrips(operatorId);
      print('Viajes obtenidos: ${operatorTrips.length}');

      if (mounted) {
        setState(() {
          trips = operatorTrips;
          trips.sort(
            (a, b) => DateTime.parse(
              b.createdAt,
            ).compareTo(DateTime.parse(a.createdAt)),
          );
          loading = false;
        });
        print('Estado actualizado. Total de viajes: ${trips.length}');
      }
    } catch (error, stackTrace) {
      print('Error cargando viajes: $error');
      print('Stack trace: $stackTrace');
      if (mounted) {
        if (!isRefresh) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudieron cargar los viajes: $error'),
              backgroundColor: errorColor,
            ),
          );
        }
        setState(() {
          loading = false;
          if (!isRefresh) trips = [];
        });
      }
    }
  }

  Future<void> handleCancelTrip(String tripId, bool isBroadcasting) async {
    try {
      if (isBroadcasting) {
        // Para solicitudes en broadcasting
        final result = await TripRequestService().cancelBroadcastingRequest(
          tripId,
        );

        // En lugar de usar ScaffoldMessenger directamente:
        if (mounted && context.mounted) {
          // Verificar si el contexto sigue siendo válido
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Solicitud cancelada correctamente')),
          );
        }

        // Recargar viajes después de cancelar
        loadTrips();
      } else {
        // Para viajes en progreso
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text('Cancelar viaje'),
                content: TextField(
                  controller: _reasonController,
                  decoration: InputDecoration(
                    hintText: 'Motivo de cancelación',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        final operatorId = widget.operatorId;
                        if (operatorId != null) {
                          await TripRequestService().cancelTrip(
                            tripId,
                            'Cancelado por operador',
                            operatorId,
                          );
                        } else {
                          throw Exception('ID de operador no disponible');
                        }

                        if (mounted && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Viaje cancelado correctamente'),
                            ),
                          );
                        }

                        loadTrips();
                      } catch (e) {
                        print('Error cancelando viaje: $e');

                        if (mounted && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error al cancelar el viaje: $e'),
                            ),
                          );
                        }
                      }
                    },
                    child: Text('Confirmar'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      print('Error cancelando viaje: $e');

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cancelar: $e')));
      }
    }
  }

  Future<void> handleResendTrip(String tripId) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
              SizedBox(width: 15),
              Text('Reenviando...'),
            ],
          ),
          backgroundColor: infoColor.withOpacity(0.8),
        ),
      );

      final tripRequestService = TripRequestService();
      await tripRequestService.resendCancelledTrip(tripId);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('El viaje ha sido reenviado como nueva solicitud'),
          backgroundColor: successColor,
        ),
      );

      loadTrips();
    } catch (error) {
      print('Error reenviando viaje: $error');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo reenviar el viaje'),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  Future<void> handleCallDriver(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Número de teléfono no disponible'),
          backgroundColor: warningColor,
        ),
      );
      return;
    }

    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'No se puede lanzar $uri';
      }
    } catch (e) {
      print('Error al intentar llamar: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo realizar la llamada'),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'broadcasting':
        return warningColor;
      case 'pending':
        return infoColor;
      case 'in_progress':
        return Colors.purple.shade500;
      case 'completed':
        return successColor;
      case 'cancelled':
      case 'rejected':
        return errorColor;
      case 'expired':
        return textColorSecondary;
      default:
        return textColorSecondary;
    }
  }

  IconData getStatusIcon(String status) {
    switch (status) {
      case 'broadcasting':
        return LucideIcons.wifi;
      case 'pending':
        return LucideIcons.clock3;
      case 'in_progress':
        return LucideIcons.truck;
      case 'completed':
        return LucideIcons.circleCheck;
      case 'cancelled':
      case 'rejected':
        return LucideIcons.circleX;
      case 'expired':
        return LucideIcons.timerOff;
      default:
        return LucideIcons.circleHelp;
    }
  }

  String getStatusText(String status) {
    switch (status) {
      case 'broadcasting':
        return 'Buscando';
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
        return status.capitalize();
    }
  }

  List<Trip> getFilteredTrips() {
    print('Filtrando viajes. Total antes de filtrar: ${trips.length}');

    // Crear un Set para rastrear IDs ya incluidos
    final Set<String> includedIds = {};
    final List<Trip> filtered = [];

    for (final trip in trips) {
      // Si ya incluimos este ID, omitirlo
      if (includedIds.contains(trip.id)) continue;

      bool shouldInclude = false;

      if (activeTab == 'active') {
        shouldInclude = [
          'broadcasting',
          'pending',
          'in_progress',
        ].contains(trip.status.toLowerCase());
      } else if (activeTab == 'cancelled') {
        shouldInclude = [
          'cancelled',
          'expired',
          'rejected',
        ].contains(trip.status.toLowerCase());
      } else {
        shouldInclude = trip.status.toLowerCase() == activeTab;
      }

      if (shouldInclude) {
        filtered.add(trip);
        includedIds.add(trip.id);
      }
    }

    print('Viajes filtrados para tab $activeTab: ${filtered.length}');
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    print(
      'Construyendo OperatorTripsScreen. Loading: $loading, Total trips: ${trips.length}',
    );
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Mis Viajes (Operador)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: cardBackgroundColor,
        foregroundColor: textColorPrimary,
        elevation: 1.0,
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child:
                loading && trips.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: primaryColor),
                          SizedBox(height: 16),
                          Text('Cargando viajes...'),
                        ],
                      ),
                    )
                    : _buildTripsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? primaryColor : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isActive ? primaryColor : tabInactiveColor,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTripsList() {
    final filteredTrips = getFilteredTrips();
    print('Construyendo lista de viajes. Filtrados: ${filteredTrips.length}');

    if (filteredTrips.isEmpty) {
      String message = 'No hay viajes activos en este momento.';
      IconData icon = LucideIcons.listChecks;
      if (activeTab == 'completed') {
        message = 'No has completado ningún viaje.';
        icon = LucideIcons.history;
      } else if (activeTab == 'cancelled') {
        message = 'No tienes viajes cancelados.';
        icon = LucideIcons.archiveX;
      }
      return _buildEmptyState(icon: icon, message: message);
    }

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: () => loadTrips(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredTrips.length,
        itemBuilder: (context, index) {
          final trip = filteredTrips[index];
          print(
            'Construyendo viaje ${index + 1}/${filteredTrips.length}: ${trip.id}',
          );
          return _buildTripCard(trip);
        },
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: textColorSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(Trip trip) {
    final canCancel = [
      'broadcasting',
      'pending',
      'in_progress',
    ].contains(trip.status);
    final canResend = [
      'cancelled',
      'expired',
      'rejected',
    ].contains(trip.status);
    final driverPhone = trip.driver_profiles?['phone_number'] as String?;
    final showCallDriver =
        trip.driverId != null && driverPhone != null && driverPhone.isNotEmpty;

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Chip(
                  avatar: Icon(
                    getStatusIcon(trip.status),
                    size: 16,
                    color: getStatusColor(trip.status),
                  ),
                  label: Text(
                    getStatusText(trip.status),
                    style: TextStyle(
                      color: getStatusColor(trip.status),
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  backgroundColor: getStatusColor(trip.status).withOpacity(0.1),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: getStatusColor(trip.status).withOpacity(0.3),
                    ),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                Row(
                  children: [
                    Icon(LucideIcons.dollarSign, size: 16, color: successColor),
                    SizedBox(width: 4),
                    Text(
                      currencyFormatter.format(trip.price ?? 0.0),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: successColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildDetailRow(icon: LucideIcons.mapPin, value: trip.origin),
            _buildDetailRow(icon: LucideIcons.flag, value: trip.destination),
            _buildDetailRow(
              icon: LucideIcons.calendar,
              value: _displayDateTimeFormat.format(
                DateTime.parse(trip.createdAt),
              ),
            ),

            if (trip.driver_profiles != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: _buildDetailRow(
                  icon: LucideIcons.user,
                  value:
                      '${trip.driver_profiles!['first_name'] ?? ''} ${trip.driver_profiles!['last_name'] ?? ''}'
                          .trim(),
                  trailing:
                      showCallDriver
                          ? IconButton(
                            icon: Icon(
                              LucideIcons.phone,
                              size: 18,
                              color: infoColor,
                            ),
                            onPressed: () => handleCallDriver(driverPhone),
                            tooltip: 'Llamar al Chofer',
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          )
                          : null,
                ),
              ),

            if (canCancel || canResend)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (canCancel)
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(LucideIcons.x, size: 16),
                          label: const Text('Cancelar Viaje'),
                          onPressed: () => handleCancelTrip(trip.id, canCancel),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: errorColor,
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    if (canCancel && canResend) const SizedBox(width: 10),
                    if (canResend)
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(LucideIcons.send, size: 16),
                          label: const Text('Reenviar'),
                          onPressed: () => handleResendTrip(trip.id),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: infoColor,
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
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

  Widget _buildDetailRow({
    required IconData icon,
    required String value,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: textColorSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: TextStyle(fontSize: 14, color: textColorPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return "";
    return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
  }
}
