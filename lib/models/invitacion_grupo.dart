import 'usuario.dart';

enum EstadoInvitacion { pendiente, aceptada, rechazada, expirada }

/// Invitación que la app envía a los mejores perfiles cuando un grupo
/// se publica. Quien la recibe puede unirse automáticamente al grupo.
class InvitacionGrupo {
  const InvitacionGrupo({
    required this.id,
    required this.grupoId,
    required this.grupoNombre,
    required this.liderId,
    required this.usuario,
    required this.puntuacion,
    required this.habilidadesCoincidentes,
    required this.estado,
    required this.fecha,
  });

  final String id;
  final String grupoId;
  final String grupoNombre;

  /// Líder del grupo (dueño). Escalar para reglas y consultas en Firestore.
  final String liderId;
  final Usuario usuario;
  final int puntuacion;
  final List<String> habilidadesCoincidentes;
  final EstadoInvitacion estado;
  final String fecha;

  bool get pendiente => estado == EstadoInvitacion.pendiente;

  /// Escalar del invitado; se guarda como `usuario_id` para reglas/consultas.
  String get usuarioId => usuario.id;

  factory InvitacionGrupo.fromJson(Map<String, dynamic> json) {
    return InvitacionGrupo(
      id: json['id'] as String,
      grupoId: json['grupo_id'] as String,
      grupoNombre: json['grupo_nombre'] as String,
      liderId: json['lider_id'] as String? ?? '',
      usuario: Usuario.fromJson(json['usuario'] as Map<String, dynamic>),
      puntuacion: json['puntuacion'] as int,
      habilidadesCoincidentes: List<String>.from(
        (json['habilidades_coincidentes'] as List<dynamic>? ?? <dynamic>[])
            .map<String>((dynamic h) => h.toString()),
      ),
      estado: EstadoInvitacion.values.byName(json['estado'] as String),
      fecha: json['fecha'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'grupo_id': grupoId,
      'grupo_nombre': grupoNombre,
      'lider_id': liderId,
      'usuario_id': usuario.id,
      'usuario': usuario.toJson(),
      'puntuacion': puntuacion,
      'habilidades_coincidentes': habilidadesCoincidentes,
      'estado': estado.name,
      'fecha': fecha,
    };
  }

  InvitacionGrupo copyWith({EstadoInvitacion? estado}) {
    return InvitacionGrupo(
      id: id,
      grupoId: grupoId,
      grupoNombre: grupoNombre,
      liderId: liderId,
      usuario: usuario,
      puntuacion: puntuacion,
      habilidadesCoincidentes: habilidadesCoincidentes,
      estado: estado ?? this.estado,
      fecha: fecha,
    );
  }
}
