import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

class AuthService {
  static const String USER_STORAGE_KEY = 'user_data';

  // Cargar usuario desde almacenamiento local
  Future<User?> loadUserFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString(USER_STORAGE_KEY);

      if (userString != null) {
        final userData = json.decode(userString);
        return User.fromJson(userData);
      }
      return null;
    } catch (e) {
      developer.log('Error cargando usuario del storage: $e');
      return null;
    }
  }

  // Actualizar usuario en almacenamiento
  Future<void> updateUser(User? user) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (user != null) {
        await prefs.setString(USER_STORAGE_KEY, json.encode(user.toJson()));
      } else {
        await prefs.remove(USER_STORAGE_KEY);
      }
    } catch (e) {
      developer.log('Error actualizando usuario: $e');
      rethrow;
    }
  }

  // Iniciar sesión usando el servicio de API
  Future<User> login(String phoneNumber, String pin) async {
    try {
      final userData = await loginUser(phoneNumber, pin);
      return User.fromJson(userData);
    } catch (e) {
      developer.log('Error en login: $e');
      throw Exception('Credenciales inválidas');
    }
  }

  // Cerrar sesión
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(USER_STORAGE_KEY);
    } catch (e) {
      developer.log('Error durante logout: $e');
      rethrow;
    }
  }
}

final authService = AuthService();
