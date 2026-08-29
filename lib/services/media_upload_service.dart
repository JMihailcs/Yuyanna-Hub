import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Configuración del endpoint de subida (Cloudflare Worker).
class MediaConfig {
  /// URL del Cloudflare Worker de subida (sin barra final).
  static const String workerUrl =
      'https://yuyanna-uploads.paqarina.workers.dev';

  /// No hay token compartido: el Worker autoriza con el ID token de Firebase
  /// del usuario y exige que tenga rol admin. Ver `cloudflare/upload-worker.js`.

  /// True cuando ya reemplazaste el valor por defecto.
  static bool get configurado => !workerUrl.contains('TU-WORKER');
}

/// Sube archivos (imágenes/videos) al Worker de Cloudflare, que los guarda en
/// R2 y devuelve una URL pública servida por el propio Worker.
class MediaUploadService {
  MediaUploadService({http.Client? client, FirebaseAuth? auth})
      : _client = client ?? http.Client(),
        _auth = auth ?? FirebaseAuth.instance;

  final http.Client _client;
  final FirebaseAuth _auth;

  Future<String> subir({
    required Uint8List bytes,
    required String nombreArchivo,
    required String contentType,
  }) async {
    if (!MediaConfig.configurado) {
      throw StateError(
        'Falta configurar el Worker de subida (MediaConfig.workerUrl).',
      );
    }
    final User? usuario = _auth.currentUser;
    if (usuario == null) {
      throw StateError('Inicia sesión para subir material.');
    }
    // Token firmado por Google, válido una hora y propio de este usuario: el
    // Worker verifica la firma y comprueba su rol admin en Firestore.
    final String? idToken = await usuario.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError('No se pudo obtener la credencial de la sesión.');
    }

    final Uri uri = Uri.parse('${MediaConfig.workerUrl}/upload');
    final http.Response resp = await _client.post(
      uri,
      headers: <String, String>{
        'Content-Type': contentType,
        'X-Filename': nombreArchivo,
        'Authorization': 'Bearer $idToken',
      },
      body: bytes,
    );
    if (resp.statusCode != 200) {
      throw StateError('La subida falló (${resp.statusCode}): ${resp.body}');
    }
    final Map<String, dynamic> data =
        jsonDecode(resp.body) as Map<String, dynamic>;
    final String? url = data['url'] as String?;
    if (url == null || url.isEmpty) {
      throw StateError('El Worker no devolvió una URL.');
    }
    return url;
  }

  /// Adivina el content-type por la extensión del archivo.
  static String contentTypePara(String nombre) {
    final String ext = nombre.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      default:
        return 'application/octet-stream';
    }
  }
}
