import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'info_screen.dart'; 

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  String _seleccionado = "auto"; 
  final TextEditingController _patenteController = TextEditingController();
  final TextEditingController _modeloController = TextEditingController();
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosBackend();
  }

  // Carga los datos reales de la Base de Datos
  Future<void> _cargarDatosBackend() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id');
    
    // Leemos local primero para mostrar rápido el ícono
    setState(() {
      _seleccionado = prefs.getString('vehiculo') ?? 'auto';
    });

    if (userId == null) return;

    try {
      // Tu IP aquí
      var url = Uri.parse("https://leyenda-vial-backend-production.up.railway.app/usuarios/$userId");
      var response = await http.get(url);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          _seleccionado = data['vehicle_type'] ?? 'auto';
          _patenteController.text = data['patente'] ?? '';
          _modeloController.text = data['modelo'] ?? '';
          _cargando = false;
        });
        // Sincronizamos localmente también
        await prefs.setString('vehiculo', _seleccionado);
      }
    } catch (e) {
      print("Error cargando vehículo: $e");
      setState(() => _cargando = false);
    }
  }

  Future<void> _guardarTodo() async {
    setState(() => _guardando = true);
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id');
    
    // Guardamos local
    await prefs.setString('vehiculo', _seleccionado);

    // Enviamos a Python
    try {
      var url = Uri.parse("https://leyenda-vial-backend-production.up.railway.app/usuarios/vehiculo");
      var response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId, 
          "vehiculo": _seleccionado,
          "patente": _patenteController.text,
          "modelo": _modeloController.text
        })
      );

      if (response.statusCode == 200) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("✅ Datos guardados correctamente"), backgroundColor: Color(0xFF00FF99))
         );
      } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al guardar en la nube")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error de conexión: $e")));
    }

    setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Mi Vehículo", style: TextStyle(color: Colors.white)),
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
                  const Text("TIPO DE VEHÍCULO", style: TextStyle(color: Color(0xFF00FF99), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 20),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _opcionVehiculo("auto", Icons.directions_car, "Auto"),
                      _opcionVehiculo("moto", Icons.two_wheeler, "Moto"),
                      _opcionVehiculo("bici", Icons.pedal_bike, "Bici"),
                    ],
                  ),

                  const SizedBox(height: 30),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 20),

                  const Text("DOCUMENTACIÓN (OPCIONAL)", style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.5)),
                  const SizedBox(height: 15),

                  _campoTexto("Modelo / Marca", Icons.branding_watermark, _modeloController),
                  const SizedBox(height: 15),
                  _campoTexto("Patente", Icons.pin_invoke, _patenteController),

                  const SizedBox(height: 25),

                  // BOTÓN GUARDAR
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF99),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                      ),
                      onPressed: _guardando ? null : _guardarTodo,
                      child: _guardando 
                        ? const CircularProgressIndicator(color: Colors.black) 
                        : const Text("GUARDAR DATOS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),

                  const SizedBox(height: 30),
                  
                  // TARJETA DE DERECHOS
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.withOpacity(0.3))
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.gavel, color: Colors.amber),
                            SizedBox(width: 10),
                            Text("TUS DERECHOS Y OBLIGACIONES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Consultá la documentación específica para ${_seleccionado.toUpperCase()} según la Ley Nacional de Tránsito Argentina.",
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.amber)),
                            onPressed: () {
                               // Pasamos el vehículo seleccionado para que InfoScreen abra la pestaña correcta
                               Navigator.push(context, MaterialPageRoute(builder: (context) => InfoScreen(vehiculoInicial: _seleccionado)));
                            },
                            child: const Text("Ver Leyes y Multas", style: TextStyle(color: Colors.amber)),
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
    );
  }
  
  // ... (Los widgets _opcionVehiculo y _campoTexto son los mismos de antes)
  Widget _opcionVehiculo(String key, IconData icono, String titulo) {
    bool activo = _seleccionado == key;
    return GestureDetector(
      onTap: () => setState(() => _seleccionado = key), // Solo visual hasta que toque Guardar
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: activo ? const Color(0xFF00FF99) : Colors.white10,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: activo ? const Color(0xFF00FF99) : Colors.transparent)
        ),
        child: Column(
          children: [
            Icon(icono, color: activo ? Colors.black : Colors.white54, size: 40),
            const SizedBox(height: 10),
            Text(titulo, style: TextStyle(color: activo ? Colors.black : Colors.white54, fontWeight: FontWeight.bold))
          ],
        ),
      ),
    );
  }

  Widget _campoTexto(String label, IconData icono, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icono, color: Colors.white54),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }
}