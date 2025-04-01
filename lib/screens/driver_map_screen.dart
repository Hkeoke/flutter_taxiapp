import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/api.dart';
import '../widgets/sidebar.dart';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';

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
  final Completer<GoogleMapController> _mapController = Completer();
  Timer? _refreshTimer;

  // Define colores para consistencia
  final Color primaryColor = Colors.red;
  final Color scaffoldBackgroundColor =
      Colors.grey.shade100; // Fondo general si se viera
  final Color cardBackgroundColor = Colors.white;
  final Color textColorPrimary = Colors.black87;
  final Color textColorSecondary = Colors.grey.shade600;
  final Color iconColor = Colors.red;
  final Color successColor = Colors.green.shade600; // En servicio
  final Color errorColor = Colors.red.shade700; // Fuera de servicio
  final Color borderColor = Colors.grey.shade300;
  final Color selectedItemColor =
      Colors.blue.shade50; // Color suave para item seleccionado
  final Color selectedItemBorderColor = Colors.blue.shade300;

  // Posición inicial del mapa (La Habana, Cuba)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(23.1136, -82.3666),
    zoom: 13, // Un poco más alejado inicialmente
  );

  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadDrivers();

    // Configurar actualización periódica cada 30 segundos
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        // Solo recargar si la pantalla está visible
        _loadDrivers(
          showLoadingIndicator: false,
        ); // No mostrar indicador en recargas automáticas
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDrivers({bool showLoadingIndicator = true}) async {
    if (showLoadingIndicator && mounted) {
      setState(() {
        loading = true;
      });
    }
    try {
      final driverService = DriverService();
      // Asumiendo que esta función trae lat/lon y estado isOnDuty
      final driversData = await driverService.getAllDriversWithLocation();

      if (mounted) {
        setState(() {
          drivers = driversData;
          loading = false;
          _updateMarkers();
        });

        // Opcional: Animar al primer conductor solo la primera vez
        // if (showLoadingIndicator && driversData.isNotEmpty) {
        //   _animateToDriver(driversData[0]);
        // }
      }
    } catch (error) {
      developer.log('Error cargando conductores: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar conductores: ${error.toString()}'),
            backgroundColor: errorColor,
          ),
        );
        setState(() {
          loading = false;
        });
      }
    }
  }

  void _updateMarkers() {
    final Set<Marker> markers = {};
    if (!mounted) return;

    for (final driver in drivers) {
      // Asegurarse que lat/lon no sean null y sean parseables
      final lat = double.tryParse(driver.latitude?.toString() ?? '');
      final lon = double.tryParse(driver.longitude?.toString() ?? '');

      if (lat != null && lon != null) {
        final marker = Marker(
          markerId: MarkerId(driver.id),
          position: LatLng(lat, lon),
          infoWindow: InfoWindow(
            title: '${driver.firstName} ${driver.lastName}',
            snippet:
                '${driver.isOnDuty ? 'En servicio' : 'Fuera de servicio'} - ${driver.vehicle ?? 'N/A'}',
          ),
          // Usar colores definidos
          icon: BitmapDescriptor.defaultMarkerWithHue(
            driver.isOnDuty
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueRed,
          ),
          onTap: () {
            _showDriverInfo(driver);
          },
        );
        markers.add(marker);
      } else {
        developer.log('Coordenadas inválidas para conductor ID: ${driver.id}');
      }
    }

    setState(() {
      _markers = markers;
    });
  }

  Future<void> _animateToDriver(DriverProfile driver) async {
    final lat = double.tryParse(driver.latitude?.toString() ?? '');
    final lon = double.tryParse(driver.longitude?.toString() ?? '');

    if (lat == null || lon == null) return; // No animar si no hay coordenadas

    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(lat, lon),
          zoom: 15.5, // Zoom un poco más cercano al seleccionar
        ),
      ),
    );
  }

  void _showDriverInfo(DriverProfile driver) {
    if (!mounted) return;
    setState(() {
      selectedDriver = driver;
    });
    _animateToDriver(driver);
  }

  void _hideDriverInfo() {
    if (!mounted) return;
    setState(() {
      selectedDriver = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // --- Pantalla de Carga ---
    if (loading) {
      return Scaffold(
        backgroundColor: scaffoldBackgroundColor,
        appBar: _buildAppBar(),
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    // --- Pantalla Principal ---
    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // --- Mapa ---
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialPosition,
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              if (!_mapController.isCompleted) {
                _mapController.complete(controller);
              }
              // Opcional: Aplicar estilo JSON al mapa si tienes uno
              // controller.setMapStyle(_mapStyleJson);
            },
            onTap: (_) => _hideDriverInfo(), // Ocultar info al tocar el mapa
            myLocationButtonEnabled: true, // Mostrar botón de mi ubicación
            myLocationEnabled:
                true, // Intentar mostrar mi ubicación (requiere permisos)
            zoomControlsEnabled: false, // Ocultar controles de zoom +/-
            padding: EdgeInsets.only(
              // Ajustar padding para que la UI no tape logos de Google
              bottom:
                  MediaQuery.of(context).size.height *
                  0.35, // Altura estimada del panel inferior
            ),
          ),

          // --- Panel Inferior: Lista de Conductores ---
          _buildDriverListPanel(),

          // --- Panel Flotante: Información del Conductor Seleccionado ---
          if (selectedDriver != null) _buildDriverInfoCard(),

          // --- Sidebar ---
          if (isSidebarVisible)
            Sidebar(
              isVisible: isSidebarVisible,
              onClose: () => setState(() => isSidebarVisible = false),
              role: 'admin', // Asegúrate que el rol sea correcto
            ),
        ],
      ),
    );
  }

  // --- Widgets de Construcción ---

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: cardBackgroundColor,
      foregroundColor: textColorPrimary,
      elevation: 1.0,
      title: const Text(
        'Mapa de Choferes',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      leading: IconButton(
        icon: Icon(Icons.menu, color: iconColor),
        onPressed: () => setState(() => isSidebarVisible = true),
      ),
      actions: [
        // Botón para recargar manualmente
        IconButton(
          icon: Icon(LucideIcons.refreshCw, color: iconColor, size: 20),
          tooltip: 'Recargar',
          onPressed: () => _loadDrivers(),
        ),
      ],
    );
  }

  Widget _buildDriverListPanel() {
    final int onDutyCount = drivers.where((d) => d.isOnDuty).length;
    final int offDutyCount = drivers.length - onDutyCount;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        // Limitar altura máxima del panel
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.of(context).size.height * 0.35, // 35% de la altura
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Para que se ajuste al contenido
          children: [
            // Encabezado con título y estadísticas
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Conductores (${drivers.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColorPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      _buildStatItem(
                        color: successColor,
                        text: '$onDutyCount En Servicio',
                      ),
                      const SizedBox(width: 12),
                      _buildStatItem(
                        color: errorColor,
                        text: '$offDutyCount Fuera',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: borderColor.withOpacity(0.5),
            ),

            // Lista de conductores (scrollable)
            Expanded(
              child:
                  drivers.isEmpty
                      ? Center(
                        child: Text(
                          'No hay conductores disponibles.',
                          style: TextStyle(color: textColorSecondary),
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: drivers.length,
                        itemBuilder: (context, index) {
                          return _buildDriverCard(drivers[index]);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverInfoCard() {
    if (selectedDriver == null) return const SizedBox.shrink();

    return Positioned(
      bottom:
          MediaQuery.of(context).size.height * 0.35 +
          10, // Encima del panel inferior + espacio
      left: 10,
      right: 10,
      child: Card(
        elevation: 4.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: cardBackgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fila superior: Título y botón de cierre
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Información del Chofer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColorPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      LucideIcons.x,
                      color: textColorSecondary,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(), // Para quitar padding extra
                    tooltip: 'Cerrar',
                    onPressed: _hideDriverInfo,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Nombre
              Text(
                '${selectedDriver!.firstName} ${selectedDriver!.lastName}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textColorPrimary,
                ),
              ),
              const SizedBox(height: 6),
              // Estado
              Row(
                children: [
                  Icon(
                    selectedDriver!.isOnDuty
                        ? LucideIcons.circleCheck
                        : LucideIcons.circleX,
                    size: 14,
                    color: selectedDriver!.isOnDuty ? successColor : errorColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    selectedDriver!.isOnDuty
                        ? 'En servicio'
                        : 'Fuera de servicio',
                    style: TextStyle(fontSize: 14, color: textColorSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Vehículo
              Row(
                children: [
                  _getVehicleIcon(
                    selectedDriver!,
                    size: 14,
                    color: textColorSecondary,
                  ), // Usar icono gris aquí
                  const SizedBox(width: 6),
                  Text(
                    selectedDriver!.vehicle ?? 'Vehículo no especificado',
                    style: TextStyle(fontSize: 14, color: textColorSecondary),
                  ),
                ],
              ),
              // Puedes añadir más info aquí si la tienes (teléfono, balance, etc.)
            ],
          ),
        ),
      ),
    );
  }

  // Widget para item de estadística en el encabezado del panel
  Widget _buildStatItem({required Color color, required String text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle, // Usar círculo
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: textColorSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Widget para la tarjeta de conductor en la lista inferior
  Widget _buildDriverCard(DriverProfile driver) {
    final bool isSelected = selectedDriver?.id == driver.id;

    return Card(
      elevation: isSelected ? 2.0 : 0.5, // Más elevación si está seleccionado
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? selectedItemBorderColor : Colors.transparent,
          width: 1.5,
        ),
      ),
      color: isSelected ? selectedItemColor : cardBackgroundColor,
      child: InkWell(
        // Usar InkWell para efecto ripple
        onTap: () => _showDriverInfo(driver),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: Row(
            children: [
              // Icono de estado (círculo)
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: driver.isOnDuty ? successColor : errorColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              // Icono de vehículo
              _getVehicleIcon(driver, size: 18, color: textColorSecondary),
              const SizedBox(width: 10),
              // Información del conductor
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${driver.firstName} ${driver.lastName}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColorPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      driver.vehicle ?? 'Vehículo N/A',
                      style: TextStyle(fontSize: 12, color: textColorSecondary),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              // Icono de chevron (indicador de acción)
              Icon(
                LucideIcons.chevronRight,
                color: textColorSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper para obtener el icono del vehículo
  Widget _getVehicleIcon(
    DriverProfile driver, {
    double size = 16,
    Color? color,
  }) {
    final iconColor = color ?? (driver.isOnDuty ? successColor : errorColor);
    IconData iconData;
    switch (driver.vehicleType?.toLowerCase()) {
      case '2_ruedas':
      case 'moto':
        iconData = LucideIcons.bike;
        break;
      case '4_ruedas':
      case 'carro':
      default:
        iconData = LucideIcons.car;
    }
    return Icon(iconData, color: iconColor, size: size);
  }
}

// Opcional: Estilo JSON para Google Maps (ejemplo básico)
// Puedes generar estilos personalizados en https://mapstyle.withgoogle.com/
/*
const String _mapStyleJson = '''
[
  {
    "featureType": "poi.business",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  }
]
''';
*/
