import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/convocatoria.dart';

/// Lectura y publicación de eventos/convocatorias en Cloud Firestore.
///
/// Publicar está permitido solo a administradores (Paqarina); esa regla se
/// **refuerza en `firestore.rules`** (colección `admins/{uid}`), no solo aquí.
class ConvocatoriaService {
  ConvocatoriaService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _convocatorias =>
      _firestore.collection('convocatorias');

  /// Eventos publicados, más recientes primero.
  Future<List<Convocatoria>> getConvocatoriasActivas() async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _convocatorias
        .orderBy('fecha_publicacion', descending: true)
        .get();
    return snap.docs
        .map<Convocatoria>(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              Convocatoria.fromJson(<String, dynamic>{
            ...doc.data(),
            'id': doc.id,
          }),
        )
        .toList(growable: false);
  }

  /// Crea un evento. Solo admins (reforzado por Security Rules).
  /// `imagenUrl`/`videoUrl` son URLs (el archivo vive en el host externo, R2).
  Future<Convocatoria> crearConvocatoria({
    required String titulo,
    required String descripcion,
    required String tipo,
    required String fechaCierre,
    required String premio,
    required String requisitos,
    String? imagenUrl,
    String? videoUrl,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _convocatorias.doc();
    final Convocatoria convocatoria = Convocatoria(
      id: ref.id,
      titulo: titulo.trim(),
      descripcion: descripcion.trim(),
      tipo: tipo,
      fechaPublicacion: _hoy(),
      fechaCierre: fechaCierre,
      premio: premio.trim(),
      requisitos: requisitos.trim(),
      imagenUrl: _limpiarUrl(imagenUrl),
      videoUrl: _limpiarUrl(videoUrl),
    );
    await ref.set(convocatoria.toJson());
    return convocatoria;
  }

  /// Actualiza un evento existente. Solo admin completo (reforzado por reglas:
  /// `update` en `convocatorias` exige `esAdmin()`). Conserva el id y la fecha
  /// de publicación original; reemplaza el resto de campos.
  Future<Convocatoria> actualizarConvocatoria({
    required String id,
    required String fechaPublicacion,
    required String titulo,
    required String descripcion,
    required String tipo,
    required String fechaCierre,
    required String premio,
    required String requisitos,
    String? imagenUrl,
    String? videoUrl,
  }) async {
    final Convocatoria convocatoria = Convocatoria(
      id: id,
      titulo: titulo.trim(),
      descripcion: descripcion.trim(),
      tipo: tipo,
      fechaPublicacion: fechaPublicacion,
      fechaCierre: fechaCierre,
      premio: premio.trim(),
      requisitos: requisitos.trim(),
      imagenUrl: _limpiarUrl(imagenUrl),
      videoUrl: _limpiarUrl(videoUrl),
    );
    await _convocatorias.doc(id).set(convocatoria.toJson());
    return convocatoria;
  }

  /// Elimina un evento (solo admins, reforzado por reglas).
  Future<void> eliminarConvocatoria(String id) async {
    await _convocatorias.doc(id).delete();
  }

  static String? _limpiarUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return null;
    }
    return url.trim();
  }

  static String _hoy() {
    final DateTime now = DateTime.now();
    final String mm = now.month.toString().padLeft(2, '0');
    final String dd = now.day.toString().padLeft(2, '0');
    return '${now.year}-$mm-$dd';
  }
}
