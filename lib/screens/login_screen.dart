import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'map_screen.dart';
import 'register_screen.dart';
import '../services/storage_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    // LIMPIAMOS ESPACIOS EN BLANCO
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _mostrarSnack("Por favor completá usuario y contraseña", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // IP UNIFICADA
      var url = Uri.parse("https://leyenda-vial-backend-production.up.railway.app/login"); 
      
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({ "email": email, "password": password }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        
        // --- GUARDAMOS LA SESIÓN CON EL TOKEN ---
        await StorageService().guardarSesion(
          token: data['access_token'], // <--- AHORA GUARDAMOS EL TOKEN REAL
          userId: data['user_id'],
          username: data['username'],
          email: email,
          reputation: data['reputation']
        );

        if (mounted) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MapScreen()));
        }
      } else {
        var errorData = jsonDecode(response.body);
        _mostrarSnack(errorData['detail'] ?? "Credenciales incorrectas", Colors.red);
      }
    } catch (e) {
      _mostrarSnack("No se pudo conectar al servidor.", Colors.red);
      print("Error Login: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final Color neonGreen = const Color(0xFF00FF99);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. LOGO E IDENTIDAD
              Image.asset(
                'assets/logo.png',
                height: 300, // Un buen tamaño
              ),
              const Text(
                "LEYENDA VIAL", // <--- CAMBIO DE NOMBRE AQUÍ
                style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const SizedBox(height: 50),

              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Email",
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.email, color: Colors.white70),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: neonGreen), borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Colors.grey[900],
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Contraseña",
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: neonGreen), borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Colors.grey[900],
                ),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: neonGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 5,
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.black) 
                    : const Text("INGRESAR", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: () {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                },
                child: Text("¿No tenés cuenta? Registrate acá", style: TextStyle(color: neonGreen)),
              )
            ],
          ),
        ),
      ),
    );
  }
}