import 'dart:convert';
import 'package:http/http.dart' as http;

// Clase modelo para los puntos (Hospitales, Talleres, etc.)
class PuntoFijo {
  final String id;
  final String nombre;
  final String tipo; // "hospital", "taller", "comisaria", "legal"
  final double lat;
  final double lng;
  final String direccion;
  final String telefono;
  final String horario;

  PuntoFijo({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.lat,
    required this.lng,
    this.direccion = "Dirección no disponible",
    this.telefono = "Sin teléfono",
    this.horario = "24 hs",
  });
}

class PuntosService {
  // ⚠️ IMPORTANTE: Chequeá tu IP con ipconfig. 
  // Si ayer era .71 y hoy es .36, tenés que cambiarlo acá.
  final String baseUrl = "https://leyenda-vial-backend-production.up.railway.app"; 

  Future<List<PuntoFijo>> getPuntosFijos() async {
    print("🚚 SOLICITANDO PUNTOS AL SERVIDOR..."); // <--- CHISMOSO 1
    try {
      var url = Uri.parse("$baseUrl/puntos-fijos");
      var response = await http.get(url);

      print("📨 RESPUESTA CÓDIGO: ${response.statusCode}"); // <--- CHISMOSO 2

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        print("✅ PUNTOS RECIBIDOS: ${data.length}"); // <--- CHISMOSO 3: ¿Cuántos llegaron?
        print("📦 DATOS: $data"); // <--- CHISMOSO 4: Ver el JSON crudo
        
        return data.map((json) => PuntoFijo(
          id: json['id'],
          nombre: json['nombre'],
          tipo: json['tipo'],
          lat: json['latitud'], 
          lng: json['longitud'],
          direccion: json['direccion'] ?? "Sin dirección",
          telefono: json['telefono'] ?? "Sin teléfono",
          horario: json['horario'] ?? "Sin horario"
        )).toList();
      } else {
        print("❌ ERROR SERVIDOR: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("🔥 ERROR DE CONEXIÓN: $e"); // <--- IMPORTANTE: Si sale esto, es la IP
      return [];
    }
  }
}