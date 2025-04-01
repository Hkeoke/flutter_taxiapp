import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:developer' as developer;
import '../services/api.dart';
import 'package:intl/intl.dart';

class DriverTripsAnalyticsScreen extends StatefulWidget {
  final String? driverId;
  final String? driverName;

  const DriverTripsAnalyticsScreen({
    Key? key,
    required this.driverId,
    this.driverName,
  }) : super(key: key);

  @override
  _DriverTripsAnalyticsScreenState createState() =>
      _DriverTripsAnalyticsScreenState();
}

class _DriverTripsAnalyticsScreenState
    extends State<DriverTripsAnalyticsScreen> {
  bool loading = true;
  String timeFrame = 'week'; // 'day', 'week', 'month'
  Map<String, dynamic>? stats;
  String? errorMessage;

  final Color primaryColor = Colors.red;
  final Color scaffoldBackgroundColor = Colors.grey.shade100;
  final Color cardBackgroundColor = Colors.white;
  final Color textColorPrimary = Colors.black87;
  final Color textColorSecondary = Colors.grey.shade600;
  final Color iconColor = Colors.red;
  final Color statIconColor = Colors.red.shade400;
  final Color borderColor = Colors.grey.shade300;
  final Color errorColor = Colors.red.shade700;
  final Color successColor = Colors.green.shade600;
  final Color infoColor = Colors.blue.shade600;
  final Color chipSelectedColor = Colors.red.shade50;
  final Color chipSelectedTextColor = Colors.red.shade800;

  final currencyFormatter = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
  );

  @override
  void initState() {
    super.initState();

    if (widget.driverId == null) {
      errorMessage = 'No se especificó un ID de chofer.';
      loading = false;
    } else {
      fetchStats();
    }
  }

  Future<void> fetchStats() async {
    if (widget.driverId == null) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      developer.log(
        'Iniciando fetchStats para conductor: ${widget.driverId}, periodo: $timeFrame',
      );

      final analyticsService = AnalyticsService();
      final data = await analyticsService.getDriverTripStats(
        widget.driverId!,
        timeFrame,
      );

      developer.log('Datos recibidos: $data');

      if (mounted) {
        if (data == null) {
          developer.log('No se recibieron datos válidos');
          setState(() {
            stats = null;
            errorMessage = 'No se encontraron estadísticas para este período.';
            loading = false;
          });
        } else {
          setState(() {
            stats = data;
            loading = false;
          });
        }
      }
    } catch (error) {
      developer.log('Error en fetchStats: $error');
      if (mounted) {
        setState(() {
          stats = null;
          errorMessage = 'Error al obtener estadísticas. Intente de nuevo.';
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBarTitle =
        widget.driverName != null
            ? 'Estadísticas (${widget.driverName})'
            : 'Estadísticas de Viajes';

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(appBarTitle, style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: cardBackgroundColor,
        foregroundColor: textColorPrimary,
        elevation: 1.0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: iconColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child:
                loading
                    ? Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    )
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTimeFrameChip('day', 'Hoy'),
          const SizedBox(width: 8),
          _buildTimeFrameChip('week', 'Semana'),
          const SizedBox(width: 8),
          _buildTimeFrameChip('month', 'Mes'),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (errorMessage != null) {
      return _buildErrorState(errorMessage!);
    }
    if (stats == null ||
        (stats?['totalTrips'] == 0 && stats?['totalEarnings'] == 0.0)) {
      return _buildEmptyState();
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildStatCard(
          icon: LucideIcons.circleCheck,
          title: 'Viajes Completados',
          value: (stats?['totalTrips'] ?? 0).toString(),
          subtitle: 'en el período seleccionado',
          valueColor: textColorPrimary,
        ),
        const SizedBox(height: 16),
        _buildStatCard(
          icon: LucideIcons.dollarSign,
          title: 'Ganancias del Período',
          value: currencyFormatter.format(stats?['totalEarnings'] ?? 0.0),
          subtitle: 'ingresos generados',
          valueColor: successColor,
        ),
        const SizedBox(height: 16),
        _buildStatCard(
          icon: LucideIcons.wallet,
          title: 'Balance Actual',
          value: currencyFormatter.format(stats?['balance'] ?? 0.0),
          subtitle: 'saldo disponible',
          valueColor: (stats?['balance'] ?? 0.0) >= 0 ? infoColor : errorColor,
        ),
      ],
    );
  }

  Widget _buildTimeFrameChip(String value, String label) {
    final isSelected = timeFrame == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            timeFrame = value;
          });
          fetchStats();
        }
      },
      labelStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: isSelected ? chipSelectedTextColor : textColorSecondary,
      ),
      backgroundColor: cardBackgroundColor,
      selectedColor: chipSelectedColor,
      checkmarkColor: chipSelectedTextColor,
      shape: StadiumBorder(
        side: BorderSide(
          color:
              isSelected ? chipSelectedTextColor.withOpacity(0.5) : borderColor,
        ),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
    Color? valueColor,
  }) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: statIconColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textColorSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? textColorPrimary,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: textColorSecondary.withOpacity(0.8),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.chartBar, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Sin Datos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColorSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'No hay estadísticas disponibles para el período seleccionado.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.triangleAlert,
              size: 60,
              color: errorColor.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Ocurrió un Error',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColorPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: textColorSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(LucideIcons.refreshCw, size: 16),
              label: Text('Reintentar'),
              onPressed: fetchStats,
              style: ElevatedButton.styleFrom(
                foregroundColor: primaryColor,
                backgroundColor: primaryColor.withOpacity(0.1),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
