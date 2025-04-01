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
    _currentRoute = route;
    if (route != null) {
      if (route['polyline'] is List<LatLng>) {
        _visibleRoute = route['polyline'] as List<LatLng>;
      } else if (route['polyline'] is List) {
        _visibleRoute =
            (route['polyline'] as List)
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
      } else {
        _visibleRoute = [];
      }
    } else {
      _visibleRoute = [];
    }
    notifyListeners();
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

  void clearTrip() {
    debugPrint('Limpieza del viaje iniciada');
    _activeTrip = null;
    _pendingRequests = [];
    _tripPhase = 'none';
    _currentRoute = null;
    _visibleRoute = [];
    _markers = {};
    _polylines = {};
    _currentStopIndex = -1;
    setLoading(false);
    notifyListeners();
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

  // Método para verificar si una solicitud ya está en la lista
  bool hasRequest(String requestId) {
    return _pendingRequests.any((r) => r.id == requestId);
  }
}
