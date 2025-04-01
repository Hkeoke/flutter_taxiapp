import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:developer' as developer;
import '../services/api.dart';

class DriverTripsAnalyticsScreen extends StatefulWidget {
  final String? driverId;

  const DriverTripsAnalyticsScreen({Key? key, this.driverId}) : super(key: key);

  @override
  _DriverTripsAnalyticsScreenState createState() =>
      _DriverTripsAnalyticsScreenState();
}

class _DriverTripsAnalyticsScreenState
    extends State<DriverTripsAnalyticsScreen> {
  bool loading = true;
  String timeFrame = 'week'; // 'day', 'week', 'month'
  Map<String, dynamic>? stats;

  @override
  void initState() {
    super.initState();

    if (widget.driverId == null) {
      // Manejar caso donde no se proporciona ID de conductor
      Future.delayed(Duration.zero, () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se especificó un chofer')),
        );
        Navigator.pop(context);
      });
    } else {
      fetchStats();
    }
  }

  Future<void> fetchStats() async {
    try {
      setState(() {
        loading = true;
      });

      developer.log('Iniciando fetchStats para conductor: ${widget.driverId}');

      final analyticsService = AnalyticsService();
      final data = await analyticsService.getDriverTripStats(
        widget.driverId!,
        timeFrame,
      );

      developer.log('Datos recibidos en componente: $data');

      if (data == null) {
        developer.log('No se recibieron datos');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron obtener las estadísticas'),
          ),
        );
        return;
      }

      setState(() {
        stats = data;
        loading = false;
      });
    } catch (error) {
      developer.log('Error en fetchStats: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudieron obtener las estadísticas del conductor. Por favor, intente de nuevo.',
          ),
        ),
      );
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Estadísticas de Viajes')),
        body: const Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas de Viajes')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado y selector de período
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estadísticas de Viajes',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildTimeFrameButton('day', 'Hoy'),
                      const SizedBox(width: 8),
                      _buildTimeFrameButton('week', 'Semana'),
                      const SizedBox(width: 8),
                      _buildTimeFrameButton('month', 'Mes'),
                    ],
                  ),
                ],
              ),
            ),

            // Tarjetas de estadísticas
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStatCard(
                    icon: LucideIcons.trendingUp,
                    title: 'Total Viajes',
                    value: '${stats?['totalTrips'] ?? 0}',
                    subtitle: 'viajes completados',
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard(
                    icon: LucideIcons.dollarSign,
                    title: 'Ganancias Totales',
                    value:
                        '\$${(stats?['totalEarnings'] ?? 0.0).toStringAsFixed(2)}',
                    subtitle: 'ingresos del período',
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard(
                    icon: LucideIcons.wallet,
                    title: 'Balance Actual',
                    value: '\$${(stats?['balance'] ?? 0.0).toStringAsFixed(2)}',
                    subtitle: 'disponible',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFrameButton(String value, String label) {
    final isSelected = timeFrame == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          timeFrame = value;
        });
        fetchStats();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDC2626) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: const Color(0xFFDC2626)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle,
                style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
              ),
            ),
        ],
      ),
    );
  }
}
