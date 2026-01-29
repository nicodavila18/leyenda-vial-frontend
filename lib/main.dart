import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Para leer la memoria del celu
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'; // Para configurar el mapa de entrada

// Importamos las pantallas
import 'screens/map_screen.dart'; 
import 'screens/login_screen.dart'; 

void main() async {
  // 1. Necesario para usar código asíncrono (await) en el main
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Configuramos Mapbox de entrada (Mejora la velocidad)
  // ¡PEGÁ TU TOKEN PÚBLICO ACÁ! (El que empieza con pk...)
  MapboxOptions.setAccessToken("pk.eyJ1Ijoibmljb2RhdmlsYTE4IiwiYSI6ImNta2VuYTkwMzA5NGsza29mdTQ1bjNmNmgifQ.3bY4dbpjoCYpv6zxUtHvwg"); 

  // 3. Revisamos la memoria del celular
  SharedPreferences prefs = await SharedPreferences.getInstance();
  // Buscamos si hay un ID de usuario o Token guardado
  // (Asumo que en tu Login guardás 'user_id' o 'access_token')
  String? userId = prefs.getString('user_id'); 
  
  // 4. Decidimos el destino:
  // Si hay ID -> Mapa. Si no hay ID -> Login.
  Widget pantallaInicial = (userId != null) ? const MapScreen() : const LoginScreen();

  runApp(MyApp(startScreen: pantallaInicial));
}

class MyApp extends StatelessWidget {
  final Widget startScreen; // Recibimos la decisión

  const MyApp({super.key, required this.startScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, 
      title: 'Seguridad Vial',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00FF99), 
        scaffoldBackgroundColor: Colors.grey[900],
        useMaterial3: true,
      ),
      // Usamos la pantalla que decidimos arriba
      home: startScreen, 
    );
  }
}