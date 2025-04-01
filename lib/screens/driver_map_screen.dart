import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/api.dart';
import '../widgets/sidebar.dart';
import 'dart:developer' as developer;

class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({Key? key}) : super(key: key);

  @override
  _DriverMapScreenState createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  bool isSidebarVisible = false;
  List<DriverProfile> drivers = [];
  bool loading = true;
  DriverProfile? selectedDriver;
  final Completer<GoogleMapController> _controller = Completer();
  Timer? _refreshTimer;

  // Posición inicial del mapa (La Habana, Cuba)
  CameraPosition initialPosition = const CameraPosition(
    target: LatLng(23.1136, -82.3666),
    zoom: 14,
  );

  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadDrivers();

    // Configurar actualización periódica
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadDrivers();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    try {
      final driverService = DriverService();
      final driversData = await driverService.getAllDriversWithLocation();

      if (mounted) {
        setState(() {
          drivers = driversData;
          loading = false;
          _updateMarkers();
        });

        // Si hay conductores, centrar el mapa en el primero
        if (driversData.isNotEmpty) {
          _animateToDriver(driversData[0]);
        }
      }
    } catch (error) {
      developer.log('Error cargando conductores: $error');
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void _updateMarkers() {
    final Set<Marker> markers = {};

    for (final driver in drivers) {
      final marker = Marker(
        markerId: MarkerId(driver.id),
        position: LatLng(
          double.parse(driver.latitude.toString()),
          double.parse(driver.longitude.toString()),
        ),
        infoWindow: InfoWindow(
          title: '${driver.firstName} ${driver.lastName}',
          snippet:
              '${driver.isOnDuty ? 'En servicio' : 'Fuera de servicio'} - ${driver.vehicle}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          driver.isOnDuty ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
        ),
        onTap: () {
          _showDriverInfo(driver);
        },
      );

      markers.add(marker);
    }

    setState(() {
      _markers = markers;
    });
  }

  Future<void> _animateToDriver(DriverProfile driver) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            double.parse(driver.latitude.toString()),
            double.parse(driver.longitude.toString()),
          ),
          zoom: 15,
        ),
      ),
    );
  }

  void _showDriverInfo(DriverProfile driver) {
    setState(() {
      selectedDriver = driver;
    });

    _animateToDriver(driver);
  }

  void _hideDriverInfo() {
    setState(() {
      selectedDriver = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mapa de Choferes'),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => setState(() => isSidebarVisible = true),
          ),
        ),
        body: const Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Choferes'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => setState(() => isSidebarVisible = true),
        ),
      ),
      body: Stack(
        children: [
          // Mapa
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: initialPosition,
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
          ),

          // Lista de conductores
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Encabezado de la lista
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Lista de Choferes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStatItem(
                              color: const Color(0xFF22C55E),
                              text:
                                  'Activos: ${drivers.where((d) => d.isOnDuty).length}',
                            ),
                            const SizedBox(width: 16),
                            _buildStatItem(
                              color: const Color(0xFFEF4444),
                              text:
                                  'Inactivos: ${drivers.where((d) => !d.isOnDuty).length}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Lista de conductores
                  Flexible(
                    child: Container(
                      color: const Color(0xFFF8FAFC),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: drivers.length,
                        itemBuilder: (context, index) {
                          final driver = drivers[index];
                          return _buildDriverCard(driver);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Panel de información del conductor seleccionado
          if (selectedDriver != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 3.84,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Información del Chofer',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        IconButton(
                          icon: const Text(
                            '×',
                            style: TextStyle(
                              fontSize: 24,
                              color: Color(0xFF666666),
                            ),
                          ),
                          onPressed: _hideDriverInfo,
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      '${selectedDriver!.firstName} ${selectedDriver!.lastName}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Estado: ${selectedDriver!.isOnDuty ? 'En servicio' : 'Fuera de servicio'}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vehículo: ${selectedDriver!.vehicle}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Sidebar
          if (isSidebarVisible)
            Sidebar(
              isVisible: isSidebarVisible,
              onClose: () => setState(() => isSidebarVisible = false),
              role: 'admin',
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem({required Color color, required String text}) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDriverCard(DriverProfile driver) {
    final bool isSelected = selectedDriver?.id == driver.id;

    return GestureDetector(
      onTap: () => _showDriverInfo(driver),
      child: Container(
        height: 50,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0F9FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF0891B2) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            // Icono del vehículo
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
              ),
              child: _getVehicleIcon(driver),
            ),
            const SizedBox(width: 6),

            // Información del conductor
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${driver.firstName} ${driver.lastName}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.car,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          driver.vehicle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Indicador de estado
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color:
                    driver.isOnDuty
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getVehicleIcon(DriverProfile driver) {
    final color =
        driver.isOnDuty ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    return driver.vehicleType == '2_ruedas'
        ? Icon(LucideIcons.bike, color: color, size: 16)
        : Icon(LucideIcons.car, color: color, size: 16);
  }
}
