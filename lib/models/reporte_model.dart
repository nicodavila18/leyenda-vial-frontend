class Reporte {
  final String id;
  final String description;
  final String tipo;       // Ejemplo: "Control de Alcoholemia"
  // final String iconAsset;  // Ejemplo: "assets/icons/alcohol.png"
  final double latitud;
  final double longitud;
  final DateTime createdAt;
  final String autor;
  final int experiencia;

  Reporte({
    required this.id,
    required this.description,
    required this.tipo,
    // required this.iconAsset,
    required this.latitud,
    required this.longitud,
    required this.createdAt,
    required this.autor,
    required this.experiencia,
  });

  // Esta fábrica es la "traductora": Toma el JSON de Python y crea el objeto Dart
  factory Reporte.fromJson(Map<String, dynamic> json) {
    return Reporte(
      id: json['id'].toString(),
      description: json['description'] ?? '', // Si viene vacío, ponemos texto vacío
      tipo: json['tipo'] ?? 'Desconocido',
      // iconAsset: json['icon_asset'] ?? '', // Ojo: En Python es con guión bajo
      // Convertimos a double por seguridad, a veces vienen como números enteros
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at']),
      autor: json['autor'] ?? 'Anónimo',
      experiencia: json['lifetime_xp'] ?? 0,
    );
  }
}