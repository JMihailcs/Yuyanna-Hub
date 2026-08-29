import 'usuario.dart';

enum EstadoSolicitud { pendiente, aceptada, rechazada }

/// Solicitud de un estudiante para unirse a un grupo publicado.
/// Solo el líder puede aceptarla; nunca produce un ingreso automático.
class SolicitudIngreso {
  const SolicitudIngreso({
    required this.id,
    required this.grupoId,
    required this.liderId,
    required this.usuario,
    required this.estado,
    required this.fecha,
  });

  final String id;
  final String grupoId;

  /// Líder del grupo (dueño). Escalar para reglas y consultas en Firestore.
  final String liderId;
  final Usuario usuario;
  final EstadoSolicitud estado;
  final String fecha;

  bool get pendiente => estado == EstadoSolicitud.pendiente;

  /// Escalar del solicitante; se guarda como `usuario_id` para reglas.
  String get usuarioId => usuario.id;

  factory SolicitudIngreso.fromJson(Map<String, dynamic> json) {
    return SolicitudIngreso(
      id: json['id'] as String,
      grupoId: json['grupo_id'] as String,
      liderId: json['lider_id'] as String? ?? '',
      usuario: Usuario.fromJson(json['usuario'] as Map<String, dynamic>),
      estado: EstadoSolicitud.values.byName(json['estado'] as String),
      fecha: json['fecha'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'grupo_id': grupoId,
      'lider_id': liderId,
      'usuario_id': usuario.id,
      'usuario': usuario.toJson(),
      'estado': estado.name,
      'fecha': fecha,
    };
  }

  SolicitudIngreso copyWith({EstadoSolicitud? estado}) {
    return SolicitudIngreso(
      id: id,
      grupoId: grupoId,
      liderId: liderId,
      usuario: usuario,
      estado: estado ?? this.estado,
      fecha: fecha,
    );
  }
}
