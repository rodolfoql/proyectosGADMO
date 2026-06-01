import 'dart:convert';

/// Modelo de Proyecto (Nivel 1 - Estratégico)
class Proyecto {
  final int? id;
  final String nombre;
  final String contratista;
  final String tipo;
  final double montoTotal;
  final int plazo; // Duración total en días
  final String fechaInicio; // Formato YYYY-MM-DD

  Proyecto({
    this.id,
    required this.nombre,
    required this.contratista,
    required this.tipo,
    required this.montoTotal,
    required this.plazo,
    required this.fechaInicio,
  });

  // Convierte a Mapa para insertar en SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'contratista': contratista,
      'tipo': tipo,
      'monto_total': montoTotal,
      'plazo': plazo,
      'fecha_inicio': fechaInicio,
    };
  }

  // Crea instancia desde SQLite
  factory Proyecto.fromMap(Map<String, dynamic> map) {
    return Proyecto(
      id: map['id'],
      nombre: map['nombre'] ?? '',
      contratista: map['contratista'] ?? '',
      tipo: map['tipo'] ?? 'VIAS',
      montoTotal: (map['monto_total'] as num).toDouble(),
      plazo: map['plazo'] ?? 0,
      fechaInicio: map['fecha_inicio'] ?? '',
    );
  }

  /// Calcula el estado de salud del proyecto basado en el Plazo vs Avance Real
  /// Utilizado para la semaforización automática
  String calcularSemaforo(double montoReal, double montoPlan) {
    if (fechaInicio.isEmpty || plazo == 0) return "Pendiente";

    DateTime inicio = DateTime.parse(fechaInicio);
    int diasTranscurridos = DateTime.now().difference(inicio).inDays;

    // Avance esperado por tiempo (lineal)
    double avanceEsperado = (diasTranscurridos / plazo) * 100;
    // Avance real financiero/físico
    double avanceReal = (montoReal / (montoPlan > 0 ? montoPlan : 1)) * 100;

    double brecha = avanceReal - avanceEsperado;

    if (brecha >= 0) return "A tiempo / Adelantado";
    if (brecha > -15) return "Retraso Leve";
    return "Retraso Crítico";
  }
}

/// Modelo de Hito (Nivel 2 - Táctico)
class Hito {
  final int? id;
  final int proyectoId;
  final String descripcion;
  final String fechaInicio;
  final String fechaFin;
  final double presupuestoProg;

  Hito({
    this.id,
    required this.proyectoId,
    required this.descripcion,
    required this.fechaInicio,
    required this.fechaFin,
    required this.presupuestoProg,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'proyecto_id': proyectoId,
      'descripcion': descripcion,
      'fecha_inicio': fechaInicio,
      'fecha_fin': fechaFin,
      'presupuesto_prog': presupuestoProg,
    };
  }

  factory Hito.fromMap(Map<String, dynamic> map) {
    return Hito(
      id: map['id'],
      proyectoId: map['proyecto_id'],
      descripcion: map['descripcion'] ?? '',
      fechaInicio: map['fecha_inicio'] ?? '',
      fechaFin: map['fecha_fin'] ?? '',
      presupuestoProg: (map['presupuesto_prog'] as num).toDouble(),
    );
  }
}

/// Modelo de Geografía GIS (Nivel 3 - Operativo)
class Geografia {
  final int? id;
  final int hitoId;
  final String tipoGeo; // punto, linea, poligono
  final String descripcion;
  final String unidad;
  final double cantidad;
  final double precioUnitario;
  final double total; // cantidad * precioUnitario
  final String coordenadas; // String JSON de List<LatLng>

  Geografia({
    this.id,
    required this.hitoId,
    required this.tipoGeo,
    required this.descripcion,
    required this.unidad,
    required this.cantidad,
    required this.precioUnitario,
    required this.total,
    required this.coordenadas,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hito_id': hitoId,
      'tipo_geo': tipoGeo,
      'descripcion': descripcion,
      'unidad': unidad,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'total': total,
      'coordenadas': coordenadas,
    };
  }

  factory Geografia.fromMap(Map<String, dynamic> map) {
    return Geografia(
      id: map['id'],
      hitoId: map['hito_id'],
      tipoGeo: map['tipo_geo'] ?? 'linea',
      descripcion: map['descripcion'] ?? '',
      unidad: map['unidad'] ?? 'm',
      cantidad: (map['cantidad'] as num).toDouble(),
      precioUnitario: (map['precio_unitario'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      coordenadas: map['coordenadas'] ?? '[]',
    );
  }
}
