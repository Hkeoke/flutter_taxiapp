import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';
import '../widgets/sidebar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:http/http.dart' as http;

class OperatorScreen extends StatefulWidget {
  const OperatorScreen({Key? key}) : super(key: key);

  @override
  _OperatorScreenState createState() => _OperatorScreenState();
}

class _OperatorScreenState extends State<OperatorScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  bool isSidebarVisible = false;
  bool isLoading = true;
  bool showRequestForm = false;
  bool showLocationModal = false;
  String searchMode = ''; // 'origin', 'destination', 'stop'

  // Lista de conductores
  List<Map<String, dynamic>> drivers = [];
  Map<String, dynamic>? selectedDriver;

  // Coordenadas para el mapa
  Map<String, dynamic>? selectedLocation;

  // Radio de búsqueda
  double searchRadius = 3000;

  // Controlador para búsqueda
  final TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];
  bool isSearching = false;

  // Posición inicial del mapa
  CameraPosition initialCameraPosition = const CameraPosition(
    target: LatLng(23.1136, -82.3666),
    zoom: 14,
  );

  // Marcadores para el mapa
  Set<Marker> markers = {};
  Set<Circle> circles = {};

  // Agregar estas variables para suscripciones
  RealtimeChannel? tripSubscription;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // --- Estado del Mapa ---
  GoogleMapController? mapController;
  final LatLng _center = const LatLng(
    19.4326,
    -99.1332,
  ); // Centro inicial (CDMX)
  Set<Marker> _markers = {};

  // --- Estado del Formulario ---
  Map<String, dynamic> requestForm = {
    'origin': '',
    'destination': '',
    'stops': [], // Lista de paradas (Map<String, dynamic>)
    'vehicle_type': '4_ruedas', // '4_ruedas' o '2_ruedas'
    'price': '',
  };
  Map<String, dynamic>? originCoords;
  Map<String, dynamic>? destinationCoords;
  // Lista de coordenadas de paradas, debe coincidir con requestForm['stops']
  List<Map<String, dynamic>> stopCoords = [];

  bool isSubmitting = false;

  // Definir colores consistentes como en AdminScreen
  final Color primaryColor = Colors.red;
  final Color scaffoldBackgroundColor = Colors.grey.shade100;
  final Color cardBackgroundColor = Colors.white;
  final Color textColorPrimary = Colors.black87;
  final Color textColorSecondary = Colors.grey.shade600;
  final Color iconColor = Colors.red;
  final Color inputFillColor = Colors.grey.shade50;
  final Color inputBorderColor = Colors.grey.shade200;
  final Color errorColor = Colors.red.shade700;
  final Color successColor = Colors.green.shade600;
  final Color infoColor = Colors.blue.shade600;

  // --- GlobalKey para el Formulario ---
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    fetchDrivers();
    _initializeNotifications();
    _setupTripSubscription();
    // Retrasar la suscripción hasta después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setupTripSubscription();
      }
    });
  }

  Future<void> fetchDrivers() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Llamada a la API para obtener conductores disponibles
      final driverService = DriverService();
      final availableDrivers = await driverService.getAvailableDrivers();

      // Convertir DriverProfile a Map<String, dynamic>
      final driversAsMaps =
          availableDrivers
              .map(
                (driver) => {
                  'id': driver.id,
                  'first_name': driver.firstName,
                  'last_name': driver.lastName,
                  'latitude': driver.latitude,
                  'longitude': driver.longitude,
                  'is_on_duty': driver.isOnDuty,
                  'vehicle_type': driver.vehicleType,
                  // Agrega otras propiedades según sea necesario
                },
              )
              .toList();

      // Filtrar conductores con coordenadas válidas
      final validDrivers =
          driversAsMaps.where((driver) {
            return driver['latitude'] != null && driver['longitude'] != null;
          }).toList();

      setState(() {
        drivers = validDrivers;
        isLoading = false;
      });

      // Actualizar marcadores en el mapa
      _updateMapMarkers();

      // Centrar el mapa si hay conductores
      if (validDrivers.isNotEmpty) {
        final firstDriver = validDrivers.first;
        final newPosition = CameraPosition(
          target: LatLng(
            double.parse(firstDriver['latitude'].toString()),
            double.parse(firstDriver['longitude'].toString()),
          ),
          zoom: 14,
        );

        final GoogleMapController controller = await _mapController.future;
        controller.animateCamera(CameraUpdate.newCameraPosition(newPosition));
      }
    } catch (error) {
      developer.log('Error fetching drivers: $error');
      setState(() {
        drivers = [];
        isLoading = false;
      });
    }
  }

  void _updateMapMarkers() {
    final Set<Marker> newMarkers = {};
    final Set<Circle> newCircles = {};

    // Agregar marcadores para conductores
    for (final driver in drivers) {
      final driverId = driver['id'].toString();
      final driverName = '${driver['first_name']} ${driver['last_name']}';
      final isOnDuty = driver['is_on_duty'] ?? false;
      final vehicleType = driver['vehicle_type'] ?? '4_ruedas';

      final markerIcon = BitmapDescriptor.defaultMarkerWithHue(
        isOnDuty ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
      );

      newMarkers.add(
        Marker(
          markerId: MarkerId(driverId),
          position: LatLng(
            double.parse(driver['latitude'].toString()),
            double.parse(driver['longitude'].toString()),
          ),
          icon: markerIcon,
          infoWindow: InfoWindow(
            title: driverName,
            snippet:
                '${isOnDuty ? 'En servicio' : 'Fuera de servicio'} - ${vehicleType == '2_ruedas' ? 'Moto' : 'Auto'}',
          ),
          onTap: () => showDriverInfo(driver),
        ),
      );
    }

    // Agregar marcadores para origen y destino
    if (originCoords != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: LatLng(
            originCoords!['latitude'],
            originCoords!['longitude'],
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: 'Origen'),
        ),
      );

      newCircles.add(
        Circle(
          circleId: const CircleId('searchRadius'),
          center: LatLng(originCoords!['latitude'], originCoords!['longitude']),
          radius: searchRadius,
          fillColor: Colors.green.withOpacity(0.1),
          strokeColor: Colors.green.withOpacity(0.3),
          strokeWidth: 1,
        ),
      );
    }

    if (destinationCoords != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(
            destinationCoords!['latitude'],
            destinationCoords!['longitude'],
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destino'),
        ),
      );
    }

    // Agregar marcador para ubicación seleccionada en el modal
    if (showLocationModal && selectedLocation != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('selectedLocation'),
          position: LatLng(
            selectedLocation!['latitude'],
            selectedLocation!['longitude'],
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet,
          ),
          draggable: true,
          onDragEnd: (newPosition) async {
            final address = await getAddressFromCoords(
              newPosition.latitude,
              newPosition.longitude,
            );
            setState(() {
              selectedLocation = {
                'name': address,
                'latitude': newPosition.latitude,
                'longitude': newPosition.longitude,
              };
              _updateMapMarkers();
            });
          },
        ),
      );
    }

    setState(() {
      markers = newMarkers;
      circles = newCircles;
    });
  }

  Future<String> getAddressFromCoords(double latitude, double longitude) async {
    try {
      final analyticsService = AnalyticsService();
      return await analyticsService.getAddressFromCoords(latitude, longitude);
    } catch (error) {
      developer.log('Error getting address: $error');
      return '$latitude, $longitude';
    }
  }

  Future<void> searchLocations(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        isSearching = false;
      });
      return;
    }

    setState(() {
      isSearching = true;
    });

    try {
      final analyticsService = AnalyticsService();
      final results = await analyticsService.searchLocations(query);

      setState(() {
        searchResults = results;
        isSearching = false;
      });
    } catch (error) {
      developer.log('Error searching locations: $error');
      setState(() {
        searchResults = [];
        isSearching = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al buscar ubicaciones')),
      );
    }
  }

  void showDriverInfo(Map<String, dynamic> driver) {
    setState(() {
      selectedDriver = driver;
    });

    _animateToDriver(driver);
  }

  Future<void> _animateToDriver(Map<String, dynamic> driver) async {
    try {
      final GoogleMapController controller = await _mapController.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              double.parse(driver['latitude'].toString()),
              double.parse(driver['longitude'].toString()),
            ),
            zoom: 15,
          ),
        ),
      );
    } catch (e) {
      developer.log('Error animating to driver: $e');
    }
  }

  void handleRemoveStop(int index) {
    setState(() {
      final stops = List<Map<String, dynamic>>.from(requestForm['stops']);
      stops.removeAt(index);
      requestForm['stops'] = stops;
    });
  }

  Future<void> handleSendRequest() async {
    if (originCoords == null ||
        destinationCoords == null ||
        requestForm['price'].isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor complete todos los campos obligatorios'),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final requestData = {
        'operator_id': user.id,
        'origin': requestForm['origin'],
        'destination': requestForm['destination'],
        'price': double.parse(requestForm['price']),
        'origin_lat': originCoords!['latitude'],
        'origin_lng': originCoords!['longitude'],
        'destination_lat': destinationCoords!['latitude'],
        'destination_lng': destinationCoords!['longitude'],
        'search_radius': searchRadius,
        'observations': requestForm['observations'],
        'vehicle_type': requestForm['vehicle_type'],
        'passenger_phone': requestForm['passenger_phone'],
        'status': 'broadcasting',
        'stops': requestForm['stops'],
      };

      // Llamada a API para crear solicitud
      final tripRequestService = TripRequestService();
      await tripRequestService.createBroadcastRequest(requestData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada a choferes cercanos')),
      );

      setState(() {
        requestForm = {
          'origin': '',
          'destination': '',
          'price': '',
          'observations': '',
          'vehicle_type': '4_ruedas',
          'passenger_phone': '',
          'stops': <Map<String, dynamic>>[],
        };
        originCoords = null;
        destinationCoords = null;
        showRequestForm = false;
        isLoading = false;
      });

      _updateMapMarkers();
    } catch (error) {
      developer.log('Error sending request: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar la solicitud')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardBackgroundColor,
        foregroundColor: textColorPrimary,
        elevation: 1.0,
        title: const Text(
          'Solicitar Viaje',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: Icon(Icons.menu, color: iconColor),
          onPressed: () => setState(() => isSidebarVisible = true),
          tooltip: 'Menú',
        ),
      ),
      body: Stack(
        children: [
          // Mapa
          GoogleMap(
            initialCameraPosition: initialCameraPosition,
            onMapCreated: (controller) {
              _mapController.complete(controller);
            },
            markers: markers,
            circles: circles,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
          ),

          // Actualizar el botón flotante
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () => setState(() => showRequestForm = true),
              backgroundColor: primaryColor,
              elevation: 4,
              child: const Icon(Icons.add, size: 28),
            ),
          ),

          // Actualizar el formulario de solicitud
          if (showRequestForm)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: GestureDetector(
                onTap: () => setState(() => showRequestForm = false),
                child: Container(color: Colors.transparent),
              ),
            ),

          if (showRequestForm)
            DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: cardBackgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cabecera mejorada
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Solicitar Viaje',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: textColorPrimary,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: iconColor),
                                onPressed:
                                    () =>
                                        setState(() => showRequestForm = false),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Campos de ubicación mejorados
                          _buildLocationField(
                            label: 'Origen',
                            value: requestForm['origin'],
                            onTap: () {
                              setState(() {
                                searchMode = 'origin';
                                showLocationModal = true;
                              });
                            },
                          ),

                          const SizedBox(height: 16),

                          _buildLocationField(
                            label: 'Destino',
                            value: requestForm['destination'],
                            onTap: () {
                              setState(() {
                                searchMode = 'destination';
                                showLocationModal = true;
                              });
                            },
                          ),

                          const SizedBox(height: 16),

                          // Tipo de vehículo
                          const Text(
                            'Tipo de vehículo:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      requestForm['vehicle_type'] = '4_ruedas';
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color:
                                          requestForm['vehicle_type'] ==
                                                  '4_ruedas'
                                              ? Colors.red[50]
                                              : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color:
                                            requestForm['vehicle_type'] ==
                                                    '4_ruedas'
                                                ? Colors.red
                                                : Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.directions_car,
                                          color:
                                              requestForm['vehicle_type'] ==
                                                      '4_ruedas'
                                                  ? Colors.red
                                                  : Colors.grey[600],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '4 ruedas',
                                          style: TextStyle(
                                            color:
                                                requestForm['vehicle_type'] ==
                                                        '4_ruedas'
                                                    ? Colors.red
                                                    : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      requestForm['vehicle_type'] = '2_ruedas';
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color:
                                          requestForm['vehicle_type'] ==
                                                  '2_ruedas'
                                              ? Colors.red[50]
                                              : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color:
                                            requestForm['vehicle_type'] ==
                                                    '2_ruedas'
                                                ? Colors.red
                                                : Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.two_wheeler,
                                          color:
                                              requestForm['vehicle_type'] ==
                                                      '2_ruedas'
                                                  ? Colors.red
                                                  : Colors.grey[600],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '2 ruedas',
                                          style: TextStyle(
                                            color:
                                                requestForm['vehicle_type'] ==
                                                        '2_ruedas'
                                                    ? Colors.red
                                                    : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Precio
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'Precio',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              setState(() {
                                requestForm['price'] = value;
                              });
                            },
                          ),

                          const SizedBox(height: 16),

                          // Observaciones
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'Observaciones (opcional)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            maxLines: 3,
                            onChanged: (value) {
                              setState(() {
                                requestForm['observations'] = value;
                              });
                            },
                          ),

                          const SizedBox(height: 16),

                          // Teléfono del pasajero
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'Teléfono del cliente',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            keyboardType: TextInputType.phone,
                            onChanged: (value) {
                              setState(() {
                                requestForm['passenger_phone'] = value;
                              });
                            },
                          ),

                          const SizedBox(height: 15),

                          // Paradas
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Paradas',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    searchMode = 'stop';
                                    showLocationModal = true;
                                  });
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.red,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.add, color: Colors.red),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Agregar parada',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...List.generate(
                                requestForm['stops'].length,
                                (index) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          requestForm['stops'][index]['name'],
                                          style: const TextStyle(
                                            color: Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.red,
                                        ),
                                        onPressed:
                                            () => handleRemoveStop(index),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Botón de enviar
                          ElevatedButton(
                            onPressed: isLoading ? null : handleSendRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child:
                                isLoading
                                    ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Text(
                                      'Enviar Solicitud',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

          // Modal de selección de ubicación
          if (showLocationModal) _buildLocationModal(),

          // Sidebar
          if (isSidebarVisible)
            Sidebar(
              isVisible: isSidebarVisible,
              onClose: () => setState(() => isSidebarVisible = false),
              role: 'operador',
            ),
        ],
      ),
    );
  }

  // Nuevo widget para campos de ubicación
  Widget _buildLocationField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textColorPrimary,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: inputFillColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: inputBorderColor),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: value.isEmpty ? textColorSecondary : primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value.isEmpty ? 'Seleccionar $label' : value,
                    style: TextStyle(
                      color:
                          value.isEmpty ? textColorSecondary : textColorPrimary,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: textColorSecondary,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Método para construir el modal de selección de ubicación
  Widget _buildLocationModal() {
    return Positioned.fill(
      child: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // Encabezado del modal
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Seleccionar ${searchMode == 'origin'
                          ? 'origen'
                          : searchMode == 'destination'
                          ? 'destino'
                          : 'parada'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          showLocationModal = false;
                          selectedLocation = null;
                          searchResults = [];
                          searchController.clear();
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Buscador
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar ubicación...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon:
                        isSearching
                            ? const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : null,
                  ),
                  onChanged: (query) {
                    if (query.isEmpty) {
                      setState(() {
                        searchResults = [];
                      });
                      return;
                    }

                    // Debounce para no hacer muchas peticiones
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (query == searchController.text) {
                        searchLocations(query);
                      }
                    });
                  },
                ),
              ),

              // Resultados de búsqueda
              if (searchResults.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final result = searchResults[index];
                      return ListTile(
                        title: Text(result['display_name']),
                        onTap: () {
                          setState(() {
                            selectedLocation = {
                              'name': result['display_name'],
                              'latitude': double.parse(result['lat']),
                              'longitude': double.parse(result['lon']),
                            };
                            searchResults = [];
                            searchController.clear();
                            _updateMapMarkers();
                          });
                        },
                      );
                    },
                  ),
                )
              else
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          '- O -',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Selecciona una ubicación en el mapa',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: GoogleMap(
                              initialCameraPosition: initialCameraPosition,
                              onMapCreated: (controller) {
                                if (!_mapController.isCompleted) {
                                  _mapController.complete(controller);
                                }
                              },
                              markers: markers,
                              circles: circles,
                              onTap: (position) async {
                                final address = await getAddressFromCoords(
                                  position.latitude,
                                  position.longitude,
                                );
                                setState(() {
                                  selectedLocation = {
                                    'name': address,
                                    'latitude': position.latitude,
                                    'longitude': position.longitude,
                                  };
                                  _updateMapMarkers();
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Botón de confirmar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed:
                      selectedLocation != null
                          ? confirmLocationSelection
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Confirmar ubicación',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void confirmLocationSelection() {
    if (selectedLocation == null) return;

    switch (searchMode) {
      case 'origin':
        setState(() {
          requestForm['origin'] = selectedLocation!['name'];
          originCoords = selectedLocation;
        });
        break;
      case 'destination':
        setState(() {
          requestForm['destination'] = selectedLocation!['name'];
          destinationCoords = selectedLocation;
        });
        break;
      case 'stop':
        setState(() {
          final stops = List<Map<String, dynamic>>.from(requestForm['stops']);
          stops.add(selectedLocation!);
          requestForm['stops'] = stops;
        });
        break;
    }

    setState(() {
      showLocationModal = false;
      selectedLocation = null;
      searchMode = '';
      searchResults = [];
      searchController.clear();
    });

    _updateMapMarkers();
  }

  // Inicializar notificaciones
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // Configurar suscripción a actualizaciones de viajes
  void _setupTripSubscription() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id;

    if (userId != null) {
      // Usar el servicio existente para suscribirse a actualizaciones
      final tripRequestService = TripRequestService();
      tripSubscription = tripRequestService.subscribeToTripUpdates(
        userId,
        (tripData) {
          _handleTripUpdate(tripData);
        },
        (error) {
          print('Error en suscripción: $error');
        },
      );
    }
  }

  // Manejar actualizaciones de viajes
  void _handleTripUpdate(Map<String, dynamic> updatedTrip) {
    if (updatedTrip['status'] == 'cancelled') {
      _showNotification(
        'Viaje Cancelado',
        'El viaje ${updatedTrip['id']} ha sido cancelado por el conductor',
      );
    } else if (updatedTrip['status'] == 'completed') {
      _showNotification(
        'Viaje Completado',
        'El viaje ${updatedTrip['id']} ha sido completado exitosamente',
      );
    }
  }

  // Mostrar notificación
  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'trip_updates',
          'Actualizaciones de Viajes',
          importance: Importance.high,
          priority: Priority.high,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  @override
  void dispose() {
    // Cancelar suscripción al salir
    if (tripSubscription != null) {
      final tripRequestService = TripRequestService();
      tripRequestService.unsubscribeFromTripUpdates(tripSubscription!);
    }
    super.dispose();
  }
}
