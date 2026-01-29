import 'package:flutter/material.dart';

class InfoScreen extends StatelessWidget {
  final String vehiculoInicial;
  
  const InfoScreen({super.key, this.vehiculoInicial = 'auto'});

  @override
  Widget build(BuildContext context) {
    // Calculamos qué pestaña abrir según el vehículo que viene
    int indexInicial = 0;
    if (vehiculoInicial == 'moto') indexInicial = 1;
    if (vehiculoInicial == 'bici') indexInicial = 2;

    return DefaultTabController(
      initialIndex: indexInicial,
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text("Leyes y Multas 🇦🇷", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.grey[900],
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Color(0xFF00FF99),
            labelColor: Color(0xFF00FF99),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(icon: Icon(Icons.directions_car), text: "AUTO"),
              Tab(icon: Icon(Icons.two_wheeler), text: "MOTO"),
              Tab(icon: Icon(Icons.pedal_bike), text: "BICI"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _InfoList(tipo: "auto"),
            _InfoList(tipo: "moto"),
            _InfoList(tipo: "bici"),
          ],
        ),
      ),
    );
  }
}

class _InfoList extends StatelessWidget {
  final String tipo;
  const _InfoList({required this.tipo});

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [];

    if (tipo == "auto") {
      items = [
        _seccion("Documentación Obligatoria", [
          "DNI Digital o Físico.",
          "Licencia de Conducir (Vigente).",
          "Cédula Verde (o Azul si no sos titular).",
          "Comprobante de Seguro Vigente (PDF o tarjeta).",
          "VTV o RTO al día."
        ]),
        _seccion("Alcohol Cero (Ley 27.714)", [
          "⚠️ Límite: 0.0 gr/l en sangre.",
          "Aplica en todas las Rutas Nacionales.",
          "Vigente en Prov. de Bs. As., Córdoba, entre otras.",
          "Negarse al test implica presunción de alcoholemia positiva."
        ]),
        _seccion("Equipamiento", [
          "Matafuegos: Cargado, a mano y vigente.",
          "Juego de balizas portátiles.",
          "Luces bajas encendidas las 24hs en ruta."
        ]),
      ];
    } else if (tipo == "moto") {
      items = [
        _seccion("Reglas de Oro", [
          "⛑️ CASCO: Obligatorio para conductor y acompañante. Debe estar homologado y abrochado.",
          "Espejos retrovisores obligatorios (ambos lados).",
          "Luces encendidas permanentemente."
        ]),
        _seccion("Alcohol Cero", [
          "⚠️ Límite: 0.0 gr/l.",
          "Las motos son controladas con mayor rigor en operativos."
        ]),
        _seccion("Documentación", [
          "Mismos papeles que el auto (Licencia, Seguro, Cédula).",
          "Ojo: El seguro debe cubrir al acompañante si llevás uno."
        ]),
      ];
    } else if (tipo == "bici") {
      items = [
        _seccion("Seguridad Ciclista", [
          "Luces: Blanca adelante, Roja atrás (Obligatorio de noche).",
          "Casco protector.",
          "Ropa clara o reflectiva.",
          "Respetar SIEMPRE los semáforos."
        ]),
        _seccion("Prioridades", [
          "Tenés derecho a ocupar el carril si no hay ciclovía.",
          "Prohibido circular por autopistas.",
          "Señalizá tus giros con los brazos."
        ]),
      ];
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: items,
    );
  }

  Widget _seccion(String titulo, List<String> puntos) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(color: Color(0xFF00FF99), fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...puntos.map((txt) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("• ", style: TextStyle(color: Colors.white, fontSize: 16)),
                Expanded(child: Text(txt, style: const TextStyle(color: Colors.white70, fontSize: 14))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}