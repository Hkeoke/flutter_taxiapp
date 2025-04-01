import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:location/location.dart' as location_pkg;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';
import '../widgets/sidebar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/trip_provider.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'taxi_driver_service',
    'Servicio de Conductor',
    description: 'Mantiene activo el servicio para recibir solicitudes',
    importance: Importance.high,
    enableVibration: true,
    playSound: true,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'taxi_driver_service',
      initialNotificationTitle: 'Servicio de Conductor',
      initialNotificationContent: 'Buscando viajes disponibles...',
      foregroundServiceNotificationId: 888,
      autoStartOnBoot: true,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

// Función para ejecutar en iOS en segundo plano
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

// Función principal del servicio en segundo plano
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  RealtimeChannel? requestSubscription;

  // Configurar el servicio primero
  if (service is AndroidServiceInstance) {
    await service.setForegroundNotificationInfo(
      title: 'Servicio de Conductor',
      content: 'Iniciando servicio...',
    );
  }

  print('Iniciando servicio en segundo plano...'); // Debug print inicial

  try {
    // Obtener SharedPreferences antes de Supabase
    final prefs = await SharedPreferences.getInstance();
    final driverId = prefs.getString('user_id');
    print('Driver ID obtenido: $driverId'); // Verificar ID

    // Verificar si Supabase ya está inicializado
    bool isInitialized = false;
    try {
      Supabase.instance.client;
      isInitialized = true;
      print('Supabase ya está inicializado');
    } catch (_) {
      print('Supabase necesita inicializarse');
      isInitialized = false;
    }

    // Inicializar Supabase si es necesario
    if (!isInitialized) {
      print('Inicializando Supabase...');
      await Supabase.initialize(
        url: 'https://gunevwlqmwhwsykpvfqi.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd1bmV2d2xxbXdod3N5a3B2ZnFpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzkyOTAwMTksImV4cCI6MjA1NDg2NjAxOX0.FR-CGD6ZUPSh5_0MKUYiUgYuKcyi96ACjwrmYFVJqoE',
      );
      print('Supabase inicializado correctamente');
    }

    if (driverId == null) {
      throw Exception('No se encontró ID del conductor');
    }

    final supabase = Supabase.instance.client;
    final tripRequestService = TripRequestService();

    print('Configurando suscripción para conductor: $driverId');

    print('Suscribiendose a solicitudes de viaje');
    requestSubscription = await tripRequestService.subscribeToDriverRequests(
      driverId,
      (request) async {
        print('Solicitud recibida: $request');

        // Crear objeto TripRequest
        final tripRequest = TripRequest.fromJson(request);

        // Enviar mensaje a la app principal para que actualice el provider
        service.invoke('newRequest', {'request': jsonEncode(request)});

        // Mostrar notificación
        final flutterLocalNotificationsPlugin =
            FlutterLocalNotificationsPlugin();
        const androidDetails = AndroidNotificationDetails(
          'trip_requests',
          'Solicitudes de Viaje',
          importance: Importance.high,
          priority: Priority.high,
        );
        await flutterLocalNotificationsPlugin.show(
          0,
          '¡Nueva solicitud de viaje!',
          'Origen: ${request['origin']}\nDestino: ${request['destination']}',
          const NotificationDetails(android: androidDetails),
        );
      },
      (error) {
        print('Error en suscripción: $error');
      },
    );

    // Escuchar solicitudes de parada
    service.on('stopService').listen((event) {
      requestSubscription?.unsubscribe();
      service.stopSelf();
    });

    // Timer para mantener la conexión viva
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        // Verificar estado de la suscripción
        if (requestSubscription?.isJoined != true) {
          print('Reconectando suscripción...');
          requestSubscription = await tripRequestService.subscribeToDriverRequests(
            driverId,
            (request) async {
              print('Solicitud recibida: $request');

              // Crear objeto TripRequest
              final tripRequest = TripRequest.fromJson(request);

              // Enviar mensaje a la app principal para que actualice el provider
              service.invoke('newRequest', {'request': jsonEncode(request)});

              // Mostrar notificación
              final flutterLocalNotificationsPlugin =
                  FlutterLocalNotificationsPlugin();
              const androidDetails = AndroidNotificationDetails(
                'trip_requests',
                'Solicitudes de Viaje',
                importance: Importance.high,
                priority: Priority.high,
              );
              await flutterLocalNotificationsPlugin.show(
                0,
                '¡Nueva solicitud de viaje!',
                'Origen: ${request['origin']}\nDestino: ${request['destination']}',
                const NotificationDetails(android: androidDetails),
              );
            },
            (error) {
              print('Error en suscripción: $error');
            },
          );
        }
      } catch (e) {
        print('Error en heartbeat: $e');
      }
    });

    // Timer para mantener el servicio vivo
    Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (service is AndroidServiceInstance) {
        await service.setForegroundNotificationInfo(
          title: 'Servicio de Conductor Activo',
          content: 'Buscando viajes disponibles...',
        );
      }
    });
  } catch (e) {
    print('Error en servicio en segundo plano: $e');
    requestSubscription?.unsubscribe();
    service.stopSelf();
  }
}

// Añade esta línea para definir driverService y tripRequestService
final driverService = DriverService();
final tripRequestService = TripRequestService();

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({Key? key}) : super(key: key);

  @override
  _DriverHomeScreenState createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with WidgetsBindingObserver {
  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();
  final location_pkg.Location _location = location_pkg.Location();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isOnDuty = false;
  bool _isSidebarVisible = false;
  bool _isLoading = true;

  location_pkg.LocationData? _userLocation;
  List<TripRequest> _pendingRequests = [];
  Trip? _activeTrip;
  String _tripPhase = 'none'; // 'none', 'toPickup', 'toStops', 'toDestination'
  Map<String, dynamic>? _currentRoute;
  List<String> _rejectedRequests = [];
  int _currentStopIndex = -1;
  List<LatLng> _visibleRoute = [];

  Timer? _locationUpdateTimer;
  RealtimeChannel? _requestSubscription;
  RealtimeChannel? _tripSubscription;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Constante para la desviación máxima permitida (en metros)
  final double MAX_ROUTE_DEVIATION = 50;

  // Añadir variable para el servicio en segundo plano
  FlutterBackgroundService? _backgroundService;

  // Añadir una variable para controlar la primera actualización de ubicación
  bool _isFirstLocationUpdate = true;

  // Añadir estas variables para el mapa
  CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(23.1136, -82.3666), // Coordenadas por defecto
    zoom: 15,
  );

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  late TripProvider _tripProvider;

  // Variable para controlar si ya se restauró el estado
  bool _stateRestored = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tripProvider = Provider.of<TripProvider>(context, listen: false);
    _initializeApp();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Restaurar estado cuando volvemos a esta pantalla
    if (mounted) {
      _restoreState().then((_) {
        if (_activeTrip != null || _pendingRequests.isNotEmpty) {
          // Reconstruir el mapa si hay un viaje activo o solicitudes pendientes
          _rebuildMapState();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationUpdateTimer?.cancel();
    _unsubscribeFromRequests();
    _unsubscribeFromTripUpdates();
    _audioPlayer.dispose();
    _location.onLocationChanged.listen(null); // Detener escucha de ubicación

    // Detener servicio en segundo plano
    _backgroundService?.invoke('stopService');

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      // Guardar estado antes de ir a segundo plano
      await _saveCurrentState();

      // App en segundo plano
      if (_isOnDuty && _activeTrip == null && _backgroundService != null) {
        // Guardar el estado actual antes de iniciar el servicio
        _saveCurrentState().then((_) {
          _backgroundService!.startService();
          debugPrint(
            'Servicio en segundo plano iniciado (app en segundo plano)',
          );
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('App volviendo a primer plano');

      // Detener el servicio en segundo plano
      if (_backgroundService != null) {
        _backgroundService!.invoke('stopService');
        debugPrint('Servicio en segundo plano detenido');
      }

      // Obtener solicitudes pendientes del provider
      final tripProvider = Provider.of<TripProvider>(context, listen: false);

      // Cargar solicitudes solo si no se han cargado antes
      await tripProvider.loadPendingRequestsFromPrefs();

      final pendingRequests = tripProvider.pendingRequests;

      if (pendingRequests.isNotEmpty) {
        debugPrint(
          'Encontradas ${pendingRequests.length} solicitudes pendientes en provider',
        );

        // Procesar cada solicitud pendiente
        for (final request in pendingRequests) {
          debugPrint('Procesando solicitud pendiente: ${request.id}');

          // Calcular la ruta para la solicitud
          final route = await _calculateRoute(
            LatLng(_userLocation?.latitude ?? 0, _userLocation?.longitude ?? 0),
            LatLng(request.originLat, request.originLng),
            request.trip_stops ?? [],
          );

          // Actualizar el estado con la nueva solicitud
          setState(() {
            _pendingRequests = [request];
            _currentRoute = route;
            if (route['polyline'] is List) {
              _visibleRoute =
                  (route['polyline'] as List)
                      .map((p) {
                        if (p is List)
                          return LatLng(p[0] as double, p[1] as double);
                        return null;
                      })
                      .whereType<LatLng>()
                      .toList();
            }
            _markers = _buildMarkers();
            _polylines = _buildPolylines();
          });

          // Actualizar el provider
          tripProvider.setCurrentRoute(route);
          tripProvider.setVisibleRoute(_visibleRoute);
          tripProvider.setMarkers(_markers);
          tripProvider.setPolylines(_polylines);

          // Ajustar el mapa para mostrar la ruta
          _fitMapToRoute();

          // Reproducir sonido de notificación
          await _playNotificationSound();

          debugPrint('Solicitud procesada y mostrada en UI');

          // Solo procesamos la primera solicitud
          break;
        }
      } else {
        debugPrint('No hay solicitudes pendientes en el provider');
      }

      // Actualizar ubicación inmediatamente
      if (_isOnDuty) {
        _location.getLocation().then((locationData) {
          if (mounted) {
            setState(() {
              _userLocation = locationData;
            });
            _updateDriverLocation();
          }
        });
      }
    }
  }

  Future<void> _initializeApp() async {
    try {
      // Inicializar notificaciones
      await _initializeNotifications();

      // Cargar estado del conductor
      await _loadDriverStatus();

      // Configurar servicio de ubicación de forma más directa
      await _setupLocationServiceImproved();

      // Configurar servicio en segundo plano
      await _setupBackgroundService();

      // Cargar solicitudes rechazadas
      await _loadRejectedRequests();

      // Restaurar estado guardado
      await _restoreState();

      // Sincronizar estado con el provider
      _syncWithProvider();

      // Actualizar estado de carga
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error inicializando la aplicación: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _loadRejectedRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rejectedList = prefs.getStringList('rejectedRequests') ?? [];
      setState(() {
        _rejectedRequests = rejectedList;
      });
    } catch (e) {
      debugPrint('Error cargando solicitudes rechazadas: $e');
    }
  }

  Future<void> _saveRejectedRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('rejectedRequests', _rejectedRequests);
    } catch (e) {
      debugPrint('Error guardando solicitudes rechazadas: $e');
    }
  }

  Future<void> _setupLocationServiceImproved() async {
    try {
      // Solicitar permisos en orden específico
      if (!await Permission.notification.isGranted) {
        await Permission.notification.request();
      }

      if (!await Permission.locationWhenInUse.isGranted) {
        final status = await Permission.locationWhenInUse.request();
        if (status != PermissionStatus.granted) {
          debugPrint('Permiso de ubicación denegado');
          return;
        }
      }

      if (!await Permission.locationAlways.isGranted) {
        final status = await Permission.locationAlways.request();
        if (status != PermissionStatus.granted) {
          debugPrint('Permiso de ubicación en segundo plano denegado');
        }
      }

      // Verificar servicio de ubicación
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          debugPrint('Servicio de ubicación deshabilitado');
          return;
        }
      }

      // Configurar el servicio de ubicación
      await _location.changeSettings(
        accuracy: location_pkg.LocationAccuracy.high,
        interval: 10000,
        distanceFilter: 10,
      );

      // Obtener ubicación inicial
      try {
        final locationData = await _location.getLocation().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('Timeout obteniendo ubicación inicial');
            return location_pkg.LocationData.fromMap({
              'latitude': 23.1136,
              'longitude': -82.3666,
              'accuracy': 0.0,
              'altitude': 0.0,
              'speed': 0.0,
              'speed_accuracy': 0.0,
              'heading': 0.0,
              'time': 0.0,
            });
          },
        );

        if (mounted) {
          setState(() {
            _userLocation = locationData;
            _isLoading = false;
          });

          // Centrar el mapa en la ubicación actual
          await _centerMapOnCurrentLocation();
        }
      } catch (e) {
        debugPrint('Error obteniendo ubicación inicial: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }

      // Configurar escucha de ubicación
      _location.onLocationChanged.listen(
        (locationData) {
          if (mounted) {
            setState(() {
              _userLocation = locationData;
            });
            if (_isOnDuty) {
              _updateDriverLocation();
            }
            // Centrar el mapa en la primera actualización
            if (_isFirstLocationUpdate) {
              _centerMapOnCurrentLocation();
              _isFirstLocationUpdate = false;
            }
          }
        },
        onError: (e) {
          debugPrint('Error en actualización de ubicación: $e');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Error configurando servicio de ubicación: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateDriverLocation() async {
    if (_userLocation == null || !_isOnDuty) return;

    try {
      await driverService.updateLocation(
        Provider.of<AuthProvider>(context, listen: false).user!.id,
        _userLocation!.latitude!,
        _userLocation!.longitude!,
      );
    } catch (e) {
      debugPrint('Error actualizando ubicación: $e');
    }
  }

  Future<void> _loadDriverStatus() async {
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user == null) return;

      final driverProfile = await driverService.getDriverProfile(user.id);
      setState(() {
        _isOnDuty = driverProfile.isOnDuty;
      });

      // Inicializar suscripción a solicitudes si está en servicio
      if (_isOnDuty) {
        _subscribeToDriverRequests();
      }
    } catch (e) {
      debugPrint('Error cargando estado del conductor: $e');
    }
  }

  Future<void> _toggleDutyStatus(bool value) async {
    try {
      setState(() {
        _isLoading = true;
      });

      await driverService.updateDutyStatus(
        Provider.of<AuthProvider>(context, listen: false).user!.id,
        value,
      );

      setState(() {
        _isOnDuty = value;
        _isLoading = false;
      });

      // Manejar suscripción según el nuevo estado
      if (value) {
        // Activar suscripción cuando se pone en servicio
        _subscribeToDriverRequests();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ahora estás en servicio')),
        );
      } else {
        // Cancelar suscripción cuando se quita del servicio
        _unsubscribeFromRequests();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ya no estás en servicio')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _subscribeToDriverRequests() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    // Primero cancelar cualquier suscripción existente
    _unsubscribeFromRequests();

    debugPrint(
      'Suscribiéndose a solicitudes de viaje para conductor: ${user.id}',
    );

    _requestSubscription = tripRequestService.subscribeToDriverRequests(
      user.id,
      (request) {
        debugPrint('Procesando solicitud recibida...');
        final tripRequest = TripRequest.fromJson(request);
        _processIncomingRequest(tripRequest);
      },
      (error) {
        debugPrint('Error en suscripción: $error');
      },
    );
  }

  void _unsubscribeFromRequests() {
    if (_requestSubscription != null) {
      tripRequestService.unsubscribeFromDriverRequests(_requestSubscription!);
      _requestSubscription = null;
    }
  }

  void _subscribeToTripUpdates() {
    if (_activeTrip == null) return;

    _tripSubscription = tripRequestService.subscribeToTripUpdates(
      _activeTrip!.id,
      _handleTripUpdate,
      (error) => debugPrint('Error en suscripción de viaje: $error'),
    );
  }

  void _unsubscribeFromTripUpdates() {
    if (_tripSubscription != null) {
      tripRequestService.unsubscribeFromTripUpdates(_tripSubscription!);
      _tripSubscription = null;
    }
  }

  void _handleTripUpdate(Map<String, dynamic> tripData) {
    final updatedTrip = Trip.fromJson(tripData);

    if (updatedTrip.status == 'cancelled') {
      // Detener alertas y notificaciones
      _stopAlerts();

      // Mostrar alerta al usuario
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Viaje Cancelado'),
              content: const Text('El viaje ha sido cancelado.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _activeTrip = null;
                      _tripPhase = 'none';
                      _currentRoute = null;
                      _pendingRequests = [];
                      _currentStopIndex = -1;
                      _visibleRoute = [];
                    });
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    }
  }

  Future<void> _handleNewRequest(TripRequest request) async {
    if (!request.id.isNotEmpty ||
        !_isOnDuty ||
        _activeTrip != null ||
        request.status != 'broadcasting' ||
        _pendingRequests.any((r) => r.id == request.id) ||
        _rejectedRequests.contains(request.id)) {
      debugPrint(
        'Solicitud ignorada: ${request.id} - No cumple con los criterios',
      );
      return;
    }

    try {
      debugPrint('Calculando ruta para solicitud: ${request.id}');
      final route = await _calculateRoute(
        LatLng(request.originLat, request.originLng),
        LatLng(request.destinationLat, request.destinationLng),
        request.trip_stops ?? [],
      );

      // Actualizar el provider primero
      final tripProvider = Provider.of<TripProvider>(context, listen: false);

      // Verificar si la solicitud ya existe en el provider
      if (!tripProvider.hasRequest(request.id)) {
        tripProvider.setPendingRequests([request]);
      }

      tripProvider.setCurrentRoute(route);

      // Procesar la ruta visible con manejo de errores
      List<LatLng> visibleRoute = [];
      try {
        if (route['polyline'] is List<dynamic>) {
          visibleRoute =
              (route['polyline'] as List<dynamic>)
                  .map((p) {
                    if (p is LatLng) return p;
                    if (p is List && p.length >= 2) {
                      return LatLng(
                        p[0] is double ? p[0] : (p[0] as num).toDouble(),
                        p[1] is double ? p[1] : (p[1] as num).toDouble(),
                      );
                    }
                    if (p is Map &&
                        p.containsKey('lat') &&
                        p.containsKey('lng')) {
                      return LatLng(
                        p['lat'] is double
                            ? p['lat']
                            : (p['lat'] as num).toDouble(),
                        p['lng'] is double
                            ? p['lng']
                            : (p['lng'] as num).toDouble(),
                      );
                    }
                    debugPrint('Formato de punto no reconocido: $p');
                    return null;
                  })
                  .whereType<LatLng>()
                  .toList();
        }
      } catch (e) {
        debugPrint('Error procesando polyline: $e');
      }

      tripProvider.setVisibleRoute(visibleRoute);

      // Luego actualizar el estado local
      if (mounted) {
        setState(() {
          _pendingRequests = [request];
          _currentRoute = route;
          _visibleRoute = visibleRoute;
          _markers = _buildMarkers();
          _polylines = _buildPolylines();
        });

        // Actualizar marcadores y polylines en el provider
        tripProvider.setMarkers(_markers);
        tripProvider.setPolylines(_polylines);

        _fitMapToRoute();
      }

      // Mostrar notificación y reproducir sonido solo si la app está en segundo plano
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused) {
        await _showNotification(
          '¡Nueva solicitud de viaje!',
          'Origen: ${request.origin}\nDestino: ${request.destination}',
        );
        await _playNotificationSound();
      }

      debugPrint('Solicitud procesada y mostrada en UI: ${request.id}');
    } catch (e) {
      debugPrint('Error procesando solicitud: $e');
    }
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'trip_requests',
          'Solicitudes de Viaje',
          importance: Importance.high,
          priority: Priority.high,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(0, title, body, details);
  }

  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification_sound.mp3'));
    } catch (e) {
      debugPrint('Error reproduciendo sonido: $e');
    }
  }

  Future<void> _stopNotificationSound() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('Error deteniendo sonido: $e');
    }
  }

  Future<Map<String, dynamic>> _calculateRoute(
    LatLng start,
    LatLng end,
    List<TripStop> stops,
  ) async {
    try {
      // Usar compute para mover el cálculo a un isolate
      return await compute(_calculateRouteIsolate, {
        'start': [start.latitude, start.longitude],
        'end': [end.latitude, end.longitude],
        'stops':
            stops
                .map(
                  (s) => {
                    'id': s.id,
                    'tripRequestId': s.tripRequestId,
                    'name': s.name, // Añadir name
                    'latitude': s.latitude,
                    'longitude': s.longitude,
                    'orderIndex': s.orderIndex,
                  },
                )
                .toList(),
      });
    } catch (e) {
      debugPrint('Error calculando ruta: $e');
      throw Exception('No se pudo calcular la ruta');
    }
  }

  // Función para ejecutar en un isolate
  static Future<Map<String, dynamic>> _calculateRouteIsolate(
    Map<String, dynamic> params,
  ) async {
    try {
      final start = LatLng(params['start'][0], params['start'][1]);
      final end = LatLng(params['end'][0], params['end'][1]);
      final stops =
          (params['stops'] as List)
              .map(
                (s) => TripStop(
                  id:
                      s['id'] ??
                      'temp_${DateTime.now().millisecondsSinceEpoch}_${s['orderIndex']}',
                  tripRequestId:
                      s['tripRequestId'] ??
                      'temp_request_${DateTime.now().millisecondsSinceEpoch}',
                  name:
                      s['name'] ??
                      'Parada ${s['orderIndex']}', // Añadir name con valor predeterminado
                  latitude: s['latitude'],
                  longitude: s['longitude'],
                  orderIndex: s['orderIndex'],
                ),
              )
              .toList();

      // Ordenar paradas por order_index
      final sortedStops = [...stops]
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      // Crear array con todos los puntos: origen -> paradas -> destino
      final points = [
        start,
        ...sortedStops.map((stop) => LatLng(stop.latitude, stop.longitude)),
        end,
      ];

      // Obtener rutas entre cada par de puntos consecutivos
      final routeSegments = [];
      double totalDistance = 0;
      double totalDuration = 0;
      List<List<double>> allPoints = []; // Lista de coordenadas [lat, lng]

      for (int i = 0; i < points.length - 1; i++) {
        final response = await http.get(
          Uri.parse(
            'https://router.project-osrm.org/route/v1/driving/'
            '${points[i].longitude},${points[i].latitude};'
            '${points[i + 1].longitude},${points[i + 1].latitude}'
            '?steps=true&geometries=geojson&overview=full',
          ),
        );

        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          totalDistance += route['distance'];
          totalDuration += route['duration'];

          final List<dynamic> coordinates = [];
          for (final step in route['legs'][0]['steps']) {
            coordinates.addAll(step['geometry']['coordinates']);
          }

          // Guardar como coordenadas [lat, lng]
          for (final coord in coordinates) {
            allPoints.add([coord[1], coord[0]]);
          }
        }
      }

      return {
        'distance': '${(totalDistance / 1000).toStringAsFixed(1)} km',
        'duration': '${(totalDuration / 60).round()} min',
        'polyline': allPoints,
      };
    } catch (e) {
      print('Error en _calculateRouteIsolate: $e');
      // Devolver una ruta vacía en caso de error
      return {'distance': '0 km', 'duration': '0 min', 'polyline': []};
    }
  }

  void _fitMapToRoute() async {
    debugPrint('Ajustando mapa a la ruta...');

    if (!_mapController.isCompleted) {
      debugPrint('No se puede ajustar el mapa: controlador no inicializado');
      return;
    }

    if (_currentRoute == null) {
      debugPrint('No se puede ajustar el mapa: no hay ruta actual');
      return;
    }

    if (_visibleRoute.isEmpty) {
      debugPrint('No se puede ajustar el mapa: ruta visible vacía');

      // Intentar reconstruir la ruta visible desde _currentRoute
      if (_currentRoute!['polyline'] is List &&
          (_currentRoute!['polyline'] as List).isNotEmpty) {
        try {
          _visibleRoute =
              (_currentRoute!['polyline'] as List)
                  .map((p) {
                    if (p is LatLng) return p;
                    if (p is List && p.length >= 2) {
                      return LatLng(
                        p[0] is double ? p[0] : (p[0] as num).toDouble(),
                        p[1] is double ? p[1] : (p[1] as num).toDouble(),
                      );
                    }
                    return null;
                  })
                  .whereType<LatLng>()
                  .toList();

          if (_visibleRoute.isEmpty) {
            debugPrint('No se pudo reconstruir la ruta visible');
            return;
          }
        } catch (e) {
          debugPrint('Error reconstruyendo ruta visible: $e');
          return;
        }
      } else {
        debugPrint('No hay datos de polyline en la ruta actual');
        return;
      }
    }

    try {
      // Verificar que haya suficientes puntos para crear un bounds
      if (_visibleRoute.length < 2) {
        debugPrint('No hay suficientes puntos para ajustar el mapa');
        return;
      }

      // Calcular los límites de la ruta
      double minLat = double.infinity;
      double maxLat = -double.infinity;
      double minLng = double.infinity;
      double maxLng = -double.infinity;

      for (final point in _visibleRoute) {
        minLat = min(minLat, point.latitude);
        maxLat = max(maxLat, point.latitude);
        minLng = min(minLng, point.longitude);
        maxLng = max(maxLng, point.longitude);
      }

      // Verificar que los límites sean válidos
      if (minLat == double.infinity ||
          maxLat == -double.infinity ||
          minLng == double.infinity ||
          maxLng == -double.infinity) {
        debugPrint('Límites de la ruta no válidos');
        return;
      }

      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      debugPrint('Mapa ajustado a la ruta correctamente');
    } catch (e) {
      debugPrint('Error ajustando el mapa a la ruta: $e');

      // En caso de error, intentar centrar en el primer punto de la ruta
      if (_visibleRoute.isNotEmpty) {
        try {
          final controller = await _mapController.future;
          controller.animateCamera(
            CameraUpdate.newLatLngZoom(_visibleRoute.first, 15),
          );
          debugPrint('Mapa centrado en el primer punto de la ruta');
        } catch (e) {
          debugPrint('Error centrando el mapa en el primer punto: $e');
        }
      }
    }
  }

  Future<void> _handleRequestResponse(String requestId, String status) async {
    try {
      await _stopNotificationSound();

      if (status == 'rejected') {
        // Actualizar el provider primero
        _tripProvider
            .clearTrip(); // Esto limpiará todo incluyendo rutas y marcadores

        // Luego actualizar el estado local
        setState(() {
          _rejectedRequests.add(requestId);
          _pendingRequests = [];
          _currentRoute = null;
          _visibleRoute = [];
          _markers = {};
          _polylines = {};
        });

        await _saveRejectedRequests();
        return;
      }

      if (status == 'accepted') {
        setState(() {
          _isLoading = true;
        });

        // 1. Intentar aceptar la solicitud
        final success = await tripRequestService.attemptAcceptRequest(
          requestId,
          Provider.of<AuthProvider>(context, listen: false).user!.id,
        );

        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Esta solicitud ya no está disponible'),
              backgroundColor: Colors.red,
            ),
          );

          setState(() {
            _pendingRequests = [];
            _currentRoute = null;
            _visibleRoute = [];
            _isLoading = false;
            _markers = {};
            _polylines = {};
          });

          // Actualizar el provider
          _tripProvider.setPendingRequests([]);
          return;
        }

        try {
          // 2. Obtener la solicitud actual con sus paradas
          final currentRequest = _pendingRequests.firstWhere(
            (req) => req.id == requestId,
          );

          debugPrint(
            'Solicitud actual con paradas: ${currentRequest.trip_stops?.length ?? 0}',
          );

          // 3. Confirmar la aceptación y obtener detalles del viaje
          final tripDetails = await tripRequestService.confirmRequestAcceptance(
            requestId,
            Provider.of<AuthProvider>(context, listen: false).user!.id,
          );

          // 4. Crear el viaje activo con los datos recibidos
          final activeTrip = Trip(
            id: tripDetails['id'],
            origin: currentRequest.origin,
            destination: currentRequest.destination,
            originLat: currentRequest.originLat,
            originLng: currentRequest.originLng,
            destinationLat: currentRequest.destinationLat,
            destinationLng: currentRequest.destinationLng,
            price: currentRequest.price,
            status: 'in_progress',
            createdBy: currentRequest.createdBy,
            createdAt: tripDetails['created_at'],
            trip_stops: currentRequest.trip_stops ?? [],
            passengerPhone: currentRequest.passengerPhone,
          );

          setState(() {
            _activeTrip = activeTrip;
            _tripPhase = 'toPickup';
            _currentStopIndex = -1;
            _isLoading = false;
          });

          // Actualizar el provider
          _tripProvider.setActiveTrip(activeTrip);
          _tripProvider.setTripPhase('toPickup');
          _tripProvider.setCurrentStopIndex(-1);

          // 5. Actualizar suscripciones
          _unsubscribeFromRequests();
          _subscribeToTripUpdates();

          // 6. Calcular ruta al punto de recogida
          if (_userLocation != null) {
            final route = await _calculateRoute(
              LatLng(_userLocation!.latitude!, _userLocation!.longitude!),
              LatLng(currentRequest.originLat, currentRequest.originLng),
              [],
            );

            setState(() {
              _currentRoute = route;
              if (route['polyline'] is List) {
                _visibleRoute =
                    (route['polyline'] as List)
                        .map((p) {
                          if (p is List)
                            return LatLng(p[0] as double, p[1] as double);
                          return null;
                        })
                        .whereType<LatLng>()
                        .toList();
              } else {
                _visibleRoute = [];
                debugPrint(
                  'Formato de polyline inesperado: ${route['polyline']}',
                );
              }
            });

            // Actualizar el provider
            _tripProvider.setCurrentRoute(route);

            _fitMapToRoute();
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Viaje aceptado'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          debugPrint('Error confirmando solicitud: $e');
          setState(() {
            _isLoading = false;
            _pendingRequests.removeWhere((req) => req.id == requestId);
          });

          // Actualizar el provider
          _tripProvider.setPendingRequests([]);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo confirmar la solicitud: $e'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      setState(() {
        _pendingRequests.removeWhere((req) => req.id == requestId);
      });

      // Actualizar el provider si no hay solicitudes pendientes
      if (_pendingRequests.isEmpty) {
        _tripProvider.setPendingRequests([]);
      }
    } catch (e) {
      debugPrint('Error procesando respuesta: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo procesar la solicitud: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleArrivalAtPickup() async {
    try {
      if (_activeTrip?.id == null || _userLocation == null) {
        debugPrint('No hay viaje activo o ubicación del usuario');
        return;
      }

      if (_currentStopIndex == -1) {
        await tripRequestService.updateTripStatus(
          _activeTrip!.id,
          'pickup_reached',
        );

        if (_activeTrip!.trip_stops!.isNotEmpty) {
          setState(() {
            _tripPhase = 'toStops';
            _currentStopIndex = 0;
          });

          // Actualizar el provider
          _tripProvider.setTripPhase('toStops');
          _tripProvider.setCurrentStopIndex(0);

          final firstStop = _activeTrip!.trip_stops![0];

          final route = await _calculateRoute(
            LatLng(_activeTrip!.originLat, _activeTrip!.originLng),
            LatLng(firstStop.latitude, firstStop.longitude),
            [],
          );

          setState(() {
            _currentRoute = route;
            _visibleRoute =
                (route['polyline'] as List<dynamic>).map((p) {
                  if (p is LatLng) return p;
                  if (p is List) return LatLng(p[0] as double, p[1] as double);
                  if (p is Map)
                    return LatLng(p['lat'] as double, p['lng'] as double);

                  throw Exception('Formato de punto de ruta no reconocido: $p');
                }).toList();
          });

          // Actualizar el provider
          _tripProvider.setCurrentRoute(route);

          _fitMapToRoute();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Siguiente parada: ${firstStop.name}'),
              backgroundColor: Colors.blue,
            ),
          );
        } else {
          setState(() {
            _tripPhase = 'toDestination';
          });

          // Actualizar el provider
          _tripProvider.setTripPhase('toDestination');

          final route = await _calculateRoute(
            LatLng(_activeTrip!.originLat, _activeTrip!.originLng),
            LatLng(_activeTrip!.destinationLat, _activeTrip!.destinationLng),
            [],
          );

          setState(() {
            _currentRoute = route;
            _visibleRoute =
                (route['polyline'] as List<dynamic>).map((p) {
                  if (p is LatLng) return p;
                  if (p is List) return LatLng(p[0] as double, p[1] as double);
                  if (p is Map)
                    return LatLng(p['lat'] as double, p['lng'] as double);

                  throw Exception('Formato de punto de ruta no reconocido: $p');
                }).toList();
          });

          // Actualizar el provider
          _tripProvider.setCurrentRoute(route);

          _fitMapToRoute();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dirígete al destino final'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } else {
        final currentStop = _activeTrip!.trip_stops![_currentStopIndex];

        if (_currentStopIndex < _activeTrip!.trip_stops!.length - 1) {
          setState(() {
            _currentStopIndex++;
          });

          // Actualizar el provider
          _tripProvider.setCurrentStopIndex(_currentStopIndex + 1);

          final nextStop = _activeTrip!.trip_stops![_currentStopIndex];

          final route = await _calculateRoute(
            LatLng(currentStop.latitude, currentStop.longitude),
            LatLng(nextStop.latitude, nextStop.longitude),
            [],
          );

          setState(() {
            _currentRoute = route;
            _visibleRoute =
                (route['polyline'] as List<dynamic>).map((p) {
                  if (p is LatLng) return p;
                  if (p is List) return LatLng(p[0] as double, p[1] as double);
                  if (p is Map)
                    return LatLng(p['lat'] as double, p['lng'] as double);

                  throw Exception('Formato de punto de ruta no reconocido: $p');
                }).toList();
          });

          // Actualizar el provider
          _tripProvider.setCurrentRoute(route);

          _fitMapToRoute();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Siguiente parada: ${nextStop.name}'),
              backgroundColor: Colors.blue,
            ),
          );
        } else {
          setState(() {
            _tripPhase = 'toDestination';
          });

          // Actualizar el provider
          _tripProvider.setTripPhase('toDestination');

          final route = await _calculateRoute(
            LatLng(currentStop.latitude, currentStop.longitude),
            LatLng(_activeTrip!.destinationLat, _activeTrip!.destinationLng),
            [],
          );

          setState(() {
            _currentRoute = route;
            _visibleRoute =
                (route['polyline'] as List<dynamic>).map((p) {
                  if (p is LatLng) return p;
                  if (p is List) return LatLng(p[0] as double, p[1] as double);
                  if (p is Map)
                    return LatLng(p['lat'] as double, p['lng'] as double);

                  throw Exception('Formato de punto de ruta no reconocido: $p');
                }).toList();
          });

          // Actualizar el provider
          _tripProvider.setCurrentRoute(route);

          _fitMapToRoute();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dirígete al destino final'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error al manejar llegada: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el estado del viaje'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleTripCompletion() async {
    try {
      if (_activeTrip?.id == null || _userLocation == null) return;

      // Verificar si está cerca del destino
      final isNearDestination = _isWithinAllowedDistance(
        _userLocation!.latitude!,
        _userLocation!.longitude!,
        _activeTrip!.destinationLat,
        _activeTrip!.destinationLng,
        maxDistance: 100, // 100 metros de tolerancia
      );

      if (!isNearDestination) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Debes estar más cerca del punto de destino para finalizar el viaje',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await tripRequestService.updateTripStatus(_activeTrip!.id, 'completed');
      final commission = _activeTrip!.price * 0.2;

      final updatedProfile = await driverService.getDriverProfile(
        Provider.of<AuthProvider>(context, listen: false).user!.id,
      );

      setState(() {
        _activeTrip = null;
        _tripPhase = 'none';
        _currentRoute = null;
        _pendingRequests = [];
        _rejectedRequests = [];
      });

      // Limpiar el provider
      _tripProvider.clearTrip();

      _unsubscribeFromTripUpdates();

      // CORRECCIÓN: Asegurarse de que la suscripción a solicitudes se realice
      if (_isOnDuty) {
        _subscribeToDriverRequests();
      }

      if (updatedProfile.balance < 0) {
        await driverService.updateDriverStatus(
          Provider.of<AuthProvider>(context, listen: false).user!.id,
          false,
        );

        await driverService.deactivateUser(
          Provider.of<AuthProvider>(context, listen: false).user!.id,
          false,
        );

        setState(() {
          _isOnDuty = false;
        });

        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Viaje Completado - Cuenta Suspendida'),
                content: Text(
                  'Viaje completado exitosamente.\n'
                  'Se ha descontado una comisión de \$${commission.toStringAsFixed(2)}.\n\n'
                  'Tu cuenta ha sido suspendida por balance negativo. Por favor, '
                  'contacta al administrador para reactivar tu cuenta.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Entendido'),
                  ),
                ],
              ),
        );
      } else {
        await driverService.updateDriverBalance(
          Provider.of<AuthProvider>(context, listen: false).user!.id,
          commission,
          BalanceOperationType.descuento,
          'Comisión del viaje #${_activeTrip!.id}',
          Provider.of<AuthProvider>(context, listen: false).user!.id,
        );

        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Viaje Completado'),
                content: Text(
                  'Viaje completado exitosamente.\n'
                  'Se ha descontado una comisión de \$${commission.toStringAsFixed(2)}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Entendido'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      debugPrint('Error completando viaje: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo completar el viaje'),
          backgroundColor: Colors.red,
        ),
      );
    }

    // Actualizar estado del servicio en segundo plano
    _updateBackgroundServiceState();
  }

  Future<void> _handleTripCancellation() async {
    if (!mounted) return;

    try {
      if (_activeTrip?.id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay viaje activo para cancelar'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Guardar el BuildContext en una variable local
      final currentContext = context;

      final result = await showDialog<bool>(
        context: currentContext,
        barrierDismissible: false,
        builder:
            (BuildContext context) => AlertDialog(
              title: const Text('Cancelar Viaje'),
              content: const Text(
                '¿Estás seguro que deseas cancelar este viaje?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Sí, Cancelar'),
                ),
              ],
            ),
      );

      if (result == true && mounted) {
        // Actualizar el provider primero
        _tripProvider.setLoading(true);

        // Luego actualizar el estado local
        setState(() {
          _isLoading = true;
        });

        try {
          final user =
              Provider.of<AuthProvider>(currentContext, listen: false).user;
          if (user == null) throw Exception('Usuario no encontrado');

          await tripRequestService.cancelTrip(
            _activeTrip!.id,
            'Cancelado por el conductor',
            user.id,
          );

          if (mounted) {
            // Limpiar el provider primero
            _tripProvider.clearTrip();

            // Luego limpiar el estado local
            setState(() {
              _activeTrip = null;
              _tripPhase = 'none';
              _currentRoute = null;
              _pendingRequests = [];
              _currentStopIndex = -1;
              _visibleRoute = [];
              _markers = {};
              _polylines = {};
              _isLoading = false;
            });

            // Actualizar el estado del servicio en segundo plano
            await _updateBackgroundServiceState();

            // CORRECCIÓN: Volver a suscribirse a las solicitudes de viaje si está en servicio
            if (_isOnDuty) {
              _subscribeToDriverRequests();
            }

            ScaffoldMessenger.of(currentContext).showSnackBar(
              const SnackBar(
                content: Text('El viaje ha sido cancelado'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          debugPrint('Error al cancelar viaje: $e');

          // Actualizar el provider primero
          _tripProvider.setLoading(false);

          // Luego actualizar el estado local
          if (mounted) {
            setState(() {
              _isLoading = false;
            });

            ScaffoldMessenger.of(currentContext).showSnackBar(
              SnackBar(
                content: Text('Error: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error en handleTripCancellation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _resumeServices() {
    _setupLocationServiceImproved();
    if (_isOnDuty && _activeTrip == null) {
      _subscribeToDriverRequests();
    } else if (_activeTrip != null) {
      _subscribeToTripUpdates();
    }
  }

  void _pauseServices() {
    _unsubscribeFromRequests();
    _unsubscribeFromTripUpdates();
  }

  Future<Map<String, dynamic>> _recalculateRoute() async {
    if (_userLocation == null || _activeTrip == null) return {};

    try {
      // Determinar el destino según la fase del viaje
      late LatLng destination;
      List<TripStop> stops = [];

      if (_tripPhase == 'toPickup') {
        destination = LatLng(_activeTrip!.originLat, _activeTrip!.originLng);
      } else if (_tripPhase == 'toStops' &&
          _activeTrip!.trip_stops?.isNotEmpty == true &&
          _currentStopIndex >= 0) {
        final nextStop = _activeTrip!.trip_stops![_currentStopIndex];
        destination = LatLng(nextStop.latitude, nextStop.longitude);
      } else {
        destination = LatLng(
          _activeTrip!.destinationLat,
          _activeTrip!.destinationLng,
        );
      }

      final route = await _calculateRoute(
        LatLng(_userLocation!.latitude!, _userLocation!.longitude!),
        destination,
        stops,
      );

      setState(() {
        _currentRoute = route;
        _visibleRoute =
            (route['polyline'] as List<dynamic>).map((p) {
              if (p is LatLng) return p;
              if (p is List) return LatLng(p[0] as double, p[1] as double);
              if (p is Map)
                return LatLng(p['lat'] as double, p['lng'] as double);

              throw Exception('Formato de punto de ruta no reconocido: $p');
            }).toList();
      });

      return route;
    } catch (e) {
      debugPrint('Error recalculando ruta: $e');
      return {};
    }
  }

  Future<void> _stopAlerts() async {
    try {
      // Detener reproducción de audio si está activa
      await _audioPlayer.stop();

      // Cancelar notificaciones
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Error deteniendo alertas: $e');
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371e3; // Radio de la tierra en metros
    final phi1 = lat1 * pi / 180; // phi, lambda en radianes
    final phi2 = lat2 * pi / 180;
    final deltaPhi = (lat2 - lat1) * pi / 180;
    final deltaLambda = (lon2 - lon1) * pi / 180;

    final a =
        sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c; // en metros
  }

  bool _isWithinAllowedDistance(
    double currentLat,
    double currentLon,
    double targetLat,
    double targetLon, {
    double maxDistance = 100,
  }) {
    final distance = _calculateDistance(
      currentLat,
      currentLon,
      targetLat,
      targetLon,
    );
    return distance <= maxDistance;
  }

  @override
  Widget build(BuildContext context) {
    // Usar el provider para obtener el estado actual
    final tripProvider = Provider.of<TripProvider>(context);

    // Sincronizar el estado local con el provider si es necesario
    if (tripProvider.activeTrip != null && _activeTrip == null) {
      _activeTrip = tripProvider.activeTrip;
      _tripPhase = tripProvider.tripPhase;
      _currentStopIndex = tripProvider.currentStopIndex;
    }

    if (tripProvider.pendingRequests.isNotEmpty && _pendingRequests.isEmpty) {
      _pendingRequests = tripProvider.pendingRequests;
    }

    if (tripProvider.currentRoute != null && _currentRoute == null) {
      _currentRoute = tripProvider.currentRoute;
      _visibleRoute = tripProvider.visibleRoute;
    }

    if (tripProvider.markers.isNotEmpty && _markers.isEmpty) {
      _markers = tripProvider.markers;
    }

    if (tripProvider.polylines.isNotEmpty && _polylines.isEmpty) {
      _polylines = tripProvider.polylines;
    }

    // Usar isLoading del provider si está disponible
    final isLoading = tripProvider.isLoading || _isLoading;

    return Scaffold(
      body: Stack(
        children: [
          // Mapa de Google
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: _markers,
            polylines: _polylines,
            onMapCreated: _onMapCreated,
          ),

          // Indicador de carga mientras se inicializa
          if (isLoading)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: const Center(child: CircularProgressIndicator()),
            ),

          // Panel de estado (en servicio/fuera de servicio)
          Positioned(
            bottom: 6,
            left: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isOnDuty ? Icons.online_prediction : Icons.offline_bolt,
                    color: _isOnDuty ? Colors.green : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  // Usar Transform.scale para hacer el switch más pequeño
                  Transform.scale(
                    scale: 0.8, // Reducir el tamaño al 80%
                    child: Switch(
                      value: _isOnDuty,
                      onChanged: _toggleDutyStatus,
                      activeColor: Colors.red,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Panel de solicitud de viaje
          if (_pendingRequests.isNotEmpty && _activeTrip == null)
            _buildRequestPanel(),

          // Panel de viaje activo
          if (_activeTrip != null) _buildActiveTripPanel(),

          // Botón de menú
          Positioned(
            top: 40,
            left: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                setState(() {
                  _isSidebarVisible = true;
                });
              },
              child: const Icon(LucideIcons.menu, color: Colors.red),
            ),
          ),

          // Botón para forzar la actualización de ubicación
          Positioned(
            top: 40,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () async {
                setState(() {
                  _isLoading = true;
                });

                try {
                  // Forzar actualización de ubicación
                  final locationData = await _location.getLocation();
                  setState(() {
                    _userLocation = locationData;
                    _isLoading = false;
                  });

                  // Centrar mapa en la nueva ubicación
                  _centerMapOnCurrentLocation();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ubicación actualizada'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 1),
                    ),
                  );
                } catch (e) {
                  setState(() {
                    _isLoading = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error al actualizar ubicación'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Icon(Icons.my_location, color: Colors.red),
            ),
          ),

          // Sidebar
          Sidebar(
            isVisible: _isSidebarVisible,
            onClose: () {
              setState(() {
                _isSidebarVisible = false;
              });
            },
            role: 'chofer',
          ),
        ],
      ),
    );
  }

  Set<Polyline> _buildPolylines() {
    final Set<Polyline> polylines = {};

    if (_visibleRoute.isEmpty) return polylines;

    // Crear polyline para la ruta
    polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: _visibleRoute,
        color: Colors.blue,
        width: 5,
      ),
    );

    return polylines;
  }

  Set<Marker> _buildMarkers() {
    final Set<Marker> markers = {};

    // Añadir marcador para el origen del viaje activo
    if (_activeTrip != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: LatLng(_activeTrip!.originLat, _activeTrip!.originLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(title: 'Origen', snippet: _activeTrip!.origin),
        ),
      );

      // Añadir marcador para el destino del viaje activo
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(
            _activeTrip!.destinationLat,
            _activeTrip!.destinationLng,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: 'Destino',
            snippet: _activeTrip!.destination,
          ),
        ),
      );
    }

    // Añadir marcadores para solicitudes pendientes
    if (_pendingRequests.isNotEmpty) {
      final request = _pendingRequests[0];
      markers.add(
        Marker(
          markerId: const MarkerId('request_origin'),
          position: LatLng(request.originLat, request.originLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow,
          ),
          infoWindow: InfoWindow(
            title: 'Origen de solicitud',
            snippet: request.origin,
          ),
        ),
      );

      markers.add(
        Marker(
          markerId: const MarkerId('request_destination'),
          position: LatLng(request.destinationLat, request.destinationLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title: 'Destino de solicitud',
            snippet: request.destination,
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildRequestPanel() {
    if (_pendingRequests.isEmpty) return const SizedBox.shrink();

    final request = _pendingRequests[0];

    return Positioned(
      top: kToolbarHeight + 20, // Ajustar la posición para que sea visible
      left: 16,
      right: 16,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Detalles del Viaje',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _currentRoute?['distance'] ?? '',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    LucideIcons.messageSquare,
                    size: 20,
                    color: Color(0xFF6366F1),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.observations ?? 'Sin observaciones',
                      style: const TextStyle(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '\$',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    request.price.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF22C55E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '${_currentRoute?['duration'] ?? ''} • ${_currentRoute?['distance'] ?? ''} • Efectivo',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed:
                        () => _handleRequestResponse(request.id, 'rejected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.x, size: 20),
                        SizedBox(width: 8),
                        Text('Rechazar'),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed:
                        () => _handleRequestResponse(request.id, 'accepted'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.check, size: 20),
                        SizedBox(width: 8),
                        Text('Aceptar'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTripPanel() {
    String phaseText = '';
    IconData phaseIcon = LucideIcons.mapPin;
    Color phaseColor = Colors.red;

    if (_tripPhase == 'toPickup') {
      phaseText = 'Origen';
      phaseIcon = LucideIcons.mapPin;
      phaseColor = Colors.red;
    } else if (_tripPhase == 'toStops') {
      phaseText = 'Parada ${_currentStopIndex + 1}';
      phaseIcon = LucideIcons.mapPin;
      phaseColor = const Color(0xFF8B5CF6);
    } else if (_tripPhase == 'toDestination') {
      phaseText = 'Destino';
      phaseIcon = LucideIcons.mapPin;
      phaseColor = const Color(0xFF22C55E);
    }

    return Positioned(
      bottom: 80,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(phaseIcon, color: phaseColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  phaseText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                // Botón de llegada
                CircleAvatar(
                  backgroundColor: const Color(0xFF059669),
                  radius: 20,
                  child: IconButton(
                    icon: const Icon(
                      LucideIcons.mapPin,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed:
                        _tripPhase == 'toDestination'
                            ? _handleTripCompletion
                            : _handleArrivalAtPickup,
                  ),
                ),
                const SizedBox(width: 8),

                // Botón de llamada
                CircleAvatar(
                  backgroundColor: const Color(0xFF2563EB),
                  radius: 20,
                  child: IconButton(
                    icon: const Icon(
                      LucideIcons.phone,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed:
                        () => _launchPhoneCall(_activeTrip?.passengerPhone),
                  ),
                ),
                const SizedBox(width: 8),

                // Botón de mensaje
                CircleAvatar(
                  backgroundColor: const Color(0xFF7C3AED),
                  radius: 20,
                  child: IconButton(
                    icon: const Icon(
                      LucideIcons.messageSquare,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => _launchSMS(_activeTrip?.passengerPhone),
                  ),
                ),
                const SizedBox(width: 8),

                // Botón de cancelar
                CircleAvatar(
                  backgroundColor: Colors.red,
                  radius: 20,
                  child: IconButton(
                    icon: const Icon(
                      LucideIcons.x,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: _handleTripCancellation,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchPhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay número de teléfono disponible'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo iniciar la llamada'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _launchSMS(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay número de teléfono disponible'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final Uri uri = Uri(scheme: 'sms', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo iniciar el mensaje'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Actualizar cuando se inicia o completa un viaje
  Future<void> _updateBackgroundServiceState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_active_trip', _activeTrip != null);

    // Si tenemos un viaje activo, detener el servicio en segundo plano
    if (_activeTrip != null && _backgroundService != null) {
      _backgroundService!.invoke('stopService');
      debugPrint('Servicio en segundo plano detenido (viaje activo)');
    }
    // Si no tenemos viaje activo, estamos en servicio y la app está en segundo plano, iniciar servicio
    else if (_activeTrip == null &&
        _isOnDuty &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused &&
        _backgroundService != null) {
      _backgroundService!.startService();
      debugPrint('Servicio en segundo plano iniciado (después de viaje)');
    }
  }

  Future<void> _setupBackgroundService() async {
    try {
      _backgroundService = FlutterBackgroundService();
      await initializeBackgroundService();

      _backgroundService?.on('newRequest').listen((event) async {
        if (event != null && event['request'] != null) {
          try {
            debugPrint(
              'Nueva solicitud recibida del servicio en segundo plano',
            );
            final requestData = jsonDecode(event['request']);
            final request = TripRequest.fromJson(requestData);

            // Guardar en el provider
            final tripProvider = Provider.of<TripProvider>(
              context,
              listen: false,
            );

            // Verificar si la solicitud ya existe en el provider
            if (!tripProvider.hasRequest(request.id)) {
              debugPrint(
                'Guardando nueva solicitud en provider: ${request.id}',
              );
              tripProvider.saveBackgroundRequest(request);
            } else {
              debugPrint(
                'La solicitud ya existe en el provider: ${request.id}',
              );
            }

            // Si la app está en primer plano, mostrar inmediatamente
            if (WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed) {
              await _handleNewRequest(request);
            }

            debugPrint('Solicitud guardada en provider');
          } catch (e) {
            debugPrint('Error procesando solicitud del servicio: $e');
          }
        }
      });
    } catch (e) {
      debugPrint('Error configurando servicio en segundo plano: $e');
    }
  }

  // Método para guardar el estado actual
  Future<void> _saveCurrentState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      final userId = authProvider.user?.id;

      if (userId != null) {
        await prefs.setString('user_id', userId);
        await prefs.setBool('is_on_duty', _isOnDuty);

        // Guardar viaje activo
        if (_activeTrip != null) {
          await prefs.setString(
            'active_trip',
            jsonEncode(_activeTrip!.toJson()),
          );
          await prefs.setString('trip_phase', _tripPhase);

          // También actualizar el provider
          tripProvider.setActiveTrip(_activeTrip);
          tripProvider.setTripPhase(_tripPhase);
        } else {
          await prefs.remove('active_trip');
          await prefs.remove('trip_phase');

          // Limpiar el provider
          tripProvider.setActiveTrip(null);
          tripProvider.setTripPhase('none');
        }

        // Ya no necesitamos guardar las solicitudes pendientes en SharedPreferences
        // porque ahora usamos el provider
      }
    } catch (e) {
      debugPrint('Error guardando estado: $e');
    }
  }

  // Método para centrar el mapa en la ubicación actual
  Future<void> _centerMapOnCurrentLocation() async {
    if (_userLocation == null || !_mapController.isCompleted) {
      debugPrint('No se puede centrar el mapa: faltan datos necesarios');
      return;
    }

    try {
      final controller = await _mapController.future;
      final position = LatLng(
        _userLocation!.latitude!,
        _userLocation!.longitude!,
      );
      controller.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
      debugPrint(
        'Mapa centrado en: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      debugPrint('Error centrando el mapa: $e');
    }
  }

  // Método para configurar la suscripción a solicitudes de viaje

  // Nueva función para procesar solicitudes entrantes
  void _processIncomingRequest(dynamic requestData) async {
    TripRequest request;

    try {
      if (requestData is TripRequest) {
        request = requestData;
      } else if (requestData is Map<String, dynamic>) {
        request = TripRequest.fromJson(requestData);
      } else {
        throw Exception('Formato de solicitud inválido');
      }

      debugPrint('Procesando solicitud: ${request.id}');

      // Si la app está en segundo plano, guardar la solicitud
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused) {
        debugPrint('App en segundo plano, guardando solicitud');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_request', jsonEncode(request.toJson()));
        return;
      }

      // Si la app está activa, procesar la solicitud inmediatamente
      await _handleNewRequest(request);
    } catch (e) {
      debugPrint('Error procesando solicitud: $e');
    }
  }

  // Llamar a este método en initState o después de _loadDriverStatus
  void _initializeRequestSubscription() {
    if (_isOnDuty) {
      _subscribeToDriverRequests();
    }
  }

  Future<void> _showTripRequestNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'trip_requests',
          'Solicitudes de Viaje',
          importance: Importance.high,
          priority: Priority.high,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(0, title, body, details);
  }

  // Método para restaurar el estado
  Future<void> _restoreState() async {
    // Si ya se restauró el estado, no volver a hacerlo
    if (_stateRestored) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final tripProvider = Provider.of<TripProvider>(context, listen: false);

      // Cargar solicitudes pendientes desde SharedPreferences (solo una vez)
      await tripProvider.loadPendingRequestsFromPrefs();

      // Restaurar viaje activo
      final activeTrip = prefs.getString('active_trip');
      if (activeTrip != null) {
        final tripData = Trip.fromJson(jsonDecode(activeTrip));
        final tripPhase = prefs.getString('trip_phase') ?? 'none';

        // Actualizar el provider primero
        tripProvider.setActiveTrip(tripData);
        tripProvider.setTripPhase(tripPhase);

        // Luego actualizar el estado local
        setState(() {
          _activeTrip = tripData;
          _tripPhase = tripPhase;
        });
      }

      // Verificar si hay solicitudes pendientes en el provider
      if (tripProvider.pendingRequests.isNotEmpty) {
        setState(() {
          _pendingRequests = tripProvider.pendingRequests;
          _currentRoute = tripProvider.currentRoute;
          _visibleRoute = tripProvider.visibleRoute;
          _markers = tripProvider.markers;
          _polylines = tripProvider.polylines;
        });

        // Si hay solicitudes pendientes pero no hay ruta calculada, calcularla
        if (_currentRoute == null &&
            _userLocation != null &&
            _pendingRequests.isNotEmpty) {
          final request = _pendingRequests.first;
          final route = await _calculateRoute(
            LatLng(_userLocation!.latitude!, _userLocation!.longitude!),
            LatLng(request.originLat, request.originLng),
            request.trip_stops ?? [],
          );

          setState(() {
            _currentRoute = route;
            if (route['polyline'] is List) {
              _visibleRoute =
                  (route['polyline'] as List)
                      .map((p) {
                        if (p is List)
                          return LatLng(p[0] as double, p[1] as double);
                        return null;
                      })
                      .whereType<LatLng>()
                      .toList();
            }
            _markers = _buildMarkers();
            _polylines = _buildPolylines();
          });

          tripProvider.setCurrentRoute(route);
          tripProvider.setVisibleRoute(_visibleRoute);
          tripProvider.setMarkers(_markers);
          tripProvider.setPolylines(_polylines);

          // Ajustar el mapa solo una vez
          _fitMapToRoute();
        }
      }

      // Marcar que el estado ya se restauró
      _stateRestored = true;
    } catch (e) {
      debugPrint('Error restaurando estado: $e');
    }
  }

  // Nuevo método para reconstruir el estado del mapa
  void _rebuildMapState() {
    if (mounted) {
      setState(() {
        _markers = _buildMarkers();
        _polylines = _buildPolylines();
      });

      if (_currentRoute != null) {
        _fitMapToRoute();
      } else if (_userLocation != null) {
        _centerMapOnCurrentLocation();
      }
    }
  }

  // Nuevo método para sincronizar con el provider
  void _syncWithProvider() {
    bool needsUpdate = false;
    Map<String, dynamic> newState = {};

    // Verificar si necesitamos actualizar el estado local desde el provider
    if (_tripProvider.activeTrip != null &&
        _activeTrip != _tripProvider.activeTrip) {
      newState['activeTrip'] = _tripProvider.activeTrip;
      newState['tripPhase'] = _tripProvider.tripPhase;
      newState['currentStopIndex'] = _tripProvider.currentStopIndex;
      needsUpdate = true;
    } else if (_activeTrip != null && _tripProvider.activeTrip == null) {
      // Actualizar el provider desde el estado local (sin setState)
      _tripProvider.updateTripState(
        activeTrip: _activeTrip,
        tripPhase: _tripPhase,
        currentStopIndex: _currentStopIndex,
      );
    }

    // Hacer lo mismo con las solicitudes pendientes
    if (_tripProvider.pendingRequests.isNotEmpty &&
        _pendingRequests != _tripProvider.pendingRequests) {
      newState['pendingRequests'] = _tripProvider.pendingRequests;
      needsUpdate = true;
    } else if (_pendingRequests.isNotEmpty &&
        _tripProvider.pendingRequests.isEmpty) {
      _tripProvider.setPendingRequests(_pendingRequests);
    }

    // Y con la ruta actual
    if (_tripProvider.currentRoute != null &&
        _currentRoute != _tripProvider.currentRoute) {
      newState['currentRoute'] = _tripProvider.currentRoute;
      newState['visibleRoute'] = _tripProvider.visibleRoute;
      needsUpdate = true;
    } else if (_currentRoute != null && _tripProvider.currentRoute == null) {
      _tripProvider.setCurrentRoute(_currentRoute);
    }

    // Actualizar el estado local solo si es necesario
    if (needsUpdate && mounted) {
      setState(() {
        if (newState.containsKey('activeTrip'))
          _activeTrip = newState['activeTrip'];
        if (newState.containsKey('tripPhase'))
          _tripPhase = newState['tripPhase'];
        if (newState.containsKey('currentStopIndex'))
          _currentStopIndex = newState['currentStopIndex'];
        if (newState.containsKey('pendingRequests'))
          _pendingRequests = newState['pendingRequests'];
        if (newState.containsKey('currentRoute'))
          _currentRoute = newState['currentRoute'];
        if (newState.containsKey('visibleRoute'))
          _visibleRoute = newState['visibleRoute'];

        // Reconstruir marcadores y polylines solo si es necesario
        if (newState.containsKey('currentRoute') ||
            newState.containsKey('activeTrip')) {
          _markers = _buildMarkers();
          _polylines = _buildPolylines();

          // Actualizar el provider sin notificar
          _tripProvider.setMarkers(_markers);
          _tripProvider.setPolylines(_polylines);
        }
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController.complete(controller);
    debugPrint('Mapa creado correctamente');

    // Intentar ajustar el mapa después de que se haya creado
    if (_currentRoute != null && _visibleRoute.isNotEmpty) {
      // Dar tiempo para que el mapa se inicialice completamente
      Future.delayed(const Duration(milliseconds: 500), () {
        _fitMapToRoute();
      });
    } else if (_userLocation != null) {
      // Si no hay ruta, centrar en la ubicación actual
      Future.delayed(const Duration(milliseconds: 500), () {
        _centerMapOnCurrentLocation();
      });
    }
  }
}
