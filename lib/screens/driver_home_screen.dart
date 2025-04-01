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
import '../utils/constants.dart'; // Importar constantes

// Definir instancias de los servicios globalmente o pasarlas a través del constructor/provider
final driverService = DriverService();
final tripRequestService =
    TripRequestService(); // Asegúrate que esta también esté

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  // --- Canal para el servicio persistente (MENOS intrusivo) ---
  const AndroidNotificationChannel serviceChannel = AndroidNotificationChannel(
    NOTIFICATION_CHANNEL_SERVICE_ID, // Usar constante
    NOTIFICATION_CHANNEL_SERVICE_NAME, // Usar constante
    description: 'Mantiene activo el servicio para recibir solicitudes',
    importance: Importance.low, // Baja importancia para que no sea molesta
    enableVibration: false,
    playSound: false, // Sin sonido para la notificación persistente
  );

  // --- Canal para las NUEVAS SOLICITUDES (MUY intrusivo) ---
  const AndroidNotificationChannel requestChannel = AndroidNotificationChannel(
    NOTIFICATION_CHANNEL_REQUESTS_ID, // Usar constante
    NOTIFICATION_CHANNEL_REQUESTS_NAME, // Usar constante
    description: 'Notificaciones para nuevas solicitudes de viaje',
    importance: Importance.max, // MÁXIMA importancia para heads-up
    enableVibration: true, // Habilitar vibración
    playSound: true, // Habilitar sonido
    sound: RawResourceAndroidNotificationSound(
      'notification_sound', // Asegúrate que 'notification_sound.mp3' (o el formato correcto) existe en android/app/src/main/res/raw
    ),
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Crear ambos canales
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(serviceChannel); // Crear canal de servicio
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(requestChannel); // Crear canal de solicitudes

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      // Usar el ID del CANAL DE SERVICIO para la notificación persistente
      notificationChannelId: NOTIFICATION_CHANNEL_SERVICE_ID,
      initialNotificationTitle: NOTIFICATION_CHANNEL_SERVICE_NAME,
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
  WidgetsFlutterBinding.ensureInitialized(); // Asegurar inicialización de bindings

  RealtimeChannel? requestSubscription;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final TripRequestService tripRequestService = TripRequestService();
  String? driverId;

  // Configurar notificación inicial (usando el canal de SERVICIO)
  if (service is AndroidServiceInstance) {
    await service.setForegroundNotificationInfo(
      title: NOTIFICATION_CHANNEL_SERVICE_NAME,
      content: 'Iniciando servicio...',
    );
    // Asegurarse de que el servicio se mantenga en primer plano
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
      print('BG Service: Forzado a primer plano.');
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
      print('BG Service: Pasado a segundo plano.');
    });
  }

  print('BG Service: Iniciando...');

  try {
    // 1. Obtener Driver ID de SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final _authProvider = AuthProvider();
    driverId = prefs.getString(PREFS_USER_ID);
    final vehiculoType = _authProvider.user?.driverProfile?.vehicleType;
    if (driverId == null) {
      throw Exception(
        'BG Service Error: No se encontró ID del conductor en SharedPreferences.',
      );
    }
    print('BG Service: Driver ID obtenido: $driverId');

    // 2. Inicializar Supabase (si no está inicializado)
    try {
      Supabase.instance.client;
      print('BG Service: Supabase ya está inicializado.');
    } catch (_) {
      print('BG Service: Inicializando Supabase...');
      try {
        await Supabase.initialize(
          url:
              'https://gunevwlqmwhwsykpvfqi.supabase.co', // Considerar obtener de variables de entorno
          anonKey:
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd1bmV2d2xxbXdod3N5a3B2ZnFpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzkyOTAwMTksImV4cCI6MjA1NDg2NjAxOX0.FR-CGD6ZUPSh5_0MKUYiUgYuKcyi96ACjwrmYFVJqoE', // Considerar obtener de variables de entorno
        );
        print('BG Service: Supabase inicializado correctamente.');
      } catch (e) {
        throw Exception(
          'BG Service Error: Falló la inicialización de Supabase: $e',
        );
      }
    }

    final supabase =
        Supabase.instance.client; // Ahora seguro que está inicializado

    // Función para manejar la recepción de solicitudes
    Future<void> handleRequest(dynamic payload) async {
      try {
        print('BG Service: Solicitud recibida: $payload');
        if (payload is! Map<String, dynamic>) {
          print('BG Service Error: Payload inesperado: ${payload.runtimeType}');
          return;
        }
        final request = TripRequest.fromJson(payload);

        print('BG Service: Solicitud parseada: ${request.id}');

        // Enviar mensaje a la app principal (si está activa)
        service.invoke('newRequest', {'request': jsonEncode(request.toJson())});
        print('BG Service: Mensaje "newRequest" invocado para la UI.');

        // --- Mostrar notificación local (¡IMPORTANTE!) ---
        // Usar el canal específico para SOLICITUDES con alta importancia
        const androidDetails = AndroidNotificationDetails(
          NOTIFICATION_CHANNEL_REQUESTS_ID, // <-- Usar el ID del canal de SOLICITUDES
          NOTIFICATION_CHANNEL_REQUESTS_NAME, // <-- Usar el nombre del canal de SOLICITUDES
          channelDescription:
              'Notificaciones para nuevas solicitudes de viaje', // Descripción opcional
          importance: Importance.max, // MÁXIMA importancia
          priority: Priority.high, // ALTA prioridad
          playSound: true, // ASEGURAR sonido
          enableVibration: true, // ASEGURAR vibración
          // El sonido ya está asociado al canal, pero podemos especificarlo aquí también por si acaso
          sound: RawResourceAndroidNotificationSound('notification_sound'),
          ticker:
              '¡Nueva solicitud!', // Texto que aparece brevemente en la barra de estado
        );
        const NotificationDetails notificationDetails = NotificationDetails(
          android: androidDetails,
          // iOS: Configuración específica si es necesario
        );

        print('BG Service: Mostrando notificación local para ${request.id}...');
        await flutterLocalNotificationsPlugin.show(
          request.hashCode, // Usar un ID único (hashCode puede funcionar)
          '¡Nueva solicitud de viaje!',
          'Origen: ${request.origin}\nDestino: ${request.destination}',
          notificationDetails, // Usar los detalles configurados
        );
        print('BG Service: Notificación local mostrada.');
      } catch (e, s) {
        print('BG Service Error: Error procesando solicitud recibida: $e\n$s');
      }
    }

    // Función para manejar errores de suscripción
    void handleError(dynamic error) {
      print('BG Service Error: Error en suscripción Realtime: $error');
      // Considerar lógica de reintento o notificación de error persistente
    }

    // 3. Suscribirse a las solicitudes
    print('BG Service: Suscribiéndose a solicitudes para conductor: $driverId');
    requestSubscription = await tripRequestService.subscribeToDriverRequests(
      driverId,
      vehiculoType,
      handleRequest, // Usar la función definida arriba
      handleError,
    );
    print('BG Service: Suscripción configurada.');

    // 4. Escuchar solicitudes de parada desde la UI
    service.on('stopService').listen((event) {
      print('BG Service: Recibida señal de parada.');
      requestSubscription?.unsubscribe();
      requestSubscription = null; // Limpiar referencia
      service.stopSelf();
      print('BG Service: Detenido.');
    });

    // 5. Heartbeat y actualización de notificación persistente
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (service is AndroidServiceInstance) {
        if (!await service.isForegroundService()) {
          print(
            "BG Service Timer: El servicio ya no está en primer plano, deteniendo timer.",
          );
          timer.cancel();
          return;
        }
        try {
          // Actualizar la notificación persistente (canal de SERVICIO)
          await service.setForegroundNotificationInfo(
            title: NOTIFICATION_CHANNEL_SERVICE_NAME,
            content:
                'Buscando viajes disponibles... (${DateTime.now().hour}:${DateTime.now().minute})',
          );
          // print('BG Service: Heartbeat - Servicio activo.');
        } catch (e) {
          print(
            "BG Service Timer: Error al actualizar notificación (posiblemente detenido): $e",
          );
          timer.cancel();
        }
      }
    });

    // Notificar que el servicio está listo (usando canal de SERVICIO)
    if (service is AndroidServiceInstance) {
      await service.setForegroundNotificationInfo(
        title: NOTIFICATION_CHANNEL_SERVICE_NAME,
        content: 'Servicio activo. Buscando viajes...',
      );
      print('BG Service: Notificación persistente actualizada a "activo".');
    }
    print('BG Service: onStart completado.');
  } catch (e, s) {
    print('BG Service Error: Error fatal en onStart: $e\n$s');
    requestSubscription?.unsubscribe();
    service.stopSelf(); // Detener el servicio si hay un error crítico inicial
  }
}

// --- Widget Principal ---

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
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  FlutterBackgroundService? _backgroundService;
  StreamSubscription<location_pkg.LocationData>? _locationSubscription;
  bool _notificationsEnabled = false; // Para rastrear permiso

  // Estado local mínimo (principalmente UI y control)
  bool _isSidebarVisible = false;
  bool _isLoading = true; // Para la carga inicial de la pantalla
  bool _isOnDuty =
      false; // Estado local para el switch, sincronizado con el provider/prefs
  location_pkg.LocationData? _userLocation;
  List<String> _rejectedRequests =
      []; // IDs de solicitudes rechazadas en esta sesión
  bool _isFirstLocationUpdate = true;
  bool _stateRestored = false; // Para evitar restauraciones múltiples

  // Acceso al Provider (se inicializará en initState)
  late TripProvider _tripProvider;
  late AuthProvider _authProvider;

  // Posición inicial del mapa (puede ser actualizada con la ubicación del usuario)
  CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(23.1136, -82.3666), // Coordenadas por defecto (Habana)
    zoom: 14, // Zoom inicial un poco más alejado
  );

  // Suscripciones Realtime (manejadas centralmente)
  RealtimeChannel? _requestSubscription;
  RealtimeChannel? _tripSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Obtener instancias de Provider SIN escuchar cambios aquí
    _tripProvider = Provider.of<TripProvider>(context, listen: false);
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _initializeApp();
    _setupBackgroundServiceListener(); // Escuchar mensajes del servicio BG
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Restaurar estado si es necesario (ej. al volver de otra pantalla)
    // Esto ahora es manejado principalmente por el provider y _initializeApp
    // Se podría añadir lógica específica si fuera necesario, pero intentaremos evitarlo.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unsubscribeFromRequests(); // Asegurar limpieza
    _unsubscribeFromTripUpdates(); // Asegurar limpieza
    _audioPlayer.dispose();
    _location.onLocationChanged.listen(
      null,
    ); // Detener escucha explícita si aún existe
    // No detener el servicio en segundo plano aquí, se maneja en didChangeAppLifecycleState
    super.dispose();
  }

  // --- Gestión del Ciclo de Vida ---

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    final bool isOnDuty = _isOnDuty;
    final bool hasActiveTrip = _tripProvider.activeTrip != null;
    _backgroundService ??= FlutterBackgroundService(); // Inicializar si es null
    bool serviceIsRunning = await _backgroundService!.isRunning();

    print(
      "App Lifecycle State: $state, IsOnDuty: $isOnDuty, HasActiveTrip: $hasActiveTrip, ServiceRunning: $serviceIsRunning, NotificationsEnabled: $_notificationsEnabled",
    );

    switch (state) {
      case AppLifecycleState.resumed:
        print('App Resumed');
        // Verificar permisos al volver a la app
        await _checkNotificationPermission();

        if (serviceIsRunning) {
          print('Deteniendo servicio en segundo plano al volver a la app...');
          _backgroundService!.invoke('stopService');
          await Future.delayed(const Duration(milliseconds: 200));
        } else {
          print('Servicio en segundo plano no estaba corriendo al resumir.');
        }

        await _restoreStateIfNeeded();
        _resumeServices(); // Reanudar escuchas UI

        _updateCurrentLocation(centerMap: !_stateRestored);

        // Procesar solicitudes pendientes que llegaron mientras estaba en BG
        await _tripProvider.processPendingBackgroundRequests(
          this._handleNewRequest, // Usar el handler de la UI
        );
        break;

      case AppLifecycleState.inactive:
        print('App Inactive');
        break;

      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        print('App Paused or Hidden');
        await _saveCurrentState();
        _pauseServices(); // Pausar listeners UI

        // Iniciar servicio en segundo plano SOLO si está en servicio, tiene permisos y no está ya corriendo
        if (isOnDuty && _notificationsEnabled && !serviceIsRunning) {
          print('Iniciando servicio en segundo plano (desde $state)...');
          try {
            await _backgroundService!.startService();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(PREFS_HAS_ACTIVE_TRIP, hasActiveTrip);
          } catch (e) {
            print("Error al iniciar el servicio en segundo plano: $e");
          }
        } else if (!isOnDuty && serviceIsRunning) {
          print(
            'Deteniendo servicio en segundo plano porque no está en servicio...',
          );
          _backgroundService!.invoke('stopService');
        } else {
          print(
            'No se inicia/detiene el servicio BG. IsOnDuty: $isOnDuty, NotificationsEnabled: $_notificationsEnabled, ServiceRunning: $serviceIsRunning',
          );
        }
        break;

      case AppLifecycleState.detached:
        print('App Detached');
        _pauseServices();
        await _saveCurrentState();
        // No detener el servicio aquí si queremos que siga corriendo
        break;
    }
  }

  // --- Inicialización ---

  Future<void> _initializeApp() async {
    print("Inicializando App...");
    setState(() => _isLoading = true);
    try {
      await _authProvider.checkAuthStatus();
      await _loadRejectedRequests();
      await _initializeNotifications(); // Inicializar notificaciones y canales
      await _checkNotificationPermission(); // Verificar permiso de notificaciones
      await _setupLocationServiceImproved(); // Configurar ubicación (incluye permisos de ubicación)
      await _loadDriverStatusFromPrefs(); // Cargar estado onDuty
      await _restoreStateIfNeeded();
      _initializeSubscriptions(); // Suscripciones Realtime si aplica
    } catch (e, s) {
      print('Error durante la inicialización: $e\n$s');
      // Mostrar error al usuario si es crítico
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al inicializar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print("Inicialización completada.");
    }
  }

  Future<void> _initializeNotifications() async {
    print("Inicializando notificaciones locales...");
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      // Podrías añadir onDidReceiveNotificationResponse aquí si necesitas manejar taps en notificaciones
    );
    print("Notificaciones locales inicializadas.");

    // La creación de canales ahora se centraliza en initializeBackgroundService
    // pero llamarlo aquí asegura que existan incluso si el servicio BG no se inicia inmediatamente.
    await initializeBackgroundService();
    print("Canales de notificación asegurados.");
  }

  // Nueva función para verificar y solicitar permiso de notificaciones
  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    print("Estado del permiso de notificación: $status");
    if (status.isDenied) {
      final result = await Permission.notification.request();
      print("Resultado de la solicitud de permiso de notificación: $result");
      _notificationsEnabled = result.isGranted;
    } else {
      _notificationsEnabled = status.isGranted;
    }

    if (!_notificationsEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Se requieren permisos de notificación para recibir alertas de viaje en segundo plano.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _loadDriverStatusFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Cargar estado de servicio directamente de prefs al inicio
      _isOnDuty = prefs.getBool(PREFS_IS_ON_DUTY) ?? false;
      // No llamar a setState aquí todavía, se hará al final de _initializeApp
    } catch (e) {
      print('Error cargando estado de servicio desde Prefs: $e');
      _isOnDuty = false; // Valor por defecto seguro
    }
    // Sincronizar con el perfil real (opcional, pero bueno para consistencia)
    // await _syncDriverStatusWithBackend();
  }

  // Opcional: Sincronizar estado con backend si difiere de prefs
  Future<void> _syncDriverStatusWithBackend() async {
    try {
      final user = _authProvider.user;
      if (user == null) return;
      final driverProfile = await driverService.getDriverProfile(user.id);
      if (driverProfile.isOnDuty != _isOnDuty) {
        print(
          "Sincronizando estado 'isOnDuty' con backend (${driverProfile.isOnDuty})",
        );
        await _toggleDutyStatus(
          driverProfile.isOnDuty,
          updateBackend: false,
        ); // Actualizar localmente
      }
    } catch (e) {
      print('Error sincronizando estado del conductor con backend: $e');
    }
  }

  Future<void> _loadRejectedRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _rejectedRequests = prefs.getStringList(PREFS_REJECTED_REQUESTS) ?? [];
    } catch (e) {
      print('Error cargando solicitudes rechazadas: $e');
      _rejectedRequests = [];
    }
  }

  Future<void> _saveRejectedRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(PREFS_REJECTED_REQUESTS, _rejectedRequests);
    } catch (e) {
      print('Error guardando solicitudes rechazadas: $e');
    }
  }

  // --- Ubicación ---

  Future<void> _setupLocationServiceImproved() async {
    bool locationPermissionsGranted = false;
    try {
      // Permisos de Ubicación
      var locationStatus = await Permission.locationWhenInUse.request();
      if (locationStatus.isGranted) {
        var locationAlwaysStatus = await Permission.locationAlways.request();
        if (locationAlwaysStatus.isGranted) {
          locationPermissionsGranted = true;
        } else {
          print(
            "Permiso locationAlways denegado. Funcionalidad en segundo plano puede ser limitada.",
          );
          // Aún podemos funcionar con locationWhenInUse, pero el BG puede fallar
          locationPermissionsGranted =
              true; // Considerarlo suficiente para iniciar
        }
      }

      if (!locationPermissionsGranted) {
        print('Permisos de ubicación no concedidos.');
        // Mostrar mensaje al usuario
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se requieren permisos de ubicación para funcionar.'),
            backgroundColor: Colors.orange,
          ),
        );
        return; // Salir si no hay permisos
      }

      // Permiso de Notificaciones (ya se pide en _checkNotificationPermission)
      // await Permission.notification.request();

      // Servicio de ubicación
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          print('Servicio de ubicación deshabilitado.');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor, active el servicio de ubicación.'),
              backgroundColor: Colors.orange,
            ),
          );
          return; // Salir si el servicio no está activo
        }
      }

      // Configuración
      await _location.changeSettings(
        accuracy: location_pkg.LocationAccuracy.high,
        interval: LOCATION_UPDATE_INTERVAL,
        distanceFilter: LOCATION_UPDATE_DISTANCE_FILTER,
      );

      // Habilitar modo background (importante para iOS y algunos Android)
      try {
        await _location.enableBackgroundMode(enable: true);
      } catch (e) {
        print(
          "Error habilitando modo background de ubicación (puede ser normal en algunas plataformas): $e",
        );
      }

      // Obtener ubicación inicial
      await _updateCurrentLocation(centerMap: true); // Obtener y centrar

      // Configurar escucha de ubicación (si no está ya escuchando)
      _startLocationUpdates(); // Usar la nueva función
    } catch (e) {
      print('Error configurando servicio de ubicación: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al configurar la ubicación.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateCurrentLocation({bool centerMap = false}) async {
    try {
      final locationData = await _location.getLocation().timeout(
        const Duration(seconds: 15),
      );
      if (mounted) {
        setState(() {
          _userLocation = locationData;
          if (_isFirstLocationUpdate) {
            _initialCameraPosition = CameraPosition(
              target: LatLng(locationData.latitude!, locationData.longitude!),
              zoom: 15, // O el zoom que prefieras
            );
            _isFirstLocationUpdate = false;
          }
        });
        if (centerMap) {
          await _centerMapOnCurrentLocation();
        }
        // Actualizar ubicación en backend si está en servicio
        if (_isOnDuty) {
          _updateDriverLocationBackend();
        }
      }
    } catch (e) {
      print('Error obteniendo ubicación actual: $e');
      // Considerar mostrar un mensaje si falla repetidamente
    }
  }

  void _onLocationChanged(location_pkg.LocationData locationData) {
    if (!mounted) return;
    setState(() {
      _userLocation = locationData;
    });

    // Actualizar backend si está en servicio
    if (_isOnDuty) {
      _updateDriverLocationBackend();
    }

    // Si hay un viaje activo, actualizar la ruta visible
    if (_tripProvider.activeTrip != null &&
        _tripProvider.visibleRoute.isNotEmpty) {
      final currentLocation = LatLng(
        locationData.latitude!,
        locationData.longitude!,
      );
      _updateVisibleRoute(currentLocation);
    }
  }

  // Añadir este nuevo método para actualizar la ruta visible
  void _updateVisibleRoute(LatLng currentLocation) {
    final route = _tripProvider.visibleRoute;
    if (route.isEmpty) return;

    // Encontrar el punto más cercano en la ruta
    int closestPointIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < route.length; i++) {
      final distance = _calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        route[i].latitude,
        route[i].longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestPointIndex = i;
      }
    }

    // Mantener solo los puntos desde la ubicación actual hasta el final
    if (closestPointIndex < route.length) {
      final updatedRoute = route.sublist(closestPointIndex);
      _tripProvider.updateVisibleRoute(updatedRoute);
    }
  }

  // Actualizar ubicación en el backend (sin esperar resultado necesariamente)
  void _updateDriverLocationBackend() {
    if (_userLocation == null || !_isOnDuty || _authProvider.user == null)
      return;
    print('${_userLocation}ubicacion');
    driverService
        .updateLocation(
          _authProvider.user!.id,
          _userLocation!.latitude!,
          _userLocation!.longitude!,
        )
        .catchError((e) {
          // Loggear error, pero no bloquear la UI
          print('Error actualizando ubicación en backend (ignorado): $e');
        });
  }

  // --- Estado de Servicio (On/Off Duty) ---

  Future<void> _toggleDutyStatus(
    bool value, {
    bool updateBackend = true,
  }) async {
    // Verificar permiso de notificación si se intenta poner en servicio
    if (value && !_notificationsEnabled) {
      await _checkNotificationPermission();
      if (!_notificationsEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Habilita las notificaciones para ponerte en servicio.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        // No cambiar el estado si el permiso es necesario y no se concedió
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (updateBackend) {
        if (_authProvider.user == null)
          throw Exception("Usuario no autenticado");
        await driverService.updateDutyStatus(_authProvider.user!.id, value);
      }

      // Actualizar estado local y persistencia
      _isOnDuty = value;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PREFS_IS_ON_DUTY, value);

      // Actualizar suscripciones y UI
      if (mounted) {
        setState(() {
          _isLoading = false; // Ocultar carga
        });
        if (value) {
          _subscribeToDriverRequests(); // Suscribirse al ponerse en servicio
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ahora estás en servicio'),
              backgroundColor: Colors.green,
            ),
          );
          // Intentar iniciar el servicio BG si la app está en pausa/oculta
          final lifecycleState = WidgetsBinding.instance.lifecycleState;
          if ((lifecycleState == AppLifecycleState.paused ||
                  lifecycleState == AppLifecycleState.hidden) &&
              _notificationsEnabled) {
            _backgroundService ??= FlutterBackgroundService();
            if (!await _backgroundService!.isRunning()) {
              print(
                "Iniciando servicio BG inmediatamente después de activar 'En Servicio' (App no en Resumed)",
              );
              _backgroundService!.startService();
            }
          }
        } else {
          _unsubscribeFromRequests(); // Desuscribirse al salir de servicio
          _tripProvider.clearPendingRequests();
          _rejectedRequests.clear();
          await _saveRejectedRequests();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ya no estás en servicio'),
              backgroundColor: Colors.orange,
            ),
          );
          // Detener el servicio BG si está corriendo
          _backgroundService ??= FlutterBackgroundService();
          if (await _backgroundService!.isRunning()) {
            print(
              "Deteniendo servicio BG inmediatamente después de desactivar 'En Servicio'",
            );
            _backgroundService!.invoke('stopService');
          }
        }
      }
    } catch (e) {
      print('Error cambiando estado de servicio: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar estado: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        if (updateBackend) {
          setState(() {
            _isOnDuty = !value; // Revertir visualmente
          });
        }
      }
    }
  }

  // --- Suscripciones Realtime ---

  void _initializeSubscriptions() {
    // Si hay un viaje activo, suscribirse a sus actualizaciones
    if (_tripProvider.activeTrip != null) {
      _subscribeToTripUpdates(_tripProvider.activeTrip!.id);
    }
    // Si está en servicio y NO hay viaje activo, suscribirse a nuevas solicitudes
    else if (_isOnDuty) {
      _subscribeToDriverRequests();
    }
  }

  void _subscribeToRequests() {
    final userId = _authProvider.user?.id;
    final vehiculoType = _authProvider.user?.driverProfile?.vehicleType;
    if (userId == null || !_isOnDuty || _tripProvider.activeTrip != null) {
      print(
        "No se suscribe a requests: userId=$userId, isOnDuty=$_isOnDuty, activeTrip=${_tripProvider.activeTrip != null}",
      );
      return; // No suscribir si no está en servicio, no hay user ID, o ya tiene viaje
    }

    _unsubscribeFromRequests(); // Asegurar que no haya suscripciones previas

    print('Suscribiéndose a solicitudes de viaje para conductor: $userId');
    try {
      _requestSubscription = tripRequestService.subscribeToDriverRequests(
        userId,
        vehiculoType,
        (TripRequest request) {
          // Ejecutar en el contexto correcto
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              print(
                'Solicitud recibida por suscripción directa (TripRequest).',
              );
              // Pasar el objeto TripRequest directamente
              _processIncomingRequest(request);
            }
          });
        },
        (error) {
          print('Error en suscripción de solicitudes: $error');
          // Considerar reintento o notificación
        },
      );
    } catch (e) {
      print("Error al iniciar suscripción a requests: $e");
    }
  }

  void _subscribeToDriverRequests() {
    final userId = _authProvider.user?.id;
    final vehiculoType = _authProvider.user?.driverProfile?.vehicleType;
    if (userId == null || !_isOnDuty || _tripProvider.activeTrip != null) {
      print(
        "No se suscribe a requests: userId=$userId, isOnDuty=$_isOnDuty, activeTrip=${_tripProvider.activeTrip != null}",
      );
      return; // No suscribir si no está en servicio, no hay user ID, o ya tiene viaje
    }

    _unsubscribeFromRequests(); // Asegurar que no haya suscripciones previas

    print('Suscribiéndose a solicitudes de viaje para conductor: $userId');
    try {
      _requestSubscription = tripRequestService.subscribeToDriverRequests(
        userId,
        vehiculoType,
        (TripRequest request) {
          // Ejecutar en el contexto correcto
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              print(
                'Solicitud recibida por suscripción directa (TripRequest).',
              );
              // Pasar el objeto TripRequest directamente
              _processIncomingRequest(request);
            }
          });
        },
        (error) {
          print('Error en suscripción de solicitudes: $error');
          // Considerar reintento o notificación
        },
      );
    } catch (e) {
      print("Error al iniciar suscripción a requests: $e");
    }
  }

  void _unsubscribeFromRequests() {
    if (_requestSubscription != null) {
      print("Desuscribiendo de solicitudes...");
      try {
        tripRequestService.unsubscribeFromDriverRequests(_requestSubscription!);
      } catch (e) {
        print("Error al desuscribir de requests: $e");
      }
      _requestSubscription = null;
    }
  }

  void _subscribeToTripUpdates(String tripId) {
    _unsubscribeFromTripUpdates(); // Limpiar suscripción anterior si existe

    print('Suscribiéndose a actualizaciones del viaje: $tripId');
    try {
      _tripSubscription = tripRequestService.subscribeToTripUpdates(tripId, (
        payload,
      ) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            print('Actualización de viaje recibida: $payload');
            _handleTripUpdate(payload);
          }
        });
      }, (error) => print('Error en suscripción de viaje: $error'));
    } catch (e) {
      print("Error al iniciar suscripción a trip updates: $e");
    }
  }

  void _unsubscribeFromTripUpdates() {
    if (_tripSubscription != null) {
      print("Desuscribiendo de actualizaciones de viaje...");
      try {
        tripRequestService.unsubscribeFromTripUpdates(_tripSubscription!);
      } catch (e) {
        print("Error al desuscribir de trip updates: $e");
      }
      _tripSubscription = null;
    }
  }

  // --- Procesamiento de Solicitudes y Viajes ---

  // Procesa una solicitud entrante (desde suscripción directa o background service)
  Future<void> _processIncomingRequest(dynamic incomingData) async {
    // Asegurarse que el widget esté montado y que el conductor esté en servicio
    // y no tenga un viaje activo.
    // print(incomingData); // Puedes mantener o quitar este print
    if (!mounted || !_isOnDuty || _tripProvider.activeTrip != null) {
      print(
        "Ignorando request entrante (UI): mounted=$mounted, isOnDuty=$_isOnDuty, activeTrip=${_tripProvider.activeTrip != null}",
      );
      return;
    }

    TripRequest?
    request; // Variable para guardar la solicitud parseada/recibida

    try {
      // Verificar el tipo de dato recibido
      if (incomingData is TripRequest) {
        // Ya es un objeto TripRequest (viene de la suscripción directa de la UI)
        request = incomingData;
        print('Procesando TripRequest recibido directamente: ${request.id}');
      } else if (incomingData is Map) {
        // Podría ser un Map directamente o un Map que contiene JSON string del BG service
        Map<String, dynamic> requestDataMap;
        if (incomingData.containsKey('request') &&
            incomingData['request'] is String) {
          // Es el Map del BG service, decodificar el JSON string
          requestDataMap = jsonDecode(incomingData['request']);
          print('Procesando Map decodificado del BG Service...');
        } else if (incomingData.keys.isNotEmpty) {
          // Asumir que es un Map directo con los datos (menos probable ahora)
          requestDataMap = Map<String, dynamic>.from(incomingData);
          print('Procesando Map recibido directamente...');
        } else {
          print('Error: _processIncomingRequest recibió un Map vacío.');
          return;
        }
        // Parsear el Map a TripRequest
        request = TripRequest.fromJson(requestDataMap);
        print('TripRequest parseado desde Map: ${request.id}');
      } else {
        // Tipo de dato inesperado
        print(
          'Error: _processIncomingRequest recibió datos inesperados: ${incomingData.runtimeType}',
        );
        return;
      }

      // --- Ahora 'request' contiene el objeto TripRequest ---

      // Validaciones adicionales usando el objeto 'request'
      if (request == null || // Chequeo extra por si acaso
          request.status != TRIP_STATUS_BROADCASTING ||
          _tripProvider.hasPendingRequest(request.id) ||
          _rejectedRequests.contains(request.id)) {
        print(
          'Solicitud (UI) ignorada: ${request?.id} (status: ${request?.status}, ya existe o rechazada)',
        );
        _tripProvider.setLoading(
          false,
        ); // Asegúrate de quitar el loading si se ignora
        return;
      }

      print('Procesando nueva solicitud válida (UI): ${request.id}');

      // Mostrar indicador de carga en la UI
      _tripProvider.setLoading(
        true,
      ); // Mover esto aquí, después de validaciones

      // Calcular ruta (esto podría hacerse opcionalmente aquí o mostrar la solicitud inmediatamente)
      final route = await _calculateRoute(
        LatLng(request.originLat, request.originLng),
        LatLng(request.destinationLat, request.destinationLng),
        request.trip_stops ?? [],
      );

      print(
        '[DriverHome] Ruta calculada para solicitud ${request.id}. Polyline tiene ${route['polyline']?.length ?? 0} puntos.',
      );

      // Añadir la solicitud pendiente al provider
      _tripProvider.setNewPendingRequest(request, route);

      // Reproducir sonido de notificación
      await _playNotificationSound();

      // Actualizar cámara del mapa
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateMapCamera();
        }
      });
    } catch (e, s) {
      print('Error en _processIncomingRequest: $e\n$s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar solicitud: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      _tripProvider.setLoading(
        false,
      ); // Asegúrate de quitar el loading en caso de error
      _tripProvider.clearPendingRequests(); // Limpiar si hubo error procesando
    } finally {
      // Quitar indicador de carga si aún está activo (aunque ya se maneja en los return/catch)
      if (_tripProvider.isLoading) {
        _tripProvider.setLoading(false);
      }
    }
  }

  // Maneja la respuesta del conductor (Aceptar/Rechazar)
  Future<void> _handleRequestResponse(
    String requestId,
    String responseStatus,
  ) async {
    await _stopNotificationSound(); // Detener sonido al interactuar

    final currentRequest = _tripProvider.getPendingRequestById(requestId);
    if (currentRequest == null) {
      print(
        "Error: Intento de responder a request $requestId que ya no está pendiente.",
      );
      return;
    }

    if (responseStatus == TRIP_STATUS_REJECTED) {
      print("Rechazando solicitud: $requestId");
      _rejectedRequests.add(requestId);
      await _saveRejectedRequests();
      _tripProvider.clearPendingRequests(); // Limpiar la solicitud del provider
      // El UI se actualizará automáticamente
      return;
    }

    if (responseStatus == TRIP_STATUS_ACCEPTED) {
      print("Intentando aceptar solicitud: $requestId");
      _tripProvider.setLoading(true);

      try {
        final userId = _authProvider.user?.id;
        if (userId == null) throw Exception("Usuario no autenticado");

        // 1. Intento Atómico de Aceptar
        final success = await tripRequestService.attemptAcceptRequest(
          requestId,
          userId,
        );

        if (!success) {
          print("Fallo al aceptar: Solicitud $requestId ya no disponible.");
          _tripProvider.clearPendingRequests(); // Limpiar si falló
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Esta solicitud ya no está disponible'),
              backgroundColor: Colors.orange,
            ),
          );
          return; // Salir
        }

        // 2. Confirmar y Crear Viaje (si attemptAcceptRequest fue exitoso)
        // Nota: Asumimos que attemptAcceptRequest ya actualizó el estado en backend
        // y podemos proceder a crear el viaje localmente y suscribirnos.

        // Crear objeto Trip localmente basado en la solicitud aceptada
        final activeTrip = Trip(
          id: requestId, // Usar el ID de la solicitud como ID del viaje (o obtenerlo si es diferente)
          origin: currentRequest.origin,
          destination: currentRequest.destination,
          originLat: currentRequest.originLat,
          originLng: currentRequest.originLng,
          destinationLat: currentRequest.destinationLat,
          destinationLng: currentRequest.destinationLng,
          price: currentRequest.price,
          status: TRIP_STATUS_IN_PROGRESS, // Estado inicial del viaje activo
          createdBy: currentRequest.createdBy,
          createdAt: DateTime.now().toIso8601String(), // Usar hora actual
          trip_stops: currentRequest.trip_stops ?? [],
          passengerPhone: currentRequest.passengerPhone,
          // Añadir driverId si el modelo Trip lo requiere
        );

        // 3. Actualizar estado en el provider y localmente
        // Usar el método renombrado startActiveTrip
        _tripProvider.startActiveTrip(activeTrip, TRIP_PHASE_TO_PICKUP);

        // 4. Calcular y mostrar la ruta hacia el punto de recogida
        if (_userLocation != null) {
          final routeToPickup = await _calculateRoute(
            LatLng(_userLocation!.latitude!, _userLocation!.longitude!),
            LatLng(activeTrip.originLat, activeTrip.originLng),
            [], // Sin paradas intermedias para ir a recoger
          );
          _tripProvider.setCurrentRoute(
            routeToPickup,
          ); // Actualizar ruta en provider
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Viaje aceptado'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e, s) {
        print('Error aceptando/confirmando solicitud $requestId: $e\n$s');
        _tripProvider.clearPendingRequests(); // Limpiar en caso de error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aceptar el viaje: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        _tripProvider.setLoading(false); // Asegurar desactivación del loader
      }
    }
  }

  // Maneja la llegada al punto de recogida o a una parada
  Future<void> _handleArrival() async {
    final activeTrip = _tripProvider.activeTrip;
    final currentPhase = _tripProvider.tripPhase;
    final currentStopIndex = _tripProvider.currentStopIndex;

    if (activeTrip == null || _userLocation == null) {
      print("Error: No se puede manejar llegada sin viaje activo o ubicación.");
      return;
    }

    _tripProvider.setLoading(true);

    try {
      String nextPhase = currentPhase;
      int nextStopIndex = currentStopIndex;
      LatLng? nextDestinationPoint;
      String snackbarMessage = "";

      if (currentPhase == TRIP_PHASE_TO_PICKUP) {
        print("Llegada al punto de recogida.");
        await tripRequestService.updateTripStatus(
          activeTrip.id,
          TRIP_STATUS_PICKUP_REACHED,
        );

        // Determinar siguiente destino: primera parada o destino final
        if (activeTrip.trip_stops != null &&
            activeTrip.trip_stops!.isNotEmpty) {
          nextPhase = TRIP_PHASE_TO_STOPS;
          nextStopIndex = 0;
          final firstStop = activeTrip.trip_stops![nextStopIndex];
          nextDestinationPoint = LatLng(
            firstStop.latitude,
            firstStop.longitude,
          );
          snackbarMessage = 'Dirígete a la parada 1: ${firstStop.name}';
        } else {
          nextPhase = TRIP_PHASE_TO_DESTINATION;
          nextDestinationPoint = LatLng(
            activeTrip.destinationLat,
            activeTrip.destinationLng,
          );
          snackbarMessage = 'Dirígete al destino final';
        }
      } else if (currentPhase == TRIP_PHASE_TO_STOPS) {
        final currentStop = activeTrip.trip_stops![currentStopIndex];
        print(
          "Llegada a la parada ${currentStopIndex + 1}: ${currentStop.name}",
        );
        // Aquí podrías llamar a una función API si necesitas registrar la llegada a la parada
        // await tripRequestService.updateTripStopStatus(activeTrip.id, currentStop.id, 'reached');

        // Determinar siguiente destino: siguiente parada o destino final
        if (currentStopIndex < activeTrip.trip_stops!.length - 1) {
          // Ir a la siguiente parada
          nextStopIndex = currentStopIndex + 1;
          final nextStop = activeTrip.trip_stops![nextStopIndex];
          nextDestinationPoint = LatLng(nextStop.latitude, nextStop.longitude);
          snackbarMessage =
              'Dirígete a la parada ${nextStopIndex + 1}: ${nextStop.name}';
          // nextPhase sigue siendo TRIP_PHASE_TO_STOPS
        } else {
          // Ir al destino final después de la última parada
          nextPhase = TRIP_PHASE_TO_DESTINATION;
          nextDestinationPoint = LatLng(
            activeTrip.destinationLat,
            activeTrip.destinationLng,
          );
          snackbarMessage = 'Dirígete al destino final';
        }
      } else {
        print(
          "Error: _handleArrival llamado en fase inesperada: $currentPhase",
        );
        _tripProvider.setLoading(false);
        return;
      }

      // Calcular nueva ruta si hay un siguiente destino
      Map<String, dynamic>? newRoute;
      if (nextDestinationPoint != null) {
        newRoute = await _calculateRoute(
          LatLng(
            _userLocation!.latitude!,
            _userLocation!.longitude!,
          ), // Desde la ubicación actual
          nextDestinationPoint,
          [], // Sin paradas intermedias en este segmento
        );
      }

      // Actualizar el estado en el provider
      _tripProvider.updateTripPhaseAndRoute(nextPhase, nextStopIndex, newRoute);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(snackbarMessage), backgroundColor: Colors.blue),
      );
    } catch (e, s) {
      print("Error manejando llegada: $e\n$s");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al actualizar estado del viaje'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _tripProvider.setLoading(false);
    }
  }

  // Maneja la finalización del viaje (llegada al destino final)
  Future<void> _handleTripCompletion() async {
    final activeTrip = _tripProvider.activeTrip;
    if (activeTrip == null || _userLocation == null) return;

    _tripProvider.setLoading(true);

    try {
      // 1. Verificar cercanía al destino (opcional pero recomendado)
      final isNear = _isWithinAllowedDistance(
        _userLocation!.latitude!,
        _userLocation!.longitude!,
        activeTrip.destinationLat,
        activeTrip.destinationLng,
        maxDistance: 150, // Aumentar tolerancia si es necesario
      );
      if (!isNear) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes estar más cerca del destino para finalizar.'),
            backgroundColor: Colors.orange,
          ),
        );
        _tripProvider.setLoading(false);
        return;
      }

      // 2. Actualizar estado en backend
      await tripRequestService.updateTripStatus(
        activeTrip.id,
        TRIP_STATUS_COMPLETED,
      );

      // 3. Calcular y aplicar comisión (si aplica)
      // Esta lógica podría estar mejor en el backend al recibir 'completed'
      final commission = activeTrip.price * 0.2; // Ejemplo de comisión
      final userId = _authProvider.user!.id;
      // await driverService.applyCommission(userId, activeTrip.id, commission); // Llamada a API hipotética

      // 4. Limpiar estado del viaje en el provider
      final completedTripPrice =
          activeTrip.price; // Guardar precio para el diálogo
      _tripProvider.clearTrip();

      // 5. Limpiar suscripción de viaje y reanudar escucha de solicitudes si está en servicio
      _unsubscribeFromTripUpdates();
      if (_isOnDuty) {
        _subscribeToDriverRequests();
      }

      // 6. Mostrar diálogo de éxito
      // Verificar balance DESPUÉS de limpiar el viaje localmente
      // La verificación de suspensión debería ocurrir en el backend o al intentar ponerse en servicio
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Viaje Completado'),
              content: Text(
                'Viaje completado exitosamente.\n'
                'Monto cobrado: \$${completedTripPrice.toStringAsFixed(2)}\n'
                'Comisión aplicada: \$${commission.toStringAsFixed(2)} (ejemplo)', // Aclarar que es ejemplo si no se confirma
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendido'),
                ),
              ],
            ),
      );

      // 7. Opcional: Verificar si el balance es negativo y mostrar advertencia
      // await _checkBalanceAndWarn();
    } catch (e, s) {
      print("Error completando viaje: $e\n$s");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al finalizar el viaje.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _tripProvider.setLoading(false);
    }
  }

  // Maneja la cancelación del viaje por parte del conductor
  Future<void> _handleTripCancellation() async {
    final activeTrip = _tripProvider.activeTrip;
    if (activeTrip == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cancelar Viaje'),
            content: const Text(
              '¿Estás seguro de que deseas cancelar este viaje?',
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

    if (confirm == true) {
      _tripProvider.setLoading(true);
      try {
        final userId = _authProvider.user?.id;
        if (userId == null) throw Exception("Usuario no autenticado");

        await tripRequestService.cancelTrip(
          activeTrip.id,
          'Cancelado por el conductor',
          userId,
        );

        // Limpiar estado local y suscripciones
        _tripProvider.clearTrip();
        _unsubscribeFromTripUpdates();
        if (_isOnDuty) {
          _subscribeToDriverRequests(); // Volver a escuchar si está en servicio
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Viaje cancelado'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e, s) {
        print("Error cancelando viaje: $e\n$s");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cancelar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        _tripProvider.setLoading(false);
      }
    }
  }

  // Maneja actualizaciones recibidas por la suscripción del viaje activo
  void _handleTripUpdate(Map<String, dynamic> tripData) {
    final activeTrip = _tripProvider.activeTrip;
    if (activeTrip == null || tripData['id'] != activeTrip.id) {
      print(
        "Actualización de viaje recibida para un viaje no activo o diferente. Ignorando.",
      );
      return; // Ignorar si no es para el viaje actual
    }

    final updatedStatus = tripData['status'] as String?;

    if (updatedStatus == TRIP_STATUS_CANCELLED) {
      print(
        "Viaje ${activeTrip.id} cancelado por otra parte (pasajero/admin).",
      );
      _stopAlerts(); // Detener sonidos/notificaciones si las hubiera

      // Limpiar estado local
      _tripProvider.clearTrip();
      _unsubscribeFromTripUpdates();
      if (_isOnDuty) {
        _subscribeToDriverRequests(); // Volver a escuchar si está en servicio
      }

      // Mostrar diálogo informativo
      showDialog(
        context: context,
        barrierDismissible: false, // No cerrar tocando fuera
        builder:
            (context) => AlertDialog(
              title: const Text('Viaje Cancelado'),
              content: const Text(
                'El viaje ha sido cancelado por el pasajero o administrador.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    }
    // Aquí podrías manejar otras actualizaciones de estado si fueran relevantes
    // Por ejemplo, si el pasajero añade una parada a mitad del viaje.
    // else if (tripData['trip_stops'] != null) {
    //    final updatedStops = (tripData['trip_stops'] as List).map((s) => TripStop.fromJson(s)).toList();
    //    _tripProvider.updateTripStops(updatedStops);
    //    // Recalcular ruta si es necesario
    // }
  }

  // --- Cálculo de Ruta ---

  Future<Map<String, dynamic>> _calculateRoute(
    LatLng start,
    LatLng end,
    List<TripStop> stops,
  ) async {
    try {
      // Usar compute para mover el cálculo a un isolate
      // Asegurarse que LatLng y TripStop sean serializables o pasar datos primitivos
      final startList = [start.latitude, start.longitude];
      final endList = [end.latitude, end.longitude];
      final stopsList =
          stops.map((s) => s.toJson()).toList(); // Usar toJson si existe

      return await compute(_calculateRouteIsolate, {
        'start': startList,
        'end': endList,
        'stops': stopsList,
      });
    } catch (e) {
      print('Error calculando ruta: $e');
      // Devolver ruta vacía o con error
      return {'distance': 'Error', 'duration': 'Error', 'polyline': <LatLng>[]};
    }
  }

  // Función para ejecutar en un isolate (mejorada)
  static Future<Map<String, dynamic>> _calculateRouteIsolate(
    Map<String, dynamic> params,
  ) async {
    try {
      final startCoords = params['start'] as List<double>;
      final endCoords = params['end'] as List<double>;
      // Reconstruir TripStop desde JSON
      final stops =
          (params['stops'] as List)
              .map((s) => TripStop.fromJson(s as Map<String, dynamic>))
              .toList();

      final start = LatLng(startCoords[0], startCoords[1]);
      final end = LatLng(endCoords[0], endCoords[1]);

      // Ordenar paradas por order_index (asegurarse que orderIndex no sea null)
      stops.sort((a, b) => (a.orderIndex ?? 0).compareTo(b.orderIndex ?? 0));

      // Crear waypoints para OSRM: start -> stops -> end
      final waypoints = [
        start,
        ...stops.map((stop) => LatLng(stop.latitude, stop.longitude)),
        end,
      ];

      // Construir URL para OSRM (un solo request con waypoints)
      final coordinatesString = waypoints
          .map((p) => '${p.longitude},${p.latitude}')
          .join(';');
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coordinatesString'
        '?overview=full&geometries=geojson&steps=false', // steps=false para respuesta más ligera si no se usan
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception('Error OSRM: ${response.statusCode} ${response.body}');
      }

      final data = jsonDecode(response.body);

      if (data['code'] != 'Ok' ||
          data['routes'] == null ||
          data['routes'].isEmpty) {
        throw Exception(
          'Error OSRM: No se encontró ruta. ${data['message'] ?? ''}',
        );
      }

      final route = data['routes'][0];
      final geometry = route['geometry']['coordinates'] as List;
      final polyline =
          geometry
              .map(
                (coord) => LatLng(coord[1] as double, coord[0] as double),
              ) // OSRM devuelve [lon, lat]
              .toList();

      final distance = (route['distance'] / 1000.0); // Distancia en km
      final duration = (route['duration'] / 60.0); // Duración en minutos

      print(
        '[_calculateRouteIsolate] Ruta calculada exitosamente. Puntos: ${polyline.length}',
      ); // LOG AÑADIDO

      return {
        'distance': '${distance.toStringAsFixed(1)} km',
        'duration': '${duration.round()} min',
        'polyline': polyline, // Devolver lista de LatLng directamente
      };
    } catch (e) {
      print('Error en _calculateRouteIsolate: $e');
      // Devolver ruta vacía o con error claro
      return {'distance': 'N/A', 'duration': 'N/A', 'polyline': <LatLng>[]};
    }
  }

  // --- Mapa ---

  // Método para centrar el mapa en la ubicación actual
  Future<void> _centerMapOnCurrentLocation() async {
    if (_userLocation == null || !_mapController.isCompleted) {
      print(
        'No se puede centrar el mapa: falta ubicación del usuario o controlador del mapa.',
      );
      return;
    }

    try {
      final controller = await _mapController.future;
      final position = LatLng(
        _userLocation!.latitude!,
        _userLocation!.longitude!,
      );
      controller.animateCamera(CameraUpdate.newLatLngZoom(position, 15.0));
      print('Mapa centrado en: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('Error centrando el mapa: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    if (!_mapController.isCompleted) {
      _mapController.complete(controller);
      print('Mapa creado y controlador completado.');
      // Intentar centrar/ajustar una vez que el mapa esté listo
      // Usar postFrameCallback para asegurar que el build inicial haya terminado
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateMapCamera();
        }
      });
    } else {
      print('Advertencia: _onMapCreated llamado de nuevo.');
    }
  }

  // Decide si centrar en usuario, ajustar a ruta o usar posición inicial
  Future<void> _updateMapCamera() async {
    if (!_mapController.isCompleted) {
      print(
        "[DriverHome] _updateMapCamera: Intentando actualizar cámara antes de que el mapa esté listo.",
      );
      return;
    }
    final controller = await _mapController.future;
    final visibleRoute =
        _tripProvider.visibleRoute; // Obtener ruta del provider
    print(
      '[DriverHome] _updateMapCamera: visibleRoute tiene ${visibleRoute.length} puntos.',
    ); // LOG AÑADIDO

    if (visibleRoute.isNotEmpty) {
      _fitMapToRoute(controller, visibleRoute);
    } else if (_userLocation != null) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_userLocation!.latitude!, _userLocation!.longitude!),
          15.0, // Zoom deseado
        ),
      );
    } else {
      // Usar la posición inicial si no hay ruta ni ubicación
      controller.animateCamera(
        CameraUpdate.newCameraPosition(_initialCameraPosition),
      );
    }
  }

  void _fitMapToRoute(
    GoogleMapController controller,
    List<LatLng> routePoints,
  ) {
    if (routePoints.length < 2) {
      // Si hay solo un punto (o ninguno), centrar en ese punto o en la ubicación del usuario
      if (routePoints.isNotEmpty) {
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(routePoints.first, 15.0),
        );
      } else if (_userLocation != null) {
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(_userLocation!.latitude!, _userLocation!.longitude!),
            15.0,
          ),
        );
      }
      return;
    }

    try {
      // Calcular bounds
      double minLat = routePoints.first.latitude;
      double maxLat = routePoints.first.latitude;
      double minLng = routePoints.first.longitude;
      double maxLng = routePoints.first.longitude;

      for (final point in routePoints) {
        minLat = min(minLat, point.latitude);
        maxLat = max(maxLat, point.latitude);
        minLng = min(minLng, point.longitude);
        maxLng = max(maxLng, point.longitude);
      }

      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 60.0),
      ); // Padding
      print('Mapa ajustado a la ruta.');
    } catch (e) {
      print('Error ajustando el mapa a la ruta: $e');
      // Fallback: centrar en el primer punto
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(routePoints.first, 15.0),
      );
    }
  }

  // Construye los marcadores basado en el estado del TripProvider
  Set<Marker> _buildMarkers(TripProvider tripProvider) {
    final Set<Marker> markers = {};
    final activeTrip = tripProvider.activeTrip;
    final pendingRequest =
        tripProvider.pendingRequests.isNotEmpty
            ? tripProvider.pendingRequests.first
            : null;

    // --- Lógica Común para Origen y Destino ---
    LatLng? originPosition;
    String originTitle = 'Origen';
    BitmapDescriptor originIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueGreen,
    ); // Verde para origen

    LatLng? destinationPosition;
    String destinationTitle = 'Destino';
    BitmapDescriptor destinationIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueRed,
    ); // Rojo para destino

    List<TripStop> stops = [];

    if (activeTrip != null) {
      // Marcadores para Viaje Activo
      originPosition = LatLng(activeTrip.originLat, activeTrip.originLng);
      destinationPosition = LatLng(
        activeTrip.destinationLat,
        activeTrip.destinationLng,
      );
      stops = activeTrip.trip_stops ?? [];

      // Podrías cambiar el título o icono según la fase si quieres
      // if (tripProvider.tripPhase == TRIP_PHASE_TO_PICKUP) { ... }
    } else if (pendingRequest != null) {
      // Marcadores para Solicitud Pendiente
      originPosition = LatLng(
        pendingRequest.originLat,
        pendingRequest.originLng,
      );
      destinationPosition = LatLng(
        pendingRequest.destinationLat,
        pendingRequest.destinationLng,
      );
      stops = pendingRequest.trip_stops ?? [];
      originTitle = 'Origen Solicitud';
      destinationTitle = 'Destino Solicitud';
    }

    // --- Crear Marcadores ---

    // Marcador de Origen
    if (originPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: originPosition,
          icon: originIcon,
          infoWindow: InfoWindow(title: originTitle),
        ),
      );
    }

    // Marcador de Destino
    if (destinationPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: destinationPosition,
          icon: destinationIcon,
          infoWindow: InfoWindow(title: destinationTitle),
        ),
      );
    }

    // Marcadores de Paradas (para viaje activo o solicitud pendiente)
    if (stops.isNotEmpty) {
      for (int i = 0; i < stops.length; i++) {
        final stop = stops[i];
        markers.add(
          Marker(
            markerId: MarkerId('stop_$i'),
            position: LatLng(stop.latitude, stop.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange, // Naranja para paradas
            ),
            infoWindow: InfoWindow(
              title: 'Parada ${i + 1}',
              snippet: stop.name, // Usar el nombre de la parada si existe
            ),
          ),
        );
      }
    }
    return markers;
  }

  // Construye las polilíneas basado en el estado del TripProvider
  Set<Polyline> _buildPolylines(TripProvider tripProvider) {
    final Set<Polyline> polylines = {};
    final visibleRoute = tripProvider.visibleRoute;
    print(
      '[DriverHome] _buildPolylines: visibleRoute tiene ${visibleRoute.length} puntos.',
    ); // LOG AÑADIDO

    if (visibleRoute.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('current_route'),
          points: visibleRoute,
          color: Colors.red,
          width: 6,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }
    return polylines;
  }

  // --- Estado Persistente (SharedPreferences) ---

  Future<void> _saveCurrentState() async {
    try {
      print("Guardando estado actual...");
      final prefs = await SharedPreferences.getInstance();
      final userId = _authProvider.user?.id;
      final activeTrip = _tripProvider.activeTrip; // Obtener del provider

      if (userId != null) {
        await prefs.setString(PREFS_USER_ID, userId);
      }
      await prefs.setBool(
        PREFS_IS_ON_DUTY,
        _isOnDuty,
      ); // Guardar estado local del switch

      if (activeTrip != null) {
        await prefs.setString(
          PREFS_ACTIVE_TRIP,
          jsonEncode(activeTrip.toJson()),
        );
        await prefs.setString(PREFS_TRIP_PHASE, _tripProvider.tripPhase);
        await prefs.setInt(
          'current_stop_index',
          _tripProvider.currentStopIndex,
        ); // Guardar índice de parada
        await prefs.setBool(PREFS_HAS_ACTIVE_TRIP, true); // Para el servicio BG
      } else {
        await prefs.remove(PREFS_ACTIVE_TRIP);
        await prefs.remove(PREFS_TRIP_PHASE);
        await prefs.remove('current_stop_index');
        await prefs.setBool(
          PREFS_HAS_ACTIVE_TRIP,
          false,
        ); // Para el servicio BG
      }
      // Las solicitudes pendientes ahora se manejan en el provider y su persistencia
      // await _tripProvider.savePendingRequestsToPrefs(); // El provider se encarga
      await _saveRejectedRequests(); // Guardar rechazadas de la sesión
      print("Estado guardado.");
    } catch (e) {
      print('Error guardando estado: $e');
    }
  }

  // Restaura el estado desde SharedPreferences al Provider si es necesario
  Future<void> _restoreStateIfNeeded() async {
    if (_stateRestored) {
      print("Estado ya restaurado, omitiendo.");
      return;
    }
    print("Restaurando estado desde SharedPreferences...");
    _tripProvider.setLoading(true); // Indicar carga durante restauración
    try {
      final prefs = await SharedPreferences.getInstance();

      // Restaurar viaje activo si existe
      final activeTripJson = prefs.getString(PREFS_ACTIVE_TRIP);
      if (activeTripJson != null) {
        final tripData = Trip.fromJson(jsonDecode(activeTripJson));
        final tripPhase = prefs.getString(PREFS_TRIP_PHASE) ?? TRIP_PHASE_NONE;
        final stopIndex = prefs.getInt('current_stop_index') ?? -1;

        // Actualizar el provider (esto NO debería recalcular ruta automáticamente)
        _tripProvider.restoreActiveTrip(tripData, tripPhase, stopIndex);
        print(
          "Viaje activo restaurado: ID ${tripData.id}, Fase: $tripPhase, Parada: $stopIndex",
        );

        // Recalcular la ruta desde la ubicación actual al destino de la fase restaurada
        if (_userLocation != null) {
          LatLng destinationPoint;
          if (tripPhase == TRIP_PHASE_TO_PICKUP) {
            destinationPoint = LatLng(tripData.originLat, tripData.originLng);
          } else if (tripPhase == TRIP_PHASE_TO_STOPS &&
              stopIndex >= 0 &&
              tripData.trip_stops != null &&
              stopIndex < tripData.trip_stops!.length) {
            destinationPoint = LatLng(
              tripData.trip_stops![stopIndex].latitude,
              tripData.trip_stops![stopIndex].longitude,
            );
          } else {
            // toDestination o estado inválido
            destinationPoint = LatLng(
              tripData.destinationLat,
              tripData.destinationLng,
            );
          }
          final restoredRoute = await _calculateRoute(
            LatLng(_userLocation!.latitude!, _userLocation!.longitude!),
            destinationPoint,
            [], // No necesitamos paradas intermedias para este cálculo
          );
          _tripProvider.setCurrentRoute(
            restoredRoute,
          ); // Actualizar ruta en provider
          print("Ruta restaurada calculada.");
        }
      } else {
        print("No hay viaje activo para restaurar.");
        // Asegurarse de que el provider esté limpio si no hay viaje guardado
        _tripProvider.clearTrip(
          notify: false,
        ); // No notificar para evitar rebuild innecesario aún
      }

      // Restaurar solicitudes pendientes (el provider lo hace internamente ahora)
      await _tripProvider.loadPendingRequestsFromPrefs();
      if (_tripProvider.pendingRequests.isNotEmpty &&
          _tripProvider.activeTrip == null) {
        print("Solicitudes pendientes restauradas desde Prefs.");
        // Si hay solicitudes pendientes y no hay viaje activo, calcular ruta para la primera
        if (_userLocation != null && _tripProvider.currentRoute == null) {
          final request = _tripProvider.pendingRequests.first;
          final route = await _calculateRoute(
            LatLng(_userLocation!.latitude!, _userLocation!.longitude!),
            LatLng(request.originLat, request.originLng),
            request.trip_stops ?? [],
          );
          _tripProvider.setCurrentRoute(route); // Actualizar ruta en provider
          print("Ruta para solicitud pendiente restaurada calculada.");
        }
      }

      _stateRestored = true; // Marcar como restaurado
      print("Restauración de estado completada.");
    } catch (e, s) {
      print('Error restaurando estado: $e\n$s');
      // Limpiar estado en caso de error de restauración para evitar inconsistencias
      _tripProvider.clearTrip();
      _tripProvider.clearPendingRequests();
    } finally {
      // Asegurar que el loading se desactive y notificar para reconstruir UI
      _tripProvider.setLoading(false); // Esto notificará a los listeners
    }
  }

  // --- Servicios (Pausar/Reanudar) ---

  void _resumeServices() {
    print("Reanudando servicios UI...");
    _startLocationUpdates(); // Reiniciar escucha de ubicación si se detuvo
    // Volver a suscribirse a Realtime si es necesario
    _initializeSubscriptions(); // Esta función ya contiene la lógica correcta
  }

  void _pauseServices() {
    print("Pausando servicios UI...");
    _locationSubscription?.cancel(); // Detener escucha de ubicación de la UI
    _locationSubscription = null;
    _unsubscribeFromRequests(); // Desuscribirse de Realtime en la UI
    _unsubscribeFromTripUpdates();
  }

  Future<void> _playNotificationSound() async {
    try {
      // Intentar primero desde raw resources (preferido)
      await _audioPlayer.play(
        DeviceFileSource(
          'android.resource://${await _getPackageName()}/raw/notification_sound',
        ),
      );
      print("Reproduciendo sonido de notificación (desde raw).");
    } catch (e) {
      print('Error reproduciendo sonido desde raw: $e');
      // Fallback a assets si falla el raw
      try {
        // Asegúrate que la ruta 'assets/sounds/notification_sound.mp3' es correcta
        // y que está declarada en pubspec.yaml
        await _audioPlayer.play(AssetSource('sounds/notification_sound.mp3'));
        print("Reproduciendo sonido de notificación (desde assets).");
      } catch (e2) {
        print('Error reproduciendo sonido (fallback AssetSource): $e2');
      }
    }
  }

  // Helper para obtener package name
  Future<String> _getPackageName() async {
    // Esta es una forma común, pero puede requerir el paquete 'package_info_plus'
    // import 'package:package_info_plus/package_info_plus.dart';
    // PackageInfo packageInfo = await PackageInfo.fromPlatform();
    // return packageInfo.packageName;
    // --- O hardcodearlo si conoces el package name ---
    return 'com.example.taxi_app'; // <-- ¡¡ASEGÚRATE QUE ESTE SEA TU PACKAGE NAME REAL!! (busca en build.gradle o AndroidManifest.xml)
  }

  Future<void> _stopNotificationSound() async {
    try {
      await _audioPlayer.stop();
      print("Sonido de notificación detenido.");
    } catch (e) {
      print('Error deteniendo sonido: $e');
    }
  }

  Future<void> _showNotification(String title, String body) async {
    // Usar el ID del canal correcto
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          NOTIFICATION_CHANNEL_REQUESTS_ID, // ID del canal para solicitudes
          NOTIFICATION_CHANNEL_REQUESTS_NAME,
          importance: Importance.max, // Max para heads-up
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound(
            'notification_sound',
          ), // Asociar sonido
          playSound: true,
          enableVibration: true,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );
    await _notificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
    ); // ID único
  }

  Future<void> _stopAlerts() async {
    await _stopNotificationSound();
    await _notificationsPlugin.cancelAll(); // Cancelar notificaciones activas
  }

  // --- Acciones de Botones (Llamar/SMS) ---
  Future<void> _launchPhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Número de teléfono no disponible'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw Exception('No se puede lanzar la URL tel:');
      }
    } catch (e) {
      print("Error al intentar llamar: $e");
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
          content: Text('Número de teléfono no disponible'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final Uri uri = Uri(scheme: 'sms', path: phoneNumber);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw Exception('No se puede lanzar la URL sms:');
      }
    } catch (e) {
      print("Error al intentar enviar SMS: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la app de mensajes'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- Helpers Varios ---
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // ... (sin cambios)
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
    print(
      "Distancia al objetivo: ${distance.toStringAsFixed(1)}m (Máx: ${maxDistance}m)",
    );
    return distance <= maxDistance;
  }

  // --- Build Method ---

  @override
  Widget build(BuildContext context) {
    // Escuchar cambios en TripProvider para reconstruir la UI
    return Consumer<TripProvider>(
      builder: (context, tripProvider, child) {
        // Sincronizar estado local del switch si es necesario (raro, pero por si acaso)
        // if (_isOnDuty != tripProvider.driverStatus) {
        //   WidgetsBinding.instance.addPostFrameCallback((_) {
        //      if (mounted) setState(() => _isOnDuty = tripProvider.driverStatus);
        //   });
        // }

        final bool isLoading =
            tripProvider.isLoading || _isLoading; // Combinar loaders
        final Set<Marker> markers = _buildMarkers(tripProvider);
        final Set<Polyline> polylines = _buildPolylines(tripProvider);

        // Actualizar cámara del mapa si la ruta cambió (después del build)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _mapController.isCompleted) {
            _updateMapCamera();
          }
        });

        return Scaffold(
          // appBar: AppBar(title: Text("Modo Conductor")), // Opcional: AppBar
          body: Stack(
            children: [
              // Mapa de Google
              GoogleMap(
                initialCameraPosition: _initialCameraPosition,
                mapType: MapType.normal,
                myLocationEnabled: true, // Habilitar punto azul
                myLocationButtonEnabled:
                    false, // Deshabilitar botón flotante nativo
                zoomControlsEnabled: false,
                markers: markers, // Usar marcadores del provider
                polylines: polylines, // Usar polilíneas del provider
                onMapCreated: _onMapCreated,
                // Opcional: Añadir padding si hay elementos flotantes arriba/abajo
                padding: EdgeInsets.only(
                  bottom: _calculateMapPadding(
                    tripProvider,
                  ), // Usar función helper
                  top: 60,
                ),
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                }, // Para evitar conflictos con DraggableScrollableSheet si se usa
              ),

              // Indicador de carga global
              if (isLoading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),

              // --- Elementos Flotantes ---

              // Botón de Menú (Sidebar)
              Positioned(
                top: 45, // Ajustar según sea necesario (considerar SafeArea)
                left: 15,
                child: FloatingActionButton(
                  heroTag: 'fab_menu', // Tag único
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () => setState(() => _isSidebarVisible = true),
                  child: const Icon(LucideIcons.menu, color: Colors.redAccent),
                ),
              ),

              // Botón de Centrar/Actualizar Ubicación
              Positioned(
                top: 45,
                right: 15,
                child: FloatingActionButton(
                  heroTag: 'fab_location', // Tag único
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () async {
                    setState(
                      () => _isLoading = true,
                    ); // Loader local para esta acción
                    await _updateCurrentLocation(centerMap: true);
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ubicación actualizada y centrada'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: const Icon(Icons.my_location, color: Colors.redAccent),
                ),
              ),

              // Switch En Servicio / Fuera de Servicio
              Positioned(
                bottom: 15,
                left: 15,
                child: Card(
                  // Usar Card para mejor estética
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isOnDuty
                              ? Icons.online_prediction
                              : Icons.power_settings_new,
                          color: _isOnDuty ? Colors.green : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isOnDuty ? "En Servicio" : "Fuera",
                          style: TextStyle(
                            fontSize: 12,
                            color: _isOnDuty ? Colors.green : Colors.grey,
                          ),
                        ),
                        // Usar Transform.scale para hacer el switch más pequeño
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: _isOnDuty,
                            onChanged:
                                isLoading
                                    ? null
                                    : (value) => _toggleDutyStatus(
                                      value,
                                    ), // Deshabilitar durante carga
                            activeColor: Colors.green,
                            inactiveThumbColor: Colors.grey,
                            inactiveTrackColor: Colors.grey.shade300,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Panel de Solicitud Pendiente (si existe y no hay viaje activo)
              if (tripProvider.pendingRequests.isNotEmpty &&
                  tripProvider.activeTrip == null)
                _buildRequestPanel(
                  tripProvider.pendingRequests.first,
                  tripProvider.currentRoute,
                ),

              // Panel de Viaje Activo (si existe)
              if (tripProvider.activeTrip != null)
                _buildActiveTripPanel(tripProvider),

              // Sidebar (fuera del Consumer si no necesita datos del tripProvider)
              Sidebar(
                isVisible: _isSidebarVisible,
                onClose: () => setState(() => _isSidebarVisible = false),
                role: 'chofer', // Pasar rol dinámicamente si es necesario
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Widgets de Paneles ---

  Widget _buildRequestPanel(TripRequest request, Map<String, dynamic>? route) {
    // Usar DraggableScrollableSheet para un panel más moderno
    return DraggableScrollableSheet(
      initialChildSize: 0.35, // Tamaño inicial (ajustar)
      minChildSize: 0.15, // Tamaño mínimo al arrastrar hacia abajo
      maxChildSize: 0.5, // Tamaño máximo al arrastrar hacia arriba
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ListView(
            // Usar ListView para contenido desplazable
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              // Handle para arrastrar
              Center(
                child: Container(
                  height: 5,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Título y Distancia/Duración
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Nueva Solicitud',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${route?['duration'] ?? '-'} • ${route?['distance'] ?? '-'}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Origen y Destino
              _buildLocationRow(
                LucideIcons.locateFixed,
                'Origen',
                request.origin,
                Colors.blue,
              ),
              _buildLocationRow(
                LucideIcons.mapPin,
                'Destino',
                request.destination,
                Colors.red,
              ),
              if (request.trip_stops != null && request.trip_stops!.isNotEmpty)
                ...request.trip_stops!
                    .map(
                      (stop) => _buildLocationRow(
                        LucideIcons.flag,
                        'Parada: ${stop.name}',
                        '',
                        Colors.purple,
                      ),
                    )
                    .toList(),
              const Divider(height: 24),
              // Observaciones
              Row(
                children: [
                  const Icon(
                    LucideIcons.messageSquare,
                    size: 20,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.observations?.isNotEmpty == true
                          ? request.observations!
                          : 'Sin observaciones',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle:
                            request.observations?.isNotEmpty == true
                                ? FontStyle.normal
                                : FontStyle.italic,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Precio
              Row(
                children: [
                  const Icon(
                    LucideIcons.dollarSign,
                    size: 20,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '\$${request.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    '(Efectivo)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ), // Asumiendo efectivo
                ],
              ),
              const SizedBox(height: 20),
              // Botones Aceptar/Rechazar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(LucideIcons.x, size: 20),
                    label: const Text('Rechazar'),
                    onPressed:
                        () => _handleRequestResponse(
                          request.id,
                          TRIP_STATUS_REJECTED,
                        ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[400],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(LucideIcons.check, size: 20),
                    label: const Text('Aceptar'),
                    onPressed:
                        () => _handleRequestResponse(
                          request.id,
                          TRIP_STATUS_ACCEPTED,
                        ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20), // Espacio extra al final
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveTripPanel(TripProvider tripProvider) {
    final activeTrip = tripProvider.activeTrip!;
    final tripPhase = tripProvider.tripPhase;
    final currentStopIndex = tripProvider.currentStopIndex;
    final route = tripProvider.currentRoute;

    String title = '';
    String subtitle = '';
    IconData icon = LucideIcons.mapPin;
    Color iconColor = Colors.grey;
    String buttonText = '';
    VoidCallback? buttonAction;

    if (tripPhase == TRIP_PHASE_TO_PICKUP) {
      title = 'Dirígete al Origen';
      subtitle = activeTrip.origin;
      icon = LucideIcons.userCheck;
      iconColor = Colors.blue;
      buttonText = 'Llegué al Origen';
      buttonAction = _handleArrival;
    } else if (tripPhase == TRIP_PHASE_TO_STOPS) {
      final stop = activeTrip.trip_stops![currentStopIndex];
      title = 'Dirígete a la Parada ${currentStopIndex + 1}';
      subtitle = stop.name;
      icon = LucideIcons.flag;
      iconColor = Colors.purple;
      buttonText = 'Llegué a la Parada';
      buttonAction = _handleArrival;
    } else if (tripPhase == TRIP_PHASE_TO_DESTINATION) {
      title = 'Dirígete al Destino Final';
      subtitle = activeTrip.destination;
      icon = LucideIcons.house;
      iconColor = Colors.green;
      buttonText = 'Finalizar Viaje';
      buttonAction = _handleTripCompletion;
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Card(
        margin: EdgeInsets.zero, // Sin margen para que ocupe todo el ancho
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Información de la fase actual
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Distancia/Duración restante (opcional)
                  if (route != null)
                    Text(
                      '${route['duration'] ?? '-'} / ${route['distance'] ?? '-'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
              const Divider(height: 24),
              // Botones de acción
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Botón principal (Llegada/Finalizar)
                  if (buttonAction != null)
                    ElevatedButton.icon(
                      icon: const Icon(LucideIcons.mapPin, size: 18),
                      label: Text(buttonText),
                      onPressed: buttonAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: iconColor, // Usar color de la fase
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),

                  // Botón Llamar
                  _buildCircleButton(
                    LucideIcons.phone,
                    Colors.blue,
                    () => _launchPhoneCall(activeTrip.passengerPhone),
                    'call_button',
                  ),

                  // Botón Mensaje
                  _buildCircleButton(
                    LucideIcons.messageSquare,
                    Colors.orange,
                    () => _launchSMS(activeTrip.passengerPhone),
                    'sms_button',
                  ),

                  // Botón Cancelar
                  _buildCircleButton(
                    LucideIcons.x,
                    Colors.red,
                    _handleTripCancellation,
                    'cancel_button',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper para botones circulares pequeños
  Widget _buildCircleButton(
    IconData icon,
    Color color,
    VoidCallback onPressed,
    String heroTag,
  ) {
    return FloatingActionButton(
      heroTag: heroTag, // Necesario si hay múltiples FABs
      mini: true,
      onPressed: onPressed,
      backgroundColor: color,
      child: Icon(icon, size: 20, color: Colors.white),
    );
  }

  // Helper para filas de ubicación en el panel de solicitud
  Widget _buildLocationRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '$label: ',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontWeight: FontWeight.normal,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // --- Manejo de Solicitudes ---
  // Asegúrate que este método existe en la clase _DriverHomeScreenState
  Future<void> _handleNewRequest(TripRequest request) async {
    if (!mounted || _tripProvider.activeTrip != null) {
      print(
        'Solicitud ${request.id} ignorada (widget no montado o viaje activo).',
      );
      return;
    }

    if (_rejectedRequests.contains(request.id)) {
      print('Solicitud ${request.id} ya rechazada en esta sesión, ignorando.');
      return;
    }

    if (_tripProvider.hasPendingRequest(request.id)) {
      print('Solicitud ${request.id} ya está pendiente, ignorando duplicado.');
      return;
    }

    print(
      '[DriverHome] Procesando nueva solicitud: ${request.id}. Origen: ${request.origin}, Destino: ${request.destination}',
    );

    setState(() => _isLoading = true);

    try {
      // Calcular la ruta desde el origen hasta el destino
      final originLatLng = LatLng(request.originLat, request.originLng);
      final destinationLatLng = LatLng(
        request.destinationLat,
        request.destinationLng,
      );
      final stops = request.trip_stops ?? [];

      print(
        '[DriverHome] Calculando ruta para solicitud ${request.id}. Origen: $originLatLng, Destino: $destinationLatLng, Paradas: ${stops.length}',
      );

      final routeData = await _calculateRoute(
        originLatLng, // Desde el origen
        destinationLatLng, // Hasta el destino
        stops,
      );

      print(
        '[DriverHome] Ruta calculada para solicitud ${request.id}. Polyline tiene ${routeData['polyline']?.length ?? 0} puntos.',
      );

      _tripProvider.setNewPendingRequest(request, routeData);

      await _playNotificationSound();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateMapCamera();
        }
      });
    } catch (e) {
      print('Error al procesar la nueva solicitud ${request.id}: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar la solicitud: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      _tripProvider.clearPendingRequests();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Inicia la escucha de actualizaciones de ubicación si no está activa
  void _startLocationUpdates() {
    if (_locationSubscription == null) {
      print("Iniciando escucha de ubicación UI...");
      _locationSubscription = _location.onLocationChanged.listen(
        _onLocationChanged,
        onError: (e) {
          print('Error en stream de ubicación UI: $e');
          // Considerar reintentar o mostrar error
        },
      );
    } else {
      print("La escucha de ubicación UI ya estaba activa.");
      // Opcional: reanudar si estaba pausada
      // _locationSubscription.resume();
    }
  }

  // Escuchar mensajes del servicio en segundo plano
  void _setupBackgroundServiceListener() {
    _backgroundService ??= FlutterBackgroundService();
    _backgroundService!.on('newRequest').listen((event) {
      print("Mensaje 'newRequest' recibido del servicio BG en la UI.");
      if (event != null && event.containsKey('request')) {
        try {
          final requestData = jsonDecode(event['request']);
          final request = TripRequest.fromJson(requestData);
          print("Solicitud decodificada del BG: ${request.id}");
          // Procesar la solicitud usando el método existente
          _processIncomingRequest(requestData);
        } catch (e, s) {
          print("Error al procesar mensaje 'newRequest' del BG: $e\n$s");
        }
      }
    });
    print("Listener para mensajes del servicio BG configurado.");
  }

  // Helper para calcular el padding inferior del mapa dinámicamente
  double _calculateMapPadding(TripProvider tripProvider) {
    if (tripProvider.activeTrip != null) {
      return 180; // Espacio para el panel de viaje activo
    } else if (tripProvider.pendingRequests.isNotEmpty) {
      // Estimar altura del DraggableScrollableSheet (initial * screen_height)
      // O usar un valor fijo grande si es más simple
      return 280; // Espacio generoso para el panel de solicitud
    } else {
      return 90; // Espacio para el switch 'En Servicio'
    }
  }
} // Fin de _DriverHomeScreenState
