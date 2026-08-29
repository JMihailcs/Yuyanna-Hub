import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../database/sqlite_helper.dart';
import '../models/usuario.dart';

/// Autenticación real con Firebase Auth + perfil en Cloud Firestore.
///
/// Reemplaza la sesión mock (solo `shared_preferences`), pero mantiene
/// `LocalSessionManager` como caché local del [Usuario] para que las
/// pantallas que ya leen de ahí sigan funcionando sin cambios.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usuarios =>
      _firestore.collection('usuarios');

  User? get usuarioAuth => _auth.currentUser;
  bool get haySesion => _auth.currentUser != null;
  Stream<User?> get cambiosDeSesion => _auth.authStateChanges();

  /// Crea la cuenta en Firebase Auth y su perfil en Firestore (`usuarios/{uid}`).
  Future<Usuario> registrar({
    required String nombre,
    required String correo,
    required List<String> habilidades,
    required String password,
    String? escuelaProfesional,
    int? semestre,
    String? ocupacion,
  }) async {
    final String email = correo.trim().toLowerCase();

    final UserCredential cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final String uid = cred.user!.uid;

    final Usuario usuario = Usuario(
      id: uid,
      nombre: nombre.trim(),
      correo: email,
      escuelaProfesional: _textoOpcional(escuelaProfesional),
      semestre: semestre,
      ocupacion: _textoOpcional(ocupacion),
      habilidades: List<String>.unmodifiable(habilidades),
    );

    await _usuarios.doc(uid).set(usuario.toJson());
    await cred.user!.updateDisplayName(usuario.nombre);
    // Enviamos el correo de verificación (opcional para el piloto).
    await cred.user!.sendEmailVerification();

    await _guardarSesionLocal(usuario);
    return usuario;
  }

  /// Inicia sesión y devuelve el perfil almacenado en Firestore.
  Future<Usuario> iniciarSesion({
    required String correo,
    required String password,
  }) async {
    final String email = correo.trim().toLowerCase();

    final UserCredential cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final Usuario usuario = await _cargarPerfil(cred.user!.uid);
    await _guardarSesionLocal(usuario);
    return usuario;
  }

  /// Perfil del usuario autenticado (caché local si coincide, si no Firestore).
  Future<Usuario?> usuarioActual() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return null;
    }
    final Usuario? cache = await LocalSessionManager.getUser();
    if (cache != null && cache.id == user.uid) {
      return cache;
    }
    final Usuario usuario = await _cargarPerfil(user.uid);
    await _guardarSesionLocal(usuario);
    return usuario;
  }

  /// Actualiza el perfil en `usuarios/{uid}` y refresca la caché local.
  ///
  /// Usa `set` (reemplazo total) para que, al cambiar de Estudiante a Externo
  /// (o viceversa), los campos que ya no aplican (escuela/semestre u ocupación)
  /// desaparezcan del documento en lugar de quedar obsoletos.
  Future<Usuario> actualizarPerfil(Usuario usuario) async {
    await _usuarios.doc(usuario.id).set(usuario.toJson());
    final User? user = _auth.currentUser;
    if (user != null && usuario.nombre != user.displayName) {
      await user.updateDisplayName(usuario.nombre);
    }
    await _guardarSesionLocal(usuario);
    return usuario;
  }

  /// Envía el correo de restablecimiento de contraseña.
  Future<void> enviarRestablecimiento(String correo) async {
    final String email = correo.trim().toLowerCase();
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> cerrarSesion() async {
    await _auth.signOut();
    await LocalSessionManager.clearSession();
  }

  static String? _textoOpcional(String? valor) {
    final String limpio = (valor ?? '').trim();
    return limpio.isEmpty ? null : limpio;
  }

  Future<Usuario> _cargarPerfil(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _usuarios.doc(uid).get();
    final Map<String, dynamic>? data = doc.data();
    if (data == null) {
      throw StateError('El perfil del usuario no existe en Firestore.');
    }
    // Aseguramos que el id sea el uid aunque el documento no lo tenga.
    return Usuario.fromJson(<String, dynamic>{...data, 'id': uid});
  }

  Future<void> _guardarSesionLocal(Usuario usuario) async {
    await LocalSessionManager.saveUser(usuario);
    await LocalSessionManager.saveLoginState(true);
  }

  /// Traduce cualquier error de auth a un mensaje en español para la UI.
  static String mensajeDeError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'El correo no es válido.';
        case 'user-disabled':
          return 'Esta cuenta está deshabilitada.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Correo o contraseña incorrectos.';
        case 'email-already-in-use':
          return 'Ya existe una cuenta con este correo.';
        case 'weak-password':
          return 'La contraseña es demasiado débil.';
        case 'network-request-failed':
          return 'Sin conexión. Revisa tu internet.';
        case 'too-many-requests':
          return 'Demasiados intentos. Intenta más tarde.';
        default:
          return 'No se pudo completar la operación. (${error.code})';
      }
    }
    return 'Ocurrió un error inesperado. Intenta de nuevo.';
  }
}
