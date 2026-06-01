import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('geoproy_otav5.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    // Subimos a versión 2 para actualizar la estructura física local
    return await openDatabase(
        join(dbPath, filePath),
        version: 2,
        onCreate: _createDB,
        onUpgrade: _onUpgrade
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Re-creación controlada del esquema para pruebas limpias de arquitectura
      await db.execute('DROP TABLE IF EXISTS multas');
      await db.execute('DROP TABLE IF EXISTS ampliaciones');
      await db.execute('DROP TABLE IF EXISTS suspensiones');
      await db.execute('DROP TABLE IF EXISTS geografias');
      await db.execute('DROP TABLE IF EXISTS hitos');
      await db.execute('DROP TABLE IF EXISTS hitos_grupos');
      await db.execute('DROP TABLE IF EXISTS proyectos');
      await _createDB(db, newVersion);
    }
  }

  Future _createDB(Database db, int version) async {
    // 1. TABLA PROYECTOS (Nivel Estratégico, Recursividad y Tiempos Dinámicos)
    await db.execute('''CREATE TABLE proyectos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      proyecto_padre_id INTEGER NULL, -- Enlace recursivo para Subproyectos (Punto 2)
      nombre TEXT NOT NULL,
      contratista TEXT,
      administrador_contrato TEXT,
      contacto_comunidad TEXT,
      monto_total REAL,             
      presupuesto_devengado REAL DEFAULT 0.0,
      saldo REAL DEFAULT 0.0,
      porcentaje_avance REAL DEFAULT 0.0,
      
      -- Flujo de Estados Solicitado y Semáforos
      estado_proyecto TEXT DEFAULT 'Idea de Proyecto', 
      estado_sistema TEXT DEFAULT 'Inicio',  
      alerta_atraso INTEGER DEFAULT 0, 
      prioridad TEXT DEFAULT 'MEDIA',
      observacion TEXT,
      canton TEXT DEFAULT 'OTAVALO',
      
      -- Restricción de Selección Estricta para Parroquias de Otavalo (Punto 3)
      parroquia TEXT NOT NULL CHECK (parroquia IN (
        'SELVA ALEGRE','PATAQUI','SAN JOSE DE QUICHINCHE','SAN PABLO',
        'GONZALEZ SUAREZ','SAN RAFAEL','SAN JUAN DE ILUMAN',
        'DOCTOR MIGUEL EGAS CABEZAS','EUGENIO ESPEJO','EL JORDAN URBANO',
        'EL JORDAN RURAL','SAN LUIS URBANO','SAN LUIS RURAL','OTAVALO'
      )),
      
      barrio TEXT,
      plazo INTEGER NOT NULL, -- Plazo contractual base original
      
      -- Campos dinámicos incrementales de Auditoría Técnica (Puntos 5 y 6)
      plazo_dinamico INTEGER, 
      fecha_inicio TEXT NOT NULL,
      fecha_final TEXT, -- Fecha contractual proyectada inicial
      fecha_culminacion TEXT, -- Cálculo automático final (Inicio + Plazo Dinámico) (Punto 6)
      
      categoria_obra TEXT, 
      foto_inicial TEXT,
      foto_final TEXT,
      coordenadas_maestras TEXT,
      
      -- Nuevos campos de Fiscalización y Sercop (Punto 1)
      url_sercop TEXT,
      fiscalizador TEXT,
      codigo_contrato TEXT,
      
      -- Campos Adicionales Técnicos (No obligatorios)
      elaborado_por TEXT,
      revisado_por TEXT,
      aprobado_por TEXT,
      porcentaje_utilidades REAL DEFAULT 0.0,
      porcentaje_imprevistos REAL DEFAULT 0.0,
      porcentaje_gastos_generales REAL DEFAULT 0.0,
      porcentaje_fiscalizacion REAL DEFAULT 0.0,
      fecha_elaboracion TEXT,
      fecha_aprobacion TEXT,
      presupuesto_referencial REAL DEFAULT 0.0,
      antecedentes TEXT,
      justificacion TEXT,
      marco_legal TEXT,
      objetivos TEXT,
      descripcion_general TEXT,
      conclusiones TEXT,
      recomendaciones TEXT,
      
      FOREIGN KEY (proyecto_padre_id) REFERENCES proyectos (id) ON DELETE SET NULL
    )''');

    // 2. TABLA HITOS_GRUPOS (Capítulos de Obra)
    await db.execute('''CREATE TABLE hitos_grupos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      proyecto_id INTEGER,
      nombre TEXT,
      FOREIGN KEY (proyecto_id) REFERENCES proyectos (id) ON DELETE CASCADE
    )''');

    // 3. TABLA HITOS / RUBROS (Nivel Técnico con Restricción de Unidades SERCOP)
    await db.execute('''CREATE TABLE hitos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      grupo_id INTEGER, 
      rubro TEXT, 
      descripcion TEXT,
      fecha_inicio TEXT, 
      plazo INTEGER, 
      fecha_fin TEXT, 
      
      -- Restricción de Selección Estricta para Unidades Técnicas (Punto 4)
      unidad TEXT NOT NULL CHECK (unidad IN ('u','kg','m','m2','m3','ml','jgo','glb','km','pto','Ha')),
      
      cantidad REAL, 
      precio_unitario REAL, 
      total REAL, 
      estado TEXT DEFAULT 'Inicio',
      fotografia TEXT,
      cumplido INTEGER DEFAULT 0,
      especificaciones_tecnicas TEXT,
      observacion TEXT,
      elaborado_por TEXT,
      porcentaje_indirectos REAL DEFAULT 0.0,
      costo_indirectos REAL DEFAULT 0.0,
      vae REAL DEFAULT 0.0,
      cpc TEXT,
      FOREIGN KEY (grupo_id) REFERENCES hitos_grupos (id) ON DELETE CASCADE
    )''');

    // 4. TABLA GEOGRAFIAS (Evidencia GIS Multimedia)
    await db.execute('''CREATE TABLE geografias (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      hito_id INTEGER, 
      tipo_geo TEXT, 
      descripcion TEXT,
      coordenadas TEXT,
      fotografia TEXT, 
      audio TEXT,      
      FOREIGN KEY (hito_id) REFERENCES hitos (id) ON DELETE CASCADE
    )''');

    // 5. SUBTABLA ONE-TO-MANY SUSPENSIONES (Punto 7)
    await db.execute('''CREATE TABLE suspensiones (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      proyecto_id INTEGER NOT NULL,
      motivo_suspension TEXT NOT NULL,
      fecha_suspension TEXT NOT NULL, 
      fecha_reactivacion TEXT,         
      total_dias_suspendido INTEGER DEFAULT 0,
      estado TEXT NOT NULL CHECK (estado IN ('SUSPENDIDO', 'SUSPENCION FINALIZADA')),
      FOREIGN KEY (proyecto_id) REFERENCES proyectos (id) ON DELETE CASCADE
    )''');

    // 6. SUBTABLA ONE-TO-MANY AMPLIACIONES (Punto 8)
    await db.execute('''CREATE TABLE ampliaciones (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      proyecto_id INTEGER NOT NULL,
      motivo_ampliacion TEXT NOT NULL,
      fecha_ampliacion TEXT NOT NULL,  
      nro_dias_ampliacion INTEGER NOT NULL,
      fecha_final TEXT,               
      FOREIGN KEY (proyecto_id) REFERENCES proyectos (id) ON DELETE CASCADE
    )''');

    // 7. SUBTABLA ONE-TO-MANY MULTAS (Punto 9)
    await db.execute('''CREATE TABLE multas (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      proyecto_id INTEGER NOT NULL,
      motivo_multa TEXT NOT NULL,
      valor REAL NOT NULL,
      estado TEXT NOT NULL, 
      FOREIGN KEY (proyecto_id) REFERENCES proyectos (id) ON DELETE CASCADE
    )''');
  }


  // --- FUNCIONES DE CÁLCULO Y AUDITORÍA INTEGRAL ---

  String _calcularFechaFinal(String fechaInicio, int dias) {
    try {
      DateTime inicio = DateFormat('yyyy-MM-dd').parse(fechaInicio);
      return DateFormat('yyyy-MM-dd').format(inicio.add(Duration(days: dias)));
    } catch (e) { return fechaInicio; }
  }

  /// Recalcula y audita de forma síncrona la ingeniería financiera, los plazos dinámicos
  /// y las fechas de culminación exacta considerando suspensiones y ampliaciones (Puntos 5, 6, 7, 8).
  Future<void> auditarProyecto(int proyectoId) async {
    final db = await instance.database;
    var resProy = await db.query('proyectos', where: 'id = ?', whereArgs: [proyectoId]);
    if (resProy.isEmpty) return;
    var proy = resProy.first;

    String fechaInicioProy = proy['fecha_inicio'] as String;
    int plazoContractualOriginal = proy['plazo'] as int;
    double montoTotal = (proy['monto_total'] as num).toDouble();

    // Recalcular plazos de suspensiones individuales y consolidadas (Punto 7)
    var suspensiones = await db.query('suspensiones', where: 'proyecto_id = ?', whereArgs: [proyectoId]);
    int acumuladoDiasSuspension = 0;

    for (var s in suspensiones) {
      int diasDeEstaSuspension = 0;
      if (s['fecha_reactivacion'] != null && (s['fecha_reactivacion'] as String).isNotEmpty) {
        try {
          DateTime fSusp = DateFormat('yyyy-MM-dd').parse(s['fecha_suspension'] as String);
          DateTime fReac = DateFormat('yyyy-MM-dd').parse(s['fecha_reactivacion'] as String);
          diasDeEstaSuspension = fReac.difference(fSusp).inDays;
          if (diasDeEstaSuspension < 0) diasDeEstaSuspension = 0;
        } catch (_) {}
      }

      await db.update('suspensiones', {
        'total_dias_suspendido': diasDeEstaSuspension
      }, where: 'id = ?', whereArgs: [s['id']]);

      acumuladoDiasSuspension += diasDeEstaSuspension;
    }

    // Recalcular fechas de ampliaciones individuales y acumular días (Punto 8)
    var ampliaciones = await db.query('ampliaciones', where: 'proyecto_id = ?', whereArgs: [proyectoId]);
    int acumuladoDiasAmpliacion = 0;

    for (var a in ampliaciones) {
      int diasAmp = a['nro_dias_ampliacion'] as int;
      String fAmp = a['fecha_ampliacion'] as String;
      String fFinalCalculadaAmpliacion = _calcularFechaFinal(fAmp, diasAmp);

      await db.update('ampliaciones', {
        'fecha_final': fFinalCalculadaAmpliacion
      }, where: 'id = ?', whereArgs: [a['id']]);

      acumuladoDiasAmpliacion += diasAmp;
    }

    // Calcular los Nuevos Plazos Dinámicos del Proyecto (Punto 5 y 6)
    int nuevoPlazoDinamico = plazoContractualOriginal + acumuladoDiasSuspension + acumuladoDiasAmpliacion;
    String nuevaFechaCulminacion = _calcularFechaFinal(fechaInicioProy, nuevoPlazoDinamico);

    // Auditoría Financiera de Rubros Ejecutados (Lógica original)
    var resSum = await db.rawQuery('''
      SELECT SUM(h.total) as devengado FROM hitos h 
      JOIN hitos_grupos hg ON h.grupo_id = hg.id 
      WHERE hg.proyecto_id = ? AND h.cumplido = 1''', [proyectoId]);

    double devengado = (resSum.first['devengado'] as num?)?.toDouble() ?? 0.0;
    double porcentaje = (devengado / (montoTotal > 0 ? montoTotal : 1)) * 100;

    DateTime inicio = DateFormat('yyyy-MM-dd').parse(fechaInicioProy);
    int diasTrans = DateTime.now().difference(inicio).inDays;
    double avanceTiempoTeorico = (diasTrans / (plazoContractualOriginal > 0 ? plazoContractualOriginal : 1)) * 100;
    int alerta = (porcentaje < avanceTiempoTeorico - 15) ? 1 : 0;

    await db.update('proyectos', {
      'presupuesto_devengado': devengado,
      'saldo': montoTotal - devengado,
      'porcentaje_avance': porcentaje.clamp(0, 100),
      'estado_sistema': (alerta == 1) ? "Retraso Crítico" : "A tiempo",
      'alerta_atraso': alerta,
      'plazo_dinamico': nuevoPlazoDinamico,
      'fecha_culminacion': nuevaFechaCulminacion
    }, where: 'id = ?', whereArgs: [proyectoId]);
  }

  // --- MÉTODOS CRUD PROYECTOS ---
  Future<int> insertarProyecto(Map<String, dynamic> row) async {
    final db = await instance.database;

    // 1. Obtener los datos del usuario logueado en SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    String? rawUserData = prefs.getString('userData');
    int odooUserId = 99; // ID de respaldo preventivo por si falla la lectura

    if (rawUserData != null) {
      try {
        var userMap = jsonDecode(rawUserData);
        odooUserId = userMap['id'] ?? 99;
      } catch (e) {
        print("Error de parseo de usuario en pref: $e");
      }
    }

    // 2. Calcular la base de rango única para este fiscalizador
    // Rango reservado: Permite hasta 99,999 obras por cada técnico de forma aislada
    int offsetBase = odooUserId * 100000;

    // 3. Consultar el ID más alto utilizado por ESTE usuario específico en SQLite
    final List<Map<String, dynamic>> result = await db.rawQuery(
        'SELECT MAX(id) as max_id FROM proyectos WHERE id > ? AND id < ?',
        [offsetBase, offsetBase + 100000]
    );

    int nuevoIdCalculado;
    if (result.isNotEmpty && result.first['max_id'] != null) {
      nuevoIdCalculado = (result.first['max_id'] as int) + 1;
    } else {
      nuevoIdCalculado = offsetBase + 1; // Primer proyecto de este ingeniero
    }

    // 4. Clonar el mapa e inyectar el ID inmutable calculado antes de la persistencia
    Map<String, dynamic> dataSaneada = Map.from(row);
    dataSaneada['id'] = nuevoIdCalculado;
    dataSaneada['elaborado_por'] = odooUserId.toString(); // Forzamos la firma de auditoría

    // Executamos la inserción física con el ID explícito libre de choques
    await db.insert('proyectos', dataSaneada);

    // Ejecutamos la auditoría interna del cronograma de la obra al instante
    await auditarProyecto(nuevoIdCalculado);
    return nuevoIdCalculado;
  }
/*
  Future<int> insertarProyecto(Map<String, dynamic> datos) async {
    final db = await instance.database;
    var raw = Map<String, dynamic>.from(datos);
    if (raw['fecha_inicio'] != null && raw['plazo'] != null) {
      raw['fecha_final'] = _calcularFechaFinal(raw['fecha_inicio'], raw['plazo']);
      raw['fecha_culminacion'] = raw['fecha_final'];
      raw['plazo_dinamico'] = raw['plazo'];
      raw['saldo'] = raw['monto_total'];
    }
    return await db.insert('proyectos', raw);
  }
  */

  Future<int> actualizarProyecto(int id, Map<String, dynamic> datos) async {
    final db = await instance.database;
    var raw = Map<String, dynamic>.from(datos);
    if (raw['fecha_inicio'] != null && raw['plazo'] != null) {
      raw['fecha_final'] = _calcularFechaFinal(raw['fecha_inicio'], raw['plazo']);
    }
    int res = await db.update('proyectos', raw, where: 'id = ?', whereArgs: [id]);
    await auditarProyecto(id);
    return res;
  }

  Future<List<Map<String, dynamic>>> obtenerProyectos() async {
    final db = await instance.database;
    return await db.query('proyectos', orderBy: 'alerta_atraso DESC, id DESC');
  }

  Future<List<Map<String, dynamic>>> obtenerSubproyectos(int padreId) async {
    final db = await instance.database;
    return await db.query('proyectos', where: 'proyecto_padre_id = ?', orderBy: 'id DESC', whereArgs: [padreId]);
  }

  // --- MÉTODOS CRUD GRUPOS ---

  //Future<int> insertarGrupo(Map<String, dynamic> datos) async => await (await database).insert('hitos_grupos', datos);

  Future<int> insertarGrupo(Map<String, dynamic> row) async {
    final db = await instance.database;

    final prefs = await SharedPreferences.getInstance();
    String? rawUserData = prefs.getString('userData');
    int odooUserId = 99;

    if (rawUserData != null) {
      try {
        var userMap = jsonDecode(rawUserData);
        odooUserId = userMap['id'] ?? 99;
      } catch (e) {
        print("Error en pref: $e");
      }
    }

    int offsetBase = odooUserId * 100000;

    // Buscamos el ID máximo de capítulos creados por este técnico
    final List<Map<String, dynamic>> result = await db.rawQuery(
        'SELECT MAX(id) as max_id FROM hitos_grupos WHERE id > ? AND id < ?',
        [offsetBase, offsetBase + 100000]
    );

    int nuevoIdGrupo;
    if (result.isNotEmpty && result.first['max_id'] != null) {
      nuevoIdGrupo = (result.first['max_id'] as int) + 1;
    } else {
      nuevoIdGrupo = offsetBase + 1;
    }

    Map<String, dynamic> dataSaneada = Map.from(row);
    dataSaneada['id'] = nuevoIdGrupo;

    await db.insert('hitos_grupos', dataSaneada);
    return nuevoIdGrupo;
  }



  Future<int> actualizarGrupo(int id, Map<String, dynamic> datos) async => await (await database).update('hitos_grupos', datos, where: 'id = ?', whereArgs: [id]);
  Future<List<Map<String, dynamic>>> obtenerGruposPorProyecto(int pId) async => await (await database).query('hitos_grupos', where: 'proyecto_id = ?', whereArgs: [pId]);

  // --- MÉTODOS CRUD HITOS / RUBROS ---

  Future<int> insertarHito(Map<String, dynamic> datos, int proyectoId) async {
    final db = await instance.database;
    var raw = Map<String, dynamic>.from(datos);
    if (raw['fecha_inicio'] != null && raw['plazo'] != null) {
      raw['fecha_fin'] = _calcularFechaFinal(raw['fecha_inicio'], raw['plazo']);
    }
    raw['total'] = (raw['cantidad'] ?? 0) * (raw['precio_unitario'] ?? 0);
    int id = await db.insert('hitos', raw);
    await auditarProyecto(proyectoId);
    return id;
  }

  Future<int> actualizarHito(int id, Map<String, dynamic> datos, int proyectoId) async {
    final db = await instance.database;
    var raw = Map<String, dynamic>.from(datos);
    raw['total'] = (raw['cantidad'] ?? 0) * (raw['precio_unitario'] ?? 0);
    if (raw['fecha_inicio'] != null && raw['plazo'] != null) {
      raw['fecha_fin'] = _calcularFechaFinal(raw['fecha_inicio'], raw['plazo']);
    }
    int res = await db.update('hitos', raw, where: 'id = ?', whereArgs: [id]);
    await auditarProyecto(proyectoId);
    return res;
  }

  Future<void> marcarCumplimientoHito(int hitoId, int valor, int proyectoId) async {
    final db = await instance.database;
    await db.update('hitos', {'cumplido': valor}, where: 'id = ?', whereArgs: [hitoId]);
    await auditarProyecto(proyectoId);
  }

  Future<List<Map<String, dynamic>>> obtenerHitosPorGrupo(int gId) async => await (await database).query('hitos', where: 'grupo_id = ?', whereArgs: [gId]);

  // --- MÉTODOS CRUD GEOGRAFÍAS Y CONTEOS ---

  Future<List<Map<String, dynamic>>> obtenerGISPorHito(int hitoId) async => await (await database).query('geografias', where: 'hito_id = ?', whereArgs: [hitoId]);
  Future<int> insertarGeografia(Map<String, dynamic> datos) async => await (await database).insert('geografias', datos);

  Future<int> consultarConteo(String tabla, String where, List<dynamic> args) async {
    final db = await instance.database;
    var res = await db.rawQuery('SELECT COUNT(*) as total FROM $tabla WHERE $where', args);
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<int> eliminar(String tabla, int id, {int? proyectoId}) async {
    final db = await instance.database;
    int res = await db.delete(tabla, where: 'id = ?', whereArgs: [id]);
    if (proyectoId != null) await auditarProyecto(proyectoId);
    return res;
  }


  // --- OPERACIONES DE SUBTABLAS CONTROL DE OBRA ---

  // Inserciones y Consultas para Suspensiones (Punto 7)
  // --- INSERCIÓN BLINDADA DE SUSPENSIONES CON MUTACIÓN DE ESTADO INMEDIATA ---
  Future<int> insertarSuspension(Map<String, dynamic> row, int proyectoId) async {
    final db = await instance.database;

    // 1. Insertamos el evento cronológico en la subtabla
    int idSuspension = await db.insert('suspensiones', {
      'proyecto_id': proyectoId,
      'motivo_suspension': row['motivo_suspension'],
      'fecha_suspension': row['fecha_suspension'],
      'fecha_reactivacion': row['fecha_reactivacion'],
      'estado': row['estado'], // 'SUSPENDIDO' o 'SUSPENCION FINALIZADA'
    });

    // 2. CORRECCIÓN DE RAÍZ: Evaluamos la fecha fin para mutar la columna correcta del proyecto
    String nuevoEstadoObra = row['fecha_reactivacion'] == null ? 'SUSPENDIDO' : 'EN EJECUCION';

    await db.update(
      'proyectos',
      {'estado_proyecto': nuevoEstadoObra}, // Sincroniza el nombre exacto de la columna
      where: 'id = ?',
      whereArgs: [proyectoId],
    );

    // 3. Forzamos el recálculo masivo de días y consolidación del POA hacia el Padre
    await auditarProyecto(proyectoId);

    return idSuspension;
  }

  /*
  Future<int> insertarSuspension(Map<String, dynamic> datos, int proyectoId) async {
    final db = await instance.database;
    int id = await db.insert('suspensiones', {...datos, 'proyecto_id': proyectoId});
    await auditarProyecto(proyectoId);
    return id;
  }
  */

  Future<List<Map<String, dynamic>>> obtenerSuspensionesProyecto(int proyectoId) async {
    final db = await instance.database;
    return await db.query('suspensiones', where: 'proyecto_id = ?', orderBy: 'fecha_suspension DESC', whereArgs: [proyectoId]);
  }

  // Inserciones y Consultas para Ampliaciones (Punto 8)
  Future<int> insertarAmpliacion(Map<String, dynamic> datos, int proyectoId) async {
    final db = await instance.database;
    int id = await db.insert('ampliaciones', {...datos, 'proyecto_id': proyectoId});
    await auditarProyecto(proyectoId);
    return id;
  }
  Future<List<Map<String, dynamic>>> obtenerAmpliacionesProyecto(int proyectoId) async {
    final db = await instance.database;
    return await db.query('ampliaciones', where: 'proyecto_id = ?', orderBy: 'fecha_ampliacion DESC', whereArgs: [proyectoId]);
  }

  // Inserciones y Consultas para Multas (Punto 9)
  Future<int> insertarMulta(Map<String, dynamic> datos, int proyectoId) async {
    final db = await instance.database;
    return await db.insert('multas', {...datos, 'proyecto_id': proyectoId});
  }
  Future<List<Map<String, dynamic>>> obtenerMultasProyecto(int proyectoId) async {
    final db = await instance.database;
    return await db.query('multas', where: 'proyecto_id = ?', orderBy: 'id DESC', whereArgs: [proyectoId]);
  }

  // --- LÓGICA DE SINCRONIZACIÓN BIDIRECCIONAL DESDE ODOO (ORIGINAL INTACTA) ---

  Future<void> insertarOActualizarDesdeOdoo(Map<String, dynamic> proyOdoo) async {
    final db = await instance.database;
    int? localId = proyOdoo['id'];

    Map<String, dynamic> proyectoData = {
      'nombre': proyOdoo['nombre'],
      'contratista': proyOdoo['contratista'],
      'monto_total': proyOdoo['monto_total'],
      'presupuesto_devengado': proyOdoo['presupuesto_devengado'] ?? 0.0,
      'fecha_inicio': proyOdoo['fecha_inicio'],
      'plazo': proyOdoo['plazo'],
      'fecha_final': proyOdoo['fecha_final'],
      'parroquia': proyOdoo['parroquia'],
      'barrio': proyOdoo['barrio'],
      'coordenadas_maestras': proyOdoo['coordenadas_maestras'],
      'administrador_contrato': proyOdoo['administrador_contrato'],
      'contacto_comunidad': proyOdoo['contacto_comunidad'],
      'observacion': proyOdoo['observacion'],
      'estado_sistema': 'Sincronizado',

      // Mapeo opcional de campos incrementados desde Odoo si existieran en la trama
      'url_sercop': proyOdoo['url_sercop'],
      'fiscalizador': proyOdoo['fiscalizador'],
      'codigo_contrato': proyOdoo['codigo_contrato'],
    };

    int proyectoId;
    List<Map> existente = await db.query('proyectos', where: 'id = ?', whereArgs: [localId]);

    if (existente.isNotEmpty) {
      proyectoId = localId!;
      await db.update('proyectos', proyectoData, where: 'id = ?', whereArgs: [proyectoId]);
    } else {
      proyectoId = await db.insert('proyectos', proyectoData);
    }

    if (proyOdoo['grupos'] != null) {
      for (var g in proyOdoo['grupos']) {
        int grupoId;
        List<Map> grupoExistente = await db.query('hitos_grupos',
            where: 'nombre = ? AND proyecto_id = ?',
            whereArgs: [g['nombre'], proyectoId]);

        if (grupoExistente.isNotEmpty) {
          grupoId = grupoExistente.first['id'];
        } else {
          grupoId = await db.insert('hitos_grupos', {
            'nombre': g['nombre'],
            'proyecto_id': proyectoId
          });
        }

        if (g['hitos'] != null) {
          for (var h in g['hitos']) {
            Map<String, dynamic> hitoData = {
              'grupo_id': grupoId,
              'rubro': h['rubro'],
              'descripcion': h['descripcion'],
              'cantidad': h['cantidad'],
              'precio_unitario': h['precio_unitario'],
              'total': (h['cantidad'] ?? 0.0) * (h['precio_unitario'] ?? 0.0),
              'fecha_inicio': h['fecha_inicio'],
              'estado': h['estado'] ?? 'Sincronizado',
              'fotografia': h['fotografia'],
              'cumplido': h['cumplido'] ?? 0,
              'unidad': h['unidad'] ?? 'u' // Seteo preventivo para no romper el CHECK
            };

            int hitoId;
            List<Map> hitoExistente = await db.query('hitos',
                where: 'rubro = ? AND grupo_id = ?',
                whereArgs: [h['rubro'], grupoId]);

            if (hitoExistente.isNotEmpty) {
              hitoId = hitoExistente.first['id'];
              await db.update('hitos', hitoData, where: 'id = ?', whereArgs: [hitoId]);
            } else {
              hitoId = await db.insert('hitos', hitoData);
            }

            await db.delete('geografias', where: 'hito_id = ?', whereArgs: [hitoId]);

            if (h['geografias'] != null) {
              for (var geo in h['geografias']) {
                await db.insert('geografias', {
                  'hito_id': hitoId,
                  'tipo_geo': geo['tipo_geo'] ?? 'Point',
                  'descripcion': geo['descripcion'] ?? '',
                  'coordenadas': geo['coordenadas'] ?? '{}',
                  'fotografia': geo['fotografia'],
                });
              }
            }
          }
        }
      }
    }
    // Disparamos auditoría local para consolidar cálculos tras la bajada masiva de Odoo
    await auditarProyecto(proyectoId);
  }
}
