import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io'; // Para manejar archivos
import 'package:image_picker/image_picker.dart'; // Para la cámara
import '../services/storage_service.dart';
import 'login_screen.dart';
import 'vehicle_screen.dart'; 
import 'shop_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Datos Visuales
  String username = "Cargando...";
  String email = "";
  String? avatarBase64; // Aquí guardamos la foto en memoria
  bool isPremium = false;
  
  // Economía y Nivel
  int saldoPuntos = 0; 
  int experiencia = 0; 
  int totalReportes = 0;
  int totalAyudas = 0;

  // Gamificación
  String rango = "Novato";
  String proximoRango = "Vigilante";
  double progreso = 0.0;
  int puntosRestantes = 0;

  String miVehiculo = 'auto';
  final ImagePicker _picker = ImagePicker(); // El objeto para sacar fotos

  @override
  void initState() {
    super.initState();
    _cargarDatosDesdeAPI();
  }

  Future<void> _cargarDatosDesdeAPI() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id');
    
    setState(() {
      username = prefs.getString('username') ?? "Usuario";
      email = prefs.getString('email') ?? "";
      miVehiculo = prefs.getString('vehiculo') ?? "auto";
      // Intentamos cargar la foto de caché local si existe
      avatarBase64 = prefs.getString('avatar_local');
    });

    if (userId == null) return;

    try {
      var url = Uri.parse("https://leyenda-vial-backend-production.up.railway.app/usuarios/$userId");
      var response = await http.get(url);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        
        setState(() {
          username = data['username'];
          email = data['email'];
          saldoPuntos = data['reputation'];
          experiencia = data['lifetime_xp'];
          totalReportes = data['total_reports'];
          totalAyudas = data['total_helps'];
          isPremium = data['is_premium'];
          miVehiculo = data['vehicle_type'];
          
          // Si viene foto del servidor, la usamos
          if (data['avatar_data'] != null && data['avatar_data'].toString().isNotEmpty) {
            avatarBase64 = data['avatar_data'];
            prefs.setString('avatar_local', avatarBase64!); // Guardamos en caché
          }

          _calcularRango(experiencia);
        });
        
        prefs.setString('username', username);
        prefs.setString('vehiculo', miVehiculo);
      }
    } catch (e) {
      print("Error cargando perfil: $e");
    }
  }

  // --- FUNCIÓN NUEVA: TOMAR FOTO ---
  Future<void> _tomarFoto() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true, // Esto ayuda a que no se rompa con el teclado
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        // Agregamos padding inferior para que el teclado no lo tape
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(25),
          // Quitamos la altura fija (height: 150)
          child: Column(
            mainAxisSize: MainAxisSize.min, // Que ocupe solo lo necesario
            children: [
              // Un pequeño indicador visual para arrastrar (opcional, pero queda lindo)
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Text("Cambiar Foto de Perfil", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _opcionFoto(Icons.camera_alt, "Usar Cámara", ImageSource.camera),
                  _opcionFoto(Icons.photo_library, "Abrir Galería", ImageSource.gallery),
                ],
              ),
              const SizedBox(height: 20), // Un poco de aire abajo
            ],
          ),
        ),
      )
    );
  }

  Widget _opcionFoto(IconData icon, String texto, ImageSource fuente) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context); // Cerrar modal
        final XFile? image = await _picker.pickImage(source: fuente, imageQuality: 50); // Calidad 50 para no pesar tanto
        if (image != null) {
          _procesarYSubirFoto(File(image.path));
        }
      },
      child: Column(children: [
        CircleAvatar(radius: 25, backgroundColor: Colors.white10, child: Icon(icon, color: const Color(0xFF00FF99))),
        const SizedBox(height: 5),
        Text(texto, style: const TextStyle(color: Colors.white))
      ]),
    );
  }

  Future<void> _procesarYSubirFoto(File foto) async {
    // 1. Convertir imagen a bytes y luego a Base64 (Texto)
    List<int> imageBytes = await foto.readAsBytes();
    String base64Image = base64Encode(imageBytes);

    // 2. Actualizar visualmente ya
    setState(() {
      avatarBase64 = base64Image;
    });

    // 3. Subir a Python
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id');
    prefs.setString('avatar_local', base64Image); // Guardar local

    try {
      var url = Uri.parse("https://leyenda-vial-backend-production.up.railway.app/usuarios/avatar");
      await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId, "avatar_base64": base64Image})
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Foto actualizada!"), backgroundColor: Color(0xFF00FF99)));
    } catch (e) {
      print("Error subiendo foto: $e");
    }
  }

  // --- TU LÓGICA DE SIEMPRE ---
  void _calcularRango(int xp) {
    if (xp >= 500) {
      rango = "Leyenda Vial 👑";
      proximoRango = "Máximo Nivel";
      progreso = 1.0;
      puntosRestantes = 0;
    } else if (xp >= 100) {
      rango = "Guardián 🛡️";
      proximoRango = "Leyenda Vial";
      progreso = (xp - 100) / (500 - 100); 
      puntosRestantes = 500 - xp;
    } else if (xp >= 50) {
      rango = "Vigilante 👁️";
      proximoRango = "Guardián";
      progreso = (xp - 50) / (100 - 50);
      puntosRestantes = 100 - xp;
    } else {
      rango = "Novato 🐣";
      proximoRango = "Vigilante";
      progreso = xp / 50; 
      puntosRestantes = 50 - xp;
    }
  }

  // --- FUNCIÓN EDITAR NOMBRE (LA QUE ARREGLAMOS ANTES) ---
  void _editarNombre() {
    TextEditingController controller = TextEditingController(text: username);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Editar Nombre", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF99))), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF99)))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF99)),
            onPressed: () async {
              Navigator.pop(ctx);
              await _guardarNuevoNombre(controller.text);
            },
            child: const Text("Guardar", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Future<void> _guardarNuevoNombre(String nuevoNombre) async {
    if (nuevoNombre.isEmpty) return;
    setState(() => username = nuevoNombre); 
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id');
    await prefs.setString('username', nuevoNombre);
    try {
      var url = Uri.parse("https://leyenda-vial-backend-production.up.railway.app/usuarios/perfil");
      await http.put(url, headers: {"Content-Type": "application/json"}, body: jsonEncode({"user_id": userId, "username": nuevoNombre}));
    } catch (e) { print("Error: $e"); }
  }

  Future<void> _cerrarSesion() async {
    await StorageService().borrarSesion();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
    }
  }

  void _confirmarCancelacion() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("¿Cancelar Suscripción?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Si cancelás ahora, seguirás siendo Premium hasta fin de mes, pero no se te volverá a cobrar.",
          style: TextStyle(color: Colors.white70)
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Volver")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _ejecutarCancelacion();
            }, 
            child: const Text("Confirmar Baja", style: TextStyle(color: Colors.redAccent))
          ),
        ],
      )
    );
  }

  Future<void> _ejecutarCancelacion() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id');
    try {
      // Endpoint de cancelación
      var url = Uri.parse("https://leyenda-vial-backend-production.up.railway.app/cancelar-suscripcion");
      var response = await http.post(
        url, 
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId})
      );
      
      var data = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['mensaje'])));
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error de conexión")));
    }
  }

  Future<void> _contactarSoporte() async {
    // Definimos el email y el asunto
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'ayuda.seguridadvial@gmail.com',
      query: 'subject=Ayuda con la App&body=Hola, necesito ayuda con...',
    );

    // Intentamos abrir la app de correo
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      // Si falla, mostramos un aviso
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo abrir la app de correo 📧"))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Mi Perfil", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // 1. AVATAR CON CÁMARA 📸
            GestureDetector(
              onTap: _tomarFoto, // <--- Al tocar, abre la cámara
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 55, // Un poco más grande para el borde
                    backgroundColor: isPremium ? Colors.amber : const Color(0xFF00FF99),
                    child: CircleAvatar(
                      radius: 51,
                      backgroundColor: Colors.grey[900],
                      backgroundImage: avatarBase64 != null 
                          ? MemoryImage(base64Decode(avatarBase64!)) // Si hay foto, la muestra
                          : null,
                      child: avatarBase64 == null 
                          ? const Icon(Icons.person, size: 60, color: Colors.white) // Si no, ícono
                          : null,
                    ),
                  ),
                  // Icono chiquito de cámara para indicar que se puede tocar
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Color(0xFF00FF99), shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.black),
                    ),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 15),
            
            // NOMBRE CENTRADO
            SizedBox(
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Text(username, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Positioned(
                    right: 0,
                    child: Container(
                      margin: const EdgeInsets.only(right: 20), 
                      child: IconButton(icon: const Icon(Icons.edit, color: Colors.white54, size: 20), onPressed: _editarNombre),
                    ),
                  ),
                ],
              ),
            ),
            if (email.isNotEmpty) Text(email, style: const TextStyle(color: Colors.white54, fontSize: 14)),
            
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF00FF99).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF00FF99))),
              child: Text(rango.toUpperCase(), style: const TextStyle(color: Color(0xFF00FF99), fontSize: 12, fontWeight: FontWeight.bold)),
            ),

            const SizedBox(height: 30),

            // ACCESO A VEHÍCULO
            const Text("MI VEHÍCULO ACTUAL", style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const VehicleScreen())).then((_) => _cargarDatosDesdeAPI());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(miVehiculo == 'moto' ? Icons.two_wheeler : (miVehiculo == 'bici' ? Icons.pedal_bike : Icons.directions_car), color: Colors.white, size: 28),
                    const SizedBox(width: 15),
                    Text(miVehiculo.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14)
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // 3. TARJETA DE NIVEL (Usamos tu lógica original)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Nivel de Experiencia", style: TextStyle(color: Colors.white70)),
                      Text("$experiencia XP", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progreso, // <--- Tu cálculo original
                      backgroundColor: Colors.black26,
                      color: const Color(0xFF00FF99),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    puntosRestantes > 0 ? "Faltan $puntosRestantes XP para $proximoRango" : "¡Máximo Nivel!",
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // 4. TARJETA DE PUNTOS
            GestureDetector(
              onTap: () {
                // Navegamos a la Tienda
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => const ShopScreen())
                ).then((_) {
                   // ✨ MAGIA: Al volver de la tienda (haya gastado puntos o comprado premium)
                   // recargamos el perfil para ver el saldo nuevo o el borde dorado.
                   _cargarDatosDesdeAPI(); 
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.blueGrey[900]!, Colors.black]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withOpacity(0.3))
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wallet, color: Colors.amber, size: 30),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("PUNTOS DISPONIBLES", style: TextStyle(color: Colors.amber, fontSize: 10, letterSpacing: 1.5)),
                        Text("$saldoPuntos", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Spacer(),
                    // Agregué una flechita para que sepan que se puede tocar
                    const Icon(Icons.arrow_forward_ios, color: Colors.amber, size: 14),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 5. ESTADÍSTICAS
            Row(
              children: [
                _statCard("Reportes", "$totalReportes", Icons.campaign), 
                const SizedBox(width: 15),
                _statCard("Ayudas", "$totalAyudas", Icons.handshake),
              ],
            ),

            const SizedBox(height: 50),

            // 1. SOPORTE TÉCNICO (Destacado) 🎧
            // Lo ponemos primero porque es lo que el usuario busca si tiene problemas.
            GestureDetector(
              onTap: _contactarSoporte,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05), // Le di un fondito suave para que resalte
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.support_agent, color: Colors.white, size: 22), // Icono más blanco
                    SizedBox(width: 10),
                    Text("Contactar Soporte", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 2. GESTIÓN DE SUSCRIPCIÓN (Solo Premium) 💎
            // Borré el duplicado. Ahora aparece una sola vez, debajo del soporte.
            if (isPremium) 
              TextButton(
                onPressed: _confirmarCancelacion,
                child: const Text(
                  "Gestionar mi Suscripción", 
                  style: TextStyle(color: Colors.redAccent, fontSize: 13) // Le saqué la transparencia para que se lea mejor
                ),
              ),

            // 3. LEGALES (Al final) ⚖️
            // Cambié el color a white54 para que se lea bien pero no robe atención
            const SizedBox(height: 30),
            GestureDetector(
              onTap: () {
                showDialog(context: context, builder: (ctx) => AlertDialog(
                  backgroundColor: Colors.grey[900],
                  title: const Text("Términos y Condiciones", style: TextStyle(color: Colors.white)),
                  content: const SingleChildScrollView(
                    child: Text(
                      terminosLegales, // Usamos la variable que pegamos abajo
                      style: TextStyle(color: Colors.white70, fontSize: 13)
                    )
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cerrar", style: TextStyle(color: Color(0xFF00FF99))))],
                ));
              },
              child: const Text(
                "Ver Términos y Condiciones de Uso", 
                style: TextStyle(color: Colors.white54, decoration: TextDecoration.underline, fontSize: 12)
              ),
            ),

            const SizedBox(height: 40), // Espacio final para que no pegue con el borde del celu
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white54, size: 24),
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// --- TEXTO LEGAL ---
const String terminosLegales = """
TÉRMINOS Y CONDICIONES DE USO

1. ACEPTACIÓN DE LOS TÉRMINOS
Al descargar y utilizar "Seguridad Vial App", usted acepta cumplir con estos términos. Si no está de acuerdo, por favor no utilice la aplicación.

2. USO RESPONSABLE
El usuario se compromete a emitir reportes verídicos y precisos. El uso malintencionado, spam o reportes falsos resultará en la suspensión permanente de la cuenta y la pérdida de los puntos acumulados.

3. EXENCIÓN DE RESPONSABILIDAD
Esta aplicación es una herramienta de ayuda y colaboración comunitaria. No garantizamos la exactitud del 100% de los reportes. El desarrollador no se hace responsable por accidentes, multas o daños ocurridos durante el uso de la aplicación. La responsabilidad de conducir con precaución recae exclusivamente en el conductor.

4. PRIVACIDAD Y UBICACIÓN
La aplicación utiliza su ubicación en tiempo real para mostrar alertas cercanas. Estos datos no se venden a terceros y se utilizan únicamente para el funcionamiento del mapa colaborativo.

5. SUSCRIPCIONES PREMIUM
Los pagos son procesados de forma segura a través de MercadoPago. La suscripción "Leyenda Vial" es mensual y se renueva automáticamente. Puede cancelar su suscripción en cualquier momento desde su perfil para evitar futuros cargos. No se realizan reembolsos parciales por meses ya iniciados.

6. MODIFICACIONES
Nos reservamos el derecho de modificar estos términos en cualquier momento. El uso continuado de la aplicación implica la aceptación de los nuevos términos.

Contacto: ayuda.seguridadvial@gmail.com
""";