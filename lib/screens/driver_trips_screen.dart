import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:developer' as developer;
import '../services/api.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class DriverTripsScreen extends StatefulWidget {
  const DriverTripsScreen({Key? key}) : super(key: key);

  @override
  _DriverTripsScreenState createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  List<Trip> allTrips = [];
  late TabController _tabController;

  final Color primaryColor = Colors.red;
  final Color scaffoldBackgroundColor = Colors.grey.shade100;
  final Color cardBackgroundColor = Colors.white;
  final Color textColorPrimary = Colors.black87;
  final Color textColorSecondary = Colors.grey.shade600;
  final Color iconColor = Colors.red;
  final Color borderColor = Colors.grey.shade300;
  final Color errorColor = Colors.red.shade700;
  final Color successColor = Colors.green.shade600;
  final Color warningColor = Colors.orange.shade600;
  final Color infoColor = Colors.blue.shade600;
  final Color cancelledColor = Colors.grey.shade500;

  final DateFormat _displayDateFormat = DateFormat("d MMM, yyyy HH:mm", 'es');
  final currencyFormatter = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTrips();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTrips() async {
    if (!mounted) return;
    setState(() {
      loading = true;
    });

    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user == null) {
        throw Exception("Usuario no autenticado");
      }

      final tripService = TripService();
      print('buscar los viajes');
      final driverTrips = await tripService.getDriverTrips(user.id);
      print(driverTrips);

      if (mounted) {
        setState(() {
          allTrips = driverTrips;
          allTrips.sort(
            (a, b) => DateTime.parse(
              b.createdAt,
            ).compareTo(DateTime.parse(a.createdAt)),
          );
          loading = false;
        });
      }
    } catch (e) {
      print('Error cargando viajes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar los viajes: ${e.toString()}'),
            backgroundColor: errorColor,
          ),
        );
        setState(() {
          loading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return warningColor;
      case 'in_progress':
        return infoColor;
      case 'completed':
        return successColor;
      case 'cancelled':
        return cancelledColor;
      default:
        return textColorSecondary;
    }
  }

  IconData _getStatusIconData(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return LucideIcons.clock;
      case 'in_progress':
        return LucideIcons.circleAlert;
      case 'completed':
        return LucideIcons.circleCheck;
      case 'cancelled':
        return LucideIcons.ban;
      default:
        return LucideIcons.circleHelp;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pendiente';
      case 'in_progress':
        return 'En Progreso';
      case 'completed':
        return 'Completado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return status.capitalize();
    }
  }

  String _formatDisplayDate(String dateString) {
    try {
      final date = DateTime.parse(dateString).toLocal();
      return _displayDateFormat.format(date);
    } catch (e) {
      developer.log('Error formateando fecha: $dateString, Error: $e');
      return 'Fecha inválida';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Mis Viajes',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: cardBackgroundColor,
        foregroundColor: textColorPrimary,
        elevation: 1.0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: textColorSecondary,
          tabs: const [Tab(text: 'Completados'), Tab(text: 'Cancelados')],
        ),
      ),
      body:
          loading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildTripList('completed'),
                  _buildTripList('cancelled'),
                ],
              ),
    );
  }

  Widget _buildTripList(String statusFilter) {
    final filteredTrips =
        allTrips
            .where((trip) => trip.status.toLowerCase() == statusFilter)
            .toList();

    if (filteredTrips.isEmpty) {
      return _buildEmptyState(statusFilter);
    }

    return RefreshIndicator(
      onRefresh: _loadTrips,
      color: primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: filteredTrips.length,
        itemBuilder: (context, index) {
          return _buildTripCard(filteredTrips[index]);
        },
      ),
    );
  }

  Widget _buildTripCard(Trip trip) {
    final statusColor = _getStatusColor(trip.status);
    final statusIconData = _getStatusIconData(trip.status);
    final statusText = _getStatusText(trip.status);
    final displayDate = _formatDisplayDate(trip.createdAt);
    final price = trip.price ?? 0.0;
    final commission = price * 0.1;
    final netEarning = price - commission;

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(statusIconData, size: 18, color: statusColor),
                    const SizedBox(width: 8),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  displayDate,
                  style: TextStyle(fontSize: 13, color: textColorSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: borderColor.withOpacity(0.5)),
            const SizedBox(height: 12),

            _buildDetailRow(
              icon: LucideIcons.mapPin,
              label: "Origen:",
              value: trip.origin,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              icon: LucideIcons.flag,
              label: "Destino:",
              value: trip.destination,
            ),

            if (trip.status.toLowerCase() == 'completed') ...[
              const SizedBox(height: 12),
              Divider(color: borderColor.withOpacity(0.5)),
              const SizedBox(height: 12),
              _buildPriceDetailRow(
                label: 'Precio Viaje:',
                value: price,
                valueColor: textColorPrimary,
              ),
              const SizedBox(height: 4),
              _buildPriceDetailRow(
                label: 'Comisión (10%):',
                value: -commission,
                valueColor: errorColor,
              ),
              const SizedBox(height: 8),
              Divider(color: borderColor.withOpacity(0.3)),
              const SizedBox(height: 8),
              _buildPriceDetailRow(
                label: 'Total Recibido:',
                value: netEarning,
                valueColor: successColor,
                isTotal: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: textColorSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: textColorSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : 'N/A',
            style: TextStyle(fontSize: 14, color: textColorPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceDetailRow({
    required String label,
    required double value,
    required Color valueColor,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 15 : 14,
            color: isTotal ? textColorPrimary : textColorSecondary,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          currencyFormatter.format(value),
          style: TextStyle(
            fontSize: isTotal ? 15 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String statusFilter) {
    final message =
        statusFilter == 'completed'
            ? 'No tienes viajes completados.'
            : 'No tienes viajes cancelados.';
    final icon =
        statusFilter == 'completed'
            ? LucideIcons.circleCheck
            : LucideIcons.fileX;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Sin Viajes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColorSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) {
      return "";
    }
    return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
  }
}
