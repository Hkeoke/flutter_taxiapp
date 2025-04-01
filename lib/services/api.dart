// ignore: avoid_print

import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:realtime_client/realtime_client.dart';
import 'package:flutter/foundation.dart';

// Cliente de Supabase
final supabase = Supabase.instance.client;

// Enums para tipos de datos
enum TripStatus { pending, inProgress, completed, cancelled }

enum Role { driver, operator, admin }

enum BalanceOperationType { recarga, descuento, comision, ajuste }

enum VehicleType { twoWheels, fourWheels }

// Extensión para convertir enums a strings
extension TripStatusExtension on TripStatus {
  String get value {
    switch (this) {
      case TripStatus.pending:
        return 'pending';
      case TripStatus.inProgress:
        return 'in_progress';
      case TripStatus.completed:
        return 'completed';
      case TripStatus.cancelled:
        return 'cancelled';
    }
  }
}

extension RoleExtension on Role {
  String get value {
    switch (this) {
      case Role.driver:
        return 'chofer';
      case Role.operator:
        return 'operador';
      case Role.admin:
        return 'admin';
    }
  }
}

extension BalanceOperationTypeExtension on BalanceOperationType {
  String get value {
    switch (this) {
      case BalanceOperationType.recarga:
        return 'recarga';
      case BalanceOperationType.descuento:
        return 'descuento';
      case BalanceOperationType.comision:
        return 'comision';
      case BalanceOperationType.ajuste:
        return 'ajuste';
    }
  }
}

extension VehicleTypeExtension on VehicleType {
  String get value {
    switch (this) {
      case VehicleType.twoWheels:
        return '2_ruedas';
      case VehicleType.fourWheels:
        return '4_ruedas';
    }
  }
}

// Modelos de datos
class User {
  final String id;
  final String phoneNumber;
  final String pin;
  final String role;
  final bool active;
  final DriverProfile? driverProfile;
  final OperatorProfile? operatorProfile;

  User({
    required this.id,
    required this.phoneNumber,
    required this.pin,
    required this.role,
    required this.active,
    this.driverProfile,
    this.operatorProfile,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      phoneNumber: json['phone_number'],
      pin: json['pin'],
      role: json['role'],
      active: json['active'],
      driverProfile:
          json['driver_profiles'] != null
              ? DriverProfile.fromJson(json['driver_profiles'])
              : null,
      operatorProfile:
          json['operator_profiles'] != null
              ? OperatorProfile.fromJson(json['operator_profiles'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      'pin': pin,
      'role': role,
      'active': active,
      'driver_profiles': driverProfile?.toJson(),
      'operator_profiles': operatorProfile?.toJson(),
    };
  }
}

class DriverProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String vehicle;
  final String vehicleType;
  final bool isOnDuty;
  final bool isSpecial;
  final double? latitude;
  final double? longitude;
  final double balance;
  final String? licenseNumber;
  final String? lastLocationUpdate;
  final dynamic users;

  DriverProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.vehicle,
    required this.vehicleType,
    required this.isOnDuty,
    required this.isSpecial,
    this.latitude,
    this.longitude,
    this.balance = 0.0,
    this.licenseNumber,
    this.lastLocationUpdate,
    this.users,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      id: json['id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      phoneNumber: json['phone_number'],
      vehicle: json['vehicle'],
      vehicleType: json['vehicle_type'],
      isOnDuty: json['is_on_duty'] ?? false,
      isSpecial: json['is_special'] ?? false,
      latitude: json['latitude'],
      longitude: json['longitude'],
      balance: json['balance'] != null ? json['balance'].toDouble() : 0.0,
      licenseNumber: json['license_number'],
      lastLocationUpdate: json['last_location_update'],
      users: json['users'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'phone_number': phoneNumber,
      'vehicle': vehicle,
      'vehicle_type': vehicleType,
      'is_on_duty': isOnDuty,
      'is_special': isSpecial,
      'latitude': latitude,
      'longitude': longitude,
      'balance': balance,
      'license_number': licenseNumber,
      'last_location_update': lastLocationUpdate,
    };
  }
}

class OperatorProfile {
  final String id;
  final String first_name;
  final String last_name;
  final String identityCard;
  final String? phone_number;
  final Map<String, dynamic>? users;

  OperatorProfile({
    required this.id,
    required this.first_name,
    required this.last_name,
    required this.identityCard,
    this.phone_number,
    this.users,
  });

  factory OperatorProfile.fromJson(Map<String, dynamic> json) {
    return OperatorProfile(
      id: json['id'],
      first_name: json['first_name'],
      last_name: json['last_name'],
      identityCard: json['identity_card'],
      phone_number: json['phone_number'],
      users: json['users'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': first_name,
      'last_name': last_name,
      'identity_card': identityCard,
      'phone_number': phone_number,
      'users': users,
    };
  }

  String get firstName => first_name;
  String get lastName => last_name;
  String? get phoneNumber => phone_number;
}

class Trip {
  final String id;
  final String origin;
  final String destination;
  final double originLat;
  final double originLng;
  final double destinationLat;
  final double destinationLng;
  final double price;
  final String status;
  final String createdBy;
  final String? driverId;
  final String? passengerPhone;
  final String? observations;
  final String createdAt;
  final String? completedAt;
  final String? cancelledAt;
  final String? cancelledBy;
  final String? cancellationReason;
  final List<TripStop>? trip_stops;
  final dynamic driver_profiles;
  final dynamic operator_profiles;

  Trip({
    required this.id,
    required this.origin,
    required this.destination,
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.price,
    required this.status,
    required this.createdBy,
    this.driverId,
    this.passengerPhone,
    this.observations,
    required this.createdAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelledBy,
    this.cancellationReason,
    this.trip_stops,
    this.driver_profiles,
    this.operator_profiles,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    List<TripStop>? stops;
    if (json['trip_stops'] != null) {
      stops =
          (json['trip_stops'] as List)
              .map((stop) => TripStop.fromJson(stop))
              .toList();
    }

    return Trip(
      id: json['id'],
      origin: json['origin'],
      destination: json['destination'],
      originLat: json['origin_lat'].toDouble(),
      originLng: json['origin_lng'].toDouble(),
      destinationLat: json['destination_lat'].toDouble(),
      destinationLng: json['destination_lng'].toDouble(),
      price: double.parse(json['price'].toString()),
      status: json['status'],
      createdBy: json['created_by'],
      driverId: json['driver_id'],
      passengerPhone: json['passenger_phone'],
      observations: json['observations'],
      createdAt: json['created_at'],
      completedAt: json['completed_at'],
      cancelledAt: json['cancelled_at'],
      cancelledBy: json['cancelled_by'],
      cancellationReason: json['cancellation_reason'],
      trip_stops: stops,
      driver_profiles: json['driver_profiles'],
      operator_profiles: json['operator_profiles'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'origin': origin,
      'destination': destination,
      'origin_lat': originLat,
      'origin_lng': originLng,
      'destination_lat': destinationLat,
      'destination_lng': destinationLng,
      'price': price,
      'status': status,
      'created_by': createdBy,
      'driver_id': driverId,
      'passenger_phone': passengerPhone,
      'observations': observations,
      'created_at': createdAt,
      'completed_at': completedAt,
      'cancelled_at': cancelledAt,
      'cancelled_by': cancelledBy,
      'cancellation_reason': cancellationReason,
      'trip_stops': trip_stops?.map((stop) => stop.toJson()).toList(),
      'driver_profiles': driver_profiles,
      'operator_profiles': operator_profiles,
    };
  }
}

class TripRequest {
  final String id;
  final String createdBy;
  final String origin;
  final String destination;
  final double originLat;
  final double originLng;
  final double destinationLat;
  final double destinationLng;
  final double price;
  final String status;
  final String passengerPhone;
  final String? observations;
  final String createdAt;
  final List<TripStop>? trip_stops;

  TripRequest({
    required this.id,
    required this.createdBy,
    required this.origin,
    required this.destination,
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.price,
    required this.status,
    required this.passengerPhone,
    this.observations,
    required this.createdAt,
    this.trip_stops,
  });

  factory TripRequest.fromJson(Map<String, dynamic> json) {
    List<TripStop>? stops;
    if (json['trip_stops'] != null) {
      stops =
          (json['trip_stops'] as List)
              .map((stop) => TripStop.fromJson(stop))
              .toList();
    }

    return TripRequest(
      id: json['id'],
      createdBy: json['created_by'],
      origin: json['origin'],
      destination: json['destination'],
      originLat: json['origin_lat'].toDouble(),
      originLng: json['origin_lng'].toDouble(),
      destinationLat: json['destination_lat'].toDouble(),
      destinationLng: json['destination_lng'].toDouble(),
      price: json['price'].toDouble(),
      status: json['status'],
      passengerPhone: json['passenger_phone'],
      observations: json['observations'],
      createdAt: json['created_at'],
      trip_stops: stops,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_by': createdBy,
      'origin': origin,
      'destination': destination,
      'origin_lat': originLat,
      'origin_lng': originLng,
      'destination_lat': destinationLat,
      'destination_lng': destinationLng,
      'price': price,
      'status': status,
      'passenger_phone': passengerPhone,
      'observations': observations,
      'created_at': createdAt,
      'trip_stops': trip_stops?.map((stop) => stop.toJson()).toList(),
    };
  }
}

class TripStop {
  final String id;
  final String tripRequestId;
  final String name;
  final double latitude;
  final double longitude;
  final int orderIndex;
  final bool completed;
  final String? completedAt;

  TripStop({
    required this.id,
    required this.tripRequestId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.orderIndex,
    this.completed = false,
    this.completedAt,
  });

  factory TripStop.fromJson(Map<String, dynamic> json) {
    return TripStop(
      id: json['id'],
      tripRequestId: json['trip_request_id'],
      name: json['name'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      orderIndex: json['order_index'],
      completed: json['completed'] ?? false,
      completedAt: json['completed_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_request_id': tripRequestId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'order_index': orderIndex,
      'completed': completed,
      'completed_at': completedAt,
    };
  }
}

class BalanceHistory {
  final String id;
  final String driverId;
  final double amount;
  final String type;
  final String description;
  final String createdBy;
  final String createdAt;
  final Map<String, dynamic>? user;

  BalanceHistory({
    required this.id,
    required this.driverId,
    required this.amount,
    required this.type,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    this.user,
  });

  factory BalanceHistory.fromJson(Map<String, dynamic> json) {
    return BalanceHistory(
      id: json['id'],
      driverId: json['driver_id'],
      amount: json['amount'].toDouble(),
      type: json['type'],
      description: json['description'],
      createdBy: json['created_by'],
      createdAt: json['created_at'],
      user: json['users'],
    );
  }
}

// Servicios
class AuthService {
  Future<User> login(String phoneNumber, String pin) async {
    final response =
        await supabase
            .from('users')
            .select('''
          *,
          driver_profiles(*),
          operator_profiles(*)
        ''')
            .eq('phone_number', phoneNumber)
            .eq('pin', pin)
            .eq('active', true)
            .single();

    return User.fromJson(response);
  }

  Future<User> register(Map<String, dynamic> userData) async {
    final response =
        await supabase.from('users').insert(userData).select().single();
    return User.fromJson(response);
  }

  Future<bool> deleteUser(String userId) async {
    try {
      // Obtener el rol del usuario
      final userData =
          await supabase.from('users').select('role').eq('id', userId).single();

      // Eliminar el perfil correspondiente según el rol
      if (userData['role'] == 'chofer') {
        await supabase.from('driver_profiles').delete().eq('id', userId);
      } else if (userData['role'] == 'operador') {
        await supabase.from('operator_profiles').delete().eq('id', userId);
      }

      // Eliminar el usuario
      await supabase.from('users').delete().eq('id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }
}

class DriverService {
  Future<DriverProfile> createProfile(Map<String, dynamic> profileData) async {
    final response =
        await supabase
            .from('driver_profiles')
            .insert(profileData)
            .select()
            .single();
    return DriverProfile.fromJson(response);
  }

  Future<DriverProfile> updateLocation(
    String driverId,
    double latitude,
    double longitude,
  ) async {
    final response =
        await supabase
            .from('driver_profiles')
            .update({
              'latitude': latitude,
              'longitude': longitude,
              'last_location_update': DateTime.now().toIso8601String(),
            })
            .eq('id', driverId)
            .select()
            .single();
    return DriverProfile.fromJson(response);
  }

  Future<List<DriverProfile>> getAvailableDrivers() async {
    final response = await supabase
        .from('driver_profiles')
        .select('''
          *,
          users!inner(*)
        ''')
        .eq('users.active', true)
        .eq('is_on_duty', true)
        .not('latitude', 'is', null)
        .not('longitude', 'is', null);

    return response.map((data) => DriverProfile.fromJson(data)).toList();
  }

  Future<DriverProfile> getDriverProfile(String driverId) async {
    final response =
        await supabase
            .from('driver_profiles')
            .select('*, is_on_duty')
            .eq('id', driverId)
            .single();
    return DriverProfile.fromJson(response);
  }

  Future<void> updateBalance(
    String driverId,
    double amount, {
    bool isDeduction = false,
  }) async {
    final finalAmount = isDeduction ? -amount : amount;
    await supabase.rpc(
      'increment_driver_balance',
      params: {'driver_id': driverId, 'amount': finalAmount},
    );
  }

  Future<List<Trip>> getActiveTrips(String driverId) async {
    final response = await supabase
        .from('trips')
        .select('''
          *,
          operator_profiles (
            first_name,
            last_name
          )
        ''')
        .eq('driver_id', driverId)
        .filter('status', 'in', ['pending', 'in_progress']);

    return response.map((data) => Trip.fromJson(data)).toList();
  }

  Future<List<DriverProfile>> getAllDriversWithLocation() async {
    final response = await supabase
        .from('driver_profiles')
        .select('''
          *,
          users!inner (
            active
          )
        ''')
        .eq('users.active', true)
        .not('latitude', 'is', null)
        .not('longitude', 'is', null)
        .order('created_at', ascending: false);

    return response.map((data) => DriverProfile.fromJson(data)).toList();
  }

  Future<List<DriverProfile>> getAllDrivers() async {
    final response = await supabase
        .from('driver_profiles')
        .select('''
          *,
          users (
            active
          )
        ''')
        .order('created_at', ascending: false);

    return response.map((data) => DriverProfile.fromJson(data)).toList();
  }

  Future<Map<String, dynamic>> createDriver({
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String vehicle,
    required String vehicleType,
    required String pin,
    required bool isSpecial,
  }) async {
    try {
      // Verificar si ya existe un usuario con ese número de teléfono
      final existingUser =
          await supabase
              .from('users')
              .select()
              .eq('phone_number', phoneNumber)
              .maybeSingle();

      if (existingUser != null) {
        return {
          'success': false,
          'error': 'Ya existe un usuario con este número de teléfono',
        };
      }

      // Crear usuario
      final userData =
          await supabase
              .from('users')
              .insert({
                'phone_number': phoneNumber,
                'pin': pin,
                'role': 'chofer',
                'active': true,
              })
              .select()
              .single();

      // Crear perfil de conductor
      final driverProfile =
          await supabase
              .from('driver_profiles')
              .insert({
                'id': userData['id'],
                'first_name': firstName,
                'last_name': lastName,
                'phone_number': phoneNumber,
                'vehicle': vehicle,
                'vehicle_type': vehicleType,
                'is_special': isSpecial,
                'license_number':
                    'LIC-${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecondsSinceEpoch.toString().substring(0, 5)}',
              })
              .select()
              .single();

      return {
        'success': true,
        'data': {...userData, 'driver_profile': driverProfile},
      };
    } catch (e) {
      //print('Error en createDriver: $e');
      rethrow;
    }
  }

  Future<DriverProfile> updateDriverStatus(
    String driverId,
    bool isOnDuty,
  ) async {
    final response =
        await supabase
            .from('driver_profiles')
            .update({'is_on_duty': isOnDuty})
            .eq('id', driverId)
            .select('''
          id,
          first_name,
          last_name,
          phone_number,
          vehicle,
          vehicle_type,
          is_on_duty,
          balance,
          users!inner (*)
        ''')
            .single();
    return DriverProfile.fromJson(response);
  }

  Future<void> deactivateUser(String driverId, bool activate) async {
    await supabase
        .from('users')
        .update({'active': activate})
        .eq('id', driverId);
  }

  Future<DriverProfile> updateDriver(
    String driverId,
    Map<String, dynamic> driverData,
  ) async {
    // Actualizar usuario si hay cambios en phone_number o pin
    if (driverData.containsKey('phone_number') ||
        driverData.containsKey('pin')) {
      final userUpdates = <String, dynamic>{};
      if (driverData.containsKey('phone_number')) {
        userUpdates['phone_number'] = driverData['phone_number'];
      }
      if (driverData.containsKey('pin')) {
        userUpdates['pin'] = driverData['pin'];
      }

      await supabase.from('users').update(userUpdates).eq('id', driverId);
    }

    // Actualizar perfil del conductor
    final driverUpdates = <String, dynamic>{
      if (driverData.containsKey('first_name'))
        'first_name': driverData['first_name'],
      if (driverData.containsKey('last_name'))
        'last_name': driverData['last_name'],
      if (driverData.containsKey('phone_number'))
        'phone_number': driverData['phone_number'],
      if (driverData.containsKey('vehicle')) 'vehicle': driverData['vehicle'],
      if (driverData.containsKey('vehicle_type'))
        'vehicle_type': driverData['vehicle_type'],
    };

    final response =
        await supabase
            .from('driver_profiles')
            .update(driverUpdates)
            .eq('id', driverId)
            .select()
            .single();
    return DriverProfile.fromJson(response);
  }

  Future<Map<String, dynamic>> toggleDutyStatus(String driverId) async {
    try {
      // Obtener estado actual
      final currentState =
          await supabase
              .from('driver_profiles')
              .select('is_on_duty')
              .eq('id', driverId)
              .single();

      final newDutyStatus = !(currentState['is_on_duty'] as bool);

      // Actualizar al estado opuesto
      final response =
          await supabase
              .from('driver_profiles')
              .update({
                'is_on_duty': newDutyStatus,
                'last_duty_change': DateTime.now().toIso8601String(),
              })
              .eq('id', driverId)
              .select('is_on_duty')
              .single();

      return {'success': true, 'isOnDuty': response['is_on_duty']};
    } catch (e) {
      //print('Error toggling duty status: $e');
      rethrow;
    }
  }

  Future<BalanceHistory> updateDriverBalance(
    String driverId,
    double amount,
    BalanceOperationType type,
    String description,
    String adminId,
  ) async {
    // Crear registro en el historial de balance
    final balanceHistory =
        await supabase
            .from('balance_history')
            .insert({
              'driver_id': driverId,
              'amount': amount,
              'type': type.value,
              'description': description,
              'created_by': adminId,
            })
            .select()
            .single();

    // Actualizar el balance del conductor
    final finalAmount =
        type == BalanceOperationType.descuento ? -amount : amount;
    await supabase.rpc(
      'increment_driver_balance',
      params: {'driver_id': driverId, 'amount': finalAmount},
    );

    return BalanceHistory.fromJson(balanceHistory);
  }

  Future<List<BalanceHistory>> getBalanceHistory(
    String driverId, {
    String? startDate,
    String? endDate,
  }) async {
    var query = supabase
        .from('balance_history')
        .select('''
          *,
          users:created_by (
            role,
            operator_profiles(first_name, last_name),
            driver_profiles(first_name, last_name)
          )
        ''')
        .eq('driver_id', driverId);

    if (startDate != null) {
      query = query.filter('created_at', 'gte', startDate);
    }
    if (endDate != null) {
      query = query.filter('created_at', 'lte', endDate);
    }

    final response = await query.order('created_at', ascending: false);
    return response.map((data) => BalanceHistory.fromJson(data)).toList();
  }

  Future<void> updateDutyStatus(String driverId, bool isOnDuty) async {
    try {
      await supabase
          .from('driver_profiles')
          .update({'is_on_duty': isOnDuty})
          .eq('id', driverId);
    } catch (e) {
      print('Error actualizando estado de servicio: $e');
      rethrow;
    }
  }
}

class OperatorService {
  Future<OperatorProfile> createProfile(
    Map<String, dynamic> profileData,
  ) async {
    final response =
        await supabase
            .from('operator_profiles')
            .insert(profileData)
            .select()
            .single();
    return OperatorProfile.fromJson(response);
  }

  Future<List<DriverProfile>> getActiveDriversWithLocation() async {
    final response = await supabase
        .from('driver_profiles')
        .select('''
          *,
          users!inner (
            active
          )
        ''')
        .eq('users.active', true)
        .eq('is_on_duty', true)
        .not('latitude', 'is', null)
        .not('longitude', 'is', null);

    return response.map((data) => DriverProfile.fromJson(data)).toList();
  }

  Future<Trip> assignTripToDriver(String tripId, String driverId) async {
    final response =
        await supabase
            .from('trips')
            .update({'driver_id': driverId, 'status': 'in_progress'})
            .eq('id', tripId)
            .select()
            .single();
    return Trip.fromJson(response);
  }

  Future<List<Trip>> getPendingTrips() async {
    final response = await supabase
        .from('trips')
        .select('''
          *,
          driver_profiles (
            first_name,
            last_name,
            vehicle
          )
        ''')
        .eq('status', 'pending');

    return response.map((data) => Trip.fromJson(data)).toList();
  }

  Future<List<OperatorProfile>> getAllOperators() async {
    final response = await supabase
        .from('operator_profiles')
        .select('''
          *,
          users (
            id,
            phone_number,
            active
          )
        ''')
        .order('created_at', ascending: false);

    return response.map((data) => OperatorProfile.fromJson(data)).toList();
  }

  Future<Map<String, dynamic>> createOperator(
    Map<String, dynamic> operatorData,
  ) async {
    try {
      // Crear usuario
      final userData =
          await supabase
              .from('users')
              .insert({
                'phone_number': operatorData['phone_number'],
                'pin': operatorData['pin'],
                'role': 'operador',
                'active': true,
              })
              .select()
              .single();

      // Generar identity_card automáticamente
      final identityCard =
          'OP${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      // Crear perfil de operador
      final operatorProfile =
          await supabase
              .from('operator_profiles')
              .insert({
                'id': userData['id'],
                'first_name': operatorData['first_name'],
                'last_name': operatorData['last_name'],
                'identity_card': identityCard,
              })
              .select()
              .single();

      return {
        'success': true,
        'data': {...userData, 'operator_profile': operatorProfile},
      };
    } catch (e) {
      //print('Error en createOperator: $e');
      rethrow;
    }
  }

  Future<OperatorProfile> updateOperator(
    String operatorId,
    Map<String, dynamic> operatorData,
  ) async {
    // Actualizar perfil del operador
    final operatorUpdates = <String, dynamic>{
      if (operatorData.containsKey('first_name'))
        'first_name': operatorData['first_name'],
      if (operatorData.containsKey('last_name'))
        'last_name': operatorData['last_name'],
    };

    final response =
        await supabase
            .from('operator_profiles')
            .update(operatorUpdates)
            .eq('id', operatorId)
            .select()
            .single();

    // Actualizar usuario si hay cambios en phone_number o pin
    if (operatorData.containsKey('phone_number') ||
        operatorData.containsKey('pin')) {
      final userUpdates = <String, dynamic>{};
      if (operatorData.containsKey('phone_number')) {
        userUpdates['phone_number'] = operatorData['phone_number'];
      }
      if (operatorData.containsKey('pin')) {
        userUpdates['pin'] = operatorData['pin'];
      }

      await supabase.from('users').update(userUpdates).eq('id', operatorId);
    }

    return OperatorProfile.fromJson(response);
  }

  Future<List<Trip>> getOperatorTrips(String operatorId) async {
    try {
      final response = await supabase
          .from('trips')
          .select('*, driver_profiles(*)')
          .eq('operator_id', operatorId)
          .order('created_at', ascending: false);

      return (response as List).map((trip) => Trip.fromJson(trip)).toList();
    } catch (error) {
      developer.log('Error obteniendo viajes del operador: $error');
      throw Exception('No se pudieron cargar los viajes');
    }
  }

  Future<User> updateOperatorStatus(String operatorId, bool isActive) async {
    final response =
        await supabase
            .from('users')
            .update({'active': isActive})
            .eq('id', operatorId)
            .select()
            .single();
    return User.fromJson(response);
  }

  Future<void> deleteOperator(String operatorId) async {
    await supabase.from('users').update({'active': false}).eq('id', operatorId);
  }
}

class TripService {
  Future<Trip> createTrip(Map<String, dynamic> tripData) async {
    final response =
        await supabase.from('trips').insert(tripData).select().single();
    return Trip.fromJson(response);
  }

  Future<Trip> updateTripStatus(String tripId, TripStatus status) async {
    final updates = <String, dynamic>{'status': status.value};

    if (status == TripStatus.completed) {
      updates['completed_at'] = DateTime.now().toIso8601String();
    }

    final response =
        await supabase
            .from('trips')
            .update(updates)
            .eq('id', tripId)
            .select()
            .single();
    return Trip.fromJson(response);
  }

  Future<List<Trip>> getDriverTrips(String driverId) async {
    final response = await supabase
        .from('trips')
        .select('''
          id,
          status,
          price,
          origin,
          destination,
          created_at
        ''')
        .eq('driver_id', driverId)
        .filter('status', 'in', ['completed', 'cancelled'])
        .order('created_at', ascending: false);

    return response.map((data) => Trip.fromJson(data)).toList();
  }

  Future<List<Trip>> getOperatorTrips(String operatorId) async {
    try {
      // Obtener la fecha de inicio y fin del día actual
      final today = DateTime.now();
      final startOfDay =
          DateTime(today.year, today.month, today.day).toIso8601String();
      final endOfDay =
          DateTime(
            today.year,
            today.month,
            today.day,
            23,
            59,
            59,
            999,
          ).toIso8601String();

      // Obtener viajes
      final trips = await supabase
          .from('trips')
          .select('*, driver_profiles(*)')
          .eq('created_by', operatorId) // Cambiar operator_id por created_by
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay)
          .order('created_at', ascending: false);

      // Obtener solicitudes en broadcasting y expiradas
      final requests = await supabase
          .from('trip_requests')
          .select('*')
          .eq('created_by', operatorId)
          .or('status=broadcasting,status=expired,status=rejected')
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay)
          .order('created_at', ascending: false);

      // Convertir solicitudes a formato de Trip
      final List<Trip> tripRequests =
          (requests as List).map((req) {
            // Convertir request a formato de Trip
            return Trip.fromJson({
              ...req,
              'id': req['id'],
              'origin': req['origin'],
              'destination': req['destination'],
              'price': req['price'],
              'status': req['status'],
              'created_at': req['created_at'],
              'created_by': req['created_by'],
              'type': 'request',
            });
          }).toList();

      // Combinar y ordenar
      final List<Trip> allTrips = [
        ...tripRequests,
        ...(trips as List)
            .map((trip) => Trip.fromJson({...trip, 'type': 'trip'}))
            .toList(),
      ];

      // Ordenar por fecha de creación (más reciente primero)
      allTrips.sort(
        (a, b) =>
            DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt)),
      );

      return allTrips;
    } catch (error) {
      developer.log('Error obteniendo viajes del operador: $error');
      throw Exception('No se pudieron cargar los viajes');
    }
  }
}

class TripRequestService {
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000; // Radio de la Tierra en metros
    final phi1 = (lat1 * pi) / 180;
    final phi2 = (lat2 * pi) / 180;
    final deltaPhi = ((lat2 - lat1) * pi) / 180;
    final deltaLambda = ((lon2 - lon1) * pi) / 180;

    final a =
        sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c; // Distancia en metros
  }

  Future<TripRequest> createBroadcastRequest(
    Map<String, dynamic> requestData,
  ) async {
    try {
      // Primero crear la solicitud de viaje
      final tripRequest =
          await supabase
              .from('trip_requests')
              .insert({
                'created_by': requestData['operator_id'],
                'origin': requestData['origin'],
                'destination': requestData['destination'],
                'price': requestData['price'],
                'origin_lat': requestData['origin_lat'],
                'origin_lng': requestData['origin_lng'],
                'destination_lat': requestData['destination_lat'],
                'destination_lng': requestData['destination_lng'],
                'search_radius': requestData['search_radius'],
                'observations': requestData['observations'],
                'vehicle_type': requestData['vehicle_type'],
                'passenger_phone': requestData['passenger_phone'],
                'status': requestData['status'],
              })
              .select()
              .single();

      // Si hay paradas, insertarlas
      if (requestData['stops'] != null &&
          (requestData['stops'] as List).isNotEmpty) {
        final stopsToInsert =
            (requestData['stops'] as List).asMap().entries.map((entry) {
              final index = entry.key;
              final stop = entry.value;
              return {
                'trip_request_id': tripRequest['id'],
                'name': stop['name'],
                'latitude': stop['latitude'],
                'longitude': stop['longitude'],
                'order_index': index + 1,
              };
            }).toList();

        await supabase.from('trip_stops').insert(stopsToInsert);
      }

      return TripRequest.fromJson(tripRequest);
    } catch (e) {
      //print('Error creating broadcast request: $e');
      rethrow;
    }
  }

  Future<TripRequest> resendCancelledTrip(String tripId) async {
    try {
      // Primero verificar si es un viaje cancelado
      final trip =
          await supabase
              .from('trips')
              .select()
              .eq('id', tripId)
              .eq('status', 'cancelled')
              .maybeSingle();

      // Si encontramos un viaje cancelado
      if (trip != null) {
        // Crear nueva solicitud broadcasting directamente del viaje
        final newRequest =
            await supabase
                .from('trip_requests')
                .insert([
                  {
                    'created_by': trip['created_by'],
                    'origin': trip['origin'],
                    'destination': trip['destination'],
                    'origin_lat': trip['origin_lat'],
                    'origin_lng': trip['origin_lng'],
                    'destination_lat': trip['destination_lat'],
                    'destination_lng': trip['destination_lng'],
                    'price': trip['price'],
                    'status': 'broadcasting',
                    'vehicle_type': '4_ruedas', // Valor por defecto
                    'passenger_phone': trip['passenger_phone'],
                    'search_radius': 3000,
                    'current_radius': 3000,
                    'observations': trip['observations'] ?? '',
                    'notified_drivers': [],
                  },
                ])
                .select()
                .single();

        return TripRequest.fromJson(newRequest);
      }

      // Si no es un viaje, intentar como solicitud rechazada
      final request =
          await supabase
              .from('trip_requests')
              .select('''
            *,
            trip_stops (*)
          ''')
              .eq('id', tripId)
              .filter('status', 'in', ['rejected', 'expired'])
              .single();

      // Crear nueva solicitud broadcasting
      final newRequest =
          await supabase
              .from('trip_requests')
              .insert([
                {
                  'created_by': request['created_by'],
                  'origin': request['origin'],
                  'destination': request['destination'],
                  'origin_lat': request['origin_lat'],
                  'origin_lng': request['origin_lng'],
                  'destination_lat': request['destination_lat'],
                  'destination_lng': request['destination_lng'],
                  'price': request['price'],
                  'status': 'broadcasting',
                  'vehicle_type': request['vehicle_type'],
                  'passenger_phone': request['passenger_phone'],
                  'search_radius': request['search_radius'] ?? 3000,
                  'current_radius': request['search_radius'] ?? 3000,
                  'observations': request['observations'] ?? '',
                  'notified_drivers': [],
                },
              ])
              .select()
              .single();

      // Copiar las paradas si existen
      if (request['trip_stops'] != null &&
          (request['trip_stops'] as List).isNotEmpty) {
        final stopsToInsert =
            (request['trip_stops'] as List)
                .map(
                  (stop) => {
                    'trip_request_id': newRequest['id'],
                    'name': stop['name'],
                    'latitude': stop['latitude'],
                    'longitude': stop['longitude'],
                    'order_index': stop['order_index'],
                  },
                )
                .toList();

        await supabase.from('trip_stops').insert(stopsToInsert);
      }

      return TripRequest.fromJson(newRequest);
    } catch (e) {
      //print('Error en resendCancelledTrip: $e');
      rethrow;
    }
  }

  RealtimeChannel subscribeToDriverRequests(
    String driverId,
    Function(Map<String, dynamic>) onRequest,
    Function(dynamic) onError,
  ) {
    try {
      print('Configurando suscripción para conductor: $driverId');

      final channelName = 'driver_requests_$driverId';
      final channel = supabase.channel(channelName);

      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'trip_requests',
            callback: (payload) {
              print('Recibida nueva solicitud: ${payload.toString()}');

              // Verificar si es una solicitud en broadcasting
              if (payload.newRecord['status'] == 'broadcasting') {
                // Verificar si el conductor está dentro del radio de búsqueda
                final originLat = payload.newRecord['origin_lat'] as double;
                final originLng = payload.newRecord['origin_lng'] as double;
                final searchRadius =
                    payload.newRecord['search_radius'] as double;
                final vehicleType = payload.newRecord['vehicle_type'] as String;

                // Obtener la ubicación actual del conductor
                supabase
                    .from('driver_profiles')
                    .select()
                    .eq('id', driverId)
                    .single()
                    .then((driverData) {
                      if (driverData != null &&
                          driverData['latitude'] != null &&
                          driverData['longitude'] != null &&
                          driverData['vehicle_type'] == vehicleType) {
                        final driverLat = driverData['latitude'] as double;
                        final driverLng = driverData['longitude'] as double;

                        // Calcular distancia
                        final distance = calculateDistance(
                          originLat,
                          originLng,
                          driverLat,
                          driverLng,
                        );

                        // Si está dentro del radio, procesar la solicitud
                        if (distance <= searchRadius) {
                          onRequest(payload.newRecord);
                        }
                      }
                    });
              }
            },
          )
          .subscribe();

      return channel;
    } catch (e) {
      print('Error configurando suscripción: $e');
      onError(e);
      return supabase.channel('error_channel');
    }
  }

  void unsubscribeFromDriverRequests(RealtimeChannel channel) {
    try {
      //print('Cancelando suscripción a solicitudes');
      supabase.removeChannel(channel);
    } catch (e) {
      //print('Error removing request subscription: $e');
      try {
        channel.unsubscribe();
      } catch (e) {
        //print('Error en segundo intento de cancelación: $e');
      }
    }
  }

  Future<bool> attemptAcceptRequest(String requestId, String driverId) async {
    try {
      final result = await supabase.rpc(
        'attempt_accept_trip_request',
        params: {'p_request_id': requestId, 'p_driver_id': driverId},
      );
      return result as bool;
    } catch (e) {
      debugPrint('Error intentando aceptar solicitud: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> confirmRequestAcceptance(
    String requestId,
    String driverId,
  ) async {
    try {
      final result = await supabase.rpc(
        'confirm_trip_request_acceptance',
        params: {'p_request_id': requestId, 'p_driver_id': driverId},
      );

      return result;
    } catch (e) {
      // Si falla la confirmación, intentar liberar la solicitud
      await releaseRequest(requestId);
      debugPrint('Error confirmando aceptación: $e');
      rethrow;
    }
  }

  Future<void> releaseRequest(String requestId) async {
    try {
      await supabase.rpc(
        'release_trip_request',
        params: {'p_request_id': requestId},
      );
    } catch (e) {
      debugPrint('Error liberando solicitud: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> broadcastRequest(String requestId) async {
    try {
      // Primero obtener los detalles de la solicitud
      final request =
          await supabase
              .from('trip_requests')
              .select()
              .eq('id', requestId)
              .single();

      if (request.isEmpty) {
        throw Exception('Solicitud no encontrada');
      }

      // Obtener conductores especiales disponibles
      final specialDrivers = await supabase.rpc(
        'get_available_drivers_in_radius',
        params: {
          'p_request_id': requestId,
          'p_latitude': request['origin_lat'],
          'p_longitude': request['origin_lng'],
          'p_radius': request['search_radius'],
          'p_vehicle_type': request['vehicle_type'],
          'p_special_only': true,
        },
      );

      if ((specialDrivers as List).isNotEmpty) {
        // Actualizar la lista de conductores notificados
        final driverIds =
            (specialDrivers as List).map((d) => d['driver_id']).toList();
        await supabase
            .from('trip_requests')
            .update({
              'notified_drivers': [
                ...(request['notified_drivers'] ?? []),
                ...driverIds,
              ],
            })
            .eq('id', requestId);

        // Esperar 10 segundos antes de notificar al resto
        await Future.delayed(const Duration(seconds: 10));
      }

      // Obtener conductores regulares disponibles
      final regularDrivers = await supabase.rpc(
        'get_available_drivers_in_radius',
        params: {
          'p_request_id': requestId,
          'p_latitude': request['origin_lat'],
          'p_longitude': request['origin_lng'],
          'p_radius': request['search_radius'],
          'p_vehicle_type': request['vehicle_type'],
          'p_special_only': false,
        },
      );

      if ((regularDrivers as List).isNotEmpty) {
        // Actualizar la lista de conductores notificados
        final driverIds =
            (regularDrivers as List).map((d) => d['driver_id']).toList();
        await supabase
            .from('trip_requests')
            .update({
              'notified_drivers': [
                ...(request['notified_drivers'] ?? []),
                ...driverIds,
              ],
            })
            .eq('id', requestId);
      }

      return {
        'success': true,
        'specialDriversCount':
            specialDrivers != null ? (specialDrivers as List).length : 0,
        'regularDriversCount':
            regularDrivers != null ? (regularDrivers as List).length : 0,
      };
    } catch (e) {
      //print('Error broadcasting request: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> cancelBroadcastingRequest(
    String requestId,
  ) async {
    try {
      // Primero obtener la solicitud y sus paradas
      final request =
          await supabase
              .from('trip_requests')
              .select('''
        *,
        trip_stops (*)
      ''')
              .eq('id', requestId)
              .single();

      if (request['status'] != 'broadcasting') {
        throw Exception('Solo se pueden cancelar solicitudes en broadcasting');
      }

      // Crear un viaje cancelado para mantener el registro
      final trip =
          await supabase
              .from('trips')
              .insert({
                'created_by': request['created_by'],
                'origin': request['origin'],
                'destination': request['destination'],
                'origin_lat': request['origin_lat'],
                'origin_lng': request['origin_lng'],
                'destination_lat': request['destination_lat'],
                'destination_lng': request['destination_lng'],
                'price': request['price'],
                'status': 'cancelled',
                'passenger_phone': request['passenger_phone'],
                'cancellation_reason':
                    'Cancelado por operador durante broadcasting',
                'cancelled_at': DateTime.now().toIso8601String(),
              })
              .select()
              .single();

      // Crear una nueva solicitud rechazada que mantendrá las paradas
      final newRequest =
          await supabase
              .from('trip_requests')
              .insert({
                'created_by': request['created_by'],
                'origin': request['origin'],
                'destination': request['destination'],
                'origin_lat': request['origin_lat'],
                'origin_lng': request['origin_lng'],
                'destination_lat': request['destination_lat'],
                'destination_lng': request['destination_lng'],
                'price': request['price'],
                'status': 'rejected',
                'vehicle_type': request['vehicle_type'],
                'passenger_phone': request['passenger_phone'],
                'search_radius': request['search_radius'],
                'observations': request['observations'],
              })
              .select()
              .single();

      // Si la solicitud tenía paradas, crear nuevas paradas para la nueva solicitud
      if (request['trip_stops'] != null &&
          (request['trip_stops'] as List).isNotEmpty) {
        final stopsToInsert =
            (request['trip_stops'] as List)
                .map(
                  (stop) => {
                    'trip_request_id': newRequest['id'],
                    'name': stop['name'],
                    'latitude': stop['latitude'],
                    'longitude': stop['longitude'],
                    'order_index': stop['order_index'],
                  },
                )
                .toList();

        await supabase.from('trip_stops').insert(stopsToInsert);
      }

      // Actualizar el estado de la solicitud original a rejected
      await supabase
          .from('trip_requests')
          .update({'status': 'rejected'})
          .eq('id', requestId);

      return {
        ...trip,
        'trip_request_id': newRequest['id'],
        'trip_stops': request['trip_stops'],
      };
    } catch (e) {
      //print('Error cancelling broadcasting request: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> convertRequestToTrip(String requestId) async {
    try {
      // Primero obtenemos los datos de la solicitud para asegurarnos de tener el driver_id
      final request =
          await supabase
              .from('trip_requests')
              .select()
              .eq('id', requestId)
              .single();

      // Verificar que tenemos el driver_id
      if (request['driver_id'] == null) {
        throw Exception('La solicitud no tiene un conductor asignado');
      }

      // Llamar a la función de la base de datos con los datos completos
      final data = await supabase.rpc(
        'convert_request_to_trip',
        params: {'request_id': requestId},
      );

      // Asegurarnos que el phone_number se incluye en los datos devueltos
      return {
        ...data,
        'phone_number': request['phone_number'],
        'driver_id': request['driver_id'],
      };
    } catch (e) {
      //print('Error converting request to trip: $e');
      rethrow;
    }
  }

  RealtimeChannel subscribeToTripUpdates(
    String tripId,
    Function(Map<String, dynamic>) onUpdate,
    Function(dynamic) onError,
  ) {
    try {
      // Crear un nombre de canal único para este viaje
      final channelName =
          'trip_updates_${tripId}_${DateTime.now().millisecondsSinceEpoch}';

      final channel = supabase
          .channel(channelName)
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'trips',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: tripId,
            ),
            callback: (payload) {
              if (payload.newRecord != null) {
                onUpdate(payload.newRecord);
              }
            },
          )
          .subscribe((status, [error]) {
            if (status == RealtimeSubscribeStatus.subscribed) {
              //print('Suscripción exitosa al viaje $tripId');
            } else if (status == RealtimeSubscribeStatus.closed ||
                status == RealtimeSubscribeStatus.channelError) {
              onError(Exception('Error subscribing to trip updates: $status'));
            }
          });

      return channel;
    } catch (e) {
      //print('Error setting up subscription: $e');
      onError(e);
      // Devolver un canal vacío que podemos desuscribir de forma segura
      return supabase.channel('error_channel');
    }
  }

  void unsubscribeFromTripUpdates(RealtimeChannel channel) {
    try {
      //print('Cancelando suscripción al canal');
      supabase.removeChannel(channel);
    } catch (e) {
      //print('Error removing subscription: $e');
      // Intentar una segunda vez con un enfoque diferente
      try {
        channel.unsubscribe();
      } catch (innerError) {
        //print('Error en segundo intento de cancelación: $innerError');
      }
    }
  }

  Future<Map<String, dynamic>> cancelTrip(
    String tripId,
    String reason,
    String userId,
  ) async {
    try {
      // Primero verificar si el viaje existe y puede ser cancelado

      final data =
          await supabase
              .from('trips')
              .update({
                'status': 'cancelled',
                'cancellation_reason': reason,
                'cancelled_at': DateTime.now().toIso8601String(),
                'cancelled_by': userId,
              })
              .eq('id', tripId)
              .select()
              .single();

      return data;
    } catch (e) {
      debugPrint('Error cancelando viaje: $e');
      throw Exception('No se pudo cancelar el viaje: $e');
    }
  }

  RealtimeChannel subscribeToTripUpdatesForOperator(
    String operatorId,
    Function(Map<String, dynamic>) onUpdate,
    Function(dynamic) onError,
  ) {
    try {
      final channel = supabase
          .channel('operator_trips_$operatorId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'trips',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'created_by',
              value: operatorId,
            ),
            callback: (payload) {
              if (payload.newRecord != null) {
                onUpdate(payload.newRecord);
              }
            },
          )
          .subscribe((status, [error]) {
            if (status == RealtimeSubscribeStatus.subscribed) {
              //print('Suscripción exitosa a actualizaciones de viajes');
            } else if (status == RealtimeSubscribeStatus.closed ||
                status == RealtimeSubscribeStatus.channelError) {
              onError(Exception('Error en la suscripción'));
            }
          });

      return channel;
    } catch (e) {
      //print('Error al crear suscripción: $e');
      rethrow;
    }
  }

  Future<bool> updateTripStatus(
    String tripId,
    String status, [
    String? userId,
  ]) async {
    try {
      final Map<String, dynamic> updates = {'status': status};

      if (status == 'completed') {
        updates['completed_at'] = DateTime.now().toIso8601String();
      } else if (status == 'cancelled') {
        updates['cancelled_by'] = userId;
        updates['cancelled_at'] = DateTime.now().toIso8601String();
      }

      await supabase.from('trips').update(updates).eq('id', tripId);

      return true;
    } catch (e) {
      print('Error actualizando estado del viaje: $e');
      return false;
    }
  }
}

class AnalyticsService {
  Future<List<Trip>> getDriverStats(
    String driverId,
    String startDate,
    String endDate,
  ) async {
    final response = await supabase
        .from('trips')
        .select()
        .eq('driver_id', driverId)
        .eq('status', 'completed')
        .gte('created_at', startDate)
        .lte('created_at', endDate);

    return response.map((data) => Trip.fromJson(data)).toList();
  }

  Future<List<Trip>> getOperatorStats(
    String operatorId,
    String startDate,
    String endDate,
  ) async {
    final response = await supabase
        .from('trips')
        .select()
        .eq('operator_id', operatorId)
        .eq('status', 'completed')
        .gte('created_at', startDate)
        .lte('created_at', endDate);

    return response.map((data) => Trip.fromJson(data)).toList();
  }

  Future<double> getDailyRevenue(String date) async {
    final response = await supabase
        .from('trips')
        .select('price')
        .eq('status', 'completed')
        .gte('created_at', date)
        .lte('created_at', '$date 23:59:59');

    return response.fold<double>(
      0,
      (sum, trip) => sum + (trip['price'] as num).toDouble(),
    );
  }

  Future<Map<String, int>> getAdminDashboardStats() async {
    try {
      // Obtener la fecha de inicio (00:00:00) y fin (23:59:59) del día actual
      final today = DateTime.now();
      final startOfDay =
          DateTime(today.year, today.month, today.day).toIso8601String();
      final endOfDay =
          DateTime(
            today.year,
            today.month,
            today.day,
            23,
            59,
            59,
            999,
          ).toIso8601String();

      // Obtener viajes completados de hoy
      final tripsToday = await supabase
          .from('trips')
          .select('*')
          .eq('status', 'completed')
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay)
          .count(CountOption.exact);

      // Obtener choferes activos
      final activeDrivers = await supabase
          .from('driver_profiles')
          .select('''
            *,
            users!inner (*)
          ''')
          .eq('users.active', true)
          .eq('is_on_duty', true)
          .count(CountOption.exact);

      // Obtener total de usuarios
      final totalUsers = await supabase
          .from('users')
          .select('*')
          .eq('active', true)
          .count(CountOption.exact);

      return {
        'tripsToday': tripsToday.count,
        'activeDrivers': activeDrivers.count,
        'totalUsers': totalUsers.count,
      };
    } catch (e) {
      //print('Error fetching dashboard stats: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getDriverTripStats(
    String driverId,
    String timeFrame,
  ) async {
    try {
      // Calcular fechas correctamente
      final now = DateTime.now();
      DateTime startDate;

      switch (timeFrame) {
        case 'day':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'week':
          startDate = DateTime(now.year, now.month, now.day - 7);
          break;
        case 'month':
          startDate = DateTime(now.year, now.month - 1, now.day);
          break;
        default:
          startDate = DateTime(now.year, now.month, now.day);
      }

      // Consulta con filtros de fecha
      final trips = await supabase
          .from('trips')
          .select()
          .eq('driver_id', driverId)
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', now.toIso8601String());

      // Consulta del perfil del conductor activo
      final driver =
          await supabase
              .from('driver_profiles')
              .select('''
            *,
            users!inner (*)
          ''')
              .eq('id', driverId)
              .eq('users.active', true)
              .single();

      // Calcular estadísticas
      final totalTrips = trips.length;
      final totalEarnings = trips.fold<double>(
        0,
        (sum, trip) => sum + ((trip['price'] as num?)?.toDouble() ?? 0),
      );
      final balance = (driver['balance'] as num?)?.toDouble() ?? 0.0;

      return {
        'totalTrips': totalTrips,
        'totalEarnings': totalEarnings,
        'balance': balance,
      };
    } catch (e) {
      //print('Error en getDriverTripStats: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCompletedTrips({
    String? startDate,
    String? endDate,
    String? driverId,
    String? operatorId,
  }) async {
    try {
      // Primero hacer la consulta básica sin filtros
      var query = supabase
          .from('trips')
          .select('''
            *,
            driver_profiles (
              id,
              first_name,
              last_name
            ),
            users!created_by (
              id,
              role,
              operator_profiles (
                first_name,
                last_name
              )
            )
          ''')
          .eq('status', 'completed');

      // Luego aplicar los filtros
      if (startDate != null) {
        query = query.gte('created_at', startDate);
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate);
      }
      if (driverId != null) {
        query = query.eq('driver_id', driverId);
      }
      if (operatorId != null) {
        query = query.eq('created_by', operatorId);
      }

      // Ejecutar la consulta con el orden
      final response = await query.order('created_at', ascending: false);

      // Transformar los datos para mantener la estructura esperada
      return response
          .map(
            (trip) => {
              ...trip,
              'operator_profiles': trip['users']?['operator_profiles'],
            },
          )
          .toList();
    } catch (e) {
      //print('Error en getCompletedTrips: $e');
      rethrow;
    }
  }

  Future<String> getAddressFromCoords(double latitude, double longitude) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&addressdetails=1',
        ),
        headers: {'User-Agent': 'TaxiApp/1.0'},
      );

      final data = jsonDecode(response.body);
      return data['display_name'] ?? '$latitude, $longitude';
    } catch (e) {
      developer.log('Error getting address: $e');
      return '$latitude, $longitude';
    }
  }

  Future<List<Map<String, dynamic>>> searchLocations(String query) async {
    if (query.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&countrycodes=cu&limit=5',
        ),
        headers: {'User-Agent': 'TaxiApp/1.0'},
      );

      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      developer.log('Error searching locations: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getOperatorCompletedTrips(
    String startDate,
    String endDate,
    String? operatorId,
  ) async {
    var query = supabase
        .from('trips')
        .select('''
          *,
          driver_profiles (
            id,
            first_name,
            last_name
          ),
          users!created_by (
            id,
            role,
            operator_profiles (
              first_name,
              last_name
            )
          )
        ''')
        .eq('status', 'completed')
        .gte('created_at', startDate)
        .lte('created_at', endDate);

    if (operatorId != null) {
      query = query.eq('created_by', operatorId);
    }

    final response = await query.order('created_at', ascending: false);

    // Transformar los datos para mantener la estructura esperada
    final transformedData =
        response
            .map(
              (trip) => {
                ...trip,
                'operator_profiles': trip['users']?['operator_profiles'],
              },
            )
            .toList();

    return transformedData;
  }
}

Future<Map<String, dynamic>> loginUser(String phoneNumber, String pin) async {
  try {
    final userData =
        await supabase
            .from('users')
            .select('''
          *,
          driver_profiles(*),
          operator_profiles(*)
        ''')
            .eq('phone_number', phoneNumber)
            .eq('pin', pin)
            .eq('active', true)
            .single();

    return userData;
  } catch (e) {
    developer.log('Error en loginUser: $e');
    throw Exception('Credenciales inválidas');
  }
}
