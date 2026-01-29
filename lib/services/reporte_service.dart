import 'package:dio/dio.dart';
import '../models/reporte_model.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ReporteService {
  final Dio _dio = Dio();
  
  // 1. CONFIGURACIÓN CENTRALIZADA (Cambiá esto si tu IP cambia)
  // Usamos la .36 que es la que te funcionó para el Login
  final String baseUrl = 'https://leyenda-vial-backend-production.up.railway.app'; 

  // --- OBTENER REPORTES (Para dibujar el mapa) ---
  Future<List<Reporte>> getReportes() async {
    try {
      // Usamos la variable baseUrl para no equivocarnos de IP
      final response = await _dio.get('$baseUrl/reportes');
      
      List<dynamic> data = response.data;
      return data.map((json) => Reporte.fromJson(json)).toList();
    } catch (e) {
      print("Error trayendo reportes: $e");
      return []; 
    }
  }

  // --- CREAR NUEVO REPORTE (Con control de ID y límites) ---
  Future<Map<String, dynamic>> crearReporte(String codigo, double lat, double lng) async {
    try {
      // 2. RECUPERAR EL ID DEL USUARIO (La Cédula) 🆔
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');

      // Seguridad: Si no hay usuario guardado, no dejamos enviar
      if (userId == null) {
        return {
          "status": "error", 
          "mensaje": "Error de sesión: Reiniciá la app."
        };
      }

      var url = Uri.parse("$baseUrl/reportes"); 
      
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "type_code": codigo,
          "description": "Reporte desde App",
          "latitud": lat,
          "longitud": lng,
          "user_id": userId // <--- 3. CLAVE: Enviamos quiénes somos
        }),
      );

      if (response.statusCode == 200) {
        // Devuelve lo que diga Python ("Creado", "Confirmado" o "Tanque Vacío")
        return jsonDecode(response.body); 
      } else {
        // Intentamos leer el mensaje de error si Python nos frenó (ej: límite alcanzado)
        try {
           return jsonDecode(response.body);
        } catch (_) {
           return {"status": "error", "mensaje": "Error en el servidor"};
        }
      }
    } catch (e) {
      return {"status": "error", "mensaje": "Error de conexión: $e"};
    }
  }

  // Función para VOTAR (Confirmar o Borrar)
  Future<Map<String, dynamic>> votarReporte(String reporteId, String tipoVoto) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');
      if (userId == null) return {"status": "error", "mensaje": "Error de sesión"};

      var url = Uri.parse("$baseUrl/reportes/votar");
      
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "reporte_id": reporteId, // <--- Ahora enviamos String directo
          "tipo_voto": tipoVoto 
        })
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try { return jsonDecode(response.body); } catch (_) { return {"status": "error", "mensaje": "Error servidor"}; }
      }
    } catch (e) {
      return {"status": "error", "mensaje": "Error conexión: $e"};
    }
  }
}