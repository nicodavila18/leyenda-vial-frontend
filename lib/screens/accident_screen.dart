import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AccidentScreen extends StatelessWidget {
  const AccidentScreen({super.key});

  // Función para llamar
  Future<void> _llamar(String numero) async {
    final Uri launchUri = Uri(scheme: 'tel', path: numero);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      // Si falla (ej: simulador), intentamos lanzar igual
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("EMERGENCIA", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Tocá para llamar inmediatamente",
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // BOTÓN 911 GIGANTE
            _botonEmergencia("911", "EMERGENCIAS", Colors.redAccent, Icons.sos),
            const SizedBox(height: 15),
            
            Row(
              children: [
                Expanded(child: _botonEmergencia("107", "SAME / Ambulancia", Colors.green, Icons.medical_services)),
                const SizedBox(width: 15),
                Expanded(child: _botonEmergencia("100", "Bomberos", Colors.orange, Icons.fire_truck)),
              ],
            ),

            const SizedBox(height: 40),
            const Divider(color: Colors.white24),
            const SizedBox(height: 20),

            const Text("PROTOCOLO RÁPIDO", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            
            _consejo("1. Mantené la calma", "No muevas a los heridos salvo peligro de incendio."),
            _consejo("2. Asegurá la zona", "Poné balizas y no te pares en la calzada."),
            _consejo("3. Datos Clave", "Al llamar, indicá ubicación exacta y cantidad de heridos."),
            _consejo("4. No cortes", "Esperá a que el operador te diga que podés colgar."),

          ],
        ),
      ),
    );
  }

  Widget _botonEmergencia(String numero, String label, Color color, IconData icon) {
    return ElevatedButton(
      onPressed: () => _llamar(numero),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 20),
        side: BorderSide(color: color, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 10),
          Text(numero, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _consejo(String titulo, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF00FF99), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(desc, style: const TextStyle(color: Colors.white60, fontSize: 13)),
              ],
            ),
          )
        ],
      ),
    );
  }
}