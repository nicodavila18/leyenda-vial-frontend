import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  // 1. La caja fuerte (Para datos sensibles)
  final _secureStorage = const FlutterSecureStorage();

  // 2. Guardar Sesión (Token + Datos básicos)
  Future<void> guardarSesion({
    required String token, 
    required String userId, 
    required String username,
    required String email,
    required int reputation
  }) async {
    // El TOKEN va a la caja fuerte
    await _secureStorage.write(key: 'auth_token', value: token);
    
    // Los datos públicos van a SharedPrefs (es más rápido para la UI)
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('username', username);
    await prefs.setString('email', email);
    await prefs.setInt('reputation', reputation);
  }

  // 3. Obtener Token (Para cuando hagas peticiones a Python)
  Future<String?> getToken() async {
    return await _secureStorage.read(key: 'auth_token');
  }

  // 4. Cerrar Sesión (Borrar todo)
  Future<void> borrarSesion() async {
    await _secureStorage.deleteAll(); // Borra claves
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Borra datos públicos
  }
}