import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _cargando = false;

  // --- LÓGICA DE SUSCRIPCIÓN (Mes Gratis) ---
  Future<void> _iniciarSuscripcion() async {
    setState(() => _cargando = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');
      String? email = prefs.getString('email'); 

      // 1. Pedimos el LINK al Backend
      var url = Uri.parse("https://leyenda-vial-backend-production.up.railway.app/crear-suscripcion"); 
      
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "email": email 
        })
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        String linkPago = data['init_point'];

        // 2. Abrimos MercadoPago
        final Uri uri = Uri.parse(linkPago);

        try {
          bool lanzado = await launchUrl(
            uri, 
            mode: LaunchMode.externalNonBrowserApplication,
          );
          
          if (!lanzado) {
            throw 'No se pudo abrir la app nativa';
          }
        } catch (e) {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            _mostrarError("No se pudo abrir el enlace de pago.");
          }
        }
      } else {
        _mostrarError("Error del servidor: No se pudo iniciar la suscripción.");
      }
    } catch (e) {
      _mostrarError("Error de conexión: Asegurate que el servidor esté corriendo.");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fondo degradado
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [const Color(0xFF00FF99).withOpacity(0.2), Colors.black],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Botón cerrar
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  const Icon(Icons.diamond, size: 80, color: Color(0xFF00FF99)),
                  const SizedBox(height: 20),
                  
                  // Títulos Grandes (Estilo Anterior)
                  const Text("Seguridad Vial PREMIUM", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  const Text("Eliminá los límites y ayudá sin parar.", style: TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
                  
                  const SizedBox(height: 40),
                  
                  // BENEFICIOS (Volvimos a agregar "Sin Publicidad")
                  _beneficio(Icons.bolt, "Reportes Ilimitados", "Olvidate del límite de 3 diarios."),
                  _beneficio(Icons.block, "Sin Publicidad", "Navegá el mapa sin interrupciones."), // <--- RECUPERADO
                  _beneficio(Icons.star, "Insignia Dorada", "Destacate en la comunidad."),
                  
                  const Spacer(),
                  
                  // BOTÓN GRANDE
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF99), foregroundColor: Colors.black),
                      onPressed: _cargando ? null : _iniciarSuscripcion,
                      child: _cargando 
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text("SUSCRIBIRSE • \$2.500/MES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text("Suscripción mensual automática. Cancelá cuando quieras.", style: TextStyle(color: Colors.white30, fontSize: 10), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar de diseño
  Widget _beneficio(IconData icon, String titulo, String sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: const Color(0xFF00FF99), size: 30),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(sub, style: const TextStyle(color: Colors.white54, fontSize: 14)),
              ],
            ),
          )
        ],
      ),
    );
  }
}