import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controladores básicos
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  
  // Ubicación
  String? _provinciaSeleccionada;
  final TextEditingController _localidadController = TextEditingController();

  // LISTA ORDENADA ALFABÉTICAMENTE (Mendoza queda en el medio)
  final List<String> _provincias = [
    "Buenos Aires", "CABA", "Catamarca", "Chaco", "Chubut", "Córdoba", 
    "Corrientes", "Entre Ríos", "Formosa", "Jujuy", "La Pampa", "La Rioja", 
    "Mendoza", "Misiones", "Neuquén", "Río Negro", "Salta", "San Juan", 
    "San Luis", "Santa Cruz", "Santa Fe", "Santiago del Estero", 
    "Tierra del Fuego", "Tucumán"
  ];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // TRUCO: Pre-seleccionamos Mendoza para ahorrarte el click 😉
    _provinciaSeleccionada = "Mendoza";
  }

  Future<void> _registrar() async {
    // 1. OBTENEMOS DATOS LIMPIOS
    String u = _userController.text.trim();
    String e = _emailController.text.trim();
    String p = _passController.text.trim();
    String l = _localidadController.text.trim();

    // 2. VALIDACIONES DE SEGURIDAD 🛡️
    
    // A. Vacíos
    if (u.isEmpty || e.isEmpty || p.isEmpty || l.isEmpty || _provinciaSeleccionada == null) {
      _mostrarSnack("Por favor completá todos los datos", Colors.orange);
      return;
    }

    // B. Formato Email
    if (!e.contains('@') || !e.contains('.')) {
      _mostrarSnack("El email no es válido (ej: pepe@gmail.com)", Colors.orange);
      return;
    }

    // C. Contraseña Segura
    if (p.length < 6) {
      _mostrarSnack("La contraseña debe tener al menos 6 caracteres", Colors.orange);
      return;
    }

    // 3. CONEXIÓN
    setState(() => _isLoading = true);

    try {
      // USAMOS TU IP REAL (Para que funcione siempre)
      var url = Uri.parse("https://leyenda-vial-backend-production.up.railway.app/registro");

      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": u,
          "email": e,
          "password": p,
          "provincia": _provinciaSeleccionada,
          "localidad": l
        }),
      );

      if (response.statusCode == 200) {
        _mostrarSnack("¡Cuenta creada! Bienvenido 🛡️", const Color(0xFF00FF99));
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context); // Volvemos al Login

      } else {
        var errorData = jsonDecode(response.body);
        _mostrarSnack(errorData['detail'] ?? "Error al registrarse", Colors.red);
      }
    } catch (e) {
      _mostrarSnack("Error de conexión: Revisá que Python esté corriendo.", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      backgroundColor: color,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final Color neonGreen = const Color(0xFF00FF99);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_add_outlined, size: 60, color: Colors.white),
              const SizedBox(height: 10),
              Text("NUEVA CUENTA", style: TextStyle(color: neonGreen, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 30),

              _crearInput(_userController, "Usuario", Icons.person, neonGreen),
              const SizedBox(height: 15),
              _crearInput(_emailController, "Email", Icons.email, neonGreen),
              const SizedBox(height: 15),
              _crearInput(_passController, "Contraseña (+6 caracteres)", Icons.lock, neonGreen, isPassword: true),
              const SizedBox(height: 15),

              // SELECTOR MEJORADO 🗺️
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: "Provincia",
                  prefixIcon: const Icon(Icons.map, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.black38,
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: neonGreen), borderRadius: BorderRadius.circular(12)),
                  labelStyle: const TextStyle(color: Colors.white70),
                ),
                dropdownColor: Colors.grey[800], // Un gris un pelín más claro para el menú
                style: const TextStyle(color: Colors.white),
                value: _provinciaSeleccionada,
                items: _provincias.map((String prov) {
                  return DropdownMenuItem<String>(
                    value: prov,
                    child: Text(prov),
                  );
                }).toList(),
                onChanged: (newValue) => setState(() => _provinciaSeleccionada = newValue),
              ),
              const SizedBox(height: 15),

              _crearInput(_localidadController, "Localidad", Icons.location_city, neonGreen),
              
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registrar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: neonGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.black) 
                    : const Text("REGISTRARME", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _crearInput(TextEditingController controller, String label, IconData icon, Color color, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: color), borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[900],
      ),
    );
  }
}