import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/grupo.dart';
import '../models/invitacion_grupo.dart';
import '../models/miembro_resumen.dart';
import '../models/solicitud_ingreso.dart';
import '../models/usuario.dart';

/// Resultado de publicar un grupo: el grupo actualizado y las invitaciones
/// enviadas a los mejores perfiles.
class ResultadoPublicacion {
  const ResultadoPublicacion({required this.grupo, required this.invitaciones});

  final Grupo grupo;
  final List<InvitacionGrupo> invitaciones;
}

/// Formación de equipos sobre Cloud Firestore (colecciones `grupos`,
/// `invitaciones`, `solicitudes`). El matching por habilidades corre en el
/// cliente (sin Cloud Functions en el plan gratuito). Las consultas usan un
/// solo campo + filtro en memoria para no requerir índices compuestos.
class GrupoService {
  GrupoService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Máximo de perfiles notificados al publicar un grupo.
  static const int maxInvitaciones = 10;

  CollectionReference<Map<String, dynamic>> get _grupos =>
      _firestore.collection('grupos');
  CollectionReference<Map<String, dynamic>> get _invitaciones =>
      _firestore.collection('invitaciones');
  CollectionReference<Map<String, dynamic>> get _solicitudes =>
      _firestore.collection('solicitudes');
  CollectionReference<Map<String, dynamic>> get _usuarios =>
      _firestore.collection('usuarios');

  // ---------------------------------------------------------------------
  // Directorio de usuarios (candidatos reales al matching)
  // ---------------------------------------------------------------------

  Future<List<Usuario>> getUsuarios() async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _usuarios.get();
    return snap.docs
        .map<Usuario>(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              Usuario.fromJson(<String, dynamic>{...d.data(), 'id': d.id}),
        )
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------
  // Grupos
  // ---------------------------------------------------------------------

  /// Grupos visibles para [usuarioId]: los publicados de la convocatoria más
  /// sus propios borradores (los borradores ajenos no se listan).
  Future<List<Grupo>> getGruposPorConvocatoria(
    String convocatoriaId, {
    String? usuarioId,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _grupos
        .where('convocatoria_id', isEqualTo: convocatoriaId)
        .get();
    return snap.docs
        .map<Grupo>(_grupoDeDoc)
        .where(
          (Grupo g) =>
              g.estado == EstadoGrupo.publicado ||
              (usuarioId != null && g.esLider(usuarioId)),
        )
        .toList(growable: false);
  }

  /// Todos los grupos (para el panel de administración).
  Future<List<Grupo>> getTodosLosGrupos() async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _grupos.get();
    return snap.docs.map<Grupo>(_grupoDeDoc).toList(growable: false);
  }

  /// Grupos en los que [liderId] es líder (borradores y publicados), para la
  /// pantalla "Mis grupos".
  Future<List<Grupo>> getGruposDeLider(String liderId) async {
    final QuerySnapshot<Map<String, dynamic>> snap =
        await _grupos.where('lider_id', isEqualTo: liderId).get();
    return snap.docs.map<Grupo>(_grupoDeDoc).toList(growable: false);
  }

  /// Elimina un grupo (líder o admin, reforzado por reglas).
  Future<void> eliminarGrupo(String grupoId) async {
    await _grupos.doc(grupoId).delete();
  }

  /// Crea un grupo en estado borrador. El líder agrega integrantes libremente
  /// antes de publicarlo.
  Future<Grupo> crearGrupo({
    required String convocatoriaId,
    required String nombre,
    required String descripcion,
    required Usuario lider,
    required int capacidadMax,
    required List<String> habilidadesBuscadas,
    List<Usuario> miembrosIniciales = const <Usuario>[],
  }) async {
    final List<MiembroResumen> miembros = <MiembroResumen>[
      MiembroResumen.fromUsuario(lider),
    ];
    for (final Usuario u in miembrosIniciales) {
      if (!miembros.any((MiembroResumen m) => m.id == u.id)) {
        miembros.add(MiembroResumen.fromUsuario(u));
      }
    }
    if (miembros.length > capacidadMax) {
      throw StateError('Los integrantes iniciales superan la capacidad máxima.');
    }

    final DocumentReference<Map<String, dynamic>> ref = _grupos.doc();
    final Grupo nuevo = Grupo(
      id: ref.id,
      convocatoriaId: convocatoriaId,
      nombre: nombre,
      descripcion: descripcion,
      liderId: lider.id,
      liderNombre: lider.nombre,
      miembros: miembros,
      capacidadMax: capacidadMax,
      habilidadesBuscadas: List<String>.unmodifiable(habilidadesBuscadas),
      abierto: true,
      estado: EstadoGrupo.borrador,
    );
    await ref.set(nuevo.toJson());
    return nuevo;
  }

  /// El líder agrega a alguien directamente (en borrador o ya publicado).
  Future<Grupo> agregarMiembro({
    required String grupoId,
    required Usuario usuario,
  }) async {
    final Grupo grupo = await _buscarGrupo(grupoId);
    if (grupo.esMiembro(usuario.id)) {
      return grupo;
    }
    if (!grupo.tienePlazas) {
      throw StateError('El grupo ya no tiene cupo disponible.');
    }
    final Grupo actualizado = grupo.copyWith(
      miembros: <MiembroResumen>[
        ...grupo.miembros,
        MiembroResumen.fromUsuario(usuario),
      ],
    );
    await _guardarGrupo(actualizado);
    await _cerrarPendientesDe(grupoId, usuario.id);
    return _cerrarSiEstaLleno(actualizado);
  }

  /// Publica el grupo y notifica (invita) a los mejores perfiles que cubren
  /// las habilidades faltantes.
  Future<ResultadoPublicacion> publicarGrupo({
    required String grupoId,
    Usuario? usuarioSesion,
  }) async {
    Grupo grupo = await _buscarGrupo(grupoId);
    if (grupo.estado == EstadoGrupo.publicado) {
      throw StateError('El grupo ya fue publicado.');
    }
    grupo = grupo.copyWith(estado: EstadoGrupo.publicado);
    await _guardarGrupo(grupo);

    final List<Usuario> directorio = await getUsuarios();
    final List<Usuario> candidatos = <Usuario>[
      ...directorio,
      if (usuarioSesion != null &&
          !directorio.any((Usuario u) => u.id == usuarioSesion.id))
        usuarioSesion,
    ].where((Usuario u) => !grupo.esMiembro(u.id)).toList();

    final List<InvitacionGrupo> invitaciones =
        _invitarMejoresPerfiles(grupo, candidatos);
    for (final InvitacionGrupo inv in invitaciones) {
      await _invitaciones.doc(inv.id).set(inv.toJson());
    }
    return ResultadoPublicacion(grupo: grupo, invitaciones: invitaciones);
  }

  // ---------------------------------------------------------------------
  // Invitaciones
  // ---------------------------------------------------------------------

  /// Invitaciones pendientes del usuario.
  Future<List<InvitacionGrupo>> getInvitacionesParaUsuario(
    Usuario usuario,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _invitaciones
        .where('usuario_id', isEqualTo: usuario.id)
        .get();
    return snap.docs
        .map<InvitacionGrupo>(_invitacionDeDoc)
        .where((InvitacionGrupo i) => i.pendiente)
        .toList(growable: false);
  }

  /// El invitado acepta y se une automáticamente (la invitación ya lo
  /// pre-aprobó).
  Future<Grupo> aceptarInvitacion(String invitacionId) async {
    final InvitacionGrupo invitacion = await _buscarInvitacion(invitacionId);
    if (!invitacion.pendiente) {
      throw StateError('La invitación ya no está disponible.');
    }
    final Grupo grupo = await _buscarGrupo(invitacion.grupoId);
    if (!grupo.abierto || !grupo.tienePlazas) {
      await _guardarInvitacion(
        invitacion.copyWith(estado: EstadoInvitacion.expirada),
      );
      throw StateError('El grupo ya no tiene cupo disponible.');
    }

    final Grupo actualizado = grupo.copyWith(
      miembros: <MiembroResumen>[
        ...grupo.miembros,
        MiembroResumen.fromUsuario(invitacion.usuario),
      ],
    );
    await _guardarGrupo(actualizado);
    await _guardarInvitacion(
      invitacion.copyWith(estado: EstadoInvitacion.aceptada),
    );
    return _cerrarSiEstaLleno(actualizado);
  }

  Future<void> rechazarInvitacion(String invitacionId) async {
    final InvitacionGrupo invitacion = await _buscarInvitacion(invitacionId);
    await _guardarInvitacion(
      invitacion.copyWith(estado: EstadoInvitacion.rechazada),
    );
  }

  /// Invitación pendiente del usuario para un grupo, si existe.
  Future<InvitacionGrupo?> getInvitacionPendiente({
    required String grupoId,
    required String usuarioId,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _invitaciones
        .where('usuario_id', isEqualTo: usuarioId)
        .get();
    final List<InvitacionGrupo> pendientes = snap.docs
        .map<InvitacionGrupo>(_invitacionDeDoc)
        .where((InvitacionGrupo i) => i.grupoId == grupoId && i.pendiente)
        .toList();
    return pendientes.isEmpty ? null : pendientes.first;
  }

  // ---------------------------------------------------------------------
  // Solicitudes de ingreso
  // ---------------------------------------------------------------------

  /// Un usuario sin invitación pide unirse; queda pendiente del líder.
  Future<SolicitudIngreso> solicitarIngreso({
    required String grupoId,
    required Usuario usuario,
  }) async {
    final Grupo grupo = await _buscarGrupo(grupoId);
    if (grupo.estado != EstadoGrupo.publicado) {
      throw StateError('El grupo aún no está publicado.');
    }
    if (grupo.esMiembro(usuario.id)) {
      throw StateError('Ya eres integrante de este grupo.');
    }
    if (!grupo.abierto || !grupo.tienePlazas) {
      throw StateError('El grupo ya no tiene cupo disponible.');
    }

    final QuerySnapshot<Map<String, dynamic>> snap = await _solicitudes
        .where('usuario_id', isEqualTo: usuario.id)
        .get();
    final List<SolicitudIngreso> existentes = snap.docs
        .map<SolicitudIngreso>(_solicitudDeDoc)
        .where((SolicitudIngreso s) => s.grupoId == grupoId && s.pendiente)
        .toList();
    if (existentes.isNotEmpty) {
      return existentes.first;
    }

    final DocumentReference<Map<String, dynamic>> ref = _solicitudes.doc();
    final SolicitudIngreso solicitud = SolicitudIngreso(
      id: ref.id,
      grupoId: grupoId,
      liderId: grupo.liderId,
      usuario: usuario,
      estado: EstadoSolicitud.pendiente,
      fecha: DateTime.now().toIso8601String(),
    );
    await ref.set(solicitud.toJson());
    return solicitud;
  }

  Future<List<SolicitudIngreso>> getSolicitudesDeGrupo(String grupoId) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _solicitudes
        .where('grupo_id', isEqualTo: grupoId)
        .get();
    return snap.docs
        .map<SolicitudIngreso>(_solicitudDeDoc)
        .where((SolicitudIngreso s) => s.pendiente)
        .toList(growable: false);
  }

  /// Ids de grupos con solicitud pendiente del usuario.
  Future<Set<String>> getGruposSolicitadosPor(String usuarioId) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _solicitudes
        .where('usuario_id', isEqualTo: usuarioId)
        .get();
    return snap.docs
        .map<SolicitudIngreso>(_solicitudDeDoc)
        .where((SolicitudIngreso s) => s.pendiente)
        .map<String>((SolicitudIngreso s) => s.grupoId)
        .toSet();
  }

  /// El líder acepta o rechaza una solicitud.
  Future<Grupo> responderSolicitud({
    required String solicitudId,
    required bool aceptar,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _solicitudes.doc(solicitudId).get();
    if (!doc.exists) {
      throw StateError('La solicitud ya no existe.');
    }
    final SolicitudIngreso solicitud = _solicitudDeDoc(doc);
    final Grupo grupo = await _buscarGrupo(solicitud.grupoId);

    if (!aceptar) {
      await _guardarSolicitud(
        solicitud.copyWith(estado: EstadoSolicitud.rechazada),
      );
      return grupo;
    }

    if (!grupo.tienePlazas) {
      await _guardarSolicitud(
        solicitud.copyWith(estado: EstadoSolicitud.rechazada),
      );
      throw StateError('El grupo ya no tiene cupo disponible.');
    }

    final Grupo actualizado = grupo.copyWith(
      miembros: <MiembroResumen>[
        ...grupo.miembros,
        MiembroResumen.fromUsuario(solicitud.usuario),
      ],
    );
    await _guardarGrupo(actualizado);
    await _guardarSolicitud(
      solicitud.copyWith(estado: EstadoSolicitud.aceptada),
    );
    await _cerrarPendientesDe(grupo.id, solicitud.usuario.id);
    return _cerrarSiEstaLleno(actualizado);
  }

  // ---------------------------------------------------------------------
  // Matching (lógica pura)
  // ---------------------------------------------------------------------

  List<InvitacionGrupo> _invitarMejoresPerfiles(
    Grupo grupo,
    List<Usuario> candidatos,
  ) {
    if (grupo.habilidadesBuscadas.isEmpty || !grupo.tienePlazas) {
      return <InvitacionGrupo>[];
    }

    final List<({Usuario usuario, int puntuacion, List<String> coincidencias})>
        puntuados = <({
      Usuario usuario,
      int puntuacion,
      List<String> coincidencias
    })>[];

    for (final Usuario candidato in candidatos) {
      final List<String> coincidencias =
          _habilidadesCoincidentes(grupo, candidato);
      if (coincidencias.isEmpty) {
        continue;
      }
      puntuados.add((
        usuario: candidato,
        puntuacion: _puntuar(coincidencias, candidato),
        coincidencias: coincidencias,
      ));
    }

    puntuados.sort((a, b) => b.puntuacion.compareTo(a.puntuacion));

    final String fecha = DateTime.now().toIso8601String();
    return puntuados.take(maxInvitaciones).map<InvitacionGrupo>((p) {
      return InvitacionGrupo(
        id: _invitaciones.doc().id,
        grupoId: grupo.id,
        grupoNombre: grupo.nombre,
        liderId: grupo.liderId,
        usuario: p.usuario,
        puntuacion: p.puntuacion,
        habilidadesCoincidentes: p.coincidencias,
        estado: EstadoInvitacion.pendiente,
        fecha: fecha,
      );
    }).toList();
  }

  int _puntuar(List<String> coincidencias, Usuario candidato) {
    return coincidencias.length * 10 + (candidato.semestre ?? 0).clamp(0, 9);
  }

  List<String> _habilidadesCoincidentes(Grupo grupo, Usuario candidato) {
    return grupo.habilidadesBuscadas
        .where(
          (String buscada) => candidato.habilidades.any(
            (String propia) => _habilidadCoincide(buscada, propia),
          ),
        )
        .toList();
  }

  bool _habilidadCoincide(String buscada, String propia) {
    final String a = _normalizar(buscada);
    final String b = _normalizar(propia);
    bool contiene(String larga, String corta) =>
        corta.length >= 4 && larga.contains(corta);
    return a == b || contiene(a, b) || contiene(b, a);
  }

  String _normalizar(String texto) {
    const Map<String, String> reemplazos = <String, String>{
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u',
    };
    String normalizado = texto.trim().toLowerCase();
    reemplazos.forEach((String de, String a) {
      normalizado = normalizado.replaceAll(de, a);
    });
    return normalizado;
  }

  // ---------------------------------------------------------------------
  // Cierre / limpieza
  // ---------------------------------------------------------------------

  /// Al llenarse el cupo, el grupo se cierra y las invitaciones y solicitudes
  /// pendientes quedan sin efecto.
  Future<Grupo> _cerrarSiEstaLleno(Grupo grupo) async {
    if (grupo.tienePlazas) {
      return grupo;
    }
    final Grupo cerrado = grupo.copyWith(abierto: false);
    await _guardarGrupo(cerrado);

    final QuerySnapshot<Map<String, dynamic>> invs =
        await _invitaciones.where('grupo_id', isEqualTo: grupo.id).get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> d in invs.docs) {
      final InvitacionGrupo inv = _invitacionDeDoc(d);
      if (inv.pendiente) {
        await _guardarInvitacion(
          inv.copyWith(estado: EstadoInvitacion.expirada),
        );
      }
    }
    final QuerySnapshot<Map<String, dynamic>> sols =
        await _solicitudes.where('grupo_id', isEqualTo: grupo.id).get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> d in sols.docs) {
      final SolicitudIngreso sol = _solicitudDeDoc(d);
      if (sol.pendiente) {
        await _guardarSolicitud(
          sol.copyWith(estado: EstadoSolicitud.rechazada),
        );
      }
    }
    return cerrado;
  }

  /// Marca como resueltas las invitaciones y solicitudes pendientes de un
  /// usuario que ya entró al grupo por otra vía.
  Future<void> _cerrarPendientesDe(String grupoId, String usuarioId) async {
    final QuerySnapshot<Map<String, dynamic>> invs =
        await _invitaciones.where('usuario_id', isEqualTo: usuarioId).get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> d in invs.docs) {
      final InvitacionGrupo inv = _invitacionDeDoc(d);
      if (inv.grupoId == grupoId && inv.pendiente) {
        await _guardarInvitacion(
          inv.copyWith(estado: EstadoInvitacion.aceptada),
        );
      }
    }
    final QuerySnapshot<Map<String, dynamic>> sols =
        await _solicitudes.where('usuario_id', isEqualTo: usuarioId).get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> d in sols.docs) {
      final SolicitudIngreso sol = _solicitudDeDoc(d);
      if (sol.grupoId == grupoId && sol.pendiente) {
        await _guardarSolicitud(
          sol.copyWith(estado: EstadoSolicitud.aceptada),
        );
      }
    }
  }

  // ---------------------------------------------------------------------
  // Utilitarios de acceso a Firestore
  // ---------------------------------------------------------------------

  Future<Grupo> _buscarGrupo(String grupoId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _grupos.doc(grupoId).get();
    if (!doc.exists) {
      throw StateError('El grupo ya no existe.');
    }
    return _grupoDeDoc(doc);
  }

  Future<InvitacionGrupo> _buscarInvitacion(String invitacionId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _invitaciones.doc(invitacionId).get();
    if (!doc.exists) {
      throw StateError('La invitación ya no existe.');
    }
    return _invitacionDeDoc(doc);
  }

  Grupo _grupoDeDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Grupo.fromJson(<String, dynamic>{...doc.data()!, 'id': doc.id});

  InvitacionGrupo _invitacionDeDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      InvitacionGrupo.fromJson(<String, dynamic>{...doc.data()!, 'id': doc.id});

  SolicitudIngreso _solicitudDeDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      SolicitudIngreso.fromJson(<String, dynamic>{...doc.data()!, 'id': doc.id});

  Future<void> _guardarGrupo(Grupo grupo) =>
      _grupos.doc(grupo.id).set(grupo.toJson());

  Future<void> _guardarInvitacion(InvitacionGrupo invitacion) =>
      _invitaciones.doc(invitacion.id).set(invitacion.toJson());

  Future<void> _guardarSolicitud(SolicitudIngreso solicitud) =>
      _solicitudes.doc(solicitud.id).set(solicitud.toJson());
}
