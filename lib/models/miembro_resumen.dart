import 'usuario.dart';

/// Resumen embebido de un integrante dentro de un `Grupo`.
///
/// Se guarda **desnormalizado** en el documento del grupo para que leerlo
/// traiga a todos sus miembros en UNA sola lectura (sin N+1). Solo incluye
/// lo que la UI necesita para pintar la tarjeta del integrante; el perfil
/// completo y autoritativo vive en la colección `usuarios/{id}`.
class MiembroResumen {
  const MiembroResumen({
    required this.id,
    required this.nombre,
    required this.escuelaProfesional,
    required this.semestre,
  });

  final String id;
  final String nombre;
  final String escuelaProfesional;
  final int semestre;

  factory MiembroResumen.fromUsuario(Usuario usuario) {
    return MiembroResumen(
      id: usuario.id,
      nombre: usuario.nombre,
      escuelaProfesional: usuario.escuelaProfesional ?? '',
      semestre: usuario.semestre ?? 0,
    );
  }

  factory MiembroResumen.fromJson(Map<String, dynamic> json) {
    return MiembroResumen(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      escuelaProfesional: json['escuela_profesional'] as String? ?? '',
      semestre: json['semestre'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'nombre': nombre,
      'escuela_profesional': escuelaProfesional,
      'semestre': semestre,
    };
  }
}
