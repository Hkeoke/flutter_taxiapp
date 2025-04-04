// Estados del Viaje
const String TRIP_STATUS_BROADCASTING = 'broadcasting';
const String TRIP_STATUS_ACCEPTED = 'accepted';
const String TRIP_STATUS_REJECTED = 'rejected';
const String TRIP_STATUS_IN_PROGRESS = 'in_progress';
const String TRIP_STATUS_PICKUP_REACHED = 'pickup_reached';
const String TRIP_STATUS_COMPLETED = 'completed';
const String TRIP_STATUS_CANCELLED = 'cancelled';

// Fases del Viaje (lado del conductor)
const String TRIP_PHASE_NONE = 'none';
const String TRIP_PHASE_TO_PICKUP = 'toPickup';
const String TRIP_PHASE_TO_STOPS = 'toStops';
const String TRIP_PHASE_TO_DESTINATION = 'toDestination';

// IDs de Canales de Notificación
const String NOTIFICATION_CHANNEL_SERVICE_ID = 'taxi_driver_service';
const String NOTIFICATION_CHANNEL_SERVICE_NAME = 'Servicio de Conductor';
const String NOTIFICATION_CHANNEL_REQUESTS_ID = 'trip_requests';
const String NOTIFICATION_CHANNEL_REQUESTS_NAME = 'Solicitudes de Viaje';

// SharedPreferences Keys
const String PREFS_USER_ID = 'user_id';
const String PREFS_IS_ON_DUTY = 'is_on_duty';
const String PREFS_ACTIVE_TRIP = 'active_trip';
const String PREFS_TRIP_PHASE = 'trip_phase';
const String PREFS_REJECTED_REQUESTS = 'rejectedRequests';
const String PREFS_HAS_ACTIVE_TRIP = 'has_active_trip'; // Para el servicio BG

// Otros
const double MAX_ROUTE_DEVIATION = 5.0; // Metros
const int LOCATION_UPDATE_INTERVAL = 10000; // Milisegundos
const double LOCATION_UPDATE_DISTANCE_FILTER = 5.0; // Metros
