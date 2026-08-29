import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/usuario.dart';

/// Roles de administración guardados en `admins/{uid}.rol`.
enum RolAdmin {
  /// Admin completo: panel de administración (eventos, usuarios, grupos, admins).
  admin,

  /// Admin de Paqarina: solo ve los eventos publicados y sus grupos.
  paqarina,
}

extension RolAdminX on RolAdmin {
  String get valor => this == RolAdmin.admin ? 'admin' : 'admin_paqarina';
  String get etiqueta =>
      this == RolAdmin.admin ? 'Administrador' : 'Admin Paqarina';
}

RolAdmin? rolAdminDesde(String? valor) {
  switch (valor) {
    case 'admin':
      return RolAdmin.admin;
    case 'admin_paqarina':
      return RolAdmin.paqarina;
    default:
      return null;
  }
}

/// Gestión de roles de administrador (Paqarina).
///
/// El **primer admin** se resuelve con una lista de *correos fundadores*: si
/// alguien inicia sesión con uno de esos correos y aún no es admin, la app le
/// crea el doc `admins/{uid}` con rol `admin` (bootstrap). Reforzado en
/// `firestore.rules` (`esFundador()` debe listar los mismos correos).
class AdminService {
  AdminService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// ⚠️ CAMBIA/AGREGA aquí los correos de los responsables de Paqarina.
  /// Debe coincidir con `esFundador()` en `firestore.rules`.
  static const List<String> correosFundadores = <String>[
    '215783@unsaac.edu.pe',
  ];

  CollectionReference<Map<String, dynamic>> get _admins =>
      _firestore.collection('admins');
  CollectionReference<Map<String, dynamic>> get _usuarios =>
      _firestore.collection('usuarios');

  /// Rol del usuario, o `null` si no es admin. Un doc sin campo `rol`
  /// (creado antes de introducir roles) se considera `admin` completo.
  Future<RolAdmin?> rolDe(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _admins.doc(uid).get();
    if (!doc.exists) {
      return null;
    }
    return rolAdminDesde(doc.data()?['rol'] as String?) ?? RolAdmin.admin;
  }

  /// ¿Es admin completo (con acceso al panel)?
  Future<bool> esAdmin(String uid) async =>
      (await rolDe(uid)) == RolAdmin.admin;

  bool esFundador(String correo) =>
      correosFundadores.contains(correo.trim().toLowerCase());

  /// Bootstrap: si es fundador y todavía no es admin, lo crea con rol `admin`.
  Future<void> asegurarAdminFundador(Usuario usuario) async {
    if (!esFundador(usuario.correo)) {
      return;
    }
    final DocumentReference<Map<String, dynamic>> ref = _admins.doc(usuario.id);
    if ((await ref.get()).exists) {
      return;
    }
    await ref.set(<String, dynamic>{
      'nombre': usuario.nombre,
      'correo': usuario.correo,
      'rol': RolAdmin.admin.valor,
      'fundador': true,
    });
  }

  /// Lista de administradores (para el panel).
  Future<List<AdminInfo>> listarAdmins() async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _admins.get();
    return snap.docs
        .map<AdminInfo>((QueryDocumentSnapshot<Map<String, dynamic>> d) {
      final Map<String, dynamic> data = d.data();
      return AdminInfo(
        uid: d.id,
        nombre: (data['nombre'] as String?) ?? '',
        correo: (data['correo'] as String?) ?? '',
        rol: rolAdminDesde(data['rol'] as String?) ?? RolAdmin.admin,
        fundador: (data['fundador'] as bool?) ?? false,
      );
    }).toList();
  }

  /// Conjunto de uids que tienen algún rol admin (para la lista de usuarios).
  Future<Set<String>> uidsAdmins() async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _admins.get();
    return snap.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> d) => d.id)
        .toSet();
  }

  /// Mapa uid → rol de cada administrador (para etiquetar la lista de usuarios
  /// distinguiendo "Administrador" de "Admin Paqarina").
  Future<Map<String, RolAdmin>> rolesDeAdmins() async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _admins.get();
    return <String, RolAdmin>{
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs)
        d.id: rolAdminDesde(d.data()['rol'] as String?) ?? RolAdmin.admin,
    };
  }

  /// Promueve a un usuario existente al [rol] indicado.
  Future<void> promover(Usuario usuario, {RolAdmin rol = RolAdmin.admin}) async {
    await _admins.doc(usuario.id).set(<String, dynamic>{
      'nombre': usuario.nombre,
      'correo': usuario.correo,
      'rol': rol.valor,
      'fundador': false,
    });
  }

  /// Promueve por correo: busca al usuario en `usuarios` y crea su doc admin.
  Future<void> promoverPorCorreo(
    String correo, {
    RolAdmin rol = RolAdmin.admin,
  }) async {
    final String email = correo.trim().toLowerCase();
    final QuerySnapshot<Map<String, dynamic>> snap =
        await _usuarios.where('correo', isEqualTo: email).get();
    if (snap.docs.isEmpty) {
      throw StateError('No hay un usuario registrado con "$email".');
    }
    final QueryDocumentSnapshot<Map<String, dynamic>> doc = snap.docs.first;
    final Map<String, dynamic> data = doc.data();
    await _admins.doc(doc.id).set(<String, dynamic>{
      'nombre': (data['nombre'] as String?) ?? '',
      'correo': (data['correo'] as String?) ?? email,
      'rol': rol.valor,
      'fundador': false,
    });
  }

  /// Cambia el rol de un administrador existente (admin ↔ admin_paqarina)
  /// sin quitarlo ni re-crearlo.
  Future<void> cambiarRol(String uid, RolAdmin rol) async {
    await _admins.doc(uid).update(<String, dynamic>{'rol': rol.valor});
  }

  /// Quita el rol de administrador.
  Future<void> quitarAdmin(String uid) async {
    await _admins.doc(uid).delete();
  }
}

/// Datos mínimos de un administrador para el panel.
class AdminInfo {
  const AdminInfo({
    required this.uid,
    required this.nombre,
    required this.correo,
    required this.rol,
    required this.fundador,
  });

  final String uid;
  final String nombre;
  final String correo;
  final RolAdmin rol;
  final bool fundador;
}
