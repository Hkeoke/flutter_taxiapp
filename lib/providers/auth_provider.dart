import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../services/auth_service.dart' as auth_service;
import '../services/api.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _loading = true;
  final auth_service.AuthService _authService = auth_service.authService;

  User? get user => _user;
  bool get loading => _loading;

  AuthProvider() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      _loading = true;
      notifyListeners();

      _user = await _authService.loadUserFromStorage();
    } catch (e) {
      developer.log('Error cargando usuario: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Método público para verificar/refrescar el estado de autenticación
  Future<void> checkAuthStatus() async {
    await _loadUser();
  }

  Future<void> login(String phoneNumber, String pin) async {
    try {
      _loading = true;
      notifyListeners();

      final userData = await _authService.login(phoneNumber, pin);

      // Verificar si es un chofer y está activo
      if (userData.role == 'chofer' && !userData.active) {
        throw Exception('Cuenta de chofer inactiva');
      }

      await _authService.updateUser(userData);
      _user = userData;
    } catch (e) {
      developer.log('Error en login: $e');
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      _loading = true;
      notifyListeners();

      await _authService.logout();
      _user = null;
    } catch (e) {
      developer.log('Error en logout: $e');
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
