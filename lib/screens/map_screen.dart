import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox; 
import 'package:http/http.dart' as http; 
import 'dart:convert';
import 'package:geolocator/geolocator.dart'; 
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

import '../services/reporte_service.dart';
import '../services/puntos_service.dart'; // <--- Ahora sí existe este archivo
import '../services/storage_service.dart'; 
import '../models/reporte_model.dart';
import 'accident_screen.dart';
import 'info_screen.dart';
import 'premium_screen.dart';
import 'profile_screen.dart'; 
import 'login_screen.dart';
import 'shop_screen.dart';
import 'vehicle_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  mapbox.MapboxMap? mapboxMap;
  mapbox.CircleAnnotationManager? circleManager; 
  mapbox.PointAnnotationManager? _managerFijos;    // Capa 1: Hospitales
  mapbox.PointAnnotationManager? _managerReportes; // Capa 2: Reportes 
  
  final ReporteService _reporteService = ReporteService();
  final PuntosService _puntosService = PuntosService(); // Servicio Nuevo

  // Variables de usuario
  String _username = "Cargando...";
  String _email = ""; 
  bool _isPremium = false; 
  int _reportsUsed = 0; 
  int _xp = 0;
  String? _avatarBase64; 
  bool _modoConduccion = false;
  StreamSubscription<Position>? _trackingStream;
  bool _puntosFijosCargados = false;
  double _bearingActual = 0.0;
  double _zoomStart = 13.0;
  final FlutterTts _tts = FlutterTts();
  final Set<String> _reportesAvisados = {}; // Lista negra para no repetir alertas

  // Mapas de reportes y puntos fijos en el mapa

  final Map<String, Reporte> _reportesEnMapa = {};
  final Map<String, PuntoFijo> _puntosFijosEnMapa = {}; 

  // Estilo Dark (El que mejor se ve)
  final String _miEstiloPersonalizado = mapbox.MapboxStyles.DARK; 

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario(); 
    _solicitarPermisosGPS(); 
    _configurarTTS();
  }

  @override
  void dispose() {
    _trackingStream?.cancel(); // Cortamos el seguimiento si cierra la pantalla
    super.dispose();
  }

  // Configuración de la voz argentina 🇦🇷
  Future<void> _configurarTTS() async {
    await _tts.setLanguage("es-AR");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
    
    // 👇 ESTA ES LA MAGIA: Obliga al celular a esperar que termine de hablar
    // antes de liberar el código para la siguiente línea.
    await _tts.awaitSpeakCompletion(true); 

    var idiomas = await _tts.getLanguages;
    if (!idiomas.contains("es-AR")) {
      await _tts.setLanguage("es-ES");
    }
  }

  Future<void> _solicitarPermisosGPS() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;
    
    mapboxMap?.location.updateSettings(mapbox.LocationComponentSettings(
      enabled: true, pulsingEnabled: true
    ));
  }

  Future<void> _cargarDatosUsuario() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id');

    setState(() {
      _username = prefs.getString('username') ?? "Usuario";
      _email = prefs.getString('email') ?? "Sin email";
      _isPremium = prefs.getBool('is_premium') ?? false;
      _avatarBase64 = prefs.getString('avatar_local');
    });

    if (userId == null) return;
    try {
      // ⚠️ ¡ATENCIÓN! REVISÁ QUE ESTA IP COINCIDA CON LA DE PUNTOS_SERVICE
      var url = Uri.parse("https://leyenda-vial-backend-production.up.railway.app/usuarios/$userId"); 
      var response = await http.get(url);
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          _isPremium = data['is_premium'];
          _reportsUsed = data['reports_used'];
          _xp = data['lifetime_xp'] ?? 0;
          if (data['avatar_data'] != null && data['avatar_data'].toString().isNotEmpty) {
             _avatarBase64 = data['avatar_data'];
             prefs.setString('avatar_local', _avatarBase64!);
          }
          prefs.setBool('is_premium', _isPremium);
        });
      }
    } catch (e) { print("Error actualizando perfil: $e"); }
  }

  String _obtenerRango(int xp) {
    if (xp >= 500) return "LEYENDA";
    if (xp >= 100) return "GUARDIÁN";
    if (xp >= 50) return "VIGILANTE";
    return "NOVATO";
  }

  _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    mapboxMap.scaleBar.updateSettings(mapbox.ScaleBarSettings(enabled: false));
    mapboxMap.location.updateSettings(mapbox.LocationComponentSettings(enabled: true, pulsingEnabled: true));

    var listener = ReporteClickListener(
        context, _reporteService, _reportesEnMapa, _puntosFijosEnMapa,
        (id) { _recargarTodo(); _cargarDatosUsuario(); }
    );

    // -----------------------------------------------------------
    // 1️⃣ PRIMERO: Creamos la Capa de FIJOS (Hospitales) 🏥
    // Al crearla primero, Mapbox la pone en el "piso".
    // -----------------------------------------------------------
    _managerFijos = await mapboxMap.annotations.createPointAnnotationManager();
    _managerFijos?.addOnPointAnnotationClickListener(listener);

    // -----------------------------------------------------------
    // 2️⃣ SEGUNDO: Creamos el Manager de CÍRCULOS (Radares/Fichas) 🔴
    // Al crearlo después, esta capa se dibuja ENCIMA de los Fijos.
    // -----------------------------------------------------------
    circleManager = await mapboxMap.annotations.createCircleAnnotationManager();
    circleManager?.addOnCircleAnnotationClickListener(listener);

    // -----------------------------------------------------------
    // 3️⃣ TERCERO: Creamos la Capa de LETRAS REPORTES (Arriba de todo) 🅰️
    // Esta siempre va última para que la letra se lea bien.
    // -----------------------------------------------------------
    _managerReportes = await mapboxMap.annotations.createPointAnnotationManager();
    _managerReportes?.addOnPointAnnotationClickListener(listener);

    // Arrancamos
    _recargarTodo();
  }

  // --- CARGA DE PUNTOS FIJOS (REAL) ---
  Future<void> _cargarPuntosFijos({List<PuntoFijo>? datosPreloaded, bool limpiar = true}) async {
    try {
      List<PuntoFijo> puntosReales = datosPreloaded ?? await _puntosService.getPuntosFijos();
      
      for (var punto in puntosReales) {
        var mapPoint = mapbox.Point(coordinates: mapbox.Position(punto.lng, punto.lat));
        
        // COLORES POR TIPO
        int colorHex = 0xFF757575; 
        String letra = "?";

        if (punto.tipo == "hospital") {
           colorHex = 0xFF2E7D32; // Verde Hospital 🏥
           letra = "H"; 
        } else if (punto.tipo == "comisaria") {
           colorHex = 0xFF1565C0; // Azul Policía 🚓
           letra = "C"; 
        } else if (punto.tipo == "taller") {
           colorHex = 0xFF6A1B9A; // Violeta Taller 🔧
           letra = "T"; 
        } else if (punto.tipo == "legal") {
           colorHex = 0xFF5D4037; // Marrón Legal ⚖️
           letra = "L"; 
        }

        // 1. EL FONDO (El cuadrado "■") 
        // Le ponemos sortKey = 1 para que se dibuje AL FONDO
        await _managerFijos?.create(mapbox.PointAnnotationOptions(
          geometry: mapPoint,
          textField: "■",        
          textSize: 45.0,        // <--- MÁS GRANDE (Era 35)
          textColor: colorHex,   
          textOffset: [0, -0.1], 
          symbolSortKey: 1.0,    // <--- CLAVE: Capa inferior 1
          textOpacity: 1.0,
        ));

        // 2. LA LETRA (Va encima)
        // Le ponemos sortKey = 10 para que flote ENCIMA del cuadrado
        var anotacion = await _managerFijos?.create(mapbox.PointAnnotationOptions(
          geometry: mapPoint,
          textField: letra,
          textSize: 20.0,            // Letra un poco más grande también
          textColor: 0xFFFFFFFF,     // Blanco puro
          textHaloColor: 0xFF000000, // Sombrita suave
          textHaloWidth: 0.5,
          textOffset: [0, -0.2],     // Ajuste fino para centrarla en el cuadrado
          symbolSortKey: 10.0,       // <--- CLAVE: Capa superior 10 (Gana al 1)
        ));
        
        if (anotacion != null) _puntosFijosEnMapa[anotacion.id] = punto;
      }
    } catch (e) { print("Error cargando puntos fijos: $e"); }
  }

  Future<void> _cargarReportes({List<Reporte>? datosPreloaded, bool limpiar = true}) async {
    try {
      List<Reporte> reportes = datosPreloaded ?? await _reporteService.getReportes();
      
      if (limpiar && datosPreloaded == null) {
         await circleManager?.deleteAll();     
         await _managerReportes?.deleteAll();  
         _reportesEnMapa.clear(); 
      }

      if (reportes.isEmpty) return;

      for (var reporte in reportes) {
        String tipoLower = reporte.tipo.toLowerCase(); 
        
        int colorFondo = 0xFF9E9E9E; 
        String letra = "?";
        // Colores intensos
        if (tipoLower.contains('polic')) { colorFondo = 0xFF1976D2; letra = "P"; } 
        else if (tipoLower.contains('accid')) { colorFondo = 0xFFD32F2F; letra = "A"; } 
        else if (tipoLower.contains('obra')) { colorFondo = 0xFFF57C00; letra = "O"; } 

        var point = mapbox.Point(coordinates: mapbox.Position(reporte.longitud, reporte.latitud));

        // 1. EL RADAR (El Halo Suave) 📡
        // Lo dibujamos primero para que quede atrás
        await circleManager?.create(mapbox.CircleAnnotationOptions(
          geometry: point,
          circleColor: colorFondo,
          circleRadius: 22.0,       // <--- TAMAÑO MEDIO (Apenas sobresale del núcleo)
          circleOpacity: 0.3,       // Transparente (30%)
          circleStrokeWidth: 0.0,   // Sin borde
          circleBlur: 0.1,          // Suavizado
        ));

        // 2. LA FICHA (Núcleo Sólido) ⚪🔴
        // Lo dibujamos segundo para que quede encima del radar
        await circleManager?.create(mapbox.CircleAnnotationOptions(
          geometry: point,
          circleColor: colorFondo,
          circleRadius: 14.0,            // <--- TAMAÑO CHICO (Era 20)
          circleStrokeColor: 0xFFFFFFFF, // Borde Blanco
          circleStrokeWidth: 2.0,        // Borde fino y elegante
          circleOpacity: 1.0,            // Sólido
        ));

        // 3. LA LETRA (A, P, O)
        var anotacion = await _managerReportes?.create(mapbox.PointAnnotationOptions(
          geometry: point,
          textField: letra,
          textSize: 15.0,            // <--- TAMAÑO AJUSTADO (Para que entre en el círculo de 14)
          textColor: 0xFFFFFFFF,
          textHaloColor: 0xFF000000, 
          textHaloWidth: 1.0,
          textOffset: [0, -0.1],     
          symbolSortKey: 101.0,      
        ));
        
        if (anotacion != null) _reportesEnMapa[anotacion.id] = reporte;
      }
    } catch (e) { print("Error cargando reportes: $e"); }
  }

  // Función maestra para evitar que se borren cosas entre sí
  Future<void> _recargarTodo({bool forzarTodo = false}) async {
    print("🔄 Recargando mapa (Inteligente)...");
    
    try {
      // 1. SIEMPRE buscamos los reportes nuevos (son dinámicos)
      var futureReportes = _reporteService.getReportes();
      
      // 2. SOLO buscamos puntos fijos si es la primera vez o si forzamos
      // Esto evita la demora innecesaria
      Future<List<PuntoFijo>>? futurePuntos;
      if (!_puntosFijosCargados || forzarTodo) {
        futurePuntos = _puntosService.getPuntosFijos();
      }

      // Esperamos resultados
      final reportes = await futureReportes;
      
      // --- LOGICA DE ACTUALIZACIÓN ---

      // A. Si hay que cargar puntos fijos (Primera vez o Refresh forzado)
      if (futurePuntos != null) {
        print("📥 Descargando puntos fijos...");
        final puntos = await futurePuntos;
        
        // Limpiamos capa Fijos
        await _managerFijos?.deleteAll(); 
        _puntosFijosEnMapa.clear();
        
        await _cargarPuntosFijos(datosPreloaded: puntos, limpiar: false);
        _puntosFijosCargados = true;
      }
      
      // B. Siempre redibujamos reportes (Pero limpiando inteligentemente)
      // Pasamos 'limpiar: true' para que _cargarReportes borre SOLO los reportes viejos
      await _cargarReportes(datosPreloaded: reportes, limpiar: true);
      
      print("✅ Mapa actualizado.");

    } catch (e) { print("❌ Error recargando: $e"); }
  }

  void _irAlPerfil() async {
    Navigator.pop(context); 
    await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
    _cargarDatosUsuario(); 
  }

  void _mostrarMenuReporte() async {
    var cameraState = await mapboxMap?.getCameraState();
    var centro = cameraState?.center;
    if (centro == null) return;
    
    // ... Tu lógica de menú de reporte ...
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("¿Qué estás viendo?", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _botonOpcion("Policía", "policia", Icons.local_police, Colors.blue, centro),
                  _botonOpcion("Accidente", "accidente", Icons.car_crash, Colors.red, centro),
                  _botonOpcion("Obra", "obra", Icons.construction, Colors.orange, centro),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _botonOpcion(String titulo, String codigo, IconData icono, Color color, mapbox.Point coordenadas) {
    return Column(
      children: [
        GestureDetector(
          onTap: () async {
            Navigator.pop(context); 
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Procesando $titulo..."), duration: const Duration(milliseconds: 500)));
            var respuesta = await _reporteService.crearReporte(codigo, coordenadas.coordinates.lat.toDouble(), coordenadas.coordinates.lng.toDouble());
            String status = respuesta['status'] ?? "error";

            if (status == "error_limit") {
               showDialog(context: context, builder: (ctx) => Dialog(backgroundColor: Colors.transparent, child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 2)), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.local_gas_station_outlined, size: 50, color: Colors.redAccent), const SizedBox(height: 20), const Text("¡Tanque Vacío!", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 10), const Text("Alcanzaste tu límite de 3 reportes diarios.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16)), const SizedBox(height: 20), ElevatedButton.icon(icon: const Icon(Icons.diamond, color: Colors.black), label: const Text("HACERME PREMIUM", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF99)), onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (context) => const PremiumScreen())); }), const SizedBox(height: 15), TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Esperar a mañana", style: TextStyle(color: Colors.white54, fontSize: 14)))]))));
            } else {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(respuesta['mensaje']), backgroundColor: status == "error" ? Colors.red : const Color(0xFF00FF99)));
            }
            if (status == "created" || status == "confirmed") { _recargarTodo(); _cargarDatosUsuario(); }
          },
          child: CircleAvatar(radius: 30, backgroundColor: color.withOpacity(0.2), child: Icon(icono, color: color, size: 30)),
        ),
        const SizedBox(height: 5),
        Text(titulo, style: const TextStyle(color: Colors.white70))
      ],
    );
  }

  Widget _menuItem(IconData icon, String text, VoidCallback onTap, {Color color = Colors.white}) {
    return ListTile(
      leading: Icon(icon, color: color, size: 24),
      title: Text(text, style: TextStyle(color: color, fontSize: 15)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 5), 
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        backgroundColor: Colors.black,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 60, bottom: 30, left: 20, right: 20),
              decoration: BoxDecoration(color: Colors.grey[900], border: const Border(bottom: BorderSide(color: Colors.white10))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      GestureDetector(onTap: _irAlPerfil, child: CircleAvatar(radius: 35, backgroundColor: _isPremium ? Colors.amber : const Color(0xFF00FF99), child: CircleAvatar(radius: 31, backgroundColor: Colors.grey[900], backgroundImage: _avatarBase64 != null ? MemoryImage(base64Decode(_avatarBase64!)) : null, child: _avatarBase64 == null ? const Icon(Icons.person, color: Colors.white, size: 40) : null))),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)), child: Text(_obtenerRango(_xp), style: TextStyle(color: _isPremium ? Colors.amber : const Color(0xFF00FF99), fontSize: 10, fontWeight: FontWeight.bold)))
                  ]),
                  const SizedBox(height: 15),
                  Text(_username, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(_email, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
            ),
            Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 20), children: [
                  
                  // 1. PREMIUM ARRIBA (Marketing)
                  if (!_isPremium) ...[
                     // 1. Banner Publicidad (El que ya tenías)
                     ListTile(
                       leading: const Icon(Icons.diamond, color: Colors.amber, size: 28), 
                       title: const Text("HAZTE PREMIUM", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, letterSpacing: 1.2)), 
                       subtitle: const Text("Sin límites + Soporte Prioritario", style: TextStyle(color: Colors.white54, fontSize: 10)),
                       contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 5), 
                       tileColor: Colors.amber.withOpacity(0.1), 
                       onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const PremiumScreen())); }
                     ),
                     
                     // 2. EL CONTADOR QUE FALTABA 📊
                     Padding(
                       padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               const Text("Reportes Diarios", style: TextStyle(color: Colors.white70, fontSize: 12)),
                               Text("$_reportsUsed / 3", style: TextStyle(color: _reportsUsed >= 3 ? Colors.redAccent : Colors.white, fontWeight: FontWeight.bold)),
                             ],
                           ),
                           const SizedBox(height: 8),
                           ClipRRect(
                             borderRadius: BorderRadius.circular(5),
                             child: LinearProgressIndicator(
                               value: (_reportsUsed / 3).clamp(0.0, 1.0), // Calculamos porcentaje (0.0 a 1.0)
                               backgroundColor: Colors.white10,
                               valueColor: AlwaysStoppedAnimation<Color>(
                                 _reportsUsed >= 3 ? Colors.red : const Color(0xFF00FF99) // Verde si hay lugar, Rojo si está lleno
                               ),
                               minHeight: 6,
                             ),
                           ),
                           if (_reportsUsed >= 3)
                             const Padding(
                               padding: EdgeInsets.only(top: 5),
                               child: Text("¡Límite alcanzado! Esperá a mañana.", style: TextStyle(color: Colors.redAccent, fontSize: 10)),
                             )
                         ],
                       ),
                     ),
                     
                     const Divider(color: Colors.white10),
                  ] 
                  // CASO 2: USUARIO PREMIUM (Lujo total) 💎
                  else ...[
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.withOpacity(0.3))
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.all_inclusive, color: Colors.amber, size: 24), // Signo Infinito
                            SizedBox(width: 10),
                            Text("REPORTES ILIMITADOS", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white10),
                  ],

                  const Padding(padding: EdgeInsets.only(left: 25, bottom: 10, top: 10), child: Text("NAVEGACIÓN", style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
                  _menuItem(Icons.map, "Mapa en Vivo", () => Navigator.pop(context), color: const Color(0xFF00FF99)),
                  _menuItem(Icons.person_outline, "Mi Perfil", _irAlPerfil),
                  _menuItem(Icons.directions_car_filled_outlined, "Mi Vehículo", () async { Navigator.pop(context); await Navigator.push(context, MaterialPageRoute(builder: (context) => const VehicleScreen())); }),
                  
                  const SizedBox(height: 20),
                  const Padding(padding: EdgeInsets.only(left: 25, bottom: 10), child: Text("UTILIDADES", style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
                  _menuItem(Icons.gavel, "Leyes y Multas", () async { Navigator.pop(context); await Navigator.push(context, MaterialPageRoute(builder: (context) => const InfoScreen())); }),
                  _menuItem(Icons.shopping_bag_outlined, "Tienda de Puntos", () async { Navigator.pop(context); await Navigator.push(context, MaterialPageRoute(builder: (context) => const ShopScreen())); _cargarDatosUsuario(); }),
                  
                  // 2. ACCIDENTE AL FINAL (Utilidad crítica)
                  const SizedBox(height: 10),
                  _menuItem(Icons.medical_services_outlined, "En caso de Accidente", () { 
                    Navigator.pop(context); // Cierra el menú
                    
                    // 👇 ACÁ ESTÁ EL CAMBIO: Vamos a la pantalla de emergencia
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AccidentScreen()));
                    
                  }, color: Colors.redAccent),

            ])),
            
            const Divider(color: Colors.white10),
            ListTile(leading: const Icon(Icons.logout, color: Colors.redAccent), title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.redAccent, fontSize: 14)), contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10), onTap: () async { Navigator.pop(context); await StorageService().borrarSesion(); if (context.mounted) { Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false); } }),
          ],
        ),
      ),
      body: Stack(children: [
          mapbox.MapWidget(
            onMapCreated: _onMapCreated, 
            styleUri: _miEstiloPersonalizado,
            cameraOptions: mapbox.CameraOptions(
              center: mapbox.Point(coordinates: mapbox.Position(-68.82717, -32.89084)), 
              zoom: 13.0
            )
          ),

          // CAPA 2: CONTROLADOR DE GESTOS (Solo aparece en Modo Copiloto) 🕹️
          if (_modoConduccion)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent, // Deja pasar toques vacíos
                
                // AL EMPEZAR A TOCAR (Guardamos zoom y rotación actuales)
                onScaleStart: (details) async {
                   var estado = await mapboxMap?.getCameraState();
                   if (estado != null) {
                     _bearingActual = estado.bearing ?? 0.0;
                     _zoomStart = estado.zoom ?? 13.0;
                   }
                },

                // AL MOVER O PELLIZCAR (Detectamos qué estás haciendo)
                onScaleUpdate: (details) {
                  // A. Si usás DOS DEDOS (Scale != 1.0) -> Es ZOOM 🔍
                  if (details.scale != 1.0) {
                     // Calculamos nuevo zoom (Zoom Inicial * Escala del dedo)
                     // Restamos 1 y sumamos para suavizar la escala logarítmica del mapa
                     double nuevoZoom = _zoomStart + (details.scale - 1) * 2.5; 
                     
                     mapboxMap?.setCamera(mapbox.CameraOptions(
                       zoom: nuevoZoom
                     ));
                  } 
                  
                  // B. Si arrastrás HORIZONTALMENTE (FocalPoint se mueve) -> Es ROTACIÓN 🔄
                  // Usamos focalPointDelta para simular el "HorizontalDrag"
                  else if (details.focalPointDelta.dx != 0) {
                     // Sensibilidad: Dividimos por 4 para que sea controlable
                     double nuevaRotacion = _bearingActual + (details.focalPointDelta.dx / 4);
                     
                     mapboxMap?.setCamera(mapbox.CameraOptions(
                       bearing: nuevaRotacion
                     ));
                     _bearingActual = nuevaRotacion; // Actualizamos referencia
                  }
                },
              ),
            ),
          Positioned(top: 50, left: 20, child: FloatingActionButton.small(heroTag: "menuBtn", backgroundColor: Colors.black.withOpacity(0.7), child: const Icon(Icons.menu, color: Colors.white), onPressed: () => _scaffoldKey.currentState?.openDrawer())),
          Positioned(top: 50, right: 20, child: FloatingActionButton.small(heroTag: "refreshBtn", backgroundColor: Colors.black.withOpacity(0.7), child: const Icon(Icons.refresh, color: Colors.white), onPressed: () { _cargarReportes(); _cargarPuntosFijos(); })),
          if (!_modoConduccion)
            const Center(child: Icon(Icons.my_location, color: Color(0xFF00FF99), size: 40)),
      ]),
      floatingActionButton: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          // BOTÓN GPS "MODO COPILOTO PROFESIONAL" (Bloqueado) 🚔
          FloatingActionButton(
            heroTag: "locateBtn",
            backgroundColor: _modoConduccion ? Colors.amber : Colors.grey[900],
            child: Icon(
              _modoConduccion ? Icons.navigation : Icons.gps_fixed,
              color: _modoConduccion ? Colors.black : const Color(0xFF00FF99)
            ),
            onPressed: () async {
              try {
                setState(() {
                  _modoConduccion = !_modoConduccion;
                });

                if (_modoConduccion) {
                  // --- 🟢 ACTIVAR MODO COPILOTO ---
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🚗 Modo Copiloto: Mapa anclado.")));

                  // 1. BLOQUEOS
                  mapboxMap?.gestures.updateSettings(mapbox.GesturesSettings(
                    scrollEnabled: false,      
                    rotateEnabled: true,       
                    pitchEnabled: true,        
                    pinchToZoomEnabled: true,  
                    doubleTapToZoomInEnabled: true,
                  ));

                  // 2. CONFIGURAMOS GPS
                  const LocationSettings locationSettings = LocationSettings(
                    accuracy: LocationAccuracy.high, 
                    distanceFilter: 3, 
                  );
                  
                  // Variable "Bandera" para controlar la entrada triunfal
                  bool esElPrimerMovimiento = true; 

                  // 3. EMPEZAMOS A ESCUCHAR
                  _trackingStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) async { // <--- OJO: Agregá 'async' aquí si no estaba
                      
                      // --- 📡 RADAR DE PELIGROS (MEJORADO) ---
                      for (var reporte in _reportesEnMapa.values) {
                        
                        // Si ya le avisé, paso al siguiente (Ahorro cálculos)
                        if (_reportesAvisados.contains(reporte.id)) continue;

                        double distancia = Geolocator.distanceBetween(
                          position.latitude, position.longitude, 
                          reporte.latitud, reporte.longitud
                        );

                        // Si está cerca (400m)
                        if (distancia < 400) {
                          
                          // 1. PRIMERO LO MARCAMOS (Para que no se repita mientras habla) 🚫
                          _reportesAvisados.add(reporte.id);

                          // 2. Preparamos el mensaje
                          String mensaje = "Precaución.";
                          String tipo = reporte.tipo.toLowerCase();
                          if (tipo.contains("polic")) mensaje = "Control policial a 400 metros.";
                          else if (tipo.contains("accid")) mensaje = "Accidente reportado más adelante.";
                          else if (tipo.contains("obra")) mensaje = "Obras en la calzada.";
                          else mensaje = "Reporte de ${reporte.tipo} cerca.";

                          // 3. HABLAMOS (El código se pausa aquí hasta que termine la frase) 🗣️
                          await _tts.speak(mensaje);
                        }
                      }
                      
                      if (esElPrimerMovimiento) {
                        // --- PRIMERA VEZ (ENTRADA TRIUNFAL) --- 🎬
                        // Aquí SÍ forzamos el 3D y el Zoom, porque recién arranca.
                        mapboxMap?.flyTo(
                          mapbox.CameraOptions(
                            center: mapbox.Point(coordinates: mapbox.Position(position.longitude, position.latitude)),
                            zoom: 18.0,   // Zoom inicial forzado
                            pitch: 60.0,  // 3D inicial forzado
                          ),
                          mapbox.MapAnimationOptions(duration: 2000) // Animación lenta de 2 seg
                        );
                        esElPrimerMovimiento = false; // Bajamos la bandera para que no lo haga más

                      } else {
                        // --- SIGUIENTES VECES (SEGUIMIENTO) --- 🚗
                        // Aquí NO tocamos zoom ni pitch, para respetar tu decisión manual.
                        mapboxMap?.easeTo(
                          mapbox.CameraOptions(
                            center: mapbox.Point(coordinates: mapbox.Position(position.longitude, position.latitude)),
                            // AL NO PONER ZOOM NI PITCH, SE MANTIENEN LOS QUE VOS TENGAS
                          ),
                          mapbox.MapAnimationOptions(duration: 1000)
                        );
                      }
                  });

                } else {
                  // --- 🔴 DESACTIVAR ---
                  _trackingStream?.cancel(); 
                  _trackingStream = null;

                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🗺️ Modo Mapa Libre")));

                  mapboxMap?.gestures.updateSettings(mapbox.GesturesSettings(
                    scrollEnabled: true,      
                    rotateEnabled: true,
                    pitchEnabled: true,
                    pinchToZoomEnabled: true, 
                    doubleTapToZoomInEnabled: true,
                  ));

                  // Volvemos al cielo
                  var cameraState = await mapboxMap?.getCameraState();
                  if (cameraState != null) {
                    mapboxMap?.flyTo(
                      mapbox.CameraOptions(
                        center: cameraState.center, 
                        zoom: 14.0,   
                        pitch: 0.0,   
                        bearing: 0.0, 
                      ),
                      mapbox.MapAnimationOptions(duration: 1500)
                    );
                  }
                }

              } catch (e) {
                _solicitarPermisosGPS();
                setState(() => _modoConduccion = false);
              }
            }
          ),
          const SizedBox(height: 15),
          FloatingActionButton(heroTag: "addBtn", backgroundColor: const Color(0xFF00FF99), child: const Icon(Icons.add, color: Colors.black), onPressed: () => _mostrarMenuReporte()),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// CLICK LISTENER INTELIGENTE
// ---------------------------------------------------------------------------
class ReporteClickListener implements mapbox.OnPointAnnotationClickListener, mapbox.OnCircleAnnotationClickListener {
  final BuildContext context;
  final ReporteService servicio;
  final Map<String, Reporte> mapReportes;
  final Map<String, PuntoFijo> mapPuntosFijos; 
  final Function(String) onUpdate;

  ReporteClickListener(this.context, this.servicio, this.mapReportes, this.mapPuntosFijos, this.onUpdate);

  String _obtenerRango(int xp) {
    if (xp >= 500) return "LEYENDA 👑";
    if (xp >= 100) return "GUARDIÁN 🛡️";
    if (xp >= 50) return "VIGILANTE 👁️";
    return "NOVATO 🐣";
  }

  void _procesarClick(String annotationId) async {
    // 1. PUNTOS FIJOS
    if (mapPuntosFijos.containsKey(annotationId)) {
      _mostrarModalPuntoFijo(mapPuntosFijos[annotationId]!);
      return;
    }
    // 2. REPORTES
    if (mapReportes.containsKey(annotationId)) {
      _mostrarModalReporte(mapReportes[annotationId]!);
      return;
    }
  }

  void _mostrarModalPuntoFijo(PuntoFijo punto) {
    IconData icono = Icons.place;
    Color color = Colors.white;

    if (punto.tipo == "hospital") { icono = Icons.local_hospital; color = Colors.redAccent; }
    if (punto.tipo == "taller") { icono = Icons.build; color = Colors.orangeAccent; }
    if (punto.tipo == "comisaria") { icono = Icons.local_police; color = Colors.blueAccent; }
    if (punto.tipo == "legal") { icono = Icons.gavel; color = Colors.amber; }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), border: Border.all(color: color.withOpacity(0.5))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(15)), child: Icon(icono, color: color, size: 30)),
                const SizedBox(width: 15),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(punto.nombre, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(punto.tipo.toUpperCase(), style: TextStyle(color: color, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                ]))
            ]),
            const SizedBox(height: 20),
            _infoRow(Icons.location_on, punto.direccion),
            _infoRow(Icons.access_time, "Horario: ${punto.horario}"),
            _infoRow(Icons.phone, punto.telefono),
            const SizedBox(height: 25),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: const Icon(Icons.navigation, color: Colors.black), label: const Text("IR AHORA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF99), padding: const EdgeInsets.symmetric(vertical: 15)), onPressed: () => Navigator.pop(ctx)))
        ]),
      )
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Icon(icon, color: Colors.white54, size: 18), const SizedBox(width: 15), Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 15)))]));
  }

  void _mostrarModalReporte(Reporte reporte) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String miVehiculo = prefs.getString('vehiculo') ?? 'auto';
    String reporteId = reporte.id;
    String tipo = reporte.tipo.toLowerCase();
    String descripcion = reporte.description;
    String consejo = "";

    if (tipo.contains("accid") || tipo.contains("obra")) {
       if (miVehiculo == "moto") consejo = "⚠️ ¡Cuidado! Aceite o restos en calzada.";
       if (miVehiculo == "bici") consejo = "⚠️ Bajá la velocidad. Carril bloqueado.";
       if (miVehiculo == "auto") consejo = "⚠️ Reducí velocidad. Posible congestión.";
    } else if (tipo.contains("polic")) {
       if (miVehiculo == "moto") consejo = "👮 Recordá: Casco abrochado y patente.";
       if (miVehiculo == "auto") consejo = "👮 Recordá: Cinturón y luces bajas.";
    }

    Color colorTema = Colors.grey;
    String titulo = "Reporte";
    IconData icono = Icons.info;

    if (tipo.contains("polic")) { colorTema = Colors.blue; titulo = "Control Policial"; icono = Icons.local_police; }
    else if (tipo.contains("accid")) { colorTema = Colors.red; titulo = "Accidente"; icono = Icons.car_crash; }
    else if (tipo.contains("obra")) { colorTema = Colors.orange; titulo = "Obra / Bache"; icono = Icons.construction; }
    else { titulo = reporte.tipo; }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), border: Border.all(color: colorTema.withOpacity(0.3), width: 1), boxShadow: [BoxShadow(color: colorTema.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: colorTema.withOpacity(0.15), borderRadius: BorderRadius.circular(18), border: Border.all(color: colorTema.withOpacity(0.3))), child: Icon(icono, color: colorTema, size: 32)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Row(children: [const Icon(Icons.person, color: Colors.white54, size: 14), const SizedBox(width: 5), Text("${reporte.autor} ", style: const TextStyle(color: Colors.white70, fontSize: 14)), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)), child: Text(_obtenerRango(reporte.experiencia), style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)))])]))]),
            const SizedBox(height: 20),
            if (consejo.isNotEmpty) Container(width: double.infinity, padding: const EdgeInsets.all(15), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.amber.withOpacity(0.15), Colors.amber.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.amber.withOpacity(0.3))), child: Row(children: [Icon(miVehiculo == 'moto' ? Icons.two_wheeler : (miVehiculo == 'bici' ? Icons.pedal_bike : Icons.directions_car), color: Colors.amber, size: 24), const SizedBox(width: 15), Expanded(child: Text(consejo, style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.w500)))])),
            const SizedBox(height: 20),
            Text(descripcion.isNotEmpty ? descripcion : "Sin detalles adicionales reportados.", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15, fontStyle: FontStyle.italic)),
            const SizedBox(height: 25),
            const Divider(color: Colors.white10),
            const SizedBox(height: 10),
            const Center(child: Text("¿Sigue ahí este reporte?", style: TextStyle(color: Colors.white54, fontSize: 14))),
            const SizedBox(height: 15),
            Row(children: [Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: Colors.white24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () async { Navigator.pop(ctx); var res = await servicio.votarReporte(reporteId, "borrar"); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['mensaje']))); if (res['status'] == 'success') onUpdate(reporteId); }, child: const Text("❌ Ya no está", style: TextStyle(color: Colors.white70, fontSize: 16)))), const SizedBox(width: 15), Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF99), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), elevation: 5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () async { Navigator.pop(ctx); var res = await servicio.votarReporte(reporteId, "confirmar"); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['mensaje']), backgroundColor: const Color(0xFF00FF99))); if (res['status'] == 'success') onUpdate(reporteId); }, child: const Text("👍 Confirmar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))))]),
          ],
        ),
      ),
    );
  }

  @override
  void onPointAnnotationClick(mapbox.PointAnnotation annotation) { _procesarClick(annotation.id); }

  @override
  void onCircleAnnotationClick(mapbox.CircleAnnotation annotation) { _procesarClick(annotation.id); }
}