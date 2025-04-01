import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TripProvider with ChangeNotifier {
  Trip? _activeTrip;
  List<TripRequest> _pendingRequests = [];
  String _tripPhase = 'none';
  Map<String, dynamic>? _currentRoute;
  List<LatLng> _visibleRoute = [];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  int _currentStopIndex = -1;
  bool _isLoading = false;
  bool _requestsLoaded = false;

  // Getters
  Trip? get activeTrip => _activeTrip;
  List<TripRequest> get pendingRequests => _pendingRequests;
  String get tripPhase => _tripPhase;
  Map<String, dynamic>? get currentRoute => _currentRoute;
  List<LatLng> get visibleRoute => _visibleRoute;
  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;
  int get currentStopIndex => _currentStopIndex;
  bool get isLoading => _isLoading;

  // Setters
  void setActiveTrip(Trip? trip) {
    _activeTrip = trip;
    notifyListeners();
  }

  void setPendingRequests(List<TripRequest> requests) {
    _pendingRequests = requests;
    notifyListeners();
  }

  void setTripPhase(String phase) {
    _tripPhase = phase;
    notifyListeners();
  }

  void setCurrentRoute(Map<String, dynamic>? route) {
    print(
      '[TripProvider] setCurrentRoute llamado. Route data: ${route != null ? route.keys : 'null'}',
    );
    _currentRoute = route;
    List<LatLng> newVisibleRoute = []; // Empezar con lista vacía

    if (route != null && route['polyline'] != null) {
      final polylineData = route['polyline'];
      print(
        '[TripProvider] Procesando polylineData: ${polylineData.runtimeType}',
      );

      if (polylineData is List<LatLng>) {
        // Caso ideal: ya es List<LatLng>
        newVisibleRoute = polylineData;
        print(
          '[TripProvider] Polyline es List<LatLng>. Longitud: ${newVisibleRoute.length}',
        );
      } else if (polylineData is List) {
        // Intentar convertir desde List<dynamic>
        print(
          '[TripProvider] Polyline es List<dynamic>. Intentando convertir...',
        );
        newVisibleRoute =
            polylineData
                .map((p) {
                  // Añadir más checks robustos
                  if (p is LatLng) return p;
                  if (p is List &&
                      p.length >= 2 &&
                      p[0] is num &&
                      p[1] is num) {
                    return LatLng(p[0].toDouble(), p[1].toDouble());
                  }
                  if (p is Map &&
                      p.containsKey('latitude') &&
                      p.containsKey('longitude') &&
                      p['latitude'] is num &&
                      p['longitude'] is num) {
                    return LatLng(
                      (p['latitude'] as num).toDouble(),
                      (p['longitude'] as num).toDouble(),
                    );
                  }
                  // Nuevo check para formato OSRM [lon, lat]
                  if (p is List &&
                      p.length >= 2 &&
                      p[0] is num &&
                      p[1] is num) {
                    print(
                      '[TripProvider] Detectado posible formato OSRM [lon, lat]',
                    );
                    // Asegurarse de que el índice 1 (latitud) va primero en LatLng
                    return LatLng(p[1].toDouble(), p[0].toDouble());
                  }
                  print(
                    '[TripProvider] Elemento de polilínea no reconocido: $p',
                  );
                  return null;
                })
                .whereType<LatLng>()
                .toList();
        print(
          '[TripProvider] Conversión completada. Longitud: ${newVisibleRoute.length}',
        );
      } else {
        print(
          '[TripProvider] polylineData no es una lista: ${polylineData.runtimeType}',
        );
      }
    } else {
      print('[TripProvider] Route o polyline es null.');
    }

    // Solo actualizar si la ruta es diferente para evitar notificaciones innecesarias
    // if (!listEquals(_visibleRoute, newVisibleRoute)) { // Necesita import 'package:flutter/foundation.dart';
    print(
      '[TripProvider] Actualizando _visibleRoute. Nueva longitud: ${newVisibleRoute.length}',
    );
    _visibleRoute = newVisibleRoute;
    notifyListeners();
    // } else {
    //   print('[TripProvider] _visibleRoute no cambió. No se notifica.');
    // }
  }

  void setMarkers(Set<Marker> markers) {
    _markers = markers;
    notifyListeners();
  }

  void setPolylines(Set<Polyline> polylines) {
    _polylines = polylines;
    notifyListeners();
  }

  void setCurrentStopIndex(int index) {
    _currentStopIndex = index;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearTrip({bool notify = true}) {
    print('[TripProvider] clearTrip llamado.');
    _activeTrip = null;
    _tripPhase = 'none';
    _currentRoute = null;
    _visibleRoute.clear(); // Limpiar explícitamente
    _markers.clear();
    _polylines.clear();
    _currentStopIndex = -1;
    if (notify) {
      notifyListeners();
    }
  }

  // Método para actualizar múltiples propiedades a la vez
  void updateTripState({
    Trip? activeTrip,
    List<TripRequest>? pendingRequests,
    String? tripPhase,
    Map<String, dynamic>? currentRoute,
    int? currentStopIndex,
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    bool? isLoading,
  }) {
    if (activeTrip != null) _activeTrip = activeTrip;
    if (pendingRequests != null) _pendingRequests = pendingRequests;
    if (tripPhase != null) _tripPhase = tripPhase;
    if (currentRoute != null) {
      _currentRoute = currentRoute;
      if (currentRoute['polyline'] is List<LatLng>) {
        _visibleRoute = currentRoute['polyline'] as List<LatLng>;
      } else if (currentRoute['polyline'] is List) {
        _visibleRoute =
            (currentRoute['polyline'] as List)
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
                  return null;
                })
                .whereType<LatLng>()
                .toList();
      }
    }
    if (currentStopIndex != null) _currentStopIndex = currentStopIndex;
    if (markers != null) _markers = markers;
    if (polylines != null) _polylines = polylines;
    if (isLoading != null) _isLoading = isLoading;

    notifyListeners();
  }

  void setVisibleRoute(List<LatLng> route) {
    _visibleRoute = route;
    notifyListeners();
  }

  void updateVisibleRoute(List<LatLng> newRoute) {
    _visibleRoute = newRoute;
    notifyListeners();
  }

  // Método para guardar una solicitud que llega en segundo plano
  void saveBackgroundRequest(TripRequest request) {
    // Si ya existe una solicitud con el mismo ID, no la añadimos
    if (_pendingRequests.any((r) => r.id == request.id)) {
      debugPrint('Solicitud ya existente en provider: ${request.id}');
      return;
    }

    debugPrint('Guardando solicitud en provider: ${request.id}');

    // Añadir la solicitud a la lista de pendientes
    _pendingRequests = [request, ..._pendingRequests];
    _requestsLoaded = true;

    // Guardar también en SharedPreferences para persistencia
    _savePendingRequestsToPrefs();

    notifyListeners();
  }

  // Método para guardar las solicitudes pendientes en SharedPreferences
  Future<void> _savePendingRequestsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_pendingRequests.isNotEmpty) {
        final requestsJson =
            _pendingRequests.map((r) => jsonEncode(r.toJson())).toList();
        await prefs.setStringList('pending_requests', requestsJson);
        debugPrint(
          'Solicitudes guardadas en SharedPreferences: ${requestsJson.length}',
        );
      } else {
        await prefs.remove('pending_requests');
        debugPrint('Solicitudes eliminadas de SharedPreferences');
      }
    } catch (e) {
      debugPrint('Error guardando solicitudes en SharedPreferences: $e');
    }
  }

  // Método para cargar solicitudes pendientes desde SharedPreferences
  Future<void> loadPendingRequestsFromPrefs() async {
    // Si ya se cargaron las solicitudes, no volver a cargarlas
    if (_requestsLoaded) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final requestsJson = prefs.getStringList('pending_requests');
      if (requestsJson != null && requestsJson.isNotEmpty) {
        _pendingRequests =
            requestsJson
                .map((json) => TripRequest.fromJson(jsonDecode(json)))
                .toList();
        debugPrint(
          'Solicitudes cargadas desde SharedPreferences: ${_pendingRequests.length}',
        );
        _requestsLoaded = true;
        notifyListeners();
      } else {
        _requestsLoaded = true;
      }
    } catch (e) {
      debugPrint('Error cargando solicitudes desde SharedPreferences: $e');
      _requestsLoaded = true;
    }
  }

  // Método para procesar solicitudes guardadas en segundo plano
  Future<void> processPendingBackgroundRequests(
    Future<void> Function(TripRequest) requestHandler,
  ) async {
    if (_pendingRequests.isEmpty) {
      debugPrint('No hay solicitudes pendientes del background para procesar.');
      return;
    }

    debugPrint(
      'Procesando ${_pendingRequests.length} solicitudes pendientes del background...',
    );
    final requestsToProcess = List<TripRequest>.from(_pendingRequests);
    _pendingRequests.clear(); // Limpiar la lista interna primero

    // Notificar que la lista está vacía ahora (antes de procesar)
    notifyListeners();

    // Procesar cada solicitud
    for (final request in requestsToProcess) {
      try {
        await requestHandler(request);
      } catch (e) {
        debugPrint(
          'Error procesando solicitud pendiente ${request.id} desde el background: $e',
        );
        // Considerar si volver a añadirla a pendientes o descartarla
      }
    }

    // Limpiar SharedPreferences después de procesar
    await _clearPendingRequestsFromPrefs();
    debugPrint('Solicitudes pendientes del background procesadas.');
  }

  // Método privado para limpiar las solicitudes de SharedPreferences
  Future<void> _clearPendingRequestsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_requests');
      debugPrint('Solicitudes pendientes eliminadas de SharedPreferences.');
    } catch (e) {
      debugPrint(
        'Error eliminando solicitudes pendientes de SharedPreferences: $e',
      );
    }
  }

  // Método para verificar si una solicitud ya está en la lista
  bool hasRequest(String requestId) {
    return _pendingRequests.any((r) => r.id == requestId);
  }

  // --- Métodos añadidos para compatibilidad con DriverHomeScreen ---

  // Verifica si existe una solicitud pendiente con el ID dado
  bool hasPendingRequest(String requestId) {
    return _pendingRequests.any((r) => r.id == requestId);
  }

  // Establece una nueva solicitud pendiente (generalmente solo una a la vez en UI)
  void setNewPendingRequest(TripRequest request, Map<String, dynamic>? route) {
    _pendingRequests = [request]; // Reemplaza las existentes
    setCurrentRoute(route); // Establece la ruta asociada
    // No es necesario guardar en prefs aquí, se maneja en saveBackgroundRequest
    notifyListeners();
  }

  // Obtiene una solicitud pendiente por su ID
  TripRequest? getPendingRequestById(String requestId) {
    try {
      return _pendingRequests.firstWhere((r) => r.id == requestId);
    } catch (e) {
      return null; // No encontrada
    }
  }

  // Limpia todas las solicitudes pendientes (usado al rechazar o aceptar)
  void clearPendingRequests() {
    print('[TripProvider] clearPendingRequests llamado.');
    if (_pendingRequests.isNotEmpty) {
      _pendingRequests.clear();
      _currentRoute = null; // Limpiar ruta asociada a la solicitud
      _visibleRoute.clear(); // Limpiar ruta visible
      _markers.clear(); // Limpiar marcadores asociados
      _polylines.clear(); // Limpiar polilíneas asociadas
      _clearPendingRequestsFromPrefs(); // Limpiar persistencia también
      notifyListeners();
    }
  }

  // Añade una solicitud recibida en segundo plano (similar a saveBackgroundRequest pero sin notificar inmediatamente?)
  // Reutilizamos saveBackgroundRequest ya que hace lo necesario
  void addBackgroundRequest(TripRequest request) {
    saveBackgroundRequest(request);
  }

  // Establece el viaje activo y la fase inicial
  void startActiveTrip(Trip trip, String initialPhase) {
    print('[TripProvider] startActiveTrip llamado para viaje: ${trip.id}');
    _activeTrip = trip;
    _tripPhase = initialPhase;
    _pendingRequests.clear();
    _currentStopIndex = -1; // Resetear índice de parada

    // QUITAR ESTO: No limpiar la ruta aquí, se establecerá justo después
    // _currentRoute = null;
    // _visibleRoute.clear();
    // _markers.clear(); // Los marcadores se reconstruirán
    // _polylines.clear(); // Las polilíneas se reconstruirán

    _clearPendingRequestsFromPrefs(); // Limpiar persistencia de solicitudes
    notifyListeners(); // Notificar cambio de estado (sin ruta aún)
  }

  // Actualiza la fase del viaje, índice de parada y ruta
  void updateTripPhaseAndRoute(
    String nextPhase,
    int nextStopIndex,
    Map<String, dynamic>? newRoute,
  ) {
    _tripPhase = nextPhase;
    _currentStopIndex = nextStopIndex;
    setCurrentRoute(newRoute); // Esto ya notifica
  }

  // Restaura un viaje activo desde persistencia
  void restoreActiveTrip(Trip tripData, String tripPhase, int stopIndex) {
    _activeTrip = tripData;
    _tripPhase = tripPhase;
    _currentStopIndex = stopIndex;
    // La ruta se recalculará si es necesario en DriverHomeScreen
    _pendingRequests.clear(); // Asegurar que no haya pendientes
    notifyListeners();
  }

  // Limpia el estado del viaje (puede mantener o no las solicitudes pendientes)
}
