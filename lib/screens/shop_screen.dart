import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'premium_screen.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _puntos = 0;
  String _userId = "";

  String _token = "";

  bool _isPremium = false; // Agregamos esto para saber si ya compró
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _puntos = prefs.getInt('reputation') ?? 0;
      _userId = prefs.getString('user_id') ?? "";
      _token = prefs.getString('token') ?? "";
      _isPremium = prefs.getBool('is_premium') ?? false;
      _cargando = false;
    });
  }

  // --- 1. LÓGICA DE CANJE POR PUNTOS (Backend) ---
  Future<void> _canjearPack(int costo, int cantidad) async {
    if (_puntos < costo) {
      _mostrarError("❌ No te alcanzan los puntos");
      return;
    }

    setState(() => _cargando = true);

    try {
      // Usamos 127.0.0.1 gracias a tu comando ADB REVERSE
      var url = Uri.parse("https://leyenda-vial-backend-production.up.railway.app/canjear-puntos");
      var response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_token"
        },
        body: jsonEncode({
          "user_id": _userId,
          "costo_puntos": costo,
          "cantidad_reportes": cantidad
        })
      );

      var data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        _actualizarSaldoLocal(data['nuevo_saldo']);
        _mostrarExito("¡Recarga Exitosa! ⛽", "Canjeaste $cantidad reportes extra.");
      } else {
        _mostrarError(data['mensaje']);
      }
    } catch (e) {
      _mostrarError("Error de conexión: $e");
    } finally {
      setState(() => _cargando = false);
    }
  }

  // --- 2. LÓGICA DE COMPRA PREMIUM POR PUNTOS ---
  Future<void> _canjearPremiumPuntos(int costo) async {
    if (_puntos < costo) {
       _mostrarError("❌ Te faltan puntos. ¡Seguí reportando! 💪");
       return;
    }
    
    setState(() => _cargando = true);
    
    try {
      var url = Uri.parse("https://leyenda-vial-backend-production.up.railway.app/canjear-premium");
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({ "user_id": _userId, "costo_puntos": costo })
      );
      
      var data = jsonDecode(response.body);
      
      if (data['status'] == 'success') {
         await _activarPremiumLocalmente();
         _actualizarSaldoLocal(data['nuevo_saldo']);
         _mostrarExito("¡BIENVENIDO AL CLUB! 💎", "Disfrutá tus beneficios VIP.");
      } else {
        _mostrarError(data['mensaje']);
      }
    } catch (e) {
      _mostrarError("Error de conexión");
    } finally {
      setState(() => _cargando = false);
    }
  }

  // --- 3. SIMULACIÓN DE PAGO REAL (MERCADOPAGO) 💳 ---
  Future<void> _pagarConDineroReal() async {
    setState(() => _cargando = true);
    
    // A. Simular espera bancaria (Suspenso...)
    await Future.delayed(const Duration(seconds: 3));

    // B. Simular llamada al Backend para activar (Usamos el truco de costo 0)
    try {
       var url = Uri.parse("https://leyenda-vial-backend-production.up.railway.app/canjear-premium"); 
       // Le mandamos costo 0 porque "ya pagó" con tarjeta
       var response = await http.post(url, headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": _userId, "costo_puntos": 0}) 
       );

       if (response.statusCode == 200) {
         await _activarPremiumLocalmente();
         _mostrarExito("¡PAGO APROBADO! ✅", "Gracias por suscribirte a Leyenda Vial.");
       } else {
         _mostrarError("Hubo un problema procesando el pago.");
       }
    } catch (e) {
      _mostrarError("Error de conexión con el banco.");
    } finally {
      setState(() => _cargando = false);
    }
  }

  // --- AUXILIARES ---
  Future<void> _actualizarSaldoLocal(int nuevosPuntos) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reputation', nuevosPuntos);
    setState(() => _puntos = nuevosPuntos);
  }

  Future<void> _activarPremiumLocalmente() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', true);
    setState(() => _isPremium = true);
  }

  void _mostrarExito(String titulo, String mensaje) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text(titulo, style: const TextStyle(color: Color(0xFF00FF99))),
      content: Text(mensaje, style: const TextStyle(color: Colors.white)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("GENIAL"))],
    ));
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Tienda de Puntos", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _cargando 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF99)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TARJETA DE SALDO
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.blueGrey[900]!, Colors.black]),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF00FF99).withOpacity(0.5))
                    ),
                    child: Column(
                      children: [
                        const Text("TU SALDO ACTUAL", style: TextStyle(color: Colors.white54, letterSpacing: 2)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.stars, color: Color(0xFF00FF99), size: 30),
                            const SizedBox(width: 10),
                            Text("$_puntos", style: const TextStyle(color: Color(0xFF00FF99), fontSize: 40, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  const Text("CANJES (Usar Puntos)", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),

                  _itemTienda(
                    titulo: "Recarga Express",
                    subtitulo: "+1 Reporte extra hoy",
                    costo: 50,
                    icon: Icons.local_gas_station,
                    onTap: () => _canjearPack(50, 1),
                  ),

                  _itemTienda(
                    titulo: "Tanque Lleno",
                    subtitulo: "+3 Reportes extra hoy",
                    costo: 120,
                    icon: Icons.ev_station,
                    esOferta: true,
                    onTap: () => _canjearPack(120, 3),
                  ),

                  // OPCIÓN PREMIUM POR PUNTOS
                  _itemTienda(
                    titulo: "Semana Premium",
                    subtitulo: "Prueba los beneficios VIP",
                    costo: 1000,
                    icon: Icons.diamond,
                    colorIcono: Colors.amber,
                    onTap: () => _canjearPremiumPuntos(1000),
                    desactivado: _isPremium
                  ),

                  const SizedBox(height: 30),
                  const Text("SUSCRIPCIONES (Dinero Real)", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),

                  // TARJETA SUSCRIPCIÓN MENSUAL (Simulación MercadoPago) 💳
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.amber, width: 1),
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.amber.withOpacity(0.1)
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(15),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.workspace_premium, color: Colors.amber, size: 30),
                      ),
                      title: const Text("HAZTE LEYENDA (Mensual)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Soporte prioritario, Icono Dorado y Cero Límites.", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                        onPressed: _isPremium
                            ? null
                            : () {
                              Navigator.push(
                                context, 
                                MaterialPageRoute(builder: (context) => const PremiumScreen())
                              ).then((_) { 
                                _cargarDatos(); // Al volver, recargamos para ver si compró
                              });
                          },
                        child: Text(_isPremium ? "ACTIVO" : "VER PLAN"), // Cambié el texto para invitar a ver
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  const Center(child: Text("Pagos procesados de forma segura vía MercadoPago", style: TextStyle(color: Colors.white24, fontSize: 10))),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _itemTienda({
    required String titulo, 
    required String subtitulo, 
    required int costo, 
    required IconData icon, 
    required VoidCallback onTap,
    bool esOferta = false,
    bool desactivado = false,
    Color colorIcono = Colors.white,
  }) {
    return GestureDetector(
      onTap: desactivado ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(15),
          border: esOferta ? Border.all(color: Colors.amber) : null
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: desactivado ? Colors.grey : (esOferta ? Colors.amber : colorIcono), size: 30),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: TextStyle(color: desactivado ? Colors.grey : (esOferta ? Colors.amber : Colors.white), fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitulo, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: desactivado ? Colors.white10 : (esOferta ? Colors.amber : Colors.white24),
                borderRadius: BorderRadius.circular(20)
              ),
              child: Text(
                desactivado ? "YA TENÉS" : "$costo Pts", 
                style: TextStyle(
                  color: desactivado ? Colors.white30 : (esOferta ? Colors.black : Colors.white), 
                  fontWeight: FontWeight.bold
                )
              ),
            )
          ],
        ),
      ),
    );
  }
}